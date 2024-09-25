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
    won = -13,
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
}

local roundKeys = {
    data = 0,
    comp = -1,
    enemy_comp = -2,
}

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

    local map_id = API:GetAddonMapID(value);
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

function ArenaMatch:IsVictory(match)
    local isWin = match and tonumber(match[matchKeys.won]);
    if(isWin == nil) then
        return nil;
    end

    return (isWin ~= 0);
end

function ArenaMatch:SetVictory(match, value)
    assert(match);

    match[matchKeys.won] = ToNumericalBool(value, 2);
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
        ArenaMatch:AddPlayer(match, player.isEnemy, player.name, player.race, player.spec, player.role, player.kills, player.deaths, player.damage, player.healing);
    end

    ArenaMatch:SortGroups(match);
    ArenaMatch:UpdateComps(match);
end

function ArenaMatch:AddPlayer(match, isEnemyTeam, fullName, race_id, spec_id, role_bitmap, kills, deaths, damage, healing)
    assert(match);

    if(fullName == nil) then
        ArenaAnalytics:Log("Warning: Adding player to stored match without name!");
    end

    local name, realm = ArenaAnalytics:GetNameAndRealm(fullName, true);

    local newPlayer = {}
    SetPlayerValue(match, newPlayer, "name", name);
    SetPlayerValue(match, newPlayer, "realm", realm);
    SetPlayerValue(match, newPlayer, "race", tonumber(race_id));
    SetPlayerValue(match, newPlayer, "spec_id", tonumber(spec_id));
    SetPlayerValue(match, newPlayer, "role", tonumber(role_bitmap));
    SetPlayerValue(match, newPlayer, "kills", tonumber(kills));
    SetPlayerValue(match, newPlayer, "deaths", tonumber(deaths));
    SetPlayerValue(match, newPlayer, "damage", tonumber(damage));
    SetPlayerValue(match, newPlayer, "healing", tonumber(healing));
    SetPlayerValue(match, newPlayer, "wins", tonumber(wins));

    local teamKey = isEnemyTeam and matchKeys.enemy_team or matchKeys.team;
    match[teamKey] = match[teamKey] or {}
    tinsert(match[teamKey], newPlayer);
end

-- Returns true if a value is set
function ArenaMatch:SetTeamMemberValue(match, isEnemyTeam, playerName, key, value)
    assert(match and playerName);
    if(value == nil) then
        return;
    end

    local team = ArenaMatch:GetTeam(match, isEnemyTeam);
    if(not team) then
        return;
    end

    key = key and playerKeys[key];
    assert(key);

    local name, realm = ArenaAnalytics:GetNameAndRealm(playerName, true);
    if(not name) then
        ArenaAnalytics:Log("Attempting to set team member value: ", key, value, " for invalid player name.");
    end

    for i,player in ipairs(team) do
        local playerName, playerRealm = player[playerKeys.name], player[playerKeys.realm];
        if(ArenaMatch:IsSamePlayer(player, name, realm)) then
            player[key] = value;
            return true;
        end
    end
end

function ArenaMatch:IsSamePlayer(player, otherName, otherRealm)
    assert(player and otherName);

    local playerName, playerRealm = ArenaMatch:GetPlayerNameAndRealm(player, true);
    return (playerName and playerName == otherName and playerRealm == otherRealm);
end

function ArenaMatch:IsLocalPlayer(player)
    assert(player);

    local playerName, playerRealm = ArenaMatch:GetPlayerNameAndRealm(player);
    return (playerName and playerName == UnitName("player") and ArenaAnalytics:IsLocalRealm(playerRealm));
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

function ArenaMatch:GetPlayerInfo(player, existingTable)
    if(not player) then
        return nil;
    end

    local spec_id = ArenaMatch:GetPlayerValue(player, "spec_id");
    local class, spec = Internal:GetClassAndSpec(spec_id);

    local name = player[playerKeys.name];
    local realm = ArenaAnalytics:GetRealm(player[playerKeys.realm]);
    local race_id = ArenaMatch:GetPlayerValue(player, "race");

    local role_bitmap = ArenaMatch:GetPlayerValue(player, "role");

    local playerInfo = existingTable or {};
    playerInfo.isSelf = (ArenaMatch:GetPlayerValue(player, "is_self") == 1);
    playerInfo.isFirstDeath = ArenaMatch:IsPlayerFirstDeath(player);
    playerInfo.name = name;
    playerInfo.realm = realm;
    playerInfo.fullName = ArenaAnalytics:CombineNameAndRealm(name, realm);
    playerInfo.faction = Internal:GetRaceFaction(race_id);
    playerInfo.race = Internal:GetRace(race_id);
    playerInfo.race_id = race_id;
    playerInfo.class = class;
    playerInfo.spec = spec;
    playerInfo.spec_id = spec_id;
    playerInfo.role = role_bitmap;
    playerInfo.role_main = Bitmap:GetMainRole(role_bitmap);
    playerInfo.role_sub = Bitmap:GetSubRole(role_bitmap);
    playerInfo.kills = ArenaMatch:GetPlayerValue(player, "kills");
    playerInfo.deaths = ArenaMatch:GetPlayerValue(player, "deaths");
    playerInfo.damage = ArenaMatch:GetPlayerValue(player, "damage");
    playerInfo.healing = ArenaMatch:GetPlayerValue(player, "healing");
    playerInfo.wins = ArenaMatch:GetPlayerValue(player, "wins");

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

function ArenaMatch:GetComparisonValues(playerA, playerB, key)
    assert(key);
    local valueA = ArenaMatch:GetPlayerValue(playerA, key);
    local valueB = ArenaMatch:GetPlayerValue(playerB, key);
    return valueA, valueB;
end

function ArenaMatch:GetPlayerFullName(player, requireCompactRealm)
    if(not player) then
        return "";
    end

    local name, realm = ArenaMatch:GetPlayerNameAndRealm(player, requireCompactRealm);
    return ArenaAnalytics:CombineNameAndRealm(name, realm);
end

function ArenaMatch:GetPlayerNameAndRealm(player, requireCompactRealm)
    if(not player) then
        return "";
    end

    local name = player[playerKeys.name];
    local realm = player[playerKeys.realm];

    if(requireCompactRealm) then
        return name, realm;
    end

    return name, ArenaAnalytics:GetRealm(realm);
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
        local spec_id = ArenaMatch:GetPlayerValue(player, "spec_id");
        if(not Helpers:IsSpecID(spec_id)) then
            return nil;
        end

        tinsert(teamSpecs, spec_id);
    end

    return teamSpecs;
end

local function GetCompForSpecs(teamSpecs, requiredSize)
    if(not teamSpecs or not requiredSize or requiredSize == 0) then
        ArenaAnalytics:Log("GetCompForSpecs", teamSpecs and #teamSpecs, requiredSize);
        Helpers:DebugLogTable(teamSpecs, 1);
        return nil;
    end

    if(#teamSpecs ~= requiredSize) then
        ArenaAnalytics:Log("GetCompForSpecs Invalid team size.")
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
            if(ArenaMatch:GetPlayerValue(player, "is_self") == 1) then
                return player;
            elseif(fallbackToLocal and ArenaMatch:IsLocalPlayer(player)) then
                return player;
            end
        end
    end

    return nil;
end

-- Returns the player info of the 
function ArenaMatch:GetSelfInfo(match, fallbackToLocal)
    if(not match) then 
        return nil;
    end

    local player = ArenaMatch:GetSelf(match, fallbackToLocal);
    local playerInfo = ArenaMatch:GetPlayerInfo(player);

    if(not playerInfo and fallbackToLocal) then
        -- Make self info from local player
        return ArenaAnalytics:GetLocalPlayerInfo()
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
-- First Death

function ArenaMatch:IsPlayerFirstDeath(player)
    return player and player[playerKeys.is_first_death] and true or false;
end

function ArenaMatch:GetFirstDeath(match)
    if(not match) then 
        return nil 
    end;

    local team = ArenaMatch:GetTeam(match, false);
    if(team) then
        for i,player in ipairs(team) do
            if(ArenaMatch:GetPlayerValue(player, "is_first_death") == 1) then
                return ArenaMatch:GetPlayerInfo(player);
            end
        end
    end
    
    local enemyTeam = ArenaMatch:GetTeam(match, false);
    if(enemyTeam) then
        for i,player in ipairs(enemyTeam) do
            if(ArenaMatch:GetPlayerValue(player, "is_first_death") == 1) then
                return ArenaMatch:GetPlayerInfo(player);
            end
        end
    end
end

function ArenaMatch:SetFirstDeath(match, fullName)
    assert(match);

    if(not fullName) then
        return;
    end

    local success = ArenaMatch:SetTeamMemberValue(match, false, fullName, "is_first_death", 1);
    
    if(not success) then
        ArenaMatch:SetTeamMemberValue(match, true, fullName, "is_first_death", 1);
    end
end

-------------------------------------------------------------------------
-- Player Value Search Checks

function ArenaMatch:CheckPlayerSpecID(player, spec_id)
    if(not spec_id) then
        return false;
    end

    local playerSpec = ArenaMatch:GetPlayerValue(player, "spec_id");

    if(Helpers:IsClassID(spec_id)) then
        local class_id = Helpers:GetClassID(spec_id);
        return class_id and class_id == Helpers:GetClassID(playerSpec);
    end

    return Search:CheckSpecMatch(spec_id, playerSpec)
end

function ArenaMatch:CheckPlayerRoleByIndex(player, roleIndex)
    local role_bitmap = ArenaMatch:GetPlayerValue(player, "role");
    return role_bitmap and Bitmap:HasBitByIndex(role_bitmap, roleIndex);
end

function ArenaMatch:CheckPlayerFaction(player, faction)
    local race_id = ArenaMatch:GetPlayerValue(player, "race");
    return race_id and faction == (race_id % 2);
end

function ArenaMatch:CheckPlayerName(player, searchValue, isExact)    
    if(not searchValue or searchValue == "") then
        return false;
    end

    local valueHasDash = searchValue:find('-');
    local playerName = valueHasDash and ArenaMatch:GetPlayerFullName(player) or player[playerKeys.name];
        
    if(not playerName or playerName == "") then
        return false;
    end

    playerName = playerName:lower();

    if(isExact) then
        if(valueHasDash) then
            return searchValue == playerName:gsub('-', "%%-");
        else
            return searchValue == playerName;
        end
    end

    -- Check partial match
    if(valueHasDash) then
        return playerName:gsub("-", "%-"):find(searchValue) ~= nil;
    else
        return playerName:find(searchValue) ~= nil;
    end
end

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
    if(ArenaMatch:GetBracket(match) ~= "shuffle") then
        ArenaAnalytics:Log("ArenaMatch:SetRounds skipping shuffle match type.", ArenaMatch:GetBracket(match));
        return;
    end

    local enemyTeam = ArenaMatch:GetTeam(match, true);
    assert(enemyTeam and #enemyTeam > 0); -- Must already have players, to compact round data

    match[matchKeys.rounds] = {};

    ArenaMatch:SortGroups(match);

    -- Fill player name to index mapping
    local indexMapping = {}
    for index, player in ipairs(enemyTeam) do
        local fullName = ArenaMatch:GetPlayerFullName(player);
        if(fullName and fullName ~= "") then
            indexMapping[fullName] = index;
        end
    end

    -- Cache values to help sort
    local myName = Helpers:GetPlayerName();
    local selfPlayerInfo = ArenaMatch:GetSelfInfo(match, true);
    local requiredTeamSize = ArenaMatch:GetTeamSize(match);

    local function compressGroup(group)
        if(not group or #group == 0) then
            return nil;
        end

        local compactGroup = {}
        local specs = {}

        for _,member in ipairs(group) do
            local spec_id = nil;
            local playerIndex = member and indexMapping[member] or nil;

            if(playerIndex) then
                local player = enemyTeam[playerIndex];
                spec_id = ArenaMatch:GetPlayerValue(player, "spec_id");

                tinsert(compactGroup, playerIndex);
            elseif(member == myName) then
                local player = ArenaMatch:GetSelf(match);
                spec_id = ArenaMatch:GetPlayerValue(player, "spec_id");
            end

            if(Helpers:IsSpecID(spec_id)) then
                tinsert(specs, spec_id);
            end
        end

        GroupSorter:SortIndexGroup(compactGroup, selfPlayerInfo, enemyTeam);
        local groupString = table.concat(compactGroup) or "";
        local comp = GetCompForSpecs(specs, requiredTeamSize);

        ArenaAnalytics:Log("compressGroup result:", groupString, comp, #specs);
        return groupString, comp;
    end

    for i,round in ipairs(rounds) do
        local team, comp = compressGroup(round.team);
        local enemy, enemyComp = compressGroup(round.enemy);
        local firstDeath = round.firstDeath and indexMapping[round.firstDeath] or "";
        local duration = round.duration or "";

        -- Insert the round to the match
        local compactRound = {
            [roundKeys.data] = team .. "-" .. enemy .. "-" .. firstDeath .. "-" .. duration,
            [roundKeys.comp] = comp,
            [roundKeys.enemy_comp] = enemyComp,
        };

        tinsert(match[matchKeys.rounds], compactRound);
        
        ArenaAnalytics:Log("SetRounds: Added round:", compactRound[0], compactRound[-1], compactRound[-2]);
    end
    
    ArenaAnalytics:Log("Match:SetRounds outcome:", #match[matchKeys.rounds], #rounds);
end

function ArenaMatch:GetRounds(match)
    return match and match[matchKeys.rounds] or nil;
end

function ArenaMatch:GetRoundData(round)
    return round and round[roundKeys.data];
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
    if(ArenaMatch:GetMatchType() ~= "shuffle") then
        ArenaMatch:SortGroups(match);
        return
    end

    -- Fill old index to player name mapping
    local enemyTeam = ArenaMatch:GetTeam(match, true);
    local oldNameOrder = {}
    for i,player in ipairs(enemyTeam) do
        if(player and player.name) then
            oldNameOrder[i] = player.name;
        end
    end

    -- Sort match enemies
	local selfPlayerInfo = ArenaMatch:GetSelfInfo(match);
    GroupSorter:SortGroup(enemyTeam, selfPlayerInfo);

    -- Fill old index to new index mapping
    local indexMapping = {}
    for newIndex,player in ipairs(enemyTeam) do
        if(player and player.name) then
            for oldIndex,name in pairs(oldNameOrder) do
                if(oldIndex and oldNameOrder[oldIndex] == player.name) then
                    indexMapping[oldIndex] = newIndex;
                    break;
                end
            end
        end
    end

    -- Update round groups to new index
    -- TODO: For each round
        -- For each group in that round
            -- Convert each index to new index

    -- Sort both groups for each round
    -- TODO: Add GroupSorter:SortIndexGroup(group, players), where group is compacted 

    -- Compress to index based format

    -- Save
end


function ArenaMatch:SortGroups(match)
    assert(match);

	local selfPlayerInfo = ArenaMatch:GetSelfInfo(match);

    local team = ArenaMatch:GetTeam(match, false);
    GroupSorter:SortGroup(team, selfPlayerInfo);

    local enemyTeam = ArenaMatch:GetTeam(match, true);
    GroupSorter:SortGroup(enemyTeam, selfPlayerInfo);
end
