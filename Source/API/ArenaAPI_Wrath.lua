-- API adjusted functions to let calling code stay version agnostic.
local _, ArenaAnalytics = ...; -- Addon Namespace
local API = ArenaAnalytics.API;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;
local Localization = ArenaAnalytics.Localization;
local Internal = ArenaAnalytics.Internal;
local Bitmap = ArenaAnalytics.Bitmap;
local TablePool = ArenaAnalytics.TablePool;

-------------------------------------------------------------------------

API.defaultButtonTemplate = "UIServiceButtonTemplate";

API.availableBrackets = {
	{ name = "2v2", key = 1},
	{ name = "3v3", key = 2},
	{ name = "5v5", key = 3},
};

API.availableMaps = { 
    "BladesEdgeArena", 
    "NagrandArena", 
    "RuinsOfLordaeron", 
    "DalaranArena" 
};

function API:IsInArena()
    return IsActiveBattlefieldArena();
end

function API:GetBattlefieldStatus(battlefieldId)
    local status, _, _, _, _, teamSize, isRated = GetBattlefieldStatus(battlefieldId);
    
    local bracket = nil;
    if(teamSize == 2) then
        bracket = 1;
    elseif(teamSize == 3) then
        bracket = 2;
    elseif(teamSize == 5) then
        bracket = 3;
    end

    return status, bracket, teamSize, isRated;
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

    return score;
end

local specByIndex = {
    ["DRUID"] = { 3, 2, 1 }, -- Balance, Feral, Resto
    ["PALADIN"] = { 11, 12, 14 }, -- Holy, Prot, Ret
    ["SHAMAN"] = { 22, 23, 21 }, -- Ele, Enh, Resto
    ["DEATHKNIGHT"] = { 33, 32, 31 }, -- Blood, Frost, Unholy
    ["HUNTER"] = { 41, 42, 43 }, -- BM, MM, Surv
    ["MAGE"] = { 53, 52, 51 }, -- Arcane, Fire, Frost
    ["ROGUE"] = { 62, 63, 61 }, -- Assa, Combat, Sub
    ["WARLOCK"] = { 71, 73, 72 }, -- Affli, Demo, Destro
    ["WARRIOR"] = { 82, 83, 81 }, -- Arms, Fury, Prot
    ["PRIEST"] = { 91, 92, 93 }, -- Disc, Holy, Shadow
};

local function GetPointsSpent(index, isInspect)
    if(isInspect) then
        return select(3,GetTalentTabInfo(index, true));
    end

    return select(3,GetTalentTabInfo(index));
end

-- Get local player current spec
function API:GetSpecialization(unitToken)
    unitToken = unitToken or "player";
    if(not UnitExists(unitToken)) then
        return nil;
    end

    local isInspect = (UnitGUID(unitToken) ~= UnitGUID("player"));

    local spec_id = nil
	local currentSpecPoints = 0;
    local isPlausiblePreg = true;

    -- Determine spec
    local _,classToken = UnitClass(unitToken);
    if(not classToken) then
        ArenaAnalytics:LogWarning("API:GetMySpec failed to retrieve class token.");
        return nil;
    end

    if(classToken ~= "PALADIN") then
        -- Not paladin, cannot be preg.
        isPlausiblePreg = false;
    end

    for i = 1, 3 do
        local pointsSpent = GetPointsSpent(i, isInspect);
        local spec = specByIndex[classToken] and specByIndex[classToken][i];
		if (pointsSpent > currentSpecPoints) then
			currentSpecPoints = pointsSpent;
			spec_id = spec;
		end

        if(isPlausiblePreg) then
            if(spec == 11) then -- Holy
                if(pointsSpent > 10) then -- Max 15 holy points for preg (0 is expected)
                    isPlausiblePreg = false;
                end
            elseif(spec == 12) then -- Protection
                if(pointsSpent < 15 or pointsSpent > 30) then -- Max 30 protection points for preg (28 expected)
                    isPlausiblePreg = false;
                end
            elseif(spec == 14) then -- Retribution
                if(pointsSpent < 15 or pointsSpent > 45) then -- Max 45 retribution points for preg (43 expected)
                    isPlausiblePreg = false;
                end
            end
        end
 	end

    if(spec_id and isPlausiblePreg) then
        spec_id = 13;
    end

    return spec_id;
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

    [839] = 11, -- Holy Paladin
    [845] = 12, -- Protection Paladin
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

-------------------------------------------------------------------------
-- Expansion API initializer

function API:InitializeExpansion()
    InitializeRoleBitmapOverrides();
end