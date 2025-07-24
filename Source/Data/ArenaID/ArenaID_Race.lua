local _, ArenaAnalytics = ... -- Namespace
local ArenaID = ArenaAnalytics.ArenaID;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;
local API = ArenaAnalytics.API;
local Colors = ArenaAnalytics.Colors;

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
};

function ArenaID:GetAddonRaceIDByToken(token, factionIndex)
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
                --Debug:Log("ArenaID:GetAddonRaceIDByToken rejected faction for:", token, factionIndex);
            end
        end
    end
    return nil;
end

function ArenaID:GetRace(race_id)
    local info = race_id and addonRaceIDs[race_id];
    if(not info) then
        return nil;
    end

    return info.name;
end

function ArenaID:GetRaceFaction(race_id)
    race_id = tonumber(race_id);
    if(not race_id) then
        return nil;
    end

    return (race_id % 2 == 1) and "Alliance" or "Horde";
end

function ArenaID:GetRaceFactionColor(race_id)
    race_id = tonumber(race_id);
    if(not race_id) then
        return Colors.white;
    end

    return (race_id % 2 == 1) and Colors.allianceColor or Colors.hordeColor;
end
