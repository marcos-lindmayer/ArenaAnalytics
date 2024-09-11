local _, ArenaAnalytics = ... -- Namespace
local ArenaTracker = ArenaAnalytics.ArenaTracker;

-- Local module aliases
local AAmatch = ArenaAnalytics.AAmatch;
local Constants = ArenaAnalytics.Constants;
local SpecSpells = ArenaAnalytics.SpecSpells;
local API = ArenaAnalytics.API;
local Helpers = ArenaAnalytics.Helpers;
local Internal = ArenaAnalytics.Internal;
local Localization = ArenaAnalytics.Localization;

-------------------------------------------------------------------------

function ArenaTracker:getCurrentArena()
	return currentArena;
end

-- Arena variables
local currentArena = {}

-- Reset current arena values
function ArenaTracker:ResetCurrentArenaValues()
	ArenaAnalytics:Log("Resetting current arena values..");

	currentArena.battlefieldId = nil;
	currentArena.mapId = nil;
	
	currentArena.playerName = "";

	currentArena.duration = 0;
	currentArena.startTime = nil;
	currentArena.hasRealStartTime = nil;
	currentArena.endTime = 0;
	
	currentArena.oldRating = nil;
	currentArena.seasonPlayed = nil;
	currentArena.requireRatingFix = nil;

	currentArena.partyRating = nil;
	currentArena.partyRatingDelta = nil;
	currentArena.partyMMR = nil;
	
	currentArena.enemyRating = nil;
	currentArena.enemyRatingDelta = nil;
	currentArena.enemyMMR = nil;
	
	currentArena.size = nil;
	currentArena.isRated = nil;
	
	currentArena.players = {};
	
	currentArena.ended = false;
	currentArena.endedProperly = false;
	currentArena.won = nil;
	
	currentArena.deathData = {};
end
ArenaTracker:ResetCurrentArenaValues();

function ArenaTracker:IsTrackingPlayer(name)
	for i = 1, #currentArena.players do
		local player = currentArena.players[i];
		if (player and player.name == name) then
			return true;
		end
	end
	return false;
end

function ArenaTracker:IsTrackingArena()
	return currentArena.mapId ~= nil;
end

function ArenaTracker:GetArenaEndedProperly()
	return currentArena.endedProperly;
end

-- TEMP (?)
function ArenaTracker:SetNotEnded()
	currentArena.ended = false;
end

function ArenaTracker:HasMapData()
	return currentArena.mapId ~= nil;
end

-- Gates opened, match has officially started
function ArenaTracker:HandleArenaStart(...)
	currentArena.startTime = time();
	currentArena.hasRealStartTime = true; -- The start time has been set by gates opened

	ArenaAnalytics:Log("Match started!");
end

-- Begins capturing data for the current arena
-- Gets arena player, size, map, ranked/skirmish
function ArenaTracker:HandleArenaEnter(...)
	if(ArenaTracker:IsTrackingArena()) then
		return;
	end

	ArenaTracker:ResetCurrentArenaValues();

	-- Update start time immediately, might be overridden by gates open if it hasn't happened yet.
	currentArena.startTime = time();

	local battlefieldId = ...;
	currentArena.battlefieldId = battlefieldId or ArenaAnalytics:GetActiveBattlefieldID();

	if(not currentArena.battlefieldId) then
		ArenaAnalytics:Log("ERROR: Invalid Battlefield ID in HandleArenaEnter");
	end
	
	local status, _, _, _, _, teamSize, isRated = GetBattlefieldStatus(currentArena.battlefieldId);
	local status, mapName, instanceID, levelRangeMin, levelRangeMax, teamSize, isRated, suspendedQueue, bool, queueType = GetBattlefieldStatus(currentArena.battlefieldId);
	if (status ~= "active") then
		return false
	end

	currentArena.playerName = Helpers:GetPlayerName();
	currentArena.isRated = isRated;
	currentArena.size = teamSize;

	if(C_PvP and C_PvP.IsSoloShuffle) then
		currentArena.isShuffle = C_PvP.IsSoloShuffle() or nil;
	end

	ArenaTracker:UpdateBracket();

	if(isRated) then
		local oldRating, seasonPlayed = API:GetPersonalRatedInfo(currentArena.bracketIndex);
		if(GetBattlefieldWinner()) then
			-- Get last rating, since we already found the winner here.
			local season = GetCurrentArenaSeason();
			currentArena.oldRating = ArenaAnalytics:GetLatestRating(currentArena.bracketIndex, season, (seasonPlayed and seasonPlayed - 1));
			currentArena.seasonPlayed = seasonPlayed;
		else
			currentArena.oldRating = oldRating;
			currentArena.seasonPlayed = seasonPlayed and seasonPlayed + 1 or nil;  -- Season played after winner is determined
		end

		ArenaAnalytics:Log("Entered Arena:", currentArena.oldRating, currentArena.seasonPlayed);
	end

	if(isRated and tonumber(currentArena.bracketIndex)) then
		if(not ArenaAnalytics:GetCachedRating(currentArena.bracketIndex)) then
			local lastRating = ArenaAnalytics:GetLatestRating(currentArena.bracketIndex);
			ArenaAnalytics:Log("Fallback: Updating cached rating to rating of last rated entry.", lastRating);
			ArenaAnalytics.cachedBracketRatings[currentArena.bracketIndex] = lastRating;
		end
	end

	-- Add self
	if (not ArenaTracker:IsTrackingPlayer(currentArena.playerName)) then
		-- Add player
		local GUID = UnitGUID("player");
		local name = currentArena.playerName;
		local race_id = Helpers:GetUnitRace("player");
		local class_id = Helpers:GetUnitClass("player");
		local spec_id = API:GetMySpec() or class_id;

		local player = ArenaTracker:CreatePlayerTable(false, GUID, name, race_id, spec_id);
		table.insert(currentArena.players, player);
	end

	if(ArenaAnalytics.DataSync) then
		ArenaAnalytics.DataSync:sendMatchGreetingMessage();
	end

	currentArena.mapId = select(8,GetInstanceInfo())
	ArenaAnalytics:Log("Match entered! Tracking mapId: ", currentArena.mapId);

	RequestBattlefieldScoreData();
end

-- Returns currently stored value by character name
-- Used to link existing spec and GUID info with players'
-- info from the UPDATE_BATTLEFIELD_SCORE event
function ArenaTracker:GetCollectedValue(valueKey, name)
	for i = 1, #currentArena.players do
		local player = currentArena.players[i];
		if (player and player.name == name) then
			return player[valueKey];
		end
	end
	return nil;
end

-- Gets arena information when it ends and the scoreboard is shown
-- Matches obtained info with previously collected player values
function ArenaTracker:HandleArenaEnd()
	currentArena.endedProperly = true;
	currentArena.ended = true;
	local winner = GetBattlefieldWinner();

	local players = {};

	-- Figure out how to default to nil, without failing to count losses.
	local myTeamIndex = nil;

	local numScores = GetNumBattlefieldScores();
	for i=1, numScores do
		-- TODO: Find a way to convert race to raceID securely for any localization!
		local name, kills, _, deaths, _, teamIndex, _, race, _, classToken, damage, healing = GetBattlefieldScore(i);
		if(not name:find("-")) then
			_,realm = UnitFullName("player"); -- Local player's realm
			name = name.."-"..realm;
		end

		ArenaAnalytics:Log("Scoreboard race:", race);

		-- Get class_id from clasToken
		local class_id = Internal:GetAddonClassID(classToken);

		-- Get spec and GUID from existing data, if available
		local spec_id = ArenaTracker:GetCollectedValue("spec", name);
		local race_id = ArenaTracker:GetCollectedValue("race", name);

		if(not tonumber(race_id)) then
			-- Convert localized race to raceID
			race_id = Localization:GetRaceID(race);
		end

		-- Create complete player tables
		local player = ArenaTracker:CreatePlayerTable(nil, nil, name, race_id, (spec_id or class_id), kills, deaths, damage, healing);
		player.teamIndex = teamIndex;

		if (name == currentArena.playerName) then
			myTeamIndex = teamIndex;
		elseif(currentArena.isShuffle) then
			player.isEnemy = true;
		end

		table.insert(players, player);
	end

	-- Assign isEnemy value
	if(not currentArena.isShuffle) then
		for _,player in ipairs(players) do
			if(player and player.teamIndex) then
				player.isEnemy = (player.teamIndex ~= myTeamIndex);
			end
		end
	end

	-- Assign Winner
	ArenaAnalytics:Log("My faction: ", myTeamIndex, "(Winner:", winner,")")
	if(winner ~= nil and winner ~= 255) then
		currentArena.won = (myTeamIndex == winner);
	end

	-- Process ranked information
	if (currentArena.isRated and myTeamIndex) then
		local otherTeamIndex = (myTeamIndex == 0) and 1 or 0;

		local _, oldPartyRating, newPartyRating, partyMMR = GetBattlefieldTeamInfo(myTeamIndex);
		local _, oldEnemyRating, newEnemyRating, enemyMMR = GetBattlefieldTeamInfo(otherTeamIndex);

		--currentArena.partyRating = tonumber(newPartyRating);
		--currentArena.partyRatingDelta = abs(Round(newPartyRating - oldPartyRating));
		currentArena.partyMMR = tonumber(partyMMR);

		--currentArena.enemyRating = tonumber(newEnemyRating);
		--currentArena.enemyRatingDelta = abs(Round(newEnemyRating - oldEnemyRating));
		currentArena.enemyMMR = tonumber(enemyMMR);
	end

	currentArena.players = players;

	ArenaAnalytics:Log("Match ended!");
end

-- Player left an arena (Zone changed to non-arena with valid arena data)
function ArenaTracker:HandleArenaExit()
	assert(currentArena.size);
	assert(currentArena.mapId);

	if(not currentArena.endedProperly) then
		currentArena.ended = true;
		currentArena.won = false;

		ArenaAnalytics:Log("Detected early leave. Has valid current arena: ", currentArena.mapId);
	end

	ArenaAnalytics:Log("Exited Arena:", API:GetPersonalRatedInfo(currentArena.bracketIndex));

	if(currentArena.isRated and not currentArena.partyRating) then
		local newRating, seasonPlayed = API:GetPersonalRatedInfo(currentArena.bracketIndex);
		if(newRating and seasonPlayed) then
			local oldRating = currentArena.oldRating;
			if(not oldRating) then
				local season = GetCurrentArenaSeason() or 0;
				oldRating = ArenaAnalytics:GetLatestRating(currentArena.bracketIndex, season, (seasonPlayed - 1));
			end

			currentArena.partyRating = newRating;
			currentArena.partyRatingDelta = oldRating and newRating - oldRating or nil;
		else
			ArenaAnalytics:Log("Warning: Nil current rating retrieved from API upon leaving arena.");
		end

		if(currentArena.seasonPlayed) then
			if(seasonPlayed and seasonPlayed < currentArena.seasonPlayed) then
				-- Rating has updated, no longer needed to store transient Season Played for fixup.
				currentArena.requireRatingFix = true;
			else
				ArenaAnalytics:Log("Tracker: Invalid season played or already up to date.", seasonPlayed, currentArena.seasonPlayed);
			end
		else
			ArenaAnalytics:Log("Tracker: No season played stored on currentArena");
		end
	end

	-- Update all the cached bracket ratings
	AAmatch:updateCachedBracketRatings();

	ArenaAnalytics:InsertArenaToMatchHistory(currentArena);
end

-- Search for missing members of group (party or arena), 
-- Adds each non-tracked player to currentArena.players table.
-- If spec and GUID are passed, include them when creating the player table
function ArenaTracker:FillMissingPlayers(unitGUID, unitSpec)
	local groups = {"party", "arena"};
	for _,group in ipairs(groups) do
		for i = 1, currentArena.size do
			local name, realm = UnitNameUnmodified(group .. i);

			if (name ~= nil and name ~= "Unknown") then
				if(realm == nil or realm == "") then
					_,realm = UnitFullName("player"); -- Local player's realm
				end

				local hasRealm = (realm and string.len(realm) > 2);
				realm = hasRealm and ("-"..realm) or "";
				name = name .. realm;

				-- Check if they were already added
				if (not ArenaTracker:IsTrackingPlayer(name)) then
					local GUID = UnitGUID(group .. i);
					local isEnemy = (group ~= "party");
					local race_id = Helpers:GetUnitRace(group .. i);
					local class_id = Helpers:GetUnitClass(group .. i);
					local spec_id = GUID and GUID == unitGuid and unitSpec or class_id;
					local player = ArenaTracker:CreatePlayerTable(isEnemy, GUID, name, race_id, spec_id);
					table.insert(currentArena.players, player);
				end
			end
		end
	end
end

-- Returns a table with unit information to be placed inside arena.players
function ArenaTracker:CreatePlayerTable(isEnemy, GUID, name, race_id, spec_id, kills, deaths, damage, healing)
	return {
		["isEnemy"] = isEnemy,
		["GUID"] = GUID,
		["name"] = name,
		["race"] = race_id,
		["spec"] = spec_id,
		["role"] = Internal:GetRoleBitmap(spec_id),
		["kills"] = kills,
		["deaths"] = deaths,
		["damage"] = damage,
		["healing"] = healing,
	};
end

-- Called from unit actions, to remove false deaths
local function tryRemoveFromDeaths(playerGUID, spell)
	local existingData = currentArena.deathData[playerGUID];
	if(existingData ~= nil) then
		local timeSinceDeath = time() - existingData.time;

		local minimumDelay = existingData.isHunter and 2 or 10;
		if(existingData.hasKillCredit) then
			minimumDelay = minimumDelay + 5;
		end

		if(timeSinceDeath > 0) then
			ArenaAnalytics:Log("Removed death by post-death action: ", spell, " for player: ",currentArena.deathData[playerGUID].name, " Time since death: ", timeSinceDeath);
			currentArena.deathData[playerGUID] = nil;
		end
	end
end

-- Fetch the real first death when saving the match
function ArenaTracker:GetFirstDeathFromCurrentArena()
	local deathData = currentArena.deathData;
	if(deathData == nil or not next(deathData)) then
		ArenaAnalytics:Log("Death data missing from currentArena.");
		return;
	end

	local bestKey, bestTime;
	for key,data in pairs(deathData) do
		if(bestTime == nil or data.time < deathData[bestKey].time) then
			bestKey = key;
			bestTime = data.time;
		end
	end

	if(bestKey) then
		return deathData[bestKey] and deathData[bestKey].name or nil;
	end
end

-- Handle a player's death, through death or kill credit message
local function handlePlayerDeath(playerGUID, isKillCredit)
	if(playerGUID == nil) then
		return;
	end

	currentArena.deathData[playerGUID] = currentArena.deathData[playerGUID] or {}

	local _, class, _, _, _, playerName, realm = GetPlayerInfoByGUID(playerGUID);
	if(playerName and playerName ~= "Unknown") then
		if(realm == nil or realm == "" or realm == "Unknown") then
			_,realm = UnitFullName("player"); -- Local player's realm
		end

		if(playerName and realm) then
			playerName = playerName .. "-" .. realm;
		end
	end

	-- Store death
	currentArena.deathData[playerGUID] = {
		["time"] = time(), 
		["GUID"] = playerGUID,
		["name"] = playerName,
		["isHunter"] = (class == "HUNTER") or nil,
		["hasKillCredit"] = isKillCredit or currentArena.deathData[playerGUID].hasKillCredit,
	}
end

function ArenaTracker:UpdateBracket()
	if(currentArena.size) then
		local bracket = nil;
		if(currentArena.isShuffle) then
			bracket = "shuffle";
		elseif(currentArena.size == 2) then
			bracket = "2v2";
		elseif(currentArena.size == 3) then
			bracket = "3v3";
		elseif(currentArena.size == 5) then
			bracket = "5v5";
		else
			ArenaAnalytics:Log("Tracker: Failed to determine bracket!", currentArena.size);
		end

		ArenaAnalytics:Log("Setting bracket:", bracket);
		currentArena.bracketIndex = ArenaAnalytics:GetAddonBracketIndex(bracket);
	end
end

-- Attempts to get initial data on arena players:
-- GUID, name, race, class, spec
function ArenaTracker:ProcessCombatLogEvent(eventType, ...)
	if (currentArena.size == nil) then
		if (IsActiveBattlefieldArena() and currentArena.battlefieldId ~= nil) then
			local _, _, _, _, _, teamSize = GetBattlefieldStatus(currentArena.battlefieldId);
			currentArena.size = teamSize;

			ArenaTracker:UpdateBracket();
		else
			return false;
		end
	end

	-- Tracking teams for spec/race and in case arena is quitted
	if (eventType == "COMBAT_LOG_EVENT_UNFILTERED") then
		local _,logEventType,_,sourceGUID,_,_,_,destGUID,_,_,_,spellID,spellName,spellSchool,extraSpellId,extraSpellName,extraSpellSchool = CombatLogGetCurrentEventInfo();
		if (logEventType == "SPELL_CAST_SUCCESS") then
			ArenaTracker:DetectSpec(sourceGUID, spellID, spellName);
			tryRemoveFromDeaths(sourceGUID, spellName);
		end

		if(logEventType == "SPELL_AURA_APPLIED") then
			ArenaTracker:DetectSpec(sourceGUID, spellID, spellName);
		end

		if(destGUID and destGUID:find("Player")) then
			-- Player Death
			if (logEventType == "UNIT_DIED") then
				handlePlayerDeath(destGUID, false);
			end
			-- Player killed
			if (logEventType == "PARTY_KILL") then
				handlePlayerDeath(destGUID, true);
				ArenaAnalytics:Log("Party Kill!");
			end
		end
	elseif (#currentArena.players < (currentArena.size * 2)) then
		ArenaTracker:FillMissingPlayers();
	end

	-- Look for missing party member or party member with missing spec. (Preg is considered uncertain)
	for i = 1, #currentArena.players do
		local partyMember = currentArena.players[i];
		if(partyMember) then
			local spec = partyMember.spec;
			if (spec == nil or spec == 13) then -- (13 = Preg)
				return false;
			end
		end
	end
end

function ArenaTracker:AssignSpec(unit, newSpec)
	assert(unit and newSpec);

	local class, oldSpec = unit.class, unit.spec;

	if(oldSpec == newSpec) then
		return;
	end

	ArenaAnalytics:Log(oldSpec, newSpec)
	if(oldSpec == nil or oldSpec == 13 or Helpers:IsClassID(oldSpec)) then
		ArenaAnalytics:Log("Assigning spec: ", newSpec, " for unit: ", unit.name);
		unit.spec = newSpec;
	else
		ArenaAnalytics:Log("Tracker: Assigning spec is keeping old spec:", oldSpec, " for unit: ", unit.name);
	end
end

-- Detects spec if a spell is spec defining, attaches it to its
-- caster if they weren't defined yet, or adds a new unit with it
function ArenaTracker:DetectSpec(sourceGUID, spellID, spellName)
	if(not SpecSpells or not SpecSpells.GetSpec) then
		return;
	end

	-- Only players matter for spec detection
	if (not string.find(sourceGUID, "Player-")) then
		return;
	end

	-- Check if spell belongs to spec defining spells
	local spec, shouldDebug = SpecSpells:GetSpec(spellID);
	if(shouldDebug ~= nil) then
		ArenaAnalytics:Log("DEBUG ID Detected spec: ", sourceGUID, spellID, spellName);
	end

	if (spec ~= nil) then
		-- Check if spell was casted by party
		for i = 1, #currentArena.players do
			local player = currentArena.players[i];
			if (player and player.GUID == sourceGUID) then
				-- Adding spec to party member
				ArenaTracker:AssignSpec(player, spec);
				return;
			end
		end

		-- Check if unit should be added
		ArenaTracker:FillMissingPlayers(sourceGUID, spec);
	end
end