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
local Initialization = ArenaAnalytics.Initialization;

-------------------------------------------------------------------------

local arenaEventsRegistered = false;

local eventFrames = {
	initEventFrame = CreateFrame("Frame"),
	globalEventFrame = CreateFrame("Frame"),
	arenaEventFrame = CreateFrame("Frame"),
};

local loadEvents = {
	"ADDON_LOADED",
	"VARIABLES_LOADED",
	"PLAYER_LOGIN",
	"PLAYER_ENTERING_WORLD",
	"UPDATE_BATTLEFIELD_STATUS", -- Experiment
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
	"UPDATE_BATTLEFIELD_SCORE",
	"PVP_RATED_STATS_UPDATE",
	"UPDATE_BATTLEFIELD_STATUS",

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

local function HandleZoneChanged(isLoad)
	-- Optionally mute/revert dialogue volume
	API:UpdateDialogueVolume();

	Debug:LogGreen("HandleZoneChanged triggered", API:IsInArena(), ArenaTracker:IsTrackingArena());

	if(API:IsInArena()) then
		ArenaTracker:HandleArenaEnter(isLoad);
	else
		Events:UnregisterArenaEvents();

		-- Handle exit here?
		if(ArenaTracker:IsTrackingArena()) then
			Debug:LogTemp("Zone changed calling HandleExit!");
			C_Timer.After(0, ArenaTracker.HandleArenaExit);
		end

		-- Clear the flag signifying that a current arena was loaded into after login or reload
		ArenaAnalytics.loadedIntoArena = nil;
	end
end

-- Manual management of zone change, counting only between arena and non-arena
ArenaAnalytics.wasInArena = nil;
function Events:CheckZoneChanged(isLoad)
	local isInArena = API:IsInArena();

	if(not isInArena) then
		ArenaAnalytics.hasMatchEnded = false;
	end

	if(ArenaAnalytics.wasInArena ~= isInArena) then
		ArenaAnalytics.wasInArena = isInArena;

		HandleZoneChanged(isLoad);
	end
end

local function HandleRatedUpdate(...)
	ArenaRatedInfo:UpdateRatedInfo();
	ArenaAnalytics:TryFixLastMatchRating();

	ArenaTracker:HandlePreTrackingRatedEvent();
end

-- Assigns behaviour for "global" events
-- ZONE_CHANGED_NEW_AREA: Tracks if player left the arena before it ended
function Events:HandleGlobalEvent(event, ...)
	-- Inspect debugging
	if(event == "INSPECT_READY") then
		if(Debug.HandleDebugInspect) then
			Debug:HandleDebugInspect(...);
		end
		return;
	end

	if(event == "PVP_RATED_STATS_UPDATE") then
		HandleRatedUpdate(...);
	elseif(event == "UPDATE_BATTLEFIELD_SCORE") then
		Events:CheckZoneChanged();
		ArenaTracker:HandlePreTrackingScoreEvent(...);
	elseif(event == "UPDATE_BATTLEFIELD_STATUS") then
		Events:CheckZoneChanged();
	end
end

-- Assigns behaviour for each arena event
-- UPDATE_BATTLEFIELD_SCORE: The arena may have ended, final info is grabbed and stored
-- UNIT_AURA, COMBAT_LOG_EVENT_UNFILTERED, ARENA_OPPONENT_UPDATE: Try to get more arena information (players, specs, etc)
-- CHAT_MSG_BG_SYSTEM_NEUTRAL: Detect if the arena started
function Events:HandleArenaEvent(event, ...)
	if (not API:IsInArena() or not ArenaTracker:IsTrackingArena()) then
		return;
	end

	if (event == "UPDATE_BATTLEFIELD_SCORE") then
		ArenaTracker:HandleScoreUpdate();

		if(API:GetWinner() ~= nil) then
			C_Timer.After(0, ArenaTracker.HandleArenaEnd);
		end

	elseif(event == "PVP_RATED_STATS_UPDATE") then
		ArenaTracker:HandleRatedUpdate();
		ArenaTracker:CheckRoundEnded();

	elseif (event == "UNIT_AURA") then
		ArenaTracker:ProcessUnitAuraEvent(...);

	elseif(event == "COMBAT_LOG_EVENT_UNFILTERED") then
		ArenaTracker:ProcessCombatLogEvent(...);

	elseif(event == "ARENA_OPPONENT_UPDATE" or event == "ARENA_PREP_OPPONENT_SPECIALIZATIONS") then
		ArenaTracker:HandleOpponentUpdate();

	elseif(event == "GROUP_ROSTER_UPDATE") then
		ArenaTracker:HandlePartyUpdate();

	elseif (event == "CHAT_MSG_BG_SYSTEM_NEUTRAL") then
		local msg = ...;
		ArenaTracker:HandleArenaMessages(msg);

	elseif(event == "INSPECT_READY") then
		if(API.enableInspection and Inspection and Inspection.HandleInspectReady) then
			Debug:Log(event, "triggered!");
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
	if(eventFrames.initEventFrame) then
		registerEvents(eventFrames.initEventFrame, loadEvents, Events.HandleLoadEvents);
	end
end

function Events:UnregisterLoadEvents()
	--unregisterEvents(eventFrames.initEventFrame, loadEvents);
	--eventFrames.initEventFrame = nil;
end

-- Creates "global" events
function Events:RegisterGlobalEvents()
	registerEvents(eventFrames.globalEventFrame, globalEvents, Events.HandleGlobalEvent);
end

-- Adds events used inside arenas
function Events:RegisterArenaEvents()
	registerEvents(eventFrames.arenaEventFrame, arenaEvents, Events.HandleArenaEvent);
end

-- Removes events used inside arenas
function Events:UnregisterArenaEvents()
	unregisterEvents(eventFrames.arenaEventFrame, arenaEvents);
end

-------------------------------------------------------------------------

function Events:Initialize()
	Events:RegisterLoadEvents();
end

-- Process load events before directing them towards Initialization flow in sanitized form
function Events:HandleLoadEvents(event, ...)
	if(event == "ADDON_LOADED") then
		local name = ...;
		if(name ~= "ArenaAnalytics") then
			return;
		end
	elseif(event == "PLAYER_ENTERING_WORLD") then
		local isLogin, isReload = ...;
		if(not isLogin and not isReload) then
			-- Zone change does not qualify as an initialization event
			return;
		end
	elseif(event == "UPDATE_BATTLEFIELD_STATUS" and not API:IsInArena()) then
		-- We don't care about UPDATE_BATTLEFIELD_STATUS outside of arena.
		return;
	end

	Initialization:HandleLoadEvents(event, ...);
end

-- Post initialization
local hasLoaded = false;
function Events:OnLoad()
	if(hasLoaded) then
		return;
	end
	hasLoaded = true;

	Debug:LogGreen("Events:OnLoad() triggered!");
	ArenaAnalytics.wasInArena = API:IsInArena();

	Events:RegisterGlobalEvents();

	-- Request events, in case critical events fired before loading in
	RequestRatedInfo();
end
