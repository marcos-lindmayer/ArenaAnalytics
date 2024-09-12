local _, ArenaAnalytics = ...; -- Addon Namespace
local Events = ArenaAnalytics.Events;

-- Local module aliases
local ArenaTracker = ArenaAnalytics.ArenaTracker;
local Constants = ArenaAnalytics.Constants;
local API = ArenaAnalytics.API;

-------------------------------------------------------------------------

local arenaEventsRegistered = false;
local eventFrame = CreateFrame("Frame");
local arenaEventFrame = CreateFrame("Frame");

local arenaEvents = { "UPDATE_BATTLEFIELD_SCORE", "UNIT_AURA", "CHAT_MSG_BG_SYSTEM_NEUTRAL", "COMBAT_LOG_EVENT_UNFILTERED", "ARENA_OPPONENT_UPDATE" }

-- Register an event as a response to a 
function Events:CreateEventListenerForRequest(event, repeatable, callback)
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent(event)
    eventFrame:SetScript("OnEvent", function(self)
        if(not repeatable) then
			self:UnregisterEvent(event, nil) -- Unregister the event handler
			self:Hide() -- Hide the frame
			eventFrame = nil;
		end

        callback();
    end)
end

-- Assigns behaviour for "global" events
-- UPDATE_BATTLEFIELD_STATUS: Begins arena tracking and arena events if inside arena
-- ZONE_CHANGED_NEW_AREA: Tracks if player left the arena before it ended
local function HandleGlobalEvents(_, eventType, ...)
	if(eventType == "PVP_RATED_STATS_UPDATE") then
		ArenaAnalytics:TryFixLastMatchRating();
	end

	if (API:IsInArena()) then
		if (not ArenaTracker:IsTrackingArena()) then
			if (eventType == "UPDATE_BATTLEFIELD_STATUS") then
				ArenaTracker:HandleArenaEnter(...);
			end
			
			Events:RegisterArenaEvents();
		end
	else -- Not in arena
		if (eventType == "UPDATE_BATTLEFIELD_STATUS") then
			ArenaTracker:SetNotEnded() -- Player is out of arena, next arena hasn't ended yet
		elseif (eventType == "ZONE_CHANGED_NEW_AREA") then
			if(ArenaTracker:IsTrackingArena()) then
				Events:UnregisterArenaEvents();
				ArenaTracker:HandleArenaExit();
			end
		end
	end
end

-- Detects start of arena by CHAT_MSG_BG_SYSTEM_NEUTRAL message (msg)
local function ParseArenaTimerMessages(msg, ...)
	if(GetLocale() == "itIT") then
		ArenaAnalytics:Log("ParseArenaTimerMessages", msg and msg:gsub("\\", "\\\\"));
		ArenaAnalytics:Log("     ", ...);
	end

	local localizedMessage = Constants.GetArenaTimer();
	if(msg:find(localizedMessage)) then
		ArenaTracker:HandleArenaStart();
	end
end

-- Assigns behaviour for each arena event
-- UPDATE_BATTLEFIELD_SCORE: the arena ended, final info is grabbed and stored
-- UNIT_AURA, COMBAT_LOG_EVENT_UNFILTERED, ARENA_OPPONENT_UPDATE: try to get more arena information (players, specs, etc)
-- CHAT_MSG_BG_SYSTEM_NEUTRAL: Detect if the arena started
local function HandleArenaEvents(_, eventType, ...)
	if (API:IsInArena()) then 
		if (ArenaTracker:IsTrackingArena()) then
			if (eventType == "UPDATE_BATTLEFIELD_SCORE" and GetBattlefieldWinner() ~= nil) then
				ArenaTracker:HandleArenaEnd();
				ArenaAnalytics:Log("Arena ended. UPDATE_BATTLEFIELD_SCORE with non-nil winner.");
				Events:UnregisterArenaEvents();
			elseif (eventType == "UNIT_AURA") then
				ArenaTracker:ProcessUnitAuraEvent(...);
			elseif(eventType == "COMBAT_LOG_EVENT_UNFILTERED") then
				ArenaTracker:ProcessCombatLogEvent(...);
			elseif(eventType == "ARENA_OPPONENT_UPDATE") then
				ArenaTracker:ProcessOpponentUpdate(...);
			elseif (eventType == "CHAT_MSG_BG_SYSTEM_NEUTRAL") then
				ParseArenaTimerMessages(...);
			end
		end
	end
end

-- Creates "global" events
function Events:RegisterGlobalEvents()
	eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS");
	eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	eventFrame:RegisterEvent("PVP_RATED_STATS_UPDATE");
	eventFrame:SetScript("OnEvent", HandleGlobalEvents);
end

-- Adds events used inside arenas
function Events:RegisterArenaEvents()
	if(not arenaEventsRegistered) then
		for _,event in ipairs(arenaEvents) do
			arenaEventFrame:RegisterEvent(event);
		end
		arenaEventFrame:SetScript("OnEvent", HandleArenaEvents);
		arenaEventsRegistered = true;
	end
end

-- Removes events used inside arenas
function Events:UnregisterArenaEvents()
	if(arenaEventsRegistered) then
		for _,event in ipairs(arenaEvents) do
			arenaEventFrame:UnregisterEvent(event);
		end
		arenaEventFrame:SetScript("OnEvent", HandleArenaEvents);
		arenaEventsRegistered = false;
	end
end