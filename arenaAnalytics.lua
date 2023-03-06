local _, core = ...;
core.Config = {};

local Config = core.Config;

ArenaAnalyticsSettings = ArenaAnalyticsSettings and ArenaAnalyticsSettings or {
	["outliers"] = 0,
	["seasonIsChecked"] = false,
	["skirmishIshChecked"] = false
}; 

local eventFrame = CreateFrame("Frame");
local arenaEventFrame = CreateFrame("Frame");
local eventTracker = {
	["UPDATE_BATTLEFIELD_STATUS"] = false, 
	["ZONE_CHANGED_NEW_AREA"] = false, 
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
local arenaMapName, arenaMapId, arenaPlayerName, 
arenaDuration, arenaTimeEnd, arenaTimeStart,
arenaEnemyMMR, arenaPatyMMR, arenaPartyRating, 
arenaEnemyRating, arenaSize, arenaIsRanked, 
arenaPlayerTeam, arenaWonByPlayer, prevRating;
local arenaPartyRatingDelta = "";
local arenaTimeStartInt = 0;
local arenaComp = {}; 
local arenaEnemyComp = {}
local arenaParty = {};
local arenaEnemy = {};
local arenaEnded = false;

local gotAllArenaInfo = false;
local arenaEndedProperly = true;

local specSpells = core.arenaConstants.GetSpecSpells();

-- Arena DB
ArenaAnalyticsDB = ArenaAnalyticsDB  ~= nil and ArenaAnalyticsDB or {
	["2v2"] = {},
	["3v3"] = {},
	["5v5"] = {},
};

--------------------------------------
-- Defaults
--------------------------------------
local defaults = {
	theme = {
		r = 0, 
		g = 0.8,
		b = 1,
		hex = "00ccff"
	}
}

-- Returns devault theme color (used by config, init)
function Config:GetThemeColor()
	local c = defaults.theme;
	return c.r, c.g, c.b, c.hex;
end

-- Reset current arena values
local function resetLastArenaValues()
	arenaMapName = "";
	arenaMapId = nil;
	arenaPlayerName = "";
	arenaDuration = nil;
	arenaTimeStartInt = 0;
	arenaTimeEnd = 0;
	arenaEnemyMMR = nil;
	arenaPartyMMR = nil;
	arenaEnemyRating = nil;
	arenaPartyRating = nil;
	arenaSize = nil;
	arenaIsRanked = nil
	arenaPlayerTeam = nil;
	arenaParty = {};
	arenaEnemy = {};
	arenaComp = {};
	arenaEnemyComp = {};
	gotAllArenaInfo = false;
	arenaPartyRatingDelta = "";
end

-- Returns a table with unit information to be placed inside either arenaParty or arenaEnemy
local function createPlayerTable(GUID, name, deaths, faction, race, class, filename, damageDone, healingDone, spec)
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
local function getArenaComp(teamTable)
	local comp = {}
	for i = 1, #teamTable do
		table.insert(comp, teamTable[i]["class"] .. "|" .. teamTable[i]["spec"])
	end
	return comp;
end

-- Calculates arena duration, turns arena data into friendly strings, adds it to ArenaAnalyticsDB
-- and triggers a layout refresh on core.arenaTable
local function insertArenaOnTable()
	-- Calculate arena duration
	if (arenaTimeStartInt == 0) then
		arenaDuration = 0;
		arenaTimeStart = date("%d/%m/%y %H:%M:%S");
	else
		arenaTimeEnd = time();
		local arenaDurationMS = ((arenaTimeEnd - arenaTimeStartInt) * 1000);
		arenaDurationMS = arenaDurationMS < 0 and 0 or arenaDurationMS;
		local minutes = arenaDurationMS >= 60000 and (SecondsToTime(arenaDurationMS/1000, true) .. " ") or "";
		local seconds = math.floor((arenaDurationMS % 60000) / 1000);
		arenaDuration = minutes .. seconds .. "sec";
		arenaTimeStart = date("%d/%m/%y %H:%M:%S", time() - seconds);
	end

	-- Get your personal rating gain instead of the one from GetBattlefieldTeamInfo (which gives an average)
	if (arenaIsRanked) then
		local arenaTeamId;
		if (arenaSize == 2) then
			arenaTeamId = 1;
		elseif (arenaSize == 3) then
			arenaTeamId = 2;
		else
			arenaTeamId = 3;
		end
		local personalRating, _, _, _, _, _, _, _, _, _, _ = GetPersonalRatedInfo(arenaTeamId)


		print("personal rating from GetPersonalRatedInfo: " .. personalRating)

		local ratingDiff = ""
		if (arenaWonByPlayer and personalRating - prevRating > 0) then
			arenaPartyRatingDelta = personalRating - prevRating
		elseif (arenaWonByPlayer == false and prevRating - personalRating > 0) then
			arenaPartyRatingDelta = prevRating - personalRating
		end
		arenaPartyRating = personalRating ~= nil and personalRating or "-";
		if (personalRating == nil) then
			local winnerIndex = GetBattlefieldWinner()
			local loserIndex = winnerIndex == 1 and 0 or 1
			local index = arenaWonByPlayer and winnerIndex or loserIndex
			local teamName, oldTeamRating, newTeamRating, teamRating = GetBattlefieldTeamInfo(index);
			DevTools_Dump(GetBattlefieldTeamInfo(index))
			arenaPartyRating = "~" .. newTeamRating;
		else 
			arenaPartyRating = personalRating
		end
		prevRating = nil;
	else 
		-- Set data for skirmish
		arenaPartyRating = arenaPartyRating ~= nil and arenaPartyRating or "SKIRMISH";
		arenaEnemyRating = arenaEnemyRating ~= nil and arenaEnemyRating or "SKIRMISH";
		arenaPartyMMR = arenaPartyMMR ~= nil and arenaPartyMMR or "-";
		arenaEnemyMMR = arenaEnemyMMR ~= nil and arenaEnemyMMR or "-";
	end

	-- Friendly name for arenaSize
	if arenaSize == 2 then
		arenaSize = "2v2";
	elseif arenaSize == 3 then
		arenaSize = "3v3";
	else
		arenaSize = "5v5";
	end;

	-- Place player first in the arena party group, sort rest 
	table.sort(arenaParty, function(a, b)
		local prioA = a["name"] == arenaPlayerName and 1 or 2
		local prioB = b["name"] == arenaPlayerName and 1 or 2
		local sameClass = a["class"] == b["class"]
		return prioA < prioB or (prioA == prioB and a["class"] < b["class"]) or (prioA == prioB and sameClass and a["name"] < b["name"])
	end
	);

	--Sort arenaEnemy
	table.sort(arenaEnemy, function(a, b)
		local sameClass = a["class"] == b["class"]
		return (sameClass and a["name"] < b["name"]) or a["class"] < b["class"]
	end
	);

	-- Get arena comp for each team
	arenaComp = getArenaComp(arenaParty);
	arenaEnemyComp = getArenaComp(arenaEnemy);

	-- Setup table data to insert into ArenaAnalyticsDB
	local arenaData = {
		["date"] = arenaTimeStart, 
		["dateInt"] = arenaTimeStartInt,
		["map"] = arenaMapName, 
		["duration"] = arenaDuration, 
		["team"] = arenaParty,
		["rating"] = arenaPartyRating, 
		["ratingDelta"] = arenaPartyRatingDelta,
		["mmr"] = arenaPartyMMR, 
		["enemyTeam"] = arenaEnemy, 
		["enemyRating"] = arenaEnemyRating, 
		["enemyMmr"] = arenaEnemyMMR,
		["comp"] = arenaComp,
		["enemyComp"] = arenaEnemyComp,
		["won"] = arenaWonByPlayer,
		["isRanked"] = arenaIsRanked
	}

	-- Insert arena data as a new ArenaAnalyticsDB row
	table.insert(ArenaAnalyticsDB[arenaSize], arenaData);

	-- Refresh and reset
	core.arenaTable.RefreshLayout(true);
	resetLastArenaValues();
end

-- Returns bool for input group containing a character (by name) in it
local function doesGroupContainMemberByName(currentGroup, name)
	for i = 1, #currentGroup do
		if (currentGroup[i]["name"] == name) then
			return true
		end
	end
	return false;
end

-- Search for missing members of group (party or arena), createsPlayerTable if 
-- it exist and inserts it in either arenaParty or arenaEnemy. If spec and GUID
-- are passed, include them when creating the player table
local function fillGroupsByUnitReference(unit, unitSpec, unitGuid)
	local groupTable = {
		["party"] = arenaParty,
		["arena"] = arenaEnemy
	}
	for j = 1, arenaSize do
		j = unit == "party" and  (j - 1) or j;
		local playerExists = UnitName(unit .. j) ~= nil;
		if (playerExists) then
			local name, realm = UnitName(unit .. j);
			if ( realm == nil or string.len(realm) < 4) then
				realm = "";
			else
				realm = "-" .. realm;
			end
			name = name .. realm;
			-- Check if they were already added
			local currentGroup = groupTable[unit];
			if (not doesGroupContainMemberByName(currentGroup, name) and name ~= "Unknown") then
				local killingBlows, deaths, faction, filename, damageDone, healingDone;
				local class = UnitClass(unit .. j);
				local race = UnitRace(unit .. j);
				local GUID = UnitGUID(unit .. j);
				local spec = GUID == unitGuid and unitSpec or nil;
				local player = createPlayerTable(GUID, name, deaths, faction, race, class, filename, damageDone, healingDone, spec);
				table.insert(currentGroup, player);
			end
		end
	end
end

-- Detects spec if a spell is spec defining, attaches it to its
-- caster if they weren't defined yet, or adds a new unit with it
local function detectSpec(sourceGUID, spellID, spellName)
	-- Check if spell belongs to spec defining spells
	if (specSpells[spellID]) then
		local unitIsParty = false;
		local unitIsEnemy = false;
		-- Check if spell was casted by party
		for partyNumber = 1, #arenaParty do
			if (arenaParty[partyNumber]["GUID"] == sourceGUID ) then
				if (#arenaParty[partyNumber]["spec"] < 2) then
					-- Adding spec to party member
					arenaParty[partyNumber]["spec"] = specSpells[spellID];
				end
				unitIsParty = true;
				break;
			end
		end
		-- Check if spell was casted by enemy
		if (not unitIsParty) then
			for enemyNumber = 1, #arenaEnemy do
				if (arenaEnemy[enemyNumber]["GUID"] == sourceGUID ) then
					if (arenaEnemy[enemyNumber]["spec"] == "-") then
						-- Adding spec to enemy member
						arenaEnemy[enemyNumber]["spec"] = specSpells[spellID];
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
			for i = 1, arenaSize do
				if (UnitGUID("party" .. i) == sourceGUID) then
					unitGroup = "party";
				end
			end
			if (unitGroup == nil) then
				unitGroup = "arena";
			end
			fillGroupsByUnitReference(unitGroup, specSpells[spellID], sourceGUID);
		end
	end
end

-- Returns bool wether all obtainable information (before arena ends) has
-- been collected. Attempts to get initial data on arena players:
-- GUID, name, race, class, spec
local function getAllAvailableInfo(eventType, ...)

	-- Start tracking time again in case of disconnect
	if (arenaTimeStartInt == 0) then
		arenaTimeStartInt = time();
	end

	-- Tracking teams for spec/race and in case arena is quitted
	local gotAllSpecs = false;
	if (eventType == "COMBAT_LOG_EVENT_UNFILTERED") then
		local _,logEventType,_,sourceGUID,_,_,_,destGUID,_,_,_,spellID,spellName,spellSchool,extraSpellId,extraSpellName,extraSpellSchool = CombatLogGetCurrentEventInfo();
		if (logEventType == "SPELL_CAST_SUCCESS" or logEventType == "SPELL_AURA_APPLIED") then
			detectSpec(sourceGUID, spellID, spellName)
		end
	else
		if (#arenaParty < arenaSize) then
			fillGroupsByUnitReference("party");
		end
		if (#arenaEnemy < arenaSize) then
			fillGroupsByUnitReference("arena");
		end
	end

	-- Getting all specs means all possible data has been collected
	local specCount = 0;
	for u = 1, #arenaParty do
		if (string.len(arenaParty[u]["spec"]) > 3) then
			specCount = specCount + 1;
		end
	end
	for y = 1, #arenaEnemy do
		if (string.len(arenaEnemy[y]["spec"]) > 3) then
			specCount = specCount + 1;
		end
	end
	
	gotAllSpecs = arenaSize * 2 == specCount;

	return gotAllSpecs;
end

-- Player quitted the arena before it ended
-- Triggers insertArenaOnTable with the available info
local function quitsArena(self, ...)
	arenaEnded = true;
	arenaWonByPlayer = false;	
	insertArenaOnTable();
end

-- Returns the player's spec
function ArenaAnalyticsGetPlayerSpec()
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


-- Begins capturing data for the current arena
-- Gets arena player, size, map, ranked/skirmish
local function trackArena(...)
	arenaEndedProperly = false;
	local i = ...;
	local status, mapName, instanceID, levelRangeMin, levelRangeMax, teamSize,
	isRankedArena, suspendedQueue, bool, queueType = GetBattlefieldStatus(i);

	if status ~= "active" then
		return false
	end

	arenaPlayerName = UnitName("player");
	arenaIsRanked = isRankedArena;
	arenaSize = teamSize;
	if (arenaIsRanked) then
		local arenaTeamId;
		if (arenaSize == 2) then
			arenaTeamId = 1;
		elseif (arenaSize == 3) then
			arenaTeamId = 2;
		else
			arenaTeamId = 3;
		end
		local personalRating, _, _, _, _, _, _, _, _, _, _ = GetPersonalRatedInfo(arenaTeamId)
		if (prevRating == nil) then
			prevRating = personalRating
		end
	end

	if (#arenaParty == 0) then
		-- Add player
		local killingBlows, faction, filename, damageDone, healingDone, spec;
		local class = UnitClass("player");
		local race = UnitRace("player");
		local GUID = UnitGUID("player");
		local name = arenaPlayerName;
		local spec = ArenaAnalyticsGetPlayerSpec();
		local player = createPlayerTable(GUID, name, deaths, faction, race, class, filename, damageDone, healingDone, spec);
		table.insert(arenaParty, player);
	end
	
	-- Not using mapName since string is lang based (unreliable) 
	-- TODO update to WOTLK values and add backwards compatibility
	arenaMapId = select(8,GetInstanceInfo())
	if (arenaMapId == 562) then
		arenaMapName = "BEA";
	elseif (arenaMapId == 572) then
		arenaMapName = "RoL"
	elseif (arenaMapId == 559) then
		arenaMapName = "NA"
	elseif (arenaMapId == 4406) then
		arenaMapName = "RoV"
	elseif (arenaMapId == 617) then
		arenaMapName = "DA"
	end

end

-- Returns currently stored value by character name
-- Used to link existing spec and GUID info with players'
-- info from the UPDATE_BATTLEFIELD_SCORE event
local function getCollectedValue(value, name)
	for i = 1, #arenaParty do
		if (arenaParty[i][value] ~= "" and arenaParty[i]["name"] == name) then
			return arenaParty[i][value]
		end
	end
	for j = 1, #arenaEnemy do
		if (arenaEnemy[j][value] ~= "" and arenaEnemy[j]["name"] == name) then
			return arenaEnemy[j][value]
		end
	end
	return "";
end

-- Gets arena information when it ends and the scoreboard is shown
-- Matches obtained info with previously collected player values
-- Triggers insertArenaOnTable with (hopefully) all the information
local function handleArenaEnd()
	arenaEndedProperly = true;
	arenaEnded = true;
	local winner =  GetBattlefieldWinner();

	local team1 = {};
	local team0 = {};
	-- Process ranked information
	local team1Name, oldTeam1Rating, newTeam1Rating, team1Rating, team1RatingDif;
	local team0Name, oldTeam0Rating, newTeam0Rating, team0Rating, team0RatingDif;
	if (arenaIsRanked) then
		team1Name, oldTeam1Rating, newTeam1Rating, team1Rating = GetBattlefieldTeamInfo(1);
		team0Name, oldTeam0Rating, newTeam0Rating, team0Rating = GetBattlefieldTeamInfo(0);
		oldTeam0Rating = tonumber(oldTeam0Rating);
		oldTeam1Rating = tonumber(oldTeam1Rating);
		newTeam1Rating = tonumber(newTeam1Rating);
		newTeam0Rating = tonumber(newTeam0Rating);
		if ((newTeam1Rating - oldTeam1Rating) > 0) then
			team1RatingDif = (newTeam1Rating - oldTeam1Rating ~= 0) and " (+" .. tostring(newTeam1Rating - oldTeam1Rating) .. ")" or "";
		else
			team1RatingDif = (oldTeam1Rating - newTeam1Rating ~= 0) and " (-" .. tostring(oldTeam1Rating - newTeam1Rating) .. ")" or "";
		end
		if ((newTeam0Rating - oldTeam0Rating) > 0) then
			team0RatingDif = (newTeam0Rating - oldTeam0Rating ~= 0) and " (+" .. tostring(newTeam0Rating - oldTeam0Rating) .. ")" or "";
		else
			team0RatingDif = (oldTeam0Rating - newTeam0Rating ~= 0) and " (-" .. tostring(oldTeam0Rating - newTeam0Rating) .. ")" or "";
		end
	end
	
	local numScores = GetNumBattlefieldScores();
	arenaWonByPlayer = false;
	for i=1, numScores do
		local name, killingBlows, honorKills, deaths, honorGained, faction, rank, race, class, filename, damageDone, healingDone = GetBattlefieldScore(i);
		-- Get spec and GUID from existing data, if available
		local spec = getCollectedValue("spec", name);
		local GUID = getCollectedValue("GUID", name);
		-- Create complete player tables
		local player = createPlayerTable(GUID, name, deaths, faction, race, class, filename, damageDone, healingDone, spec);
		if (player["name"] == arenaPlayerName) then
			if (player["faction"] == winner) then
				arenaWonByPlayer = true;
			end
			arenaPlayerTeam = player["faction"];
		end
		if (player["faction"] == 1) then
			table.insert(team1, player);
		else
			table.insert(team0, player);
		end
	end
	if (arenaPlayerTeam == 1) then
		arenaParty = team1;
		arenaEnemy = team0;
		if (arenaIsRanked) then
			arenaPartyMMR = team1Rating;
			arenaEnemyMMR = team0Rating;
			arenaEnemyRating = newTeam0Rating .. team0RatingDif;
		end
	else
		arenaParty = team0;
		arenaEnemy = team1;
		if (arenaIsRanked) then
			arenaPartyMMR = team0Rating;
			arenaEnemyMMR = team1Rating;
			arenaEnemyRating = newTeam1Rating .. team1RatingDif;
		end
	end
	insertArenaOnTable();
end

-- Detects start of arena by CHAT_MSG_BG_SYSTEM_NEUTRAL message (msg)
local function hasArenaStarted(msg)
	local locale = core.arenaConstants.GetArenaTimer()
    for k,v in pairs(locale) do
        if string.find(msg, v) then
            if k == 0 then
				arenaTimeStartInt = time();
            end
        end
    end
end

-- Removes events used inside arenas
local function removeArenaEvents()
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
		if (not arenaEnded) then
			if (eventType == "UPDATE_BATTLEFIELD_SCORE" and GetBattlefieldWinner() ~= nil ) then
				handleArenaEnd();
				removeArenaEvents();
			elseif (eventType == "UNIT_AURA" or eventType == "COMBAT_LOG_EVENT_UNFILTERED" or eventType == "ARENA_OPPONENT_UPDATE") then
				gotAllArenaInfo = gotAllArenaInfo == false and getAllAvailableInfo(eventType, ...) or gotAllArenaInfo;
			elseif (eventType == "CHAT_MSG_BG_SYSTEM_NEUTRAL" and arenaTimeStartInt == 0) then
				hasArenaStarted(...)
			end
		end
	end
end

-- Adds events used inside arenas
local function addArenaEvents()
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
local function handleEvents(_, eventType, ...)
	if (IsActiveBattlefieldArena()) then 
		if (not arenaEnded) then
			if (eventType == "UPDATE_BATTLEFIELD_STATUS") then
				trackArena(...);
			end
			if (not eventTracker["ArenaEventsAdded"]) then
				addArenaEvents()
			end
		end
	elseif (eventType == "UPDATE_BATTLEFIELD_STATUS") then
		arenaEnded = false; -- Player is out of arena, next arena hasn't ended yet
	elseif (not IsActiveBattlefieldArena() and eventType == "ZONE_CHANGED_NEW_AREA" and arenaEndedProperly ~= true and arenaMapId ~= nil) then
		quitsArena();
		removeArenaEvents();
	end

end

-- Creates "global" events
function Config:EventRegister()
	eventTracker["UPDATE_BATTLEFIELD_STATUS"] = eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS");
	eventTracker["ZONE_CHANGED_NEW_AREA"] = eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	eventFrame:SetScript("OnEvent", handleEvents);
	
end

function fixAllRatingGains()
	for i = 1, #ArenaAnalyticsDB["3v3"] - 1, 1 do
		if (ArenaAnalyticsDB["3v3"][i]["isRanked"] == false or string.len(ArenaAnalyticsDB["3v3"][i]["rating"]) > 6) then
			
		else
			gameRating = tonumber(ArenaAnalyticsDB["3v3"][i]["rating"])
			if(string.len(ArenaAnalyticsDB["3v3"][i + 1]["rating"]) > 6) then
			else
				nextGameRating = tonumber(ArenaAnalyticsDB["3v3"][i + 1]["rating"])
				fixedArenaDiff = ""
				if (nextGameRating ~= gameRating) then
					if (ArenaAnalyticsDB["3v3"][i]["won"] == true) then
						fixedArenaDiff = "+" .. nextGameRating - gameRating
					else
						fixedArenaDiff = "-" .. gameRating - nextGameRating
					end
					ArenaAnalyticsDB["3v3"][i]["rating"] = gameRating .. " (" .. fixedArenaDiff .. ")";
				end
			end
		end
    end

	for i = 1, #ArenaAnalyticsDB["2v2"] - 1, 1 do
		if (ArenaAnalyticsDB["2v2"][i]["isRanked"] == false or string.len(ArenaAnalyticsDB["2v2"][i]["rating"]) > 6) then
			
		else
			gameRating = tonumber(ArenaAnalyticsDB["2v2"][i]["rating"])
			if(string.len(ArenaAnalyticsDB["2v2"][i + 1]["rating"]) > 6) then
				print("following arena has correct rating")
				print(ArenaAnalyticsDB["2v2"][i]["rating"])
				print(ArenaAnalyticsDB["2v2"][i + 1]["rating"])
				print("-------------------")
			else
				nextGameRating = tonumber(ArenaAnalyticsDB["2v2"][i + 1]["rating"])
				fixedArenaDiff = ""
				if (nextGameRating ~= gameRating) then
					if (ArenaAnalyticsDB["2v2"][i]["won"] == true) then
						fixedArenaDiff = "+" .. nextGameRating - gameRating
					else
						fixedArenaDiff = "-" .. gameRating - nextGameRating
					end
					print("rating is " .. gameRating)
					print("next rating is " .. nextGameRating)
					print("so first rating should be " .. gameRating .. " (" .. fixedArenaDiff .. ")")
					print("-------------------")
					ArenaAnalyticsDB["2v2"][i]["rating"] = gameRating .. " (" .. fixedArenaDiff .. ")";
				end
			end
		end
    end

	for i = 1, #ArenaAnalyticsDB["5v5"] - 1, 1 do
		if (ArenaAnalyticsDB["5v5"][i]["isRanked"] == false or string.len(ArenaAnalyticsDB["5v5"][i]["rating"]) > 6) then
			
		else
			gameRating = tonumber(ArenaAnalyticsDB["5v5"][i]["rating"])
			if(string.len(ArenaAnalyticsDB["5v5"][i + 1]["rating"]) > 6) then
			else
				nextGameRating = tonumber(ArenaAnalyticsDB["5v5"][i + 1]["rating"])
				fixedArenaDiff = ""
				if (nextGameRating ~= gameRating) then
					if (ArenaAnalyticsDB["5v5"][i]["won"] == true) then
						fixedArenaDiff = "+" .. nextGameRating - gameRating
					else
						fixedArenaDiff = "-" .. gameRating - nextGameRating
					end
					ArenaAnalyticsDB["5v5"][i]["rating"] = gameRating .. " (" .. fixedArenaDiff .. ")";
				end
			end
		end
    end
end
