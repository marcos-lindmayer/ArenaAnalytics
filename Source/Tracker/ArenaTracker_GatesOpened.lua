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
-- Responsible for processing when gates open, through chat messages or match state.
-------------------------------------------------------------------------

local currentArena = {};
function ArenaTracker:InitializeSubmodule_GatesOpened()
    currentArena = ArenaAnalyticsTransientDB.currentArena;
end


function ArenaTracker:HandleArenaMessages(msg)
	if(msg and not API:IsSecretValue(msg)) then
		return;
	end

	if(not ArenaTracker:IsTrackingArena()) then
		return;
	end

	local isStart, timeTillStart = Constants:CheckTimerMessage(msg);

	if(not timeTillStart) then
		return;
	end

	Debug:LogGreen("HandleArenaMessages:", msg);

	if(not currentArena.hasRealStartTime) then
		local newTime = (time() + timeTillStart);

		if(currentArena.startTime) then
			Debug:LogGreen("Start Time changed by broadcast message:", currentArena.startTime, newTime, newTime - time());
		end

		currentArena.startTime = newTime;
	end

	-- Trigger Start handling logic
	if(isStart) then
		ArenaTracker:HandleArenaGatesOpened();
		currentArena.matchState = 3;
	end
end


function ArenaTracker:CheckHasGatesOpened()
	local state = API:GetActiveMatchState() or 0;

	if(state > 2) then
		ArenaTracker:HandleArenaGatesOpened();
	end
end


-- Gates opened, match has officially started
function ArenaTracker:HandleArenaGatesOpened()
	if(not ArenaTracker:IsTrackingArena()) then
		return;
	end

	local isShuffle = ArenaTracker:IsTrackingShuffle();
	if(not isShuffle and currentArena.hasRealStartTime or currentArena.round.hasStarted) then
		return;
	end

	currentArena.startTime = time();
	currentArena.hasRealStartTime = true; -- The start time has been set by gates opened

	if(isShuffle) then
		currentArena.round.startTime = time();
		currentArena.round.hasStarted = true;
	end

	ArenaTracker:FillMissingPlayers();
	ArenaTracker:ForceTeamsUpdate();

	ArenaTracker:RequestPartySpecs();
end
