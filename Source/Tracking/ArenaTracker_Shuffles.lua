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

-------------------------------------------------------------------------
-- Solo Shuffle module for ArenaTracker

-- Get current player wins and all players summed wins
function ArenaTracker:GetCurrentWins()
    local currentArena = ArenaTracker:GetCurrentArena();
	if(not currentArena or not currentArena.isShuffle) then
		return;
	end

	local myWins, totalWins = 0,0;
	for i=1, GetNumBattlefieldScores() do
		local score = API:GetPlayerScore(i);
		if(score and score.wins) then
			if(score.name == currentArena.playerName) then
				myWins = score.wins;
			end

			totalWins = totalWins + score.wins;
		end
	end

	return myWins, totalWins;
end

function ArenaTracker:UpdateRoundTeam()
    local currentArena = ArenaTracker:GetCurrentArena();
	if(not currentArena or not currentArena.isShuffle) then
		return;
	end

	if(ArenaTracker:IsSameRoundTeam()) then
		ArenaAnalytics:Log("Still same team, round team update delayed.");
		return;
	end

	TablePool:Release(currentArena.round.team)
	currentArena.round.team = TablePool:Acquire();
	for i=1, 2 do
		local name = Helpers:GetUnitFullName("party"..i);
		tinsert(currentArena.round.team, name);
		ArenaAnalytics:Log("Adding team player:", name, #currentArena.round.team);
	end

	ArenaAnalytics:Log("UpdateRoundTeam", #currentArena.round.team);
end

function ArenaTracker:RoundTeamContainsPlayer(playerName)
	local currentArena = ArenaTracker:GetCurrentArena();
	if(not currentArena or not currentArena.isShuffle) then
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
	local currentArena = ArenaTracker:GetCurrentArena();
	if(not currentArena or not currentArena.isShuffle) then
		return nil;
	end

	for i=1, 2 do
		local unitToken = "party"..i;
		local unitName = Helpers:GetUnitFullName(unitToken);

		if(unitName and not ArenaTracker:RoundTeamContainsPlayer(unitName)) then
			return false;
		end
	end

	return true;
end

function ArenaTracker:CommitCurrentRound(force)
	local currentArena = ArenaTracker:GetCurrentArena();
	if(not currentArena or not currentArena.isShuffle) then
		return;
	end

	if(not currentArena.round.hasStarted) then
		return;
	end

	ArenaAnalytics:LogGreen("CommitCurrentRound triggered!")

	-- Delay commit until team has changed, unless match ended.
	if(not force and ArenaTracker:IsSameRoundTeam() and not GetBattlefieldWinner()) then
		ArenaAnalytics:LogGreen("Delaying round commit. Team has not yet changed.");
		return;
	end

	local startTime = currentArena.round.startTime;
	local death, endTime = ArenaTracker:GetFirstDeathFromCurrentArena();
	endTime = endTime or time();

	-- Get death stats, then wipe the deaths to avoid double counting
	ArenaTracker:CommitDeaths();
	wipe(currentArena.deathData);

	local roundData = {
		duration = startTime and (endTime - startTime) or nil,
		firstDeath = death,
		team = {},
		enemy = {},
	};

	-- Get the total wins after current round
	local myWins, totalWins = ArenaTracker:GetCurrentWins();
	if(myWins == currentArena.round.wins and totalWins == currentArena.round.totalWins) then
		ArenaAnalytics:LogGreen("Neither wins changed since last round. Assuming draw.");
		roundData.outcome = 2;
	else
		local isWin = (myWins > currentArena.round.wins);
		roundData.outcome = isWin and 1 or 0;
		ArenaAnalytics:LogGreen("Outcome determined:", roundData.outcome, "New wins:", myWins, totalWins, "Old wins:", currentArena.round.wins, currentArena.round.totalWins, "Rounds played:", #currentArena.committedRounds);
	end

	-- Fill round teams
	for _,player in ipairs(currentArena.players) do
		if(player and player.name) then
			local team = ArenaTracker:RoundTeamContainsPlayer(player.name) and roundData.team or roundData.enemy;
			tinsert(team, player.name);
		end
	end

	ArenaAnalytics:LogGreen("Committed round:!", roundData.duration, roundData.firstDeath, #roundData.team, #roundData.enemy, #currentArena.players);
	tinsert(currentArena.committedRounds, roundData);

	-- Reset currentArena round data
	currentArena.deathData = TablePool:Acquire();

	-- Reset current round
	currentArena.round.team = {};
	currentArena.round.startTime = nil;
	currentArena.round.hasStarted = false;

	currentArena.round.wins = myWins;
	currentArena.round.totalWins = totalWins;

	-- Make sure we update the team, if we're not done playing.
	if(not GetBattlefieldWinner()) then
		ArenaAnalytics:LogGreen("Round commit forcing team update!");
		ArenaTracker:UpdateRoundTeam();
	end
end

function ArenaTracker:CheckRoundEnded()
    if(not API:IsInArena()) then
        return;
    end

	local currentArena = ArenaTracker:GetCurrentArena();
	if(not currentArena or not currentArena.isShuffle) then
		return;
	end

	if(not ArenaTracker:IsTracking() or not currentArena.round.hasStarted) then
		ArenaAnalytics:Log("CheckRoundEnded called while not tracking arena, or without active shuffle round.", currentArena.round.hasStarted);
		return;
	end
	
	-- Check if this is a new round
	if(#currentArena.round.team ~= 2) then
		ArenaAnalytics:Log("CheckRoundEnded missing players.");
		return;
	end
	
	-- Team remains same, thus round has not changed.
	if(ArenaTracker:IsSameRoundTeam()) then
		ArenaAnalytics:Log("CheckRoundEnded has same team.");
		return;
	end

	ArenaAnalytics:Log("CheckRoundEnded");
	ArenaTracker:HandleRoundEnd();
end

-- Solo Shuffle specific round end
function ArenaTracker:HandleRoundEnd(force)
    if(not API:IsInArena()) then
        return;
    end

	local currentArena = ArenaTracker:GetCurrentArena();
	if(not currentArena or not currentArena.isShuffle) then
		return;
	end

	ArenaAnalytics:Log("HandleRoundEnd!", #currentArena.players);

	ArenaTracker:CommitCurrentRound(force);
end

function ArenaTracker:GetShuffleOutcome()
	local currentArena = ArenaTracker:GetCurrentArena();
	if(not currentArena or not currentArena.isShuffle) then
		return;
	end

	if(currentArena.committedRounds) then
		local wins = 0;

        -- Iterate through all the rounds
        for _, round in ipairs(currentArena.committedRounds) do
            -- Check if firstDeath exists
            if(round.firstDeath) then
                for _, enemyPlayer in ipairs(round.enemy) do
                    if enemyPlayer == round.firstDeath then
                        wins = wins + 1;
						break;
                    end
                end
            end
        end

        if(wins == 3) then
			-- Draw
			return 2; 
		else
			return wins > 3 and 1 or 0;
		end
	end

	return nil;
end