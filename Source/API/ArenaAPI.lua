-- API adjusted functions to let calling code stay version agnostic.
local _, ArenaAnalytics = ...; -- Addon Namespace
local API = ArenaAnalytics.API;

-- Local module aliases
local Internal = ArenaAnalytics.Internal;

-------------------------------------------------------------------------

function API:GetAddonVersion()
    if(GetAddOnMetadata) then
        return GetAddOnMetadata("ArenaAnalytics", "Version") or "-";
    end
    return C_AddOns and C_AddOns.GetAddOnMetadata("ArenaAnalytics", "Version") or "-";
end

function API:GetMapToken(mapID)
    assert(API.availableMaps);

    mapID = tonumber(mapID);
    if(not mapID) then
        return nil;
    end

    for _,data in ipairs(API.availableMaps) do
        if(data and data.id == mapID) then
            assert(data.token);
            return data.token;
        end
    end
end

function API:GetAddonMapID(map)
    assert(API.availableMaps);

    local token = tonumber(map) and API:GetMapToken(map) or map;
    return Internal:GetAddonMapID(token);
end

function API:GetArenaPlayerSpec(index, isEnemy)
    if(isEnemy) then
        -- Depends on GotArenaOpponentSpec API to function    
        if(GetArenaOpponentSpec) then
            local id = GetArenaOpponentSpec(index);
            return API:GetMappedAddonSpecID(id);
        end
    else
        -- Add friendly support
    end
end
