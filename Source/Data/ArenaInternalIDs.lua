local _, ArenaAnalytics = ...; -- Addon Namespace
local Internal = ArenaAnalytics.Internal;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;
local Constants = ArenaAnalytics.Constants;
local Bitmap = ArenaAnalytics.Bitmap;

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
}

function Internal:GetAddonRaceIDByToken(token)
    token = Helpers:ToSafeLower(token);
    if(token == nil) then
        return nil;
    end

    if(token == "Scourge") then
        token = "Undead";
    end

    for id,data in pairs(addonRaceIDs) do
        if(data and Helpers:ToSafeLower(data.token) == token) then
            return id;
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

function Internal:GetRaceFaction(race_id)
    if(not race_id) then
        return nil;
    end

    return (race_id % 2 == 1) and "Alliance" or "Horde";
end

function Internal:GetRaceFactionColor(race_id)
    if(not race_id) then
        return "ffffffff";
    end

    return (race_id % 2 == 1) and "ff3090FF" or "ffD00A06";
end

-------------------------------------------------------------------------
-- Class indexes

local classIndexes = {
    [1]  = { addonID = 80,  token = "WARRIOR",      name = "Warrior" },
    [2]  = { addonID = 10,  token = "PALADIN",      name = "Paladin" },
    [3]  = { addonID = 40,  token = "HUNTER",       name = "Hunter" },
    [4]  = { addonID = 60,  token = "ROGUE",        name = "Rogue" },
    [5]  = { addonID = 90,  token = "PRIEST",       name = "Priest" },
    [6]  = { addonID = 30,  token = "DEATHKNIGHT",  name = "Death Knight" },
    [7]  = { addonID = 20,  token = "SHAMAN",       name = "Shaman" },
    [8]  = { addonID = 50,  token = "MAGE",         name = "Mage" },
    [9]  = { addonID = 70,  token = "WARLOCK",      name = "Warlock" },
    [10] = { addonID = 100, token = "MONK",         name = "Monk" },
    [11] = { addonID = 0,   token = "DRUID",        name = "Druid" },
    [12] = { addonID = 110, token = "DEMONHUNTER",  name = "Demon Hunter" },
    [13] = { addonID = 120, token = "EVOKER",       name = "Evoker" },
}

function Internal:GetAddonClassIDByToken(classToken)
    if(classToken == nil) then
        return nil;
    end

    for _,data in pairs(classIndexes) do
        if(data and data.token == classToken) then
            return data.addonID;
        end
    end
    return nil;
end

function Internal:GetClassInfo(classIndex)
    if(not classIndex) then
        return nil;
    end
    
    return classIndexes[classIndex];
end

function Internal:GetClassColor(classIndex)
    local classToken = classIndex and classIndexes[classIndex] and classIndexes[classIndex].token;
    return classToken and select(4, GetClassColor(classToken)) or "ffffffff";
end

-------------------------------------------------------------------------
-- Specialization IDs

local addonSpecializationIDs = nil;

function InitializeSpecIDs()
    assert(Bitmap.roles);
    local roles = Bitmap.roles;

    addonSpecializationIDs = {
        -- Druid
        [0] = { classIndex = 11 },
        [1] = { classIndex = 11, spec = "Restoration", role = roles.healer },
        [2] = { classIndex = 11, spec = "Feral", role = roles.melee_damager },
        [3] = { classIndex = 11, spec = "Balance", role = roles.caster_damager},

        -- Paladin
        [10] = { classIndex = 2, role = roles.melee },
        [11] = { classIndex = 2, spec = "Holy", role = roles.melee_healer},
        [12] = { classIndex = 2, spec = "Protection", role = roles.melee_tank },
        [13] = { classIndex = 2, spec = "Preg", role = roles.melee_damager },
        [14] = { classIndex = 2, spec = "Retribution", role = roles.melee_damager },

        -- Shaman
        [20] = { classIndex = 7 },
        [21] = { classIndex = 7, spec = "Restoration", role = roles.caster_healer },
        [22] = { classIndex = 7, spec = "Elemental", role = roles.caster_damager },
        [23] = { classIndex = 7, spec = "Enhancement", role = roles.melee_damager },

        -- Death Knight
        [30] = { classIndex = 6, role = roles.melee },
        [31] = { classIndex = 6, spec = "Unholy", role = roles.melee_damager },
        [32] = { classIndex = 6, spec = "Frost", role = roles.melee_damager },
        [33] = { classIndex = 6, spec = "Blood", role = roles.melee_tank },

        -- Hunter
        [40] = { classIndex = 3 },
        [41] = { classIndex = 3, spec = "Beast Mastery", role = roles.ranged_damager },
        [42] = { classIndex = 3, spec = "Marksmanship", role = roles.ranged_damager },
        [43] = { classIndex = 3, spec = "Survival", role = roles.ranged_damager },

        -- Mage
        [50] = { classIndex = 8, role = roles.caster_damager },
        [51] = { classIndex = 8, spec = "Frost", role = roles.caster_damager },
        [52] = { classIndex = 8, spec = "Fire", role = roles.caster_damager },
        [53] = { classIndex = 8, spec = "Arcane", role = roles.caster_damager },

        -- Rogue
        [60] = { classIndex = 4, role = roles.melee_damager },
        [61] = { classIndex = 4, spec = "Subtlety", role = roles.melee_damager },
        [62] = { classIndex = 4, spec = "Assassination", role = roles.melee_damager },
        [63] = { classIndex = 4, spec = "Combat", role = roles.melee_damager },
        [64] = { classIndex = 4, spec = "Outlaw", role = roles.melee_damager },

        -- Warlock
        [70] = { classIndex = 9, role = roles.caster_damager },
        [71] = { classIndex = 9, spec = "Affliction", role = roles.caster_damager },
        [72] = { classIndex = 9, spec = "Destruction", role = roles.caster_damager },
        [73] = { classIndex = 9, spec = "Demonology", role = roles.caster_damager },

        -- Warrior
        [80] = { classIndex = 1, role = roles.melee },
        [81] = { classIndex = 1, spec = "Protection", role = roles.melee_tank },
        [82] = { classIndex = 1, spec = "Arms", role = roles.melee_damager },
        [83] = { classIndex = 1, spec = "Fury", role = roles.melee_damager },

        -- Priest
        [90] = { classIndex = 5, role = roles.caster },
        [91] = { classIndex = 5, spec = "Discipline", role = roles.caster_healer },
        [92] = { classIndex = 5, spec = "Holy", role = roles.caster_healer },
        [93] = { classIndex = 5, spec = "Shadow", role = roles.caster_damager },

        -- Monk
        [100] = { classIndex = 10, role = roles.melee },
        [101] = { classIndex = 10, spec = "Mistweaver", role = roles.melee_healer },
        [102] = { classIndex = 10, spec = "Brewmaster", role = roles.melee_tank },
        [103] = { classIndex = 10, spec = "Windwalker", role = roles.melee_damager },

        -- Demon Hunter
        [110] = { classIndex = 12, role = roles.melee },
        [111] = { classIndex = 12, spec = "Vengeance", role = roles.melee_tank },
        [112] = { classIndex = 12, spec = "Havoc", role = roles.melee_damager },

        -- Evoker
        [120] = { classIndex = 13, role = roles.caster },
        [121] = { classIndex = 13, spec = "Preservation", role = roles.caster_healer },
        [122] = { classIndex = 13, spec = "Augmentation", role = roles.caster_damager },
        [123] = { classIndex = 13, spec = "Devastation", role = roles.caster_damager },
    }
end

function Internal:GetClassIcon(spec_id)
    spec_id = tonumber(spec_id);

    local info = spec_id and addonSpecializationIDs[spec_id];
    if(not info or not info.classIndex) then
        return "";
    end

    -- Death Knight
    if(info.classIndex == 6) then
        return "Interface\\Icons\\spell_deathknight_classicon";
    end

    local classInfo = classIndexes[info.classIndex];
    local classToken = classInfo and classInfo.token;
    return classToken and "Interface\\Icons\\classicon_" .. classToken:lower() or "";
end

function Internal:GetSpecInfo(spec_id)
    spec_id = tonumber(spec_id);

    local info = spec_id and addonSpecializationIDs[spec_id];
    if(not info) then
        return nil;
    end

    -- Get expansion spec ID from API mapping table
    local class,spec,icon = API:GetMappedSpecID(spec_id);
    spec = spec or info.spec or "";

    if(not class) then
        local classInfo = Internal:GetClassInfo(info.classIndex);
        class = classInfo and classInfo.name or "";
    end

    return class, spec, info.role, icon;
end

function Internal:GetClassIndex(spec_id)
    if(not spec_id) then
        return nil;
    end

    local info = spec_id and addonSpecializationIDs[spec_id];
    if(not info) then
        return nil;
    end

    return info.classIndex;
end

-- Get the ID from string class and spec. Should only be used by version control.
function Internal:GetSpecFromSpecString(classID, spec, forceExactSpec)
    local info = classID and addonSpecializationIDs[classID] or nil;
    local classIndex = info and info.classIndex or nil;

    if(not classIndex) then 
        return nil;
    end

    if forceExactSpec and spec == nil then
        return nil;
    end

    -- Iterate through the table to find the matching class and spec
    for id, data in pairs(addonSpecializationIDs) do
        if(data.classIndex == classIndex) then
            if((not forceExactSpec and spec == nil) or (data.spec == spec)) then
                return id;
            end
        end
    end

    return nil;
end

function Internal:GetRoleBitmap(spec_id)
    if(not spec_id or not addonSpecializationIDs[spec_id]) then
        return nil;
    end

    return addonSpecializationIDs[spec_id].role;
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
