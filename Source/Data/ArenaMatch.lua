local _, ArenaAnalytics = ...; -Addon Namespace
local AAmatch = ArenaAnalytics.ArenaMatch;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;
local Constants = ArenaAnalytics.Constants;

-------------------------------------------------------------------------

local matchTypes = { "rated", "skirmish", "wargame" }
local brackets = { "2v2", "3v3", "5v5", "shuffle" }

local matchKeys = {
    ["date"] = 1,
    ["duration"] = 2,
    ["map"] = 3,
    ["bracket"] = 4,
    ["match_type"] = 5,
    ["rating"] = 6,
    ["rating_delta"] = 7,
    ["mmr"] = 8,
    ["enemy_rating"] = 9,
    ["enemy_rating_delta"] = 10,
    ["enemy_mmr"] = 11,
    ["season"] = 12,
    ["session"] = 13,
    ["won"] = 14,
    ["self"] = 15,
    ["first_death"] = 16,
    ["team"] = 17,
    ["enemy"] = 18,
    ["comp"] = 19,
    ["enemy_comp"] = 20,
}

local playerKeys = {
    ["name"] = 1,
    ["race"] = 2,
    ["spec_id"] = 3,
    ["deaths"] = 4,
    ["kills"] = 5,
    ["healing"] = 6,
    ["damage"] = 7,
    ["wins"] = 8,
}

-------------------------------------------------------------------------
-- Helper functions

local function ToPositiveNumber(value, allowZero)
    value = tonumber(value);
    if(not value) then
        return nil;
    end

    value = round(value);

    if(allowZero and value == 0) then
        return value;
    end

    return value > 0 and value;
end

local function ToNumericalBool(value)
    if(value == nil) then
        return nil;
    end
    return (value and value ~= 0) and 1 or 0;
end

-------------------------------------------------------------------------
-- Date (1)

function ArenaMatch:GetDate(match)
    local key = matchKeys["date"];
    return match and tonumber(match[key]);
end

function ArenaMatch:SetDate(match, value)
    assert(match);

    local key = matchKeys["date"];
    match[key] = ToPositiveNumber(value);
end

-------------------------------------------------------------------------
-- Duration (2)

function ArenaMatch:GetDuration(match)
    local key = matchKeys["duration"];
    return match and tonumber(match[key]);
end

function ArenaMatch:SetDuration(match, value)
    assert(match);

    local key = matchKeys["duration"];
    match[key] = ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Map (3)

function ArenaMatch:GetMapIndex(match)
    local key = matchKeys["map"];
    return match and tonumber(match[key]);
end

function ArenaMatch:SetMapID(match, value)
    assert(match);

    if(type(value) == "string") then
        value = Constants:GetMapIdByKey(mapKey);
    end

    local key = matchKeys["map"];
    match[key] = tonumber(value);
end

function ArenaMatch:SetMap(match, value)
    assert(match);

    local key = matchKeys["map"];
    mapId = tonumber(value) or Constants:GetMapIdByKey(value);
    match[key] = tonumber(mapId);
end

-------------------------------------------------------------------------
-- Bracket (4)

function ArenaMatch:GetBracketIndex(match)
    local key = matchKeys["bracket"];
    return match and tonumber(match[key]);
end

function ArenaMatch:SetBracketIndex(match, value)
    assert(match);

    local key = matchKeys["bracket"];
    match[key] = tonumber(value);
end

function ArenaMatch:SetBracket(match, value)
    assert(match);
    local key = matchKeys["bracket"];

    value = Helpers:ToSafeLower(value);
    for index,bracket in ipairs(brackets) do
        if(value == Helpers:ToSafeLower(bracket)) then
            match[key] = index;
            return;
        end
    end
    
    match[key] = nil;
    ArenaAnalytics:Log("Error: Attempted to set invalid bracket:", value);
end

-------------------------------------------------------------------------
-- Match Type (5)

-- rated, skirmish or wargame
function ArenaMatch:GetMatchType(match)
    local key = matchKeys["match_type"];
    local typeKey = match and tonumber(match[key]);
    return typeKey and matchTypes[typeKey];
end

function ArenaMatch:SetMatchType(match, value)
    assert(match);
    local key = matchKeys["match_type"];
    
    value = Helpers:ToSafeLower(value);
    for index,matchType in ipairs(matchTypes) do
        if(value == index or value == matchType:lower()) then
            match[key] = index;
            return;
        end
    end

    match[key] = nil;
    ArenaAnalytics:Log("Error: Attempted to set invalid match type:", value);
end

-------------------------------------------------------------------------
-- Party Rating (6)

function ArenaMatch:GetPartyRating(match)
    local key = matchKeys["rating"];
    return match and tonumber(match[key]);
end

function ArenaMatch:SetPartyRating(match, value)
    assert(match);

    local key = matchKeys["rating"];
    match[key] = ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Party Rating Delta (7)

function ArenaMatch:GetPartyRatingDelta(match)
    local key = matchKeys["rating_delta"];
    return match and tonumber(match[key]);
end

function ArenaMatch:SetPartyRatingDelta(match, value)
    assert(match);

    local key = matchKeys["rating_delta"];
    match[key] = ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Party MMR (8)

function ArenaMatch:GetPartyMMR(match)
    local key = matchKeys["mmr"];
    return match and tonumber(match[key]);
end

function ArenaMatch:SetPartyRatingMMR(match, value)
    assert(match);

    local key = matchKeys["mmr"];
    match[key] = ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Enemy Rating (9)

function ArenaMatch:GetEnemyRating(match)
    local key = matchKeys["enemy_rating"];
    return match and tonumber(match[key]);
end

function ArenaMatch:SetEnemyRating(match, value)
    assert(match);

    local key = matchKeys["enemy_rating"];
    match[key] = ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Enemy Rating Delta (10)

function ArenaMatch:GetEnemyRatingDelta(match)
    local key = matchKeys["enemy_rating_delta"];
    return match and tonumber(match[key]);
end

function ArenaMatch:SetEnemyRatingDelta(match, value)
    assert(match);

    local key = matchKeys["enemy_rating_delta"];
    match[key] = ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Enemy MMR (11)

function ArenaMatch:GetEnemyMMR(match)
    local key = matchKeys["enemy_mmr"];
    return match and tonumber(match[key]);
end

function ArenaMatch:SetEnemyRatingMMR(match, value)
    assert(match);

    local key = matchKeys["enemy_mmr"];
    match[key] = ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Season (12)

function ArenaMatch:GetSeason(match)
    local key = matchKeys["season"];
    return match and tonumber(match[key]);
end

function ArenaMatch:SetSeason(match, value)
    assert(match);

    local key = matchKeys["season"];
    match[key] = ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Session (13)

function ArenaMatch:GetSession(match)
    local key = matchKeys["session"];
    return match and tonumber(match[key]);
end

function ArenaMatch:SetSession(match, value)
    assert(match);

    local key = matchKeys["session"];
    match[key] = ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Victory (14)

function ArenaMatch:IsVictory(match)
    local key = matchKeys["won"];
    local isWin = match and tonumber(match[key]);
    if(isWin == nil) then
        return nil;
    end

    return (isWin ~= 0);
end

function ArenaMatch:SetVictory(match, value)
    assert(match);

    local key = matchKeys["won"];
    match[key] = ToNumericalBool(value);
end

-------------------------------------------------------------------------
-- Self (15)

function ArenaMatch:GetSelf(match)
    local key = matchKeys["self"];
    return match[key];
end

function ArenaMatch:SetSelf(match, value)
    assert(match);

    local key = matchKeys["self"];
    match[key] = value;
end

-------------------------------------------------------------------------
-- First Death (16)

function ArenaMatch:GetFirstDeath(match)
    local key = matchKeys["first_death"];
    return match[key];
end

function ArenaMatch:SetFirstDeath(match, value)
    assert(match);

    local player = ArenaMatch:GetSelf();
    if(value == player) then
        value = player;
    end
    
    local key = matchKeys["first_death"];
    match[key] = value;
end

-------------------------------------------------------------------------
-- Team (16)

function ArenaMatch:GetTeamSize(match, isEnemyTeam)
    assert(match);

    local key = isEnemyTeam and matchKeys["enemy_team"] or matchKeys["team"];
    return key and #match[key] or 0;
end

function ArenaMatch:GetPlayerInfo(match, isEnemyTeam, index)
    assert(match and index);

    local key = isEnemyTeam and matchKeys["enemy_team"] or matchKeys["team"];
    local team = key and match[key];
    if(not team) then
        return {};
    end

    local player = index and team[index];
    if(not player) then
        return {};
    end

    local spec_id = ArenaMatch:GetPlayerValue(match, player, "spec_id");
    local class, spec = Constants:GetClassAndSpec(spec_id);

    local playerInfo = {
        name = ArenaMatch:GetPlayerName(match, player),
        race = ArenaMatch:GetPlayerValue(match, player, "race"),
        class = class,
        spec = spec,
        deaths = ArenaMatch:GetPlayerValue(match, player, "deaths"),
        kills = ArenaMatch:GetPlayerValue(match, player, "kills"),
        healing = ArenaMatch:GetPlayerValue(match, player, "healing"),
        damage = ArenaMatch:GetPlayerValue(match, player, "damage"),
        wins = ArenaMatch:GetPlayerValue(match, player, "wins"),
    }

    return playerInfo;
end

function ArenaMatch:GetPlayerValue(match, player, key)
    assert(match);
    if(key == nil) then
        return nil;
    end

    if(key == "name") then
        return ArenaMatch:GetPlayerName(match, player);
    end

    local playerKey = playerKeys[key];
    local spec_id = playerKey and player[key];
end

function ArenaMatch:GetPlayerName(match, player)
    assert(match);

    if(not player) then
        return "";
    end

    local key = playerKeys["name"];
    local name = key and player[key];

    if(not name) then
        return "";
    elseif(name == 0) then
        local key = matchKeys["self"];
        name = key and match[key] or "";
    elseif(not name:find('-')) then
        local key = matchKeys["self"];
        local selfName = key and match[key] or "";
        name = name .. (string.match(selfName, "%-.+") or "");
    end

    return name;
end


--[[
    ["team"] = 17,
    ["enemy_team"] = 18,
    ["comp"] = 19,
    ["enemy_comp"] = 20,
--]]