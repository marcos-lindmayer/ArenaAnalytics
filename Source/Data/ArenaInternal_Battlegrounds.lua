local _, ArenaAnalytics = ...; -- Addon Namespace
local Internal = ArenaAnalytics.Internal;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;
local Constants = ArenaAnalytics.Constants;
local Bitmap = ArenaAnalytics.Bitmap;
local API = ArenaAnalytics.API;
local TablePool = ArenaAnalytics.TablePool;

-------------------------------------------------------------------------

local battlefieldStats = {
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

function Internal:GetBattlegroundStatID(statToken)
    if(not token) then
        return nil;
    end
    token = Helpers:ToSafeLower(token);

    for key,data in pairs(battlefieldStats) do
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

local battlegroundMapData = {
    [18]  = { token = "WarsongGulch", gameType = "CTF", statMapping = statMappings.ctf },                       -- Flag capture, flag return
    [19]  = { token = "ArathiBasin", gameType = "Domination", statMapping = statMappings.tower },               -- Base capture, base defense
    [20]  = { token = "AlteracValley", gameType = "Boss", statMapping = statMappings.graveyard_tower },         -- Graveyard capture, graveyard defense, tower capture, tower defense
    [21]  = { token = "EyeOfTheStorm", gameType = "CTF", statMapping = statMappings.flag2 },                    -- Secondary flag capture
    [22]  = { token = "StrandOfTheAncients", gameType = "Siege", statMapping = statMappings.demolisher_gate },  -- Demolishers destroyed, gates destroyed
    [23]  = { token = "IsleOfConquest", gameType = "Boss", statMapping = statMappings.tower },                  -- Base capture, base defense
    [24]  = { token = "BattleForGilneas", gameType = "Domination", statMapping = statMappings.tower },          -- Base capture, base defense
    [25]  = { token = "TwinPeaks", gameType = "CTF", statMapping = statMappings.ctf },                          -- Flag capture, flag return
    [26]  = { token = "SilvershardMines", gameType = "Payload", statMapping = statMappings.payload },           -- Carts controlled
    [27]  = { token = "TempleOfKotmogu", gameType = "Orbs", statMapping = statMappings.orbs_points },           -- Orb possessions, victory points
    [28]  = { token = "DeepwindGorge", gameType = "Resource", statMapping = statMappings.ftc_tower },           -- Cart capture, cart return, mine capture, mine defense
    [29]  = { token = "SeethingShore", gameType = "Resource", statMapping = statMappings.points },              -- Azerite collected
    [30]  = { token = "Wintergrasp", gameType = "Epic", statMapping = nil },                                    -- Uncertain stats
    [31]  = { token = "TolBarad", gameType = "Epic", statMapping = nil },                                       -- Uncertain stats
    [32]  = { token = "Ashran", gameType = "Epic", statMapping = statMappings.points },                         -- Artifacts collected
    [33]  = { token = "KorraksRevenge", gameType = "Epic", statMapping = statMappings.graveyard_tower },        -- GY capture, GY defense, tower capture, tower defense
    [34]  = { token = "ArathiBlizzard", gameType = "Domination", statMapping = statMappings.tower },            -- Base capture, base defense
    [35]  = { token = "DeepwindGorge2", gameType = "Domination", statMapping = statMappings.tower },            -- Base capture, base defense
};

function Internal:GetStatMapping(map_id)
    local mapData = map_id and battlegroundMapData[map_id];
    if(not mapData or not mapData.statMapping) then
        return nil;
    end

    local mapping = TablePool:Acquire();
    for _,stat in ipairs(mapData.statMapping) do
        local statID = Internal:GetBattlegroundStatID(stat) or 0;
        tinsert(mapping, statID);
    end

    return mapping;
end