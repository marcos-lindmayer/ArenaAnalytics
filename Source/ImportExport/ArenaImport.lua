local _, ArenaAnalytics = ...; -- Addon Namespace
local Import = ArenaAnalytics.Import;

-- Local module aliases

-------------------------------------------------------------------------

Import.current = nil;
Import.cachedValues = {};

Import.raw = "";
Import.source = "Invalid";

Import.cachedArenas = {};

function Import:GetSourceName()
    if(Import.source and Import.source ~= "") then
        if(Import.source == "ArenaAnalytics_v3") then
            return "ArenaAnalytics (v3)";
        end

        if(Import.source == "ArenaStats_Wotlk") then
            return "ArenaStats (WotLK)";
        end

        if(Import.source == "ArenaStats_Cata") then
            return "ArenaStats (Cata)";
        end
    end

    return "Invalid";
end

function Import:ProcessImportSource()
    if(#Import.raw > 0) then
        -- ArenaAnalytics v3
        if(Import:CheckDataSource_ArenaAnalytics_v3()) then
            return "ArenaAnalytics_v3";
        end

        if(Import:CheckDataSource_ArenaStatsCata()) then
            return "ArenaStats_Cata";
        end

        if(Import:CheckDataSource_ArenaStatsWotlk()) then
            return "ArenaStats_Wotlk";
        end
    end

    return "Invalid";
end

function Import:SetPastedInput(pasteBuffer)
    ArenaAnalytics:Log("Finalizing import paste.");

    Import.raw = pasteBuffer and string.trim(table.concat(pasteBuffer)) or "";
    Import.source = Import:ProcessImportSource();

    pasteBuffer, index = {}, 0;
end

function Import:ParseRawData()
    if(not Import.raw or Import.raw == "") then
        return;
    end

    if(Import.source == "Invalid") then
        ArenaAnalytics:Log("Invalid data for import attempt.. Bailing out immediately..");
        return;
    end
end
