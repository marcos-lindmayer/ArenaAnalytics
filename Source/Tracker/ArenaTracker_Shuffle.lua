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

	local myWins, totalWins = 0,0;
	for i=1, GetNumBattlefieldScores() do
		local score = API:GetPlayerScore(i);
		if(score and API:IsValidValue(score.wins)) then
			if(API:IsValidValue(score.name) and API:IsValidValue(currentArena.playerName)) then
				if(score.name == currentArena.playerName) then
					myWins = score.wins;
					currentArena.wins = score.wins;
				end
			end

			totalWins = totalWins + score.wins;
		end
	end

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

	TablePool:Release(currentArena.round.team);
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


function ArenaTracker:RoundTeamContainsPlayer(playerName, team)
	if(not ArenaTracker:IsTrackingShuffle(true)) then
		return nil;
	end

	if(not playerName) then
		return nil;
	end

	team = type(team) == "table" and team or currentArena.round.team;

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

	if(not ArenaTracker:IsTrackingArena() or not currentArena.round.hasStarted) then
		Debug:Log("CheckRoundEnded called while not tracking arena, or without active shuffle round.", currentArena.round.hasStarted);
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

	Debug:Log("CheckRoundEnded");
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
	ArenaTracker:CommitCurrentRound(force);
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
	if(myWins == currentArena.round.wins and totalWins == currentArena.round.totalWins) then
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

	Debug:LogGreen("Committed round:!", roundData.duration, roundData.firstDeath, #roundData.team, #roundData.enemy, #currentArena.players);
	tinsert(currentArena.committedRounds, roundData);

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
		return;
	end

	if(round.enemy and #round.enemy == 3) then
		return;
	end

	TablePool:Release(round.enemy);
	round.enemy = TablePool:Acquire();

	for i,player in ipairs(players) do
		if(player.name and not ArenaTracker:RoundTeamContainsPlayer(player.name, round.team)) then
			tinsert(round.enemy, player.name);
		end
	end

	Debug:LogGreen("Filled round enemies:", index, #round.enemy);
end

-- Update committed rounds
function ArenaTracker:UpdateRoundEnemyTeams()
	if(not ArenaTracker:IsShuffle()) then
		return;
	end

    if(not currentArena.players) then
        return;
    end

	for i,round in ipairs(currentArena.committedRounds) do
		FillRoundEnemyTeam(round, currentArena.players, i);
	end
end
