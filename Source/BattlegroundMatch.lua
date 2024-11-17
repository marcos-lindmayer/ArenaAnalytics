local _, ArenaAnalytics = ...; -- Addon Namespace
local BattlegroundMatch = ArenaAnalytics.BattlegroundMatch;

-- Local module aliases
local Constants = ArenaAnalytics.Constants;
local Bitmap = ArenaAnalytics.Bitmap;
local Helpers = ArenaAnalytics.Helpers;
local Internal = ArenaAnalytics.Internal;
local GroupSorter = ArenaAnalytics.GroupSorter;
local API = ArenaAnalytics.API;
local Search = ArenaAnalytics.Search;
local TablePool = ArenaAnalytics.TablePool;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------

local matchKeys = {
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
    statMapping = -14,
    players = -15,

    transient_seasonPlayed = -100,
    transient_requireRatingFix = -101,
}

local playerKeys = {
    name = 0,
    realm = -1,
    race = -2,
    spec = -3,
    role = -4,
    is_self = -5,
    is_enemy = -6,
    is_party = -7,
    rated_info = -8,
    stats = -9,
    variable_stats = -10, -- Game mode specific stats (Flag capture, flag returns, etc)
};

-------------------------------------------------------------------------
-- Rating fixup

function BattlegroundMatch:ClearTransientValues(match)
    assert(match);

    match[matchKeys.transient_seasonPlayed] = nil;
    match[matchKeys.transient_requireRatingFix] = nil;
end

function BattlegroundMatch:SetTransientSeasonPlayed(match, value)
    assert(match);
    ArenaAnalytics:Log("Assigning transient season played value:", value, "from:", match[matchKeys.transient_seasonPlayed]);
    match[matchKeys.transient_seasonPlayed] = tonumber(value);
end

function BattlegroundMatch:GetSeasonPlayed(match)
    return match and match[matchKeys.transient_seasonPlayed]
end

function BattlegroundMatch:SetRequireRatingFix(match, value)
    assert(match);
    ArenaAnalytics:Log("SetRequireRatingFix:", value, "from:", match[matchKeys.transient_requireRatingFix]);
    match[matchKeys.transient_requireRatingFix] = value and true or nil;
end

function BattlegroundMatch:DoesRequireRatingFix(match)
    return match and (match[matchKeys.transient_requireRatingFix] ~= nil);
end

function BattlegroundMatch:TryFixLastRating(match)
    assert(match);

    if(not BattlegroundMatch:DoesRequireRatingFix(match)) then
        return;
    end

    local trackedSeasonPlayed = tonumber(match[matchKeys.transient_seasonPlayed]);
    if(not trackedSeasonPlayed) then
        return;
    end

    local season = BattlegroundMatch:GetSeason(match);
    local currentSeason = GetCurrentArenaSeason();
    if(currentSeason and currentSeason > 0 and season and season ~= currentSeason) then
        -- Season appears to have changed, too late to fix last rating.
        BattlegroundMatch:ClearTransientValues(match);
        return;
    end

    local bracketIndex = BattlegroundMatch:GetBracketIndex(match);
    local newRating,seasonPlayed = API:GetPersonalRatedInfo(bracketIndex);
    if(not seasonPlayed or (seasonPlayed - 1) < trackedSeasonPlayed) then
        ArenaAnalytics:Log("BattlegroundMatch: Delaying rating fix - Season Played.", seasonPlayed, bracketIndex, trackedSeasonPlayed);
        return;
    end

    if((seasonPlayed - 1) == trackedSeasonPlayed) then
        if(newRating) then
            -- Fix rating
            local oldRating = BattlegroundMatch:GetPartyRating(match);
            local delta = oldRating and newRating - oldRating;

            ArenaAnalytics:Log("BattlegroundMatch: Fixing rating from:", oldRating, "to:", newRating, delta);

            BattlegroundMatch:SetPartyRating(match, newRating);
            BattlegroundMatch:SetPartyRatingDelta(match, delta);
        end
    end

    -- Clear transient values
    BattlegroundMatch:ClearTransientValues(match);
end

-------------------------------------------------------------------------
-- Date (1)

function BattlegroundMatch:GetDate(match)
    if(not match) then 
        return nil 
    end;
    
    local key = matchKeys.date;
    return match and tonumber(match[key]);
end

function BattlegroundMatch:SetDate(match, value)
    assert(match);

    local key = matchKeys.date;
    match[key] = Helpers:ToPositiveNumber(value);
end

-------------------------------------------------------------------------
-- Duration (2)

function BattlegroundMatch:GetDuration(match)
    if(not match) then
        return nil;
    end

    local key = matchKeys.duration;
    return match and tonumber(match[key]);
end

function BattlegroundMatch:SetDuration(match, value)
    assert(match);

    local key = matchKeys.duration;
    match[key] = Helpers:ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Map (3)

function BattlegroundMatch:GetMapID(match)
    if(not match) then 
        return nil 
    end;

    local key = matchKeys.map;
    return match and tonumber(match[key]);
end

function BattlegroundMatch:GetMap(match, useShortName)
    local map_id = BattlegroundMatch:GetMapID(match);
    if(not map_id) then
        return nil;
    end

    if(useShortName) then
        local map = Internal:GetShortMapName(map_id);
        if(map) then
            return map;
        end

        ArenaAnalytics:Log("BattlegroundMatch failed to get short name for map_id:", map_id);
    end

    return Internal:GetMapName(map_id);
end

function BattlegroundMatch:SetMap(match, value)
    assert(match);
    
    if(not value) then
        return;
    end

    local map_id = Internal:GetAddonMapID(value);
    if(not map_id) then
        ArenaAnalytics:Log("Warning: BattlegroundMatch:SetMap failed to find map_id for value:", value);
    end

    match[matchKeys.map] = tonumber(map_id);
    match[matchKeys.statMapping] = Internal:GetStatMapping(map_id);
end

-------------------------------------------------------------------------
-- Bracket (4)

function BattlegroundMatch:GetBracketIndex(match)
    if(not match) then 
        return nil 
    end;
    
    local key = matchKeys.bracket;
    return match and tonumber(match[key]);
end

function BattlegroundMatch:GetBracket(match)
    if(not match) then 
        return nil 
    end;

    local bracketIndex = BattlegroundMatch:GetBracketIndex(match);
    return ArenaAnalytics:GetBracket(bracketIndex);
end

function BattlegroundMatch:IsShuffle(match)
    return match and BattlegroundMatch:GetBracketIndex(match) == 4;
end

function BattlegroundMatch:SetBracketIndex(match, index)
    assert(match);

    local key = matchKeys.bracket;
    match[key] = tonumber(index);
end

function BattlegroundMatch:SetBracket(match, value)
    assert(match);
    local key = matchKeys.bracket;
    match[key] = ArenaAnalytics:GetAddonBracketIndex(value);
end

-------------------------------------------------------------------------
-- Match Type (5)

-- rated, skirmish or wargame
function BattlegroundMatch:GetMatchType(match)
    if(not match) then 
        return nil 
    end;

    local typeIndex = match and tonumber(match[matchKeys.match_type]);
    return ArenaAnalytics:GetMatchType(typeIndex);
end

function BattlegroundMatch:IsRated(match)
    return match and tonumber(match[matchKeys.match_type]) == 1;
end

function BattlegroundMatch:SetMatchType(match, value)
    assert(match);
    local key = matchKeys.match_type;
    match[key] = ArenaAnalytics:GetAddonMatchTypeIndex(value);
end

-------------------------------------------------------------------------
-- Party Rating (6)

function BattlegroundMatch:GetPartyRating(match)
    if(not match) then 
        return nil 
    end;
    
    local key = matchKeys.rating;
    return match and tonumber(match[key]);
end

function BattlegroundMatch:SetPartyRating(match, value)
    assert(match);

    local key = matchKeys.rating;
    match[key] = Helpers:ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Party Rating Delta (7)

function BattlegroundMatch:GetPartyRatingDelta(match)
    if(not match) then 
        return nil 
    end;
    
    local key = matchKeys.rating_delta;
    return match and tonumber(match[key]);
end

function BattlegroundMatch:SetPartyRatingDelta(match, value)
    assert(match);

    match[matchKeys.rating_delta] = tonumber(value);
end

-------------------------------------------------------------------------
-- Party MMR (8)

function BattlegroundMatch:GetPartyMMR(match)
    if(not match) then 
        return nil 
    end;
    
    local key = matchKeys.mmr;
    return match and tonumber(match[key]);
end

function BattlegroundMatch:SetPartyMMR(match, value)
    assert(match);

    local key = matchKeys.mmr;
    match[key] = Helpers:ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Enemy Rating (9)

function BattlegroundMatch:GetEnemyRating(match)
    if(not match) then 
        return nil 
    end;
    
    local key = matchKeys.enemy_rating;
    return match and tonumber(match[key]);
end

function BattlegroundMatch:SetEnemyRating(match, value)
    assert(match);

    local key = matchKeys.enemy_rating;
    match[key] = Helpers:ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Enemy Rating Delta (10)

function BattlegroundMatch:GetEnemyRatingDelta(match)
    if(not match) then 
        return nil 
    end;

    local key = matchKeys.enemy_rating_delta;
    return match and tonumber(match[key]);
end

function BattlegroundMatch:SetEnemyRatingDelta(match, value)
    assert(match);

    local key = matchKeys.enemy_rating_delta;
    match[key] = tonumber(value);
end

-------------------------------------------------------------------------
-- Enemy MMR (11)

function BattlegroundMatch:GetEnemyMMR(match)
    if(not match) then 
        return nil 
    end;

    return match and tonumber(match[matchKeys.enemy_mmr]);
end

function BattlegroundMatch:SetEnemyMMR(match, value)
    assert(match);
    match[matchKeys.enemy_mmr] = Helpers:ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Season (12)

function BattlegroundMatch:GetSeason(match)
    if(not match) then 
        return nil 
    end;

    return tonumber(match[matchKeys.season]);
end

function BattlegroundMatch:SetSeason(match, value)
    assert(match);
    match[matchKeys.season] = Helpers:ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Session (13)

function BattlegroundMatch:GetSession(match)
    if(not match) then 
        return nil;
    end

    return tonumber(match[matchKeys.session]);
end

function BattlegroundMatch:SetSession(match, value)
    assert(match);
    match[matchKeys.session] = Helpers:ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Victory (14)

function BattlegroundMatch:GetMatchOutcome(match)
    return match and tonumber(match[matchKeys.outcome]);
end

function BattlegroundMatch:IsVictory(match)
    local outcome = BattlegroundMatch:GetMatchOutcome(match);
    return outcome ~= nil and (outcome == 1);
end

function BattlegroundMatch:IsDraw(match)
    local outcome = BattlegroundMatch:GetMatchOutcome(match);
    return outcome ~= nil and (outcome == 2);
end

function BattlegroundMatch:IsLoss(match)
    local outcome = BattlegroundMatch:GetMatchOutcome(match);
    return outcome ~= nil and (outcome == 0);
end

function BattlegroundMatch:SetMatchOutcome(match, value)
    assert(match);

    -- 0 = loss, 1 = win, 2 = draw, nil = unknown. 
    match[matchKeys.outcome] = Helpers:ToNumericalBool(value, 2);
end

-------------------------------------------------------------------------
-- players (17)

local function SetPlayerValue(match, player, key, value)
    assert(match and player);

    -- Convert the key
    key = key and playerKeys[key];
    assert(key);

    if(value ~= nil) then
        player[key] = value;
    end
end

function BattlegroundMatch:AddPlayers(match, players)
    assert(match)
    assert(players);

    for _,player in ipairs(players) do
        BattlegroundMatch:AddPlayer(match, player);
    end

    BattlegroundMatch:SortPlayers(match);
end

function BattlegroundMatch:AddPlayer(match, player)
    assert(match);

    if(not player) then
        return;
    end

    if(player.name ~= nil) then
        local name, realm = strsplit('-', player.name);
        player.name = name;
        player.realm = realm;
    else
        ArenaAnalytics:Log("Warning: Adding player to stored match without name!");
    end

    local newPlayer = BattlegroundMatch:MakeCompactPlayerData(player, BattlegroundMatch:IsRated(match));
    
    local key = matchKeys.players;
    match[key] = match[key] or TablePool:Acquire();
    tinsert(match[key], newPlayer);
    ArenaAnalytics:Log("Added player:", #match[key]);
    Debug:LogTable(newPlayer);
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

function BattlegroundMatch:MakeCompactPlayerData(player, isRated)
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
        [playerKeys.is_party] = player.isParty and 1 or nil,
    };

    if(isRated) then
        local ratedInfoKeys = {
            "rating",
            "ratingDelta",
            "mmr",
            "mmrDelta",
        };

        newPlayer[playerKeys.rated_info] = CompressPlayerKeys(player, ratedInfoKeys);
    end

    local statsKeys = {
        "kills",
        "deaths",
        "damage",
        "healing",
    };

    newPlayer[playerKeys.stats] = CompressPlayerKeys(player, statsKeys);

    if(player.stats and #player.stats > 0) then
        newPlayer[playerKeys.variable_stats] = table.concat(player.stats, '|');
    end

    return newPlayer;
end

-- Returns true if a value is set
function BattlegroundMatch:SetPlayerValue(match, indexedFullName, key, value)
    assert(match and indexedFullName);

    key = key and playerKeys[key];
    assert(key, "SetPlayerValue: Invalid playerKey provided.");

    if(not indexedFullName) then
        return;
    end

    local players = match[matchKeys.players];
    if(not players) then
        return;
    end

    for i,player in ipairs(players) do
        if(BattlegroundMatch:IsSamePlayer(player, indexedFullName)) then
            player[key] = value;
            return true;
        end
    end
end

function BattlegroundMatch:IsSamePlayer(player, indexedFullName)
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

function BattlegroundMatch:IsLocalPlayer(player)
    assert(player);

    local localFullName = Helpers:GetPlayerName();
    local fullName = BattlegroundMatch:GetPlayerFullName(player);
    return fullName and fullName == localFullName;
end

function BattlegroundMatch:IsEnemy(player)
    return player and match[matchKeys.players] or false;
end

function BattlegroundMatch:CheckIsEnemy(player, requiredValue)
    requiredValue = requiredValue or false;
    return BattlegroundMatch:IsEnemy(player) == requiredValue;
end

function BattlegroundMatch:GetTeam(match, isEnemyTeam)
    if(not match) then
        return nil;
    end

    local players = BattlegroundMatch:GetPlayers(match);
    if(not players) then
        return nil;
    end

    local team = TablePool:Acquire();
    for _,player in ipairs(players) do
        if(BattlegroundMatch:CheckIsEnemy(player, isEnemyTeam)) then
            tinsert(team, player);
        end
    end

    return team or {};
end

function BattlegroundMatch:GetPlayers(match)
    if(not match) then
        return nil;
    end

    return match[matchKeys.players] or {};
end

function BattlegroundMatch:GetTeamSize(match, isSessionTeamCheck)
    if(not match) then
        return nil;
    end

    local bracketIndex = BattlegroundMatch:GetBracketIndex(match);
    if(isSessionTeamCheck and bracketIndex == 4) then
        return 1; -- Session checks only care of the stored team size being 1 for shuffles
    end

    return ArenaAnalytics:getTeamSizeFromBracketIndex(bracketIndex);
end

function BattlegroundMatch:GetPlayerCount(match)
    if(not match) then
        return 0;
    end

    local players = BattlegroundMatch:GetPlayers(match);
    return players and #players or 0;
end

function BattlegroundMatch:GetPlayer(match, isEnemyTeam, index)
    index = tonumber(index);
    if(not match or not index) then 
        return nil 
    end;

    local players = BattlegroundMatch:GetPlayers(match);
    return players and players[index];
end

function BattlegroundMatch:GetPlayerInfo(player)
    if(not player) then
        return nil;
    end

    -- Initialize or update an existing table for player info
    local playerInfo = TablePool:Acquire();

    playerInfo.name = player[playerKeys.name];
    playerInfo.realm = player[playerKeys.realm];
    playerInfo.fullName = BattlegroundMatch:GetPlayerFullName(player, false, false);
    playerInfo.race = BattlegroundMatch:GetPlayerRace(player);
    playerInfo.spec = BattlegroundMatch:GetPlayerSpec(player);
    playerInfo.role = BattlegroundMatch:GetPlayerRole(player);

    -- Fix role in case it's missing
    if(not playerInfo.role and playerInfo.spec) then
        player[playerKeys.role] = Internal:GetRoleBitmap(playerInfo.spec);
        playerInfo.role = player[playerKeys.role];
    end

    -- Expand role
    playerInfo.role_main = Bitmap:GetMainRole(playerInfo.role);
    playerInfo.role_sub = Bitmap:GetSubRole(playerInfo.role);
 
    -- Expand bitmask (isFirstDeath, isEnemy, isSelf)
    for key,index in pairs(Constants.playerFlags) do
        assert(key and tonumber(index), "Invalid flag in Constants.playerFlags!");
        playerInfo[key] = playerInfo.bitmask and Bitmap:HasBitByIndex(playerInfo.bitmask, index) or nil;
    end

    return playerInfo;
end

function BattlegroundMatch:GetPlayerValue(player, key)
    if(not player or not key) then 
        return nil;
    end

    if(key == "full_name") then
        return BattlegroundMatch:GetPlayerFullName(player);
    end

    local playerKey = playerKeys[key];
    return playerKey and tonumber(player[playerKey]) or player[playerKey];
end

function BattlegroundMatch:GetPlayerRace(player)
    return player and tonumber(player[playerKeys.race]);
end

function BattlegroundMatch:GetPlayerSpec(player)
    return player and tonumber(player[playerKeys.spec]);
end

function BattlegroundMatch:GetPlayerRole(player)
    return player and tonumber(player[playerKeys.role]);
end

-- Rating, RatingDelta, Mmr, MmrDelta
function BattlegroundMatch:GetPlayerRatedInfo(player)
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
function BattlegroundMatch:GetPlayerStats(player)
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
function BattlegroundMatch:GetPlayerVariableStats(player)
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

function BattlegroundMatch:GetPlayerName(player, requireCompact)
    if(not player or not player[playerKeys.name]) then
        return nil;
    end

    if(requireCompact) then
        return player[playerKeys.name];
    end

    return ArenaAnalytics:GetName(player[playerKeys.name]);
end

function BattlegroundMatch:GetPlayerRealm(player, requireCompact)
    if(not player or not player[playerKeys.realm]) then
        return nil;
    end

    if(requireCompact) then
        return player[playerKeys.realm];
    end

    return ArenaAnalytics:GetRealm(player[playerKeys.realm]);
end

function BattlegroundMatch:GetPlayerNameAndRealm(player, requireCompact)
    if(not player) then
        return nil;
    end

    local name = BattlegroundMatch:GetPlayerName(player, requireCompact);
    local realm = BattlegroundMatch:GetPlayerRealm(player, requireCompact);
    return name, realm;
end

function BattlegroundMatch:GetPlayerFullName(player, hideLocalRealm, requireCompact)
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

-------------------------------------------------------------------------
-- Self

function BattlegroundMatch:IsPlayerSelf(player)
    return player and player[playerKeys.is_self] or false;
end

function BattlegroundMatch:HasSelf(match)
    if(not match) then
        return false;
    end

    return (BattlegroundMatch:GetSelf(match) ~= nil);
end

function BattlegroundMatch:GetSelf(match, fallbackToLocal)
    if(not match) then 
        return nil;
    end

    local players = BattlegroundMatch:GetPlayers(match);
    if(players) then
        for i,player in ipairs(players) do
            if(BattlegroundMatch:IsPlayerSelf(player)) then
                return player;
            elseif(fallbackToLocal and BattlegroundMatch:IsLocalPlayer(player)) then
                return player;
            end
        end
    end

    return nil;
end

-- Returns the player info of self
function BattlegroundMatch:GetSelfInfo(match, fallbackToLocal)
    if(not match) then 
        return nil;
    end

    local player = BattlegroundMatch:GetSelf(match, fallbackToLocal);
    local playerInfo = BattlegroundMatch:GetPlayerInfo(player);

    if(not playerInfo and fallbackToLocal) then
        -- Make self info from local player
        return ArenaAnalytics:GetLocalPlayerInfo();
    end

    return playerInfo;
end

function BattlegroundMatch:SetSelf(match, fullName)
    assert(match);
    if(not fullName) then
        return;
    end

    assert(type(fullName) == "string", "Provided fullName must be a string.");

    local fullName = ArenaAnalytics:GetIndexedFullName(fullName);
    local result = BattlegroundMatch:SetTeamMemberValue(match, false, fullName, "is_self", 1);
    return result;
end

-------------------------------------------------------------------------
-- Player Value Search Checks

-- Smart player name check
function BattlegroundMatch:CheckPlayerName(player, searchValue, isExact)
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
-- Player Sorting

function BattlegroundMatch:SortPlayers(match)
    assert(match);

	local selfPlayerInfo = BattlegroundMatch:GetSelfInfo(match, true);
    local players = BattlegroundMatch:GetPlayers(match);
    GroupSorter:SortGroup(players, selfPlayerInfo);
end