local _, ArenaAnalytics = ...; -- Addon Namespace
local Import = ArenaAnalytics.Import;

-- Local module aliases
local Sessions = ArenaAnalytics.Sessions;
local TablePool = ArenaAnalytics.TablePool;
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local Filters = ArenaAnalytics.Filters;
local Helpers = ArenaAnalytics.Helpers;
local Debug = ArenaAnalytics.Debug;

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
--]]
-------------------------------------------------------------------------

Import.raw = nil;
Import.isImporting = false;

Import.current = nil;

Import.cachedArenas = nil;

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

    Import.raw = nil;
    Import.current = nil;
    Import.cachedArenas = nil;
end

function Import:TryHide()
    if(ArenaAnalyticsScrollFrame.importDialogFrame ~= nil and ArenaAnalytics:HasStoredMatches()) then
        ArenaAnalyticsScrollFrame.importDialogFrame.button:Disable();
        ArenaAnalyticsScrollFrame.importDialogFrame.importBox:SetText("");
        ArenaAnalyticsScrollFrame.importDialogFrame:Hide();
        ArenaAnalyticsScrollFrame.importDialogFrame = nil;
    end
end

function Import:ProcessImportSource()
    local newImportData = {}
    local isValid = false;

    if(not Import.raw or #Import.raw == 0) then
        Import.current = nil;
        return false;
    end

    -- ArenaAnalytics v3
    if(Import:CheckDataSource_ArenaAnalytics(newImportData)) then
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
    return false;
end

function Import:SetPastedInput(pasteBuffer)
    ArenaAnalytics:Log("Finalizing import paste.");

    Import.raw = pasteBuffer and string.trim(table.concat(pasteBuffer)) or nil;
    Import:ProcessImportSource();
end

function Import:ParseRawData()
    if(not Import.raw or Import.raw == "") then
        Import:Reset();
        return;
    end

    if(not Import.current  or not Import.current.isValid or not Import.current.processorFunc) then
        ArenaAnalytics:Log("Invalid data for import attempt.. Bailing out immediately..");
        Import:Reset();
        return;
    end

    -- Reset cached values
    Import.cachedArenas = Import.cachedArenas or TablePool:Acquire();
    TablePool:Clear(Import.cachedArenas);

    for arena in Import.raw:gmatch("[^\n]+") do
        table.insert(Import.cachedArenas, arena)
    end

    Import.raw = nil;

    ArenaAnalytics:Log("Importing", Import.current.sourceName, #Import.cachedArenas);
    Import:ProcessCachedValues();
end

function Import:ProcessCachedValues()
    local index = 2;
    local batchLimit = 100;

    Import.isImporting = true;

    local skippedArenaCount = 0;

    local existingArenaCount = #ArenaAnalyticsDB;

    local function Finalize()
        Import:Reset();
        Import:TryHide();

        ArenaAnalytics:ResortMatchHistory();

        Sessions:RecomputeSessionsForMatchHistory();
        ArenaAnalytics.unsavedArenaCount = #ArenaAnalyticsDB;

        Filters:Refresh();

        ArenaAnalytics:Print("Import complete. " .. (#ArenaAnalyticsDB - existingArenaCount) .. " arenas added!");
        ArenaAnalytics:Log("Import ignored", skippedArenaCount, "arenas due to their date.");
    end

    local function ProcessBatch()
        local batchIndexLimit = index + batchLimit;
        Debug:LogFrameTime("Import: ProcessBatch()");
        if(ArenaAnalyticsScrollFrame.importDataText3) then
            ArenaAnalyticsScrollFrame.importDataText3:SetText(string.format("Progress: %d out of %d", index, #Import.cachedArenas));
        end

        while index <= #Import.cachedArenas do
            if(not Import.current.processorFunc) then
                ArenaAnalytics:Log("Import: Processor func missing, bailing out at index:", lastIndex + 1);
                break;
            end

            local arena = Import.current.processorFunc(index);
            if(arena) then
                Import:SaveArena(arena);
                TablePool:ReleaseNested(arena);
            end

            index = index + 1;
            if(batchIndexLimit <= index) then
                C_Timer.After(0, ProcessBatch);
                return;
            end
        end

        Finalize();
    end

    C_Timer.After(0, ProcessBatch);
end

function Import:SaveArena(arena)
    -- Fill the arena by ArenaMatch formatting
    local newArena = {}
	ArenaMatch:SetDate(newArena, arena.date);
	ArenaMatch:SetDuration(newArena, arena.duration);
	ArenaMatch:SetMap(newArena, arena.map);

	ArenaMatch:SetBracketIndex(newArena, arena.bracketIndex);

	local matchType = nil;
	if(arena.isRated) then
		matchType = "rated";
	elseif(arena.isWargame) then
		matchType = "wargame";
	else
		matchType = "skirmish";
	end

	ArenaMatch:SetMatchType(newArena, matchType);

	if (arena.isRated) then
		ArenaMatch:SetPartyRating(newArena, arena.partyRating);
		ArenaMatch:SetPartyRatingDelta(newArena, arena.partyRatingDelta);
		ArenaMatch:SetPartyMMR(newArena, arena.partyMMR);

		ArenaMatch:SetEnemyRating(newArena, arena.enemyRating);
		ArenaMatch:SetEnemyRatingDelta(newArena, arena.enemyRatingDelta);
		ArenaMatch:SetEnemyMMR(newArena, arena.enemyMMR);
	end

	ArenaMatch:SetSeason(newArena, season);

	ArenaMatch:SetMatchOutcome(newArena, arena.outcome);

	-- Add players from both teams sorted, and assign comps.
	ArenaMatch:AddPlayers(newArena, arena.players);

	if(arena.isShuffle) then
		ArenaMatch:SetRounds(newArena, arena.committedRounds);
	end

	-- Assign session
	local session = Sessions:GetLatestSession();
	local lastMatch = ArenaAnalytics:GetLastMatch();
	if (not Sessions:IsMatchesSameSession(lastMatch, newArena)) then
		session = session + 1;
	end

	ArenaMatch:SetSession(newArena, session);

	-- Insert arena data as a new ArenaAnalyticsDB entry
	table.insert(ArenaAnalyticsDB, newArena);
end

-------------------------------------------------------------------------

function Import:CreatePlayer(isEnemy, isSelf, name, race, spec, kills, deaths, damage, healing, wins, rating, ratingDelta, mmr, mmrDelta)
    return {
        isEnemy = isEnemy,
        isSelf = isSelf,
        name = name,
        race_id = race,
        spec_id = spec,
        kills = kills,
        deaths = deaths,
        damage = damage,
        healing = healing,
        wins = wins,
        rating = rating,
        ratingDelta = ratingDelta,
        mmr = mmr,
        mmrDelta = mmrDelta,
    };
end

function Import:RetrieveBool(value)
    if(value == nil or value == "") then
        return nil;
    end

    value = Helpers:ToSafeLower(value);

    -- Support multiple affirmative values
    return (value == "yes") or (value == "1") or (value == "true") or (value == true) or false;
end

function Import:RetrieveSimpleOutcome(value)
    local isWin = Import:RetrieveBool(value);

    if(isWin == nil) then
        return nil;
    end

    return isWin and 1 or 0;
end