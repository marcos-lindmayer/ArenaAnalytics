local _, ArenaAnalytics = ...; -- Addon Namespace
local ArenaMatch = ArenaAnalytics.ArenaMatch;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;
local Constants = ArenaAnalytics.Constants;
local Internal = ArenaAnalytics.Internal;

-------------------------------------------------------------------------

local matchTypes = { "rated", "skirmish", "wargame" }
local brackets = { "2v2", "3v3", "5v5", "shuffle" }

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
}

local playerKeys = {
    name = 0,
    realm = -1,
    is_self = -2,
    is_first_death = -3,
    race = -4,
    spec_id = -5,
    deaths = -6,
    kills = -7,
    healing = -8,
    damage = -9,
    wins = -10,
}

-------------------------------------------------------------------------
-- Helper functions

local function ToPositiveNumber(value, allowZero)
    value = tonumber(value);
    if(not value) then
        return;
    end

    value = Round(value);

    if(value == 0) then
        if(not allowZero) then
            return;
        end
        return 0;
    end

    return (value > 0) and value;
end

local function ToNumericalBool(value)
    if(value == nil) then
        return;
    end
    return (value and value ~= 0) and 1 or 0;
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
    local mapID = ArenaMatch:GetMapID(match);
    return mapID and Constants:GetShortMapName(mapID);
end

function ArenaMatch:SetMapID(match, value)
    assert(match);

    if(type(value) == "string") then
        value = Constants:GetMapIdByKey(mapKey);
    end

    local key = matchKeys.map;
    match[key] = tonumber(value);
end

function ArenaMatch:SetMap(match, value)
    assert(match);

    local key = matchKeys.map;
    mapId = tonumber(value) or Constants:GetMapIdByKey(value);
    match[key] = tonumber(mapId);
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
    return bracketIndex and brackets[bracketIndex];
end

function ArenaMatch:SetBracketIndex(match, value)
    assert(match);

    local key = matchKeys.bracket;
    match[key] = tonumber(value);
end

function ArenaMatch:SetBracket(match, value)
    assert(match);
    local key = matchKeys.bracket;

    value = Helpers:ToSafeLower(value);
    for index,bracket in ipairs(brackets) do
        if(value == Helpers:ToSafeLower(bracket)) then
            match[key] = index;
            return;
        end
    end
    
    ArenaAnalytics:Log("Error: Attempted to set invalid bracket:", value);
    match[key] = nil;
end

-------------------------------------------------------------------------
-- Match Type (5)

-- rated, skirmish or wargame
function ArenaMatch:GetMatchType(match)
    if(not match) then 
        return nil 
    end;
    
    local key = matchKeys.match_type;
    local typeKey = match and tonumber(match[key]);
    return typeKey and matchTypes[typeKey];
end

function ArenaMatch:SetMatchType(match, value)
    assert(match);
    local key = matchKeys.match_type;
    
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

    local key = matchKeys.rating_delta;
    match[key] = ToPositiveNumber(value, false);
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
    match[key] = ToPositiveNumber(value, false);
end

-------------------------------------------------------------------------
-- Enemy MMR (11)

function ArenaMatch:GetEnemyMMR(match)
    if(not match) then 
        return nil 
    end;
    
    local key = matchKeys.enemy_mmr;
    return match and tonumber(match[key]);
end

function ArenaMatch:SetEnemyMMR(match, value)
    assert(match);

    local key = matchKeys.enemy_mmr;
    match[key] = ToPositiveNumber(value, true);
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

    local key = matchKeys.season;
    match[key] = ToPositiveNumber(value, true);
end

-------------------------------------------------------------------------
-- Session (13)

function ArenaMatch:GetSession(match)
    if(not match) then 
        return nil 
    end;
    
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

    match[matchKeys.won] = ToNumericalBool(value);
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
    assert(match and players);

    for _,player in ipairs(players) do
        ArenaMatch:AddPlayer(match, player.isEnemy, player.name, player.race, player.class, player.spec, player.kills, player.deaths, player.damage, player.healing);
    end

    ArenaMatch:SortGroups(match);
    ArenaMatch:UpdateComps(match);
end

function ArenaMatch:AddPlayer(match, isEnemyTeam, fullName, raceID, classID, spec_id, kills, deaths, damage, healing)
    assert(match);

    if(fullName == nil) then
        ArenaAnalytics:Log("Warning: Adding player to stored match without name!");
    end
    
    local name, realm = ArenaAnalytics:GetNameAndRealm(fullName, true);
    
    local newPlayer = {}
    SetPlayerValue(match, newPlayer, "name", name);
    SetPlayerValue(match, newPlayer, "realm", realm);
    SetPlayerValue(match, newPlayer, "race", tonumber(raceID));
    SetPlayerValue(match, newPlayer, "spec_id", (tonumber(spec_id) or tonumber(classID)));
    SetPlayerValue(match, newPlayer, "kills", tonumber(kills));
    SetPlayerValue(match, newPlayer, "deaths", tonumber(deaths));
    SetPlayerValue(match, newPlayer, "damage", tonumber(damage));
    SetPlayerValue(match, newPlayer, "healing", tonumber(healing));
    SetPlayerValue(match, newPlayer, "wins", tonumber(wins));
    
    local teamKey = isEnemyTeam and matchKeys.enemy_team or matchKeys.team;
    assert(teamKey);

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

function ArenaMatch:GetTeam(match, isEnemyTeam)
    if(not match) then 
        return nil;
    end;

    local key = isEnemyTeam and matchKeys.enemy_team or matchKeys.team;
    return key and match[key] or {};
end

function ArenaMatch:GetTeamSize(match, isEnemyTeam)
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

function ArenaMatch:GetPlayerInfo(player)
    if(not player) then
        return nil;
    end

    local spec_id = ArenaMatch:GetPlayerValue(player, "spec_id");
    local class, spec = Constants:GetClassAndSpec(spec_id);

    local name = player[playerKeys.name];
    local realm = ArenaAnalytics:GetRealm(player[playerKeys.realm]);
    local race_id = ArenaMatch:GetPlayerValue(player, "race");

    local playerInfo = {
        is_self = (ArenaMatch:GetPlayerValue(player, "is_self") == 1),
        is_first_death = (ArenaMatch:GetPlayerValue(player, "is_first_death") == 1),
        name = name,
        realm = realm,
        fullName = ArenaAnalytics:CombineNameAndRealm(name, realm),
        faction = Internal:GetRaceFaction(race_id),
        race = Internal:GetRace(race_id),
        race_id = race_id,
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

function ArenaMatch:GetPlayerValue(player, key)
    if(not player or not key) then 
        return nil;
    end

    if(key == "full_name") then
        return ArenaMatch:GetPlayerFullName(player);
    end

    local playerKey = playerKeys[key];
    return playerKey and player[playerKey];
end

function ArenaMatch:GetComparisonValues(playerA, playerB, key)
    assert(key);
    local valueA = ArenaMatch:GetPlayerValue(playerA, key);
    local valueB = ArenaMatch:GetPlayerValue(playerB, key);
    return valueA, valueB;
end

function ArenaMatch:GetPlayerFullName(player)
    if(not player) then
        return "";
    end

    local name, realm = ArenaMatch:GetPlayerNameAndRealm(player);
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

    local key = isEnemyComp and matchKeys.comp or matchKeys["enemyComp"];
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
        local classA, classB = ArenaMatch:GetComparisonValues(playerA, playerB, "class");
        local specA, specB = ArenaMatch:GetComparisonValues(playerA, playerB, "spec");
		local nameA, nameB = ArenaMatch:GetComparisonValues(playerA, playerB, "name");
		
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

-------------------------------------------------------------------------
-- Self

function ArenaMatch:GetSelf(match)
    if(not match) then 
        return nil 
    end;
    
    local team = ArenaMatch:GetTeam(match, false);
    if(team) then
        for i,player in ipairs(team) do
            if(ArenaMatch:GetPlayerValue(match, player, "is_self") == 1) then
                return ArenaMatch:GetPlayerInfo(player);
            end
        end
    end
end

function ArenaMatch:SetSelf(match, fullName)
    assert(match);

    if(not fullName) then
        return;
    end

    ArenaMatch:SetTeamMemberValue(match, false, fullName, "is_self", 1);
end

-------------------------------------------------------------------------
-- First Death

function ArenaMatch:GetFirstDeath(match)
    if(not match) then 
        return nil 
    end;

    local team = ArenaMatch:GetTeam(match, false);
    if(team) then
        for i,player in ipairs(team) do
            if(ArenaMatch:GetPlayerValue(match, player, "is_first_death") == 1) then
                return ArenaMatch:GetPlayerInfo(player);
            end
        end
    end
    
    local enemyTeam = ArenaMatch:GetTeam(match, false);
    if(enemyTeam) then
        for i,player in ipairs(enemyTeam) do
            if(ArenaMatch:GetPlayerValue(match, player, "is_first_death") == 1) then
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
