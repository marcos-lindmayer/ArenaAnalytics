local _, ArenaAnalytics = ...; -- Addon Namespace
local ArenaMatch = ArenaAnalytics.ArenaMatch;

-- Local module aliases
local Constants = ArenaAnalytics.Constants;
local Bitmap = ArenaAnalytics.Bitmap;
local Helpers = ArenaAnalytics.Helpers;
local Internal = ArenaAnalytics.Internal;
local GroupSorter = ArenaAnalytics.GroupSorter;
local API = ArenaAnalytics.API;
local Search = ArenaAnalytics.Search;

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
    team = -14,
    enemy_team = -15,
    comp = -16,
    enemy_comp = -17,
    rounds = -18,

    transient_seasonPlayed = -100,
    transient_requireRatingFix = -101,
}

local playerKeys = {
    name = 0,
    realm = -1,
    is_self = -2,
    is_first_death = -3,
    race = -4,
    spec_id = -5,
    role = -6,
    deaths = -7,
    kills = -8,
    healing = -9,
    damage = -10,
    wins = -11,
    rating = -12,
    ratingDelta = -13,
    mmr = -14,
    mmrDelta = -15,
}

local roundKeys = {
    data = 0,
    comp = -1,
    enemy_comp = -2,
}

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
            ArenaAnalytics:LogEscaped(newData, "  :  ", round[roundKeys.data]);
            round[roundKeys.data] = newData;
        end
    end
end

-- Revert 
function ArenaMatch:RevertPlayerNameAndRealmIndexing(match)
    if(not match) then
        return;
    end

    for i,isEnemy in ipairs({false, true}) do
        local team = ArenaMatch:GetTeam(match, isEnemy);
        if(type(team) == "table") then
            for i,player in ipairs(team) do
                local name = player[playerKeys.name];
                local realm = player[playerKeys.realm];

                -- If either name or realm requires reverting
                if(type(name) == "number" or type(realm) == "number") then
                    ArenaAnalytics:Log("Reverting player names:", name, realm);

                    if(type(name) == "number") then
                        name = ArenaAnalytics:GetName(name, true);
                    end

                    if(type(realm) == "number") then
                        realm = ArenaAnalytics:GetRealm(realm, true);
                    end

                    ArenaAnalytics:Log("   Reverted player names:", name, realm);
                    player[playerKeys.name] = name;
                    player[playerKeys.realm] = realm;
                end
            end
        end
    end
end

function ArenaMatch:ConvertPlayerValues(match)
    if(not match) then
        return;
    end

    local oldPlayerKeys = {
        name = 0,
        realm = -1,
        is_self = -2,
        is_first_death = -3,
        race = -4,
        spec_id = -5,
        role = -6,
        deaths = -7,
        kills = -8,
        healing = -9,
        damage = -10,
        wins = -11,
        rating = -12,
        ratingDelta = -13,
        mmr = -14,
        mmrDelta = -15,
    }

    -- Get a compact | separated player data string
    local function ToPlayerData(player, isEnemy)
        if(not player or type(player) == "string") then
            return nil;
        end

        local name = player[oldPlayerKeys.name];
        local realm = player[oldPlayerKeys.realm];
        local fullName = (name or "") .. '-' .. (realm or "");

        local player = {
            name = fullName,
            isSelf = player[oldPlayerKeys.is_self],
            isFirstDeath = player[oldPlayerKeys.is_first_death],
            isEnemy = isEnemy,
            race = player[oldPlayerKeys.race],
            spec = player[oldPlayerKeys.spec_id],
            role = player[oldPlayerKeys.role],
            kills = player[oldPlayerKeys.kills],
            deaths = player[oldPlayerKeys.deaths],
            damage = player[oldPlayerKeys.damage],
            healing = player[oldPlayerKeys.healing],
        };

        return ArenaMatch:MakeCompactPlayerData(player);
    end

    -- For each player
    for i,isEnemy in ipairs({false, true}) do
        local team = ArenaMatch:GetTeam(match, isEnemy);
        local newTeam = {}

        if(type(team) == "table") then
            for i,player in ipairs(team) do
                local isOldFormat = type(player) == "table";
                local newDataString = isOldFormat and ToPlayerData(player, isEnemy) or player;
                ArenaAnalytics:LogEscaped("ConvertPlayerValues:", i, isOldFormat, newDataString);

                if(newDataString == "") then
                    ArenaAnalytics:Log("ERROR: Converting player values added empty player value string!");
                end

                -- Actual conversion NYI!
                if(newDataString) then
                    tinsert(newTeam, newDataString);
                end
            end
        end

        ArenaAnalytics:Log("ConvertPlayerValues", #newTeam)
        if(#newTeam > 0) then
            local teamKey = isEnemy and matchKeys.enemy_team or matchKeys.team;
            for i,player in ipairs(newTeam) do
                ArenaAnalytics:LogEscaped("     ", i, player);
            end

            match[teamKey] = newTeam;
        end
    end
end

-------------------------------------------------------------------------
-- Helper functions

local function ToPositiveNumber(value, allowZero)
    value = tonumber(value);
    if(not value) then
        return;
    end

    value = Round(value);

    if(value < 0) then
        return nil;
    elseif(value == 0) then
        if(not allowZero) then
            return nil;
        end
        return 0;
    end

    return value or nil;
end

local function ToNonZeroNumber(value)
    value = tonumber(value);
    if(not value or value == 0) then
        return nil;
    end
    return value;
end

local function ToNumericalBool(value, drawValue)
    if(value == nil) then
        return;
    end

    if(drawValue and value == drawValue) then
        return tonumber(value);
    end

    return (value and value ~= 0) and 1 or 0;
end

-------------------------------------------------------------------------
-- Rating fixup

function ArenaMatch:ClearTransientValues(match)
    assert(match);

    match[matchKeys.transient_seasonPlayed] = nil;
    match[matchKeys.transient_requireRatingFix] = nil;
end

function ArenaMatch:SetTransientSeasonPlayed(match, value)
    assert(match);
    ArenaAnalytics:Log("Assigning transient season played value:", value, "from:", match[matchKeys.transient_seasonPlayed]);
    match[matchKeys.transient_seasonPlayed] = tonumber(value);
end

function ArenaMatch:SetRequireRatingFix(match, value)
    assert(match);
    ArenaAnalytics:Log("SetRequireRatingFix:", value, "from:", match[matchKeys.transient_requireRatingFix]);
    match[matchKeys.transient_requireRatingFix] = value and true or nil;
end

function ArenaMatch:DoesRequireRatingFix(match)
    return match and (match[matchKeys.transient_requireRatingFix] ~= nil);
end

function ArenaMatch:TryFixLastRating(match)
    assert(match);

    if(not ArenaMatch:DoesRequireRatingFix(match)) then
        return;
    end

    local requiredSeasonPlayed = tonumber(match[matchKeys.transient_seasonPlayed]);
    if(not requiredSeasonPlayed) then
        return;    
    end

    local season = ArenaMatch:GetSeason(match);
    local currentSeason = GetCurrentArenaSeason();
    if(currentSeason and currentSeason > 0 and season and season ~= currentSeason) then
        -- Season appears to have changed, too late to fix last rating.
        ArenaMatch:ClearTransientValues(match);
        return;
    end

    local bracketIndex = ArenaMatch:GetBracketIndex(match);
    local newRating,seasonPlayed = API:GetPersonalRatedInfo(bracketIndex);
    if(not seasonPlayed or seasonPlayed < requiredSeasonPlayed) then
        ArenaAnalytics:Log("ArenaMatch: Delaying rating fix - Season Played.", seasonPlayed, bracketIndex, requiredSeasonPlayed)
        return;
    end

    if(seasonPlayed == requiredSeasonPlayed) then
        if(newRating) then
            -- Fix rating
            local oldRating = ArenaMatch:GetPartyRating(match);
            local delta = oldRating and newRating - oldRating;

            ArenaAnalytics:Log("ArenaMatch: Fixing rating from:", oldRating, "to:", newRating, delta);

            ArenaMatch:SetPartyRating(match, newRating);
            ArenaMatch:SetPartyRatingDelta(match, delta);
        end
    end

    -- Clear transient values
    ArenaMatch:ClearTransientValues(match);
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
        return nil 
    end;
    
    local key = matchKeys.duration;
    return match and tonumber(match[key]);
end

function ArenaMatch:SetDuration(match, value)
    assert(match);

    local key = matchKeys.duration;
    match[key] = ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Map (3)

function ArenaMatch:GetMapID(match)
    if(not match) then 
        return nil 
    end;

    local key = matchKeys.map;
    return match and tonumber(match[key]);
end

function ArenaMatch:GetMap(match)
    local map_id = ArenaMatch:GetMapID(match);
    return Internal:GetShortMapName(map_id);
end

function ArenaMatch:SetMap(match, value)
    assert(match);
    
    if(not value) then
        return;
    end

    local map_id = Internal:GetAddonMapID(value);
    if(not map_id) then
        ArenaAnalytics:Log("Warning: ArenaMatch:SetMap failed to find map_id for value:", value);
    end

    match[matchKeys.map] = tonumber(map_id)
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
    
    local key = matchKeys.match_type;
    local typeIndex = match and tonumber(match[key]);
    return ArenaAnalytics:GetMatchType(typeIndex);
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
        return nil 
    end;
    
    local key = matchKeys.rating_delta;
    return match and tonumber(match[key]);
end

function ArenaMatch:SetPartyRatingDelta(match, value)
    assert(match);

    match[matchKeys.rating_delta] = ToNonZeroNumber(value);
end

-------------------------------------------------------------------------
-- Party MMR (8)

function ArenaMatch:GetPartyMMR(match)
    if(not match) then 
        return nil 
    end;
    
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
        return nil 
    end;
    
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
    match[key] = ToNonZeroNumber(value);
end

-------------------------------------------------------------------------
-- Enemy MMR (11)

function ArenaMatch:GetEnemyMMR(match)
    if(not match) then 
        return nil 
    end;

    return match and tonumber(match[matchKeys.enemy_mmr]);
end

function ArenaMatch:SetEnemyMMR(match, value)
    assert(match);
    match[matchKeys.enemy_mmr] = ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Season (12)

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
    match[matchKeys.outcome] = ToNumericalBool(value, 2);
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

    if(player.name == nil) then
        ArenaAnalytics:Log("Warning: Adding player to stored match without name!");
    end

    local name, realm = ArenaAnalytics:SplitFullName(player.name, true);

    local newPlayer = {}
    newPlayer[playerKeys.name] = name;
    newPlayer[playerKeys.realm] = realm;
    newPlayer[playerKeys.race] = tonumber(player.race);
    newPlayer[playerKeys.spec_id] = tonumber(player.spec);
    newPlayer[playerKeys.role] = API:GetRoleBitmap(player.spec);
    newPlayer[playerKeys.kills] = tonumber(player.kills);
    newPlayer[playerKeys.deaths] = tonumber(player.deaths);
    newPlayer[playerKeys.damage] = tonumber(player.damage);
    newPlayer[playerKeys.healing] = tonumber(player.healing);
    newPlayer[playerKeys.wins] = tonumber(player.wins);

    newPlayer[playerKeys.is_self] = player.isSelf and 1 or nil;
    newPlayer[playerKeys.is_first_death] = player.isFirstDeath and 1 or nil;

    local teamKey = player.isEnemy and matchKeys.enemy_team or matchKeys.team;
    match[teamKey] = match[teamKey] or {}
    tinsert(match[teamKey], newPlayer);
end

function ArenaMatch:MakePlayerBitmask(player)
    if(not player) then
        return nil;
    end

    local bitmask = 0;
    for key,index in pairs(Constants.playerFlags) do
        assert(key and tonumber(index), "Invalid values in Constants.playerFlags! " .. (key or "nil") .. " " .. (index or "nil") .. " " .. (type(index)));

        if(player[key]) then
            bitmask = bitmask + Bitmap:IndexToBitmap(index);
        end
    end

    ArenaAnalytics:Log("   ", bitmask, player.isFirstDeath, player.isEnemy, player.isSelf);
    return (bitmask > 0) and bitmask or nil;
end

function ArenaMatch:MakeCompactPlayerData(player)
    if(not player) then
        return nil;
    end

    player.bitmask = ArenaMatch:MakePlayerBitmask(player);

    if(player.name) then
        ArenaAnalytics:Log("MakeCompactPlayerData", player.name);
        local name, realm = strsplit('-', player.name);
        name = ArenaAnalytics:GetNameIndex(name) or "";
        realm = ArenaAnalytics:GetRealmIndex(realm) or "";
        player.fullName = name .. '-' .. realm;
        ArenaAnalytics:Log("   MakeCompactPlayerData", player.fullName, name, realm);
    end

    local playerDataOrder = {
        "fullName",
        "bitmask",
        "race",
        "spec",
        "role",
        "kills",
        "deaths",
        "damage",
        "healing",
        "wins",
        "rating",
        "ratingDelta",
        "mmr",
        "mmrDelta",
    };

    local values = {}
    local emptyCount = 0;

    for i,key in ipairs(playerDataOrder) do
        if(player[key] ~= nil) then
            if(emptyCount > 0) then
                -- One separator will be added at concat time. Add all but one of the missing ones here.                
                local missingSeparators = (emptyCount == 1) and "" or string.rep('|', emptyCount-1);
                tinsert(values, missingSeparators);
                emptyCount = 0;
            end

            tinsert(values, player[key]);
        else
            emptyCount = emptyCount + 1;
        end
    end

    return table.concat(values, '|');
end

-- Returns true if a value is set
function ArenaMatch:SetTeamMemberValue(match, isEnemyTeam, playerName, key, value)
    assert(match and playerName);

    key = key and playerKeys[key];
    assert(key, "SetTeamMemberValue: Invalid playerKey provided.");

    local team = ArenaMatch:GetTeam(match, isEnemyTeam);
    if(not team) then
        return;
    end

    local fullName = ArenaAnalytics:GetIndexedFullName(playerName, false);

    for i,player in ipairs(team) do
        if(ArenaMatch:IsSamePlayer(player, playerName)) then
            player[key] = value;
            return true;
        end
    end
end

function ArenaMatch:IsSamePlayer(player, otherFullName)
    assert(player and otherFullName);

    local playerName = ArenaMatch:GetPlayerFullName(player);
    if(not playerName or not otherFullName) then
        return false;
    end

    if(playerName == otherFullName) then
        return true;
    end

    local name, realm = strsplit('-', playerName, 2);
    local otherName, otherRealm = strsplit('-', otherFullName, 2);

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

    local fullName = ArenaMatch:GetPlayerFullName(player);
    return fullName and fullName == "1-1";
end

function ArenaMatch:GetTeam(match, isEnemyTeam)
    if(not match) then 
        return nil;
    end;

    local key = isEnemyTeam and matchKeys.enemy_team or matchKeys.team;
    return key and match[key] or {};
end

function ArenaMatch:GetTeamSize(match)
    if(not match) then 
        return nil 
    end;

    local bracketIndex = ArenaMatch:GetBracketIndex(match);
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

    if(not match) then 
        return nil 
    end;

    local team = ArenaMatch:GetTeam(match, isEnemyTeam);

    if(not team or index < 1 or index > #team) then
        return nil;
    end

    return team[index];
end

function ArenaMatch:GetPlayerInfo(player, existingTable, searchableOnly)
    if(type(player) ~= "string") then
        return nil;
    end

    -- Split the player data string by '|'
    local valueCount = searchableOnly and 6 or nil;
    local playerData = { strsplit('|', player, valueCount) }

    -- Initialize or update an existing table for player info
    local playerInfo = existingTable or {}

    playerInfo.name = playerData[1];
    playerInfo.bitmask = tonumber(playerData[2]);
    playerInfo.race = tonumber(playerData[3]);
    playerInfo.spec = tonumber(playerData[4]);
    playerInfo.role = tonumber(playerData[5]);

    -- Nil for searchable only info!
    if(not searchableOnly) then
        playerInfo.kills = tonumber(playerData[6]);
        playerInfo.deaths = tonumber(playerData[7]);
        playerInfo.damage = tonumber(playerData[8]);
        playerInfo.healing = tonumber(playerData[9]);
        playerInfo.wins = tonumber(playerData[10]);
        playerInfo.rating = tonumber(playerData[11]);
        playerInfo.ratingDelta = tonumber(playerData[12]);
        playerInfo.mmr = tonumber(playerData[13]);
        playerInfo.mmrDelta = tonumber(playerData[14]);
    else
        playerInfo.kills = nil;
        playerInfo.deaths = nil;
        playerInfo.damage = nil;
        playerInfo.healing = nil;
        playerInfo.wins = nil;
        playerInfo.rating = nil;
        playerInfo.ratingDelta = nil;
        playerInfo.mmr = nil;
        playerInfo.mmrDelta = nil;
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

function ArenaMatch:GetPlayerFullName(player)
    if(not player) then
        return nil;
    end

    local fullName = strsplit('|', player, 2);
    return fullName;
end

local function GetTeamSpecs(team, requiredSize)    
    if(not team or not requiredSize or requiredSize == 0) then
        return nil;
    end

    if(#team ~= requiredSize) then
        return nil;
    end

    local teamSpecs = {}

    -- Gather all team specs, bailing out if any are missing
    for i,player in ipairs(team) do
        local playerInfo = ArenaMatch:GetPlayerInfo(player);
        if(not playerInfo or not Helpers:IsSpecID(playerInfo.spec)) then
            return nil;
        end

        tinsert(teamSpecs, playerInfo.spec);
    end

    return teamSpecs;
end

local function GetCompForSpecs(teamSpecs, requiredSize)
    if(not teamSpecs or not requiredSize or requiredSize == 0) then
        ArenaAnalytics:Log("GetCompForSpecs: Invalid spec count:", teamSpecs and #teamSpecs, requiredSize);
        return nil;
    end

    if(#teamSpecs ~= requiredSize) then
        ArenaAnalytics:Log("GetCompForSpecs: Invalid team size.", #teamSpecs, requiredSize)
        return nil;
    end

    table.sort(teamSpecs, function(a, b)
        return a < b;
    end);

    return table.concat(teamSpecs, '|');
end

function ArenaMatch:GetComp(match, isEnemyTeam)
    assert(match);

    local key = isEnemyTeam and matchKeys.enemy_comp or matchKeys.comp;
    return match[key];
end

function ArenaMatch:UpdateComps(match)
    assert(match);

    ArenaMatch:UpdateComp(match, false);
    ArenaMatch:UpdateComp(match, true);
end

function ArenaMatch:UpdateComp(match, isEnemyTeam)
    assert(match);

    local team = ArenaMatch:GetTeam(match, isEnemyTeam);
    local requiredTeamSize = ArenaMatch:GetTeamSize(match);

    local teamSpecs = GetTeamSpecs(team, requiredTeamSize);

    local key = isEnemyTeam and matchKeys.enemy_comp or matchKeys.comp;
    match[key] = GetCompForSpecs(teamSpecs, requiredTeamSize);
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
    for _,player in ipairs(team) do
        if(ArenaMatch:IsPlayerSelf(player)) then
            return true;
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
            local _,bitmask = strsplit('|', player, 3);
            if(Bitmap:HasBitByIndex(bitmask, Constants.playerFlags.isSelf)) then
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
    assert(not fullName or type(fullName) == "string");

    if(not fullName) then
        return;
    end

    local result = ArenaMatch:SetTeamMemberValue(match, false, fullName, "is_self", 1);
    return result;
end

-------------------------------------------------------------------------
-- Player Value Search Checks

-------------------------------------------------------------------------
-- Solo Shuffle

-- Set rounds data
function ArenaMatch:SetRounds(match, rounds)
    assert(match);
    assert(not match[matchKeys.rounds]);

    if(not rounds or #rounds == 0) then
        ArenaAnalytics:Log("ArenaMatch:SetRounds bailing out due to invalid incoming rounds:", rounds and #rounds);
        return;
    end

    -- Only solo shuffle supports multiple rounds
    if(not ArenaMatch:IsShuffle(match)) then
        ArenaAnalytics:Log("ArenaMatch:SetRounds skipping shuffle match type.", ArenaMatch:GetBracket(match));
        return;
    end

    ArenaMatch:SortGroups(match);

    local enemyTeam = ArenaMatch:GetTeam(match, true);
    assert(enemyTeam and #enemyTeam > 0); -- Must already have players, to compact round data

    match[matchKeys.rounds] = {};

    -- Cache values to help sort
    local myName = Helpers:GetPlayerName();
    local selfPlayerInfo = ArenaMatch:GetSelfInfo(match, true);
    local requiredTeamSize = ArenaMatch:GetTeamSize(match);
    
    -- Fill player name to index mapping
    local indexMapping = {}

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

        local compactGroup = {}
        local specs = {}

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
            local spec_id = ArenaMatch:GetPlayerValue(player, "spec_id");
            if(Helpers:IsSpecID(spec_id)) then
                tinsert(specs, spec_id);
            end
        end

        GroupSorter:SortIndexGroup(compactGroup, enemyTeam, selfPlayerInfo);
        local groupString = table.concat(compactGroup) or "";
        local comp = GetCompForSpecs(specs, requiredTeamSize);

        return groupString, comp;
    end

    for i,round in ipairs(rounds) do
        local team, comp = compressGroup(round.team);
        local enemy, enemyComp = compressGroup(round.enemy);
        local death = round.firstDeath and indexMapping[round.firstDeath];

        -- Insert the round to the match (team-enemy-death-duration)
        local compactRound = {
            [roundKeys.data] = (team or "") .. '|' .. (enemy or "") .. '|' .. (death or "") .. '|' .. (round.duration or ""),
            [roundKeys.comp] = comp,
            [roundKeys.enemy_comp] = enemyComp,
        };

        tinsert(match[matchKeys.rounds], compactRound);
    end
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

    -- 4 values: team, enemy, death, duration
    return strsplit('|', data);
end

function ArenaMatch:GetRoundComp(round)
    return round and round[roundKeys.comp];
end

function ArenaMatch:GetRoundEnemyComp(round)
    return round and round[roundKeys.enemy_comp];
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
    for i,player in ipairs(enemyTeam) do
        player.oldIndex = i;
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
    for newIndex,player in ipairs(enemyTeam) do
        local oldIndex = player and player.oldIndex;
        if(oldIndex) then
            indexMapping[oldIndex] = newIndex;
            player.oldIndex = nil; -- Clear temporary tag
        else
            ArenaAnalytics:Log("ERROR: Failed to retrieve old index for player! Sorting is likely to have broken the match data!");
            assert(false); -- Force the addon to crash, preventing it from saving the match wrongly
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
        local team, enemy, death, duration = ArenaMatch:GetRoundData(round);

        team = ConvertPlayerIndices(team, true);
        enemy = ConvertPlayerIndices(enemy, true);
        death = ConvertPlayerIndices(death);

        round[roundKeys.data] = team .. '|' .. enemy .. '|' .. death .. '|' .. (duration or "");
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
