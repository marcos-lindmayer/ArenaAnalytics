local _, ArenaAnalytics = ...; -- Namespace
ArenaAnalytics.AAmatch = {};

local AAmatch = ArenaAnalytics.AAmatch;

-- Character SavedVariables match history
MatchHistoryDB = MatchHistoryDB or { }

ArenaAnalytics.unsavedArenaCount = 0;

-- TODO: Consider making the settings character specific (For cases like one char having lots of games desiring different comp filter limits)
-- User settings
ArenaAnalyticsSettings = ArenaAnalyticsSettings and ArenaAnalyticsSettings or {};

function ArenaAnalyticsLoadSettings()
	ArenaAnalyticsSettings["outliers"] = ArenaAnalyticsSettings["outliers"] or 0;
	ArenaAnalyticsSettings["compsLimit"] = ArenaAnalyticsSettings["compsLimit"] or 0;
	ArenaAnalyticsSettings["seasonIsChecked"] = ArenaAnalyticsSettings["seasonIsChecked"] or false;
	ArenaAnalyticsSettings["skirmishIshChecked"] = ArenaAnalyticsSettings["skirmishIshChecked"] or false;
	ArenaAnalyticsSettings["sessionOnly"] = false; -- Treat as an unsaved filter for now
	ArenaAnalyticsSettings["alwaysShowDeathBg"] = ArenaAnalyticsSettings["alwaysShowDeathBg"] or false;
	ArenaAnalyticsSettings["unsavedWarningThreshold"] = ArenaAnalyticsSettings["unsavedWarningThreshold"] or 13;
	ArenaAnalyticsSettings["sortCompFilterByTotalPlayed"] = ArenaAnalyticsSettings["sortCompFilterByTotalPlayed"] or true;
	ArenaAnalyticsSettings["selectionControlModInversed"] = ArenaAnalyticsSettings["selectionControlModInversed"] or true;
end

ArenaAnalyticsCharacterSettings = ArenaAnalyticsCharacterSettings and ArenaAnalyticsCharacterSettings or {
	-- Character specific settings
}

local eventFrame = CreateFrame("Frame");
local arenaEventFrame = CreateFrame("Frame");
local eventTracker = {
	["UPDATE_BATTLEFIELD_STATUS"] = false, 
	["ZONE_CHANGED_NEW_AREA"] = false, 
	["CHAT_MSG_ADDON"] = false,
	["ArenaEvents"] = {
		["UPDATE_BATTLEFIELD_SCORE"] = false, 
		["UNIT_AURA"] = false, 
		["CHAT_MSG_BG_SYSTEM_NEUTRAL"] = false, 
		["COMBAT_LOG_EVENT_UNFILTERED"] = false,
		["ARENA_OPPONENT_UPDATE"] = false
	},
	["ArenaEventsAdded"] = false
}

-- Arena variables
local currentArena = {
	["battlefieldId"] = nil,
	["mapName"] = "", 
	["mapId"] = nil, 
	["playerName"] = "",
	["duration"] = nil, 
	["timeStartInt"] = 0,
	["timeEnd"] = 0, 
	["partyRating"] = nil,
	["partyRatingDelta"] = "",
	["partyMMR"] = nil, 
	["enemyRating"] = nil,
	["enemyRatingDelta"] = "",
	["enemyMMR"] = nil,
	["size"] = nil,
	["isRated"] = nil,
	["playerTeam"] = nil,
	["comp"] = {},
	["enemyComp"] = {},
	["party"] = {},
	["enemy"] = {},
	["gotAllArenaInfo"] = false,
	["ended"] = false,
	["endedProperly"] = false,
	["wonByPlayer"] = nil,
	["firstDeath"] = nil
}

-- Reset current arena values
function AAmatch:resetCurrentArenaValues()
	currentArena["battlefieldId"] = nil;
	currentArena["mapName"] = "";
	currentArena["mapId"] = nil;
	currentArena["playerName"] = "";
	currentArena["duration"] = nil;
	currentArena["timeStartInt"] = 0;
	currentArena["timeEnd"] = 0;
	currentArena["partyRating"] = nil;
	currentArena["partyRatingDelta"] = "";
	currentArena["partyMMR"] = nil;
	currentArena["enemyRating"] = nil;
	currentArena["enemyRatingDelta"] = "";
	currentArena["enemyMMR"] = nil;
	currentArena["size"] = nil;
	currentArena["isRated"] = nil;
	currentArena["playerTeam"] = nil;
	currentArena["comp"] = {};
	currentArena["enemyComp"] = {};
	currentArena["party"] = {};
	currentArena["enemy"] = {};
	currentArena["gotAllArenaInfo"] = false;
	currentArena["ended"] = false;
	currentArena["endedProperly"] = false;
	currentArena["wonByPlayer"] = nil;
	currentArena["firstDeath"] = nil;
end

function AAmatch:getCurrentArena()
	return currentArena;
end

function ArenaAnalytics:recomputeSessionsForMatchHistoryDB()
	-- Assign session to filtered matches
	local session = 1
	for i = 1, #MatchHistoryDB do
		local current = MatchHistoryDB[i];
		local prev = MatchHistoryDB[i - 1];

		if(prev and not ArenaAnalytics:isMatchesSameSession(prev, current)) then
			session = session + 1;
		end

		current["session"] = session;
	end
end

-- Arena DB
ArenaAnalyticsDB = ArenaAnalyticsDB ~= nil and ArenaAnalyticsDB or {
	["2v2"] = {},
	["3v3"] = {},
	["5v5"] = {},
};

function ArenaAnalytics:hasStoredMatches()
	return (MatchHistoryDB ~= nil and #MatchHistoryDB > 0);
end

-- Check if 2 arenas are in the same session
function ArenaAnalytics:isMatchesSameSession(first, second)
	if(not first or not second) then
		return false;
	end

	if(second["date"] - first["date"] > 3600) then
		return false;
	end
	
	if(not ArenaAnalytics:arenasHaveSameParty(first, second)) then
		return false;
	end

	-- TODO: Add skirm diff to filter logic?

	return true;
end

-- Checks if 2 arenas have the same party members
function ArenaAnalytics:arenasHaveSameParty(arena1, arena2)
    if(arena1["bracket"] ~= arena2["bracket"]) then
        return false;
    end

    if(arena1 == nil or arena2 == nil or arena1["team"] == nil or arena2["team"] == nil) then
        return false;
    end

    if(#arena1["team"] ~= #arena2["team"]) then
        return false;
    end

    for i = 1, #arena1["team"] do
        if (arena2["team"][i] and arena1["team"][i]["name"] ~= arena2["team"][i]["name"]) then
            return false;
        end
    end

    return true;
end

-- Returns the session for a given match index
function ArenaAnalytics:getMatchSessionByIndex(matchIndex)
	local match = MatchHistoryDB[matchIndex];
	if (match) then
		return tonumber(match["session"]);
	end
	return nil;
end

-- Returns the whether last session and whether it has expired by time
function ArenaAnalytics:getLastSession()
	for i=#MatchHistoryDB, 1, -1 do
		local match = MatchHistoryDB[i];
		if(match and tonumber(match["session"])) then
			local session = match["session"];
			local expired = (time() - match["date"]) > 3600;
			return session, expired;
		end
	end
	return 1, false;
end

-- Returns the start and end times of the last session
function ArenaAnalytics:getLastSessionStartAndEndTime()
	local lastSession, expired, bestStartTime, endTime;

	for i=#MatchHistoryDB, 1, -1 do
		local match = MatchHistoryDB[i];
		if(match and tonumber(match["session"])) then
			if(lastSession == nil) then
				lastSession = tonumber(match["session"]);
				expired = (time() - match["date"]) > 3600;
				endTime = expired and match["date"] or time();
			end
			ForceDebugNilError(lastSession, true);
						
			if(lastSession == tonumber(match["session"])) then
				bestStartTime = match["date"] - match["duration"];
			else
				break;
			end
		end
	end

	return lastSession, expired, bestStartTime, endTime;
end

-- Returns last saved rating on selected bracket (teamSize)
function ArenaAnalytics:getLastSeason()
	for i = #MatchHistoryDB, 1, -1 do
		local match = MatchHistoryDB[i];
		if(match ~= nil and match["season"] and match["season"] ~= 0) then
			return tonumber(match["season"]);
		end
	end

	return 0;
end

-- Returns last saved rating on selected bracket (teamSize)
function ArenaAnalytics:getLastRating(teamSize)
	local bracket = ArenaAnalytics:getBracketFromTeamSize(teamSize);

	for i = #MatchHistoryDB, 1, -1 do
		local match = MatchHistoryDB[i];
		if(match ~= nil and match["bracket"] == bracket and match["rating"] ~= "SKIRMISH") then
			return tonumber(match["rating"]);
		end
	end

	return 0;
end

-- Cached last rating per bracket ID
ArenaAnalyticsCachedBracketRatings = ArenaAnalyticsCachedBracketRatings ~= nil and ArenaAnalyticsCachedBracketRatings or {
	[1] = nil,
	[2] = nil,
	[3] = nil,
}

-- Updates the cached bracket rating for each bracket
function AAmatch:updateCachedBracketRatings()
	if(IsActiveBattlefieldArena()) then
		ArenaAnalyticsCachedBracketRatings[1] = ArenaAnalytics:getLastRating(2); -- 2v2
		ArenaAnalyticsCachedBracketRatings[2] = ArenaAnalytics:getLastRating(3); -- 3v3
		ArenaAnalyticsCachedBracketRatings[3] = ArenaAnalytics:getLastRating(4); -- 5v5
	else
		ArenaAnalyticsCachedBracketRatings[1] = GetPersonalRatedInfo(1); -- 2v2
		ArenaAnalyticsCachedBracketRatings[2] = GetPersonalRatedInfo(2); -- 3v3
		ArenaAnalyticsCachedBracketRatings[3] = GetPersonalRatedInfo(3); -- 5v5
	end
end

-- Returns a table with unit information to be placed inside either arena["party"] or arena["enemy"]
function AAmatch:createPlayerTable(GUID, name, deaths, faction, race, class, filename, damageDone, healingDone, spec)
	local classIcon = ArenaAnalyticsGetClassIcon(class)
	local playerTable = {
		["GUID"] = GUID,
		["name"] = name,
		["killingBlows"] = killingBlows,
		["deaths"] = deaths,
		["race"] = race,
		["faction"] = ArenaAnalytics.Constants:GetFactionByRace(race),
		["class"] = class,
		["damageDone"] = damageDone,
		["healingDone"] = healingDone,
		["spec"] = spec or nil
	};
	return playerTable;
end

-- Returns a table with the selected arena's player comp
function AAmatch:getArenaComp(teamTable, bracket)
	local size = ArenaAnalytics:getTeamSizeFromBracket(bracket);
	
	if(teamTable == nil or size > #teamTable) then
		return nil;
	end

	local newComp = {}
	for i=1, size do
		local player = teamTable[i];

		-- No comp with missing player
		if(player == nil) then
			return nil;
		end

		local class, spec = player["class"], player["spec"];
		if(not class or #class < 3 or not spec or #spec < 3) then
			return nil;
		end

		local specID = ArenaAnalytics.Constants:getAddonSpecializationID(player["class"] .. "|" .. player["spec"]);
		if(specID == nil) then
			return nil;
		end

		table.insert(newComp, specID);
	end

	table.sort(newComp, function(a, b)
		return a < b;
	end);

	return table.concat(newComp, '|');
end

-- Calculates arena duration, turns arena data into friendly strings, adds it to MatchHistoryDB
-- and triggers a layout refresh on ArenaAnalytics.arenaTable
function AAmatch:insertArenaOnTable()
	-- Calculate arena duration
	if (currentArena["timeStartInt"] == 0) then
		currentArena["duration"] = 0;
	else
		currentArena["timeEnd"] = time();
		local duration = (currentArena["timeEnd"] - currentArena["timeStartInt"]);
		duration = duration < 0 and 0 or duration;
		currentArena["duration"] = duration;
	end

	-- Set data for skirmish
	if (currentArena["isRated"] == false) then
		currentArena["partyRating"] = "SKIRMISH";
		currentArena["partyMMR"] = "-";
		currentArena["partyRatingDelta"] = "";
		currentArena["enemyRating"] = "-";
		currentArena["enemyRatingDelta"] = "";
		currentArena["enemyMMR"] = "-";
	end

	-- Place player first in the arena party group, sort rest 
	table.sort(currentArena["party"], function(a, b)
		local prioA = a["name"] == currentArena["playerName"] and 1 or 2
		local prioB = b["name"] == currentArena["playerName"] and 1 or 2
		local sameClass = a["class"] == b["class"]
		return prioA < prioB or (prioA == prioB and a["class"] < b["class"]) or (prioA == prioB and sameClass and a["name"] < b["name"])
	end);

	--Sort arena["enemy"]
	table.sort(currentArena["enemy"], function(a, b)
		local sameClass = a["class"] == b["class"]
		return (sameClass and a["name"] < b["name"]) or a["class"] < b["class"]
	end);

	-- Get arena comp for each team
	local bracket = ArenaAnalytics:getBracketFromTeamSize(currentArena["size"]);
	currentArena["comp"] = AAmatch:getArenaComp(currentArena["party"], bracket);
	currentArena["enemyComp"] = AAmatch:getArenaComp(currentArena["enemy"], bracket);

	local name, realm = UnitFullName("player");
	if(name and realm) then
		name = name .. "-" .. realm;
	end
	arenaData = name or nil;

	local season = GetCurrentArenaSeason();
	if (season == 0) then
		ArenaAnalytics:Log("Failed to get valid season for new match.");
	end

	-- Setup table data to insert into MatchHistoryDB
	local arenaData = {
		["player"] = name,
		["isRated"] = currentArena["isRated"],
		["date"] = tonumber(currentArena["timeStartInt"]) or time(),
		["season"] = season,
		["session"] = session,
		["map"] = currentArena["mapName"], 
		["bracket"] = bracket,
		["duration"] = currentArena["duration"],
		["team"] = currentArena["party"],
		["rating"] = tonumber(currentArena["partyRating"]), 
		["ratingDelta"] = tonumber(currentArena["partyRatingDelta"]),
		["mmr"] = tonumber(currentArena["partyMMR"]), 
		["enemyTeam"] = currentArena["enemy"], 
		["enemyRating"] = tonumber(currentArena["enemyRating"]), 
		["enemyRatingDelta"] = tonumber(currentArena["enemyRatingDelta"]),
		["enemyMmr"] = tonumber(currentArena["enemyMMR"]),
		["comp"] = currentArena["comp"],
		["enemyComp"] = currentArena["enemyComp"],
		["won"] = currentArena["wonByPlayer"],
		["firstDeath"] = currentArena["firstDeath"]
	}

	-- Assign session
	local session = ArenaAnalytics:getLastSession();
	local lastMatch = MatchHistoryDB[#MatchHistoryDB];
	if (not ArenaAnalytics:isMatchesSameSession(lastMatch, arenaData)) then
		session = session + 1;
	end
	arenaData["session"] = session;
	ArenaAnalytics.lastSession = session;

	-- Insert arena data as a new MatchHistoryDB entry
	table.insert(MatchHistoryDB, arenaData);
	ArenaAnalytics.unsavedArenaCount = ArenaAnalytics.unsavedArenaCount + 1;

	ArenaAnalytics:Print("Arena recorded!");
	
	-- Refresh and reset current arena
	AAmatch:resetCurrentArenaValues();
	
	ArenaAnalytics.Filter:refreshFilters();

	ArenaAnalytics.AAtable:tryStartSessionDurationTimer();
end

-- Returns bool for input group containing a character (by name) in it
function AAmatch:doesGroupContainMemberByName(currentGroup, name)
	for i = 1, #currentGroup do
		if (currentGroup[i]["name"] == name) then
			return true
		end
	end
	return false;
end

-- Search for missing members of group (party or arena), createsPlayerTable if 
-- it exist and inserts it in either currentArena["party"] or currentArena["enemy"]. If spec and GUID
-- are passed, include them when creating the player table
function AAmatch:fillGroupsByUnitReference(unitGroup, unitGuid, unitSpec)
	unitGroup = unitGroup == "party" and "party" or "arena";
	
	initialValue = unitGroup == "party" and  0 or 1;
	for i = initialValue, currentArena["size"] do
		local name, realm = UnitName(unitGroup .. i);
		
		if (name ~= nil and name ~= "Unknown") then
			if(realm == nil or realm == "") then
				_,realm = UnitFullName("player"); -- Local player's realm
			end

			if ( realm == nil or string.len(realm) < 4) then
				realm = "";
			else
				realm = "-" .. realm;
			end
			name = name .. realm;
			
			-- Check if they were already added
			local currentGroup = (unitGroup == "party") and currentArena["party"] or currentArena["enemy"];
			if (not AAmatch:doesGroupContainMemberByName(currentGroup, name)) then
				local killingBlows, deaths, faction, filename, damageDone, healingDone;
				local class = UnitClass(unitGroup .. i);
				local race = UnitRace(unitGroup .. i);
				local GUID = UnitGUID(unitGroup .. i);
				local spec = GUID == unitGuid and unitSpec or nil;
				local player = AAmatch:createPlayerTable(GUID, name, deaths, faction, race, class, filename, damageDone, healingDone, spec);
				table.insert(currentGroup, player);
			end
		end
	end
end

-- Detects spec if a spell is spec defining, attaches it to its
-- caster if they weren't defined yet, or adds a new unit with it
function AAmatch:detectSpec(sourceGUID, spellID, spellName)
	-- Check if spell belongs to spec defining spells
	local spec = ArenaAnalytics.SpecSpells:GetSpec(spellID);
	if (spec ~= nil) then
		local unitIsParty = false;
		local unitIsEnemy = false;
		-- Check if spell was casted by party
		for i = 1, #currentArena["party"] do
			local unit = currentArena["party"][i];
			if (unit["GUID"] == sourceGUID ) then
				-- Adding spec to party member
				unit["spec"] = AAmatch:assignSpec(unit["class"], unit["spec"], spec);
				unitIsParty = true;
				break;
			end
		end
		-- Check if spell was casted by enemy
		if (not unitIsParty) then
			for i = 1, #currentArena["enemy"] do
				local unit = currentArena["enemy"][i];
				if (unit["GUID"] == sourceGUID ) then
					-- Adding spec to enemy member
					unit["spec"] = AAmatch:assignSpec(unit["class"], unit["spec"], spec);
					unitIsEnemy = true;
					break;
				end
			end
		end
		-- Check if unit should be added
		if (unitIsEnemy == false and unitIsParty == false and string.find(sourceGUID, "Player-")) then
			--Determine arena group
			local unitGroup;
			for i = 1, currentArena["size"] do
				if (UnitGUID("party" .. i) == sourceGUID) then
					unitGroup = "party";
				end
			end
			if (unitGroup == nil) then
				unitGroup = "arena";
			end
			ArenaAnalytics:Log("Adding unit with spec: ", spec)
			AAmatch:fillGroupsByUnitReference(unitGroup, sourceGUID, spec);
		end
	end
end

function AAmatch:assignSpec(class, oldSpec, newSpec)
	if(oldSpec == newSpec) then 
		return oldSpec 
	end

	-- TODO: Fixup data for a standardized format of missing specs
	if(oldSpec == nil or oldSpec == "" or oldSpec == "-" or oldSpec == "?" or oldSpec == "Preg") then
		ArenaAnalytics:Log("Assigning spec: ", newSpec);
		return newSpec;
	end

	ArenaAnalytics:Log("Keeping spec: ", oldSpec);
	return oldSpec;
end

-- Returns bool whether all obtainable information (before arena ends) has
-- been collected. Attempts to get initial data on arena players:
-- GUID, name, race, class, spec
function AAmatch:getAllAvailableInfo(eventType, ...)
	-- Start tracking time again in case of disconnect
	if (currentArena["timeStartInt"] == 0) then
		currentArena["timeStartInt"] = time();
	end

	if (currentArena["size"] == nil) then
		if (IsActiveBattlefieldArena() and currentArena["battlefieldId"] ~= nil) then
			local _, _, _, _, _, teamSize = GetBattlefieldStatus(currentArena["battlefieldId"]);
			currentArena["size"] = teamSize;
		else
			return false;
		end
	end

	-- Tracking teams for spec/race and in case arena is quitted
	if (eventType == "COMBAT_LOG_EVENT_UNFILTERED") then
		local _,logEventType,_,sourceGUID,_,_,_,destGUID,_,_,_,spellID,spellName,spellSchool,extraSpellId,extraSpellName,extraSpellSchool = CombatLogGetCurrentEventInfo();
		if (logEventType == "SPELL_CAST_SUCCESS" or logEventType == "SPELL_AURA_APPLIED") then
			AAmatch:detectSpec(sourceGUID, spellID, spellName)
		end
		if (logEventType == "UNIT_DIED" and currentArena["firstDeath"] == nil) then
			if(destGUID:find("Player")) then
				deathRegistered = true;
				local _, _, _, _, _, name, realm = GetPlayerInfoByGUID(destGUID)
				if(name ~= nil and name ~= "Unknown") then
					if(realm == nil or realm == "") then
						_,realm = UnitFullName("player"); -- Local player's realm
					end

					currentArena["firstDeath"] = name .. "-" .. realm;
				end
			end
		end
	else
		if (#currentArena["party"] < currentArena["size"]) then
			AAmatch:fillGroupsByUnitReference("party");
		end
		if (#currentArena["enemy"] < currentArena["size"]) then
			AAmatch:fillGroupsByUnitReference("arena");
		end
	end

	-- Look for missing party member or party member with missing spec. (Preg is considered uncertain)
	for i = 1, currentArena["size"] do
		local partyMember = currentArena["party"][i];
		if(partyMember == nil) then
			return false;
		end

		local spec = partyMember["spec"]
		if (spec == nil or string.len(spec) < 3 or spec == "Preg") then
			return false;
		end
	end

	-- Look for missing enemy or enemy with missing spec. (Preg is considered uncertain)
	for i = 1, currentArena["size"] do
		local enemy = currentArena["enemy"][i];
		if(enemy == nil) then
			return false;
		end

		local spec = enemy["spec"];
		if (spec == nil or string.len(spec) < 3 or spec == "Preg") then
			return false;
		end
	end

	return currentArena["firstDeath"];
end

-- Player quitted the arena before it ended
function AAmatch:quitsArena(self, ...)
	currentArena["ended"] = true;
	currentArena["wonByPlayer"] = false;

	ArenaAnalytics:Log("Detected early leave. Has valid current arena: ", currentArena["mapId"]);
end

-- Returns the player's spec
function AAmatch:getPlayerSpec()
	local spec = ArenaAnalytics.API:GetMySpec();

	if (spec == nil) then -- Workaround for when GetTalentTabInfo returns nil
		if(#MatchHistoryDB > 0) then
			-- Get the player from last match (Assumes sorting to index 1)
			spec = MatchHistoryDB[#MatchHistoryDB]["team"][1]["spec"];
		end
	end
	
	return spec
end

local function isArenaPreparationStateActive()
	local auraIndex = 1;
	local aura = UnitAura("player", auraIndex)
	
	if(aura ~= nil) then
		repeat
			local auraID = tonumber(select(10, UnitAura("player", auraIndex)));
			ArenaAnalytics:Log("Aura: ", auraID);
			if(auraID ~= nil and (auraID == 32728 or auraID == 32727)) then
				return true;
			end

			auraIndex = auraIndex + 1;
			aura = UnitAura("player", auraIndex);
		until (aura == nil)
	end

	return false;
end

function AAmatch:getArenaStatus()
	if(not IsActiveBattlefieldArena()) then
		return "None";
	end

	if(GetBattlefieldWinner() ~= nil) then
		return "Ended";
	end

	if(isArenaPreparationStateActive()) then
		return "Preparation";
	end

	return "Active";
end

-- Begins capturing data for the current arena
-- Gets arena player, size, map, ranked/skirmish
function AAmatch:trackArena(...)
	AAmatch:resetCurrentArenaValues();

	currentArena["battlefieldId"] = ...;
	local status, mapName, instanceID, levelRangeMin, levelRangeMax, teamSize, isRated, suspendedQueue, bool, queueType = GetBattlefieldStatus(currentArena["battlefieldId"]);
	
	if (status ~= "active") then
		return false
	end

	local name,realm = UnitFullName("player");
	currentArena["playerName"] = name.."-"..realm;
	currentArena["isRated"] = isRated;
	currentArena["size"] = teamSize;
	
	local bracketId = ArenaAnalytics:getBracketIdFromTeamSize(teamSize);
	if(isRated and ArenaAnalyticsCachedBracketRatings[bracketId] == nil) then
		local lastRating = ArenaAnalytics:getLastRating(teamSize);
		ArenaAnalytics:Log("Fallback: Updating cached rating to rating of last rated entry.");
		ArenaAnalyticsCachedBracketRatings[bracketId] = lastRating;
	end

	-- TODO (v0.4.0): Update to depend on whether local player has been added, in case data 
	if (#currentArena["party"] == 0) then
		-- Add player
		local killingBlows, faction, filename, damageDone, healingDone, spec;
		local class = UnitClass("player");
		local race = UnitRace("player");
		local GUID = UnitGUID("player");
		local name = currentArena["playerName"];
		local spec = AAmatch:getPlayerSpec();
		local player = AAmatch:createPlayerTable(GUID, name, deaths, faction, race, class, filename, damageDone, healingDone, spec);
		table.insert(currentArena["party"], player);
	end

	if(ArenaAnalytics.DataSync) then
		ArenaAnalytics.DataSync:sendMatchGreetingMessage();
	end
	
	-- Not using mapName since string is lang based (unreliable) 
	-- TODO update to WOTLK values and add backwards compatibility
	currentArena["mapId"] = select(8,GetInstanceInfo())
	currentArena["mapName"] = AAmatch:getMapNameById(currentArena["mapId"])
end

-- Returns map string
function AAmatch:getMapNameById(mapId)
	if (mapId == 562) then
		return "BEA";
	elseif (mapId == 572) then
		return "RoL"
	elseif (mapId == 559) then
		return "NA"
	elseif (mapId == 4406) then
		return "RoV"
	elseif (mapId == 617) then
		return "DA"
	end
end

-- Returns currently stored value by character name
-- Used to link existing spec and GUID info with players'
-- info from the UPDATE_BATTLEFIELD_SCORE event
function AAmatch:getCollectedValue(value, name)
	for i = 1, #currentArena["party"] do
		if (currentArena["party"][i][value] ~= "" and currentArena["party"][i]["name"] == name) then
			return currentArena["party"][i][value]
		end
	end
	for j = 1, #currentArena["enemy"] do
		if (currentArena["enemy"][j][value] ~= "" and currentArena["enemy"][j]["name"] == name) then
			return currentArena["enemy"][j][value]
		end
	end
	return "";
end

-- Gets arena information when it ends and the scoreboard is shown
-- Matches obtained info with previously collected player values
function AAmatch:handleArenaEnd()
	currentArena["endedProperly"] = true;
	currentArena["ended"] = true;
	local winner =  GetBattlefieldWinner();

	local team1 = {};
	local team0 = {};
	-- Process ranked information
	local team1Name, oldTeam1Rating, newTeam1Rating, team1Rating, team1RatingDif;
	local team0Name, oldTeam0Rating, newTeam0Rating, team0Rating, team0RatingDif;
	if (currentArena["isRated"]) then
		team1Name, oldTeam1Rating, newTeam1Rating, team1Rating = GetBattlefieldTeamInfo(1);
		team0Name, oldTeam0Rating, newTeam0Rating, team0Rating = GetBattlefieldTeamInfo(0);
		oldTeam0Rating = tonumber(oldTeam0Rating);
		oldTeam1Rating = tonumber(oldTeam1Rating);
		newTeam1Rating = tonumber(newTeam1Rating);
		newTeam0Rating = tonumber(newTeam0Rating);
		if ((newTeam1Rating - oldTeam1Rating) > 0) then
			team1RatingDif = (newTeam1Rating - oldTeam1Rating ~= 0) and (newTeam1Rating - oldTeam1Rating) or "";
		else
			team1RatingDif = (oldTeam1Rating - newTeam1Rating ~= 0) and (oldTeam1Rating - newTeam1Rating) or "";
		end
		if ((newTeam0Rating - oldTeam0Rating) > 0) then
			team0RatingDif = (newTeam0Rating - oldTeam0Rating ~= 0) and (newTeam0Rating - oldTeam0Rating) or "";
		else
			team0RatingDif = (oldTeam0Rating - newTeam0Rating ~= 0) and (oldTeam0Rating - newTeam0Rating) or "";
		end
	end
	
	local numScores = GetNumBattlefieldScores();
	currentArena["wonByPlayer"] = false;
	for i=1, numScores do
		local name, killingBlows, honorKills, deaths, honorGained, faction, rank, race, class, filename, damageDone, healingDone = GetBattlefieldScore(i);
		if(not name:find("-")) then
			_,realm = UnitFullName("player"); -- Local player's realm
			name = name.."-"..realm;
		end

		-- Get spec and GUID from existing data, if available
		local spec = AAmatch:getCollectedValue("spec", name);
		local GUID = AAmatch:getCollectedValue("GUID", name);
		-- Create complete player tables
		local player = AAmatch:createPlayerTable(GUID, name, deaths, faction, race, class, filename, damageDone, healingDone, spec);
		if (player["name"] == currentArena["playerName"]) then
			if (faction == winner) then
				currentArena["wonByPlayer"] = true;
			end
			currentArena["playerTeam"] = faction;
		end
		if (faction == 1) then
			table.insert(team1, player);
		else
			table.insert(team0, player);
		end
	end

	if (currentArena["playerTeam"] == 1) then
		currentArena["party"] = team1;
		currentArena["enemy"] = team0;
		if (currentArena["isRated"]) then
			currentArena["partyMMR"] = team1Rating;
			currentArena["enemyMMR"] = team0Rating;
			currentArena["enemyRating"] = newTeam0Rating;
			currentArena["enemyRatingDelta"] = team0RatingDif;
		end
	else
		currentArena["party"] = team0;
		currentArena["enemy"] = team1;
		if (currentArena["isRated"]) then
			currentArena["partyMMR"] = team0Rating;
			currentArena["enemyMMR"] = team1Rating;
			currentArena["enemyRating"] = newTeam1Rating;
			currentArena["enemyRatingDelta"] = team1RatingDif;
		end
	end
end

function AAmatch:handleArenaExited()
	if (currentArena["mapId"] == nil or currentArena["size"] == nil) then
		return false;	
	end

	local bracketId = ArenaAnalytics:getBracketIdFromTeamSize(currentArena["size"]);

	if(currentArena["isRated"] == true) then
		local newRating = GetPersonalRatedInfo(bracketId);
		local oldRating = ArenaAnalyticsCachedBracketRatings[bracketId];
		ForceDebugNilError(ArenaAnalyticsCachedBracketRatings[bracketId]);
		
		if(oldRating == nil or oldRating == "SKIRMISH") then
			oldRating = ArenaAnalytics:getLastRating();
			ForceDebugNilError(nil);
		end
		
		local deltaRating = newRating - oldRating;
		
		currentArena["partyRating"] = newRating;
		currentArena["partyRatingDelta"] = deltaRating;
	else
		currentArena["partyRating"] = "SKIRMISH";
		currentArena["partyRatingDelta"] = "";
	end

	-- Update all the cached bracket ratings
	AAmatch:updateCachedBracketRatings();

	AAmatch:insertArenaOnTable();
	return true;
end

-- Detects start of arena by CHAT_MSG_BG_SYSTEM_NEUTRAL message (msg)
function AAmatch:hasArenaStarted(msg)
	local locale = ArenaAnalytics.Constants.GetArenaTimer()
    for k,v in pairs(locale) do
        if string.find(msg, v) then
            if (k == 0 and currentArena["timeStartInt"] == 0) then
				currentArena["timeStartInt"] = time();
            end
        end
    end
end

-- Removes events used inside arenas
function AAmatch:removeArenaEvents()
	eventTracker["ArenaEvents"]["UPDATE_BATTLEFIELD_SCORE"] = arenaEventFrame:UnregisterEvent("UPDATE_BATTLEFIELD_SCORE");
	eventTracker["ArenaEvents"]["UNIT_AURA"] = arenaEventFrame:UnregisterEvent("UNIT_AURA");
	eventTracker["ArenaEvents"]["CHAT_MSG_BG_SYSTEM_NEUTRAL"] = arenaEventFrame:UnregisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL");
	eventTracker["ArenaEvents"]["COMBAT_LOG_EVENT_UNFILTERED"] = arenaEventFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
	eventTracker["ArenaEvents"]["ARENA_OPPONENT_UPDATE"] = arenaEventFrame:UnregisterEvent("ARENA_OPPONENT_UPDATE");
	arenaEventFrame:SetScript("OnEvent", nil);
	eventTracker["ArenaEventsAdded"] = false;
end

-- Assigns behaviour for each arena event
-- UPDATE_BATTLEFIELD_SCORE: the arena ended, final info is grabbed and stored
-- UNIT_AURA, COMBAT_LOG_EVENT_UNFILTERED, ARENA_OPPONENT_UPDATE: try to get more arena information (players, specs, etc)
-- CHAT_MSG_BG_SYSTEM_NEUTRAL: Detect if the arena started
local function handleArenaEvents(_, eventType, ...)
	if (IsActiveBattlefieldArena()) then 
		if (not currentArena["ended"]) then
			if (eventType == "UPDATE_BATTLEFIELD_SCORE" and GetBattlefieldWinner() ~= nil ) then
				AAmatch:handleArenaEnd();
				AAmatch:removeArenaEvents();
				-- print("FIRED UPDATE_BATTLEFIELD_SCORE")
			elseif (eventType == "UNIT_AURA" or eventType == "COMBAT_LOG_EVENT_UNFILTERED" or eventType == "ARENA_OPPONENT_UPDATE") then
				currentArena["gotAllArenaInfo"] = currentArena["gotAllArenaInfo"] or AAmatch:getAllAvailableInfo(eventType, ...);
			elseif (eventType == "CHAT_MSG_BG_SYSTEM_NEUTRAL" and currentArena["timeStartInt"] == 0) then
				AAmatch:hasArenaStarted(...)
			end
		end
	end
end

-- Adds events used inside arenas
function AAmatch:addArenaEvents()
	eventTracker["ArenaEvents"]["UPDATE_BATTLEFIELD_SCORE"] = arenaEventFrame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE");
	eventTracker["ArenaEvents"]["UNIT_AURA"] = arenaEventFrame:RegisterEvent("UNIT_AURA");
	eventTracker["ArenaEvents"]["CHAT_MSG_BG_SYSTEM_NEUTRAL"] = arenaEventFrame:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL");
	eventTracker["ArenaEvents"]["COMBAT_LOG_EVENT_UNFILTERED"] = arenaEventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
	eventTracker["ArenaEvents"]["ARENA_OPPONENT_UPDATE"] = arenaEventFrame:RegisterEvent("ARENA_OPPONENT_UPDATE");
	arenaEventFrame:SetScript("OnEvent", handleArenaEvents);
	eventTracker["ArenaEventsAdded"] = true;
end

-- Assigns behaviour for "global" events
-- UPDATE_BATTLEFIELD_STATUS: Begins arena tracking and arena events if inside arena
-- ZONE_CHANGED_NEW_AREA: Tracks if player left the arena before it ended
local function handleEvents(prefix, eventType, ...)
	if (IsActiveBattlefieldArena()) then 
		if (not currentArena["ended"]) then
			if (eventType == "UPDATE_BATTLEFIELD_STATUS") then
				AAmatch:trackArena(...);
			end
			if (not eventTracker["ArenaEventsAdded"]) then
				AAmatch:addArenaEvents();
			end
		end
	elseif (eventType == "UPDATE_BATTLEFIELD_STATUS") then
		currentArena["ended"] = false; -- Player is out of arena, next arena hasn't ended yet
	elseif (eventType == "ZONE_CHANGED_NEW_AREA") then
		if(currentArena["mapId"] ~= nil) then
			if(currentArena["endedProperly"] == false) then
				AAmatch:quitsArena();
			end
			
			AAmatch:removeArenaEvents();
			AAmatch:handleArenaExited();
		end
	end
end

-- Creates "global" events
function AAmatch:EventRegister()
	eventTracker["UPDATE_BATTLEFIELD_STATUS"] = eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS");
	eventTracker["ZONE_CHANGED_NEW_AREA"] = eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	eventFrame:SetScript("OnEvent", handleEvents);
end