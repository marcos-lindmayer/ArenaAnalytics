-- API adjusted functions to let calling code stay version agnostic.
local _, ArenaAnalytics = ...; -- Addon Namespace
local API = ArenaAnalytics.API;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;
local Localization = ArenaAnalytics.Localization;
local Internal = ArenaAnalytics.Internal;
local Bitmap = ArenaAnalytics.Bitmap;

-------------------------------------------------------------------------

API.defaultButtonTemplate = "UIPanelButtonTemplate";

-- Order defines the UI order of maps bracket dropdown
API.availableBrackets = {
    { name = "Solo", key = 4},
	{ name = "2v2", key = 1},
	{ name = "3v3", key = 2},
	{ name = "5v5", key = 3},
}

-- Order defines the UI order of maps filter dropdown
API.availableMaps = {
    { id = 1505,  token = "NagrandArena" },
    { id = 572,  token = "RuinsOfLordaeron" },
    { id = 2167, token = "TheRobodrome" },
    { id = 2563, token = "NokhudonProvingGrounds" },
    { id = 1552,  token = "AshamanesFall" },
    { id = 1672,  token = "BladesEdgeArena" },
    { id = 1911,  token = "Mugambala" },
    { id = 1504,  token = "BlackRookHoldArena" },
    { id = 1825,  token = "HookPoint" },
    { id = 2373, token = "EmpyreanDomain" },
    { id = 617,  token = "DalaranArena" },
    { id = 1134,  token = "TheTigersPeak" },
    { id = 2547, token = "EnigmaCrucible" },
    { id = 2509, token = "MaldraxxusColiseum" },
    { id = 980,  token = "TolVironArena" },
}

function API:IsInArena()
    return IsActiveBattlefieldArena() and not C_PvP.IsInBrawl(); -- TODO: Add solo shuffle support
end

function API:IsRatedArena()
    return API:IsInArena() and (C_PvP.IsRatedArena() or C_PvP.IsRatedSoloShuffle()) and not IsWargame() and not IsArenaSkirmish() and not C_PvP.IsInBrawl();
end

function API:GetBattlefieldStatus(battlefieldId)
    local status,_, teamSize = GetBattlefieldStatus(battlefieldId);
    local isRated = API:IsRatedArena();

    return status, teamSize, isRated;
end

function API:GetCurrentMapID()
    return select(8,GetInstanceInfo());
end

function API:GetTeamMMR(teamIndex)
    local _,_,_,mmr = GetBattlefieldTeamInfo(teamIndex);
    return tonumber(mmr);
end

function API:GetPersonalRatedInfo(bracketIndex)
    bracketIndex = tonumber(bracketIndex);
    if(not bracketIndex) then
        return nil;
    end

    -- Solo Shuffle
    if(bracketIndex == 4) then
        bracketIndex = 7;
    end

    local rating,_,_,seasonPlayed = GetPersonalRatedInfo(bracketIndex);
    return rating, seasonPlayed;
end

-- TODO: Decide if we wanna get rating and MMR values from here
function API:GetBattlefieldScore(index)
    local scoreInfo = C_PvP.GetScoreInfo(index);
    name = Helpers:ToFullName(scoreInfo.name);

    -- Convert localized values
    local race_id = Localization:GetRaceID(scoreInfo.raceName);
    local spec_id = Localization:GetSpecID(scoreInfo.classToken, scoreInfo.talentSpec);

    -- Fall back to class ID
    if(not spec_id) then
        spec_id = Internal:GetAddonClassID(scoreInfo.classToken);
    end

    --ArenaAnalytics:Log("Score:", name);
    --Helpers:DebugLogTable(scoreInfo.stats);
    
    return name, race_id, spec_id, scoreInfo.faction, scoreInfo.killingBlows, scoreInfo.deaths, scoreInfo.damageDone, scoreInfo.healingDone;
end

-- Get local player current spec
function API:GetMySpec()
    local currentSpec = GetSpecialization();
    local id = currentSpec and GetSpecializationInfo(currentSpec);

    local spec_id = API:GetMappedAddonSpecID(id);
	ArenaAnalytics:Log("My Spec ID:", spec_id, "from ID:", id);
	return spec_id;
end

function API:GetInspectSpecialization(unitToken)
    if(not unitToken or not UnitExists(unitToken)) then
        return;
    end

    if(UnitGUID("player") == UnitGUID(unitToken)) then
        return API:GetMySpec();
    end

    local specID = GetInspectSpecialization(unitToken);
    return API:GetMappedAddonSpecID(specID);
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
    [105] = 1, -- Restoration Druid
    [103] = 2, -- Feral Druid
    [102] = 3, -- Balance Druid
    [104] = 4, -- Guardian Druid

    [65] = 11, -- Holy Paladin
    [66] = 12, -- Protection Paladin
    [70] = 14, -- Retribution Paladin

    [264] = 21, -- Restoration Shaman
    [262] = 22, -- Elemental Shaman
    [263] = 23, -- Enhancement Shaman

    [252] = 31, -- Unholy Death Knight
    [251] = 32, -- Frost Death Knight
    [250] = 33, -- Blood Death Knight

    [253] = 41, -- Beast Mastery Hunter
    [254] = 42, -- Marksmanship Hunter
    [255] = 43, -- Survival Hunter

    [64] = 51, -- Frost Mage
    [63] = 52, -- Fire Mage
    [62] = 53, -- Arcane Mage

    [261] = 61, -- Subtlety Rogue
    [259] = 62, -- Assassination Rogue
    [260] = 64, -- Outlaw Rogue

    [265] = 71, -- Affliction Warlock
    [267] = 72, -- Destruction Warlock
    [266] = 73, -- Demonology Warlock

    [73] = 81, -- Protection Warrior
    [71] = 82, -- Arms Warrior
    [72] = 83, -- Fury Warrior

    [256] = 91, -- Discipline Priest
    [257] = 92, -- Holy Priest
    [258] = 93, -- Shadow Priest

    [270] = 101, -- Mistweaver Monk
    [268] = 102, -- Brewmaster Monk
    [269] = 103, -- Windwalker Monk

    [581] = 111, -- Vengeance Demon Hunter
    [577] = 112, -- Havoc Demon Hunter

    [1468] = 121, -- Preservation Evoker
    [1473] = 122, -- Augmentation Evoker
    [1467] = 123, -- Devastation Evoker
}

function API:GetMappedAddonSpecID(specID)
    specID = tonumber(specID);

    local spec_id = specID and API.specMappingTable[specID];
    if(not spec_id) then
        ArenaAnalytics:Log("Failed to find spec_id for:", specID, type(specID));
        return nil;
    end

    return spec_id;
end

-------------------------------------------------------------------------
-- Overrides

API.roleBitmapOverrides = nil;
local function InitializeRoleBitmapOverrides()
    API.roleBitmapOverrides = {
        [43] = Bitmap.roles.melee_damager, -- Survival hunter
    }
end

API.specIconOverrides = nil;
local function InitializeSpecOverrides()
    API.specIconOverrides = {
        []
     }
end
-------------------------------------------------------------------------
-- Expansion API initializer

function API:InitializeExpansion()
    InitializeRoleBitmapOverrides();
end