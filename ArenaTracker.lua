local _, ArenaAnalytics = ... -- Namespace
ArenaAnalytics.ArenaTracker = {}
local ArenaTracker = ArenaAnalytics.ArenaTracker;

function ArenaTracker:getCurrentArena()
	return currentArena;
end

-- Arena variables
local currentArena = {
	["battlefieldId"] = nil,
	["mapName"] = "", 
	["mapId"] = nil, 
	["playerName"] = "",
	["duration"] = nil, 
	["timeStartInt"] = nil,
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
	["firstDeath"] = nil,
	["deathData"] = {}
}

-- Reset current arena values
function ArenaTracker:ResetCurrentArenaValues()
	currentArena["battlefieldId"] = nil;
	currentArena["mapName"] = "";
	currentArena["mapId"] = nil;
	currentArena["playerName"] = "";
	currentArena["duration"] = nil;
	currentArena["timeStartInt"] = nil;
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
	currentArena["deathData"] = {};
end

function ArenaTracker:IsTrackingArena()
	return not currentArena["ended"];
end

function ArenaTracker:GetArenaEndedProperly()
	return currentArena["endedProperly"];
end

-- TEMP (?)
function ArenaTracker:SetNotEnded()
	currentArena["ended"] = false;
end

function ArenaTracker:HasMapData()
	return currentArena["mapId"] ~= nil;
end

-- Begins capturing data for the current arena
-- Gets arena player, size, map, ranked/skirmish
function ArenaTracker:trackArena(...)
	ArenaTracker:ResetCurrentArenaValues();

	ArenaAnalytics:Print("Tracking started..");

	currentArena["timeStartInt"] = currentArena["timeStartInt"] or time();

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
		local kills, faction, damage, healing, spec;
		local class = UnitClass("player");
		local race = UnitRace("player");
		local GUID = UnitGUID("player");
		local name = currentArena["playerName"];
		local spec = ArenaAnalytics.AAmatch:getPlayerSpec();
		local player = ArenaTracker:CreatePlayerTable(GUID, name, kills, deaths, faction, race, class, damage, healing, spec);
		table.insert(currentArena["party"], player);
	end

	if(ArenaAnalytics.DataSync) then
		ArenaAnalytics.DataSync:sendMatchGreetingMessage();
	end
	
	-- Not using mapName since string is lang based (unreliable) 
	-- TODO update to WOTLK values and add backwards compatibility
	currentArena["mapId"] = select(8,GetInstanceInfo())
	currentArena["mapName"] = ArenaAnalytics.AAmatch:getMapNameById(currentArena["mapId"])
end

-- Detects start of arena by CHAT_MSG_BG_SYSTEM_NEUTRAL message (msg)
function ArenaTracker:hasArenaStarted(msg)
	if(not currentArena["timeStartInt"]) then
		local locale = ArenaAnalytics.Constants.GetArenaTimer()
		for k,v in pairs(locale) do
			if string.find(msg, v) then
				-- Time is zero according to the broadcast message, and 
				if (k == 0) then
					currentArena["timeStartInt"] = time();
				end
			end
		end
	end
end

function ArenaTracker:handleArenaExited()
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
	ArenaAnalytics.AAmatch:updateCachedBracketRatings();

	ArenaAnalytics.AAmatch:insertArenaOnTable(currentArena);
	return true;
end

-- Returns currently stored value by character name
-- Used to link existing spec and GUID info with players'
-- info from the UPDATE_BATTLEFIELD_SCORE event
function ArenaTracker:GetCollectedValue(value, name)
	local teams = {"party", "enemy"}
	for _,v in pairs(teams) do
		for i = 1, #currentArena[v] do
			if (currentArena[v][i][value] ~= "" and currentArena[v][i]["name"] == name) then
				return currentArena["party"][i][value]
			end
		end
	end
	return nil;
end

-- Gets arena information when it ends and the scoreboard is shown
-- Matches obtained info with previously collected player values
function ArenaTracker:HandleArenaEnd()
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
		local name, kills, honorKills, deaths, honorGained, faction, rank, race, class, _, damage, healing = GetBattlefieldScore(i);
		if(not name:find("-")) then
			_,realm = UnitFullName("player"); -- Local player's realm
			name = name.."-"..realm;
		end

		-- Get spec and GUID from existing data, if available
		local spec = ArenaTracker:GetCollectedValue("spec", name);
		local GUID = ArenaTracker:GetCollectedValue("GUID", name);

		-- Create complete player tables
		local player = ArenaTracker:CreatePlayerTable(GUID, name, kills, deaths, faction, race, class, damage, healing, spec);

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

-- Player quitted the arena before it ended
function ArenaTracker:QuitsArena(self, ...)
	currentArena["ended"] = true;
	currentArena["wonByPlayer"] = false;

	ArenaAnalytics:Log("Detected early leave. Has valid current arena: ", currentArena["mapId"]);
end

-- Returns bool for input group containing a character (by name) in it
function ArenaTracker:DoesGroupContainMemberByName(currentGroup, name)
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
function ArenaTracker:FillGroupsByUnitReference(unitGroup, unitGuid, unitSpec)
	unitGroup = unitGroup == "party" and "party" or "arena";
	
	initialValue = unitGroup == "party" and  0 or 1;
	for i = initialValue, currentArena["size"] do
		local name, realm = UnitNameUnmodified(unitGroup .. i);
		
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
			if (not ArenaTracker:DoesGroupContainMemberByName(currentGroup, name)) then
				local kills, deaths, faction, damage, healing;
				local class = UnitClass(unitGroup .. i);
				local race = UnitRace(unitGroup .. i);
				local GUID = UnitGUID(unitGroup .. i);
				local spec = GUID == unitGuid and unitSpec or nil;
				local player = ArenaTracker:CreatePlayerTable(GUID, name, kills, deaths, faction, race, class, damage, healing, spec);
				table.insert(currentGroup, player);
			end
		end
	end
end

-- Returns a table with unit information to be placed inside either arena["party"] or arena["enemy"]
function ArenaTracker:CreatePlayerTable(GUID, name, kills, deaths, faction, race, class, damage, healing, spec)
	local classIcon = ArenaAnalyticsGetClassIcon(class)
	local playerTable = {
		["GUID"] = GUID,
		["name"] = name,
		["kills"] = kills,
		["deaths"] = deaths,
		["race"] = race,
		["faction"] = ArenaAnalytics.Constants:GetFactionByRace(race),
		["class"] = class,
		["damage"] = damage,
		["healing"] = healing,
		["spec"] = spec or nil
	};
	return playerTable;
end

-- Called from unit actions, to remove false deaths
local function tryRemoveFromDeaths(playerGUID, spell)
	local existingData = currentArena["deathData"][playerGUID];
	if(existingData ~= nil) then
		local timeSinceDeath = time() - existingData["time"]
		
		-- TODO: Confirm that minimal delay is fine. Otherwise improve logic to determine delay based on isHunter and hasKillCredit.
		local minimumDelay = existingData["isHunter"] and 2 or 10;
		if(existingData["hasKillCredit"]) then
			minimumDelay = minimumDelay + 5;
		end
		
		if(timeSinceDeath > 0) then
			ArenaAnalytics:Log("Removed death by post-death action: ", spell, " for player: ",currentArena["deathData"][playerGUID]["name"], " Time since death: ", timeSinceDeath);
			currentArena["deathData"][playerGUID] = nil;
		end
	end
end

-- Fetch the real first death when saving the match
function ArenaTracker:GetFirstDeathFromCurrentArena()
	local deathData = currentArena["deathData"];
	if(deathData == nil or not next(deathData)) then
		ArenaAnalytics:Log("Death data missing from currentArena.");
		return;
	end

	local bestKey, bestTime;
	for key,data in pairs(deathData) do
		if(bestTime == nil or data["time"] < deathData[bestKey]["time"]) then
			ArenaAnalytics:Log("Best death data: ", data["name"])
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

	currentArena["deathData"][playerGUID] = currentArena["deathData"][playerGUID] or {}

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
	currentArena["deathData"][playerGUID] = {
		["time"] = time(), 
		["GUID"] = playerGUID,
		["name"] = playerName,
		["isHunter"] = (class == "HUNTER") or nil;
		["hasKillCredit"] = isKillCredit or currentArena["deathData"][playerGUID]["hasKillCredit"]
	}
end

-- Returns bool whether all obtainable information (before arena ends) has
-- been collected. Attempts to get initial data on arena players:
-- GUID, name, race, class, spec
function ArenaTracker:getAllAvailableInfo(eventType, ...)
	-- Start tracking time again in case of disconnect
	if (not currentArena["timeStartInt"] or currentArena["timeStartInt"] == 0) then
		currentArena["timeStartInt"] = time();
		ArenaAnalytics:Log("Set new start time. Probable reconnect.");
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
	else
		if (#currentArena["party"] < currentArena["size"]) then
			ArenaTracker:FillGroupsByUnitReference("party");
		end
		if (#currentArena["enemy"] < currentArena["size"]) then
			ArenaTracker:FillGroupsByUnitReference("arena");
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
end

function ArenaTracker:assignSpec(class, oldSpec, newSpec)
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

-- Detects spec if a spell is spec defining, attaches it to its
-- caster if they weren't defined yet, or adds a new unit with it
function ArenaTracker:DetectSpec(sourceGUID, spellID, spellName)
	-- Check if spell belongs to spec defining spells
	local spec = ArenaAnalytics.SpecSpells:GetSpec(spellID);
	if (spec ~= nil) then
		local unitIsParty = false;
		local unitIsEnemy = false;
		-- Check if spell was casted by party
		for i = 1, #currentArena["party"] do
			local unit = currentArena["party"][i];
			if (unit["GUID"] == sourceGUID) then
				-- Adding spec to party member
				unit["spec"] = ArenaTracker:assignSpec(unit["class"], unit["spec"], spec);
				unitIsParty = true;
				break;
			end
		end
		-- Check if spell was casted by enemy
		if (not unitIsParty) then
			for i = 1, #currentArena["enemy"] do
				local unit = currentArena["enemy"][i];
				if (unit["GUID"] == sourceGUID) then
					-- Adding spec to enemy member
					unit["spec"] = ArenaTracker:assignSpec(unit["class"], unit["spec"], spec);
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
			ArenaTracker:FillGroupsByUnitReference(unitGroup, sourceGUID, spec);
		end
	end
end