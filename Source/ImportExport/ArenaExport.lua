local _, ArenaAnalytics = ...; -- Addon Namespace
local Export = ArenaAnalytics.Export;

-- Local module aliases
local Internal = ArenaAnalytics.Internal;
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local Bitmap = ArenaAnalytics.Bitmap;
local TablePool = ArenaAnalytics.TablePool;
local Debug = ArenaAnalytics.Debug;
local AAtable = ArenaAnalytics.AAtable;

-------------------------------------------------------------------------
-- ArenaAnalytics export

--[[

  Functions:
    - Begin(exportFormat)
    - Stop
    - Process

--]]

local BATCH_TIME_LIMIT = 0.05;

Export.formats = {
    None = -1,
    Compact = 1,
    CSV = 2,
};

local states = {
    None = 0,
    Starting = 1,
    Exporting = 2,  -- Currently exporting
    Finished = 3,   -- Export completed
    Aborted = 4,    -- Aborting export
    Locked = 5,     -- Blocking new export / Showing last export
};


Export.state = states.None;
Export.startTime = nil;
Export.index = nil;
Export.skippedArenaCount = nil;
Export.exportTable = {};

Export.format = nil;
Export.processorFunc = nil;


function Export:GetState()
    return Export.state;
end

function Export:IsExporting()
    return Export.state == states.Starting or Export.state == states.Exporting;
end

-------------------------------------------------------------------------

function Export:CountFields(str)
    local _, count = str:gsub(",", "")
    return count;
end


function Export:MakeDummyString(count)
    local dummy = "";

    for i=1, count do
        dummy = dummy .. ",";
    end

    return dummy;
end

-- TODO: Use format specific helper functions to assign values
local function UpdateProcessorFunc()
    if(Export.format == Export.formats.CSV) then
        tinsert(Export.exportTable, Export.exportPrefix_CSV);
        Export.processorFunc = Export.ProcessMatch_CSV;
    elseif(Export.format == Export.formats.Compact) then
        tinsert(Export.exportTable, Export.exportPrefix_Compact);
        Export.processorFunc = Export.ProcessMatch_Compact;
    else
        Export.processorFunc = nil;
    end
end


local function CallProcessorFunc(index)
    if(not Export.processorFunc) then
        return;
    end

    Export:UpdateFormattedMatch(index);

    return Export.processorFunc(index);
end


function Export:Start(exportFormat)
    local currentState = Export:GetState();
    if(currentState ~= states.None) then
        Debug:Log("Export rejected: Invalid current state:", currentState);
        return;
    end

    if(not exportFormat) then
        Debug:Log("Export rejected: No format specified.");
        return;
    end

    Export.state = states.Starting;

    Export.index = 1;
    Export.startTime = time();
    Export.format = exportFormat;
    Export.skippedArenaCount = 0;

    wipe(Export.exportTable);

    UpdateProcessorFunc();

    Debug:Log("Prefix field count:", Export.fieldCount_CSV, Export.format);

    local function ProcessBatch()
        local batchEndTime = GetTimePreciseSec() + BATCH_TIME_LIMIT;

        while Export:IsExporting() and GetTimePreciseSec() < batchEndTime do
            Debug:Log("Exporting index:", Export.index, #Export.exportTable);

            local matchString = CallProcessorFunc(Export.index);
            if(matchString) then
                -- Add to combined export string
                tinsert(Export.exportTable, matchString);
            else
                Export.skippedArenaCount = Export.skippedArenaCount + 1;
            end

            Export.index = Export.index + 1;
            if(Export.index > #ArenaAnalyticsDB) then
                Export.state = states.Finished;
            end
        end

        if(Export:GetState() == states.Aborted) then
            -- Reset & Hide UI
            Export:Reset();
            return;
        end

        if(Export:IsExporting() and Export.index > #ArenaAnalyticsDB) then
            Export.state = states.Finished;
        end

        if(Export:GetState() == states.Finished) then
            -- Finalize & provide combined export string
            Export:Finalize();
            return;
        end

        C_Timer.After(0, ProcessBatch);
    end

    if(Export.state ~= states.Starting) then
        Export:Reset();
        return;
    end

    -- Begin export
    Export.state = states.Exporting;
    C_Timer.After(0, ProcessBatch);
end


function Export:Stop()
    if(not Export:IsExporting()) then
        return;
    end

    Export.isExporting = false;
end


function Export:Abort()
    if(Export:IsExporting()) then
        Export.state = states.Aborted;
    end
end


local function formatNumber(num)
    assert(num ~= nil);
    local left,num,right = string.match(num,'^([^%d]*%d)(%d*)(.-)')
    return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

function Export:Finalize()
    Export.state = states.Locked;
    Debug:Log("Finalized export:", #Export.exportTable);

    -- TODO: Hide progress frame & show during export

    -- Show export with the new CSV string
    if (ArenaAnalytics:HasStoredMatches()) then
        AAtable:CreateExportDialogFrame();
        ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame:SetText(table.concat(Export.exportTable, "\n"));
	    ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame:HighlightText();

        ArenaAnalyticsScrollFrame.exportDialogFrame.totalText:SetText("Total arenas: " .. formatNumber(#Export.exportTable - 1));
        ArenaAnalyticsScrollFrame.exportDialogFrame.lengthText:SetText("Export length: " .. formatNumber(#ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame:GetText()));
        ArenaAnalyticsScrollFrame.exportDialogFrame:Show();
    elseif(ArenaAnalyticsScrollFrame.exportDialogFrame) then
        ArenaAnalyticsScrollFrame.exportDialogFrame:Hide();
    end

    wipe(Export.exportTable);
    collectgarbage("collect");
    Debug:Log("Garbage Collection forced by Export finalize.");
end


function Export:Reset()
    Export:Hide();
    wipe(Export.exportTable);

    Export.state = states.None;
end


function Export:Hide()

end

-------------------------------------------------------------------------
--  @TODO: Implement formatted match table

-- Match
    -- MatchData
    -- Players
    -- RatedInfo
    -- Rounds

Export.formattedMatch = {};
local formattedMatch = Export.formattedMatch;

-- Helper functions
local outcomes = { [0] = "L", [1] = "W", [2] = "D" };
local function GetOutcome(outcome)
    outcome = tonumber(outcome);
    return outcome and outcomes[outcome] or "";
end

local function GetGender(player)
    local gender = tonumber(ArenaMatch:IsPlayerFemale(player));
    if(gender == nil) then
        return "";
    end
    return gender == 1 and "F" or "M";
end

local factions = { [0] = "H", [1] = "A" };
local function GetFaction(race_id)
    local faction = tonumber(Internal:GetRaceFactionIndex(race_id));
    return faction and factions[faction] or "";
end

local function GetTeam(player, isEnemy, isShuffle, isValid)
    if(isValid) then
        if(ArenaMatch:IsPlayerSelf(player)) then
            return "self";
        elseif(not isShuffle) then
            return isEnemy and "enemy" or "ally";
        end
    end

    return "";
end

local function GetClassAndSpec(player)
    local spec_id = ArenaMatch:GetPlayerSpec(player);
    local class, spec = Internal:GetClassAndSpec(spec_id);
    return (class or ""), (spec or "");
end

local function GetRole(player)
    local role_bitmap = ArenaMatch:GetPlayerRole(player);
    local _,role = Bitmap:GetMainRole(role_bitmap);
    local _,subRole = Bitmap:GetSubRole(role_bitmap);

    return (role or ""), (subRole or "");
end


function Export:ResetFormattedMatch()
    TablePool:Release(formattedMatch.RatedInfo);

    if(formattedMatch.Players) then
        -- Release players

        TablePool:Release(formattedMatch.Players);
    end

    TablePool:Release(formattedMatch.Rounds);

    wipe(formattedMatch)
end


function Export:GetFormattedRatedInfo(match)
    local ratedInfo = TablePool:Acquire();

    if(ArenaMatch:IsRated(match)) then
        ratedInfo.rating = ArenaMatch:GetPartyRating(match);
        ratedInfo.ratingDelta = ArenaMatch:GetPartyRatingDelta(match);
        ratedInfo.mmr = ArenaMatch:GetPartyMMR(match);

        ratedInfo.enemyRating = ArenaMatch:GetEnemyRating(match);
        ratedInfo.enemyRatingDelta = ArenaMatch:GetEnemyRatingDelta(match);
        ratedInfo.enemyMmr = ArenaMatch:GetEnemyMMR(match);
    end

    return ratedInfo;
end


local function FormatPlayer(player, isEnemy, isShuffle)
    if(not player) then
        return;
    end

    local playerTable = TablePool:Acquire();
    local race_id = ArenaMatch:GetPlayerRace(player);

    local isFirstDeath = ArenaMatch:IsPlayerFirstDeath(player);

    playerTable.name = ArenaMatch:GetPlayerFullName(player) or "";
    playerTable.race = Internal:GetRace(race_id) or "";
    playerTable.faction = GetFaction(race_id);
    playerTable.team = GetTeam(player, isEnemy, isShuffle, (playerTable.name ~= "")); -- Self, Ally, Enemy
    playerTable.gender = GetGender(player);
    playerTable.class, playerTable.spec = GetClassAndSpec(player);
    playerTable.role, playerTable.subRole = GetRole(player);

    local kills, deaths, damage, healing = ArenaMatch:GetPlayerStats(player);
    playerTable.kills = tonumber(kills) or "";
    playerTable.deaths = tonumber(deaths) or "";
    playerTable.damage = tonumber(damage) or "";
    playerTable.healing = tonumber(healing) or "";

    playerTable.wins = isShuffle and tonumber(ArenaMatch:GetPlayerVariableStats(player)) or "";

    local rating, ratingDelta, mmr, mmrDelta = ArenaMatch:GetPlayerRatedInfo(player);
    playerTable.rating = rating or "";
    playerTable.ratingDelta = ratingDelta or "";
    playerTable.mmr = mmr or "";
    playerTable.mmrDelta = mmrDelta or "";

    return playerTable, isFirstDeath;
end


function Export:GetFormattedPlayers(match, isShuffle)
    local players = TablePool:Acquire();

    local teams = {"team", "enemyTeam"};
    for _,teamKey in ipairs(teams) do
        local team = match[teamKey];
        local isEnemy = (teamKey == "enemyTeam");

        for i=1, 5 do
            local player = ArenaMatch:GetPlayer(match, isEnemy, i);

            --local player = team and team[i] or nil;

            local formattedPlayer, isFirstDeath = FormatPlayer(player, isShuffle, isEnemy);
            if(formattedPlayer) then
                tinsert(players, formattedPlayer);

                if(isFirstDeath) then
                    formattedMatch.firstDeath = formattedPlayer.name;
                    formattedMatch.firstDeathIndex = #players;
                end
            end

        end
    end

    -- Sort by self first?

    return players;
end

local function GetPlayerID(playerRaw)
    if(not playerRaw) then
        return nil;
    end

    local playerName = ArenaMatch:GetPlayerFullName(playerRaw);
    if(not playerName) then
        return nil;
    end

    for playerIndex,player in ipairs(formattedMatch.players) do
        if(player.name == playerName) then
            return player.name; -- Name or Index?
        end
    end

    return nil;
end

local function FormatRound(allies, enemies, firstDeath, duration, outcome)
    local round = TablePool:Acquire();

    round.duration = tonumber(duration) or "";
    round.outcome = GetOutcome(outcome);
    round.firstDeath = firstDeath or "";
    round.allies = allies or TablePool:Acquire();
    round.enemies = enemies or TablePool:Acquire();

    return round;
end

function Export:GetFormattedRounds(match)
    local formattedRounds = TablePool:Acquire();

    local selfPlayer = ArenaMatch:GetSelf(match);
    local players = ArenaMatch:GetTeam(match, true);

    local function GetPlayerByIndex(playerIndex)
        playerIndex = tonumber(playerIndex);
        if(not playerIndex) then
            return nil;
        end

        return (playerIndex == 0) and selfPlayer or players[playerIndex];
    end

    local currentRounds = ArenaMatch:GetRounds(match);
    for roundIndex=1, 6 do
        local allies = TablePool:Acquire();
        local enemies = TablePool:Acquire();

        local roundData = currentRounds and ArenaMatch:GetRoundDataRaw(currentRounds[roundIndex]);
        if(roundData) then
            local team, enemy, firstDeath, duration, outcome = ArenaMatch:SplitRoundData(roundData);

            for i=1, 3 do
                local index;

                -- Deconstruct compact team (210) where each index is a player index, and match the values to firstDeath index.
                if(type(team) == "string") then
                    local playerIndex = (i == 0) and 0 or tonumber(team:sub(i,i));
                    if(playerIndex) then
                        local player = GetPlayerByIndex(playerIndex);
                        index = GetPlayerID(player) or playerIndex;
                    end
                end

                allies[i] = index or "";
            end

            for i=1, 3 do
                local index;

                -- Deconstruct compact enemy team (345) where each index is a player index, and match the values to firstDeath index.
                if(type(enemy) == "string") then
                    local playerIndex = tonumber(enemy:sub(i,i));
                    if(playerIndex) then
                        local player = GetPlayerByIndex(playerIndex);
                        index = GetPlayerID(player) or playerIndex;
                    end
                end

                enemies[i] = index or "";
            end

            -- first death conversion
            local firstDeathPlayer = GetPlayerByIndex(firstDeath);
            firstDeath = GetPlayerID(firstDeathPlayer) or firstDeath;

            -- Fill round
            tinsert(formattedRounds, FormatRound(allies, enemies, firstDeath, duration, outcome));
        end
    end

    return formattedRounds;
end


function Export:UpdateFormattedMatch(index)
    local index = tonumber(index);
    local match = index and ArenaAnalyticsDB[index];
    if(not match) then
        Export:ResetFormattedMatch();
        return;
    end

    formattedMatch.firstDeath = nil;
    formattedMatch.firstDeathIndex = nil;

    local isShuffle = ArenaMatch:IsShuffle(match);
    formattedMatch.isShuffle = isShuffle or false;
    formattedMatch.isRated = ArenaMatch:IsRated(match);

    -- Match Data
    formattedMatch.date = ArenaMatch:GetDate(match) or "";
    formattedMatch.season = ArenaMatch:GetSeason(match) or "";
    formattedMatch.seasonPlayed = ArenaMatch:GetSeasonPlayed(match) or "";
    formattedMatch.map = ArenaMatch:GetMap(match) or "";
    formattedMatch.bracket = ArenaMatch:GetBracket(match) or "";
    formattedMatch.matchType = ArenaMatch:GetMatchType(match) or "";
    formattedMatch.duration = ArenaMatch:GetDuration(match) or "";
    formattedMatch.outcome = GetOutcome(ArenaMatch:GetMatchOutcome(match));
    formattedMatch.dampening = nil; -- NYI
    formattedMatch.queueTime = nil; -- NYI

    -- Rated Info
    formattedMatch.ratedInfo = Export:GetFormattedRatedInfo(match);

    -- Players
    formattedMatch.players = Export:GetFormattedPlayers(match, isShuffle);

    -- Rounds
    formattedMatch.rounds = isShuffle and Export:GetFormattedRounds(match) or nil;

    formattedMatch.isValid = true;
end


local function formatNumber(num)
    assert(num ~= nil);
    local left,num,right = string.match(num,'^([^%d]*%d)(%d*)(.-)')
    return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

function Export:FinalizeExportCSV(exportTable)
    Debug:Log("Attempting export.. FinalizeExportCSV", #exportTable);

    -- Show export with the new CSV string
    if (ArenaAnalytics:HasStoredMatches()) then
        AAtable:CreateExportDialogFrame();
        ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame:SetText(table.concat(exportTable, "\n"));
	    ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame:HighlightText();

        ArenaAnalyticsScrollFrame.exportDialogFrame.totalText:SetText("Total arenas: " .. formatNumber(#exportTable - 1));
        ArenaAnalyticsScrollFrame.exportDialogFrame.lengthText:SetText("Export length: " .. formatNumber(#ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame:GetText()));
        ArenaAnalyticsScrollFrame.exportDialogFrame:Show();
    elseif(ArenaAnalyticsScrollFrame.exportDialogFrame) then
        ArenaAnalyticsScrollFrame.exportDialogFrame:Hide();
    end

    wipe(exportTable);
    collectgarbage("collect");
    Debug:Log("Garbage Collection forced by Export finalize.");
end