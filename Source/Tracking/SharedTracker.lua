local _, ArenaAnalytics = ... -- Namespace
local SharedTracker = ArenaAnalytics.SharedTracker;

-- Local module aliases
local ArenaTracker = ArenaAnalytics.ArenaTracker;
local BattlegroundTracker = ArenaAnalytics.BattlegroundTracker;
local SpecSpells = ArenaAnalytics.SpecSpells;
local API = ArenaAnalytics.API;
local Helpers = ArenaAnalytics.Helpers;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------

function SharedTracker:GetPlayer(playerID)
	if(not playerID or playerID == "") then
		return nil;
	end

	local players;
	if(ArenaTracker:IsTracking()) then
		local currentMatch = ArenaTracker:GetCurrentArena();
		players = currentMatch and currentMatch.players;
	elseif(BattlegroundTracker:IsTracking()) then
		local currentMatch = BattlegroundTracker:GetCurrentBattleground();
		players = currentMatch and currentMatch.players;
	end

	if(not players) then
		return;
	end

	for i = 1, #players do
		local player = players[i];
		if (player) then
			if(Helpers:ToSafeLower(player.name) == Helpers:ToSafeLower(playerID)) then
				return player;
			elseif(player.GUID == playerID) then
				return player;
			else -- Unit Token
				local GUID = UnitGUID(playerID);
				if(GUID and GUID == player.GUID) then
					return player;
				end
			end
		end
	end
	return nil;
end

function SharedTracker:HasSpec(GUID)
	local player = SharedTracker:GetPlayer(GUID);
	return player and Helpers:IsSpecID(player.spec);
end

-- Is tracking player, supports GUID, name and unitToken
function SharedTracker:IsTrackingPlayer(playerID)
	return (SharedTracker:GetPlayer(playerID) ~= nil);
end

-- Attempts to get initial data on arena players:
-- GUID, name, race, class, spec
function SharedTracker:ProcessCombatLogEvent(...)
	if (not API:IsInArena()) then
		return;
	end

	-- Tracking teams for spec/race and in case arena is quitted
	local timestamp,logEventType,_,sourceGUID,_,_,_,destGUID,_,_,_,spellID,spellName = CombatLogGetCurrentEventInfo();
	if (logEventType == "SPELL_CAST_SUCCESS") then
		ArenaTracker:TryRemoveFromDeaths(sourceGUID, spellName);
		SharedTracker:DetectSpec(sourceGUID, spellID, spellName);
	elseif(logEventType == "SPELL_AURA_APPLIED" or logEventType == "SPELL_AURA_REMOVED") then
		SharedTracker:DetectSpec(sourceGUID, spellID, spellName);
	elseif(destGUID and destGUID:find("Player-", 1, true)) then
		-- Player Death
		if (logEventType == "UNIT_DIED") then
			ArenaTracker:HandlePlayerDeath(destGUID, false);
		end
		-- Player killed
		if (logEventType == "PARTY_KILL") then
			ArenaTracker:HandlePlayerDeath(destGUID, true);
		end
	end
end

function SharedTracker:GetSpecializationsBySpell(spellID)
	local spec_id, hero_spec_id;

	-- Specialziation
	if(SpecSpells.GetSpec) then
		spec_id = SpecSpells:GetSpec(spellID);		
	end

	-- Hero Spec
	if(SpecSpells.GetHeroSpec) then
		hero_spec_id = SpecSpells:GetHeroSpec(spellID);
	end

	return spec_id, hero_spec_id;
end

function SharedTracker:ProcessUnitAuraEvent(...)
	-- Excludes versions without spell detection included
	if(not SpecSpells or not SpecSpells.GetSpec) then
		return;
	end

	if (not API:IsInArena()) then
		return;
	end

	local unitTarget, updateInfo = ...;
	if(not updateInfo or updateInfo.isFullUpdate) then
		return;
	end

	if(updateInfo.addedAuras) then
		for _,aura in ipairs(updateInfo.addedAuras) do
			if(aura and aura.sourceUnit and aura.isFromPlayerOrPlayerPet) then
				local sourceGUID = UnitGUID(aura.sourceUnit);

				SharedTracker:DetectSpec(sourceGUID, aura.spellId, aura.name);
			end
		end
	end
end

-- Detects spec if a spell is spec defining, attaches it to its
-- caster if they weren't defined yet, or adds a new unit with it
function SharedTracker:DetectSpec(sourceGUID, spellID, spellName)
	if(not SpecSpells) then
		return;
	end

	-- Only players matter for spec detection
	if (not string.find(sourceGUID, "Player-", 1, true)) then
		return;
	end

	local spec_id, hero_spec_id = SharedTracker:GetSpecializationsBySpell(spellID);
	SharedTracker:OnSpecDetected(sourceGUID, spec_id, hero_spec_id);
end

function SharedTracker:OnSpecDetected(GUID, spec_id, hero_spec_id)
	if(not GUID or (not spec_id and not hero_spec_id)) then
		return;
	end

	if(ArenaTracker:IsTracking()) then
		if(SharedTracker:IsTrackingPlayer(GUID)) then
			ArenaTracker:AssignSpec(GUID, spec_id, hero_spec_id);
		else
			-- Check if unit should be added
			ArenaTracker:FillMissingPlayers(GUID, spec_id, hero_spec_id);
		end
	elseif(BattlegroundTracker:IsTracking()) then
		BattlegroundTracker:HandleSpecDetected(GUID, spec_id, hero_spec_id);
	end
end
