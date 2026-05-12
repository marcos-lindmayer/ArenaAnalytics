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
-- Responsible for resolving wins for incomplete rounds
-------------------------------------------------------------------------

local currentArena = {};
function ArenaTracker:InitializeSubmodule_ShuffleResolver()
    currentArena = ArenaAnalyticsTransientDB.currentArena;
end

-------------------------------------------------------------------------

local rounds = {};
local finalScore = nil;

local outcomes = Constants.outcomes;

local outcomes_char = {
	[0] = "L",
	[1] = "W",
	[2] = "D",
};

local outcomes_number = {
	["L"] = 0,
	["W"] = 1,
	["D"] = 2,
};

local function GetNumberOutcome(value)
	if(not value) then return end;
	return (outcomes_char[value] ~= nil) and value or outcomes_number[value];
end

local function CheckScore(score)
	if(not score or not finalScore) then
		return nil;
	end

	for key,wins in pairs(finalScore) do
		if(key ~= "wins" and score[key] ~= finalScore[key]) then
			return false;
		end
	end

	return true;
end

local function IsPlayerInTeam(team, fullname)
	if(type(team) ~= "table" or not fullname) then
		return false;
	end

	for i,playerName in ipairs(team) do
		if(playerName == fullname) then
			return true;
		end
	end
	return false;
end

local function AddRound(committedRound)
	if(not committedRound or #committedRound.team ~= 3 or #committedRound.enemy ~= 3) then
		Debug:LogWarning("Shuffle resolver received invalid committed round found.");
		return;
	end

	local newRound = {};

	-- Assign teams
	newRound.team = committedRound.team;
	newRound.enemy = committedRound.enemy;

	local firstDeath = nil;
	if(not committedRound.isHunterDeath) then
		firstDeath = committedRound.firstDeath;
	end

	local knownOutcome = GetNumberOutcome(committedRound.outcome);
	if(knownOutcome ~= nil) then
		newRound.possibleOutcomes = { knownOutcome };
	elseif(firstDeath) then
		if(IsPlayerInTeam(newRound.team, firstDeath)) then
			newRound.possibleOutcomes = { outcomes.draw, outcomes.loss };
		elseif(IsPlayerInTeam(newRound.enemy, firstDeath)) then
			newRound.possibleOutcomes = { outcomes.draw, outcomes.win };
		else
			newRound.possibleOutcomes = { outcomes.draw, outcomes.win, outcomes.loss };
		end
	else
		newRound.possibleOutcomes = { outcomes.draw, outcomes.win, outcomes.loss };
	end

	tinsert(rounds, newRound);
end

local function AddScore(scoreData, round, outcome)
    local team = nil;
    if outcome == outcomes.win then
        team = round.team;
    elseif outcome == outcomes.loss then
        team = round.enemy;
    end

    if not team then
        return;
    end

    scoreData.total = (scoreData.total or 0) + 3;

    for _, fullname in ipairs(team) do
        if fullname then
            scoreData[fullname] = (scoreData[fullname] or 0) + 1;
        end
    end
end

local function AddScoresRecursive(output, scoreData, roundIndex)
	roundIndex = roundIndex or 1;
	scoreData = scoreData or { outcomes = {} };

    local round = rounds[roundIndex];
    if round then
		for _, outcome in ipairs(round.possibleOutcomes) do
			local branchData = Helpers:DeepCopy(scoreData);
			AddScore(branchData, round, outcome);
			branchData.outcomes[roundIndex] = outcome;
			AddScoresRecursive(output, branchData, roundIndex + 1);
		end
	else
        -- All rounds processed: compare against known score
        if CheckScore(scoreData) then
            tinsert(output, Helpers:DeepCopy(scoreData));
        end
    end
end

local function CommitKnownWins(matchedScores)
	assert(matchedScores);

	if(#matchedScores == 0) then
		-- No matching scores found
		Debug:LogWarning("ResolveShuffleOutcomes failed to find any possible outcome.");
		return;
	end

	Debug:LogGreen("Shuffle resolver committing outcomes from: #" .. #matchedScores, "scores.");

	-- Assign outcomes that are shared in all possible matched scores.
	for roundIndex=1, 6 do
		local outcome = nil;
		for i,score in ipairs(matchedScores) do
			local newOutcome = score.outcomes[roundIndex];
			if(outcome == nil) then
				outcome = newOutcome;
			elseif(outcome ~= newOutcome) then
				outcome = nil;
				break;
			end
		end

		if(outcome) then
			-- Commit outcome to round
			local round = currentArena.committedRounds[roundIndex];
			if(round) then
				Debug:LogPurple("   Resolving outcome for round:", roundIndex, outcome, round.outcome, round.firstDeath);
				round.outcome = round.outcome or outcome;
			end
		else
			Debug:Log("   Failed to find outcome for round:", roundIndex);
		end
	end
end


local function GetWinsCache()
	local cache = { total = 0 };

	for i,player in ipairs(currentArena.players) do
		local wins = tonumber(player.wins);
		if(wins) then
			cache[player.name] = wins;
			cache.total = cache.total + wins;
		end
	end

	Debug:Log("New computed wins cache:");
	Debug:LogTable(cache);

	return cache;
end


function ArenaTracker:ResolveShuffleOutcomes()
	if(not ArenaTracker:IsTrackingShuffle(true)) then
		Debug:Log("ResolveShuffleOutcomes rejected: No shuffle tracking.");
		return;
	end

	local winsCache = GetWinsCache();
	if(not winsCache) then
		-- No scores to resolve outcomes for
		Debug:Log("ResolveShuffleOutcomes rejected: No scores.");
		return;
	end

	wipe(rounds);
	finalScore = winsCache;

	-- Add committed rounds
	if(currentArena.committedRounds) then
		for _,round in ipairs(currentArena.committedRounds) do
			if(round) then
				AddRound(round);
			end
		end
	end

	if(#rounds == 6) then
		local matchedScores = {};
		AddScoresRecursive(matchedScores);
		CommitKnownWins(matchedScores);
	else
		Debug:LogWarning("ResolveShuffleOutcomes missing rounds. #" .. #rounds);
	end

	wipe(rounds);
	finalScore = nil;
end