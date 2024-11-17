local _, ArenaAnalytics = ...; -- Addon Namespace
local Events = ArenaAnalytics.Events;

-- Local module aliases
local SharedTracker = ArenaAnalytics.SharedTracker;
local ArenaTracker = ArenaAnalytics.ArenaTracker;
local BattlegroundTracker = ArenaAnalytics.BattlegroundTracker;
local Constants = ArenaAnalytics.Constants;
local API = ArenaAnalytics.API;
local Inspection = ArenaAnalytics.Inspection;

-------------------------------------------------------------------------

local function CacheTempData(msg)
	ArenaAnalytics:LogGreen("CacheTempData", msg);

	ArenaAnalyticsTempDB[GetLocale()] = ArenaAnalyticsTempDB[GetLocale()] or {}
	local cache = ArenaAnalyticsTempDB[GetLocale()];

	local currentMapID = API:GetCurrentMapID();

	if(msg) then
		cache.messages = cache.messages or {};
		cache.messages[msg] = currentMapID or -1;
	end

	if(currentMapID) then
		cache.maps = cache.maps or {}
		cache.maps[currentMapID] = cache.maps[currentMapID] or {};

		local map = cache.maps[currentMapID];
		map.name = GetZoneText();

		local playerScore = API:GetPlayerScore(1);
		if(playerScore and playerScore.stats) then
			map.stats = playerScore.stats;
		end
	end
end

local arenaEventsRegistered = false;
local eventFrame = CreateFrame("Frame");
local arenaEventFrame = CreateFrame("Frame");

local arenaEvents = { 
	"UPDATE_BATTLEFIELD_SCORE", 
	"UNIT_AURA", 
	"CHAT_MSG_BG_SYSTEM_NEUTRAL", 
	"COMBAT_LOG_EVENT_UNFILTERED", 
	"INSPECT_READY", 
	"ARENA_OPPONENT_UPDATE", 
	"GROUP_ROSTER_UPDATE", 
	"ARENA_PREP_OPPONENT_SPECIALIZATIONS",
}

local globalEvents = { 
	"UPDATE_BATTLEFIELD_STATUS", 
	"ZONE_CHANGED_NEW_AREA", 
	"PVP_RATED_STATS_UPDATE",
}

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
local function HandleGlobalEvent(_, eventType, ...)
	if(eventType == "PVP_RATED_STATS_UPDATE") then
		ArenaAnalytics:TryFixLastMatchRating();

		-- This checks for IsInArena() and IsTrackingArena()
		if(API:IsInArena()) then
			ArenaTracker:HandleArenaEnter();
		elseif(API:IsInBattleground()) then
			BattlegroundTracker:HandleEnter();
		end
	elseif(eventType == "ZONE_CHANGED_NEW_AREA") then
		API:UpdateDialogueVolume();
	end

	local isTrackingArena = ArenaTracker:IsTracking();
	if (API:IsInArena()) then
		if (not isTrackingArena) then
			if (eventType == "UPDATE_BATTLEFIELD_STATUS") then
				RequestRatedInfo(); -- Will trigger ArenaTracker:HandleArenaEnter(...)
			end
		end
	elseif(isTrackingArena and eventType == "ZONE_CHANGED_NEW_AREA") then
		Events:UnregisterArenaEvents();
		C_Timer.After(0, ArenaTracker.HandleArenaExit);
		ArenaAnalytics:Log("ZONE_CHANGED_NEW_AREA triggering delayed HandleArenaExit");
	end

	-- Battleground
	local isTrackingBattleground = BattlegroundTracker:IsTracking();
	if (API:IsInBattleground()) then
		CacheTempData();

		if (not isTrackingBattleground) then
			if (eventType == "UPDATE_BATTLEFIELD_STATUS") then
				RequestRatedInfo(); -- Will trigger ArenaTracker:HandleArenaEnter(...)
			end
		end
	elseif(isTrackingBattleground and eventType == "ZONE_CHANGED_NEW_AREA") then
		Events:UnregisterBattlegroundEvents();
		C_Timer.After(0, BattlegroundTracker.HandleExit);
		ArenaAnalytics:Log("ZONE_CHANGED_NEW_AREA triggering delayed BattlegroundTracker.HandleExit");
	end
end

-- Detects start of arena by CHAT_MSG_BG_SYSTEM_NEUTRAL message (msg)
local function ParseArenaTimerMessages(msg, ...)
	local localizedMessage = Constants.GetArenaTimer();
	if(localizedMessage and msg:find(localizedMessage, 1, true)) then
		ArenaTracker:HandleArenaStart();
	end
end

-- Assigns behaviour for each arena event
-- UPDATE_BATTLEFIELD_SCORE: the arena ended, final info is grabbed and stored
-- UNIT_AURA, COMBAT_LOG_EVENT_UNFILTERED, ARENA_OPPONENT_UPDATE: try to get more arena information (players, specs, etc)
-- CHAT_MSG_BG_SYSTEM_NEUTRAL: Detect if the arena started
local function HandleArenaEvent(_, eventType, ...)
	if (not API:IsInArena()) then 
		return;
	end

	if (eventType == "UPDATE_BATTLEFIELD_SCORE") then
		ArenaAnalytics:LogSpacer();
		ArenaAnalytics:LogTemp("UPDATE_BATTLEFIELD_SCORE");
		ArenaAnalytics:LogTemp(API:GetTeamMMR(0), API:GetTeamMMR(1));
		ArenaAnalytics:LogTemp(GetBattlefieldWinner(), GetNumBattlefieldScores());
		ArenaAnalytics:LogSpacer();
	end

	if (ArenaTracker:IsTracking()) then
		if (eventType == "UPDATE_BATTLEFIELD_SCORE" and GetBattlefieldWinner() ~= nil) then
			ArenaAnalytics:Log("Arena ended. UPDATE_BATTLEFIELD_SCORE with non-nil winner.");
			ArenaTracker:HandleArenaEnd();
			Events:UnregisterArenaEvents();
		elseif(eventType == "UNIT_AURA") then
			SharedTracker:ProcessUnitAuraEvent(...);
		elseif(eventType == "COMBAT_LOG_EVENT_UNFILTERED") then
			SharedTracker:ProcessCombatLogEvent(...);
		elseif(eventType == "ARENA_OPPONENT_UPDATE" or eventType == "ARENA_PREP_OPPONENT_SPECIALIZATIONS") then
			ArenaTracker:HandleOpponentUpdate();
		elseif(eventType == "GROUP_ROSTER_UPDATE") then
			ArenaTracker:HandlePartyUpdate();
		elseif(eventType == "CHAT_MSG_BG_SYSTEM_NEUTRAL") then
			ParseArenaTimerMessages(...);
		elseif(eventType == "INSPECT_READY") then
			if(Inspection and Inspection.HandleInspectReady) then
				Inspection:HandleInspectReady(...);
			end
		end
	end
end

-- Detects start of arena by CHAT_MSG_BG_SYSTEM_NEUTRAL message (msg)
local function ParseBattlegroundTimerMessages(msg, ...)
	CacheTempData(msg);

	local localizedMessage = Constants.GetArenaTimer();
	if(localizedMessage and msg:find(localizedMessage, 1, true)) then
		BattlegroundTracker:HandleStart();
	end
end

local function HandleBattlegroundEvent(_, eventType, ...)
	if (not API:IsInBattleground()) then 
		return;
	end

	if (eventType == "UPDATE_BATTLEFIELD_SCORE") then
		ArenaAnalytics:LogSpacer();
		ArenaAnalytics:LogTemp("UPDATE_BATTLEFIELD_SCORE");
		ArenaAnalytics:LogTemp(API:GetTeamMMR(0), API:GetTeamMMR(1));
		ArenaAnalytics:LogTemp(GetBattlefieldWinner(), GetNumBattlefieldScores());
		ArenaAnalytics:LogSpacer();
	end

	if (BattlegroundTracker:IsTracking()) then
		if (eventType == "UPDATE_BATTLEFIELD_SCORE") then
			BattlegroundTracker:UpdatePlayers();

			if(GetBattlefieldWinner() ~= nil) then
				ArenaAnalytics:Log("Arena ended. UPDATE_BATTLEFIELD_SCORE with non-nil winner.");
				BattlegroundTracker:HandleEnd();
				Events:UnregisterArenaEvents();
			end
		elseif(eventType == "UNIT_AURA" or eventType == "COMBAT_LOG_EVENT_UNFILTERED") then
			SharedTracker:ProcessCombatLogEvent(...);
		elseif (eventType == "CHAT_MSG_BG_SYSTEM_NEUTRAL") then
			ParseBattlegroundTimerMessages(...);
		elseif(eventType == "INSPECT_READY") then
			if(Inspection and Inspection.HandleInspectReady) then
				Inspection:HandleInspectReady(...);
			end
		end
	end
end

-------------------------------------------------------------------------

-- Creates "global" events
function Events:RegisterGlobalEvents()
	for _,event in ipairs(globalEvents) do
		if(C_EventUtils.IsEventValid(event)) then
			eventFrame:RegisterEvent(event);
		end
	end
	eventFrame:SetScript("OnEvent", HandleGlobalEvent);
end

-------------------------------------------------------------------------

-- Adds events used inside arenas
function Events:RegisterArenaEvents()
	if(not arenaEventsRegistered) then
		for _,event in ipairs(arenaEvents) do
			if(C_EventUtils.IsEventValid(event)) then
				arenaEventFrame:RegisterEvent(event);
			end
		end

		arenaEventFrame:SetScript("OnEvent", HandleArenaEvent);
		arenaEventsRegistered = true;
	end
end

-- Removes events used inside arenas
function Events:UnregisterArenaEvents()
	if(arenaEventsRegistered) then
		for _,event in ipairs(arenaEvents) do
			if(C_EventUtils.IsEventValid(event)) then
				arenaEventFrame:UnregisterEvent(event);
			end
		end

		arenaEventFrame:SetScript("OnEvent", nil);
		arenaEventsRegistered = false;
	end
end

-------------------------------------------------------------------------
-- Battlegrounds 

-- Adds events used inside battlegrounds
function Events:RegisterBattlegroundEvents()
	if(not arenaEventsRegistered) then
		for _,event in ipairs(arenaEvents) do
			if(C_EventUtils.IsEventValid(event)) then
				arenaEventFrame:RegisterEvent(event);
			end
		end

		arenaEventFrame:SetScript("OnEvent", HandleBattlegroundEvent);
		arenaEventsRegistered = true;
	end
end

-- Removes events used inside battlegrounds
function Events:UnregisterBattlegroundEvents()
	if(arenaEventsRegistered) then
		for _,event in ipairs(arenaEvents) do
			if(C_EventUtils.IsEventValid(event)) then
				arenaEventFrame:UnregisterEvent(event);
			end
		end

		arenaEventFrame:SetScript("OnEvent", nil);
		arenaEventsRegistered = false;
	end
end
