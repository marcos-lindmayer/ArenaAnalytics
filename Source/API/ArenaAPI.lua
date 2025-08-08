-- API adjusted functions to let calling code stay version agnostic.
local _, ArenaAnalytics = ...; -- Addon Namespace
local API = ArenaAnalytics.API;

-- Local module aliases
local Internal = ArenaAnalytics.Internal;
local Constants = ArenaAnalytics.Constants;
local Options = ArenaAnalytics.Options;
local Helpers = ArenaAnalytics.Helpers;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------

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


function API:GetUnitFullName(unitToken, skipRealm)
    if(not unitToken) then
        Debug:LogWarning("API:GetUnitFullName called with invalid unitToken:", unitToken);
        return nil;
    end

    local name = UnitNameUnmodified(unitToken);

    if(not Helpers:IsValidValue(name)) then
        return nil;
    end

    if(skipRealm) then
        return name;
    end

    -- Get the realm
    local realm = select(2, UnitFullName(unitToken));
    if(not Helpers:IsValidValue(realm)) then
        realm = select(2, UnitFullName("player")); -- Local player's realm
    end

    if(not Helpers:IsValidValue(realm)) then
        Debug:LogWarning("Helpers:GetUnitFullName failed to retrieve any realm for unit:", unitToken);
        return name;
    end

    return format("%s-%s", name, realm);
end


function API:GetPlayerName(skipRealm)
    return API:GetUnitFullName("player", skipRealm);
end


function API:ToFullName(name)
    if(not name) then
        return nil;
    end

    if(not name:find("-", 1, true)) then
        local _,realm = UnitFullName("player"); -- Local player's realm
        name = realm and (name.."-"..realm) or name;
    end

    return name;
end


function API:GetUnitGender(unitToken)
    local genderIndex = UnitSex(unitToken);
    return tonumber(genderIndex);
end


function API:GetPlayerInfoByGUID(GUID)
    local _,class,_,race,genderIndex,name,realm = GetPlayerInfoByGUID(GUID);

    name = Helpers:ToValidValue(name);
    realm = Helpers:ToValidValue(realm);
    local isFemale = Helpers:IsFemaleIndex(genderIndex);

    return name, realm, class, race, isFemale;
end


function API:CanInspect(unitToken)
    -- TODO: Validate that this is allowed in all versions (To avoid inspect error message)
    if(not InCombatLockdown() and not CheckInteractDistance(unitToken, 1)) then
        Debug:Log("Inspection skipped due to out of combat interact distance.");
        return;
    end

    return unitToken ~= nil; --and CanInspect(unitToken);
end


function API:GetActiveBattlefieldID()
    for index = 1, GetMaxBattlefieldID() do
        local status = API:GetBattlefieldStatus(index);
        if status == "active" then
            return index;
        end
    end
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


function API:GetCurrentSeason()
    return GetCurrentArenaSeason();
end


function API:GetSeasonPlayed(bracketIndex)
    local _, seasonPlayed = API:GetPersonalRatedInfo(bracketIndex);
    return seasonPlayed;
end


function API:GetTeamIndex(isEnemy)
    if(not API:IsInArena()) then
        return nil;
    end

    -- Invalid in shuffles, uncomfirmed otherwise
    local teamIndex = GetBattlefieldArenaFaction();
    Debug:Log("GetTeamIndex my team:", teamIndex);
    if(not teamIndex) then
        return nil;
    end

    if(isEnemy) then
        -- Inverse team index for enemy team
        teamIndex = (teamIndex == 0) and 1 or 0;
    end

    Debug:Log("Received team:", teamIndex, isEnemy);
    return tonumber(teamIndex);
end

function API:GetTeamMMR(team)
    if(not API:IsInArena()) then
        return nil;
    end

    -- Must be a teamIndex by now
    team = tonumber(team);
    if(not team) then
        return nil;
    end

    -- Get current MMR for the given team
    local mmr = select(4, GetBattlefieldTeamInfo(team));
    mmr = tonumber(mmr);

    -- Discard invalid MMR value
    if(mmr <= 0) then
        return nil;
    end

    return mmr;
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
    Debug:Log("Map:", mapID)
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

function API:Round(number, decimals)
    number = tonumber(number) or 0;

    if(not Debug:Assert(type(Round) == "function", "WoW API Round missing.")) then
        return number;
    end

    return Round(number, decimals);
end

-- Rounds the winrate, flooring 99-100.
function API:RoundPercentage(winrate)
    winrate = tonumber(winrate) or 0;

    if(winrate > 99 and winrate < 99.97) then
        return math.floor(winrate);
    end

    return API:Round(winrate);
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
-- Specializations

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
-- Aura checks (Dampening & Preparation)

function API:FindAuraByID(auraIDs)
    if(type(auraIDs) == "number") then
        return C_UnitAuras.GetPlayerAuraBySpellID(auraIDs);
    end

    if(type(auraIDs) == "table") then
        for _,ID in ipairs(auraIDs) do
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(ID);
            if(aura ~= nil) then
                return aura;
            end
        end
    end

    return nil;
end

function API:GetCurrentDampening()
    if(not API.hasDampening) then
        return nil;
    end

    if(not API:IsInArena()) then
        return nil;
    end

    local aura = API:FindAuraByID(API.explicitDampeningID or { 110310, 397766 });
    if(aura ~= nil) then
        local stacks = aura.applications or 0;
        return stacks, aura.name, aura.spellId;
    end

    return nil;
end

function API:IsArenaPreparation()
    if(not API:IsInArena()) then
        return nil;
    end

    local aura = API:FindAuraByID(API.explicitPreparationID or { 32727, 44521 }); -- 32727 confirmed for MoP
    if(aura ~= nil) then
        return true, aura.name, aura.spellId;
    end

    return false;
end


-------------------------------------------------------------------------
-- Initialize the general and expansion specific addon API

function API:Initialize()
    if(API.InitializeExpansion) then
        API:InitializeExpansion();
    end
end