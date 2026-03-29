local _, ArenaAnalytics = ... -- Namespace
local ArenaTracker = ArenaAnalytics.ArenaTracker;

-- Local module aliases
local AAmatch = ArenaAnalytics.AAmatch;
local Constants = ArenaAnalytics.Constants;
local API = ArenaAnalytics.API;
local Helpers = ArenaAnalytics.Helpers;
local Internal = ArenaAnalytics.Internal;
local Localization = ArenaAnalytics.Localization;
local Inspection = ArenaAnalytics.Inspection;
local Events = ArenaAnalytics.Events;
local TablePool = ArenaAnalytics.TablePool;
local Debug = ArenaAnalytics.Debug;
local ArenaRatedInfo = ArenaAnalytics.ArenaRatedInfo;

-------------------------------------------------------------------------
-- ArenaTracker subsection
-- Responsible for dealing with Solo Shuffle specific logic
-------------------------------------------------------------------------

local currentArena = {};
function ArenaTracker:InitializeSubmodule_Shuffle()
    currentArena = ArenaAnalyticsTransientDB.currentArena;
end


function ArenaTracker:IsTrackingShuffle(skipTransient)
	return ArenaTracker:IsTrackingArena(skipTransient) and ArenaTracker:IsShuffle();
end


-- Get current player wins and all players summed wins
function ArenaTracker:GetCurrentWins()
	if(not ArenaTracker:IsTrackingShuffle(true)) then
		return;
	end

	local hasAnyScores = false;

	local myWins, totalWins = 0,0;
	for i=1, API:GetNumBattlefieldScores() do
		local score = API:GetPlayerScore(i);
		if(score and API:IsValidValue(score.wins)) then
			hasAnyScores = true;

			if(API:IsValidValue(score.name) and API:IsValidValue(currentArena.playerName)) then
				if(score.name == currentArena.playerName) then
					myWins = score.wins;
					currentArena.wins = score.wins;
				end
			end

			totalWins = totalWins + score.wins;
		end
	end

	if(not hasAnyScores) then
		return nil, nil;
	end

	Debug:LogGreen("Current Wins:", myWins, totalWins);
	return myWins, totalWins;
end


function ArenaTracker:UpdateRoundTeam_Internal()
	if(not ArenaTracker:IsTrackingShuffle()) then
		return;
	end

	if(ArenaTracker:IsSameRoundTeam()) then
		Debug:Log("Still same team, round team update delayed.");
		return;
	end

	currentArena.round.team = TablePool:Acquire();

	for i=1, 2 do
		local name = API:GetUnitFullName("party"..i);
		if(name) then
			tinsert(currentArena.round.team, name);
			Debug:Log("Adding team player:", name, #currentArena.round.team);
		end
	end

	Debug:Log("UpdateRoundTeam", #currentArena.round.team);
end

function ArenaTracker:UpdateRoundTeam()
	-- TODO: Test if this even matters for correct spec fix...
	C_Timer.After(1, ArenaTracker.UpdateRoundTeam_Internal);
end


function ArenaTracker:RoundTeamContainsPlayer(playerName)
	if(not ArenaTracker:IsTrackingShuffle(true)) then
		return nil;
	end

	if(not playerName) then
		return nil;
	end

	local team;
	if(currentArena.lastRoundTeam and #currentArena.lastRoundTeam == 2) then
		team = currentArena.lastRoundTeam;
	else
		team = currentArena.round.team;
	end

	for _,teamMember in ipairs(team) do
		if(teamMember == playerName) then
			return true;
		end
	end

	return playerName == API:GetPlayerName();
end


function ArenaTracker:IsSameRoundTeam()
	if(not ArenaTracker:IsTrackingShuffle(true)) then
		return nil;
	end

	for i=1, 2 do
		local unitName = API:GetUnitFullName("party"..i);

		if(unitName and not ArenaTracker:RoundTeamContainsPlayer(unitName)) then
			return false;
		end
	end

	return true;
end


function ArenaTracker:GetShuffleOutcome()
	if(not currentArena.committedRounds) then
		return nil;
	end

	local roundWins = 0;
	if(currentArena.wins) then
		roundWins = currentArena.wins;
	else
		-- Iterate through all the rounds
		for _, round in ipairs(currentArena.committedRounds) do
			-- Check if firstDeath exists
			if(round.firstDeath) then
				for _, enemyPlayer in ipairs(round.enemy) do
					if enemyPlayer == round.firstDeath then
						roundWins = roundWins + 1;
						break;
					end
				end
			end
		end
	end

	currentArena.wins = tonumber(roundWins) or 0;

	if(currentArena.wins == 3) then
		-- Draw
		return 2;
	else
		return currentArena.wins > 3 and 1 or 0;
	end
end


function ArenaTracker:CheckRoundEnded()
	if(not API:IsInArena() or not ArenaTracker:IsTrackingShuffle()) then
		return;
	end

	if(not ArenaTracker:IsTrackingArena() or not currentArena.round.isInitiated) then
		Debug:Log("CheckRoundEnded called while not tracking arena, or without active shuffle round.", currentArena.round.isInitiated);
		return;
	end

	-- Check if this is a new round
	if(#currentArena.round.team ~= 2) then
		Debug:Log("CheckRoundEnded missing players.");
		return;
	end

	-- Team remains same, thus round has not changed.
	if(ArenaTracker:IsSameRoundTeam()) then
		Debug:Log("CheckRoundEnded has same team.");
		return;
	end

	ArenaTracker:HandleRoundEnd();
	return true;
end


-- Solo Shuffle specific round end
function ArenaTracker:HandleRoundEnd(force)
	if(not ArenaTracker:IsTrackingShuffle(true)) then
		return;
	end

	Debug:Log("HandleRoundEnd!", #currentArena.players);

	Inspection:Clear();
	ArenaTracker:CommitRound();
end


function ArenaTracker:CommitCurrentRound(force)
	if(not ArenaTracker:IsTrackingShuffle()) then
		return;
	end

	if(not currentArena.round.hasStarted) then
		return;
	end

	-- Delay commit until team has changed, unless match ended.
	if(not force and ArenaTracker:IsSameRoundTeam() and not API:GetWinner()) then
		Debug:LogGreen("Delaying round commit. Team has not yet changed.");
		return;
	end

	Debug:LogGreen("CommitCurrentRound triggered!")

	local startTime = currentArena.round.startTime;
	local death, endTime = ArenaTracker:GetFirstDeathFromCurrentArena();
	endTime = endTime or time();

	-- Get death stats, then wipe the deaths to avoid double counting
	ArenaTracker:CommitDeaths();

	local roundData = {
		duration = startTime and (endTime - startTime) or nil,
		firstDeath = death,
		team = TablePool:Acquire(),
		enemy = TablePool:Acquire(),
	};

	-- Get the total wins after current round
	local myWins, totalWins = ArenaTracker:GetCurrentWins();
	if(not myWins or not totalWins) then
		roundData.outcome = nil;
	elseif(myWins == currentArena.round.wins and totalWins == currentArena.round.totalWins) then
		Debug:LogGreen("Neither wins changed since last round. Assuming draw.");
		roundData.outcome = 2;
	else
		local isWin = (myWins > currentArena.round.wins);
		roundData.outcome = isWin and 1 or 0;
		Debug:LogGreen("Outcome determined:", roundData.outcome, "New wins:", myWins, totalWins, "Old wins:", currentArena.round.wins, currentArena.round.totalWins, "Rounds played:", #currentArena.committedRounds);
	end

	-- Fill round teams
	for _,player in ipairs(currentArena.players) do
		if(player and player.name) then
			if(API.hasSecrets) then
				if(ArenaTracker:RoundTeamContainsPlayer(player.name)) then
					tinsert(roundData.team, player.name);
				end
			else -- Non-secret logic (Fill enemies immediately)
				local team = ArenaTracker:RoundTeamContainsPlayer(player.name) and roundData.team or roundData.enemy;
				tinsert(team, player.name);
			end
		end
	end

	Debug:LogGreen("Committed round (DEPRECATED):", roundData.duration, roundData.firstDeath, #roundData.team, #roundData.enemy, #currentArena.players);
	tinsert(currentArena.committedRounds, roundData);


	-- @TODO: Move this for new shuffle flow
	-- Reset currentArena round data
	currentArena.deathData = TablePool:Acquire();

	-- Reset current round
	currentArena.round.team = TablePool:Acquire();
	currentArena.round.startTime = nil;
	currentArena.round.hasStarted = false;

	currentArena.round.wins = myWins;
	currentArena.round.totalWins = totalWins;

	-- Make sure we update the team, if we're not done playing.
	if(not API:GetWinner()) then
		Debug:LogGreen("Round commit forcing team update!");
		ArenaTracker:UpdateRoundTeam();
	end
end


local function FillRoundEnemyTeam(round, players, index)
	if(not round or not round.team) then
		Debug:Log("Shuffle round missing team:", index);
		return;
	end

	if(round.enemy and #round.enemy == 3) then
		Debug:Log("Already filled shuffle enemy team for round:", index);
		return;
	end

	TablePool:Release(round.enemy);
	round.enemy = TablePool:Acquire();

	for i,player in ipairs(players) do
		if(player.name and not ArenaTracker:RoundTeamContainsPlayer(player.name)) then
			tinsert(round.enemy, player.name);
		end
	end

	Debug:LogGreen("Filled shuffle round enemies:", index, #round.enemy);
end

-- Update committed rounds
function ArenaTracker:UpdateRoundEnemyTeams()
	if(not ArenaTracker:IsShuffle()) then
		return;
	end

    if(not currentArena.players or #currentArena.players < 6) then
		Debug:Log("Missing players from shuffles match. Total players:", currentArena.players and #currentArena.players)
        return;
    end

	for i,round in ipairs(currentArena.committedRounds) do
		FillRoundEnemyTeam(round, currentArena.players, i);
	end
end

-------------------------------------------------------------------------
--- Midnight Refactoring WIP
--- @TODO: Complete and replace with the following


function ArenaTracker:ResetShuffleRounds()
	currentArena.round = TablePool:Acquire();
	currentArena.round.team = TablePool:Acquire();
	currentArena.round.hasStarted = nil;
	currentArena.round.startTime = nil;
	currentArena.wins = nil;
end


function ArenaTracker:ResetShuffleWins()
	currentArena.shuffleWinsCache = currentArena.shuffleWinsCache or {};
	wipe(currentArena.shuffleWinsCache);

	local cache = currentArena.shuffleWinsCache;
	cache.wins = 0;
	cache.total = 0;

	cache.estimatedRound = 0;
	cache.drawCount = 0;

	cache.winsDelta = nil;
	cache.totalDelta = nil;

	cache.committedTotal = nil;
end


function ArenaTracker:TryUpdateCurrentShuffleWins()
	if(not ArenaTracker:IsTrackingShuffle(true)) then
		return;
	end

	-- Update the wins cache during match states: PostRound or Completed
	local matchState = API:GetActiveMatchState();
	if(matchState ~= 4 and matchState ~= 5) then
		return;
	end

	local newCache = TablePool:Acquire();
	newCache.wins = 0;
	newCache.total = 0;

	if(not currentArena.shuffleWinsCache) then
		return;
	end


	local hasAnyScores = false;
	local myWins, totalWins = 0,0;

	for i=1, API:GetNumBattlefieldScores() do
		local score = API:GetPlayerScore(i);
		if(score and API:IsValidValue(score.wins)) then
			hasAnyScores = true;

			if(API:IsValidValue(score.name)) then
				if(API:IsValidValue(currentArena.playerName) and score.name == currentArena.playerName) then
					newCache.wins = score.wins;
					currentArena.wins = score.wins;
				end

				newCache[score.name] = score.wins;
			end

			newCache.total = newCache.total + score.wins;
		end
	end

	if(hasAnyScores) then
		Debug:LogGreen("TryUpdateCurrentShuffleWins:", myWins, totalWins);
		local cache = currentArena.shuffleWinsCache;

		newCache.winsDelta = newCache.wins - cache.wins;
		newCache.totalDelta = newCache.total - cache.total;

		if(newCache.totalDelta >= 0) then
			currentArena.shuffleWinsCache = newCache;
		end
	end
end


function ArenaTracker:GetCurrentShuffleWins()
	-- Get wins and total from wins cache
	local cache = currentArena.shuffleWinsCache;
	if(not cache) then
		return nil, nil;
	end

	return cache.wins, cache.total;
end


function ArenaTracker:UpdateLastRoundTeam()
	if(not ArenaTracker:IsTrackingShuffle()) then
		return;
	end

	if(ArenaTracker:IsSameRoundTeam()) then
		Debug:Log("Still same team, round team update delayed.");
		return;
	end

	currentArena.round.team = TablePool:Acquire();

	for i=1, 2 do
		local fullname = API:GetUnitFullName("party"..i);
		if(API:IsValidValue(fullname)) then
			tinsert(currentArena.round.team, fullname);
			Debug:Log("Adding team player:", fullname, #currentArena.round.team);
		end
	end

	currentArena.lastRoundTeam = currentArena.round.team;
	Debug:LogGreen("UpdateRoundTeam", #currentArena.round.team);
end


function ArenaTracker:HasRoundInitiated()
	return currentArena.round.isInitiated;
end


function ArenaTracker:InitiateRound()
	if(not ArenaTracker:IsTrackingShuffle()) then
		return;
	end

	-- Try Commit previous round
	ArenaTracker:CommitRound();

	ArenaTracker:UpdateRoundTeam();

	Debug:LogGreen("ArenaTracker:InitiateRound() triggered!");
	local myWins, totalWins = ArenaTracker:GetCurrentShuffleWins();
	currentArena.round.wins = myWins;
	currentArena.round.totalWins = totalWins;

	Debug:LogGreen("Initiated round!", #currentArena.committedRounds, myWins, totalWins);

	ArenaTracker:UpdateLastRoundTeam();
	currentArena.round.isInitiated = true;

	ArenaTracker:CheckHasGatesOpened();
end


local function GetRoundOutcome()
	-- TODO: Implement
	local winsCache = currentArena.shuffleWinsCache or {};

	if(not winsCache.totalDelta or winsCache.totalDelta > 3) then
		-- We missed a round, unknown outcome
		return nil;
	end

	if(not winsCache.winsDelta or winsCache.winsDelta > 1) then
		-- We missed a round, unknown outcome
		return nil;
	end

	if(winsCache.totalDelta == 0) then
		return 2;
	else
		local isWin = (winsCache.winsDelta == 1);
		return isWin and 1 or 0;
	end
end


local function FillRoundTeams(roundData)
	-- Fill round teams
	for _,player in ipairs(currentArena.players) do
		if(API:IsValidValue(player.name)) then
			-- Non-secret logic (Fill enemies immediately)
			local isTeamMember = ArenaTracker:RoundTeamContainsPlayer(player.name);
			local team = isTeamMember and roundData.team or roundData.enemy;
			tinsert(team, player.name);
			Debug:LogGreen("Added player to team. isTeamMember:", isTeamMember, player.name, Internal:GetClassAndSpec(player.spec));
		end
	end
end


local isCommittingRound = false;
function ArenaTracker:CommitRound()
	if(not ArenaTracker:IsTrackingShuffle()) then
		return;
	end

	if(isCommittingRound or not ArenaTracker:HasRoundInitiated()) then
		return;
	end
	isCommittingRound = true;

	ArenaTracker:TryUpdateCurrentShuffleWins();
	ArenaTracker:UpdatePlayersFromScoreboard();

	local matchState = API:GetActiveMatchState();
	local winsCache = currentArena.shuffleWinsCache or {};

	local startTime = currentArena.round.startTime;
	local death, endTime = ArenaTracker:GetFirstDeathFromCurrentArena();
	endTime = endTime or time();

	ArenaTracker:CommitDeaths();

	-- Processed round to commit
	local roundData = {
		duration = startTime and (endTime - startTime) or nil,
		firstDeath = death,
		team = TablePool:Acquire(),
		enemy = TablePool:Acquire(),
	};

	FillRoundTeams(roundData);

	-- Outcome
	if(matchState >= 4) then
		roundData.outcome = GetRoundOutcome();
	end

	-- Update committed total
	winsCache.committedTotal = winsCache.total;

	-- Store committed round
	Debug:LogGreen("Committed round:", roundData.duration, roundData.firstDeath, #roundData.team, #roundData.enemy, #currentArena.players, winsCache.wins, winsCache.total);
	tinsert(currentArena.committedRounds, roundData);

	-- Reset for next round
	ArenaTracker:ResetRound();

	isCommittingRound = false;
end


function ArenaTracker:ResetRound()
	-- Reset currentArena round data
	currentArena.deathData = TablePool:Acquire();

	-- Reset current round
	currentArena.round.team = TablePool:Acquire();
	currentArena.round.startTime = nil;
	currentArena.round.hasStarted = false;

	local myWins, totalWins = ArenaTracker:GetCurrentShuffleWins();
	currentArena.round.wins = myWins;
	currentArena.round.totalWins = totalWins;

	currentArena.round.isInitiated = false;
end