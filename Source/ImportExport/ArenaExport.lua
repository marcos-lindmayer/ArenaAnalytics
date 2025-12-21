local _, ArenaAnalytics = ...; -- Addon Namespace
local Export = ArenaAnalytics.Export;

-- Local module aliases
local Internal = ArenaAnalytics.Internal;
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local Bitmap = ArenaAnalytics.Bitmap;
local TablePool = ArenaAnalytics.TablePool;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------
-- ArenaAnalytics export

--[[

  Functions:
    - Begin(exportFormat)
    - Stop
    - Process

--]]

local BATCH_TIME_LIMIT = 0.01;

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

Export.format = nil;
Export.processorFunc = nil;

Export.combinedString = nil;


function Export:GetState()
    return Export.state;
end

function Export:IsExporting()
    return Export.state == states.Starting or Export.state == states.Exporting;
end

-------------------------------------------------------------------------

local function UpdateProcessorFunc()
    if(Export.format == Export.formats.CSV) then
        Export.processorFunc = nil;
    elseif(Export.format == Export.formats.Compact) then
        Export.processorFunc = nil;
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
    Export.combinedString = "";
    Export.skippedArenaCount = 0;

    UpdateProcessorFunc();

    local function ProcessBatch()
        local batchEndTime = GetTimePreciseSec() + BATCH_TIME_LIMIT;

        while Export:IsExporting() and GetTimePreciseSec() < batchEndTime do
            local matchString = CallProcessorFunc(Export.index);
            if(matchString) then
                -- Add to combined export string
                Export.combinedString = Export.combinedString .. matchString;
            else
                Export.skippedArenaCount = Export.skippedArenaCount + 1;
            end
        end

        if(Export:GetState() == states.Aborted) then
            -- Reset & Hide UI
            Export:Reset();
            return;
        end

        if(Export:IsExporting()) then
            Export.index = Export.index + 1;

            if(Export.index > #ArenaAnalyticsDB) then
                Export.state = states.Finished;
            end
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


function Export:Finalize()
    Export.state = states.Locked;

    -- TODO: Hide progress frame
    -- TODO: Show export frame
end


function Export:Reset()
    Export:Hide();
    Export.combinedString = nil;
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
local outcomes = { "L", "W", "D" };
local function GetOutcome(outcome)
    return outcome and outcomes[outcome] or "";
end

local genders = { "F", "M" };
local function GetGender(player)
    local gender = ArenaMatch:IsPlayerFemale(player);
    gender = gender and genders[gender] or "";
end

local factions = { "A", "H" };
local function GetFaction(race_id)
    local faction = Internal:GetRaceFactionIndex(race_id);
    return faction and factions[faction] or "";
end

local function GetTeam(player, isEnemy, isShuffle)
    if(ArenaMatch:IsPlayerSelf(player)) then
        return "self";
    elseif(not isShuffle) then
        return isEnemy and "enemy" or "ally";
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

function Export:UpdateFormattedMatch(index)
    local index = tonumber(index);
    local match = index and ArenaAnalyticsDB[index];
    if(not match) then
        Export:ResetFormattedMatch();
        return;
    end

    local isShuffle = ArenaMatch:IsShuffle(match);

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
    if(isShuffle) then
        formattedMatch.rounds = Export:GetFormattedRounds(match);
    else
        formattedMatch.rounds = nil;
    end
end


function Export:GetFormattedRatedInfo(match)
    if(not ArenaMatch:IsRated(match)) then
        return;
    end

    local ratedInfo = TablePool:Acquire();
    ratedInfo.rating = ArenaMatch:GetPartyRating(match);
    ratedInfo.ratingDelta = ArenaMatch:GetPartyRatingDelta(match);
    ratedInfo.mmr = ArenaMatch:GetPartyMMR(match);

    ratedInfo.enemyRating = ArenaMatch:GetEnemyRating(match);
    ratedInfo.enemyRatingDelta = ArenaMatch:GetEnemyRatingDelta(match);
    ratedInfo.enemyMmr = ArenaMatch:GetEnemyMMR(match);

    return ratedInfo;
end


local function FormatPlayer(player, isEnemy, isShuffle)
    local playerTable = TablePool:Acquire();
    local race_id = ArenaMatch:GetPlayerRace(player);

    local isFirstDeath = ArenaMatch:isFirstDeath(player);

    playerTable.name = ArenaMatch:GetPlayerFullName(player) or "";
    playerTable.race = ArenaMatch:GetRace(race_id) or "";
    playerTable.faction = GetFaction(race_id);
    playerTable.team = GetTeam(player, isEnemy, isShuffle); -- Self, Ally, Enemy
    playerTable.isFirstDeath = isFirstDeath and "1" or ""; -- TODO: Y, N, ""?
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

    return TablePool, isFirstDeath;
end

function Export:GetFormattedPlayers(match, isShuffle)
    local players = TablePool:Acquire();

    local teams = {"team", "enemyTeam"};
    for _,teamKey in ipairs(teams) do
        local team = match[teamKey];
        local isEnemy = not isShuffle and (teamKey == "enemyTeam") or nil;

        for i=1, 5 do
            local player = team and team[i] or nil;
            local formattedPlayer, isFirstDeath = FormatPlayer(player, isShuffle, isEnemy);
            tinsert(players, formattedPlayer);

            if(isFirstDeath) then
                formattedMatch.firstDeath = formattedPlayer.name;
                formattedMatch.firstDeathIndex = #players;
            end
        end
    end

    return players;
end

local function GetPlayerIndex(player)
    local playerName = ArenaMatch:GetPlayerFullName(player);

    for i,player in ipairs(formattedMatch.players) do
        if(player.name == playerName) then
            return i;
        end
    end

    return nil;
end

local function FormatRound(allies, enemies, firstDeath, duration, outcome)
    local round = TablePool:Acquire();

    round.duration = tonumber(duration) or "";
    round.outcome = GetOutcome(outcome);
    round.firstDeath = firstDeath and "Y" or "";
    round.allies = allies;
    round.enemies = enemies;

end

function Export:GetFormattedRounds(match)
    local formattedRounds = TablePool:Acquire();

    local selfPlayer = ArenaMatch:GetSelf(match);
    local players = ArenaMatch:GetTeam(match, true);

    local currentRounds = ArenaMatch:GetRounds(match);
    for roundIndex=1, 6 do
        local roundFrame = self.rounds[roundIndex];
        assert(roundFrame, "ShuffleTooltip should always have 6 round frames!" .. (self.rounds and #self.rounds or "nil"));

        local deaths = TablePool:Acquire();
        local allies = TablePool:Acquire();
        local enemies = TablePool:Acquire();

        local roundData = currentRounds and ArenaMatch:GetRoundDataRaw(currentRounds[roundIndex]);
        if(roundData) then
            local team, enemy, firstDeath, duration, outcome = ArenaMatch:SplitRoundData(roundData);

            if(firstDeath) then
                deaths[firstDeath] = (deaths[firstDeath] or 0) + 1;
            end

            for i=1, 3 do
                local index;

                -- Deconstruct compact team (210) where each index is a player index, and match the values to firstDeath index.
                if(type(team) == "string") then
                    local playerIndex = (i == 0) and 0 or tonumber(team:sub(i,i));
                    if(playerIndex) then
                        local player = (playerIndex == 0) and selfPlayer or players[playerIndex];
                        index = GetPlayerIndex(player);
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
                        local player = players[playerIndex];
                        index = GetPlayerIndex(player);
                    end
                end

                enemies[i] = index or "";
            end

            -- Fill round
            tinsert(formattedRounds, FormatRound(allies, enemies, firstDeath, duration, outcome));
        end
    end

    return formattedRounds;
end