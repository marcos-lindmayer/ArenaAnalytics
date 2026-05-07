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
-- Responsible for dealing with loading into an arena.
-------------------------------------------------------------------------

local currentArena = {};
function ArenaTracker:InitializeSubmodule_Scoreboard()
    currentArena = ArenaAnalyticsTransientDB.currentArena;
end

local function ToNonZero(num)
	return num ~= 0 and num or nil;
end


function ArenaTracker:FindOrAddPlayer(fullname)
	if(not API:IsValidValue(fullname)) then
		return nil;
	end

	local player = ArenaTracker:GetPlayer(fullname);
	if(not player) then
		-- Use scoreboard info
		player = ArenaTracker:CreatePlayer(nil, fullname);

		if(player and player.name) then
			Debug:LogGreen("Creating new player by scoreboard:", player.name, fullname, Internal:GetClassAndSpec(player.spec));
			tinsert(currentArena.players, player);
		end
	end

	return player;
end


-- Gets arena information when it ends and the scoreboard is shown
-- Matches obtained info with previously collected player values
function ArenaTracker:UpdatePlayersFromScoreboard()
	if(not ArenaTracker:IsTrackingArena()) then
		Debug:LogWarning("ArenaTracker:HandleArenaEnd skipped: Not tracking arena.");
		return;
	end

	Debug:LogGreen("UpdatePlayersFromScoreboard:", #currentArena.players, currentArena.startTime, API:GetNumBattlefieldScores());

	RequestRatedInfo();

	-- Figure out how to default to nil, without failing to count losses.
	local myTeamIndex = nil;

	local isShuffle = ArenaTracker:IsShuffle();

	for i=1, API:GetNumBattlefieldScores() do
		local score = API:GetPlayerScore(i) or TablePool:Acquire();

		-- Find or add player
		local player = ArenaTracker:FindOrAddPlayer(score.name);

		if(player) then
			-- Testing:
			local pClass, pSpec = Internal:GetClassAndSpec(player.spec);
			local sClass, sSpec = Internal:GetClassAndSpec(score.spec);
			Debug:LogTemp("Scoreboard test - Player:", player.name, pClass, pSpec, " to score:", sClass, sSpec);

			-- Fill missing data
			player.teamIndex = score.team;
			player.spec = Helpers:IsSpecID(player.spec) and player.spec or score.spec;
			player.race = player.race or score.race;
			player.kills = score.kills;
			player.deaths = ToNonZero(score.deaths) or ToNonZero(player.deaths) or 0;
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

					currentArena.wins = player.wins;

				elseif(isShuffle) then
					-- Everyone else is an opponent in shuffle (1v5)
					player.isEnemy = true;
				end
			else
				Debug:LogWarning("Tracker: Invalid player name, player will not be stored!");
			end
		end

		TablePool:Release(score);
	end

	if(not isShuffle) then
		-- Assign isEnemy value
		for _,player in ipairs(currentArena.players) do
			if(player and player.teamIndex) then
				player.isEnemy = (player.teamIndex ~= myTeamIndex);
			end
		end
	else
		--ArenaTracker:UpdateRoundEnemyTeams();
	end

	-- Process ranked information
	if (ArenaTracker:IsRated() and myTeamIndex) then
		local otherTeamIndex = (myTeamIndex == 0) and 1 or 0;

		currentArena.partyMMR = API:GetTeamMMR(myTeamIndex);
		currentArena.enemyMMR = API:GetTeamMMR(otherTeamIndex);
	end

	-- @TEMP:
	Debug:LogTemp("Updated from scoreboard:", #currentArena.players);
end