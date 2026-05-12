-- Namespace for managing versions, including backwards compatibility and converting data
local _, ArenaAnalytics = ...; -- Addon Namespace
local VersionManager = ArenaAnalytics.VersionManager;

-- Local module aliases
local Constants = ArenaAnalytics.Constants;
local Filters = ArenaAnalytics.Filters;
local Import = ArenaAnalytics.Import;
local API = ArenaAnalytics.API;
local Helpers = ArenaAnalytics.Helpers;
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local Internal = ArenaAnalytics.Internal;
local Localization = ArenaAnalytics.Localization;
local Sessions = ArenaAnalytics.Sessions;
local Debug = ArenaAnalytics.Debug;
local Interface = ArenaAnalytics.Interface;

-------------------------------------------------------------------------

VersionManager.disabled = false;

-- True if data sync was detected with a later version.
VersionManager.newDetectedVersion = false;
VersionManager.latestFormatVersion = 6;

-- TODO: Fix & Validate this function
-- Compare two version strings. Returns -1 if version is lower, 0 if equal, 1 if higher.
function VersionManager:compareVersions(version, otherVersion)
    otherVersion = otherVersion or API:GetAddonVersion();

    if(version == nil or version == "") then
        return otherVersion and 1 or 0;
    end

    if(otherVersion == nil or otherVersion == "") then
        return -1;
    end

    local function versionToTable(inVersion)
        local outTable = {}
        inVersion = inVersion or 0;

        inVersion:gsub("([^.]*).", function(c)
            table.insert(outTable, c)
        end);

        return outTable;
    end

    if(version ~= otherVersion) then
        local v1table = versionToTable(version);
        local v2table = versionToTable(otherVersion);

        local length = max(#v1table, #v2table);
        for i=1, length do
            local v1 = tonumber(v1table[i]) or 0;
            local v2 = tonumber(v2table[i]) or 0;

            if(v1 ~= v2) then
                return (v1 < v2 and -1 or 1);
            end
        end
    end

    return 0;
end


-- Returns true if loading should convert data
function VersionManager:OnInit()
    Debug:Log("Version OnInit...     Last:", ArenaAnalyticsDB.formatVersion, "Current:", VersionManager.latestFormatVersion);

    if(VersionManager.disabled) then
        return;
    end

    ArenaAnalyticsDB.formatVersion = ArenaAnalyticsDB.formatVersion or 0;
    if(ArenaAnalyticsDB.formatVersion >= VersionManager.latestFormatVersion) then
        return;
    end

    if(ArenaAnalyticsDB.formatVersion < 6) then
        for i,match in ipairs(ArenaAnalyticsDB) do
            ArenaMatch:ConvertShuffleOutcome(match);
        end

        ArenaAnalyticsDB.formatVersion = 6;
    end

    VersionManager:FinalizeConversionAttempts();

    ArenaAnalyticsDB.formatVersion = VersionManager.latestFormatVersion;
end


function VersionManager:FinalizeConversionAttempts()
	ArenaAnalytics:ResortGroupsInMatchHistory();
	Sessions:RecomputeSessionsForMatchHistory(true);

    Filters:Refresh();
    API:TriggerEvent(Interface.Events.MatchHistoryChanged);
    ArenaAnalyticsScrollFrame:Hide();
end