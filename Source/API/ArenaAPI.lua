-- API adjusted functions to let calling code stay version agnostic.
local _, ArenaAnalytics = ...; -- Addon Namespace
local API = ArenaAnalytics.API;

-- Local module aliases
local Internal = ArenaAnalytics.Internal;
local Constants = ArenaAnalytics.Constants;
local Options = ArenaAnalytics.Options;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------

-- TODO: DEtermine desired order, and whether index order matters
API.classTokens = {
    -- Classic/TBC
    "WARRIOR",
    "PALADIN",
    "HUNTER",
    "ROGUE",
    "PRIEST",
    "SHAMAN",
    "MAGE",
    "WARLOCK",
    "DRUID",
    "DEATHKNIGHT",  -- WotLK
    "MONK",         -- MoP
    "DEMONHUNTER",  -- Legion
    "EVOKER",       -- Dragonflight
};

function API:CanInspect(unitToken)
    -- TODO: Validate that this is allowed in all versions (To avoid inspect error message)
    if(not InCombatLockdown() and not CheckInteractDistance(unitToken, 1)) then
        Debug:Log("Inspection skipped due to out of combat interact distance.");
        return;
    end

    return unitToken ~= nil; --and CanInspect(unitToken);
end

function API:GetClassToken(index)
    index = tonumber(index);
    return index and API.classTokens[index];
end

function API:GetNumClasses()
    return #API.classTokens;
end

function API:GetAddonVersion()
    if(GetAddOnMetadata) then
        return GetAddOnMetadata("ArenaAnalytics", "Version") or "-";
    end
    return C_AddOns and C_AddOns.GetAddOnMetadata("ArenaAnalytics", "Version") or "-";
end

function API:GetActiveBattlefieldID()
    for index = 1, GetMaxBattlefieldID() do
        local status = API:GetBattlefieldStatus(index);
        Debug:LogTemp("battlefield status:", index, status);
        if status == "active" then
			Debug:Log("Found battlefield ID ", index);
            return index;
        end
    end
	Debug:Log("Failed to find battlefield ID");
end

-- Unused
function API:GetMaxSpecializationsForClass(classIndex)
    if(C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID) then
        return C_SpecializationInfo.GetNumSpecializationsForClassID(classIndex);
    end

    if(GetNumSpecializationsForClassID) then
        return GetNumSpecializationsForClassID(classIndex);
    end

    return nil;
end

-- TODO: Custom off season logic?
function API:GetCurrentSeason()
    return GetCurrentArenaSeason();
end

function API:GetSeasonPlayed(bracketIndex)
    local _, seasonPlayed = API:GetPersonalRatedInfo(bracketIndex);
    return seasonPlayed;
end

function API:GetWinner()
    if(not API:IsInArena()) then
        return nil;
    end

    local winner = GetBattlefieldWinner();
    if(winner == 255) then
        return 2; -- Draw
    end

    return tonumber(winner);
end

function API:GetCurrentMapID()
    local mapID = select(8,GetInstanceInfo());
    return tonumber(mapID);
end

function API:IsInArena()
    return IsActiveBattlefieldArena() and not C_PvP.IsInBrawl();
end

function API:IsWargame()
    return IsWargame and IsWargame();
end

function API:IsSkirmish()
    return IsArenaSkirmish();
end

function API:IsSoloShuffle()
    return C_PvP and C_PvP.IsSoloShuffle and C_PvP.IsSoloShuffle();
end

function API:DetermineMatchType()
    if(API:IsInArena()) then
        if(API:IsRatedArena()) then
            return "rated";
        end

        if(API:IsWargame()) then
            return "wargame";
        end

        if(API:IsSkirmish()) then
            return "skirmish";
        end
    end

    return "none";
end

function API:DetermineBracket(teamSize)
    if(API:IsSoloShuffle()) then
        return "shuffle";
    elseif(teamSize == 2) then
        return "2v2";
    elseif(teamSize == 3) then
        return "3v3";
    elseif(teamSize == 5) then
        return "5v5";
    end

    return nil;
end

-------------------------------------------------------------------------

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

-------------------------------------------------------------------------

function API:UpdateDialogueVolume()
    local hasPreviousValue = type(ArenaAnalyticsSharedSettingsDB.previousDialogMuteValue) ~= "number"

    if(API:IsInArena() and Options:Get("muteArenaDialogSounds")) then
        if(not hasPreviousValue) then
            local previousValue = tonumber(GetCVar("Sound_DialogVolume"));
            if(previousValue ~= 0) then
                Debug:Log("Muted dialogue sound.");
                SetCVar("Sound_DialogVolume", 0);
                local newValue = tonumber(GetCVar("Sound_DialogVolume"));
                if(tonumber(newValue) == 0) then
                    ArenaAnalyticsSharedSettingsDB.previousDialogMuteValue = previousValue;
                    Debug:LogGreen("previousDialogMuteValue set to previous value:", previousValue);
                end
            end
        end
    elseif(hasPreviousValue) then
        if(tonumber(GetCVar("Sound_DialogVolume")) == 0) then
            SetCVar("Sound_DialogVolume", ArenaAnalyticsSharedSettingsDB.previousDialogMuteValue);
            Debug:Log("Unmuted dialogue sound.");
        end

        ArenaAnalyticsSharedSettingsDB.previousDialogMuteValue = nil;
    end
end

-------------------------------------------------------------------------

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
        Debug:Log("GetMappedAddonSpecID: Failed to find specMappingTable. Ignoring spec:", specID);
        return nil;
    end

    specID = tonumber(specID);

    local spec_id = specID and tonumber(API.specMappingTable[specID]);
    if(not spec_id) then
        Debug:Log("Failed to find spec_id for:", specID, type(specID));
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