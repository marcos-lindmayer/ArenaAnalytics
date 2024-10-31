-- API adjusted functions to let calling code stay version agnostic.
local _, ArenaAnalytics = ...; -- Addon Namespace
local API = ArenaAnalytics.API;

-- Local module aliases
local Internal = ArenaAnalytics.Internal;
local Constants = ArenaAnalytics.Constants;
local Options = ArenaAnalytics.Options;

-------------------------------------------------------------------------

API.numClasses = 13; -- Number of class indices to check for class info

-------------------------------------------------------------------------
-- Arena

function API:IsInArena()
    return IsActiveBattlefieldArena() and not C_PvP.IsInBrawl();
end

function API:IsRatedArena()
    if(not API:IsInArena()) then
        return false;
    end

    -- Unrated modes
    if(IsWargame() or IsArenaSkirmish() or C_PvP.IsInBrawl()) then
        return false;
    end

    -- Any rated arena type
    return C_PvP.IsRatedArena() or (C_PvP.IsRatedSoloShuffle and C_PvP.IsRatedSoloShuffle()) or false;
end

-------------------------------------------------------------------------
-- Battleground

function API:IsInBattleground()
    local _, instanceType = IsInInstance();
    return C_PvP.IsInBrawl() or instanceType == "pvp";
end

function API:IsInRatedBattleground()
    if(not API:IsInBattleground() or IsWargame() or C_PvP.IsInBrawl()) then
        return false;
    end

    -- Old interface
    if(IsRatedBattleground) then
        return IsRatedBattleground();
    end

    -- New interface
    return C_PvP and C_PvP.IsRatedBattleground and C_PvP.IsRatedBattleground();
end

-------------------------------------------------------------------------

function API:IsRated()
    return C_PvP.IsRatedMap();
end

function API:HasSurrenderAPI()
    return CanSurrenderArena and SurrenderArena;
end

function API:TrySurrenderArena(source)
    if(not API:HasSurrenderAPI()) then
        return nil;
    end

    if(not IsActiveBattlefieldArena()) then
        return nil;
    end

    if(source == "afk" and not Options:Get("enableSurrenderAfkOverride")) then
        return nil;
    elseif(source == "gg" and not Options:Get("enableSurrenderGoodGameCommand")) then
        return nil;
    end

    if(CanSurrenderArena()) then
        ArenaAnalytics:PrintSystem("You have surrendered!");
        ArenaAnalytics.lastSurrenderAttempt = nil;
        SurrenderArena();
        return true;
    elseif(Options:Get("enableDoubleAfkToLeave") and source == "afk") then
        if(not ArenaAnalytics.lastSurrenderAttempt or (ArenaAnalytics.lastSurrenderAttempt + 5 < time())) then
            ArenaAnalytics:PrintSystem("Type /afk again to leave.");
            ArenaAnalytics.lastSurrenderAttempt = time();
        else
            ArenaAnalytics:PrintSystem("Double /afk triggered.");
            ArenaAnalytics.lastSurrenderAttempt = nil;
            LeaveBattlefield();
        end
    else
        ArenaAnalytics:PrintSystem("You cannot surrender yet!");
        return false;
    end
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

function API:GetTeamMMR(teamIndex)
    local mmr = select(4, GetBattlefieldTeamInfo(teamIndex));
    return tonumber(mmr);
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