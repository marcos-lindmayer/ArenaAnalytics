local _, ArenaAnalytics = ...; -- Addon Namespace
local ArenaMatch = ArenaAnalytics.ArenaMatch;

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

    value = Round(value);

    if(value == 0) then
        return allowZero and 0 or nil;
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
    if(not match) then 
        return nil 
    end;
    
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
    if(not match) then 
        return nil 
    end;
    
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

function ArenaMatch:GetMapID(match)
    if(not match) then 
        return nil 
    end;
    
    local key = matchKeys["map"];
    return match and tonumber(match[key]);
end

function ArenaMatch:GetMap(match)
    local mapID = ArenaMatch:GetMapID(match);
    return mapID and Constants:GetShortMapName(mapID);
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
    if(not match) then 
        return nil 
    end;
    
    local key = matchKeys["bracket"];
    return match and tonumber(match[key]);
end

function ArenaMatch:GetBracket(match)
    if(not match) then 
        return nil 
    end;
    
    local bracketIndex = ArenaMatch:GetBracketIndex(match);
    return bracketIndex and brackets[bracketIndex];
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
    if(not match) then 
        return nil 
    end;
    
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
    if(not match) then 
        return nil 
    end;
    
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
    if(not match) then 
        return nil 
    end;
    
    local key = matchKeys["rating_delta"];
    return match and tonumber(match[key]);
end

function ArenaMatch:SetPartyRatingDelta(match, value)
    assert(match);

    local key = matchKeys["rating_delta"];
    match[key] = ToPositiveNumber(value, false);
end

-------------------------------------------------------------------------
-- Party MMR (8)

function ArenaMatch:GetPartyMMR(match)
    if(not match) then 
        return nil 
    end;
    
    local key = matchKeys["mmr"];
    return match and tonumber(match[key]);
end

function ArenaMatch:SetPartyMMR(match, value)
    assert(match);

    local key = matchKeys["mmr"];
    match[key] = ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Enemy Rating (9)

function ArenaMatch:GetEnemyRating(match)
    if(not match) then 
        return nil 
    end;
    
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
    if(not match) then 
        return nil 
    end;
    
    local key = matchKeys["enemy_rating_delta"];
    return match and tonumber(match[key]);
end

function ArenaMatch:SetEnemyRatingDelta(match, value)
    assert(match);

    local key = matchKeys["enemy_rating_delta"];
    match[key] = ToPositiveNumber(value, false);
end

-------------------------------------------------------------------------
-- Enemy MMR (11)

function ArenaMatch:GetEnemyMMR(match)
    if(not match) then 
        return nil 
    end;
    
    local key = matchKeys["enemy_mmr"];
    return match and tonumber(match[key]);
end

function ArenaMatch:SetEnemyMMR(match, value)
    assert(match);

    local key = matchKeys["enemy_mmr"];
    match[key] = ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Season (12)

function ArenaMatch:GetSeason(match)
    if(not match) then 
        return nil 
    end;
    
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
    if(not match) then 
        return nil 
    end;
    
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
    if(not match) then 
        return nil 
    end;
    
    local key = matchKeys["self"];
    return match and match[key];
end

function ArenaMatch:SetSelf(match, value)
    assert(match);

    local key = matchKeys["self"];
    match[key] = value;
end

-------------------------------------------------------------------------
-- First Death (16)

function ArenaMatch:GetFirstDeath(match)
    if(not match) then 
        return nil 
    end;
    
    local key = matchKeys["first_death"];
    return match[key];
end

function ArenaMatch:SetFirstDeath(match, value)
    assert(match);

    local player = ArenaMatch:GetSelf(match);
    if(value == player) then
        value = player;
    end
    
    local key = matchKeys["first_death"];
    match[key] = value;
end

-------------------------------------------------------------------------
-- Team (17)

function ArenaMatch:PrepareTeams(match)
    assert(match);

    local teamKey, enemyTeamKey = matchKeys["enemy_team"], matchKeys["team"];
    match[teamKey] = match[teamKey] or {};
    match[enemyTeamKey] = match[enemyTeamKey] or {};
end

function ArenaMatch:AddPlayers(match, players)
    assert(match and players);
    
    --ArenaMatch:PrepareTeams(match);

    for _,player in ipairs(players) do
        ArenaMatch:AddPlayer(match, player.isEnemy, player.name, player.race, player.class, player.spec, player.kills, player.deaths, player.damage, player.healing);
    end

    ArenaMatch:SortGroups(match);
    ArenaMatch:UpdateComps(match);
end

function ArenaMatch:AddPlayer(match, isEnemyTeam, name, raceID, classID, spec_id, kills, deaths, damage, healing)
    assert(match);
    ArenaAnalytics:Log("Adding player:", isEnemyTeam, name, raceID, classID, spec_id, kills, deaths, damage, healing)

    if(name ~= nil) then
        local selfKey = matchKeys["self"];
        local myName = selfKey and match[selfKey];
        if(myName) then
            if(name == myName) then
                name = 0;
            else
                local realm = myName:match("%-.+");
                if(realm and realm ~= "" and name:find(realm)) then
                    name = (name:match("^[^-]+") or name) .. '-' .. realm;
                end
            end
        end
    else
        ArenaAnalytics:Log("Warning: Adding player to stored match without name!");
    end

    local newPlayer = {}
    newPlayer[playerKeys["name"]] = name;
    newPlayer[playerKeys["race"]] = tonumber(raceID);
    newPlayer[playerKeys["spec_id"]] = tonumber(spec_id) or tonumber(classID);
    newPlayer[playerKeys["kills"]] = tonumber(kills);
    newPlayer[playerKeys["deaths"]] = tonumber(deaths);
    newPlayer[playerKeys["damage"]] = tonumber(damage);
    newPlayer[playerKeys["healing"]] = tonumber(healing);
    newPlayer[playerKeys["wins"]] = tonumber(wins);
    
    
    local teamKey = isEnemyTeam and matchKeys["enemy_team"] or matchKeys["team"];
    assert(teamKey);

    match[teamKey] = match[teamKey] or {}
    tinsert(match[teamKey], newPlayer);
end

function ArenaMatch:GetTeam(match, isEnemyTeam)
    if(not match) then 
        return nil 
    end;

    local key = isEnemyTeam and matchKeys["enemy_team"] or matchKeys["team"];
    return key and match[key];
end

function ArenaMatch:GetTeamSize(match, isEnemyTeam)
    if(not match) then 
        return nil 
    end;

    local bracketIndex = ArenaMatch:GetBracketIndex(match);
    return ArenaAnalytics:getTeamSizeFromBracketIndex(bracketIndex);
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

function ArenaMatch:GetPlayerInfo(match, player, isEnemyTeam)
    if(not match) then 
        return nil 
    end;

    if(not player) then
        return {};
    end

    local spec_id = ArenaMatch:GetPlayerValue(match, player, "spec_id");
    local class, spec = Constants:GetClassAndSpec(spec_id);
    
    local playerInfo = {
        name = ArenaMatch:GetPlayerName(match, player),
        race = ArenaMatch:GetPlayerValue(player, "race"),
        class = class,
        spec = spec,
        spec_id = spec_id,
        kills = ArenaMatch:GetPlayerValue(player, "kills"),
        deaths = ArenaMatch:GetPlayerValue(player, "deaths"),
        damage = ArenaMatch:GetPlayerValue(player, "damage"),
        healing = ArenaMatch:GetPlayerValue(player, "healing"),
        wins = ArenaMatch:GetPlayerValue(player, "wins"),
    }

    return playerInfo;
end

function ArenaMatch:GetPlayerValue(match, player, key)
    if(not match or not player) then 
        return nil;
    end
    
    if(key == nil) then
        return nil;
    end

    if(key == "name") then
        return ArenaMatch:GetPlayerName(match, player);
    end

    local playerKey = playerKeys[key];
    return playerKey and player[playerKey];
end

function ArenaMatch:GetComparisonValues(match, playerA, playerB, key)
    assert(match and key);
    local valueA = ArenaMatch:GetPlayerValue(match, playerA, key);
    local valueB = ArenaMatch:GetPlayerValue(match, playerB, key);
    return valueA, valueB;
end

function ArenaMatch:GetPlayerName(match, player)
    if(not match) then 
        return nil 
    end;

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
        local realm = string.match(selfName, "%-.+") or "";
        name = name .. realm;
    end

    return name;
end

local function GetTeamSpecs(team, size)
    if(not team or not size) then
        return nil;
    end

    if(#team ~= size) then
        return nil;
    end

    local teamSpecs = {}
    
    -- Gather all team specs, bailing out if any are missing
    for i,player in ipairs(team) do
        local spec_id = ArenaMatch:GetPlayerValue(match, player, "spec_id");
        if(not spec_id) then
            return nil;
        end

        tinsert(teamSpecs, spec_id);
    end

    if(#teamSpecs ~= size) then
        return nil;
    end

    return teamSpecs;
end

function ArenaMatch:GetComp(match, isEnemyComp)
    assert(match);

    local key = isEnemyComp and matchKeys["comp"] or matchKeys["enemyComp"];
    return key and match[key];
end

function ArenaMatch:UpdateComps(match)
    assert(match);

    local sizeKey = matchKeys.size;
    local size = sizeKey and match[sizeKey] or 0;
    if(size == 0) then
        return;
    end

    ArenaMatch:UpdateComp(match, false);
    ArenaMatch:UpdateComp(match, true);
end

function ArenaMatch:UpdateComp(match, isEnemyTeam)
    local team = ArenaMatch:GetTeam(match, isEnemyTeam);
    local teamSpecs = GetTeamSpecs(team, match.size);
    if(teamSpecs) then        
        table.sort(teamSpecs, function(a, b)
            return a < b;
        end);

        local compKey = (teamKey == "team") and "comp" or "enemy_comp";
        match[compKey] = table.concat(teamSpecs, '|');
    end
end

function ArenaMatch:SortGroups(match)
    assert(match);
    
    ArenaMatch:SortGroup(match, false);
    ArenaMatch:SortGroup(match, true);
end

function ArenaMatch:SortGroup(match, isEnemyTeam)
    assert(match);

    local group = ArenaMatch:GetTeam(match, isEnemyTeam);
    if(not group or #group == 0) then
		return;
	end
	
	-- Set playerName if missing
	if(not playerFullName) then
		playerFullName = ArenaMatch:GetSelf() or Helpers:GetPlayerName();
	end
	local name = playerFullName:match("^[^-]+");

    table.sort(group, function(playerA, playerB)
        local classA, classB = ArenaMatch:GetComparisonValues(match, playerA, playerB, "class");
        local specA, specB = ArenaMatch:GetComparisonValues(match, playerA, playerB, "spec");
		local nameA, nameB = ArenaMatch:GetComparisonValues(match, playerA, playerB, "name");
		
        if(not isEnemyTeam) then
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