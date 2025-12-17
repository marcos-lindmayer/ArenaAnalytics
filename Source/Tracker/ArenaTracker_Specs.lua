local _, ArenaAnalytics = ... -- Namespace
local ArenaTracker = ArenaAnalytics.ArenaTracker;

-- Local module aliases
local SpecSpells = ArenaAnalytics.SpecSpells;
local API = ArenaAnalytics.API;
local Helpers = ArenaAnalytics.Helpers;
local Inspection = ArenaAnalytics.Inspection;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------

local currentArena = {};
function ArenaTracker:InitializeSubmodule_Specs()
    currentArena = ArenaAnalyticsTransientDB.currentArena;
end


function ArenaTracker:HasSpec(GUID)
	local player = ArenaTracker:GetPlayer(GUID);
	return player and Helpers:IsSpecID(player.spec);
end


function ArenaTracker:ProcessUnitAuraEvent(...)
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
				local sourceGUID = Helpers:UnitGUID(aura.sourceUnit);

				ArenaTracker:DetectSpec(sourceGUID, aura.spellId, aura.name);
			end
		end
	end
end


function ArenaTracker:HandleOpponentUpdate()
	if (not API:IsInArena()) then
		return;
	end

	ArenaTracker:FillMissingPlayers();

	-- If API exist to get opponent spec, use it
	if(GetArenaOpponentSpec) then
		for i = 1, currentArena.size do
			local unitToken = "arena"..i;
			local player = ArenaTracker:GetPlayer(unitToken);
			if(player) then
				if(not Helpers:IsSpecID(player.spec)) then
					local spec_id = API:GetArenaPlayerSpec(i, true);
					Debug:Log("Assigning spec for:", unitToken, spec_id);
					ArenaTracker:OnSpecDetected(unitToken, spec_id);
				end
			end
		end
	end
end


function ArenaTracker:RequestPartySpecs()
	for i = 1, currentArena.size do
		local unitToken = "party"..i;
		local player = ArenaTracker:GetPlayer(Helpers:UnitGUID(unitToken));
		if(player and not Helpers:IsSpecID(player.spec)) then
			if(Inspection and Inspection.RequestSpec) then
				Debug:Log("Tracker: HandlePartyUpdate requesting spec:", unitToken, Helpers:UnitGUID(unitToken));
				Inspection:RequestSpec(unitToken);
			end
		end
	end
end


-- Detects spec if a spell is spec defining, attaches it to its
-- caster if they weren't defined yet, or adds a new unit with it
function ArenaTracker:DetectSpec(sourceGUID, spellID, spellName)
	if(not SpecSpells or not SpecSpells.GetSpec) then
		return;
	end

	-- Only players matter for spec detection
	if(not sourceGUID) then
		return;
	end

	if(sourceGUID:find("Pet-", 1, true)) then
		-- Find owner if possible
		sourceGUID = ArenaTracker:TryFindPetOwnerGUID(sourceGUID);
	end

	if(not sourceGUID or not sourceGUID:find("Player-", 1, true)) then
		return;
	end

	-- Check if spell belongs to spec defining spells
	local spec_id, points = SpecSpells:GetSpec(spellID, spellName);

	if (spec_id ~= nil) then
		-- Check if unit should be added
		ArenaTracker:FillMissingPlayers(); -- sourceGUID, spec_id);		@TODO: Determine if there were any advantage to adding params for filling
		ArenaTracker:UpdateSpecData(sourceGUID, spec_id, points);
	end
end


function ArenaTracker:UpdateSpecData(playerID, spec_id, points)
	if(not playerID or not spec_id) then
		return;
	end

	local player = ArenaTracker:GetPlayer(playerID);
	if(not player) then
		return;
	end

	-- Get whether spec has been proven
	if(Helpers:IsSpecID(player.spec) and player.spec ~= 13) then -- Preg doesn't count as a known spec
		Debug:Log("Tracker: Keeping old spec:", player.spec, " for player: ", player.name);
		return;
	end

	ArenaTracker:AssignSpecData(player, spec_id, points);
end


function ArenaTracker:AssignSpecData(player, spec_id, points)
	if(not player) then
		return;
	end

	-- Sanitize points
	points = tonumber(points) or -1;

	if(not player.specData) then
		player.specData = {};
	end

	local data = player.specData;
	data[spec_id] = tonumber(data[spec_id]) or -2;

	if(data[spec_id] < points) then
		data[spec_id] = points;
		Debug:Log("Assigned spec data for player:", player.name, spec_id, points);
	end
end

-- Compute spec from existing specData
function ArenaTracker:ComputeSpec(player)
	local data = player.specData;
	if(not data) then
		Debug:Log("No spec data found for player:", player.name);
		return;
	end

	local bestSpec, bestPoints = nil, nil;
	for spec_id, points in pairs(data) do
		if(not bestSpec or bestSpec == 13 or not bestPoints or points > bestPoints) then
			bestSpec = spec_id;
			bestPoints = points;
		end
	end

	if(bestSpec ~= player.spec and Helpers:IsSpecID(bestSpec)) then
		Debug:Log("Updating player spec from:", player.spec, "to:", bestSpec, "for player:", player.name);
		player.spec = bestSpec;
	end
end


-- Assign explicit spec
function ArenaTracker:OnSpecDetected(playerID, spec_id)
	if(not playerID or not spec_id) then
		return;
	end

	local player = ArenaTracker:GetPlayer(playerID);
	if(not player) then
		return;
	end

	if(not Helpers:IsSpecID(player.spec) or player.spec == 13) then -- Preg doesn't count as a known spec
		Debug:Log("Assigning spec: ", spec_id, " for player: ", player.name);
		player.spec = spec_id;
	elseif(player.spec) then
		Debug:Log("Tracker: Keeping old spec:", player.spec, " for player: ", player.name);
	end
end
