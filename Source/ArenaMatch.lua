local _, ArenaAnalytics = ...; -- Addon Namespace
local ArenaMatch = ArenaAnalytics.ArenaMatch;

-- Local module aliases
local Constants = ArenaAnalytics.Constants;
local Bitmap = ArenaAnalytics.Bitmap;
local Helpers = ArenaAnalytics.Helpers;
local Internal = ArenaAnalytics.Internal;
local GroupSorter = ArenaAnalytics.GroupSorter;
local API = ArenaAnalytics.API;
local ArenaRatedInfo = ArenaAnalytics.ArenaRatedInfo;
local TablePool = ArenaAnalytics.TablePool;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------

ArenaMatch.matchKeys = {
    date = 0,
    duration = -1,
    map = -2,
    bracket = -3,
    match_type = -4,
    rating = -5,
    rating_delta = -6,
    mmr = -7,
    enemy_rating = -8,
    enemy_rating_delta = -9,
    enemy_mmr = -10,
    season = -11,
    session = -12,
    outcome = -13,
    team = -14,
    enemy_team = -15,
    comp = -16,
    enemy_comp = -17,
    rounds = -18,
    seasonPlayed = -19,

    transient_seasonPlayed_DEPRECATED = -100, -- TODO: Remove in favor of persistent seasonPlayed key
    transient_requireRatingFix = -101,
};
local matchKeys = ArenaMatch.matchKeys;

ArenaMatch.playerKeys = {
    name = 0,
    realm = -1,
    race = -2,
    spec = -3,
    role = -4,
    is_self = -5,
    is_first_death = -6,
    rated_info = -7,
    stats = -8,
    variable_stats = -9, -- Game mode specific stats (Wins for shuffle)
    is_female = -10, -- For future localization logic
};
local playerKeys = ArenaMatch.playerKeys;

ArenaMatch.roundKeys = {
    data = 0,
    comp = -1,
    enemy_comp = -2,
};
local roundKeys = ArenaMatch.roundKeys;

-------------------------------------------------------------------------
-- Temp conversion functions

-- Conversion logic
function ArenaMatch:FixRoundFormat(match)
    if(not match or not match[matchKeys.rounds]) then
        return nil;
    end

    for i,round in ipairs(match[matchKeys.rounds]) do
        local round = match[matchKeys.rounds][i];
        local roundData = round and round[roundKeys.data];
        if(roundData and roundData:find('-', 1, true)) then
            local newData = roundData:gsub('-', '|');
            Debug:LogEscaped(newData, "  :  ", round[roundKeys.data]);
            round[roundKeys.data] = newData;
        end
    end
end

function ArenaMatch:AddWinsToRoundData(match)
    local rounds = match and match[matchKeys.rounds];
    if(not rounds or #rounds == 0) then
        return;
    end

    for i,round in ipairs(rounds) do
        local data = round and round[roundKeys.data];
        local team, enemy, firstDeath, duration, outcome = ArenaMatch:SplitRoundData(data);

        if(firstDeath and not outcome) then
            if(firstDeath == 0 or (team and team:find(firstDeath, 1, true))) then
                outcome = 0;
            elseif(enemy and enemy:find(firstDeath, 1, true)) then
                outcome = 1;
            end

            if(outcome ~= nil) then
                -- Update round data
                round[roundKeys.data] = ArenaMatch:MakeRoundData(team, enemy, firstDeath, duration, outcome);
                Debug:LogEscaped("Converting data:", data, "To:", round[roundKeys.data]);
            end
        end
    end
end

-------------------------------------------------------------------------
-- Helper functions

local function ToPositiveNumber(value, allowZero)
    value = tonumber(value);
    if(not value) then
        return nil;
    end

    value = Round(value);

    if(value < 0) then
        return nil;
    elseif(value == 0) then
        return allowZero and 0 or nil;
    end

    return value or nil;
end

local function ToNumericalOutcome(value, drawValue)
    value = tonumber(value);
    if(value == nil) then
        return nil;
    end

    if(drawValue and value == drawValue) then
        assert(type(drawValue) == "number", "ToNumericalOutcome drawValue must be a number!");
        return drawValue;
    end

    return (value ~= 0) and 1 or 0;
end

local function ToNumericalBool(value, ignoreFalse)
    if(value == nil) then
        return nil;
    end

    if(type(value) == "number") then
        value = (value ~= 0); -- Convert to bool
    end

    if(not value) then
        return not ignoreFalse and 0 or nil;
    end

    return 1;
end

-------------------------------------------------------------------------
-- Rating fixup

function ArenaMatch:ClearTransientValues(match)
    assert(match);

    match[matchKeys.transient_seasonPlayed_DEPRECATED] = nil;
    match[matchKeys.transient_requireRatingFix] = nil;
end

function ArenaMatch:TrySetRequireRatingFix(match, value)
    assert(match);

    value = value and true;
    if(not value) then
        return;
    end

    Debug:LogWarning("TrySetRequireRatingFix:", value, "from:", match[matchKeys.transient_requireRatingFix]);
    match[matchKeys.transient_requireRatingFix] = value;
end

function ArenaMatch:DoesRequireRatingFix(match)
    return match and (match[matchKeys.transient_requireRatingFix] ~= nil);
end

function ArenaMatch:TryFixLastRating(match)
    assert(match);

    if(not ArenaMatch:DoesRequireRatingFix(match)) then
        return;
    end

    local trackedSeasonPlayed = ArenaMatch:GetSeasonPlayed(match);
    Debug:Log("Attempting rating fix for last match..", trackedSeasonPlayed, ArenaMatch:GetBracket(match));
    if(not trackedSeasonPlayed) then
        return;
    end

    local season = ArenaMatch:GetSeason(match);
    local currentSeason = API:GetCurrentSeason();
    if(season and currentSeason and currentSeason > 0 and season ~= currentSeason) then
        -- Season appears to have changed, too late to fix last rating.
        ArenaMatch:ClearTransientValues(match);
        Debug:Log("Rating fix cancelled - Incorrect season:", season, "current:", currentSeason);
        return;
    end

    Debug:Log("TryFixLastRating:", trackedSeasonPlayed, currentSeason);

    local bracketIndex = ArenaMatch:GetBracketIndex(match);
    local currentSeasonPlayed = API:GetSeasonPlayed(bracketIndex);

    if(not currentSeasonPlayed or currentSeasonPlayed < trackedSeasonPlayed) then
        Debug:Log("ArenaMatch: Rating fix delayed - Season Played.", bracketIndex, currentSeasonPlayed, trackedSeasonPlayed);
        return;
    end

    local newRating, oldRating = ArenaRatedInfo:GetRatedInfo(bracketIndex, trackedSeasonPlayed);
    if(not newRating) then
        if(currentSeasonPlayed > trackedSeasonPlayed) then
            -- Lacking data, and already passed the match. We cannot recover.
            ArenaMatch:ClearTransientValues(match);
            Debug:Log("Rating fix cancelled - Outdated season played:", trackedSeasonPlayed, "current:", currentSeasonPlayed);
            return;
        end

        Debug:Log("Rating fix delayed - Missing new rating still.");
        return; -- No data found to fix rating
    end

    oldRating = oldRating or ArenaMatch:GetPartyRating(match);
    local delta = oldRating and newRating - oldRating;

    ArenaMatch:SetPartyRating(match, newRating);
    ArenaMatch:SetPartyRatingDelta(match, delta);

    -- Clear transient values
    ArenaMatch:ClearTransientValues(match);

    Debug:Log("Fixed last rating:", ArenaMatch:GetBracket(match), newRating, oldRating, currentSeasonPlayed);
end

-------------------------------------------------------------------------
-- Date (1)

function ArenaMatch:GetDate(match)
    if(not match) then 
        return nil 
    end;

    local key = matchKeys.date;
    return match and tonumber(match[key]);
end

function ArenaMatch:SetDate(match, value)
    assert(match);

    local key = matchKeys.date;
    match[key] = ToPositiveNumber(value);
end

-------------------------------------------------------------------------
-- Duration (2)

function ArenaMatch:GetDuration(match)
    if(not match) then
        return nil;
    end

    local key = matchKeys.duration;
    return match and tonumber(match[key]);
end

function ArenaMatch:SetDuration(match, value)
    assert(match);

    local key = matchKeys.duration;
    match[key] = ToPositiveNumber(value);
end

-------------------------------------------------------------------------
-- Map (3)

function ArenaMatch:GetMapID(match)
    if(not match) then 
        return nil 
    end;

    local key = matchKeys.map;
    local value = match and match[key];

    -- Table implies saved map is invalid or Game Map ID
    if(type(value) == "table") then
        if(value.raw) then
            -- Check for map_id from an arbitrary raw value
            local map_id = tonumber(Internal:GetAddonMapID(value.raw));
            if(map_id) then
                match[key] = map_id;
                return map_id;
            end
        else
            match[key] = nil;
        end

        return nil;
    end

    return tonumber(value);
end

function ArenaMatch:GetMap(match, useShortName)
    local map_id = ArenaMatch:GetMapID(match);
    if(not map_id) then
        return nil;
    end

    if(useShortName) then
        local map = Internal:GetShortMapName(map_id);
        if(map) then
            return map;
        end

        Debug:Log("ArenaMatch failed to get short name for map_id:", map_id);
    end

    return Internal:GetMapName(map_id);
end

function ArenaMatch:SetMap(match, value)
    assert(match);

    if(not value or value == 0) then
        return;
    end

    local map_id = Internal:GetAddonMapID(value);
    if(map_id) then
        match[matchKeys.map] = tonumber(map_id);
    else
        Debug:LogError("ArenaMatch:SetMap failed to find map_id for value:", value);

        -- Store raw value to fix later
        match[matchKeys.map] = { raw=value };
    end
end

-------------------------------------------------------------------------
-- Bracket (4)

function ArenaMatch:GetBracketIndex(match)
    if(not match) then 
        return nil 
    end;
    
    local key = matchKeys.bracket;
    return match and tonumber(match[key]);
end

function ArenaMatch:GetBracket(match)
    if(not match) then 
        return nil 
    end;

    local bracketIndex = ArenaMatch:GetBracketIndex(match);
    return ArenaAnalytics:GetBracket(bracketIndex);
end

function ArenaMatch:IsShuffle(match)
    return match and ArenaMatch:GetBracketIndex(match) == 4;
end

function ArenaMatch:SetBracketIndex(match, index)
    assert(match);

    local key = matchKeys.bracket;
    match[key] = tonumber(index);
end

function ArenaMatch:SetBracket(match, value)
    assert(match);
    local key = matchKeys.bracket;
    match[key] = ArenaAnalytics:GetAddonBracketIndex(value);
end

-------------------------------------------------------------------------
-- Match Type (5)

-- rated, skirmish or wargame
function ArenaMatch:GetMatchType(match)
    if(not match) then 
        return nil 
    end;

    local typeIndex = match and tonumber(match[matchKeys.match_type]);
    return ArenaAnalytics:GetMatchType(typeIndex);
end

function ArenaMatch:IsRated(match)
    return match and tonumber(match[matchKeys.match_type]) == 1;
end

function ArenaMatch:SetMatchType(match, value)
    assert(match);
    local key = matchKeys.match_type;
    match[key] = ArenaAnalytics:GetAddonMatchTypeIndex(value);
end

-------------------------------------------------------------------------
-- Party Rating (6)

function ArenaMatch:GetPartyRating(match)
    if(not match) then 
        return nil 
    end;
    
    local key = matchKeys.rating;
    return match and tonumber(match[key]);
end

function ArenaMatch:SetPartyRating(match, value)
    assert(match);

    local key = matchKeys.rating;
    match[key] = ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Party Rating Delta (7)

function ArenaMatch:GetPartyRatingDelta(match)
    if(not match) then
        return nil;
    end

    local key = matchKeys.rating_delta;
    return match and tonumber(match[key]);
end

function ArenaMatch:SetPartyRatingDelta(match, value)
    assert(match);

    match[matchKeys.rating_delta] = tonumber(value);
end

-------------------------------------------------------------------------
-- Party MMR (8)

function ArenaMatch:GetPartyMMR(match)
    local key = matchKeys.mmr;
    return match and tonumber(match[key]);
end

function ArenaMatch:SetPartyMMR(match, value)
    assert(match);

    local key = matchKeys.mmr;
    match[key] = ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Enemy Rating (9)

function ArenaMatch:GetEnemyRating(match)
    if(not match) then
        return nil;
    end

    local key = matchKeys.enemy_rating;
    return match and tonumber(match[key]);
end

function ArenaMatch:SetEnemyRating(match, value)
    assert(match);

    local key = matchKeys.enemy_rating;
    match[key] = ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Enemy Rating Delta (10)

function ArenaMatch:GetEnemyRatingDelta(match)
    if(not match) then 
        return nil 
    end;

    local key = matchKeys.enemy_rating_delta;
    return match and tonumber(match[key]);
end

function ArenaMatch:SetEnemyRatingDelta(match, value)
    assert(match);

    local key = matchKeys.enemy_rating_delta;
    match[key] = tonumber(value);
end

-------------------------------------------------------------------------
-- Enemy MMR (11)

function ArenaMatch:GetEnemyMMR(match)
    local key = matchKeys.enemy_mmr;
    return match and tonumber(match[key]);
end

function ArenaMatch:SetEnemyMMR(match, value)
    assert(match);
    match[matchKeys.enemy_mmr] = ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Season (12) and Season Played (19)

function ArenaMatch:GetSeason(match)
    if(not match) then 
        return nil 
    end;

    return tonumber(match[matchKeys.season]);
end

function ArenaMatch:SetSeason(match, value)
    assert(match);
    match[matchKeys.season] = ToPositiveNumber(value, true);
end


function ArenaMatch:GetSeasonPlayed(match)
    return match and tonumber(match[matchKeys.seasonPlayed]);
end

function ArenaMatch:SetSeasonPlayed(match, value)
    assert(match);
    match[matchKeys.seasonPlayed] = ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Session (13)

function ArenaMatch:GetSession(match)
    if(not match) then
        return nil;
    end

    return tonumber(match[matchKeys.session]);
end

function ArenaMatch:SetSession(match, value)
    assert(match);
    match[matchKeys.session] = ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Victory (14)

function ArenaMatch:GetMatchOutcome(match)
    return match and tonumber(match[matchKeys.outcome]);
end

function ArenaMatch:IsVictory(match)
    local outcome = ArenaMatch:GetMatchOutcome(match);
    return outcome ~= nil and (outcome == 1);
end

function ArenaMatch:IsDraw(match)
    local outcome = ArenaMatch:GetMatchOutcome(match);
    return outcome ~= nil and (outcome == 2);
end

function ArenaMatch:IsLoss(match)
    local outcome = ArenaMatch:GetMatchOutcome(match);
    return outcome ~= nil and (outcome == 0);
end

function ArenaMatch:SetMatchOutcome(match, value)
    assert(match);

    -- 0 = loss, 1 = win, 2 = draw, nil = unknown. 
    match[matchKeys.outcome] = ToNumericalOutcome(value, 2);
end

-------------------------------------------------------------------------
-- Team (17)

local function SetPlayerValue(match, player, key, value)
    assert(match and player);

    -- Convert the key
    key = key and playerKeys[key];
    assert(key);

    if(value ~= nil) then
        player[key] = value;
    end
end

function ArenaMatch:AddPlayers(match, players)
    assert(match)
    assert(players);

    for _,player in ipairs(players) do
        ArenaMatch:AddPlayer(match, player);
    end

    if(not ArenaMatch:IsShuffle(match)) then
        ArenaMatch:UpdateComps(match);
    end

    ArenaMatch:SortGroups(match);
end

function ArenaMatch:AddPlayer(match, player)
    assert(match);

    if(not player) then
        return;
    end

    if(player.name ~= nil) then
        local name, realm = strsplit('-', player.name);
        player.name = name;
        player.realm = realm;
    else
        Debug:Log("Warning: Adding player to stored match without name!");
    end

    local newPlayer = ArenaMatch:MakeCompactPlayerData(player);

    local teamKey = player.isEnemy and matchKeys.enemy_team or matchKeys.team;
    match[teamKey] = match[teamKey] or {};
    tinsert(match[teamKey], newPlayer);
end

local function CompressPlayerKeys(player, keys)
    local values = {}
    local emptyCount = 0;

    for _,key in ipairs(keys) do
        if(tonumber(player[key])) then
            if(emptyCount > 0) then
                -- One separator will be added at concat time. Add all but one of the missing ones here.                
                local missingSeparators = (emptyCount == 1) and "" or string.rep('|', emptyCount-1);
                tinsert(values, missingSeparators);
                emptyCount = 0;
            end

            tinsert(values, tonumber(player[key]));
        else
            emptyCount = emptyCount + 1;
        end
    end

    -- Add the stats, if we found any
    if(#values == 0) then
        return nil;
    end

    return table.concat(values, '|');
end

function ArenaMatch:MakeCompactPlayerData(player)
    if(not player) then
        return nil;
    end

    local name = player.name and ArenaAnalytics:GetNameIndex(player.name);
    local realm = player.realm and ArenaAnalytics:GetRealmIndex(player.realm);

    if(not player.name and not player.realm) then
        --return nil;
    end

    local newPlayer = {
        [playerKeys.name] = tonumber(name),
        [playerKeys.realm] = tonumber(realm),
        [playerKeys.race] = tonumber(player.race),
        [playerKeys.spec] = tonumber(player.spec),
        [playerKeys.role] = Internal:GetRoleBitmap(player.spec),
        [playerKeys.is_self] = player.isSelf and 1 or nil,
        [playerKeys.is_first_death] = player.isFirstDeath and 1 or nil,
        [playerKeys.is_female] = ToNumericalBool(player.isFemale),
    };

    local ratedInfoKeys = {
        "rating",
        "ratingDelta",
        "mmr",
        "mmrDelta",
    }

    local statsKeys = {
        "kills",
        "deaths",
        "damage",
        "healing",
    };

    newPlayer[playerKeys.rated_info] = CompressPlayerKeys(player, ratedInfoKeys);
    newPlayer[playerKeys.stats] = CompressPlayerKeys(player, statsKeys);

    -- Add support for compact bg variable stats values? (Arena/BG mode specific order)
    newPlayer[playerKeys.variable_stats] = player.wins;

    return newPlayer;
end

-- Returns true if a value is set
function ArenaMatch:SetTeamMemberValue(match, isEnemyTeam, indexedFullName, key, value)
    assert(match and indexedFullName);

    key = key and playerKeys[key];
    assert(key, "SetTeamMemberValue: Invalid playerKey provided.");

    if(not indexedFullName) then
        return;
    end

    local team = ArenaMatch:GetTeam(match, isEnemyTeam);
    if(not team) then
        return;
    end

    for i,player in ipairs(team) do
        if(ArenaMatch:IsSamePlayer(player, indexedFullName)) then
            player[key] = value;
            return true;
        end
    end
end

function ArenaMatch:IsSamePlayer(player, indexedFullName)
    assert(player and indexedFullName);

    local name = player[playerKeys.name];
    local realm = player[playerKeys.realm];

    local otherName, otherRealm;
    if(type(indexedFullName) == "string") then
        otherName, otherRealm = ArenaAnalytics:SplitFullName(indexedFullName, true);
    else
        otherName = tonumber(indexedFullName);
    end

    if(not name or name ~= otherName) then
        return false;
    end

    if(otherRealm and otherRealm ~= realm) then
        return false;
    end

    return true;
end

function ArenaMatch:IsLocalPlayer(player)
    assert(player);

    local localFullName = API:GetPlayerName();
    local fullName = ArenaMatch:GetPlayerFullName(player);
    return fullName and fullName == localFullName;
end

function ArenaMatch:GetMMR(match, isEnemyTeam)
    local key = isEnemyTeam and matchKeys.enemy_mmr or matchKeys.mmr;
    return match and key and tonumber(match[key]);
end

function ArenaMatch:GetTeam(match, isEnemyTeam)
    local key = isEnemyTeam and matchKeys.enemy_team or matchKeys.team;
    return match and key and match[key] or {};
end

function ArenaMatch:GetTeamSize(match, isSessionTeamCheck)
    if(not match) then
        return nil;
    end

    local bracketIndex = ArenaMatch:GetBracketIndex(match);
    if(isSessionTeamCheck and bracketIndex == 4) then
        return 1; -- Session checks only care of the stored team size being 1 for shuffles
    end

    return ArenaAnalytics:getTeamSizeFromBracketIndex(bracketIndex);
end

function ArenaMatch:GetPlayerCount(match)
    if(not match) then
        return 0;
    end

    local team = ArenaMatch:GetTeam(match, false);
    local enemy = ArenaMatch:GetTeam(match, true);

    if(not team) then
        return enemy and #enemy or 0;
    end

    if(not enemy) then
        return #team;
    end

    return #team + #enemy;
end

function ArenaMatch:GetPlayer(match, isEnemyTeam, index)
    assert(index);

    if(not match or index < 1) then
        return nil;
    end

    local team = ArenaMatch:GetTeam(match, isEnemyTeam);

    if(not team or index > #team) then
        return nil;
    end

    return team[index];
end

function ArenaMatch:GetPlayerInfo(player)
    if(not player) then
        return nil;
    end

    -- Initialize or update an existing table for player info
    local playerInfo = TablePool:Acquire();

    playerInfo.name = player[playerKeys.name];
    playerInfo.realm = player[playerKeys.realm];
    playerInfo.fullName = ArenaMatch:GetPlayerFullName(player, false, false);
    playerInfo.race = ArenaMatch:GetPlayerRace(player);
    playerInfo.spec = ArenaMatch:GetPlayerSpec(player);
    playerInfo.role = ArenaMatch:GetPlayerRole(player);

    -- Fix role in case it's missing
    if(not playerInfo.role and playerInfo.spec) then
        player[playerKeys.role] = Internal:GetRoleBitmap(playerInfo.spec);
        playerInfo.role = player[playerKeys.role];
    end

    -- Expand role
    playerInfo.role_main = Bitmap:GetMainRole(playerInfo.role);
    playerInfo.role_sub = Bitmap:GetSubRole(playerInfo.role);

    -- Expand bitmask (isFirstDeath, isEnemy, isSelf, isFemale)
    for key,index in pairs(Constants.playerFlags) do
        assert(key and tonumber(index), "Invalid flag in Constants.playerFlags!");
        --playerInfo[key] = playerInfo.bitmask and Bitmap:HasBitByIndex(playerInfo.bitmask, index) or nil;
    end

    return playerInfo;
end

function ArenaMatch:GetPlayerValue(player, key)
    if(not player or not key) then 
        return nil;
    end

    if(key == "full_name") then
        return ArenaMatch:GetPlayerFullName(player);
    end

    local playerKey = playerKeys[key];
    return playerKey and tonumber(player[playerKey]) or player[playerKey];
end

function ArenaMatch:GetPlayerRace(player)
    return player and tonumber(player[playerKeys.race]);
end

function ArenaMatch:GetPlayerSpec(player)
    return player and tonumber(player[playerKeys.spec]);
end

function ArenaMatch:GetPlayerRole(player)
    return player and tonumber(player[playerKeys.role]);
end

-- Rating, RatingDelta, Mmr, MmrDelta
function ArenaMatch:GetPlayerRatedInfo(player)
    if(not player) then
        return nil;
    end

    local ratedInfo = player[playerKeys.rated_info];
    if(not ratedInfo) then
        return nil;
    end

    local rating, ratingDelta, mmr, mmrDelta = strsplit('|', ratedInfo, 5);
    return tonumber(rating), tonumber(ratingDelta), tonumber(mmr), tonumber(mmrDelta);
end

-- Kills, Deaths, Damage, Healing
function ArenaMatch:GetPlayerStats(player)
    if(not player) then
        return nil;
    end

    local stats = player[playerKeys.stats];
    if(not stats) then
        return nil;
    end

    local kills, deaths, damage, healing = strsplit('|', stats, 5);
    return tonumber(kills), tonumber(deaths), tonumber(damage), tonumber(healing);
end

-- NOTE: If Add data and formatting to determine mode to use when parsing the compact var stats
function ArenaMatch:GetPlayerVariableStats(player)
    if(not player) then
        return nil;
    end

    local variableStats = player[playerKeys.variable_stats];
    if(not variableStats) then
        return nil;
    end

    -- Single number or compact '|' separated string
    return tonumber(variableStats) or variableStats;
end

function ArenaMatch:GetPlayerName(player, requireCompact)
    if(not player or not player[playerKeys.name]) then
        return nil;
    end

    if(requireCompact) then
        return player[playerKeys.name];
    end

    return ArenaAnalytics:GetName(player[playerKeys.name]);
end

function ArenaMatch:GetPlayerRealm(player, requireCompact)
    if(not player or not player[playerKeys.realm]) then
        return nil;
    end

    if(requireCompact) then
        return player[playerKeys.realm];
    end

    return ArenaAnalytics:GetRealm(player[playerKeys.realm]);
end

function ArenaMatch:GetPlayerNameAndRealm(player, requireCompact)
    if(not player) then
        return nil;
    end

    local name = ArenaMatch:GetPlayerName(player, requireCompact);
    local realm = ArenaMatch:GetPlayerRealm(player, requireCompact);
    return name, realm;
end

function ArenaMatch:GetPlayerFullName(player, hideLocalRealm, requireCompact)
    if(not player) then
        return nil;
    end

    local name = player[playerKeys.name] or 0;
    local realm = player[playerKeys.realm];

    if(hideLocalRealm and ArenaAnalytics:IsLocalRealm(realm)) then
        realm = nil;
    end

    -- Convert to string names
    if(not requireCompact) then
        name = name and ArenaAnalyticsDB.names[name] or "";

        if(realm) then
            realm = ArenaAnalyticsDB.realms[realm] or "";
        end
    end

    if(not realm) then
        return name;
    end

    local fullNameFormat = "%s-%s";
    return string.format(fullNameFormat, name, realm);
end

local function GetCompForSpecs(teamSpecs, requiredSize)
    if(not teamSpecs or not requiredSize or requiredSize == 0) then
        return nil;
    end

    if(#teamSpecs ~= requiredSize) then
        Debug:Log("GetCompForSpecs: Invalid team size.", #teamSpecs, requiredSize)
        return nil;
    end

    table.sort(teamSpecs, function(a, b)
        return a < b;
    end);

    return table.concat(teamSpecs, '|');
end

function ArenaMatch:GetComp(match, isEnemyTeam)
    local key = isEnemyTeam and matchKeys.enemy_comp or matchKeys.comp;
    return match and key and match[key];
end

function ArenaMatch:HasComp(match, comp, isEnemyTeam)
    if(not match or not comp) then
        return false;
    end

    if(ArenaMatch:IsShuffle(match)) then
        local rounds = match[matchKeys.rounds];
        if(not rounds) then
            return nil;
        end

        for i,round in ipairs(rounds) do
            if(isEnemyTeam) then
                if(comp == round[roundKeys.enemy_comp]) then
                    return true;
                end
            elseif(comp == round[roundKeys.comp]) then
                return true;
            end
        end

        return false;
    end

    return comp == ArenaMatch:GetComp(match, isEnemyTeam);
end

-- Returns the comp, outcome and mmr values for the match or round 
function ArenaMatch:GetCompInfo(match, isEnemyTeam, roundIndex)
    if(not match) then
        return nil;
    end

    local mmr = ArenaMatch:GetMMR(match, isEnemyTeam);

    if(ArenaMatch:IsShuffle(match)) then
        if(not roundIndex) then
            Debug:Log("ArenaMatch:GetCompInfo called for a shuffle without provided round index!");
            return;
        end

        local rounds = match[matchKeys.rounds];
        local round = rounds and rounds[roundIndex];
        if(not round) then
            return nil;
        end

        local comp = ArenaMatch:GetRoundComp(round, isEnemyTeam);
        local outcome = select(5, ArenaMatch:GetRoundData(round));
        return comp, outcome, mmr;
    else
        local comp = ArenaMatch:GetComp(match, isEnemyTeam);
        local outcome = ArenaMatch:GetMatchOutcome(match);
        return comp, outcome, mmr;
    end
end

function ArenaMatch:UpdateComps(match)
    assert(match);

    ArenaMatch:UpdateComp(match, false);
    ArenaMatch:UpdateComp(match, true);
end

function ArenaMatch:UpdateComp(match, isEnemyTeam)
    assert(match);

    if(ArenaMatch:IsShuffle(match)) then
        return;
    end

    local key = isEnemyTeam and matchKeys.enemy_comp or matchKeys.comp;
    if(not Debug:Assert(key)) then
        return;
    end

    local team = ArenaMatch:GetTeam(match, isEnemyTeam);
    local requiredTeamSize = ArenaMatch:GetTeamSize(match);

    local teamSpecs = ArenaMatch:GetTeamSpecs(team, requiredTeamSize);

    local oldComp = match[key];
    match[key] = GetCompForSpecs(teamSpecs, requiredTeamSize);

    if(oldComp ~= match[key]) then
        Debug:Log("Assigned comp to match:", match[key], "Old Comp:", oldComp, "IsEnemy:", isEnemyTeam);
    end

    TablePool:Release(teamSpecs);
end

function ArenaMatch:GetTeamSpecs(team, requiredSize)
    if(not team or not requiredSize or requiredSize == 0) then
        return nil;
    end

    if(#team ~= requiredSize) then
        return nil;
    end

    local teamSpecs = TablePool:Acquire();

    -- Gather all team specs, bailing out if any are missing
    for i,player in ipairs(team) do
        local spec_id = ArenaMatch:GetPlayerSpec(player);
        if(not Helpers:IsSpecID(spec_id)) then
            TablePool:Release(teamSpecs);
            return nil;
        end

        tinsert(teamSpecs, spec_id);
    end

    return teamSpecs;
end

-------------------------------------------------------------------------
-- First Death

function ArenaMatch:IsPlayerFirstDeath(player)
    return player and player[playerKeys.is_first_death] or false;
end

-------------------------------------------------------------------------
-- Gender

function ArenaMatch:IsPlayerFemale(player)
    Debug:LogTemp("ArenaMatch:IsPlayerFemale", player, playerKeys.is_female, player[playerKeys.is_female])
    return player and player[playerKeys.is_female];
end

-------------------------------------------------------------------------
-- Self

function ArenaMatch:IsPlayerSelf(player)
    return player and player[playerKeys.is_self] or false;
end

function ArenaMatch:HasSelf(match)
    if(not match) then
        return false;
    end

    local team = ArenaMatch:GetTeam(match, false);
    if(team) then
        for _,player in ipairs(team) do
            if(ArenaMatch:IsPlayerSelf(player)) then
                return true;
            end
        end
    end

    return false;
end

function ArenaMatch:GetSelf(match, fallbackToLocal)
    if(not match) then 
        return nil;
    end

    local team = ArenaMatch:GetTeam(match, false);
    if(team) then
        for i,player in ipairs(team) do
            if(ArenaMatch:IsPlayerSelf(player)) then
                return player;
            elseif(fallbackToLocal and ArenaMatch:IsLocalPlayer(player)) then
                return player;
            end
        end
    end

    return nil;
end

-- Returns the player info of self
function ArenaMatch:GetSelfInfo(match, fallbackToLocal)
    if(not match) then 
        return nil;
    end

    local player = ArenaMatch:GetSelf(match, fallbackToLocal);
    local playerInfo = ArenaMatch:GetPlayerInfo(player);

    if(not playerInfo and fallbackToLocal) then
        -- Make self info from local player
        return ArenaAnalytics:GetLocalPlayerInfo();
    end

    return playerInfo;
end

function ArenaMatch:SetSelf(match, fullName)
    assert(match);
    if(not fullName) then
        return;
    end

    assert(type(fullName) == "string", "Provided fullName must be a string.");

    local fullName = ArenaAnalytics:GetIndexedFullName(fullName);
    local result = ArenaMatch:SetTeamMemberValue(match, false, fullName, "is_self", 1);
    return result;
end

-------------------------------------------------------------------------
-- Player Value Search Checks

-- Smart player name check
function ArenaMatch:CheckPlayerName(player, searchValue, isExact)
    if(not player or not searchValue) then
        return false;
    end

    local fullName;
    if(searchValue:find('-', 1, true)) then
        local name = ArenaAnalytics:GetName(player[playerKeys.name]);
        local realm = ArenaAnalytics:GetRealm(player[playerKeys.realm]);
        fullName = (name or "") .. '-' .. (realm or "");
    else
        fullName = ArenaAnalytics:GetName(player[playerKeys.name]);
    end

    if(not fullName) then
        return false;
    end

    fullName = fullName:lower();

    if(searchValue == fullName) then
        return true;
    end

    -- Check partial match
    return not isExact and fullName:find(searchValue, 1, true) ~= nil;
end

-------------------------------------------------------------------------
-- Solo Shuffle

-- Set rounds data
function ArenaMatch:SetRounds(match, rounds)
    assert(match);
    assert(not match[matchKeys.rounds]);

    if(not rounds or #rounds == 0) then
        Debug:Log("ArenaMatch:SetRounds bailing out due to invalid incoming rounds:", rounds and #rounds);
        return;
    end

    -- Only solo shuffle supports multiple rounds
    if(not ArenaMatch:IsShuffle(match)) then
        Debug:Log("ArenaMatch:SetRounds skipping shuffle match type.", ArenaMatch:GetBracket(match));
        return;
    end

    Debug:LogGreen("Setting shuffle rounds for match.", #rounds);

    ArenaMatch:SortGroups(match);

    local enemyTeam = ArenaMatch:GetTeam(match, true);

    -- Must already have players, to compact round data
    if(not Debug:Assert(enemyTeam and #enemyTeam > 0)) then
        return;
    end

    match[matchKeys.rounds] = TablePool:Acquire();

    -- Cache values to help sort
    local myName = API:GetPlayerName();
    local selfPlayerInfo = ArenaMatch:GetSelfInfo(match, true);
    local requiredTeamSize = ArenaMatch:GetTeamSize(match);

    -- Fill player name to index mapping
    local indexMapping = TablePool:Acquire();

    -- Add self
    indexMapping[myName] = 0;

    for index, player in ipairs(enemyTeam) do
        local fullName = ArenaMatch:GetPlayerFullName(player);
        if(fullName and fullName ~= "" and fullName ~= myName) then
            indexMapping[fullName] = index;
        end
    end

    local function compressGroup(group)
        if(not group or #group == 0) then
            return nil;
        end

        local compactGroup = TablePool:Acquire();
        local specs = TablePool:Acquire();

        for _,member in ipairs(group) do
            local spec_id = nil;
            local playerIndex = member and indexMapping[member] or nil;
            local player = nil;

            if(member == myName) then
                player = ArenaMatch:GetSelf(match);
            elseif(playerIndex) then
                player = enemyTeam[playerIndex];
                tinsert(compactGroup, playerIndex);
            end

            -- Add spec for comp
            local spec_id = ArenaMatch:GetPlayerSpec(player);
            if(Helpers:IsSpecID(spec_id)) then
                tinsert(specs, spec_id);
            end
        end

        GroupSorter:SortIndexGroup(compactGroup, enemyTeam, selfPlayerInfo);
        local groupString = table.concat(compactGroup) or "";
        local comp = GetCompForSpecs(specs, requiredTeamSize);

        TablePool:Release(compactGroup);
        TablePool:Release(specs);

        return groupString, comp;
    end

    for i,round in ipairs(rounds) do
        local team, comp = compressGroup(round.team);
        local enemy, enemyComp = compressGroup(round.enemy);
        local death = round.firstDeath and indexMapping[round.firstDeath];

        -- Insert the round to the match (team-enemy-death-duration)
        local compactRound = {
            [roundKeys.data] = ArenaMatch:MakeRoundData(team, enemy, death, round.duration, round.outcome),
            [roundKeys.comp] = comp,
            [roundKeys.enemy_comp] = enemyComp,
        };

        tinsert(match[matchKeys.rounds], compactRound);
    end
end

function ArenaMatch:MakeRoundData(team, enemy, death, duration, outcome)
    return (team or "") .. '|' .. (enemy or "") .. '|' .. (death or "") .. '|' .. (duration or "") .. "|" .. (outcome or "");
end

function ArenaMatch:GetRounds(match)
    return match and match[matchKeys.rounds] or nil;
end

function ArenaMatch:GetRoundDataRaw(round)
    return round and round[roundKeys.data];
end

function ArenaMatch:GetRoundData(round)
    local data = ArenaMatch:GetRoundDataRaw(round);
    return ArenaMatch:SplitRoundData(data);
end

function ArenaMatch:SplitRoundData(data)
    if(not data) then
        return nil;
    end

    -- 5 values: team, enemy, death, duration, outcome
    local team, enemy, death, duration, outcome = strsplit('|', data);
    return team, enemy, tonumber(death), tonumber(duration), tonumber(outcome);
end

function ArenaMatch:GetRoundComp(round, isEnemyComp)
    local compKey = isEnemyComp and roundKeys.enemy_comp or roundKeys.comp;
    return round and compKey and round[compKey];
end

-------------------------------------------------------------------------
-- Player Sorting

-- Smart resort, fixing indicies stored per round
function ArenaMatch:ResortPlayers(match)
    -- If map is not solo shuffle, do standard sorting
    if(not ArenaMatch:IsShuffle(match)) then
        ArenaMatch:SortGroups(match);
        return;
    end

    -- Fill old index to player name mapping
    local enemyTeam = ArenaMatch:GetTeam(match, true);
    local oldNameOrder = {}

    if(enemyTeam) then
        for i,player in ipairs(enemyTeam) do
            player.oldIndex = i;
        end
    end

    -- Sort match enemies
	local selfPlayerInfo = ArenaMatch:GetSelfInfo(match);
    GroupSorter:SortGroup(enemyTeam, selfPlayerInfo);

    local rounds = ArenaMatch:GetRounds(match);

    -- No rounds to fix
    if(not rounds) then
        return;
    end

    -- Fill old index to new index mapping
    local indexMapping = {}

    if(enemyTeam) then
        for newIndex,player in ipairs(enemyTeam) do
            local oldIndex = player and player.oldIndex;
            if(oldIndex) then
                indexMapping[oldIndex] = newIndex;
                player.oldIndex = nil; -- Clear temporary tag
            else
                Debug:Log("ERROR: Failed to retrieve old index for player! Sorting is likely to have broken the match data!");
                assert(false); -- Force the addon to crash, preventing it from saving the match wrongly
            end
        end
    end

    local function ConvertPlayerIndices(string, requireSort)
        if(not string or string == "") then
            return "";
        end

        string = tostring(string);

        local values = {}
        for i=1, #string do
            local char = string:sub(i,i);
            local oldIndex = tonumber(char);

            local newValue = nil;

            if(oldIndex == 0) then
                newValue = 0;
            else
                newValue = oldIndex and indexMapping[oldIndex];
                if(not newValue) then
                    if(not tonumber(char)) then
                        newValue = char;
                    end
                end
            end

            if(newValue) then
                tinsert(values, newValue);
            end
        end

        if(requireSort) then
            GroupSorter:SortIndexGroup(values, enemyTeam, selfPlayerInfo);
        end

        return table.concat(values);
    end

    -- Update round groups to new index
    for _,round in ipairs(rounds) do
        local team, enemy, death, duration, outcome = ArenaMatch:GetRoundData(round);

        team = ConvertPlayerIndices(team, true);
        enemy = ConvertPlayerIndices(enemy, true);
        death = ConvertPlayerIndices(death);

        round[roundKeys.data] = ArenaMatch:MakeRoundData(team, enemy, death, duration, outcome);
    end
end

function ArenaMatch:SortGroups(match)
    assert(match);

	local selfPlayerInfo = ArenaMatch:GetSelfInfo(match, true);

    local team = ArenaMatch:GetTeam(match, false);
    GroupSorter:SortGroup(team, selfPlayerInfo);

    local enemyTeam = ArenaMatch:GetTeam(match, true);
    GroupSorter:SortGroup(enemyTeam, selfPlayerInfo);
end
