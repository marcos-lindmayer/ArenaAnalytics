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

local outcomes = {
	loss = 0,
	win = 1,
	draw = 2,
}

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


local function AddRound(committedRound)
	if(not committedRound or #committedRound.team ~= 3 or #committedRound.enemy ~= 3) then
		Debug:LogWarning("Shuffle resolver received invalid committed round found.");
		return;
	end

	local newRound = {};

	-- Assign teams
	newRound.team = committedRound.team;
	newRound.enemy = committedRound.enemy;

	local knownOutcome = GetNumberOutcome(committedRound.outcome);
	if(knownOutcome ~= nil) then
		newRound.possibleOutcomes = { knownOutcome };
	elseif(committedRound.hasPartyDeath) then -- Presume feign death excluded here?
		newRound.possibleOutcomes = { 0, 2 };
	else
		newRound.possibleOutcomes = { 0, 1, 2 };
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

    for _, player in ipairs(team) do
        if player and player.name then
            scoreData[player.name] = (scoreData[player.name] or 0) + 1;
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
				Debug:LogPurple("   Resolving outcome for round:", roundIndex, outcome, round.outcome);
				round.outcome = round.outcome or outcome;
			end
		else
			Debug:Log("   Failed to find outcome for round:", roundIndex);
		end
	end
end

function ArenaTracker:ResolveShuffleOutcomes(winsCache)
	if(not ArenaTracker:IsTrackingShuffle(true)) then
		return;
	end

	if(not winsCache) then
		-- No scores to resolve outcomes for
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




--@TODO: Remove the following:
-------------------------------------------------------------------------
--- Wins Resolver Tests

local duplicateScoreTable = {};
local scoreLookupCache = {};
local uniqueOutcomeTable = {};

local fixedRoundTeams = {
	[1] = {{1,2,3}, {4,5,6}},
	[2] = {{1,2,4}, {3,5,6}},
	[3] = {{1,2,5}, {3,4,6}},
	[4] = {{1,3,4}, {2,5,6}},
	[5] = {{1,3,5}, {2,4,6}},
	[6] = {{1,4,5}, {2,3,6}},
};

local maxDraws = 2;
local unknownRounds = 6;

local function CountDraws(scoreKey)
	local count = 0;
	for i=1, #scoreKey do
		local outcome = tonumber(string.sub(scoreKey, i, i));
		if(outcome == 0) then
			count = count + 1;
		end
	end
	return count;
end

local function FindOrAddLookupScore(scoreKey, outcome)
	assert(outcome and uniqueOutcomeTable[outcome] == nil, "Attempting to add an already existing outcome to scoreLookupCache.");

	scoreLookupCache[scoreKey] = scoreLookupCache[scoreKey] or {};
	local scoreTable = scoreLookupCache[scoreKey];

	scoreTable.count = scoreTable.count and (scoreTable.count + 1) or 1;

	scoreTable.outcomes = scoreTable.outcomes or {};
	tinsert(scoreTable.outcomes, outcome);

	if(scoreTable.count > 1) then
		duplicateScoreTable[scoreKey] = scoreTable.count;
	end

	return scoreTable;
end

local function GenerateOutcomesRecursive(roundIndex, outcomeKey, outcomeTable)
	roundIndex = roundIndex or 1;
	assert(roundIndex <= 6);

	outcomeTable = outcomeTable or {};
	local lastKey = outcomeKey or "";

	for i=0, 2 do
		-- Add current round outcome (win, loss or draw)
		local newKey = lastKey .. i;

		if(roundIndex < unknownRounds) then
			GenerateOutcomesRecursive(roundIndex+1, newKey, outcomeTable);
		elseif(CountDraws(newKey) <= maxDraws) then
			tinsert(outcomeTable, newKey);
		end
	end

	if(roundIndex == 1) then
		Debug:Log("GenerateOutcomesRecursive generated #" .. #outcomeTable, "outcomes");
		return outcomeTable;
	end
end


local function AddScoreWins(score, team)
	for _,playerIndex in ipairs(team) do
		score[playerIndex] = score[playerIndex] + 1;
	end
	score.total = score.total + 3;
end

local hasGenerated = false;
local function GenerateScoreLookup()
	if(hasGenerated) then
		return;
	end
	hasGenerated = true;

	local outcomeTable = GenerateOutcomesRecursive();

	local score = {};
	local function ResetScore()
		score.total = 0;
		for i=1, 6 do
			score[i] = 0;
		end
	end

	for idx,outcomes in ipairs(outcomeTable) do
		ResetScore();

		for roundIndex=1, #outcomes do
			local outcome = tonumber(string.sub(outcomes, roundIndex, roundIndex));

			if(outcome == 1) then
				AddScoreWins(score, fixedRoundTeams[roundIndex][1]);
			elseif(outcome == 2) then
				AddScoreWins(score, fixedRoundTeams[roundIndex][2]);
			else
				assert(outcome == 0);
			end
		end

		-- Compute sorted key total-sortedHealers-sortedDps (T-hh-dddd)
		local h = { score[1], score[6] };
		--table.sort(h, function(a,b) return a > b end);

		local d = { score[2], score[3], score[4], score[5] };
		--table.sort(d, function(a,b) return a > b end);

		local scorekey = string.format("%02d-%d%d-%d%d%d%d",
			score.total,
			h[1], h[2],
			d[1], d[2], d[3], d[4]
		);

		Debug:Log("Shuffle Resolver: ScoreKey:", scorekey, outcomes)
		FindOrAddLookupScore(scorekey, outcomes);
	end

	return #outcomeTable;
end


function ArenaAnalytics:RunScoreTest()
	local outcomeCount = GenerateScoreLookup();

	local uniqueCount, duplicateCount, total = 0, 0, 0;
	for key,data in pairs(scoreLookupCache) do
		if(data.count == 1) then
			uniqueCount = uniqueCount + 1;
		else
			Debug:LogTable(data);
			duplicateCount = duplicateCount + 1;
		end

		total = total + 1;
	end

	--Debug:LogTable(scoreLookupCache);
	Debug:Log("Score Duplicate:", duplicateCount, "Unique:", uniqueCount, "Total:", total, outcomeCount);
end