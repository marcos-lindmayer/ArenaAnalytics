local _, ArenaAnalytics = ... -- Namespace
local ArenaTracker = ArenaAnalytics.ArenaTracker;

-- Local module aliases
local Constants = ArenaAnalytics.Constants;
local API = ArenaAnalytics.API;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------
-- ArenaTracker subsection
-- Responsible for processing when gates open, through chat messages.
-------------------------------------------------------------------------

local currentArena = {};
function ArenaTracker:InitializeSubmodule_GatesOpened()
    currentArena = ArenaAnalyticsTransientDB.currentArena;
end

function ArenaTracker:HandleArenaMessages(msg)
	if(not msg or not ArenaTracker:IsTrackingArena()) then
		return;
	end

	local isStart, timeTillStart = Constants:CheckTimerMessage(msg);

	if(not timeTillStart) then
		Debug:LogWarning("Invalid msg:", msg);
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
		ArenaTracker:HandleArenaGatesOpened(msg);
	end
end

-- Gates opened, match has officially started
function ArenaTracker:HandleArenaGatesOpened(...)
	currentArena.startTime = time();
	currentArena.hasRealStartTime = true; -- The start time has been set by gates opened

	ArenaTracker:FillMissingPlayers();
	ArenaTracker:ForceTeamsUpdate();
	ArenaTracker:UpdateRoundTeam();

	if(ArenaTracker:IsTrackingShuffle()) then
		local myWins, totalWins = ArenaTracker:GetCurrentWins();
		currentArena.round.wins = myWins;
		currentArena.round.totalWins = totalWins;
		Debug:Log("Assigned round wins:", myWins, totalWins);

		currentArena.round.startTime = time();
		currentArena.round.hasStarted = true;
	end

	Debug:LogGreen("Match started!", API:GetCurrentMapID(), GetZoneText(), #currentArena.players);
end
