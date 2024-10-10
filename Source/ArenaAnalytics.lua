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
local Sessions = ArenaAnalytics.Sessions;

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

function ArenaAnalytics:InitializeArenaAnalyticsDB()
	ArenaAnalyticsDB = ArenaAnalyticsDB or {};
	ArenaAnalyticsDB.names = ArenaAnalyticsDB.names or {};
	ArenaAnalyticsDB.realms = ArenaAnalyticsDB.realms or {};

	local name = UnitNameUnmodified("player");
	local _, realm = UnitFullName("player");
	ArenaAnalyticsDebugAssert(name and realm);

	if(#ArenaAnalyticsDB.names == 0) then
		ArenaAnalyticsDB.names[1] = name;
	end

	if(#ArenaAnalyticsDB.realms == 0) then
		ArenaAnalyticsDB.realms[1] = realm;
	end
end

function ArenaAnalytics:PurgeArenaAnalyticsDB()
	ArenaAnalyticsDB = {};
	ArenaAnalytics:InitializeArenaAnalyticsDB()

	ArenaAnalytics:Print("Match history purged!");
end

-------------------------------------------------------------------------
-- Compressed name and realm logic

-- Name
function ArenaAnalytics:GetNameIndex(name)
	assert(type(name) == "string", "GetNameIndex invalid name provided. " .. type(name) .. " " .. (name or ""));

	if(name == "") then
		return nil;
	end

	-- Conversion from deprecated format
	for i=1, #ArenaAnalyticsDB.names do
		local existingName = ArenaAnalyticsDB.names[i];
		if(existingName and name == existingName) then
			return i;
		end
	end

	tinsert(ArenaAnalyticsDB.names, name);
	ArenaAnalytics:Log("Cached new name:", name, "at index:", #ArenaAnalyticsDB.names);
	return #ArenaAnalyticsDB.names;
end

function ArenaAnalytics:GetName(nameIndex, errorIfMissing)
	nameIndex = tonumber(nameIndex);
	if(not nameIndex) then
		return nil;
	end

	local name = ArenaAnalyticsDB.names[nameIndex];
	
	if(errorIfMissing and not name) then
		error("Name index: " .. nameIndex .. " found no names.")
	end

	return name;
end

-- Realm
function ArenaAnalytics:GetRealmIndex(realm)
	assert(type(realm) == "string", "GetRealmIndex invalid realm provided. " .. type(realm) .. " " .. (realm or ""));

	if(realm == "") then
		return nil;
	end

	-- Conversion from deprecated format
	for i=1, #ArenaAnalyticsDB.realms do
		local existingRealm = ArenaAnalyticsDB.realms[i];
		if(existingRealm and realm == existingRealm) then
			return i;
		end
	end

	tinsert(ArenaAnalyticsDB.realms, realm);
	ArenaAnalytics:Log("Cached new realm:", realm, "at index:", #ArenaAnalyticsDB.realms);
	return #ArenaAnalyticsDB.realms;
end

function ArenaAnalytics:GetRealm(realmIndex, errorIfMissing)
	realmIndex = tonumber(realmIndex);
	if(not realmIndex) then
		return nil;
	end

	local realm = ArenaAnalyticsDB.realms[realmIndex];
	
	if(errorIfMissing and not realm) then
		error("Realm index: " .. realmIndex .. " found no realms.")
	end

	return realm;
end

function ArenaAnalytics:GetIndexedFullName(fullName)
	if(type(fullName) ~= "string") then
		return nil;
	end

	-- Assume realm is only given when name is not full
	local name, realm = strsplit('-', fullName, 2);
	name = ArenaAnalytics:GetNameIndex(name) or "";

	-- Combine expanded realm suffix
	if(realm) then
		realm = ArenaAnalytics:GetRealmIndex(realm);
		realm = realm and ('-' .. realm);
	end

    local fullNameFormat = "%s-%s";
    return string.format(fullNameFormat, name, (realm or ""));
end

function ArenaAnalytics:GetFullName(playerInfo, hideLocalRealm)
	if(not playerInfo.name) then
		return nil;
	end

	local name = playerInfo.name;
	name = ArenaAnalytics:GetName(name) or name;

	if(hideLocalRealm and ArenaAnalytics:IsLocalRealm(playerInfo.realm)) then
		return name;
	end

	-- Combine expanded realm suffix
	local realm = ArenaAnalytics:GetRealm(playerInfo.realm) or playerInfo.realm;
	if(not realm or realm == "") then
		return name;
	end

	local fullNameFormat = "%s-%s";
	return string.format(fullNameFormat, name, realm)
end

function ArenaAnalytics:SplitFullName(fullName, requireCompact)
	if(not fullName) then
		return nil,nil;
	end

	-- Split name and realm
	local name, realm = fullName:match("^(.-)%-(.+)$");
	name = name or fullName;

	name = tonumber(name) or name;
	realm = tonumber(realm) or realm;

	-- Attempt name compression
	if(requireCompact) then -- Index format
		if(type(name) == "string") then
			local nameIndex = ArenaAnalytics:GetNameIndex(name);
			if(nameIndex and ArenaAnalyticsDB.names[nameIndex] == name) then
				name = nameIndex;
			end
		end

		if(type(realm) == "string") then
			local realmIndex = ArenaAnalytics:GetRealmIndex(realm);
			if(realmIndex and ArenaAnalyticsDB.realms[realmIndex] == realm) then
				realm = realmIndex;
			end
		end
	else -- String format
		if(type(name) == "number") then
			name = ArenaAnalyticsDB.names[tonumber(name)];
			assert(name, "Name index had no name stored:", name);
		end

		if(type(realm) == "number") then
			realm = ArenaAnalyticsDB.realms[tonumber(realm)];
			assert(realm, "Realm index had no realm stored:", realm);
		end
	end

	return name, realm;
end

function ArenaAnalytics:CombineNameAndRealm(name, realm)
	if(name == nil) then
		return nil;
	end

	if(tonumber(name)) then
		name = ArenaAnalyticsDB.names[tonumber(name)];
		assert(name, "Name index had no name stored:", name);
	end

	if(tonumber(realm)) then
		realm = ArenaAnalyticsDB.realms[tonumber(realm)];
		assert(realm, "Realm index had no realm stored:", realm);
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
	return ArenaAnalytics:GetRealmIndex(realm);
end

function ArenaAnalytics:IsLocalRealm(realm)
	if(realm == nil) then
		return;
	end

	local _, localRealm = UnitFullName("player");

	if(tonumber(realm)) then
		assert(ArenaAnalyticsDB.realms[1] == localRealm, "Local realm not found at index 1!");
		return tonumber(realm) == 1;
	end

	return realm == localRealm;
end

ArenaAnalytics.localPlayerInfo = nil;
local lastLocalPlayerUpdate = 0;
function ArenaAnalytics:GetLocalPlayerInfo(forceUpdate)
	if(lastLocalPlayerUpdate < time()) then
		forceUpdate = true;
	end

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

		lastLocalPlayerUpdate = time();
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

function ArenaAnalytics:ResortGroupsInMatchHistory()
    debugprofilestart();

	for i=1, #ArenaAnalyticsDB do
		local match = ArenaAnalytics:GetMatch(i);
		if(match) then
			ArenaMatch:ResortPlayers(match);
		end
	end

	ArenaAnalytics:Log("ArenaAnalytics:ResortGroupsInMatchHistory", debugprofilestop())
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

function ArenaAnalytics:GetLastMatch(ignoreInvalidDate, explicitBracketIndex)
	if(not ArenaAnalytics:HasStoredMatches()) then
		return nil;
	end

	if(not ignoreInvalidDate) then
		for i=#ArenaAnalyticsDB, 1, -1 do
			local match = ArenaAnalytics:GetMatch(i);
			if(not explicitBracketIndex or explicitBracketIndex == ArenaMatch:GetBracketIndex(match)) then
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
	local lastMatch = ArenaAnalytics:GetLastMatch(true);
	if(ArenaMatch:DoesRequireRatingFix(lastMatch)) then
		ArenaMatch:TryFixLastRating(lastMatch);
	end
end

function ArenaAnalytics:ClearLastMatchTransientValues(bracketIndex)
	local lastMatch = ArenaAnalytics:GetLastMatch(true, bracketIndex);
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
	Sessions:AssignSession(arenaData);
	ArenaAnalytics:Log("session:", session);

	-- Transient data
	ArenaMatch:SetTransientSeasonPlayed(arenaData, newArena.seasonPlayed);
	ArenaMatch:SetRequireRatingFix(arenaData, newArena.requireRatingFix);

	-- Clear transient season played from last match
	ArenaAnalytics:ClearLastMatchTransientValues(newArena.bracketIndex);

	-- Insert arena data as a new ArenaAnalyticsDB entry
	table.insert(ArenaAnalyticsDB, arenaData);

	ArenaAnalytics.unsavedArenaCount = ArenaAnalytics.unsavedArenaCount + 1;

	if(Import.TryHide) then
		Import:TryHide();
	end

	ArenaAnalytics:Print("Arena recorded!");

	Filters:Refresh();

	Sessions:TryStartSessionDurationTimer();
end