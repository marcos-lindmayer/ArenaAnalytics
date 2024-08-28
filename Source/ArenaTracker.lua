local _, ArenaAnalytics = ... -- Namespace
local ArenaTracker = ArenaAnalytics.ArenaTracker;

-- Local module aliases
local AAmatch = ArenaAnalytics.AAmatch;
local Constants = ArenaAnalytics.Constants;
local SpecSpells = ArenaAnalytics.SpecSpells;
local API = ArenaAnalytics.API;

-------------------------------------------------------------------------

function ArenaTracker:getCurrentArena()
	return currentArena;
end

-- Arena variables
local currentArena = { }

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
	currentArena.partyRating = nil;
	currentArena.partyRatingDelta = nil;
	currentArena.partyMMR = nil;
	currentArena.enemyRating = nil;
	currentArena.enemyRatingDelta = nil;
	currentArena.enemyMMR = nil;
	currentArena.size = nil;
	currentArena.isRated = nil;
	currentArena.players = {};
	currentArena.party = {};
	currentArena.enemy = {};
	currentArena.ended = false;
	currentArena.endedProperly = false;
	currentArena.won = nil;
	currentArena.deathData = {};
end
ArenaTracker:ResetCurrentArenaValues();

function ArenaTracker:IsTrackingPlayer(name)
	for i = 1, #currentArena.players do
		local player = currentArena.players[i];
		if (player and player["name"] == name) then
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
	
	local status, mapName, instanceID, levelRangeMin, levelRangeMax, teamSize, isRated, suspendedQueue, bool, queueType = GetBattlefieldStatus(currentArena.battlefieldId);
	
	if (status ~= "active") then
		return false
	end

	currentArena.playerName = Helpers:GetPlayerName();
	currentArena.isRated = isRated;
	currentArena.size = teamSize;
	
	local bracketId = ArenaAnalytics:getBracketIdFromTeamSize(teamSize);
	if(isRated and ArenaAnalytics.cachedBracketRatings[bracketId] == nil) then
		local lastRating = ArenaAnalytics:GetLatestRating(teamSize);
		ArenaAnalytics:Log("Fallback: Updating cached rating to rating of last rated entry.");
		ArenaAnalytics.cachedBracketRatings[bracketId] = lastRating;
	end

	-- Add self
	if (not IsTrackingPlayer(currentArena.playerName)) then
		-- Add player
		local GUID = UnitGUID("player");
		local name = currentArena.playerName;
		local raceID = Helpers:GetUnitRace("player");
		local classID = Helpers:GetUnitClass("player");
		local spec_id = API:GetMySpec();

		local player = ArenaTracker:CreatePlayerTable("team", GUID, name, raceID, classID, spec_id);
		table.insert(currentArena.players, player);
	end

	if(ArenaAnalytics.DataSync) then
		ArenaAnalytics.DataSync:sendMatchGreetingMessage();
	end
	
	-- Not using mapName since string is lang based (unreliable) 
	currentArena.mapId = select(8,GetInstanceInfo())
	ArenaAnalytics:Log("Match entered! Tracking mapId: ", currentArena.mapId)

	RequestBattlefieldScoreData();

	-- Determine if a winner has already been determined.
	if(GetBattlefieldWinner() ~= nil) then
		ArenaAnalytics:Log("Started tracking after a team won. Calling HandleArenaEnd().")
		--ArenaTracker:HandleArenaEnd();
	end
end


-- Returns currently stored value by character name
-- Used to link existing spec and GUID info with players'
-- info from the UPDATE_BATTLEFIELD_SCORE event
function ArenaTracker:GetCollectedValue(valueKey, name)
	for i = 1, #currentArena.players do
		local player = currentArena.players
		if (player and player["name"] == name) then
			return player[valueKey];
		end
	end
	return nil;
end

--- TODO: Refactor this?
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

		-- Get spec and GUID from existing data, if available
		local spec_id = ArenaTracker:GetCollectedValue("spec", name);
		local raceID = ArenaTracker:GetCollectedValue("race", name);

		if(not raceID) then
			-- TODO: Implement this!
			-- Convert localized race to raceID
			raceID = Helpers:GetRaceIDFromLocalizedRace(race) or race;
		end

		-- Create complete player tables
		local player = ArenaTracker:CreatePlayerTable(nil, nil, name, raceID, classToken, spec_id, kills, deaths, damage, healing);
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

		currentArena.partyRating = tonumber(newPartyRating);
		currentArena.partyMMR = tonumber(partyMMR);
		currentArena.partyRatingDelta = abs(round(newPartyRating - oldPartyRating));
		
		currentArena.enemyRating = tonumber(newEnemyRating);
		currentArena.enemyMMR = tonumber(enemyMMR);
		currentArena.enemyRatingDelta = abs(round(newEnemyRating - oldEnemyRating));
	end

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

	local bracketId = ArenaAnalytics:getBracketIdFromTeamSize(currentArena.size);
	
	if(currentArena.isRated and not currentArena.partyRating) then
		local newRating = GetPersonalRatedInfo(bracketId);
		local oldRating = ArenaAnalytics.cachedBracketRatings[bracketId];
		ArenaAnalyticsDebugAssert(ArenaAnalytics.cachedBracketRatings[bracketId] ~= nil);
		
		if(oldRating == nil or oldRating == "SKIRMISH") then
			oldRating = ArenaAnalytics:GetLatestRating();
		end
		
		local deltaRating = newRating - oldRating;
		
		currentArena.partyRating = newRating;
		currentArena.partyRatingDelta = deltaRating;
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
			local name, realm = UnitNameUnmodified(unit .. i);
			
			if (name ~= nil and name ~= "Unknown") then
				if(realm == nil or realm == "") then
					_,realm = UnitFullName("player"); -- Local player's realm
				end

				local hasRealm = (realm and string.len(realm) > 2);
				realm = hasRealm and ("-"..realm) or "";
				name = name .. realm;
				
				-- Check if they were already added
				if (not ArenaTracker:IsTrackingPlayer(name)) then
					local GUID = UnitGUID(unit .. i);
					local team = (group == "party") and "team" or "enemy";
					local raceID = Helpers:GetUnitRace(unit .. i);
					local classID = Helpers:GetUnitClass(unit .. i);
					local spec_id = GUID and GUID == unitGuid and unitSpec or nil;
					local player = ArenaTracker:CreatePlayerTable(team, GUID, name, raceID, classIndex, spec_id);
					table.insert(currentArena.players, player);
				end
			end
		end
	end
end

-- Returns a table with unit information to be placed inside either arena.party or arena.enemy
function ArenaTracker:CreatePlayerTable(team, GUID, name, raceID, classIndex, spec_id, kills, deaths, damage, healing)
	return {
		["team"] = team,
		["GUID"] = GUID,
		["name"] = name,
		["race"] = raceID,
		["class"] = classIndex,
		["spec"] = spec_id,
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
		local timeSinceDeath = time() - existingData["time"];
		
		local minimumDelay = existingData["isHunter"] and 2 or 10;
		if(existingData["hasKillCredit"]) then
			minimumDelay = minimumDelay + 5;
		end
		
		if(timeSinceDeath > 0) then
			ArenaAnalytics:Log("Removed death by post-death action: ", spell, " for player: ",currentArena.deathData[playerGUID]["name"], " Time since death: ", timeSinceDeath);
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
		if(bestTime == nil or data["time"] < deathData[bestKey]["time"]) then
			bestKey = key;
			bestTime = data["time"];
		end
	end

	if(bestKey) then
		return deathData[bestKey] and deathData[bestKey]["name"] or nil;
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
		["isHunter"] = (class == "HUNTER") or nil;
		["hasKillCredit"] = isKillCredit or currentArena.deathData[playerGUID]["hasKillCredit"]
	}
end

-- Attempts to get initial data on arena players:
-- GUID, name, race, class, spec
function ArenaTracker:ProcessCombatLogEvent(eventType, ...)
	if (currentArena.size == nil) then
		if (IsActiveBattlefieldArena() and currentArena.battlefieldId ~= nil) then
			local _, _, _, _, _, teamSize = GetBattlefieldStatus(currentArena.battlefieldId);
			currentArena.size = teamSize;
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
	elseif (#currentArena.party < (currentArena.size * 2)) then
		ArenaTracker:FillMissingPlayers();
	end

	-- Look for missing party member or party member with missing spec. (Preg is considered uncertain)
	for i = 1, currentArena.size do
		local partyMember = currentArena.party[i];
		if(partyMember == nil) then
			return false;
		end

		local spec = partyMember["spec"]
		if (spec == nil or string.len(spec) < 3 or spec == "Preg") then
			return false;
		end
	end

	-- Look for missing enemy or enemy with missing spec. (Preg is considered uncertain)
	for i = 1, currentArena.size do
		local enemy = currentArena.enemy[i];
		if(enemy == nil) then
			return false;
		end

		local spec = enemy["spec"];
		if (spec == nil or string.len(spec) < 3 or spec == "Preg") then
			return false;
		end
	end
end

function ArenaTracker:AssignSpec(unit, newSpec)
	assert(unit and newSpec);

	local class, oldSpec = unit["class"], unit["spec"];

	if(oldSpec == newSpec) then 
		return;
	end

	if(oldSpec == nil or oldSpec == "Preg") then
		ArenaAnalytics:Log("Assigning spec: ", newSpec, " for unit: ", unit["name"]);
		unit["spec"] = newSpec;
	else
		ArenaAnalytics:Log("Tracker: Assigning spec is keeping old spec:", oldSpec, " for unit: ", unit["name"]);
	end
end

-- Detects spec if a spell is spec defining, attaches it to its
-- caster if they weren't defined yet, or adds a new unit with it
function ArenaTracker:DetectSpec(sourceGUID, spellID, spellName)
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
			if (player and player["GUID"] == sourceGUID) then
				-- Adding spec to party member
				ArenaTracker:AssignSpec(player, spec);
				return;
			end
		end

		-- Check if unit should be added
		ArenaTracker:FillMissingPlayers(sourceGUID, spec);
	end
end