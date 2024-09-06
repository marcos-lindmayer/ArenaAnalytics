local _, ArenaAnalytics = ...; -- Addon Namespace
local AAmatch = ArenaAnalytics.AAmatch;

-- Local module aliases
local Constants = ArenaAnalytics.Constants;
local Bitmap = ArenaAnalytics.Bitmap;
local ArenaTracker = ArenaAnalytics.ArenaTracker;
local Filters = ArenaAnalytics.Filters;
local AAtable = ArenaAnalytics.AAtable;
local API = ArenaAnalytics.API;
local Import = ArenaAnalytics.Import;
local Options = ArenaAnalytics.Options;
local Helpers = ArenaAnalytics.Helpers;
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local Internal = ArenaAnalytics.Internal;

-------------------------------------------------------------------------

function ArenaAnalytics:GetVersion()
    return GetAddOnMetadata("ArenaAnalytics", "Version") or "-";
end

-------------------------------------------------------------------------
-- Character SavedVariables match history
ArenaAnalyticsDB = ArenaAnalyticsDB or {}
ArenaAnalyticsRealmsDB = ArenaAnalyticsRealmsDB or {}

-------------------------------------------------------------------------
-- Realms logic

local function GetRealmIndex(realm)
	assert(realm);

	for i=1, #ArenaAnalyticsRealmsDB do
		local existingRealm = ArenaAnalyticsRealmsDB[i];
		if(existingRealm and realm == existingRealm) then
			return i;
		end
	end

	tinsert(ArenaAnalyticsRealmsDB, realm);
	ArenaAnalytics:Log("Cached new realm:", realm, "at index:", #ArenaAnalyticsRealmsDB);
	return #ArenaAnalyticsRealmsDB;
end

function ArenaAnalytics:GetRealm(realmIndex, errorIfMissing)
	if(not tonumber(realmIndex)) then
		return nil;
	end

	local realm = ArenaAnalyticsRealmsDB[realmIndex];
	
	if(errorIfMissing and not realm) then
		error("Realm index: " .. realmIndex .. " found no realms.")
	end

	return realm;
end

function ArenaAnalytics:GetNameAndRealm(fullName, doCompressRealm)
	if(not fullName) then
		return nil,nil;
	end

	-- Split name and realm
	local name,realm = fullName:match("^(.-)%-(.+)$");
	name = name or fullName;

	-- Attempt name compression
	if(doCompressRealm and realm and not tonumber(realm)) then
		local realmIndex = GetRealmIndex(realm);
		if(realmIndex and ArenaAnalyticsRealmsDB[realmIndex] == realm) then
			realm = realmIndex;
		end
	end

	return name, realm;
end

function ArenaAnalytics:CombineNameAndRealm(name, realm)
	if(name == nil) then
		return nil;
	end

	if(tonumber(realm)) then
		realm = ArenaAnalyticsRealmsDB[tonumber(realm)];
		assert(realm, "Realm index had no realm stored!");
	end

	realm = realm and ("-" .. realm) or "";
	return name .. realm;
end

ArenaAnalytics.localRealmIndex = nil;

function ArenaAnalytics:GetLocalRealmIndex()
	if(tonumber(ArenaAnalytics.localRealmIndex)) then
		return ArenaAnalytics.localRealmIndex;
	end

	local _, realm = UnitFullName("player");
	assert(realm);
	return GetRealmIndex(realm);
end

function ArenaAnalytics:IsLocalRealm(realm)
	if(realm == nil) then
		return;
	end

	if(tonumber(realm)) then
		return tonumber(realm) == ArenaAnalytics:GetLocalRealmIndex();
	end
	
	local _, localRealm = UnitFullName("player");
	return realm == localRealm;
end

ArenaAnalytics.localPlayerInfo = nil;

function ArenaAnalytics:GetLocalPlayerInfo(forceUpdate)
	if(not ArenaAnalytics.localPlayerInfo or forceUpdate) then
		local spec_id = API:GetMySpec();	
		local name, realm = UnitFullName("player");
		local race_id = Helpers:GetUnitRace("player");

		local role_bitmap = Internal:GetRoleBitmap(spec_id);

		ArenaAnalytics.localPlayerInfo = {
			is_self = true,
			name = name,
			realm = realm,
			fullName = ArenaAnalytics:CombineNameAndRealm(name, realm),
			faction = Internal:GetRaceFaction(race_id),
			race = Internal:GetRace(race_id),
			race_id = race_id,
			spec_id = Helpers:GetClassID(spec_id), -- Avoid dynamic changes for sorting
			role = role_bitmap,
			role_main = Bitmap:GetMainRole(role_bitmap),
			role_sub = Bitmap:GetSubRole(role_bitmap),
		};
	end

	return ArenaAnalytics.localPlayerInfo;
end

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

ArenaAnalytics.unsavedArenaCount = 0;

ArenaAnalytics.filteredMatchCount = 0;
ArenaAnalytics.filteredMatchHistory = {};

function ArenaAnalytics:GetMatch(index)
	return index and ArenaAnalyticsDB and ArenaAnalyticsDB[index];
end

function ArenaAnalytics:GetFilteredMatch(index)
	if(not index or index > ArenaAnalytics.filteredMatchCount) then
		return nil;
	end

	local filteredMatchInfo = ArenaAnalytics.filteredMatchHistory[index];
	if(not filteredMatchInfo) then
		return nil;
	end

	local filteredMatch = ArenaAnalytics:GetMatch(filteredMatchInfo.index);
	return filteredMatch, filteredMatchInfo.filteredSession;
end

ArenaAnalytics.lastSession = 1;

function ArenaAnalytics:UpdateLastSession()
	ArenaAnalytics.lastSession = ArenaAnalytics:GetLatestSession();
end

function ArenaAnalytics:RecomputeSessionsForMatchHistory()
	-- Assign session to filtered matches
	local session = 1
	for i = 1, #ArenaAnalyticsDB do
		local current = ArenaAnalytics:GetMatch(i);
		local prev = ArenaAnalytics:GetMatch(i - 1);
		
		if(current) then
			if(prev and not ArenaAnalytics:IsMatchesSameSession(prev, current)) then
				session = session + 1;
			end

			ArenaMatch:SetSession(current, session);
		end

	end

	ArenaAnalytics:UpdateLastSession();
end

function ArenaAnalytics:ResortGroupsInMatchHistory()
	for i=1, #ArenaAnalyticsDB do
		local match = ArenaAnalytics:GetMatch(i);
		if(match) then
			ArenaMatch:SortGroups(match);
		end
	end
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

function ArenaAnalytics:HasStoredMatches()
	return (ArenaAnalyticsDB ~= nil and #ArenaAnalyticsDB > 0);
end

-- Check if 2 arenas are in the same session
function ArenaAnalytics:IsMatchesSameSession(arena1, arena2)
	if(not arena1 or not arena2) then
		return false;
	end

	local date1 = ArenaMatch:GetDate(arena1) or 0;
	local date2 = ArenaMatch:GetDate(arena2) or 0;

	if(date2 - date1 > 3600) then
		return false;
	end
	
	if(not ArenaAnalytics:ArenasHaveSameParty(arena1, arena2)) then
		return false;
	end

	return true;
end

function ArenaAnalytics:TeamContainsPlayer(team, name, realm)
	if(not team or not name) then
		return nil;
	end

	for _,player in ipairs(team) do
		if (ArenaMatch:IsSamePlayer(player, name, realm)) then
			return true;
		end
	end
end

-- Checks if 2 arenas have the same party members
function ArenaAnalytics:ArenasHaveSameParty(arena1, arena2)
    if(not arena1 or not arena2) then
        return false;
    end

	local team1, team2 = ArenaMatch:GetTeam(arena1), ArenaMatch:GetTeam(arena2);
	if(not team1 or not team2) then
		return false;
	end

	local bracket1, bracket2 = ArenaMatch:GetBracketIndex(arena1), ArenaMatch:GetBracketIndex(arena2);
	if(bracket1 ~= bracket2) then
		return false;
	end

	-- In case one team is smaller, make sure we loop through that one.
	local teamOneIsSmaller = (#team1 < #team2);
	local smallerTeam = teamOneIsSmaller and team1 or team2;
	local largerTeam = teamOneIsSmaller and team2 or team1;

	for _,player in ipairs(smallerTeam) do
		local name, realm = ArenaMatch:GetPlayerNameAndRealm(player, true);
		if(not ArenaAnalytics:TeamContainsPlayer(largerTeam, name, realm)) then
			return false;
		end
	end

    return true;
end

function ArenaAnalytics:GetLastMatch(ignoreInvalidDate)
	if(not ArenaAnalytics:HasStoredMatches()) then
		return nil;
	end

	if(not ignoreInvalidDate) then
		for i=#ArenaAnalyticsDB, 1, -1 do
			local match = ArenaAnalytics:GetMatch(i);
			local date = ArenaMatch:GetDate(match);
			if(date and date > 0) then
				return match;
			end
		end
	end

	-- Get the last match
	return ArenaAnalytics:GetMatch(#ArenaAnalyticsDB);
end

function ArenaAnalytics:ShouldSkipMatchForSessions(match)
	-- Invalid match Check
	if(match == nil) then
		return true;
	end

	-- Invalid session Check
	if(ArenaMatch:GetSession(match) == nil) then
		return true;
	end

	-- Invalid date Check
	local date = ArenaMatch:GetDate(match);
	if(date and date > 0) then
		return true;
	end

	-- Invalid comp check (Missing players)
	local team = ArenaMatch:GetTeam(match);
	if(not team or #team < ArenaMatch:GetTeamSize(match)) then
		return true;
	end

	-- Don't skip
	return false; 
end

-- Returns the whether last session and whether it has expired by time
function ArenaAnalytics:GetLatestSession()
	for i=#ArenaAnalyticsDB, 1, -1 do
		local match = ArenaAnalytics:GetMatch(i);
		if(not ArenaAnalytics:ShouldSkipMatchForSessions(match)) then
			local session = ArenaMatch:GetSession(match);

			local matchDate = ArenaMatch:GetDate(match);
			local expired = matchDate and (time() - matchDate) > 3600 or true;
			return session, expired;
		end
	end
	return 0, false;
end

-- Returns the start and end times of the last session
function ArenaAnalytics:GetLatestSessionStartAndEndTime()
	local lastSession, expired, bestStartTime, endTime = nil,true;

	for i=#ArenaAnalyticsDB, 1, -1 do
		local match = ArenaAnalytics:GetMatch(i);

		if(ArenaAnalytics:ShouldSkipMatchForSessions(match)) then
			local date = ArenaMatch:GetDate(match);
			local session = ArenaMatch:GetSession(match);

			if(lastSession == nil) then
				lastSession = session;

				local duration = ArenaMatch:GetDuration(match);
				local testEndTime = duration and date + duration or date;

				expired = testEndTime and (time() - testEndTime) > 3600 or true;
				endTime = expired and testEndTime or time();
			end

			if(lastSession == session) then
				bestStartTime = date;
			else
				break;
			end
		end
	end

	return lastSession, expired, bestStartTime, endTime;
end

-- Returns last saved rating on selected bracket (teamSize)
function ArenaAnalytics:GetLatestSeason()
	for i = #ArenaAnalyticsDB, 1, -1 do
		local match = ArenaAnalytics:GetMatch(i);
		local season = ArenaMatch:GetSeason(match);
		if(season and season > 0) then
			return season;
		end
	end

	return 0;
end

-- Returns last saved rating on selected bracket (teamSize)
function ArenaAnalytics:GetLatestRating(teamSize)
	local targetBracket = ArenaAnalytics:getBracketFromTeamSize(teamSize);
	if(targetBracket ~= nil) then
		for i = #ArenaAnalyticsDB, 1, -1 do
			local match = ArenaAnalytics:GetMatch(i);
			local bracket = ArenaMatch:GetBracket(match);
			if(match) then
				local rating = ArenaMatch:GetPartyRating(match);
				if(rating and bracket == targetBracket) then
					return rating;
				end
			end
		end
	end

	return 0;
end

-- TODO: Replace with ArenaMatch:SortGroup(match)
-- TODO: Look into use cases, determine if new data structure affects this
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
		ArenaAnalytics:Log()
		ArenaAnalytics.cachedBracketRatings[1] = ArenaAnalytics:GetLatestRating(2); -- 2v2
		ArenaAnalytics.cachedBracketRatings[2] = ArenaAnalytics:GetLatestRating(3); -- 3v3
		ArenaAnalytics.cachedBracketRatings[3] = ArenaAnalytics:GetLatestRating(5); -- 5v5
	else
		ArenaAnalytics.cachedBracketRatings[1] = GetPersonalRatedInfo(1); -- 2v2
		ArenaAnalytics.cachedBracketRatings[2] = GetPersonalRatedInfo(2); -- 3v3
		ArenaAnalytics.cachedBracketRatings[3] = GetPersonalRatedInfo(3); -- 5v5
	end
end

-- Returns a table with the selected arena's player comp
function AAmatch:GetArenaComp(teamTable, teamSize)	
	if(teamTable == nil or teamSize > #teamTable) then
		return nil;
	end

	local newComp = {}
	for i=1, teamSize do
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

-- Calculates arena duration, turns arena data into friendly strings, adds it to ArenaAnalyticsDB
-- and triggers a layout refresh on ArenaAnalytics.AAtable
function ArenaAnalytics:InsertArenaToMatchHistory(newArena)
	local hasStartTime = tonumber(newArena.startTime) and newArena.startTime > 0;
	if(not hasStartTime) then
		-- At least get an estimate for the time of the match this way.
	end
	
	-- Calculate arena duration
	if (not hasStartTime) then
		ArenaAnalytics:Log("Force fixed start time at match end.");
		newArena.startTime = time();
		newArena.duration = 0;
	else
		newArena.endTime = time();
		local duration = (newArena.endTime - newArena.startTime);
		duration = duration < 0 and 0 or duration;
		newArena.duration = duration;
	end

	local matchType = nil;
	if(newArena.isRated) then
		matchType = "rated";
	elseif(newArena.isWargame) then
		matchType = "wargame";
	else
		matchType = "skirmish";
	end

	local season = GetCurrentArenaSeason();
	if (season == 0) then
		ArenaAnalytics:Log("Failed to get valid season for new match.");
	end

	-- Setup table data to insert into ArenaAnalyticsDB
	local arenaData = { }
	ArenaMatch:SetDate(arenaData, newArena.startTime);
	ArenaMatch:SetDuration(arenaData, newArena.duration);
	ArenaMatch:SetMap(arenaData, newArena.mapId);
	
	ArenaAnalytics:Log("Bracket:", newArena.bracket);
	ArenaMatch:SetBracket(arenaData, newArena.bracket);

	ArenaMatch:SetMatchType(arenaData, matchType);

	if (newArena.isRated) then
		ArenaMatch:SetPartyRating(arenaData, newArena.partyRating);
		ArenaMatch:SetPartyRatingDelta(arenaData, newArena.partyRatingDelta);
		ArenaMatch:SetPartyMMR(arenaData, newArena.partyMMR);

		ArenaMatch:SetEnemyRating(arenaData, newArena.enemyRating);
		ArenaMatch:SetEnemyRatingDelta(arenaData, newArena.enemyRatingDelta);
		ArenaMatch:SetEnemyMMR(arenaData, newArena.enemyMMR);
	end

	ArenaMatch:SetSeason(arenaData, season);

	ArenaMatch:SetVictory(arenaData, newArena.won);

	-- Add players from both teams sorted, and assign comps.
	ArenaMatch:AddPlayers(arenaData, newArena.players);

	ArenaMatch:SetSelf(arenaData, (newArena.player or Helpers:GetPlayerName()));

	local firstDeath = ArenaTracker:GetFirstDeathFromCurrentArena();
	ArenaMatch:SetFirstDeath(arenaData, firstDeath);
	
	-- Assign session
	local session = ArenaAnalytics:GetLatestSession();
	local lastMatch = ArenaAnalytics:GetLastMatch(false);
	if (not ArenaAnalytics:IsMatchesSameSession(lastMatch, arenaData)) then
		session = session + 1;
	end
	ArenaMatch:SetSession(arenaData, session);
	ArenaAnalytics.lastSession = session;
	ArenaAnalytics:Log("session:", session)

	-- Insert arena data as a new ArenaAnalyticsDB entry
	table.insert(ArenaAnalyticsDB, arenaData);
	ArenaAnalytics.unsavedArenaCount = ArenaAnalytics.unsavedArenaCount + 1;
	if(Import.tryHide) then
		Import:tryHide();
	end

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