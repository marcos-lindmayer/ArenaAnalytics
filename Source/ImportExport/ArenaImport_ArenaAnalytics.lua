local _, ArenaAnalytics = ...; -- Addon Namespace
local Import = ArenaAnalytics.Import;

-- Local module aliases

-------------------------------------------------------------------------
local sourceKey = "ImportSource_ArenaStatsCata";
local sourceName = "ArenaStats (Cata)";

local formatPrefix = "" --TODO Fill with new format

local importIdentifier = "ArenaAnalytics:";
local formatPrefix = importIdentifier ..
    -- Match data
    "date,season,bracket,map,duration,won,isRated,rating,ratingDelta,mmr,enemyRating,enemyRatingDelta,enemyMMR,firstDeath,player,"..

    -- Team data
    "party1Name,party2Name,party3Name,party4Name,party5Name,"..
    "party1Race,party2Race,party3Race,party4Race,party5Race,"..
    "party1Class,party2Class,party3Class,party4Class,party5Class,"..
    "party1Spec,party2Spec,party3Spec,party4Spec,party5Spec,"..
    "party1Kills,party2Kills,party3Kills,party4Kills,party5Kills,"..
    "party1Deaths,party2Deaths,party3Deaths,party4Deaths,party5Deaths,"..
    "party1Damage,party2Damage,party3Damage,party4Damage,party5Damage,"..
    "party1Healing,party2Healing,party3Healing,party4Healing,party5Healing,"..

    -- Enemy Team Data
    "enemy1Name,enemy2Name,enemy3Name,enemy4Name,enemy5Name,"..
    "enemy1Race,enemy2Race,enemy3Race,enemy4Race,enemy5Race,"..
    "enemy1Class,enemy2Class,enemy3Class,enemy4Class,enemy5Class,"..
    "enemy1Spec,enemy2Spec,enemy3Spec,enemy4Spec,enemy5Spec,"..
    "enemy1Kills,enemy2Kills,enemy3Kills,enemy4Kills,enemy5Kills,"..
    "enemy1Deaths,enemy2Deaths,enemy3Deaths,enemy4Deaths,enemy5Deaths,"..
    "enemy1Damage,enemy2Damage,enemy3Damage,enemy4Damage,enemy5Damage,"..
    "enemy1Healing,enemy2Healing,enemy3Healing,enemy4Healing,enemy5Healing";

-- TODO: Update to v3 format, including shuffles and possibly additional tracked data
function Import:CheckDataSource_ArenaAnalytics_v3()
    if(not Import.raw or Import.raw == "") then
        return false;
    end

    return Import.raw:sub(1, #importIdentifier) == importIdentifier;
end

function Import:CheckDataSource_ArenaAnalytics(outImportData)
    if(not Import.raw or Import.raw == "") then
        return false;
    end

    if(formatPrefix ~= Import.raw:sub(1, #formatPrefix)) then
        return false;
    end

    local valueCount = select(2, Import.raw:gsub("[^" .. delimiter .. "]+", ""));

    -- Corrupted import
    if(#valueCount % valuesPerArena ~= 0) then
        ArenaAnalytics:Log("Import corrupted! Source:", sourceName);
        return false;
    end

    ArenaAnalytics:Log("Discarding ArenaAnalytics import: NYI!");
    if(true) then return false end -- NYI

    -- Get arena count
    outImportData.isValid = true;
    outImportData.count = valueCount / valuesPerArena;
    outImportData.sourceKey = sourceKey;
    outImportData.sourceName = sourceName;
    outImportData.delimiter = delimiter;
    outImportData.prefixLength = #formatPrefix;
    outImportData.processorFunc = Import.ProcessNextMatch_ArenaStatsCata;
    return true;
end