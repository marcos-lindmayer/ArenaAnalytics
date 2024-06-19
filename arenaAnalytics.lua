local _, ArenaAnalytics = ...; -- Namespace
ArenaAnalytics.AAmatch = {};

local AAmatch = ArenaAnalytics.AAmatch;

-- Character SavedVariables match history
MatchHistoryDB = MatchHistoryDB or { }

ArenaAnalytics.unsavedArenaCount = 0;

ArenaAnalyticsCharacterSettings = ArenaAnalyticsCharacterSettings and ArenaAnalyticsCharacterSettings or {
	-- Character specific settings
}

-- TODO: Confirm that all events are still used correctly, then delete after refactoring tracking & events
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

function ArenaAnalytics:getLastMatch(ignoreInvalidDate)
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

-- Returns the whether last session and whether it has expired by time
function ArenaAnalytics:getLastSession()
	for i=#MatchHistoryDB, 1, -1 do
		local match = MatchHistoryDB[i];
		if(match and tonumber(match["session"]) and tonumber(match["date"]) and match["date"] > 0) then
			local session = match["session"];
			local expired = (time() - match["date"]) > 3600;
			return session, expired;
		end
	end
	return 1, false;
end

-- TODO: Study to determine risk of no start time detected
-- Returns the start and end times of the last session
function ArenaAnalytics:getLastSessionStartAndEndTime()
	local lastSession, expired, bestStartTime, endTime = nil,true;

	for i=#MatchHistoryDB, 1, -1 do
		local match = MatchHistoryDB[i];

		if(match and tonumber(match["session"])) then
			if(lastSession == nil) then
				lastSession = tonumber(match["session"]);
				expired = (time() - match["date"]) > 3600;
				endTime = expired and match["date"] or time();
			end
						
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
function AAmatch:insertArenaOnTable(newArena)
	if(not newArena["timeStartInt"] or newArena["timeStartInt"] == 0) then
		-- At least get an estimate for the time of the match this way.
		newArena["timeStartInt"] = time();
		ArenaAnalytics:Log("Force fixed start time at match end.");
	end

	-- Calculate arena duration
	if (newArena["timeStartInt"] == 0) then
		newArena["duration"] = 0;
	else
		newArena["timeEnd"] = time();
		local duration = (newArena["timeEnd"] - newArena["timeStartInt"]);
		duration = duration < 0 and 0 or duration;
		newArena["duration"] = duration;
	end

	-- Set data for skirmish
	if (newArena["isRated"] == false) then
		newArena["partyRating"] = "SKIRMISH";
		newArena["partyMMR"] = "-";
		newArena["partyRatingDelta"] = "";
		newArena["enemyRating"] = "-";
		newArena["enemyRatingDelta"] = "";
		newArena["enemyMMR"] = "-";
	end

	-- Place player first in the arena party group, sort rest 
	table.sort(newArena["party"], function(a, b)
		local prioA = a["name"] == newArena["playerName"] and 1 or 2
		local prioB = b["name"] == newArena["playerName"] and 1 or 2
		local sameClass = a["class"] == b["class"]
		return prioA < prioB or (prioA == prioB and a["class"] < b["class"]) or (prioA == prioB and sameClass and a["name"] < b["name"])
	end);

	--Sort arena["enemy"]
	table.sort(newArena["enemy"], function(a, b)
		local sameClass = a["class"] == b["class"]
		return (sameClass and a["name"] < b["name"]) or a["class"] < b["class"]
	end);

	-- Get arena comp for each team
	local bracket = ArenaAnalytics:getBracketFromTeamSize(newArena["size"]);
	newArena["comp"] = AAmatch:getArenaComp(newArena["party"], bracket);
	newArena["enemyComp"] = AAmatch:getArenaComp(newArena["enemy"], bracket);

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
		["isRated"] = newArena["isRated"],
		["date"] = tonumber(newArena["timeStartInt"]) or time(),
		["season"] = season,
		["session"] = nil,
		["map"] = newArena["mapName"], 
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
		["firstDeath"] = ArenaAnalytics.ArenaTracker:GetFirstDeathFromCurrentArena();
	}

	-- Assign session
	local session = ArenaAnalytics:getLastSession();
	local lastMatch = ArenaAnalytics:getLastMatch(false);
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
	ArenaAnalytics.ArenaTracker:ResetCurrentArenaValues();
	
	ArenaAnalytics.Filter:refreshFilters();

	ArenaAnalytics.AAtable:tryStartSessionDurationTimer();
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



