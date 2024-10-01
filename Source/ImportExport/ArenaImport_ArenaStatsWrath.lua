local _, ArenaAnalytics = ...; -- Addon Namespace
local Import = ArenaAnalytics.Import;

-- Local module aliases
local API = ArenaAnalytics.API;

-------------------------------------------------------------------------

local sourceKey = "ImportSource_ArenaStatsWrath";
local sourceName = "ArenaStats (Wrath)";

local formatPrefix = "isRanked,startTime,endTime,zoneId,duration,teamName,teamColor,"..
    "winnerColor,teamPlayerName1,teamPlayerName2,teamPlayerName3,teamPlayerName4,teamPlayerName5,"..
    "teamPlayerClass1,teamPlayerClass2,teamPlayerClass3,teamPlayerClass4,teamPlayerClass5,"..
    "teamPlayerRace1,teamPlayerRace2,teamPlayerRace3,teamPlayerRace4,teamPlayerRace5,oldTeamRating,"..
    "newTeamRating,diffRating,mmr,enemyOldTeamRating,enemyNewTeamRating,enemyDiffRating,enemyMmr,"..
    "enemyTeamName,enemyPlayerName1,enemyPlayerName2,enemyPlayerName3,enemyPlayerName4,"..
    "enemyPlayerName5,enemyPlayerClass1,enemyPlayerClass2,enemyPlayerClass3,enemyPlayerClass4,"..
    "enemyPlayerClass5,enemyPlayerRace1,enemyPlayerRace2,enemyPlayerRace3,enemyPlayerRace4,"..
    "enemyPlayerRace5,enemyFaction";

local valuesPerArena = 48;

-- Define the separator pattern that accounts for both ";" and "\n"
local delimiter = "[,\n]";

function Import:CheckDataSource_ArenaStatsWotlk(outImportData)
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

    -- Get arena count
    outImportData.count = valueCount / valuesPerArena;
    outImportData.sourceKey = sourceKey;
    outImportData.sourceName = sourceName;
    outImportData.delimiter = delimiter;
    outImportData.prefixLength = #formatPrefix;
    outImportData.processorFunc = Import.ProcessNextMatch_ArenaStatsWotlk;
    return true;
end

-------------------------------------------------------------------------
-- Process arenas

local function ProcessPlayer(lastIndex, isEnemyTeam, playerIndex, factionIndex)
    local indexOffset = isEnemyTeam and 32 or 8;

    local valueIndex = lastIndex + indexOffset + playerIndex;

    local name = Import.cachedValues[valueIndex];
    
    -- Assume invalid player, if name is missing
    if(not name) then
        return nil;
    end

    if(not isEnemyTeam) then
        factionIndex = nil;
    end

    local class = Import.cachedValues[valueIndex + 5];
    local race = Import.cachedValues[valueIndex + 10];

    local player = {
        isEnemy = isEnemyTeam,
        isSelf = (name == UnitName("player")),
        name = name,
        spec_id = Localization:GetClassID(class),
        race_id = Localization:GetRaceID(race, factionIndex),
    };

    return player;
end

function Import:ProcessNextMatch_ArenaStatsWotlk(lastIndex)
    assert(Import.cachedValues);

    -- Create a new arena match table in a standardized format
    local newArena = {}

    -- Set basic arena properties
    newArena.isRated = Import:RetrieveBool(Import.cachedValues[lastIndex + 1]);        -- isRated (boolean)
    newArena.date = tonumber(Import.cachedValues[lastIndex + 2]);          -- Start time (date)
    newArena.map = Internal:GetAddonMapID(Import.cachedValues[lastIndex + 4]);  -- Map ID
    newArena.duration = tonumber(Import.cachedValues[lastIndex + 5]);  -- Duration
    newArena.outcome = Import:RetrieveSimpleOutcome(Import.cachedValues[lastIndex + 8]);    -- Victory (boolean)

    -- Fill teams with player data
    newArena.players = {}

    local enemyCount = 0;
    local factionIndex = Localization:GetFactionIndex(Import.cachedValues[lastIndex + 48]);
    for _,isEnemy in ipairs({false, true}) do
        for i=1, 5 do
            local player = ProcessPlayer(lastIndex, isEnemy, i, factionIndex);
            if(player) then
                tinsert(newArena.players, player);

                if(player.isEnemy) then
                    enemyCount = enemyCount + 1;
                end
            end
        end
    end

    if(#newArena.players == 4 and enemyCount == 2) then
        newArena.bracket = "2v2";
    elseif (#newArena.players == 6 and enemyCount == 3) then
        newArena.bracket = "3v3";
    elseif(#newArena.players == 10 and enemyCount == 5) then
        newArena.bracket = "5v5";
    end

    -- Player rating and MMR data
    newArena.partyRating = tonumber(Import.cachedValues[lastIndex + 25]);
    newArena.partyRatingDelta = tonumber(Import.cachedValues[lastIndex + 26]);  -- Rating Delta
    newArena.partyMMR = tonumber(Import.cachedValues[lastIndex + 27]);  -- Party MMR

    -- Enemy rating and MMR data
    newArena.enemyRating = tonumber(Import.cachedValues[lastIndex + 29]);
    newArena.enemyRatingDelta = tonumber(Import.cachedValues[lastIndex + 30]);  -- Rating Delta
    newArena.enemyMMR = tonumber(Import.cachedValues[lastIndex + 31]);  -- Enemy MMR

    -- Return new arena and updated index
    lastIndex = lastIndex + valuesPerArena;
    return newArena, lastIndex;
end