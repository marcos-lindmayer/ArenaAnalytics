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

local matchTypes = { "rated", "skirmish", "wargame" }
local brackets = { "2v2", "3v3", "5v5", "shuffle" }

function ArenaAnalytics:GetAddonBracketIndex(bracket)
	if(bracket) then
		bracket = Helpers:ToSafeLower(bracket)
		for i,value in ipairs(brackets) do
			if(Helpers:ToSafeLower(value) == bracket or tonumber(bracket) == i) then
				return i;
			end
		end
	end
	return nil;
end

function ArenaAnalytics:GetBracket(index)
	index = tonumber(index);
	return index and brackets[index];
end

function ArenaAnalytics:GetAddonMatchTypeIndex(matchType)
	if(matchType) then
		matchType = Helpers:ToSafeLower(matchType);
		for i,value in ipairs(matchTypes) do
			if(Helpers:ToSafeLower(value) == matchType or tonumber(value) == i) then
				return i;
			end
		end
	end
	return nil;
end

function ArenaAnalytics:GetMatchType(index)
	index = tonumber(index);
	return index and matchTypes[index];
end

-------------------------------------------------------------------------
-- Character SavedVariables match history
ArenaAnalyticsDB = ArenaAnalyticsDB or {}
ArenaAnalyticsDB.Names = ArenaAnalyticsDB.Names or {}
ArenaAnalyticsDB.Realms = ArenaAnalyticsDB.Realms or {}

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

		local role_bitmap = API:GetRoleBitmap(spec_id);

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
			ArenaMatch:ResortPlayers(match);
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
        local status = API:GetBattlefieldStatus(index)
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
	
	local matchType1 = ArenaMatch:GetMatchType(arena1);
	local matchType2 = ArenaMatch:GetMatchType(arena2);

	if(matchType1 ~= "skirmish" or matchType2 ~= "skirmish") then	
		if(not ArenaAnalytics:ArenasHaveSameParty(arena1, arena2)) then
			return false;
		end
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

function ArenaAnalytics:GetLastMatch(bracketIndex, ignoreInvalidDate)
	if(not ArenaAnalytics:HasStoredMatches()) then
		return nil;
	end

	if(not ignoreInvalidDate) then
		for i=#ArenaAnalyticsDB, 1, -1 do
			local match = ArenaAnalytics:GetMatch(i);
			if(not bracketIndex or bracketIndex == ArenaMatch:GetBracketIndex(match)) then
				local date = ArenaMatch:GetDate(match);
				if(date and date > 0) then
					return match;
				end
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
	if(not date or date == 0) then
		return true;
	end

	-- Invalid comp check (Missing players)
	local team = ArenaMatch:GetTeam(match);
	local requiredTeamSize = ArenaMatch:GetTeamSize(match) or 0;
	if(not team or #team < requiredTeamSize) then
		return true;
	end

	-- Don't skip
	return false; 
end

function ArenaAnalytics:HasMatchSessionExpired(match)
	if(not match) then
		return nil;
	end

	local date = ArenaMatch:GetDate(match);
	local duration = ArenaMatch:GetDuration(match) or 0;

	local endTime = date and date + duration;
	if(not endTime) then
		return true;
	end

	return (time() - endTime) > 3600;
end

-- Returns the whether last session and whether it has expired by time
function ArenaAnalytics:GetLatestSession()
	for i=#ArenaAnalyticsDB, 1, -1 do
		local match = ArenaAnalytics:GetMatch(i);
		if(not ArenaAnalytics:ShouldSkipMatchForSessions(match)) then
			local session = ArenaMatch:GetSession(match);
			local expired = ArenaAnalytics:HasMatchSessionExpired(match);
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

		if(not ArenaAnalytics:ShouldSkipMatchForSessions(match)) then
			local date = ArenaMatch:GetDate(match);
			local session = ArenaMatch:GetSession(match);

			if(lastSession == nil) then
				lastSession = session;

				local duration = ArenaMatch:GetDuration(match);
				local testEndTime = duration and date + duration or date;

				expired = not testEndTime or (time() - testEndTime) > 3600;
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
function ArenaAnalytics:GetLatestRating(bracketIndex, explicitSeason, explicitSeasonPlayed)
	bracketIndex = tonumber(bracketIndex);
	if(bracketIndex) then
		for i = #ArenaAnalyticsDB, 1, -1 do
			local match = ArenaAnalytics:GetMatch(i);
			if(match) then
				local passedSeason = not explicitSeason or explicitSeason == ArenaMatch:GetSeason(match);
				local passedSeasonPlayed = not explicitSeasonPlayed or explicitSeasonPlayed == ArenaMatch:GetSeasonPlayed(match);

				if(passedSeason and passedSeasonPlayed) then
					local rating = ArenaMatch:GetPartyRating(match);
					local bracket = ArenaMatch:GetBracketIndex(match);
					if(rating and bracket == bracketIndex) then
						return rating, seasonPlayed;
					end
				end
			end
		end
	end

	return 0;
end

function ArenaAnalytics:TryFixLastMatchRating()
	local lastMatch = ArenaAnalytics:GetLastMatch(nil, true);
	if(ArenaMatch:DoesRequireRatingFix(lastMatch)) then
		ArenaMatch:TryFixLastRating(lastMatch);
	end
end

function ArenaAnalytics:ClearLastMatchTransientValues(bracketIndex)
	local lastMatch = ArenaAnalytics:GetLastMatch(bracketIndex, true);
	if(lastMatch) then
		ArenaMatch:ClearTransientValues(lastMatch);
	end
end

-- DEPRECATED
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
	if(newArena.isShuffle) then
		newArena.duration = 0;

		if(newArena.committedRounds) then
			for _,round in ipairs(newArena.committedRounds) do
				if(round) then
					newArena.duration = newArena.duration + (tonumber(round.duration) or 0);
				end
			end
		end

		ArenaAnalytics:Log("Shuffle combined duration:", newArena.duration);
	else
		if (hasStartTime) then
			newArena.endTime = time();
			local duration = (newArena.endTime - newArena.startTime);
			duration = duration < 0 and 0 or duration;
			newArena.duration = duration;
		else
			ArenaAnalytics:Log("Force fixed start time at match end.");
			newArena.startTime = time();
			newArena.duration = 0;
		end
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

	ArenaAnalytics:Log("Bracket:", newArena.bracketIndex);
	ArenaMatch:SetBracketIndex(arenaData, newArena.bracketIndex);

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

	ArenaMatch:SetMatchOutcome(arenaData, newArena.outcome);

	-- Add players from both teams sorted, and assign comps.
	ArenaMatch:AddPlayers(arenaData, newArena.players);

	if(newArena.isShuffle) then
		ArenaMatch:SetRounds(arenaData, newArena.committedRounds);
	end

	-- Assign session
	local session = ArenaAnalytics:GetLatestSession();
	local lastMatch = ArenaAnalytics:GetLastMatch(nil, false);
	if (not ArenaAnalytics:IsMatchesSameSession(lastMatch, arenaData)) then
		session = session + 1;
	end
	ArenaMatch:SetSession(arenaData, session);
	ArenaAnalytics.lastSession = session;
	ArenaAnalytics:Log("session:", session);

	-- Transient data
	ArenaMatch:SetTransientSeasonPlayed(arenaData, newArena.seasonPlayed);
	ArenaMatch:SetRequireRatingFix(arenaData, newArena.requireRatingFix);

	-- Clear transient season played from last match
	ArenaAnalytics:ClearLastMatchTransientValues(newArena.bracketIndex);

	-- Insert arena data as a new ArenaAnalyticsDB entry
	table.insert(ArenaAnalyticsDB, arenaData);

	ArenaAnalytics.unsavedArenaCount = ArenaAnalytics.unsavedArenaCount + 1;

	if(Import.tryHide) then
		Import:tryHide();
	end

	ArenaAnalytics:Print("Arena recorded!");

	Filters:Refresh();

	AAtable:TryStartSessionDurationTimer();
end