local _, ArenaAnalytics = ... -- Namespace
ArenaAnalytics.Events = {}
local Events = ArenaAnalytics.Events;

local arenaEventsRegistered = false;
local eventFrame = CreateFrame("Frame");
local arenaEventFrame = CreateFrame("Frame");

local arenaEvents = { "UPDATE_BATTLEFIELD_SCORE", "UNIT_AURA", "CHAT_MSG_BG_SYSTEM_NEUTRAL", "COMBAT_LOG_EVENT_UNFILTERED", "ARENA_OPPONENT_UPDATE" }

-- Assigns behaviour for "global" events
-- UPDATE_BATTLEFIELD_STATUS: Begins arena tracking and arena events if inside arena
-- ZONE_CHANGED_NEW_AREA: Tracks if player left the arena before it ended
local function HandleGlobalEvents(prefix, eventType, ...)
	if (IsActiveBattlefieldArena()) then
		if (not ArenaAnalytics.ArenaTracker:IsTrackingArena()) then
			if (eventType == "UPDATE_BATTLEFIELD_STATUS") then
				ArenaAnalytics.ArenaTracker:HandleArenaEnter(...);
			end
			
			ArenaAnalytics.Events:RegisterArenaEvents();			
		end
	else -- Not in arena
		if (eventType == "UPDATE_BATTLEFIELD_STATUS") then
			ArenaAnalytics.ArenaTracker:SetNotEnded() -- Player is out of arena, next arena hasn't ended yet
		elseif (eventType == "ZONE_CHANGED_NEW_AREA") then
			if(ArenaAnalytics.ArenaTracker:IsTrackingArena()) then
				ArenaAnalytics.Events:UnregisterArenaEvents();
				ArenaAnalytics.ArenaTracker:HandleArenaExit();
			end
		end
	end
end

-- Detects start of arena by CHAT_MSG_BG_SYSTEM_NEUTRAL message (msg)
local function ParseArenaTimerMessages(msg)
	local locale = ArenaAnalytics.Constants.GetArenaTimer()
	for k,v in pairs(locale) do
		if string.find(msg, v) then
			-- Time is zero according to the broadcast message, and 
			if (k == 0) then
				ArenaAnalytics.ArenaTracker:HandleArenaStart();
			end
		end
	end
end

-- Assigns behaviour for each arena event
-- UPDATE_BATTLEFIELD_SCORE: the arena ended, final info is grabbed and stored
-- UNIT_AURA, COMBAT_LOG_EVENT_UNFILTERED, ARENA_OPPONENT_UPDATE: try to get more arena information (players, specs, etc)
-- CHAT_MSG_BG_SYSTEM_NEUTRAL: Detect if the arena started
local function HandleArenaEvents(_, eventType, ...)
	if (IsActiveBattlefieldArena()) then 
		if (ArenaAnalytics.ArenaTracker:IsTrackingArena()) then
			if (eventType == "UPDATE_BATTLEFIELD_SCORE" and GetBattlefieldWinner() ~= nil) then
				ArenaAnalytics.ArenaTracker:HandleArenaEnd();
				Events:UnregisterArenaEvents();
			elseif (eventType == "UNIT_AURA" or eventType == "COMBAT_LOG_EVENT_UNFILTERED" or eventType == "ARENA_OPPONENT_UPDATE") then
				ArenaAnalytics.ArenaTracker:ProcessCombatLogEvent(eventType, ...);
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