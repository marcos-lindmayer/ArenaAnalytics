local _, ArenaAnalytics = ...; -- Namespace
ArenaAnalytics.AAmatch = {};

local AAmatch = ArenaAnalytics.AAmatch;

-- User settings
ArenaAnalyticsSettings = ArenaAnalyticsSettings and ArenaAnalyticsSettings or {
	["outliers"] = 0,
	["seasonIsChecked"] = false,
	["skirmishIshChecked"] = false,
	["alwaysShowDeathBg"] = false
}; 

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
	["timeEnd"] = 0, 
	["enemyMMR"] = nil,
	["patyMMR"] = nil, 
	["partyRating"] = nil,
	["enemyRating"] = nil,
	["size"] = nil,
	["isRanked"] = nil,
	["playerTeam"] = nil,
	["wonByPlayer"] = nil,
	["prevRating"] = nil,
	["partyRatingDelta"] = "",
	["enemyRatingDelta"] = "",
	["timeStartInt"] = 0,
	["comp"] = {},
	["enemyComp"] = {},
	["party"] = {},
	["enemy"] = {},
	["ended"] = false,
	["gotAllArenaInfo"] = false,
	["endedProperly"] = false,
	["pendingSync"] = false;
	["pendingSyncData"] = nil,
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
	currentArena["enemyMMR"] = nil;
	currentArena["partyMMR"] = nil;
	currentArena["enemyRating"] = nil;
	currentArena["partyRating"] = nil;
	currentArena["size"] = nil;
	currentArena["isRanked"] = nil
	currentArena["playerTeam"] = nil;
	currentArena["party"] = {};
	currentArena["enemy"] = {};
	currentArena["comp"] = {};
	currentArena["enemyComp"] = {};
	currentArena["gotAllArenaInfo"] = false;
	currentArena["partyRatingDelta"] = "";
	currentArena["enemyRatingDelta"] = "";
	currentArena["pendingSync"] = false;
	currentArena["pendingSyncData"] = nil;
	currentArena["prevRating"] = nil;
	currentArena["firstDeath"] = nil
end

local specSpells = ArenaAnalytics.Constants.GetSpecSpells();

-- Arena DB
ArenaAnalyticsDB = ArenaAnalyticsDB  ~= nil and ArenaAnalyticsDB or {
	["2v2"] = {},
	["3v3"] = {},
	["5v5"] = {},
};

-- Cached last rating per bracket ID
ArenaAnalyticsCachedBracketRatings = ArenaAnalyticsCachedBracketRatings ~= nil and ArenaAnalyticsCachedBracketRatings or {
	[1] = nil,
	[2] = nil,
	[3] = nil,
}

-- Updates the cached bracket rating for each bracket
function AAmatch:updateCachedBracketRatings()
	if(IsActiveBattlefieldArena()) then
		ArenaAnalyticsCachedBracketRatings[1] = AAmatch:getLastRating(2); -- 2v2
		ArenaAnalyticsCachedBracketRatings[2] = AAmatch:getLastRating(3); -- 3v3
		ArenaAnalyticsCachedBracketRatings[3] = AAmatch:getLastRating(4); -- 5v5
	else
		ArenaAnalyticsCachedBracketRatings[1] = GetPersonalRatedInfo(1); -- 2v2
		ArenaAnalyticsCachedBracketRatings[2] = GetPersonalRatedInfo(2); -- 3v3
		ArenaAnalyticsCachedBracketRatings[3] = GetPersonalRatedInfo(3); -- 5v5
	end
end

-- Returns a table with unit information to be placed inside either arena["party"] or arena["enemy"]
function AAmatch:createPlayerTable(GUID, name, deaths, faction, race, class, filename, damageDone, healingDone, spec)
	local classIcon = ArenaAnalyticsGetClassIcon(class)
	spec = spec ~= nil and spec or "-";
	local playerTable = {
		["GUID"] = GUID,
		["name"] = name,
		["killingBlows"] = killingBlows,
		["deaths"] = deaths,
		["faction"] = faction,
		["race"] = race,
		["class"] = class,
		["filename"] = filename,
		["damageDone"] = damageDone,
		["healingDone"] = healingDone,
		["classIcon"] = classIcon,
		["spec"] = spec
	};
	return 	playerTable;
end

-- Returns a table with the selected arena's player comp
function AAmatch:getArenaComp(teamTable)
	local comp = {}
	for i = 1, #teamTable do
		table.insert(comp, teamTable[i]["class"] .. "|" .. teamTable[i]["spec"])
	end
	return comp;
end

-- Calculates arena duration, turns arena data into friendly strings, adds it to ArenaAnalyticsDB
-- and triggers a layout refresh on ArenaAnalytics.arenaTable
function AAmatch:insertArenaOnTable()
	-- Calculate arena duration
	if (currentArena["timeStartInt"] == 0) then
		currentArena["duration"] = 0;
	else
		currentArena["timeEnd"] = time();
		local durationMS = ((currentArena["timeEnd"] - currentArena["timeStartInt"]) * 1000);
		durationMS = durationMS < 0 and 0 or durationMS;
		local minutes = durationMS >= 60000 and (SecondsToTime(durationMS/1000, true) .. " ") or "";
		local seconds = math.floor((durationMS % 60000) / 1000);
		currentArena["duration"] = minutes .. seconds .. "sec";
	end

	-- Set data for skirmish
	if (currentArena["isRanked"] == false) then
		currentArena["partyRating"] = "SKIRMISH";
		currentArena["enemyRating"] = "SKIRMISH";
		currentArena["partyMMR"] = "-";
		currentArena["enemyMMR"] = "-";
	end

	-- Friendly name for currentArena["size"]
	local bracket = ArenaAnalytics.Constants.GetBracketFromTeamSize(currentArena["size"]);

	-- Place player first in the arena party group, sort rest 
	table.sort(currentArena["party"], function(a, b)
		local prioA = a["name"] == currentArena["playerName"] and 1 or 2
		local prioB = b["name"] == currentArena["playerName"] and 1 or 2
		local sameClass = a["class"] == b["class"]
		return prioA < prioB or (prioA == prioB and a["class"] < b["class"]) or (prioA == prioB and sameClass and a["name"] < b["name"])
	end
	);

	--Sort arena["enemy"]
	table.sort(currentArena["enemy"], function(a, b)
		local sameClass = a["class"] == b["class"]
		return (sameClass and a["name"] < b["name"]) or a["class"] < b["class"]
	end
	);

	if (currentArena["gotAllArenaInfo"] == false) then 
		-- print("Missing specs. Requesting data")
		if(IsInInstance() or IsInGroup(1)) then
			local messageChannel = IsInInstance() and "INSTANCE_CHAT" or "PARTY";

			-- Request party specs
			for i = 1, #currentArena["party"] do
				if (#currentArena["party"][i]["spec"]<3) then
					local messageSuccess = C_ChatInfo.SendAddonMessage("ArenaAnalytics", UnitGUID("player") .. "_request|spec#" .. currentArena["party"][i]["name"], messageChannel)
				end
			end

			-- Request enemy specs
			for j = 1, #currentArena["enemy"] do
				if (#currentArena["enemy"][j]["spec"]<3) then
					local messageSuccess = C_ChatInfo.SendAddonMessage("ArenaAnalytics", UnitGUID("player") .. "_request|spec#" .. currentArena["enemy"][j]["name"], messageChannel)
				end
			end
		end
	end

	-- Get arena comp for each team
	currentArena["comp"] = AAmatch:getArenaComp(currentArena["party"]);
	currentArena["enemyComp"] = AAmatch:getArenaComp(currentArena["enemy"]);

	-- Setup table data to insert into ArenaAnalyticsDB
	local arenaData = {
		["dateInt"] = currentArena["timeStartInt"],
		["map"] = currentArena["mapName"], 
		["bracket"] = ArenaAnalytics.Constants:GetBracketFromTeamSize(currentArena["size"]),
		["duration"] = currentArena["duration"], 
		["team"] = currentArena["party"],
		["rating"] = currentArena["partyRating"], 
		["ratingDelta"] = currentArena["partyRatingDelta"],
		["mmr"] = currentArena["partyMMR"], 
		["enemyTeam"] = currentArena["enemy"], 
		["enemyRating"] = currentArena["enemyRating"], 
		["enemyRatingDelta"] = currentArena["enemyRatingDelta"],
		["enemyMmr"] = currentArena["enemyMMR"],
		["comp"] = currentArena["comp"],
		["enemyComp"] = currentArena["enemyComp"],
		["won"] = currentArena["wonByPlayer"],
		["isRanked"] = currentArena["isRanked"],
		["firstDeath"] = currentArena["firstDeath"],
		["check"] = false
	}

	-- Insert arena data as a new ArenaAnalyticsDB row
	table.insert(ArenaAnalyticsDB[bracket], arenaData);
	
	if (currentArena["pendingSync"]) then
		AAmatch:handleSync(currentArena["pendingSyncData"])
	end

	if (UnitAffectingCombat("player")) then
		local regenEvent = CreateFrame("Frame");
		regenEvent:RegisterEvent("PLAYER_REGEN_ENABLED");
		regenEvent:SetScript("OnEvent", AAmatch:resetAndRefresh(true, regenEvent));
	else
		-- Refresh and reset
		AAmatch:resetAndRefresh(false, nil)
	end
end

function AAmatch:resetAndRefresh(removeEvent, event)
	if(removeEvent and event ~= nil) then
		event:SetScript("OnEvent", nil);
	end
	AAmatch:resetCurrentArenaValues();
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
function AAmatch:fillGroupsByUnitReference(unit, unitSpec, unitGuid)
	local groupTable = {
		["party"] = currentArena["party"],
		["arena"] = currentArena["enemy"]
	}
	for j = 1, currentArena["size"] do
		j = unit == "party" and  (j - 1) or j;
		local name, realm = UnitName(unit .. j);
		if (name ~= nil) then
			if ( realm == nil or string.len(realm) < 4) then
				realm = "";
			else
				realm = "-" .. realm;
			end
			name = name .. realm;
			-- Check if they were already added
			local currentGroup = groupTable[unit];
			if (not AAmatch:doesGroupContainMemberByName(currentGroup, name) and name ~= "Unknown") then
				local killingBlows, deaths, faction, filename, damageDone, healingDone;
				local class = UnitClass(unit .. j);
				local race = UnitRace(unit .. j);
				local GUID = UnitGUID(unit .. j);
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
	if (specSpells[spellID]) then
		local unitIsParty = false;
		local unitIsEnemy = false;
		-- Check if spell was casted by party
		for partyNumber = 1, #currentArena["party"] do
			if (currentArena["party"][partyNumber]["GUID"] == sourceGUID ) then
				if (#currentArena["party"][partyNumber]["spec"] < 2) then
					-- Adding spec to party member
					currentArena["party"][partyNumber]["spec"] = specSpells[spellID];
				end
				unitIsParty = true;
				break;
			end
		end
		-- Check if spell was casted by enemy
		if (not unitIsParty) then
			for enemyNumber = 1, #currentArena["enemy"] do
				if (currentArena["enemy"][enemyNumber]["GUID"] == sourceGUID ) then
					if (currentArena["enemy"][enemyNumber]["spec"] == "-") then
						-- Adding spec to enemy member
						currentArena["enemy"][enemyNumber]["spec"] = specSpells[spellID];
					end
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
			AAmatch:fillGroupsByUnitReference(unitGroup, specSpells[spellID], sourceGUID);
		end
	end
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
	local gotAllSpecs = false;
	if (eventType == "COMBAT_LOG_EVENT_UNFILTERED") then
		local _,logEventType,_,sourceGUID,_,_,_,destGUID,_,_,_,spellID,spellName,spellSchool,extraSpellId,extraSpellName,extraSpellSchool = CombatLogGetCurrentEventInfo();
		if (logEventType == "SPELL_CAST_SUCCESS" or logEventType == "SPELL_AURA_APPLIED") then
			AAmatch:detectSpec(sourceGUID, spellID, spellName)
		end
		if (logEventType == "UNIT_DIED" and currentArena["firstDeath"] == nil) then
			if(destGUID:gsub("Player", "")) then
				deathRegistered = true;
				local _, _, _, _, _, name, _ = GetPlayerInfoByGUID(destGUID)
				currentArena["firstDeath"] = name;
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

	-- Getting all specs means all possible data has been collected
	local specCount = 0;
	for u = 1, #currentArena["party"] do
		if (string.len(currentArena["party"][u]["spec"]) > 3) then
			specCount = specCount + 1;
		end
	end
	for y = 1, #currentArena["enemy"] do
		if (string.len(currentArena["enemy"][y]["spec"]) > 3) then
			specCount = specCount + 1;
		end
	end
	
	gotAllSpecs = currentArena["size"] * 2 == specCount and currentArena["firstDeath"];

	return gotAllSpecs;
end

-- Player quitted the arena before it ended
-- Triggers AAmatch:insertArenaOnTable with the available info (@NOTE: Commented out, moved to handleArenaExited!)
function AAmatch:quitsArena(self, ...)
	currentArena["ended"] = true;
	currentArena["wonByPlayer"] = false;	
	-- AAmatch:insertArenaOnTable();
end

-- Returns the player's spec
function AAmatch:getPlayerSpec()
	local currentSpecNumber = 0
	local spec
	for i = 1, 3 do
		local name,_ ,pointsSpent = GetTalentTabInfo(i)
		if (pointsSpent > currentSpecNumber) then
			currentSpecNumber = pointsSpent;
			spec = name;
		end
 	end
	spec = spec == "Feral Combat" and "Feral" or spec

	if (spec == nil) then -- Workaround for when GetTalentTabInfo returns nil
		if (#ArenaAnalyticsDB["2v2"] > 0) then
			spec = ArenaAnalyticsDB["2v2"][#ArenaAnalyticsDB["2v2"]]["team"][1]["spec"]
		elseif (#ArenaAnalyticsDB["3v3"] > 0) then
			spec = ArenaAnalyticsDB["3v3"][#ArenaAnalyticsDB["3v3"]]["team"][1]["spec"]
		elseif (#ArenaAnalyticsDB["5v5"] > 0) then
			spec = ArenaAnalyticsDB["5v5"][#ArenaAnalyticsDB["5v5"]]["team"][1]["spec"]
		end
	end
	return spec
end

-- Returns last saved rating on selected bracket (teamSize)
function AAmatch:getLastRating(teamSize)
	if (teamSize == 2 and #ArenaAnalyticsDB["2v2"] > 0) then
		return ArenaAnalyticsDB["2v2"][#ArenaAnalyticsDB["2v2"]]["rating"]
	elseif (teamSize == 3 and #ArenaAnalyticsDB["3v3"] > 0) then
		return ArenaAnalyticsDB["3v3"][#ArenaAnalyticsDB["3v3"]]["rating"]
	elseif (#ArenaAnalyticsDB["5v5"] > 0) then
		return ArenaAnalyticsDB["5v5"][#ArenaAnalyticsDB["5v5"]]["rating"]
	end
	return nil;
end

-- Begins capturing data for the current arena
-- Gets arena player, size, map, ranked/skirmish
function AAmatch:trackArena(...)
	currentArena["endedProperly"] = false;
	currentArena["battlefieldId"] = ...;
	local status, mapName, instanceID, levelRangeMin, levelRangeMax, teamSize, isRankedArena, suspendedQueue, bool, queueType = GetBattlefieldStatus(currentArena["battlefieldId"]);
	
	if status ~= "active" then
		return false
	end

	currentArena["playerName"] = UnitName("player");
	currentArena["isRanked"] = isRankedArena;
	currentArena["size"] = teamSize;
	
	if(ArenaAnalyticsCachedBracketRatings[bracketId] == nil) then
		local rating = GetInspectArenaData(bracketId);
		ArenaAnalytics:Print("DEBUG: GetInspectArenaData(" .. bracketId .. ") returned rating: " .. rating .. " inside the arena.");

		local bracketId = ArenaAnalyticsBracketIdFromTeamSize(teamSize);
		ArenaAnalyticsCachedBracketRatings[bracketId] = rating; -- AAmatch:getLastRating(teamSize);
	end

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
-- Triggers AAmatch:insertArenaOnTable with (hopefully) all the information (@NOTE: Commented out, moved to handleArenaExited!)
function AAmatch:handleArenaEnd()
	currentArena["endedProperly"] = true;
	currentArena["ended"] = true;
	local winner =  GetBattlefieldWinner();

	local team1 = {};
	local team0 = {};
	-- Process ranked information
	local team1Name, oldTeam1Rating, newTeam1Rating, team1Rating, team1RatingDif;
	local team0Name, oldTeam0Rating, newTeam0Rating, team0Rating, team0RatingDif;
	if (currentArena["isRanked"]) then
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
		-- Get spec and GUID from existing data, if available
		local spec = AAmatch:getCollectedValue("spec", name);
		local GUID = AAmatch:getCollectedValue("GUID", name);
		-- Create complete player tables
		local player = AAmatch:createPlayerTable(GUID, name, deaths, faction, race, class, filename, damageDone, healingDone, spec);
		if (player["name"] == currentArena["playerName"]) then
			if (player["faction"] == winner) then
				currentArena["wonByPlayer"] = true;
			end
			currentArena["playerTeam"] = player["faction"];
		end
		if (player["faction"] == 1) then
			table.insert(team1, player);
		else
			table.insert(team0, player);
		end
	end

	if (currentArena["playerTeam"] == 1) then
		currentArena["party"] = team1;
		currentArena["enemy"] = team0;
		if (currentArena["isRanked"]) then
			currentArena["partyMMR"] = team1Rating;
			currentArena["enemyMMR"] = team0Rating;
			currentArena["enemyRating"] = newTeam0Rating;
			currentArena["enemyRatingDelta"] = team0RatingDif;
		end
	else
		currentArena["party"] = team0;
		currentArena["enemy"] = team1;
		if (currentArena["isRanked"]) then
			currentArena["partyMMR"] = team0Rating;
			currentArena["enemyMMR"] = team1Rating;
			currentArena["enemyRating"] = newTeam1Rating;
			currentArena["enemyRatingDelta"] = team1RatingDif;
		end
	end

	-- AAmatch:insertArenaOnTable();
end

function AAmatch:handleArenaExited()
	if (currentArena["mapId"] == nil or currentArena["size"] == nil) then
		return false;	
	end

	local bracketId;
	if (currentArena["size"] == 2) then
		bracketId = 1
	elseif (currentArena["size"] == 3) then
		bracketId = 2
	else
		bracketId = 3
	end

	if(currentArena["isRanked"] == true) then
		local newRating = GetPersonalRatedInfo(bracketId);
		local oldRating = ArenaAnalyticsCachedBracketRatings[bracketId];
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

-- Handles both requests and delivers for specs, enemy MMR/Rating, and version
function AAmatch:handleSync(...)
	local _, msg = ...

	if(msg == nil) then
		ArenaAnalytics:Print("handleSync called with nil message.");
		return;
	end

	-- Exit out if expected symbols for sync message format is missing
	if (not string.find(msg, "|") or not string.find(msg, "_") or not string.find(msg, "%#")) then 
		return;
	end

	local indexOfSeparator, _ = string.find(msg, "_")
	local  sender = msg:sub(1, indexOfSeparator - 1);
	-- Only read if you're not the sender
	if (sender ~= tostring(UnitGUID("player"))) then
		local msgString = msg:sub(indexOfSeparator + 1, #msg);
		indexOfSeparator, _ = string.find(msgString, "|")
		local messageType = msgString:sub(1, indexOfSeparator - 1);
		local messageData = msgString:sub(indexOfSeparator + 1, #msgString);
		indexOfSeparator, _ = string.find(messageData, "#")
		local dataType = messageData:sub(1, indexOfSeparator - 1);
		local dataValue = messageData:sub(indexOfSeparator + 1, #messageData);
		ArenaAnalytics:Print("|cff00cc66" .. sender .. "|r " .. messageType .. "ed: " .. messageData)
		if (messageType == "request") then
			if (dataType == "spec") then
				-- Check if arena in progress, else need to get data from saved game
				local foundSpec = false;
				local spec
				if (currentArena["mapId"] ~= nil) then
					for i = 1, #arenaParty do
						if (arenaParty[i]["name"] == dataValue and #arenaParty[i]["spec"]>2) then
							foundSpec = true;
							spec = arenaParty[i]["spec"]
							break;
						end
					end
					if (foundSpec == false) then
						for i = 1, #arenaEnemy do
							if (arenaEnemy[i]["name"] == dataValue and #arenaEnemy[i]["spec"]>2) then
								spec = arenaEnemy[i]["spec"]
								foundSpec = true
								break;
							end
						end
					end
					
				else
					local lastGame
					local lastGamePerBracket = {
						#ArenaAnalyticsDB["2v2"] > 0 and ArenaAnalyticsDB["2v2"][#ArenaAnalyticsDB["2v2"]] or 0,
						#ArenaAnalyticsDB["3v3"] > 0 and ArenaAnalyticsDB["3v3"][#ArenaAnalyticsDB["3v3"]] or 0,
						#ArenaAnalyticsDB["5v5"] > 0 and ArenaAnalyticsDB["5v5"][#ArenaAnalyticsDB["5v5"]] or 0,
					}
					table.sort(lastGamePerBracket, function (k1,k2)
						if (k1["dateInt"] and k2["dateInt"]) then
							return k1["dateInt"] < k2["dateInt"];
						end
					end)
					local lastGame = lastGamePerBracket[3]

					if (lastGame["team"]) then 
						for i = 1, #lastGame["team"] do
							if (lastGame["team"][i]["name"] == dataValue and #lastGame["team"][i]["spec"] > 2) then
								foundSpec = true;
								spec = lastGame["team"][i]["spec"];
								break;
							end
						end
						if (lastGame["enemyTeam"]) then 
							for j = 1, #lastGame["enemyTeam"] do
								if (lastGame["enemyTeam"][j]["name"] == dataValue and #lastGame["enemyTeam"][j]["spec"] > 2) then
									foundSpec = true;
									spec = lastGame["enemyTeam"][j]["spec"];
									break;
								end
							end
						end
					end
				end
				
				if (foundSpec) then
					if (IsInInstance() or IsInGroup(1)) then
						local messageChannel = IsInInstance() and "INSTANCE_CHAT" or "PARTY";
						local messageSuccess = C_ChatInfo.SendAddonMessage("ArenaAnalytics", UnitGUID("player") .. "_deliver|spec#" .. sender .. "?" .. dataValue .. "=" .. spec, messageChannel);
					end
				end
			elseif (dataType == "enemyRateMMR") then

			end
		elseif (messageType == "deliver") then
			if (dataType == "spec") then
				
				if (currentArena["pendingSync"]) then
					print("sending data")
					indexOfSeparator, _ = string.find(dataValue, "?")
					local nameAndSpec = dataValue:sub(indexOfSeparator + 1, #dataValue);
					indexOfSeparator, _ = string.find(nameAndSpec, "=")
					local deliveredName = nameAndSpec:sub(1, indexOfSeparator - 1);
					local deliveredSpec = nameAndSpec:sub(indexOfSeparator + 1, #nameAndSpec);
					local lastGame
					local lastGamePerBracket = {
						#ArenaAnalyticsDB["2v2"] > 0 and ArenaAnalyticsDB["2v2"][#ArenaAnalyticsDB["2v2"]] or 0,
						#ArenaAnalyticsDB["3v3"] > 0 and ArenaAnalyticsDB["3v3"][#ArenaAnalyticsDB["3v3"]] or 0,
						#ArenaAnalyticsDB["5v5"] > 0 and ArenaAnalyticsDB["5v5"][#ArenaAnalyticsDB["5v5"]] or 0,
					}
					
					table.sort(lastGamePerBracket, function (k1,k2)
						if (k1["dateInt"] and k2["dateInt"]) then
							return k1["dateInt"] < k2["dateInt"];
						end
					end)
					local lastGame = lastGamePerBracket[3]
					
					local foundName = false;

					if (lastGame["team"]) then 
						for i = 1, #lastGame["team"] do
							if (lastGame["team"][i]["name"] == deliveredName and #lastGame["team"][i]["spec"] < 2) then
								foundName = true;
								lastGame["team"][i]["spec"] = deliveredSpec
								break;
							end
						end
						if (lastGame["enemyTeam"]) then 
						for j = 1, #lastGame["enemyTeam"] do
								if (lastGame["enemyTeam"][j]["name"] == deliveredName and #lastGame["enemyTeam"][j]["spec"] < 2) then
									foundName = true;
									lastGame["team"][j]["spec"] = deliveredSpec
									break;
								end
							end
						end
					end
					if (foundName) then
						ArenaAnalytics:Print("Spec(" .. deliveredSpec .. ") for " .. deliveredName .. " has been added!")
					else
						ArenaAnalytics:Print("Error! Name could not be found or already has a spec assigned for latest match!")
					end
				else
					currentArena["pendingSync"] = true;
					currentArena["pendingSyncData"] = ...;
					print("data got requested to me, storing and sending when arena is over for me")
				end
				
			elseif (dataType == "version") then
				indexOfSeparator, _ = string.find(dataValue, "=")
				local version = GetAddOnMetadata("ArenaAnalytics", "Version") or 9999;
				local deliveredVersion = dataValue:sub(indexOfSeparator + 1, #dataValue);
				deliveredVersion = deliveredVersion:gsub("%.","")
				version = version:gsub("%.","")
				print(tonumber(deliveredVersion), tonumber(version))
				if (tonumber(deliveredVersion) > tonumber(version)) then
					ArenaAnalytics:Print("There is an update available. Please download the latest release from TBD") --TODO: Add curseforge page
				end
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
				currentArena["gotAllArenaInfo"] = currentArena["gotAllArenaInfo"] == false and AAmatch:getAllAvailableInfo(eventType, ...) or currentArena["gotAllArenaInfo"];
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
				AAmatch:removeArenaEvents();
			end

			AAmatch:handleArenaExited();
		end
	end

	if (eventType == "CHAT_MSG_ADDON" and ... == "ArenaAnalytics") then
		AAmatch:handleSync(...);
	end
end

-- Creates "global" events
function AAmatch:EventRegister()
	eventTracker["UPDATE_BATTLEFIELD_STATUS"] = eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS");
	eventTracker["ZONE_CHANGED_NEW_AREA"] = eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	eventTracker["CHAT_MSG_ADDON"] = eventFrame:RegisterEvent("CHAT_MSG_ADDON");
	eventFrame:SetScript("OnEvent", handleEvents);
end