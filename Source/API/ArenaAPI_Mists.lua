-- API adjusted functions to let calling code stay version agnostic.
local _, ArenaAnalytics = ...; -- Addon Namespace
local API = ArenaAnalytics.API;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;
local Localization = ArenaAnalytics.Localization;
local Internal = ArenaAnalytics.Internal;
local Bitmap = ArenaAnalytics.Bitmap;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------

API.defaultButtonTemplate = "UIPanelButtonTemplate";
API.enableInspection = true;
API.disableSpecInfoAPI = true;
API.hasDampening = true;

-- Order defines the UI order of maps bracket dropdown
API.availableBrackets = {
    -- { name = "Solo", key = 4, requireMatches = true },    -- TODO: Implement requireMatches logic
    { name = "2v2", key = 1 },
    { name = "3v3", key = 2 },
    { name = "5v5", key = 3 },
};

-- Order defines the UI order of maps filter dropdown
API.availableMaps = {
    "BladesEdgeArena",
    "NagrandArena",
    "RuinsOfLordaeron",
    "DalaranArena",
    "TigersPeak",
    "TolVironArena",
};

function API:IsRatedArena()
    return API:IsInArena() and C_PvP.IsRatedMap() and not API:IsWargame() and not API:IsSkirmish();
end

function API:GetBattlefieldStatus(battlefieldId)
    if(not battlefieldId) then
        Debug:LogError("API:GetBattlefieldStatus called with invalid battlefieldId.");
        return nil;
    end

    local status, _, _, _, _, teamSize = GetBattlefieldStatus(battlefieldId);

    local bracket = API:DetermineBracket(teamSize);
    local matchType = API:DetermineMatchType();

    return status, bracket, teamSize, matchType;
end

function API:GetPersonalRatedInfo(bracketIndex)
    bracketIndex = tonumber(bracketIndex);
    if(not bracketIndex) then
        return nil;
    end

    -- Solo Shuffle
    if(bracketIndex == 4) then
        return nil;
    end

    local rating,_,_,seasonPlayed = GetPersonalRatedInfo(bracketIndex);
    return tonumber(rating), tonumber(seasonPlayed);
end

function API:GetPlayerScore(index)
    local name, kills, _, deaths, _, teamIndex, _, race, _, classToken, damage, healing = GetBattlefieldScore(index);
    name = API:ToFullName(name);

    -- Convert values
    local race_id = Localization:GetRaceID(race);
    local class_id = Internal:GetAddonClassID(classToken);

    local score = {
        name = name,
        race = race_id,
        spec = class_id,
        team = teamIndex,
        kills = kills,
        deaths = deaths,
        damage = damage,
        healing = healing,
    };

    return score;
end

function API:GetSpecialization(unitToken, explicit)
    if(unitToken ~= nil) then
        Debug:Log("API:GetSpecialization", unitToken, explicit)
    end

    if(explicit and not unitToken) then
        return nil;
    end

    unitToken = unitToken or "player";
    if(not UnitExists(unitToken)) then
        return nil;
    end

    if(UnitGUID(unitToken) == UnitGUID("player")) then
        local currentSpec = C_SpecializationInfo.GetSpecialization();
		if(currentSpec == 5) then
			return nil;
		end

        local id = currentSpec and C_SpecializationInfo.GetSpecializationInfo(currentSpec);
        return API:GetMappedAddonSpecID(id);
    end

    -- TODO: Figure out what will work in MoP Beta
    --local specID = C_SpecializationInfo.GetSpecialization(true);
    local specID = GetInspectSpecialization(unitToken);
    if(specID == nil or specID == 0) then
        return nil;
    end

    return API:GetMappedAddonSpecID(specID);
end

API.maxRaceID = 70;

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
    [260] = 63, -- Outlaw Rogue

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
};

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
        -- Paladin
        [12] = [[Interface\Icons\spell_holy_devotionaura]], -- Protection

        -- Shaman
        [23] = [[Interface\Icons\spell_shaman_improvedstormstrike]], -- Enhancement

        -- Hunter
        [41] = [[Interface\Icons\ability_hunter_bestialdiscipline]], -- Beast Mastery
        [42] = [[Interface\Icons\ability_hunter_focusedaim]], -- Marksmanship
        [43] = [[Interface\Icons\ability_hunter_camouflage]], -- Survival

        -- Rogue
        [62] = [[Interface\Icons\Ability_rogue_deadlybrew]], -- Assassination

        -- Warrior
        [82] = [[Interface\Icons\ability_warrior_savageblow]], -- Arms

        -- Priest
        [91] = [[Interface\Icons\spell_holy_powerwordshield]], -- Discipline
    };
end

-------------------------------------------------------------------------
-- Expansion API initializer

function API:InitializeExpansion()
    InitializeRoleBitmapOverrides();
    InitializeSpecOverrides();
end