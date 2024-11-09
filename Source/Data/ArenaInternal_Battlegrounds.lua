local _, ArenaAnalytics = ...; -- Addon Namespace
local Internal = ArenaAnalytics.Internal;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;
local Constants = ArenaAnalytics.Constants;
local Bitmap = ArenaAnalytics.Bitmap;
local API = ArenaAnalytics.API;

-------------------------------------------------------------------------

local battlegroundMapTokens = {
    -- Capture the Flag
    [489]  = "WarsongGulch",        -- Warsong Gulch (Classic)
    [2106] = "WarsongGulch",        -- Warsong Gulch (Updated)
    [726]  = "TwinPeaks",           -- Twin Peaks

    -- Domination (5-cap maps, similar scoring objectives)
    [529]  = "ArathiBasin",         -- Arathi Basin (Classic)
    [2107] = "ArathiBasin",         -- Arathi Basin (Updated)
    [1681] = "ArathiBlizzard",      -- Arathi Blizzard
    [2245] = "DeepwindGorge2",      -- Deepwind Gorge (Updated, 5-cap)

    -- Resource Race (collect and hold objectives for score accumulation)
    [566]  = "EyeOfTheStorm",       -- Eye of the Storm
    [968]  = "EyeOfTheStorm",       -- Eye of the Storm (Rated)

    -- Epic Battlegrounds (large-scale PvP with unique objectives)
    [1191] = "Ashran",              -- Ashran
    [2118] = "Wintergrasp",         -- Wintergrasp (Epic Battleground)
    [30]   = "AlteracValley",       -- Alterac Valley
    [628]  = "IsleOfConquest",      -- Isle of Conquest
    [2197] = "KorraksRevenge",      -- Korrak's Revenge (Alterac Valley Classic)

    -- Misc
    [607]  = "StrandOfTheAncients", -- Strand of the Ancients
    [761]  = "BattleForGilneas",    -- Battle for Gilneas
    [727]  = "SilvershardMines",    -- Silvershard Mines
    [998]  = "TempleOfKotmogu",     -- Temple of Kotmogu
    [1105]  = "DeepwindGorge",      -- Deepwind Gorge (Classic)
    [1803] = "SeethingShore",       -- Seething Shore
    [2656] = "DeephaulRavine",    -- Deephaul Ravine

    -- Blitz
    [0] = "EyeOfTheStormBlitz",     -- Eye of the Storm (Blitz)
};

function Internal:GetBattlegroundMapToken(mapID)
    mapID = tonumber(mapID);
    if(not mapID or mapID == 0) then
        return nil;
    end

    local token = battlegroundMapTokens[mapID];
    if(not token) then
        ArenaAnalytics:LogWarning("Failed to retrieve token for mapID:", mapID);
        return nil;
    end

    return token;
end

local stats = {
    { token = "FlagCapture", icon = "Interface\\WorldStateFrame\\ColumnIcon-FlagCapture" },
    { token = "FlagReturn", icon = "Interface\\WorldStateFrame\\ColumnIcon-FlagReturn" },
    { token = "FlagCapture2", icon = "Interface\\WorldStateFrame\\ColumnIcon-FlagCapture2" },
    { token = "TowerCapture", icon = "Interface\\WorldStateFrame\\ColumnIcon-TowerCapture" },
    { token = "TowerDefend", icon = "Interface\\WorldStateFrame\\ColumnIcon-TowerDefend" },
    { token = "GraveyardCapture", icon = "Interface\\WorldStateFrame\\ColumnIcon-GraveyardCapture" },
    { token = "GraveyardDefend", icon = "Interface\\WorldStateFrame\\ColumnIcon-GraveyardDefend" },
    { token = "CartsControlled", icon = "Interface\\MINIMAP\\Vehicle-SilvershardMines-MineCart" },
    { token = "DemolishersDestroyed", icon = "Interface\\MINIMAP\\Vehicle-HordeCart" },
    { token = "Points", icon = "Interface\\MONEYFRAME\\UI-GoldIcon" },
    { token = "OrbPossessions", icon = "Interface\\MINIMAP\\TempleofKotmogu_ball_purple" },
    { token = "CrystalCaptures", icon = "Interface\\WorldStateFrame\\ColumnIcon-FlagCapture2" },
};

function Internal:GetBattlegroundStatID(token)
    if(tonumber(token)) then
        token = Internal:GetBattlegroundMapToken(token);
    end

    if(not token) then
        return nil;
    end

    token = Helpers:ToSafeLower(token);

    for key,data in pairs(stats) do
        if(data and token == Helpers:ToSafeLower(data.token)) then
            return key;
        end
    end
end

local statMappings = {
    ctf = { "FlagCapture", "FlagReturn" },
    flag2 = { "FlagCapture2" },
    tower = { "TowerCapture", "TowerDefend" },
    ctf_towers = { "FlagCapture", "FlagReturn", "TowerCapture", "TowerDefend" },
    tower_flag2 = { "TowerCapture", "TowerDefend", "FlagCapture2" },
    ctf_tower = { "FlagCapture", "FlagReturn", "TowerCapture", "TowerDefend" },
    graveyard_tower = { "GraveyardCapture", "GraveyardDefend", "TowerCapture", "TowerDefend" },
    payload = { "CartsControlled" },
    orbs_points = { "OrbPossessions", "Points" },
    crystal_payload = { "CrystalCaptures", "CartsControlled" },
    demolisher_gate = { "DemolishersDestroyed", "GatesDestroyed" },
    points = { "Points" }
};

function Internal:GetBattlegroundStatMappings()
    return statMappings;
end

local battlegroundAddonMapIDs = {
    [1]  = { token = "WarsongGulch", shortName = "WG", name = "Warsong Gulch", statMapping = statMappings.ctf }, -- Flag cap, flag return
    [2]  = { token = "ArathiBasin", shortName = "AB", name = "Arathi Basin", statMapping = statMappings.tower }, -- Base cap, base def
    [3]  = { token = "AlteracValley", shortName = "AV", name = "Alterac Valley", statMapping = statMappings.graveyard_tower }, -- gy cap, gy def, tower cap, tower def
    [4]  = { token = "EyeOfTheStorm", shortName = "EotS", name = "Eye of the Storm", statMapping = statMappings.flag2 }, -- Flag2
    [5]  = { token = "StrandOfTheAncients", shortName = "SotA", name = "Strand of the Ancients", statMapping = statMappings.demolisher_gate }, -- Demo destroyed, gates destroyed
    [6]  = { token = "IsleOfConquest", shortName = "IoC", name = "Isle of Conquest", statMapping = statMappings.tower }, -- Base cap, base def
    [7]  = { token = "BattleForGilneas", shortName = "BfG", name = "Battle for Gilneas", statMapping = statMappings.tower }, -- Base cap, base def
    [8]  = { token = "TwinPeaks", shortName = "TP", name = "Twin Peaks", statMapping = statMappings.ctf }, -- Flag cap, flag return
    [9]  = { token = "SilvershardMines", shortName = "SSM", name = "Silvershard Mines", statMapping = statMappings.payload }, -- Carts controlled
    [10] = { token = "TempleOfKotmogu", shortName = "ToK", name = "Temple of Kotmogu", statMapping = statMappings.orbs_points }, -- Orb possessions, Victory Points
    [11] = { token = "DeepwindGorge", shortName = "DWG", name = "Deepwind Gorge", statMapping = statMappings.ftc_tower }, -- Carts cap, carts returned, mines capped, mines def
    [12] = { token = "SeethingShore", shortName = "SS", name = "Seething Shore", statMapping = statMappings.points }, -- Azerite Collected
    [13] = { token = "Wintergrasp", shortName = "WG", name = "Wintergrasp", statMapping = nil }, -- ??
    [14] = { token = "TolBarad", shortName = "TB", name = "Tol Barad", statMapping = nil }, -- ??
    [15] = { token = "Ashran", shortName = "Ash", name = "Ashran", statMapping = statMappings.points }, -- Artifacts collected
    [16] = { token = "KorraksRevenge", shortName = "KR", name = "Korrak's Revenge", statMapping = statMappings.graveyard_tower }, -- GY cap, GY def, Tower Cap, Tower Def,     Secondary Objectives
    [17] = { token = "ArathiBlizzard", shortName = "ABW", name = "Arathi Basin Blizzard", statMapping = statMappings.tower }, -- Base cap, base def
    [18] = { token = "DeepwindGorge2", shortName = "DWG", name = "Deepwind Gorge", statMapping = statMappings.tower }, -- Base cap, base def
};

function Internal:GetBattlegroundAddonMapID(map)
    if(not map) then
        return nil;
    end

    if(tonumber(map)) then
        map = Internal:GetBattlegroundMapToken(map);
    end

    map = Helpers:ToSafeLower(map);

    for map_id, data in pairs(battlegroundAddonMapIDs) do
        assert(data and data.token);

        if(map == Helpers:ToSafeLower(data.token)) then
            return map_id;
        elseif(map == Helpers:ToSafeLower(data.shortName)) then
            return map_id;
        elseif(map == Helpers:ToSafeLower(data.name)) then
            return map_id;
        end
    end

    return nil;
end

function Internal:GetBattlegroundShortMapName(map_id)
    local mapInfo = map_id and battlegroundAddonMapIDs[map_id];
    return mapInfo and mapInfo.shortName;
end

function Internal:GetBattlegroundMapName(map_id)
    local mapInfo = map_id and battlegroundAddonMapIDs[map_id];
    return mapInfo and mapInfo.name;
end

function Internal:GetStatMapping(map_id)
    local mapData = map_id and battlegroundAddonMapIDs[map_id];
    return mapData and mapData.statMapping;
end