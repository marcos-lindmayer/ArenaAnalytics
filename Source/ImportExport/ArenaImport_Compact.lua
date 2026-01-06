local _, ArenaAnalytics = ...; -- Addon Namespace
local Import = ArenaAnalytics.Import;

-- Local module aliases
local Export = ArenaAnalytics.Export;

-------------------------------------------------------------------------

local sourceName = "ArenaAnalytics";

local formatIdentifier = "ArenaAnalyticsExport_Compact:"

-- TODO: Update format
local formatPrefix = Export.exportPrefix_Compact;

local valuesPerArena = Export:CountFields(formatPrefix);

function Import:CheckDataSource_ArenaAnalytics_Compact(outImportData)
    if(not Import.raw or Import.raw == "") then
        return false;
    end

    if(formatIdentifier ~= Import.raw:sub(1, #formatIdentifier)) then
        return false;
    end

    -- Get arena count
    outImportData.isValid = true;
    outImportData.sourceName = sourceName;
    outImportData.processorFunc = Import.ProcessNextMatch_ArenaAnalytics;
    return true;
end

-------------------------------------------------------------------------
-- Process arenas

-- TODO: Implement
function Import.ProcessNextMatch_ArenaAnalytics(arenaString, index)

end
