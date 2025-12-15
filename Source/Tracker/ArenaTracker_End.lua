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
-- Responsible for dealing with loading into an arena.
-------------------------------------------------------------------------

local currentArena = {};
function ArenaTracker:InitializeSubmodule_End()
    currentArena = ArenaAnalyticsTransientDB.currentArena;
end


-- Gets arena information when it ends and the scoreboard is shown
-- Matches obtained info with previously collected player values
function ArenaTracker:HandleArenaEnd()
	if(not ArenaTracker:IsTrackingArena()) then
		Debug:LogWarning("ArenaTracker:HandleArenaEnd skipped: Not tracking arena.");
		return;
	end

	Events:UnregisterArenaEvents();

	-- Not ready to end yet
	if(not ArenaTracker:IsInState("Active")) then
		return;
	end

	ArenaTracker:SetState("Ended");

	if(currentArena.endedProperly) then
		return;
	end

	currentArena.endedProperly = true;
	currentArena.ended = true;
	currentArena.endTime = tonumber(currentArena.endTime) or time();

	Debug:LogGreen("HandleArenaEnd!", #currentArena.players, currentArena.startTime, currentArena.endTime, GetNumBattlefieldScores());

	-- Solo Shuffle
	ArenaTracker:HandleRoundEnd(true);

	local winner = API:GetWinner();

	RequestRatedInfo();

	local players = TablePool:Acquire();

	-- Figure out how to default to nil, without failing to count losses.
	local myTeamIndex = nil;

	local isShuffle = ArenaTracker:IsShuffle();

	for i=1, GetNumBattlefieldScores() do
		local score = API:GetPlayerScore(i) or TablePool:Acquire();

		-- Find or add player
		local player = ArenaTracker:GetPlayer(score.name);
		if(not player) then
			-- Use scoreboard info
			Debug:Log("Creating new player by scoreboard:", score.name);
			player = ArenaTracker:CreatePlayerTable(nil, score.name);
			Debug:Log("Adding player: ", score.name);
		end

		-- Fill missing data
		player.teamIndex = score.team;
		player.spec = Helpers:IsSpecID(player.spec) and player.spec or score.spec;
		player.race = player.race or score.race;
		player.kills = score.kills;
		player.deaths = API.trustScoreboardDeaths and score.deaths or player.deaths or 0;
		player.damage = score.damage;
		player.healing = score.healing;

		if(ArenaTracker:IsRated()) then
			player.rating = score.rating;
			player.ratingDelta = score.ratingDelta;
			player.mmr = score.mmr;
			player.mmrDelta = score.mmrDelta;
		end

		if(isShuffle) then
			player.wins = score.wins or 0;
		end

		if(player.name) then
			if (currentArena.playerName and player.name == currentArena.playerName) then
				myTeamIndex = player.teamIndex;
				player.isSelf = true;

				-- Probably not useful, keeping at warning log level for non-shuffles, in case I learn more.
				if(not isShuffle and myTeamIndex ~= GetBattlefieldArenaFaction()) then
					Debug:LogWarning("My team index API mismatch! GetBattlefieldArenaFaction cannot be trusted?");
				end

			elseif(isShuffle) then
				-- Everyone else is an opponent in shuffle (1v5)
				player.isEnemy = true;
			end

			table.insert(players, player);
		else
			Debug:LogWarning("Tracker: Invalid player name, player will not be stored!");
		end

		TablePool:Release(score);
	end

	if(isShuffle) then
		-- Determine match outcome
		currentArena.outcome = ArenaTracker:GetShuffleOutcome()
	else
		-- Assign isEnemy value
		for _,player in ipairs(players) do
			if(player and player.teamIndex) then
				player.isEnemy = (player.teamIndex ~= myTeamIndex);
			end
		end

		-- Assign Winner
		if(winner == 255) then
			currentArena.outcome = 2;
		elseif(winner ~= nil) then
			currentArena.outcome = (myTeamIndex == winner) and 1 or 0;
		end
	end

	-- Process ranked information
	if (ArenaTracker:IsRated() and myTeamIndex) then
		local otherTeamIndex = (myTeamIndex == 0) and 1 or 0;

		currentArena.partyMMR = API:GetTeamMMR(myTeamIndex);
		currentArena.enemyMMR = API:GetTeamMMR(otherTeamIndex);
	end

	currentArena.players = players;

	Debug:Log("Match ended!", #currentArena.players, "players tracked.");

	ArenaTracker:SetState("Locked"); -- TODO: Convert to currentArena.locked?
end