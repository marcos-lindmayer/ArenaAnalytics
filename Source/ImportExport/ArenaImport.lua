local _, ArenaAnalytics = ...; -- Addon Namespace
local Import = ArenaAnalytics.Import;

-- Local module aliases

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

-------------------------------------------------------------------------

Import.raw = nil;
Import.isImporting = false;

Import.current = nil;
Import.cachedValues = nil;

Import.cachedArenas = nil;

function Import:IsLocked()
    return not Import.isImporting;
end

function Import:Reset()
    if(Import.isImporting) then
        return;
    end

    Import.raw = nil;
    Import.current = nil;
    Import.cachedValues = nil;
    Import.cachedArenas = nil;
end

function Import:TryHide()
    if(ArenaAnalyticsScrollFrame.importDialogFrame ~= nil and ArenaAnalytics:HasStoredMatches()) then
        ArenaAnalyticsScrollFrame.importDialogFrame.button:Disable();
        ArenaAnalyticsScrollFrame.importDialogFrame.editbox:SetText("");
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
    if(Import:CheckDataSource_ArenaAnalytics_v3(newImportData)) then
        isValid = true;
    elseif(Import:CheckDataSource_ArenaStatsCata(newImportData)) then
        isValid = true;
    elseif(Import:CheckDataSource_ArenaStatsWotlk(newImportData)) then
        isValid = true;
    elseif(Import:CheckDataSource_REFlex(newImportData)) then
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
        return;
    end

    if(not Import.current or not Import.current.processorFunc) then
        ArenaAnalytics:Log("Invalid data for import attempt.. Bailing out immediately..");
        return;
    end

    -- Reset cached values
    Import.cachedValues = {};
    
    -- TODO: Validate this
    local delimiter = Import.current.delimiter;
    Import.raw:sub(Import.current.prefixLength):gsub("([^"..delimiter.."]*)"..delimiter, function(c)
        table.insert(Import.cachedValues, c);
    end);

    ArenaAnalytics:Log("Importing", Import.current.sourceKey, Import.current.sourceName, import.current.count, #Import.cachedValues);
end

function Import:ProcessCachedValues()
    local lastIndex = 0;
    batchDurationLimit = 0.05;
    Import.isImporting = true;

    local skippedArenaCount = 0;

    local existingArenaCount = #ArenaAnalyticsDB;

    local function Finalize()
        Import:Reset();
        Import:TryHide();

        table.sort(ArenaAnalyticsDB, function (k1,k2)
            if (k1.date and k2.date) then
                return k1.date < k2.date;
            end
        end);

        ArenaAnalytics:RecomputeSessionsForMatchHistory();
        ArenaAnalytics:UpdateLastSession();
        ArenaAnalytics.unsavedArenaCount = #ArenaAnalyticsDB;

        Filters:Refresh();

        ArenaAnalytics:Print("Import complete. " .. (#ArenaAnalyticsDB - existingArenaCount) .. " arenas added!");
        ArenaAnalytics:Log("Import ignored", skippedArenaCount, "arenas due to their date.");
    end

    local function ProcessBatch()
        local batchEndTime = GetTime() + batchDurationLimit;

        while lastIndex < #Import.cachedValues do
            local arena, index = ProcessMatchIndex(currentIndex);
            lastIndex = index; -- Last processed value index

            Import:SaveArena(arena);

            if(batchEndTime < GetTime()) then
                C_Timer.After(0, ProcessBatch);
                return;
            end
        end

        Finalize();
    end
end

function Import:SaveArena(arena)
    -- Fill the arena by ArenaMatch formatting
    local newArena = {}
	ArenaMatch:SetDate(newArena, arena.date);
	ArenaMatch:SetDuration(newArena, arena.duration);
	ArenaMatch:SetMap(newArena, arena.map);

	ArenaMatch:SetBracketIndex(newArena, arena.bracketIndex);

	local matchType = nil;
	if(newArena.isRated) then
		matchType = "rated";
	elseif(newArena.isWargame) then
		matchType = "wargame";
	else
		matchType = "skirmish";
	end

	ArenaMatch:SetMatchType(newArena, matchType);

	if (newArena.isRated) then
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
	local session = ArenaAnalytics:GetLatestSession();
	local lastMatch = ArenaAnalytics:GetLastMatch(nil, false);
	if (not ArenaAnalytics:IsMatchesSameSession(lastMatch, newArena)) then
		session = session + 1;
	end
	ArenaMatch:SetSession(newArena, session);

	ArenaAnalytics.lastSession = session;

	-- Insert arena data as a new ArenaAnalyticsDB entry
	table.insert(ArenaAnalyticsDB, arenaData);
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
    if not value or value == "" then
        return nil
    end

    -- Support multiple affirmative values
    return value == "YES" or value == "1" or value == "true" or value == true;
end

function Import:RetrieveSimpleOutcome(value)
    local isWin = Import:RetrieveBool(value);
    if(isWin == nil) then
        return nil;
    end

    return isWin and 1 or 0;
end