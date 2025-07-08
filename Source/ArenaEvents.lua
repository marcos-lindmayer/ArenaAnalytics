local _, ArenaAnalytics = ...; -- Addon Namespace
local Events = ArenaAnalytics.Events;

-- Local module aliases
local ArenaTracker = ArenaAnalytics.ArenaTracker;
local Constants = ArenaAnalytics.Constants;
local API = ArenaAnalytics.API;
local Inspection = ArenaAnalytics.Inspection;
local Options = ArenaAnalytics.Options;
local ArenaRatedInfo = ArenaAnalytics.ArenaRatedInfo;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------

local arenaEventsRegistered = false;

local eventFrames = {
	onLoadFrame = CreateFrame("Frame"),
	globalEventFrame = CreateFrame("Frame"),
	arenaEventFrame = CreateFrame("Frame"),
}


local loadEvents = {
	"PLAYER_LOGIN",
	"PLAYER_ENTERING_WORLD",
	"VARIABLES_LOADED",
};

local arenaEvents = {
	"INSPECT_READY",
	"ARENA_OPPONENT_UPDATE",
	"ARENA_PREP_OPPONENT_SPECIALIZATIONS",
	"GROUP_ROSTER_UPDATE",
	"UPDATE_BATTLEFIELD_SCORE",
	"PVP_RATED_STATS_UPDATE",
	"UNIT_AURA", -- TODO: Modify to allow expansion specfic toggles for events
	"CHAT_MSG_BG_SYSTEM_NEUTRAL",
	"COMBAT_LOG_EVENT_UNFILTERED",
};

local globalEvents = {
	"UPDATE_BATTLEFIELD_STATUS",
	"ZONE_CHANGED_NEW_AREA",
	"PVP_RATED_STATS_UPDATE",
	"UPDATE_BATTLEFIELD_SCORE",

	--"INSPECT_READY", -- Used when testing inspection
};

-- Register an event as a response to a 
function Events:CreateEventListenerForRequest(event, repeatable, callback)
    local frame = CreateFrame("Frame")
    frame:RegisterEvent(event)
    frame:SetScript("OnEvent", function(self)
        if(not repeatable) then
			self:UnregisterEvent(event, nil) -- Unregister the event handler
			self:Hide() -- Hide the frame
			frame = nil;
		end

        callback();
    end);
end

local function isLoaded()
	if(not IsLoggedIn()) then
		return false;
	end

	-- Check some APIs

	return true;
end

local function useFallbackLoadTimer()
	-- If all load events hapened, and API still fails, then start a 1 sec timer loop until they work?
end

local function HandleLoadEvent(_, eventType, ...)
	if(not isLoaded()) then
		Debug:LogWarning("HandleLoadEvent called before isLoaded() is true.", eventType);
		return
	end

	Debug:LogGreen("HandleLoadEvent:", eventType, ..., "||||", API:GetActiveBattlefieldID());
	Events:OnLoad();
end

-- Post initialization
local hasLoaded = false;
function Events:OnLoad()
	if(hasLoaded) then
		return;
	end
	hasLoaded = true;

	Events:UnregisterLoadEvents();
	Events:RegisterGlobalEvents();

	-- Request events, in case critical events fired before loading in
	C_Timer.After(0, function() RequestRatedInfo() end);

	if(API:IsInArena()) then
		Debug:Log("Requesting RequestBattlefieldScoreData")
		C_Timer.After(0, function() RequestBattlefieldScoreData() end);

		-- TESTING - Request appears to be failing.
		ArenaAnalytics.ArenaTracker:HandleArenaEnter();

	elseif(ArenaTracker:IsTrackingArena()) then
		-- Clear outdated arena tracking
		ArenaTracker:HandleArenaExit();
	end
end

local hasZoneChanged = false;
local function HandleZoneChanged()
	hasZoneChanged = true;
	RequestRatedInfo();
end

local function HandleRatedUpdate(...)
	ArenaAnalytics:TryFixLastMatchRating();
	ArenaRatedInfo:UpdateRatedInfo();

	-- Enter/Exit
	if(hasZoneChanged) then
		hasZoneChanged = false;

		Debug:LogGreen("HandleRatedUpdate", API:IsInArena(), ArenaTracker:IsTrackingArena());

		if (API:IsInArena()) then
			-- Internal checks for existing tracking
			if(not ArenaTracker:IsTrackingArena()) then
				ArenaTracker:HandleArenaEnter();
			end
		else -- Not in arena
			Events:UnregisterArenaEvents();
			if(ArenaTracker:IsTrackingArena()) then
				C_Timer.After(0, ArenaTracker.HandleArenaExit);
			end
		end
	end

	ArenaTracker:HandleRatedUpdate();
end

local function HandleBattlefieldScore(...)
	Debug:Log("Events HandleBattlefieldScore triggered.");

	if(API:IsInArena()) then
		ArenaTracker:HandleScoreUpdate();
	end
end

-- Assigns behaviour for "global" events
-- UPDATE_BATTLEFIELD_STATUS: Begins arena tracking and arena events if inside arena
-- ZONE_CHANGED_NEW_AREA: Tracks if player left the arena before it ended
local function HandleGlobalEvent(_, eventType, ...)
	Debug:LogTemp(eventType, "GetPersonalRatedInfo", API:GetPersonalRatedInfo(1), API:IsInArena());

	-- Inspect debugging
	if(eventType == "INSPECT_READY") then
		if(Debug.HandleDebugInspect) then
			Debug:HandleDebugInspect(...);
		end
		return;
	end

	if(eventType == "PVP_RATED_STATS_UPDATE") then
		HandleRatedUpdate(...);
	elseif(eventType == "ZONE_CHANGED_NEW_AREA") then
		API:UpdateDialogueVolume();
		HandleZoneChanged();

	elseif (eventType == "UPDATE_BATTLEFIELD_STATUS" or eventType == "UPDATE_BATTLEFIELD_SCORE") then
		HandleBattlefieldScore(...);
	end
end

-- Assigns behaviour for each arena event
-- UPDATE_BATTLEFIELD_SCORE: the arena ended, final info is grabbed and stored
-- UNIT_AURA, COMBAT_LOG_EVENT_UNFILTERED, ARENA_OPPONENT_UPDATE: try to get more arena information (players, specs, etc)
-- CHAT_MSG_BG_SYSTEM_NEUTRAL: Detect if the arena started
local function HandleArenaEvent(_, eventType, ...)
	if (not API:IsInArena() or not ArenaTracker:IsTrackingArena()) then
		return;
	end

	if (eventType == "UPDATE_BATTLEFIELD_SCORE") then
		ArenaTracker:HandleScoreUpdate();

		if(API:GetWinner() ~= nil) then
			Events:UnregisterArenaEvents();
			C_Timer.After(0, ArenaTracker.HandleArenaEnd);
		end

	elseif(eventType == "PVP_RATED_STATS_UPDATE") then
		C_Timer.After(0, ArenaTracker.HandleRatedUpdate);
		ArenaTracker:CheckRoundEnded();

	elseif (eventType == "UNIT_AURA") then
		ArenaTracker:ProcessUnitAuraEvent(...);

	elseif(eventType == "COMBAT_LOG_EVENT_UNFILTERED") then
		ArenaTracker:ProcessCombatLogEvent(...);

	elseif(eventType == "ARENA_OPPONENT_UPDATE" or eventType == "ARENA_PREP_OPPONENT_SPECIALIZATIONS") then
		ArenaTracker:HandleOpponentUpdate();

	elseif(eventType == "GROUP_ROSTER_UPDATE") then
		ArenaTracker:HandlePartyUpdate();

	elseif (eventType == "CHAT_MSG_BG_SYSTEM_NEUTRAL") then
		local msg = ...;
		ArenaTracker:HandleArenaMessages(msg);

	elseif(eventType == "INSPECT_READY") then
		if(API.enableInspection and Inspection and Inspection.HandleInspectReady) then
			Debug:Log(eventType, "triggered!");
			Inspection:HandleInspectReady(...);
		end
	end
end

-------------------------------------------------------------------------

local function registerEvents(eventFrame, events, func)
	if(not eventFrame or type(events) ~= "table" or type(func) ~= "function") then
		Debug:LogError("RegisterEvents failed.", eventFrame, type(events), type(func));
		return;
	end

	if(eventFrame.hasRegisteredEvents) then
		return;
	end

	for _,event in ipairs(events) do
		if(C_EventUtils.IsEventValid(event)) then
			eventFrame:RegisterEvent(event);
		end
	end

	eventFrame:SetScript("OnEvent", func);
	eventFrame.hasRegisteredEvents = true;
end

local function unregisterEvents(eventFrame, events)
	if(not eventFrame or not eventFrame.hasRegisteredEvents) then
		return;
	end

	for _,event in ipairs(events) do
		if(C_EventUtils.IsEventValid(event)) then
			eventFrame:UnregisterEvent(event);
		end
	end

	eventFrame:SetScript("OnEvent", nil);
	eventFrame.hasRegisteredEvents = false;
end

-------------------------------------------------------------------------

-- Custom OnLoad event handling
function Events:RegisterLoadEvents()
	if(eventFrames.onLoadFrame) then
		registerEvents(eventFrames.onLoadFrame, loadEvents, HandleLoadEvent);
	end
end

function Events:UnregisterLoadEvents()
	--unregisterEvents(eventFrames.onLoadFrame, loadEvents);
	--eventFrames.onLoadFrame = nil;
end

-- Creates "global" events
function Events:RegisterGlobalEvents()
	registerEvents(eventFrames.globalEventFrame, globalEvents, HandleGlobalEvent);
end

-- Adds events used inside arenas
function Events:RegisterArenaEvents()
	registerEvents(eventFrames.arenaEventFrame, arenaEvents, HandleArenaEvent);

	if(not arenaEventsRegistered) then
		for _,event in ipairs(arenaEvents) do
			if(C_EventUtils.IsEventValid(event)) then
				eventFrames.arenaEventFrame:RegisterEvent(event);
			end
		end

		eventFrames.arenaEventFrame:SetScript("OnEvent", HandleArenaEvent);
		arenaEventsRegistered = true;
	end
end

-- Removes events used inside arenas
function Events:UnregisterArenaEvents()
	unregisterEvents(eventFrames.arenaEventFrame, arenaEvents);
end

-------------------------------------------------------------------------

function Events:Initialize()
	Events:RegisterLoadEvents();
end