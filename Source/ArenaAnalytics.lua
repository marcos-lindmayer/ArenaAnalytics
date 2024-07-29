local _, ArenaAnalytics = ...; -- Addon Namespace
local AAmatch = ArenaAnalytics.AAmatch;

-- Local module aliases
local Constants = ArenaAnalytics.Constants;
local ArenaTracker = ArenaAnalytics.ArenaTracker;
local Filters = ArenaAnalytics.Filters;
local AAtable = ArenaAnalytics.AAtable;
local API = ArenaAnalytics.API;
local Import = ArenaAnalytics.Import;
local Options = ArenaAnalytics.Options;
local Helpers = ArenaAnalytics.Helpers;

-------------------------------------------------------------------------
-- Current filtered comp data

local currentCompData = {
	comp = { ["All"] = {} },
	enemyComp = { ["All"] = {} },
};

function ArenaAnalytics:SetCurrentCompData(newCompDataTable)
	assert(newCompDataTable and newCompDataTable.Filter_Comp and newCompDataTable.Filter_EnemyComp);
	currentCompData = Helpers:DeepCopy(newCompDataTable);
end

function ArenaAnalytics:GetCurrentCompData(compKey, comp)
    assert(compKey);

    if(comp ~= nil and currentCompData[compKey]) then
        return currentCompData[compKey][comp] or {};
    else
        return currentCompData[compKey] or {};
    end
end

-- Returns a sorted version of the team specific comp data table
function ArenaAnalytics:GetCurrentCompDataSorted(compKey)
	local compTable = ArenaAnalytics:GetCurrentCompData(compKey);
	local sortableTable = {};

	for comp, data in pairs(compTable) do
		tinsert(sortableTable, {
			comp = comp,
			played = data.played,
			winrate = data.winrate,
			mmr = data.mmr,
		});
	end

	table.sort(sortableTable, function(a,b)
        if(a and a.comp == "All" or b == nil) then
            return true;
        elseif(b and b.comp == "All" or a == nil) then
            return false;
        end

        local sortByTotal = Options:Get("sortCompFilterByTotalPlayed");
        local value1 = tonumber(sortByTotal and (a.played or 0) or (a.winrate or 0));
        local value2 = tonumber(sortByTotal and (b.played or 0) or (b.winrate or 0));
        if(value1 and value2) then
            return value1 > value2;
        end
        return value1 ~= nil;
    end);

	return sortableTable;
end

-------------------------------------------------------------------------

-- Character SavedVariables match history
MatchHistoryDB = MatchHistoryDB or { }

ArenaAnalytics.unsavedArenaCount = 0;

ArenaAnalytics.filteredMatchHistory = { };

function ArenaAnalytics:GetMatch(index)
	return index and MatchHistoryDB[index];
end

function ArenaAnalytics:GetFilteredMatch(index)
	local realMatchIndex = ArenaAnalytics.filteredMatchHistory[index];
	return realMatchIndex and MatchHistoryDB[realMatchIndex];
end

ArenaAnalytics.lastSession = 1;

function ArenaAnalytics:UpdateLastSession()
	ArenaAnalytics.lastSession = ArenaAnalytics:GetLatestSession();
end

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

function ArenaAnalytics:GetActiveBattlefieldID()
    for index = 1, GetMaxBattlefieldID() do
        local status = GetBattlefieldStatus(index)
        if status == "active" then
			ArenaAnalytics:Log("Found battlefield ID ", index)
            return index
        end
    end
	ArenaAnalytics:Log("Failed to find battlefield ID");
end

function ArenaAnalytics:RecomputeSessionsForMatchHistoryDB()
	-- Assign session to filtered matches
	local session = 1
	for i = 1, #MatchHistoryDB do
		local current = MatchHistoryDB[i];
		local prev = MatchHistoryDB[i - 1];

		if(prev and not ArenaAnalytics:IsMatchesSameSession(prev, current)) then
			session = session + 1;
		end

		current["session"] = session;
	end
end

function ArenaAnalytics:HasStoredMatches()
	return (MatchHistoryDB ~= nil and #MatchHistoryDB > 0);
end

-- Check if 2 arenas are in the same session
function ArenaAnalytics:IsMatchesSameSession(arena1, arena2)
	if(not arena1 or not arena2) then
		return false;
	end

	if(arena2["date"] - arena1["date"] > 3600) then
		return false;
	end
	
	if(not ArenaAnalytics:ArenasHaveSameParty(arena1, arena2)) then
		return false;
	end

	return true;
end

function ArenaAnalytics:TeamContainsPlayer(team, playerName)
	if(team and playerName) then
		for _,player in ipairs(team) do
			if (player["name"] == playerName) then
				return true;
			end
		end
	end
end

-- Checks if 2 arenas have the same party members
function ArenaAnalytics:ArenasHaveSameParty(arena1, arena2)
    if(arena1["bracket"] ~= arena2["bracket"]) then
        return false;
    end

    if(not arena1 or not arena2 or not arena1["team"] or not arena2["team"]) then
        return false;
    end

	-- In case one team is smaller, make sure we loop through that one.
	local teamOneIsSmaller = (#arena1["team"] < #arena2["team"]);
	local smallerTeam = teamOneIsSmaller and arena1["team"] or arena2["team"];
	local largerTeam = teamOneIsSmaller and arena2["team"] or arena1["team"];

	for _,player in ipairs(smallerTeam) do
		local playerName = player["name"];
		if (playerName) then
			if(not ArenaAnalytics:TeamContainsPlayer(largerTeam, playerName)) then
				return false;
			end
		end
	end   

    return true;
end

function ArenaAnalytics:GetLastMatch(ignoreInvalidDate)
	if(not ignoreInvalidDate) then
		for i=#MatchHistoryDB, 1, -1 do
			local match = MatchHistoryDB[i];
			if(tonumber(MatchHistoryDB[i]["date"]) and MatchHistoryDB[i]["date"] > 0) then
				return MatchHistoryDB[i];
			end
		end
	end

	return MatchHistoryDB[#MatchHistoryDB];
end

function ArenaAnalytics:ShouldSkipMatchForSessions(match)
	-- Invalid match
	if(match == nil) then
		return true;
	end

	-- Invalid session
	if(tonumber(session) == nil) then
		return true;
	end

	-- Invalid date
	if(tonumber(match["date"]) and tonumber(match["date"]) > 0) then
		return true;
	end

	-- Invalid comp, missing players
	if(not match["party"] or #match["party"] < ArenaAnalytics:getTeamSizeFromBracket(match["bracket"])) then
		return true;
	end

	-- Don't skip
	return false; 
end

-- Returns the whether last session and whether it has expired by time
function ArenaAnalytics:GetLatestSession()
	for i=#MatchHistoryDB, 1, -1 do
		local match = MatchHistoryDB[i];
		if(ArenaAnalytics:ShouldSkipMatchForSessions(match)) then
			local session = match["session"];
			local expired = (time() - match["date"]) > 3600;
			return session, expired;
		end
	end
	return 1, false;
end

-- Returns the start and end times of the last session
function ArenaAnalytics:GetLatestSessionStartAndEndTime()
	local lastSession, expired, bestStartTime, endTime = nil,true;

	for i=#MatchHistoryDB, 1, -1 do
		local match = MatchHistoryDB[i];

		if(ArenaAnalytics:ShouldSkipMatchForSessions(match)) then
			if(lastSession == nil) then
				lastSession = tonumber(match["session"]);
				local testEndTime = match["date"] + match["duration"];
				expired = (time() - testEndTime) > 3600;
				endTime = expired and testEndTime or time();
			end

			if(lastSession == tonumber(match["session"])) then
				bestStartTime = match["date"];
			else
				break;
			end
		end
	end

	return lastSession, expired, bestStartTime, endTime;
end

-- Returns last saved rating on selected bracket (teamSize)
function ArenaAnalytics:GetLatestSeason()
	for i = #MatchHistoryDB, 1, -1 do
		local match = MatchHistoryDB[i];
		if(match ~= nil and match["season"] and match["season"] ~= 0) then
			return tonumber(match["season"]);
		end
	end

	return 0;
end

-- Returns last saved rating on selected bracket (teamSize)
function ArenaAnalytics:GetLatestRating(teamSize)
	local bracket = ArenaAnalytics:getBracketFromTeamSize(teamSize);

	for i = #MatchHistoryDB, 1, -1 do
		local match = MatchHistoryDB[i];
		if(match ~= nil and match["bracket"] == bracket and match["rating"] ~= "SKIRMISH") then
			return tonumber(match["rating"]);
		end
	end

	return 0;
end

function ArenaAnalytics:SortGroup(group, isPlayerPriority, playerFullName)
	if(not group or #group == 0) then
		return;
	end
	
	-- Set playerName if missing
	if(not playerFullName) then
		playerFullName = Helpers:GetPlayerName();
	end
	local name = playerFullName:match("^[^-]+");
	
    table.sort(group, function(playerA, playerB)
		local classA, classB = playerA["class"], playerB["class"];
        local specA, specB = playerA["spec"], playerB["spec"];
		local nameA, nameB = playerA["name"], playerB["name"];
		
        if(isPlayerPriority) then
			if(playerFullName) then
				if(nameA == name or nameA == playerFullName) then
					return true;
				elseif(nameB == name or nameB == playerFullName) then
					return false;
				end
			end

            if(myClass) then
                local priorityA = (classA == myClass) and 1 or 0;
                local priorityB = (classB == myClass) and 1 or 0;

                if(mySpec) then
                    priorityA = priorityA + ((specA == mySpec) and 2 or 0);
                    priorityB = priorityB + ((specB == mySpec) and 2 or 0);
                end

                return priorityA > priorityB;
            end


            if (playerClass) then 
                if(classA == playerClass) then 
                    return true;
                elseif(classB == playerClass) then
                    return false;
                end
            end
        end

		local specID_A = Constants:getAddonSpecializationID(classA, specA);
        local priorityValueA = Constants:getSpecPriorityValue(specID_A);

		local specID_B = Constants:getAddonSpecializationID(classB, specB);
        local priorityValueB = Constants:getSpecPriorityValue(specID_B);

		if(priorityValueA == priorityValueB) then
			return nameA < nameB;
		end

        return priorityValueA < priorityValueB;
    end);
end

-- Cached last rating per bracket ID
ArenaAnalytics.cachedBracketRatings = ArenaAnalytics.cachedBracketRatings ~= nil and ArenaAnalytics.cachedBracketRatings or {
	[1] = nil,
	[2] = nil,
	[3] = nil,
}

-- Updates the cached bracket rating for each bracket
function AAmatch:updateCachedBracketRatings()
	if(IsActiveBattlefieldArena()) then
		ArenaAnalytics.cachedBracketRatings[1] = ArenaAnalytics:GetLatestRating(2); -- 2v2
		ArenaAnalytics.cachedBracketRatings[2] = ArenaAnalytics:GetLatestRating(3); -- 3v3
		ArenaAnalytics.cachedBracketRatings[3] = ArenaAnalytics:GetLatestRating(4); -- 5v5
	else
		ArenaAnalytics.cachedBracketRatings[1] = GetPersonalRatedInfo(1); -- 2v2
		ArenaAnalytics.cachedBracketRatings[2] = GetPersonalRatedInfo(2); -- 3v3
		ArenaAnalytics.cachedBracketRatings[3] = GetPersonalRatedInfo(3); -- 5v5
	end
end

-- Returns a table with the selected arena's player comp
function AAmatch:GetArenaComp(teamTable, bracket)
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

		local specID = Constants:getAddonSpecializationID(player["class"], player["spec"], true);
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
-- and triggers a layout refresh on ArenaAnalytics.AAtable
function ArenaAnalytics:InsertArenaToMatchHistory(newArena)
	local hasStartTime = tonumber(newArena["startTime"]) and newArena["startTime"] > 0;
	if(not hasStartTime) then
		-- At least get an estimate for the time of the match this way.
		newArena["startTime"] = time();
		ArenaAnalytics:Log("Force fixed start time at match end.");
	end

	-- Calculate arena duration
	if (not hasStartTime) then
		newArena["duration"] = 0;
	else
		newArena["endTime"] = time();
		local duration = (newArena["endTime"] - newArena["startTime"]);
		duration = duration < 0 and 0 or duration;
		newArena["duration"] = duration;
	end

	-- Set data for skirmish
	if (newArena["isRated"] == false) then
		newArena["partyRating"] = "SKIRMISH";
		newArena["partyMMR"] = "-";
		newArena["partyRatingDelta"] = nil;
		newArena["enemyRating"] = "-";
		newArena["enemyRatingDelta"] = nil;
		newArena["enemyMMR"] = "-";
	end

	local playerName = Helpers:GetPlayerName();

	ArenaAnalytics:SortGroup(newArena["party"], true, playerName);
	ArenaAnalytics:SortGroup(newArena["enemy"], false, playerName);

	-- Get arena comp for each team
	local bracket = ArenaAnalytics:getBracketFromTeamSize(newArena["size"]);
	newArena["comp"] = AAmatch:GetArenaComp(newArena["party"], bracket);
	newArena["enemyComp"] = AAmatch:GetArenaComp(newArena["enemy"], bracket);

	local season = GetCurrentArenaSeason();
	if (season == 0) then
		ArenaAnalytics:Log("Failed to get valid season for new match.");
	end

	-- Setup table data to insert into MatchHistoryDB
	local arenaData = {
		["player"] = playerName,
		["isRated"] = newArena["isRated"],
		["date"] = tonumber(newArena["startTime"]) or time(),
		["season"] = season,
		["session"] = nil,
		["map"] = Constants:GetMapKeyByID(newArena["mapId"]), 
		["bracket"] = bracket,
		["duration"] = newArena["duration"],
		["team"] = newArena["party"],
		["rating"] = tonumber(newArena["partyRating"]), 
		["ratingDelta"] = tonumber(newArena["partyRatingDelta"]),
		["mmr"] = tonumber(newArena["partyMMR"]), 
		["enemyTeam"] = newArena["enemy"], 
		["enemyRating"] = tonumber(newArena["enemyRating"]), 
		["enemyRatingDelta"] = tonumber(newArena["enemyRatingDelta"]),
		["enemyMmr"] = tonumber(newArena["enemyMMR"]),
		["comp"] = newArena["comp"],
		["enemyComp"] = newArena["enemyComp"],
		["won"] = newArena["wonByPlayer"],
		["firstDeath"] = ArenaTracker:GetFirstDeathFromCurrentArena();
	}

	-- Assign session
	local session = ArenaAnalytics:GetLatestSession();
	local lastMatch = ArenaAnalytics:GetLastMatch(false);
	if (not ArenaAnalytics:IsMatchesSameSession(lastMatch, arenaData)) then
		session = session + 1;
	end
	arenaData["session"] = session;
	ArenaAnalytics.lastSession = session;

	-- Insert arena data as a new MatchHistoryDB entry
	table.insert(MatchHistoryDB, arenaData);
	ArenaAnalytics.unsavedArenaCount = ArenaAnalytics.unsavedArenaCount + 1;
	Import:tryHide();

	ArenaAnalytics:Print("Arena recorded!");
	
	-- Refresh and reset current arena
	ArenaTracker:ResetCurrentArenaValues();
	
	Filters:Refresh();

	AAtable:TryStartSessionDurationTimer();
end

function ArenaAnalytics:IsArenaPreparationStateActive()
	local auraIndex = 1;
	local spellID = select(10, UnitAura("player", auraIndex));

	while(tonumber(spellID)) do
		local auraID = tonumber(spellID);
		if(auraID and (auraID == 32728 or auraID == 32727)) then
			ArenaAnalytics:Log("Arena Preparation active!");
			return true;
		end

		auraIndex = auraIndex + 1;
		spellID = select(10, UnitAura("player", auraIndex));
	end

	return false;
end

function ArenaAnalytics:GetArenaStatus()
	if(not IsActiveBattlefieldArena()) then
		return "None";
	end

	if(GetBattlefieldWinner() ~= nil) then
		return "Ended";
	end

	if(ArenaAnalytics:IsArenaPreparationStateActive()) then
		return "Preparation";
	end

	return "Active";
end