local _, ArenaAnalytics = ...; -- Addon Namespace
local Import = ArenaAnalytics.Import;

-- Local module aliases
local API = ArenaAnalytics.API;
local Localization = ArenaAnalytics.Localization;
local Helpers = ArenaAnalytics.Helpers;
local Internal = ArenaAnalytics.Internal;

-------------------------------------------------------------------------

local sourceKey = "ImportSource_ReflexArenas";
local sourceName = "REFlex (Arenas)";

local formatPrefix = "Timestamp;Map;PlayersNumber;TeamComposition;EnemyComposition;Duration;Victory;KillingBlows;Damage;Healing;Honor;RatingChange;MMR;EnemyMMR;Specialization;isRated";
local valuesPerArena = 16;

-- Define the separator pattern that accounts for both ";" and "\n"
local delimiter = "[;\n]";

function Import:CheckDataSource_ReflexArenas(outImportData)
    if(not Import.raw or Import.raw == "") then
        return false;
    end

    if(formatPrefix ~= Import.raw:sub(1, #formatPrefix)) then
        return false;
    end

    local valueCount = select(2, Import.raw:gsub("[^" .. delimiter .. "]+", ""));

    -- Corrupted import
    if(valueCount % valuesPerArena ~= 0) then
        ArenaAnalytics:Log("Import corrupted! Source:", sourceName);
        return false;
    end

    -- Get arena count
    outImportData.count = valueCount / valuesPerArena;
    outImportData.sourceKey = sourceKey;
    outImportData.sourceName = sourceName;
    outImportData.delimiter = delimiter;
    outImportData.prefixLength = #formatPrefix;
    outImportData.processorFunc = Import.ProcessNextMatch_ReflexArenas;
    return true;
end

-------------------------------------------------------------------------
-- Process arenas

local function ProcessTeam(players, lastIndex, isEnemyTeam)
    assert(players);

    local valueIndex = isEnemyTeam and 5 or 4;
    local composition = Import.cachedValues[lastIndex + valueIndex];
    if(not composition or composition == "") then
        return;
    end

    local teamCount = 0;

    -- Process each player
    for playerString in composition:gmatch("([^,]+)") do
        if(playerString and playerString ~= "") then
            local newPlayer = {};

            -- Split player details by hyphen: "CLASS-Spec-Name-Realm"
            local class, spec, name = strsplit("-", playerString, 3);
            if(not name) then
                ArenaAnalytics:Log("ReflexArenas imported player with missing name!");
            end

            newPlayer.isEnemy = isEnemyTeam;
            newPlayer.name = name;
            newPlayer.spec_id = Localization:GetSpecID(class, spec);

            -- Determine if the player is self
            newPlayer.isSelf = (name == UnitName("player"));
            if(newPlayer.isSelf and tonumber(lastIndex)) then
                -- Get player stats (Index 8, 9, 10)
                newPlayer.kills = tonumber(Import.cachedValues[lastIndex + 8]);
                newPlayer.damage = tonumber(Import.cachedValues[lastIndex + 9]);
                newPlayer.healing = tonumber(Import.cachedValues[lastIndex + 10]);
            end

            -- Add player data to the team list
            table.insert(players, newPlayer);
            teamCount = teamCount + 1;
        end
    end

    return teamCount;
end

function Import:ProcessNextMatch_ReflexArenas(lastIndex)
    assert(Import.cachedValues);

    -- New arena in standardized import format
    local newArena = {}
    newArena.date = tonumber(Import.cachedValues[lastIndex + 1]);           -- Date
    newArena.map = Internal:GetAddonMapID(Import.cachedValues[lastIndex + 2]);   -- Map

    -- Fill teams
    newArena.players = {}
    local teamCount = ProcessTeam(newArena.players, lastIndex, false);      -- TeamComposition
    local enemyCount = ProcessTeam(newArena.players, lastIndex, true);      -- EnemyComposition

    -- Appears to be a 2v2.
    if(teamCount == 2 and enemyCount == 2) then
        newArena.bracket = "2v2";
    end

    newArena.duration = tonumber(Import.cachedValues[lastIndex + 6]);           -- Duration
    newArena.outcome = Import:RetrieveSimpleOutcome(Import.cachedValues[lastIndex + 7]); -- Victory (boolean)

        -- Player stats moved into ProcessTeam for ally team (Index 8, 9, 10)
        -- Honor ignored (Index 11)

    newArena.partyRatingDelta = tonumber(Import.cachedValues[lastIndex + 12]);  -- RatingChange
    newArena.partyMMR = tonumber(Import.cachedValues[lastIndex + 13]);           -- MMR

    newArena.enemyMMR = tonumber(Import.cachedValues[lastIndex + 14]);      -- EnemyMMR

    local mySpec = Import.cachedValues[lastIndex + 15];                    -- Specialization

    newArena.isRated = Import:RetrieveBool(Import.cachedValues[lastIndex + 16]);   -- isRated (boolean)

    lastIndex = lastIndex + valuesPerArena;
    return newArena, lastIndex;
end
