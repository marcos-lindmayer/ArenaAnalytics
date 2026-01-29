local _, ArenaAnalytics = ...; -- Addon Namespace
local Import = ArenaAnalytics.Import;

-- Local module aliases
local Sessions = ArenaAnalytics.Sessions;
local TablePool = ArenaAnalytics.TablePool;
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local Filters = ArenaAnalytics.Filters;
local Helpers = ArenaAnalytics.Helpers;
local Debug = ArenaAnalytics.Debug;
local ImportBox = ArenaAnalytics.ImportBox;
local ImportProgressFrame = ArenaAnalytics.ImportProgressFrame;
local AAtable = ArenaAnalytics.AAtable;
local Colors = ArenaAnalytics.Colors;
local Options = ArenaAnalytics.Options;

-------------------------------------------------------------------------

--[[
    isEnemy
    isSelf
    name
    race_id
    spec_id
    kills
    deaths
    damage
    healing
    wins
    rating
    ratingDelta
    mmr
    mmrDelta
--]]

--[[
    Current Import structure:
        count
        sourceName
        processorFunc
        state
--]]

-------------------------------------------------------------------------

-- Processing
local BATCH_TIME_LIMIT = 0.01;

Import.isImporting = false;
Import.raw = nil;
Import.current = nil;
Import.dateCache = {};

Import.latestImportIndex = -1;

function Import:UpdateImportIndex()
    Import.latestImportIndex = ArenaAnalytics:GetLastImportIndex();
end

function Import:IsLocked()
    return not Import.isImporting;
end

function Import:GetSourceName()
    if(Import.current and Import.current.isValid) then
        return Import.current.sourceName or "[Missing Name]";
    end
    return "Invalid";
end

function Import:Reset()
    if(Import.isImporting) then
        return;
    end

    ImportBox:ResetAll();
    ImportProgressFrame:Stop();

    Import.raw = nil;
    Import.current = nil;
    Import.state = nil;
    Import.currentImportIndex = nil;
end

function Import:Cancel()
    if(not Import.isImporting) then
        return;
    end

    Import:Finalize();
    Import.isImporting = false;

    C_Timer.After(0, Import.Reset);
end

function Import:ProcessImportSource()
    local newImportData = {}
    local isValid = false;

    if(not Import.raw or #Import.raw == 0) then
        Import.current = nil;
        return false;
    end

    if(Import:CheckDataSource_ArenaAnalytics_CSV(newImportData)) then
        isValid = true;
    elseif(Import:CheckDataSource_ArenaStatsCata(newImportData)) then
        isValid = true;
    elseif(Import:CheckDataSource_ArenaStatsWrath(newImportData)) then
        isValid = true;
    elseif(Import:CheckDataSource_ReflexArenas(newImportData)) then
        isValid = true;
    else
        Import.current = nil;
    end

    Import.current = newImportData;
    return isValid;
end

function Import:SetPastedInput(pasteBuffer)
    Debug:Log("Finalizing import paste.");

    Import.raw = pasteBuffer and string.trim(table.concat(pasteBuffer)) or nil;
    Import:ProcessImportSource();
end

function Import:ParseRawData()
    if(not Import.raw or Import.raw == "") then
        Import:Reset();
        return;
    end

    if(not Import.current or not Import.current.isValid or not Import.current.processorFunc) then
        Debug:Log("Invalid data for import attempt.. Bailing out immediately..");
        Import:Reset();
        return;
    end

    Import:ProcessImport();
end

local function ArenaIterator()
    return coroutine.wrap(function()
        for arena in Import.raw:gmatch("[^\n]+") do
            coroutine.yield(arena);
        end
    end);
end

-- Initiate processing
function Import:ProcessImport()
    Import.isImporting = true;
    local iterator = ArenaIterator() -- Create the iterator

    -- Progress state data
    Import.state = TablePool:Acquire();
    local state = Import.state;

    state.startTime = GetTimePreciseSec();
    state.index = 0;

    local _, importCount = Import.raw:gsub("\n", "");
    state.total = importCount - 1;
    state.existing = #ArenaAnalyticsDB;
    state.skippedArenaCount = 0;

    Import:UpdateDateCache();

    Import.currentImportIndex = ArenaAnalytics:GetLastImportIndex() + 1;
    Debug:Log("Import Index:", Import.currentImportIndex);

    if(importCount > 0) then
        -- Hide import dialogue
        AAtable:HideImportDialog(true);
    end

    ImportProgressFrame:Start();

    -- Batched proccessing
    local function ProcessBatch()
        local batchEndTime = GetTimePreciseSec() + BATCH_TIME_LIMIT;

        while GetTimePreciseSec() < batchEndTime do
            if(not Import.isImporting) then
                Debug:Log("Import: Processor func missing, bailing out at index:", state.index + 1);
                Import:Finalize();
                return;
            end

            local arenaString = iterator();
            if(state and state.index and state.index > 0) then -- First iteration is the format prefix, before arena index 1
                if(not arenaString) then
                    Debug:Log("Empty arenaString")
                    Import:Finalize();
                    return;
                end

                local processedArena = Import.current.processorFunc(arenaString);
                if(processedArena) then
                    Import:SaveArena(processedArena);

                    TablePool:Release(processedArena.players);
                    TablePool:Release(processedArena.rounds);
                    TablePool:Release(processedArena);
                else
                    state.skippedArenaCount = state.skippedArenaCount + 1;
                end
            end

            state.index = state.index + 1;
        end

        C_Timer.After(0, ProcessBatch);
    end

    C_Timer.After(0, ProcessBatch);
end

function Import:Finalize()
    if(not Import.isImporting) then
        return;
    end

    -- Force update before potential freeze from resorting matches.
    ImportProgressFrame:Update();

    Import.isImporting = nil;

    wipe(Import.dateCache);

    local state = Import.current and Import.state;

    local elapsed, existingCount;
    if(state) then
        elapsed = state.startTime and (GetTimePreciseSec() - state.startTime) or 0;
        existingCount = state.existing or 0;
    else
        elapsed = 0;
        existingCount = 0;
    end

    Import:Reset();
    Import:UpdateImportIndex();

    ArenaAnalytics:ResortMatchHistory(true);
    Sessions:RecomputeSessionsForMatchHistory(true);

    Filters:Refresh();

    local addedCount = max(0, #ArenaAnalyticsDB - existingCount);
    local skippedCount = state and tonumber(state.skippedArenaCount) or 0;

    ArenaAnalytics:PrintSystemSpacer();

    local elapsedText = elapsed and format(" in %.1f seconds.", elapsed) or ".";
    ArenaAnalytics:PrintSystem(format("Import complete. %d arenas added%s", addedCount, elapsedText));

    if(skippedCount > 0) then
        ArenaAnalytics:PrintSystem(format("Import skipped %d arenas!", skippedCount));
    end

    if(addedCount > 0) then
        ArenaAnalytics:PrintSystem(format("Import Hint: %s to save, %s to undo import.", Colors:ColorText("/reload", Colors.slashCommandColor), Colors:ColorText("/aa undo", Colors.slashCommandColor)));
    end
end

function Import:SaveArena(arena)
    -- Fill the arena by ArenaMatch formatting
    local newArena = {}
	ArenaMatch:SetDate(newArena, arena.date);
	ArenaMatch:SetDuration(newArena, arena.duration);
	ArenaMatch:SetMap(newArena, arena.map);

	ArenaMatch:SetBracket(newArena, arena.bracket);

	ArenaMatch:SetMatchType(newArena, arena.matchType);

	if (arena.matchType == "rated") then
		ArenaMatch:SetPartyRating(newArena, arena.partyRating);
		ArenaMatch:SetPartyRatingDelta(newArena, arena.partyRatingDelta);
		ArenaMatch:SetPartyMMR(newArena, arena.partyMMR);

		ArenaMatch:SetEnemyRating(newArena, arena.enemyRating);
		ArenaMatch:SetEnemyRatingDelta(newArena, arena.enemyRatingDelta);
		ArenaMatch:SetEnemyMMR(newArena, arena.enemyMMR);
	end

	ArenaMatch:SetSeason(newArena, arena.season);

	ArenaMatch:SetMatchOutcome(newArena, arena.outcome);

	-- Add players from both teams sorted, and assign comps.
	ArenaMatch:AddPlayers(newArena, arena.players);

	if(arena.isShuffle) then
		ArenaMatch:SetRounds(newArena, arena.committedRounds);
	end

    ArenaMatch:SetImportIndex(newArena, Import.currentImportIndex);

	-- Insert arena data as a new ArenaAnalyticsDB entry
	table.insert(ArenaAnalyticsDB, newArena);
end

-------------------------------------------------------------------------

local truthyValues = { ["yes"] = true, ["y"] = true, ["1"] = true, ["true"] = true, [true] = true };
function Import:RetrieveBool(value)
    if(value == nil or value == "") then
        return nil;
    end

    value = Helpers:ToSafeLower(value);

    -- Support multiple affirmative values
    return value and truthyValues[value] or false;
end

function Import:RetrieveSimpleOutcome(value)
    local isWin = Import:RetrieveBool(value);

    if(isWin == nil) then
        return nil;
    end

    return isWin and 1 or 0;
end

-------------------------------------------------------------------------

function Import:UpdateDateCache()
    local first, last;

    for i=1, #ArenaAnalyticsDB do
        local match = ArenaAnalyticsDB[i];
        local date = ArenaMatch:GetDate(match);

        if(date and date > 0) then
            -- Date mapping
            Import.dateCache[date] = true;

            -- Update first date
            if(not first or date < first) then
                first = date;
            end

            -- Update last date
            if(not last or date > last) then
                last = date;
            end
        end
    end

    local minimumOffset = 86400;
    Import.dateCache.first = first and first - minimumOffset; -- 24 hours before first match
    Import.dateCache.last = last and last + minimumOffset; -- 24 hours after last match
end

-- Check a date for a duplicate, in case of repeating same import
function Import:CheckDate(timestamp)
    timestamp = tonumber(timestamp);
    if(not timestamp or timestamp == 0) then
        Debug:LogWarning("Rejecting import arena for invalid date:", timestamp);
        return false;
    end

    -- Duplicate timestamp
    if(Import.dateCache[timestamp]) then
        Debug:LogWarning("Rejecting import arena for duplicate date at index:", Import.state and Import.state.index, timestamp, Helpers:FormatDate(timestamp));
        return false;
    end

    if(Import.current and not Import.current.trustDate) then
        local firstLimit = Import.dateCache.first;
        local lastLimit = Import.dateCache.last;

        if(firstLimit and lastLimit) then
            if(timestamp > firstLimit and timestamp < lastLimit) then
                Debug:LogWarning("Rejecting import arena due to bounded timestamp limits.");
                return false;
            end
        end
    end

    return true;
end

-------------------------------------------------------------------------
-- Initialization

function Import:Initiate()
    ArenaAnalytics:ClearMatchImportIndices();
end