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
-- Responsible for collecting final data including scoreboard
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

	-- Solo Shuffle
	ArenaTracker:HandleRoundEnd(true);

	local winner = API:GetWinner();

	RequestRatedInfo();

	ArenaTracker:UpdatePlayersFromScoreboard();

	local isShuffle = ArenaTracker:IsShuffle();

	-- Find myTeamIndex
	local myTeamIndex = nil;
	for i,player in ipairs(currentArena.players) do
		if(player) then
			Debug:Log("IsEnemy before fixup:", player.name, player.teamIndex, player.isEnemy);

			if(player.isSelf) then
				myTeamIndex = player.teamIndex;
				player.isEnemy = false;
				Debug:Log("HandleArenaEnd found myTeamIndex:", myTeamIndex, isShuffle);
			else
				player.isEnemy = true;
			end
		end
	end

	if(isShuffle) then
		ArenaTracker:UpdateRoundEnemyTeams();
		currentArena.outcome = ArenaTracker:GetShuffleOutcome();
	else
		-- Assign isEnemy value
		for _,player in ipairs(currentArena.players) do
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

	Debug:LogGreen("HandleArenaEnd completed:", #currentArena.players, currentArena.startTime, currentArena.endTime, API:GetNumBattlefieldScores());
	ArenaTracker:SetState("Locked"); -- TODO: Convert to currentArena.locked?
end