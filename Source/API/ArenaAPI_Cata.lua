-- API adjusted functions to let calling code stay version agnostic.
local _, ArenaAnalytics = ...; -- Addon Namespace
local API = ArenaAnalytics.API;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;
local Localization = ArenaAnalytics.Localization;
local Internal = ArenaAnalytics.Internal;
local Bitmap = ArenaAnalytics.Bitmap;

-------------------------------------------------------------------------

API.defaultButtonTemplate = "UIServiceButtonTemplate";

API.availableBrackets = {
	{ name = "2v2", key = 1},
	{ name = "3v3", key = 2},
	{ name = "5v5", key = 3},
}

API.availableMaps = { 
    "BladesEdgeArena", 
    "NagrandArena", 
    "RuinsOfLordaeron", 
    "DalaranArena" 
};

function API:GetBattlefieldStatus(battlefieldId)
    local status, _, _, _, _, teamSize, isRated = GetBattlefieldStatus(battlefieldId);

    local matchType;
    if(API:IsRated()) then
        matchType = "rated";
    elseif(API:IsWarGame()) then
        matchType = "wargame";
    else
        matchType = "unrated";
    end

    local bracket = nil;
    if(teamSize == 2) then
        bracket = 1;
    elseif(teamSize == 3) then
        bracket = 2;
    elseif(teamSize == 5) then
        bracket = 3;
    end

    return status, bracket, matchType, teamSize;
end

function API:GetCurrentMapID()
    return select(8,GetInstanceInfo());
end

function API:GetPersonalRatedInfo(bracketIndex)
    bracketIndex = tonumber(bracketIndex);
    if(not bracketIndex) then
        return nil;
    end

    -- Solo Shuffle
    if(bracketIndex == 4) then
        return nil; -- NYI
    end

    local rating,_,_,seasonPlayed = GetPersonalRatedInfo(bracketIndex);
    return rating, seasonPlayed;
end

function API:GetPlayerScore(index, includeStats)
    local name, kills, _, deaths, _, teamIndex, _, race, _, classToken, damage, healing = GetBattlefieldScore(index);
    name = Helpers:ToFullName(name);

    -- Convert values
    local race_id = Localization:GetRaceID(race);
    local class_id = Internal:GetAddonClassID(classToken);

    local score = TablePool:Acquire();
    score.name = name;
    score.race = race_id;
    score.spec = class_id;
    score.team = teamIndex;
    score.kills = kills;
    score.deaths = deaths;
    score.damage = damage;
    score.healing = healing;

    if(API:IsInBattleground() or API:IsSoloShuffle() or includeStats) then
        local stats = TablePool:Acquire();

        for statIndex=1, GetNumBattlefieldStats() do
            local stat = GetBattlefieldStatData(index, statIndex);
            if(stat) then
                tinsert(stats, stat);
            end
        end

        if(#stats > 0) then
            score.stats = stats;
        end
    end

    return score;
end

function API:GetSpecialization(unitToken)
    unitToken = unitToken or "player";
    if(not UnitExists(unitToken)) then
        return nil;
    end

    local isInspect = (UnitGUID(unitToken) ~= UnitGUID("player"));

    local spec_id = nil;
	local currentSpecPoints = 0;

    local spec, currentSpecPoints = nil, 0;
    for i = 1, 3 do
        local id, _, _, _, pointsSpent = GetTalentTabInfo(i, isInspect);
		if (id and pointsSpent > currentSpecPoints) then
			currentSpecPoints = pointsSpent;
			spec = id;
		end
 	end

    return API:GetMappedAddonSpecID(spec);
end

-- Get local player current spec
function API:GetMySpec()
    local spec_id = nil;
	local currentSpecPoints = 0;

    for i = 1, 3 do
        local id, name, _, _, pointsSpent = GetTalentTabInfo(i);
		if (pointsSpent > currentSpecPoints) then
			currentSpecPoints = pointsSpent;
			spec_id = API:GetMappedAddonSpecID(id);
		end
 	end

    return spec_id;
end

function API:GetInspectSpecialization(unitToken)
    if(not unitToken or not UnitExists(unitToken)) then
        return;
    end

    if(UnitGUID("player") == UnitGUID(unitToken)) then
        return API:GetMySpec();
    end

    local spec, currentSpecPoints = nil, 0;
    for i = 1, 3 do
        local id, _, _, _, pointsSpent = GetTalentTabInfo(i, true);
		if (id and pointsSpent > currentSpecPoints) then
			currentSpecPoints = pointsSpent;
			spec = id;
		end
 	end

    return API:GetMappedAddonSpecID(spec);
end

function API:GetPlayerInfoByGUID(GUID)
    local _,class,_,race,_,name,realm = GetPlayerInfoByGUID(GUID);
    return class,race,name,realm;
end

API.maxRaceID = 70;

API.classMappingTable = {
    [1] = 80,
    [2] = 10,
    [3] = 40,
    [4] = 60,
    [5] = 90,
    [6] = 30,
    [7] = 20,
    [8] = 50,
    [9] = 70,
    [10] = 100,
    [11] = 0,
    [12] = 110,
    [13] = 120,
}

-- Internal Addon Spec ID to expansion spec IDs
API.specMappingTable = {
    [748] = 1, -- Restoration Druid
    [750] = 2, -- Feral Druid
    [752] = 3, -- Balance Druid

    [831] = 11, -- Holy Paladin
    [839] = 12, -- Protection Paladin
    [855] = 14, -- Retribution Paladin

    [262] = 21, -- Restoration Shaman
    [261] = 22, -- Elemental Shaman
    [263] = 23, -- Enhancement Shaman

    [400] = 31, -- Unholy Death Knight
    [399] = 32, -- Frost Death Knight
    [398] = 33, -- Blood Death Knight

    [811] = 41, -- Beast Mastery Hunter
    [807] = 42, -- Marksmanship Hunter
    [809] = 43, -- Survival Hunter

    [823] = 51, -- Frost Mage
    [851] = 52, -- Fire Mage
    [799] = 53, -- Arcane Mage

    [183] = 61, -- Subtlety Rogue
    [182] = 62, -- Assassination Rogue
    [181] = 63, -- Combat Rogue

    [871] = 71, -- Affliction Warlock
    [865] = 72, -- Destruction Warlock
    [867] = 73, -- Demonology Warlock

    [845] = 81, -- Protection Warrior
    [746] = 82, -- Arms Warrior
    [815] = 83, -- Fury Warrior

    [760] = 91, -- Discipline Priest
    [813] = 92, -- Holy Priest
    [795] = 93, -- Shadow Priest
}

-------------------------------------------------------------------------
-- Overrides

API.roleBitmapOverrides = nil;
local function InitializeRoleBitmapOverrides()
    API.roleBitmapOverrides = {
        [43] = Bitmap.roles.ranged_damager, -- Survival hunter
    }
end

API.specIconOverrides = nil;
local function InitializeSpecOverrides()
    API.specIconOverrides = {
        -- Paladin
        [12] = [[Interface\Icons\spell_holy_devotionaura]], -- Protection

        -- Hunter
        [41] = [[Interface\Icons\ability_hunter_bestialdiscipline]], -- Beast Mastery
        [42] = [[Interface\Icons\ability_hunter_focusedaim]], -- Marksmanship
        [43] = [[Interface\Icons\ability_hunter_camouflage]], -- Survival

        -- Warrior
        [82] = [[Interface\Icons\ability_warrior_savageblow]], -- Arms
    }
end

-------------------------------------------------------------------------
-- Expansion API initializer

function API:InitializeExpansion()
    InitializeRoleBitmapOverrides();
    InitializeSpecOverrides();
end