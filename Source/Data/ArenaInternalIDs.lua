local _, ArenaAnalytics = ...; -- Addon Namespace
local Internal = ArenaAnalytics.Internal;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;
local Constants = ArenaAnalytics.Constants;
local Bitmap = ArenaAnalytics.Bitmap;
local API = ArenaAnalytics.API;
local Debug = ArenaAnalytics.Debug;
local TablePool = ArenaAnalytics.TablePool;

-------------------------------------------------------------------------
-- Maps

local mapTokens = {
    [559] = "NagrandArena",
    [1505] = "NagrandArena",

    [562] = "BladesEdgeArena",
    [1672] = "BladesEdgeArena",

    [617] = "DalaranArena",
    [571] = "DalaranArena", -- Northrend ID (Some imports use it, assuming Dalaran Arena)

    [572] = "RuinsOfLordaeron",
    [2167] = "TheRobodrome",
    [2563] = "NokhudonProvingGrounds",
    [1552] = "AshamanesFall",
    [1911] = "Mugambala",
    [1504] = "BlackRookHoldArena",
    [1825] = "HookPoint",
    [2373] = "EmpyreanDomain",
    [1134] = "TigersPeak",
    [2547] = "EnigmaCrucible",
    [2509] = "MaldraxxusColiseum",
    [980] = "TolVironArena",
    [2759] = "CageOfCarnage",
};

function Internal:GetMapToken(mapID)
    mapID = tonumber(mapID);
    if(not mapID or mapID == 0) then
        return nil;
    end

    local token = mapID and mapTokens[mapID];

    if(not token) then
        Debug:LogWarning("Failed to retrieve token for mapID:", mapID);
        return nil;
    end

    return token;
end

Internal.addonMapIDs = {
    [1]  =  { token = "BladesEdgeArena", shortName = "BEA", name = "Blade's Edge Arena" },
    [2]  =  { token = "RuinsOfLordaeron", shortName = "RoL", name = "Ruins of Lordaeron" },
    [3]  =  { token = "NagrandArena", shortName = "NA", name = "Nagrand Arena" },

    [4]  =  { token = "RingOfValor", shortName = "RoV", name = "Ring of Valor" },
    [5]  =  { token = "DalaranArena", shortName = "DA", name = "Dalaran Arena" },

    [6]  =  { token = "TigersPeak", shortName = "TP", name = "The Tiger's Peak" },
    [7]  =  { token = "TolVironArena", shortName = "TVA", name = "Tol'Viron Arena" },

    [8]  =  { token = "AshamanesFall", shortName = "AF", name = "Ashamane's Fall" },
    [9]  =  { token = "BlackRookHoldArena", shortName = "BRH", name = "Black Rook Hold Arena" },

    [10] =  { token = "HookPoint", shortName = "HP", name = "Hook Point" },
    [11] =  { token = "KulTirasArena", shortName = "KTA", name = "Kul Tiras Arena" }, -- Non-existent arena? (Hook Point by wrong name?)
    [12] =  { token = "Mugambala", shortName = "M", name = "Mugambala" },
    [13] =  { token = "TheRobodrome", shortName = "TR", name = "The Robodrome" },

    [14] =  { token = "EmpyreanDomain", shortName = "ED", name = "Empyrean Domain" },
    [15] =  { token = "EnigmaCrucible", shortName = "EC", name = "Enigma Crucible" },
    [16] =  { token = "MaldraxxusColiseum", shortName = "MC", name = "Maldraxxus Coliseum" },

    [17] =  { token = "NokhudonProvingGrounds", shortName = "NPG", name = "Nokhudon Proving Grounds" },
    [18] =  { token = "CageOfCarnage", shortName = "CoC", name = "Cage of Carnage" },
};

Internal.mapLookupTable = {};

local function fillMapLookupTable()
    local keys = { "token", "shortName", "name" };

    for map_id, data in pairs(Internal.addonMapIDs) do
        -- Support silently continuing from provided map_id.
        Internal.mapLookupTable[map_id] = tonumber(map_id);

        for i,key in ipairs(keys) do
            local value = Helpers:ToSafeLower(data[key]);
            if(Helpers:IsValidValue(value)) then
                Internal.mapLookupTable[value] = tonumber(map_id);
            end
        end
    end

    -- Add game map IDs to addon map_id mapping
    for mapID,token in pairs(mapTokens) do
        assert(mapID and Internal.addonMapIDs[mapID] == nil, "Game map ID found overlapping with addon ID, breaks assumptions.");

        token = Helpers:ToSafeLower(token);
        local spec_id = Internal.mapLookupTable[token];

        if(not spec_id) then
            Debug:LogWarning("Failed to find spec_id for map token:", token);
        end

        Internal.mapLookupTable[mapID] = tonumber(spec_id);
    end
end
fillMapLookupTable();


function Internal:GetAddonMapID(map)
    map = tonumber(map) or Helpers:ToSafeLower(map);
    return map and tonumber(Internal.mapLookupTable[map]);
end

function Internal:GetShortMapName(map_id)
    local mapInfo = map_id and Internal.addonMapIDs[map_id];
    return mapInfo and mapInfo.shortName;
end

function Internal:GetMapName(map_id)
    local mapInfo = map_id and Internal.addonMapIDs[map_id];
    return mapInfo and mapInfo.name;
end

-------------------------------------------------------------------------
-- Race

-- Odd = Alliance, Even = Horde
local addonRaceIDs = {
    [1]  = { token = "Human",                name = "Human" },
    [3]  = { token = "Dwarf",                name = "Dwarf" },
    [5]  = { token = "NightElf",             name = "Night Elf" },
    [7]  = { token = "Gnome",                name = "Gnome" },
    [9]  = { token = "Draenei",              name = "Draenei" },
    [11] = { token = "Worgen",               name = "Worgen" },
    [13] = { token = "Pandaren",             name = "Pandaren" },
    [15] = { token = "Dracthyr",             name = "Dracthyr" },
    [17] = { token = "VoidElf",              name = "Void Elf" },
    [19] = { token = "LightforgedDraenei",   name = "Lightforged Draenei" },
    [21] = { token = "DarkIronDwarf",        name = "Dark Iron Dwarf" },
    [23] = { token = "Earthen",              name = "Earthen" },
    [25] = { token = "KulTiran",             name = "Kul Tiran" },
    [27] = { token = "Mechagnome",           name = "Mechagnome" },
    [29] = { token = "Haranir",              name = "Haranir" },

    [2]  = { token = "Orc",                  name = "Orc" },
    [4]  = { token = "Undead",               name = "Undead" },
    [6]  = { token = "Tauren",               name = "Tauren" },
    [8]  = { token = "Troll",                name = "Troll" },
    [10] = { token = "BloodElf",             name = "Blood Elf" },
    [12] = { token = "Goblin",               name = "Goblin" },
    [14] = { token = "Pandaren",             name = "Pandaren" },
    [16] = { token = "Dracthyr",             name = "Dracthyr" },
    [18] = { token = "Nightborne",           name = "Nightborne" },
    [20] = { token = "HighmountainTauren",   name = "Highmountain Tauren" },
    [22] = { token = "MagharOrc",            name = "Mag'har Orc" },
    [24] = { token = "Earthen",              name = "Earthen" },
    [26] = { token = "ZandalariTroll",       name = "Zandalari Troll" },
    [28] = { token = "Vulpera",              name = "Vulpera" },
    [30] = { token = "Haranir",              name = "Haranir" },
};

Internal.raceLookupTable = {};

local function fillRaceLookupTable()
    local keys = { "token", "name" };

    for race_id, data in pairs(addonRaceIDs) do
        for i,key in ipairs(keys) do
            local value = Helpers:ToSafeLower(data[key]);
            if(Helpers:IsValidValue(value)) then
                Internal.raceLookupTable[value] = tonumber(race_id);
            end
        end
    end
end
fillRaceLookupTable();

function Internal:GetAddonRaceIDByToken(token, factionIndex)
    if(not token) then
        return nil;
    end

    token = Helpers:ToSafeLower(token);
    factionIndex = tonumber(factionIndex);

    if(token == "scourge") then
        token = "undead";
    end

    for id,data in pairs(addonRaceIDs) do
        if(data and Helpers:ToSafeLower(data.token) == token) then
            if(not factionIndex or (id % 2 == factionIndex)) then
                return tonumber(id);
            else
                --Debug:Log("Internal:GetAddonRaceIDByToken rejected faction for:", token, factionIndex);
            end
        end
    end
    return nil;
end

function Internal:GetRace(race_id)
    local info = race_id and addonRaceIDs[race_id];
    if(not info) then
        return nil;
    end

    return info.name;
end

function Internal:GetRaceFactionIndex(race_id)
    race_id = tonumber(race_id);
    return race_id and race_id % 2 or nil;
end

function Internal:GetRaceFaction(race_id)
    race_id = tonumber(race_id);
    if(not race_id) then
        return nil;
    end

    return (race_id % 2 == 1) and "Alliance" or "Horde";
end

function Internal:GetRaceFactionColor(race_id)
    race_id = tonumber(race_id);
    if(not race_id) then
        return "ffffffff";
    end

    return (race_id % 2 == 1) and "FF009DEC" or "ffE00A05";
end

-------------------------------------------------------------------------
-- Class indexes

Internal.addonClassIDs = {
    [0]   = { token = "DRUID",        name = "Druid" },
    [10]  = { token = "PALADIN",      name = "Paladin" },
    [20]  = { token = "SHAMAN",       name = "Shaman" },
    [30]  = { token = "DEATHKNIGHT",  name = "Death Knight" },
    [40]  = { token = "HUNTER",       name = "Hunter" },
    [50]  = { token = "MAGE",         name = "Mage" },
    [60]  = { token = "ROGUE",        name = "Rogue" },
    [70]  = { token = "WARLOCK",      name = "Warlock" },
    [80]  = { token = "WARRIOR",      name = "Warrior" },
    [90]  = { token = "PRIEST",       name = "Priest" },
    [100] = { token = "MONK",         name = "Monk" },
    [110] = { token = "DEMONHUNTER",  name = "Demon Hunter" },
    [120] = { token = "EVOKER",       name = "Evoker" },
};

Internal.classLookupTable = {};

local function fillClassLookupTable()
    local keys = { "token", "name" };

    for class_id, data in pairs(Internal.addonClassIDs) do
        for i,key in ipairs(keys) do
            local value = Helpers:ToSafeLower(data[key]);
            if(Helpers:IsValidValue(value)) then
                Internal.classLookupTable[value] = tonumber(class_id);
            end
        end

        Internal.classLookupTable[class_id] = tonumber(class_id);
    end
end
fillClassLookupTable();

function Internal:LookupClassID(class)
    class = tonumber(class) or Helpers:ToSafeLower(class);
    return class and tonumber(Internal.classLookupTable[class]);
end

function Internal:GetAddonClassID(class)
    if(class == nil) then
        return nil;
    end

    class = Helpers:ToSafeLower(class);

    for class_id,data in pairs(Internal.addonClassIDs) do
        if(class == Helpers:ToSafeLower(data.token) or class == Helpers:ToSafeLower(data.name)) then
            return tonumber(class_id);
        end
    end

    return nil;
end

function Internal:GetClassInfo(class_id)
    if(not class_id) then
        return nil;
    end

    return Internal.addonClassIDs[class_id];
end

function Internal:GetClassColor(spec_id)
    local class_id = Helpers:GetClassID(spec_id);
    local classInfo = Internal:GetClassInfo(class_id);
    local classToken = classInfo and classInfo.token;
    return classToken and select(4, GetClassColor(classToken)) or "ffffffff";
end

function Internal:GetClassIcon(spec_id)
    local class_id = Helpers:GetClassID(spec_id);
    if(not class_id) then
        return nil;
    end

    -- Death Knight
    if(class_id == 30) then
        return "Interface\\Icons\\spell_deathknight_classicon";
    end

    local classInfo = Internal.addonClassIDs[class_id];
    local classToken = classInfo and classInfo.token;
    return classToken and "Interface\\Icons\\classicon_" .. classToken:lower() or nil;
end

-------------------------------------------------------------------------
-- Specialization IDs

local addonSpecializationIDs = {};
Internal.specLookupTable = {};

local function fillSpecLookupTable()
    local function InsertAmbiguousSpec(ambiguousTable, spec_id)
        if(Helpers:IsSpecID(spec_id)) then
            local class = Helpers:GetClassID(spec_id);
            if(class) then
                ambiguousTable[class] = tonumber(spec_id);
            end
        end
    end


    for spec_id, data in pairs(addonSpecializationIDs) do
        local value = Helpers:ToSafeLower(data["spec"]);
        if(Helpers:IsValidValue(value) and Helpers:IsSpecID(spec_id)) then
            local existingSpec = Internal.specLookupTable[value];

            if(existingSpec ~= nil) then
                local ambiguousTable = type(existingSpec) == "table" and existingSpec or {};
                InsertAmbiguousSpec(ambiguousTable, existingSpec);
                InsertAmbiguousSpec(ambiguousTable, spec_id);

                Internal.specLookupTable[value] = ambiguousTable;
            else
                Internal.specLookupTable[value] = tonumber(spec_id);
            end
        end
    end
end

function InitializeSpecIDs()
    assert(Bitmap.roles);
    local roles = Bitmap.roles;

    addonSpecializationIDs = {
        -- Druid
        [0] = { },
        [1] = { spec = "Restoration", role = roles.healer },
        [2] = { spec = "Feral", role = roles.melee_damager },
        [3] = { spec = "Balance", role = roles.caster_damager },
        [4] = { spec = "Guardian", role = roles.melee_tank },

        -- Paladin
        [10] = { role = roles.melee },
        [11] = { spec = "Holy", role = roles.melee_healer},
        [12] = { spec = "Protection", role = roles.melee_tank },
        [13] = { spec = "Preg", role = roles.melee_damager },
        [14] = { spec = "Retribution", role = roles.melee_damager },

        -- Shaman
        [20] = { },
        [21] = { spec = "Restoration", role = roles.caster_healer },
        [22] = { spec = "Elemental", role = roles.caster_damager },
        [23] = { spec = "Enhancement", role = roles.melee_damager },

        -- Death Knight
        [30] = { role = roles.melee },
        [31] = { spec = "Unholy", role = roles.melee_damager },
        [32] = { spec = "Frost", role = roles.melee_damager },
        [33] = { spec = "Blood", role = roles.melee_tank },

        -- Hunter
        [40] = { },
        [41] = { spec = "Beast Mastery", role = roles.ranged_damager },
        [42] = { spec = "Marksmanship", role = roles.ranged_damager },
        [43] = { spec = "Survival", role = roles.ranged_damager },

        -- Mage
        [50] = { role = roles.caster_damager },
        [51] = { spec = "Frost", role = roles.caster_damager },
        [52] = { spec = "Fire", role = roles.caster_damager },
        [53] = { spec = "Arcane", role = roles.caster_damager },

        -- Rogue
        [60] = { role = roles.melee_damager },
        [61] = { spec = "Subtlety", role = roles.melee_damager },
        [62] = { spec = "Assassination", role = roles.melee_damager },
        [63] = { spec = "Combat", role = roles.melee_damager },
        [64] = { spec = "Outlaw", role = roles.melee_damager },

        -- Warlock
        [70] = { role = roles.caster_damager },
        [71] = { spec = "Affliction", role = roles.caster_damager },
        [72] = { spec = "Destruction", role = roles.caster_damager },
        [73] = { spec = "Demonology", role = roles.caster_damager },

        -- Warrior
        [80] = { role = roles.melee },
        [81] = { spec = "Protection", role = roles.melee_tank },
        [82] = { spec = "Arms", role = roles.melee_damager },
        [83] = { spec = "Fury", role = roles.melee_damager },

        -- Priest
        [90] = { role = roles.caster },
        [91] = { spec = "Discipline", role = roles.caster_healer },
        [92] = { spec = "Holy", role = roles.caster_healer },
        [93] = { spec = "Shadow", role = roles.caster_damager },

        -- Monk
        [100] = { role = roles.melee },
        [101] = { spec = "Mistweaver", role = roles.melee_healer },
        [102] = { spec = "Brewmaster", role = roles.melee_tank },
        [103] = { spec = "Windwalker", role = roles.melee_damager },

        -- Demon Hunter
        [110] = { role = roles.melee },
        [111] = { spec = "Vengeance", role = roles.melee_tank },
        [112] = { spec = "Havoc", role = roles.melee_damager },
        [113] = { spec = "Devourer", role = roles.melee_damager },

        -- Evoker
        [120] = { role = roles.caster },
        [121] = { spec = "Preservation", role = roles.caster_healer },
        [122] = { spec = "Augmentation", role = roles.caster_damager },
        [123] = { spec = "Devastation", role = roles.caster_damager },
    };

    fillSpecLookupTable();
end


function Internal:LookupSpecID(class, spec, requireSpec)
    if(requireSpec and not Helpers:IsValidValue(spec)) then
        return nil;
    end

    spec = Helpers:ToSafeLower(spec);
    local value = spec and Internal.specLookupTable[spec];

    local class_id = tonumber(class) or Internal:LookupClassID(class);
    if(class_id) then
        if(type(value) == "table") then
            value = class_id and value[class_id];
        end

        if(not value and not requireSpec) then
            return class_id;
        end
    end

    return tonumber(value);
end


-- Get the ID from string class and spec. (For import and version control)
function Internal:GetSpecFromSpecString(class_id, spec, forceExactSpec)
    if(not class_id) then
        return nil;
    end

    if(forceExactSpec and spec == nil) then
        return nil;
    end

    spec = Helpers:SanitizeValue(spec);

    -- Iterate through the table to find the matching class and spec
    if(addonSpecializationIDs) then
        for id,data in pairs(addonSpecializationIDs) do
            if(Helpers:GetClassID(id) == class_id) then
                if(spec == Helpers:SanitizeValue((data.spec))) then
                    return tonumber(id);
                end
            end
        end
    end

    return nil;
end

function Internal:PopulateEnglishSpecs(outSpecTable, classIndex)
    if(not addonSpecializationIDs) then
        return;
    end

    local classToken = API:GetClassToken(classIndex);
    if(not classToken) then
        return;
    end

    classToken = Helpers:ToSafeLower(classToken);

    local class_id = Internal:GetAddonClassID(classToken);
    if(not class_id) then
        return;
    end

    outSpecTable[classToken] = outSpecTable[classToken] or {};

    for id,data in pairs(addonSpecializationIDs) do
        if(Helpers:IsSpecID(id) and Helpers:GetClassID(id) == class_id) then
            local specToken = Helpers:SanitizeValue(data.spec);
            if(specToken) then
                outSpecTable[classToken][specToken] = id;
            end
        end
    end
end

function Internal:GetRoleBitmap(spec_id)
    if(not addonSpecializationIDs) then
        return nil;
    end

    spec_id = tonumber(spec_id);
    if(not spec_id or not addonSpecializationIDs[spec_id]) then
        return nil;
    end

    return tonumber(addonSpecializationIDs[spec_id].role);
end

-------------------------------------------------------------------------

function Internal:GetClassAndSpec(spec_id)
    if(not spec_id or not addonSpecializationIDs) then
        return nil;
    end

    if(Helpers:IsClassID(spec_id)) then
        local classInfo = Internal.addonClassIDs[spec_id];
        return classInfo and classInfo.name;
    end

    -- Class
    local class_id = Helpers:GetClassID(spec_id)
    local classInfo = Internal.addonClassIDs[class_id];
    local class = classInfo and classInfo.name;

    -- Spec
    local specInfo = addonSpecializationIDs[spec_id];
    local spec = specInfo and specInfo.spec;
    return class, spec;
end

-------------------------------------------------------------------------

local hasInitialized = nil;
function Internal:Initialize()
    if(hasInitialized) then
        return;
    end

	Bitmap:Initialize();
    InitializeSpecIDs();

    hasInitialized = true;
end
