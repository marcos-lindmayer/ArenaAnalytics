-- API adjusted functions to let calling code stay version agnostic.
local _, ArenaAnalytics = ...; -- Addon Namespace
local API = ArenaAnalytics.API;

-- Local module aliases
local Internal = ArenaAnalytics.Internal;
local Constants = ArenaAnalytics.Constants;

-------------------------------------------------------------------------

-- Initialize the general and expansion specific addon API
function API:Initialize()

end

function API:GetAddonVersion()
    if(GetAddOnMetadata) then
        return GetAddOnMetadata("ArenaAnalytics", "Version") or "-";
    end
    return C_AddOns and C_AddOns.GetAddOnMetadata("ArenaAnalytics", "Version") or "-";
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

function API:IsSoloShuffle()
    return C_PvP and C_PvP.IsSoloShuffle and C_PvP.IsSoloShuffle();
end

function API:GetRoleBitmap(spec_id)
    spec_id = tonumber(spec_id);
    if(not spec_id) then
        return;
    end

    -- Check for override
    local bitmapOverride = API.roleBitmapOverrides and API.roleBitmapOverrides[spec_id];

    return bitmapOverride or Internal:GetRoleBitmap(spec_id);
end

function API:GetMappedAddonSpecID(specID)
    if(not API.specMappingTable) then
        ArenaAnalytics:Log("GetMappedAddonSpecID: Failed to find specMappingTable. Ignoring spec:", specID);
        return nil;
    end

    specID = tonumber(specID);

    local spec_id = specID and API.specMappingTable[specID];
    if(not spec_id) then
        ArenaAnalytics:Log("Failed to find spec_id for:", specID, type(specID));
        return nil;
    end

    return spec_id;
end

function API:GetSpecIcon(spec_id)
    spec_id = tonumber(spec_id);
    if(not spec_id) then
        return;
    end

    -- Check for override
    local bitmapOverride = API.specIconOverrides and API.specIconOverrides[spec_id];

    return bitmapOverride or Constants:GetBaseSpecIcon(spec_id);
end

-------------------------------------------------------------------------
-- Initialize the general and expansion specific addon API
function API:Initialize()
    if(API.InitializeExpansion) then
        API:InitializeExpansion();
    end
end
