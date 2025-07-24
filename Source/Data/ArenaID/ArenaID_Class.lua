local _, ArenaAnalytics = ... -- Namespace
local ArenaID = ArenaAnalytics.ArenaID;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;
local API = ArenaAnalytics.API;

-------------------------------------------------------------------------
-- Class indexes

ArenaID.addonClassIDs = {
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

function ArenaID:GetAddonClassID(class)
    if(class == nil) then
        return nil;
    end

    class = Helpers:ToSafeLower(class);

    for class_id,data in pairs(ArenaID.addonClassIDs) do
        if(class == Helpers:ToSafeLower(data.token) or class == Helpers:ToSafeLower(data.name)) then
            return tonumber(class_id);
        end
    end

    return nil;
end

function ArenaID:GetClassInfo(class_id)
    if(not class_id) then
        return nil;
    end

    return ArenaID.addonClassIDs[class_id];
end

function ArenaID:GetClassIcon(spec_id)
    local class_id = Helpers:GetClassID(spec_id);
    if(not class_id) then
        return nil;
    end

    -- Death Knight
    if(class_id == 30) then
        return "Interface\\Icons\\spell_deathknight_classicon";
    end

    local classInfo = ArenaID.addonClassIDs[class_id];
    local classToken = classInfo and classInfo.token;
    return classToken and "Interface\\Icons\\classicon_" .. classToken:lower() or nil;
end
