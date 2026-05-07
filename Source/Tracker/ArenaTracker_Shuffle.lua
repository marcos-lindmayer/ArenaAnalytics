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
local currentRound = {};
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

	Debug:LogPurple("Current Wins:", myWins, totalWins);
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

	Inspection:Clear();

	currentRound.team = TablePool:Acquire();

	Debug:LogGreen("UpdateRoundTeam filling team:");
	for i=1, 2 do
		local name = API:GetUnitFullName("party"..i);
		if(name) then
			tinsert(currentRound.team, name);
			Debug:Log("   Adding team player:", name, #currentRound.team);
		end
	end

	Debug:Log("   Team Player Count:", #currentRound.team);

	ArenaTracker:RequestPartySpecs();

	currentArena.lastRoundTeam = currentRound.team;
end


function ArenaTracker:RoundTeamContainsPlayer(fullname)
	if(not ArenaTracker:IsTrackingShuffle(true)) then
		return nil;
	end

	if(not fullname) then
		return nil;
	end

	for _,teamMember in ipairs(currentArena.lastRoundTeam) do
		if(teamMember == fullname) then
			return true;
		end
	end

	return fullname == API:GetPlayerFullName();
end


function ArenaTracker:IsSameRoundTeam()
	if(not ArenaTracker:IsTrackingShuffle(true)) then
		return nil;
	end

	for i=1, 2 do
		local fullname = API:GetUnitFullName("party"..i);
		if(fullname and not ArenaTracker:RoundTeamContainsPlayer(fullname)) then
			return false;
		end
	end

	return true;
end


function ArenaTracker:HasFullTeam(isLastTeamCheck)
	-- Assume player always exists, first two party members must exist, and nothing beyond this for shuffles
	return UnitExists("party1") and UnitExists("party2") and not UnitExists("party3");
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


function ArenaTracker:CommitCurrentRound_DEPRECATED(force)
	if(not ArenaTracker:IsTrackingShuffle()) then
		return;
	end

	if(not currentRound.hasStarted) then
		return;
	end

	-- Delay commit until team has changed, unless match ended.
	if(not force and ArenaTracker:IsSameRoundTeam() and not API:GetWinner()) then
		Debug:LogGreen("Delaying round commit. Team has not yet changed.");
		return;
	end

	Debug:LogGreen("CommitCurrentRound_DEPRECATED triggered!")

	local startTime = currentRound.startTime;
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
	elseif(myWins == currentRound.wins and totalWins == currentRound.totalWins) then
		Debug:LogGreen("Neither wins changed since last round. Assuming draw.");
		roundData.outcome = 2;
	else
		local isWin = (myWins > currentRound.wins);
		roundData.outcome = isWin and 1 or 0;
		Debug:LogGreen("Outcome determined:", roundData.outcome, "New wins:", myWins, totalWins, "Old wins:", currentRound.wins, currentRound.totalWins, "Rounds played:", #currentArena.committedRounds);
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
	currentRound.team = TablePool:Acquire();
	currentRound.startTime = nil;
	currentRound.hasStarted = false;

	currentRound.wins = myWins;
	currentRound.totalWins = totalWins;

	-- Make sure we update the team, if we're not done playing.
	if(not API:GetWinner()) then
		Debug:LogGreen("Round commit forcing team update!");
		ArenaTracker:UpdateRoundTeam();
	end
end


local function FillRoundEnemyTeam(round, players, index)
	if(not round or not round.team) then
		Debug:Log("   Shuffle round missing team:", index);
		return;
	end

	round.enemy = round.enemy or TablePool:Acquire();
	if(#round.enemy == 3) then
		return;
	end

	wipe(round.enemy);

	local function IsTeamPlayer(fullname)
		for _,teamMember in ipairs(round.team) do
			if(teamMember == fullname) then
				return true;
			end
		end

		return fullname == API:GetPlayerFullName();
	end

	for i,player in ipairs(players) do
		if(player.name and not IsTeamPlayer(player.name)) then
			tinsert(round.enemy, player.name);
		end
	end

	Debug:LogPurple("   Filled shuffle round enemies:", index, #round.enemy);
end


-- Update committed rounds
function ArenaTracker:UpdateRoundEnemyTeams()
	if(not ArenaTracker:IsTrackingShuffle(true)) then
		return;
	end

	Debug:LogGreen("UpdateRoundEnemyTeams processing..");

    if(not currentArena.players or #currentArena.players < 6) then
		Debug:Log("   Missing players from shuffles match. Total players:", currentArena.players and #currentArena.players)
        return;
    end

	for i,round in ipairs(currentArena.committedRounds) do
		FillRoundEnemyTeam(round, currentArena.players, i);
	end
end

-------------------------------------------------------------------------
--- Midnight Refactoring WIP
--- @TODO: Complete and replace with the following

function ArenaTracker:GetScoreboardWinsCache()
	local newCache = TablePool:Acquire();
	newCache.wins = 0;
	newCache.total = 0;

	local hasAnyScores = false;

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

	return newCache, hasAnyScores;
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

	local newCache, hasAnyScores = ArenaTracker:GetScoreboardWinsCache();

	if(not currentArena.shuffleWinsCache) then
		ArenaTracker:ResetShuffleWins();
	end

	if(hasAnyScores) then
		Debug:LogPurple("TryUpdateCurrentShuffleWins:", newCache.wins, newCache.total);
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


function ArenaTracker:HasRoundInitiated()
	return currentRound.isInitiated;
end


function ArenaTracker:CheckShufflePartyChanged()
	if(not ArenaTracker:HasFullTeam()) then
		return
	end

	ArenaTracker:CheckRoundState()
end


function ArenaTracker:CheckRoundState(isScoreEvent)
	if(not API:IsInArena() or not ArenaTracker:IsTrackingShuffle()) then
		return;
	end

	local isSameTeam = ArenaTracker:IsSameRoundTeam();

	local state = API:GetActiveMatchState();
	local lastState = ArenaTracker:GetMatchState();

	-- PostRound or Completed
	if(state >= 4) then
		Inspection:Clear();
	end

	if(not isSameTeam) then
		ArenaTracker:HandleRoundEnd();
	end

	-- Try open the gates, state >= 3
	ArenaTracker:CheckHasGatesOpened()

	ArenaTracker:AssignShuffleWinsCache(isScoreEvent);
end


-- Pre-initiate round check?
function ArenaTracker:CheckRoundEnded_Deprecated()
	if(not API:IsInArena() or not ArenaTracker:IsTrackingShuffle()) then
		return;
	end

	if(not ArenaTracker:IsTrackingArena() or not currentRound.isInitiated) then
		Debug:Log("CheckRoundEnded called while not tracking arena, or without active shuffle round.", currentRound.isInitiated);
		return;
	end

	-- Check if this is a new round
	if(#currentRound.team ~= 2) then
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
local roundEndLock = nil
function ArenaTracker:HandleRoundEnd(force)
	if(not ArenaTracker:IsTrackingShuffle(true)) then
		return;
	end

	if(roundEndLock) then
		return
	end
	roundEndLock = true

	Debug:LogGreen("HandleRoundEnd!", #currentArena.players);

	Inspection:Clear();
	ArenaTracker:CommitRound();
	ArenaTracker:InitiateRound();

	roundEndLock = nil
end


function ArenaTracker:CanInitiate()
	if(not ArenaTracker:IsTrackingShuffle()) then
		return;
	end

	return true;
end


function ArenaTracker:InitiateRound()
	if(not API:IsInArena() or not ArenaTracker:IsTrackingShuffle()) then
		return nil;
	end

	if(not ArenaTracker:HasFullTeam()) then
		return false
	end

	if(ArenaTracker:IsSameRoundTeam()) then
		return false;
	end

	Inspection:Clear();
	ArenaTracker:CommitRound();

	if(ArenaTracker:HasRoundInitiated()) then
		return false;
	end

	ArenaTracker:FillMissingPlayers();
	ArenaTracker:UpdateRoundTeam();

	local myWins, totalWins = ArenaTracker:GetCurrentShuffleWins();
	currentRound.wins = myWins;
	currentRound.totalWins = totalWins;

	Debug:LogGreen("Initiated round!", #currentArena.committedRounds, myWins, totalWins);

	currentRound.isInitiated = true;

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
	Debug:LogGreen("Filling Round Teams..");

	-- Fill round teams
	for _,player in ipairs(currentArena.players) do
		if(API:IsValidValue(player.name)) then
			-- Non-secret logic (Fill enemies immediately)
			local isTeamMember = ArenaTracker:RoundTeamContainsPlayer(player.name);
			local team = isTeamMember and roundData.team or roundData.enemy;
			tinsert(team, player.name);
			Debug:LogPurple("   Added player to team. isTeamMember:", isTeamMember, player.name, Internal:GetClassAndSpec(player.spec));
		end
	end

	Debug:Log("   Round Players:", #currentArena.players, "Team:", #roundData.team, "Enemy:", #roundData.enemy);
end


local isCommittingRound = false;
function ArenaTracker:CommitRound()
	if(not ArenaTracker:IsTrackingShuffle(true)) then
		return;
	end

	if(isCommittingRound or not ArenaTracker:HasRoundInitiated()) then
		return;
	end
	isCommittingRound = true;

	Inspection:Clear();

	local matchState = API:GetActiveMatchState();

	local startTime = currentRound.startTime;
	local death, endTime, isHunter = ArenaTracker:GetFirstDeathFromCurrentArena();
	endTime = endTime or time();

	ArenaTracker:CommitDeaths();

	-- Processed round to commit
	local roundData = {
		duration = startTime and (endTime - startTime) or nil,
		firstDeath = death,
		isHunterDeath = isHunter,
		team = TablePool:Acquire(),
		enemy = TablePool:Acquire(),
	};

	FillRoundTeams(roundData);

	-- Outcome
	if(matchState >= 4) then
		roundData.outcome = GetRoundOutcome();
	end

	-- Store committed round
	Debug:LogGreen("Committed round:", #currentArena.committedRounds, "duration:", roundData.duration, "death:", roundData.firstDeath, "teams:", #roundData.team, #roundData.enemy, "/", #currentArena.players);
	tinsert(currentArena.committedRounds, roundData);

	-- Reset for next round
	ArenaTracker:ResetRound();

	isCommittingRound = false;
end


function ArenaTracker:AssignShuffleWinsCache(isScoreEvent)
	if(not ArenaTracker:HasRoundInitiated()) then
		return;
	end

	local state = API:GetActiveMatchState();
	local lastState = ArenaTracker:GetMatchState();

	-- nil = neither, true = new, false = old
	local shouldAssignNew = nil;

	if(state >= 4) then
		if(isScoreEvent) then
			-- assign as new
			shouldAssignNew = true;
		elseif(ArenaTracker.transientLoginDetection) then
			-- assign old
			shouldAssignNew = false;
		end
	elseif(isScoreEvent) then -- state <= 3
		-- assign old
		shouldAssignNew = false;
	end

	if(shouldAssignNew == nil) then
		return;
	end

	local cache, hasAnyScores = ArenaTracker:GetScoreboardWinsCache();
	if(not hasAnyScores) then
		return;
	end

	if(shouldAssignNew) then
		currentRound.oldWinsCache = cache;
	else
		currentRound.newWinsCache = cache;
	end

	currentArena.latestWinsCache = cache;
end


function ArenaTracker:ResetRound()
	currentArena.round = currentArena.round or {};
	currentRound = currentArena.round;

	-- Reset currentArena round data
	currentArena.deathData = TablePool:Acquire();

	-- Reset current round
	currentRound.team = TablePool:Acquire();
	currentRound.enemy = TablePool:Acquire();
	currentRound.startTime = nil;
	currentRound.hasStarted = nil;

	local myWins, totalWins = ArenaTracker:GetCurrentShuffleWins();
	currentRound.wins = myWins;
	currentRound.totalWins = totalWins;

	currentRound.isInitiated = false;
end


function ArenaTracker:ResetShuffleWins()
	currentArena.wins = nil;

	currentArena.shuffleWinsCache = currentArena.shuffleWinsCache or {};
	wipe(currentArena.shuffleWinsCache);

	local cache = currentArena.shuffleWinsCache;
	cache.wins = 0;
	cache.total = 0;

	cache.estimatedRound = 0;
	cache.drawCount = 0;

	cache.winsDelta = nil;
	cache.totalDelta = nil;
end


function ArenaTracker:ResetShuffleData()
	ArenaTracker:ResetRound();
	ArenaTracker:ResetShuffleWins();

	currentArena.lastRoundTeam = TablePool:Acquire();
	currentArena.committedRounds = TablePool:Acquire();
end
