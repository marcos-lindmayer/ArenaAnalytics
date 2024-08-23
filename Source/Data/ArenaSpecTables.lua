local _, ArenaAnalytics = ...; -- Addon Namespace
local SpecTables = ArenaAnalytics.SpecTables;

-- Local module aliases

-------------------------------------------------------------------------

local TANK = 1;
local HEALER = 2;
local DPS = 3;

local MELEE = 8;
local RANGED = 16;
local CASTER = 32;

local MELEE_TANK = MELEE + TANK;
local MELEE_HEALER = MELEE + HEALER;
local MELEE_DPS = MELEE + DPS;

local RANGED_DPS = RANGED + DPS;

local CASTER_HEALER = CASTER + HEALER;
local CASTER_DPS = CASTER + DPS;

-------------------------------------------------------------------------

local addonSpecializationIDs = {
    [0] = { class = "Druid" },
    [1] = { class = "Druid", spec = "Restoration", role = HEALER },
    [2] = { class = "Druid", spec = "Feral", role = MELEE_DPS },
    [3] = { class = "Druid", spec = "Balance", role = CASTER_DPS},

    [10] = { class = "Paladin", role = MELEE },
    [11] = { class = "Paladin", spec = "Holy", role = MELEE_HEALER},
    [12] = { class = "Paladin", spec = "Protection", role = MELEE_TANK },
    [13] = { class = "Paladin", spec = "Preg", role = MELEE_DPS },
    [14] = { class = "Paladin", spec = "Retribution", role = MELEE_DPS },

    [20] = { class = "Shaman" },
    [21] = { class = "Shaman", spec = "Restoration", role = CASTER_HEALER },
    [22] = { class = "Shaman", spec = "Elemental", role = CASTER_DPS },
    [23] = { class = "Shaman", spec = "Enhancement", role = MELEE_DPS },

    [30] = { class = "Death Knight", role = MELEE },
    [31] = { class = "Death Knight", spec = "Unholy", role = MELEE_DPS },
    [32] = { class = "Death Knight", spec = "Frost", role = MELEE_DPS },
    [33] = { class = "Death Knight", spec = "Blood", role = MELEE_TANK },

    [40] = { class = "Hunter" },
    [41] = { class = "Hunter", spec = "Beast Mastery", role = RANGED_DPS },
    [42] = { class = "Hunter", spec = "Marksmanship", role = RANGED_DPS },
    [43] = { class = "Hunter", spec = "Survival", role = MELEE_DPS },

    [50] = { class = "Mage" role = CASTER_DPS },
    [51] = { class = "Mage", spec = "Frost", role = CASTER_DPS },
    [52] = { class = "Mage", spec = "Fire", role = CASTER_DPS },
    [53] = { class = "Mage", spec = "Arcane", role = CASTER_DPS },

    [60] = { class = "Rogue", role = MELEE_DPS },
    [61] = { class = "Rogue", spec = "Subtlety", role = MELEE_DPS },
    [62] = { class = "Rogue", spec = "Assassination", role = MELEE_DPS },
    [63] = { class = "Rogue", spec = "Combat", role = MELEE_DPS },
    [64] = { class = "Rogue", spec = "Outlaw", role = MELEE_DPS },

    [70] = { class = "Warlock", role = CASTER_DPS },
    [71] = { class = "Warlock", spec = "Affliction", role = CASTER_DPS },
    [72] = { class = "Warlock", spec = "Destruction", role = CASTER_DPS },
    [73] = { class = "Warlock", spec = "Demonology", role = CASTER_DPS },

    [80] = { class = "Warrior", role = MELEE },
    [81] = { class = "Warrior", spec = "Protection", role = MELEE_TANK },
    [82] = { class = "Warrior", spec = "Arms", role = MELEE_DPS },
    [83] = { class = "Warrior", spec = "Fury", role = MELEE_DPS },

    [90] = { class = "Priest", role = CASTER },
    [91] = { class = "Priest", spec = "Discipline", role = CASTER_HEALER },
    [92] = { class = "Priest", spec = "Holy", role = CASTER_HEALER },
    [93] = { class = "Priest", spec = "Shadow", role = CASTER_DPS },
    
    [100] = { class = "Monk", role = MELEE },
    [101] = { class = "Monk", spec = "Mistweaver", role = HEALER },
    [102] = { class = "Monk", spec = "Brewmaster", role = MELEE_TANK },
    [103] = { class = "Monk", spec = "Windwalker", role = MELEE_DPS },
    
    [110] = { class = "Demon Hunter", role = MELEE },
    [111] = { class = "Demon Hunter", spec = "Vengeance", role = MELEE_TANK },
    [112] = { class = "Demon Hunter", spec = "Havoc", role = MELEE_DPS },
    
    [120] = { class = "Evoker", role = CASTER },
    [121] = { class = "Evoker", spec = "Preservation", role = CASTER_HEALER },
    [122] = { class = "Evoker", spec = "Augmentation", role = CASTER_DPS },
    [123] = { class = "Evoker", spec = "Devastation", role = CASTER_DPS },
}

function SpecTables:GetSpecInfo(spec_id)
    local info = spec_id and addonSpecializationIDs[spec_id];
    if(not info) then
        return nil;
    end

    -- TODO: Get expansion spec ID from API mapping table
    -- TODO: Get localized class and spec

    return info.class, info.spec, info.role;
end

-- TODO: Add a quick lookup table, if any future code relies on this frequently
function SpecTables:GetID(class, spec, forceExactSpec)
    if class == nil then 
        return nil;
    end

    if forceExactSpec and spec == nil then
        return nil;
    end

    -- Iterate through the table to find the matching class and spec
    for id, data in pairs(addonSpecializationIDs) do
        if data.class == class then
            if (not forceExactSpec and spec == nil) or (data.spec == spec) then
                return id;
            end
        end
    end

    return nil;
end