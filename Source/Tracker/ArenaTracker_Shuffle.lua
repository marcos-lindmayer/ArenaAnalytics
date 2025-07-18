local _, ArenaAnalytics = ... -- Namespace
local ArenaTracker = ArenaAnalytics.ArenaTracker;

-- Local module aliases
local AAmatch = ArenaAnalytics.AAmatch;
local Constants = ArenaAnalytics.Constants;
local SpecSpells = ArenaAnalytics.SpecSpells;
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
		if(score and score.wins) then
			if(currentArena.playerName and score.name == currentArena.playerName) then
				myWins = score.wins;
			end

			totalWins = totalWins + score.wins;
		end
	end

	return myWins, totalWins;
end


function ArenaTracker:UpdateRoundTeam()
	if(not ArenaTracker:IsTrackingShuffle()) then
		return;
	end

	if(ArenaTracker:IsSameRoundTeam()) then
		Debug:Log("Still same team, round team update delayed.");
		return;
	end

	wipe(currentArena.round.team)
	currentArena.round.team = TablePool:Acquire();
	for i=1, 2 do
		local name = Helpers:GetUnitFullName("party"..i);
		if(name) then
			tinsert(currentArena.round.team, name);
			Debug:Log("Adding team player:", name, #currentArena.round.team);
		end
	end

	Debug:Log("UpdateRoundTeam", #currentArena.round.team);
end


function ArenaTracker:RoundTeamContainsPlayer(playerName)
	if(not ArenaTracker:IsTrackingShuffle(true)) then
		return;
	end

	if(not playerName) then
		return nil;
	end

	for _,teamMember in ipairs(currentArena.round.team) do
		if(teamMember == playerName) then
			return true;
		end
	end

	return playerName == Helpers:GetPlayerName();
end


function ArenaTracker:IsSameRoundTeam()
	if(not ArenaTracker:IsTrackingShuffle(true)) then
		return nil;
	end

	for i=1, 2 do
		local unitName = Helpers:GetUnitFullName("party"..i);

		if(unitName and not ArenaTracker:RoundTeamContainsPlayer(unitName)) then
			return false;
		end
	end

	return true;
end


function ArenaTracker:GetShuffleOutcome()
	if(currentArena.committedRounds) then
		local roundWins = 0;

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

        if(roundWins == 3) then
			-- Draw
			return 2;
		else
			return roundWins > 3 and 1 or 0;
		end
	end

	return nil;
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
end


-- Solo Shuffle specific round end
function ArenaTracker:HandleRoundEnd(force)
	if(not ArenaTracker:IsTrackingShuffle(true)) then
		return;
	end

	Debug:Log("HandleRoundEnd!", #currentArena.players);

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
			local team = ArenaTracker:RoundTeamContainsPlayer(player.name) and roundData.team or roundData.enemy;
			tinsert(team, player.name);
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
