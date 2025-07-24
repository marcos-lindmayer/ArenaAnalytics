local _, ArenaAnalytics = ... -- Namespace
local ArenaID = ArenaAnalytics.ArenaID;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;
local Debug = ArenaAnalytics.Debug;

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

function ArenaID:GetMapToken(mapID)
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

local addonMapIDs = {
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
    [11] =  { token = "KulTirasArena", shortName = "KTA", name = "Kul Tiras Arena" },
    [12] =  { token = "Mugambala", shortName = "M", name = "Mugambala" },
    [13] =  { token = "TheRobodrome", shortName = "TR", name = "The Robodrome" },

    [14] =  { token = "EmpyreanDomain", shortName = "ED", name = "Empyrean Domain" },
    [15] =  { token = "EnigmaCrucible", shortName = "EC", name = "Enigma Crucible" },
    [16] =  { token = "MaldraxxusColiseum", shortName = "MC", name = "Maldraxxus Coliseum" },

    [17] =  { token = "NokhudonProvingGrounds", shortName = "NPG", name = "Nokhudon Proving Grounds" },

    [18] =  { token = "CageOfCarnage", shortName = "CoC", name = "Cage of Carnage" },
};

function ArenaID:GetAddonMapID(map)
    if(tonumber(map)) then
        map = ArenaID:GetMapToken(map);
    end

    if(not map) then
        return nil;
    end

    map = Helpers:ToSafeLower(map);

    for map_id, data in pairs(addonMapIDs) do
        assert(data and data.token);

        if(map == Helpers:ToSafeLower(data.token)) then
            return tonumber(map_id);
        elseif(map == Helpers:ToSafeLower(data.shortName)) then
            return tonumber(map_id);
        elseif(map == Helpers:ToSafeLower(data.name)) then
            return tonumber(map_id);
        end
    end

    return nil;
end

function ArenaID:GetShortMapName(map_id)
    local mapInfo = map_id and addonMapIDs[map_id];
    return mapInfo and mapInfo.shortName;
end

function ArenaID:GetMapName(map_id)
    local mapInfo = map_id and addonMapIDs[map_id];
    return mapInfo and mapInfo.name;
end
