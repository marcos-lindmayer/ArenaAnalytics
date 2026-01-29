local _, ArenaAnalytics = ...; -- Addon Namespace
local DataCollector = ArenaAnalytics.DataCollector;

-- Local module aliases
local SpecSpells = ArenaAnalytics.SpecSpells;
local API = ArenaAnalytics.API;
local Helpers = ArenaAnalytics.Helpers;
local Inspection = ArenaAnalytics.Inspection;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------

function DataCollector:Initiate()
    ArenaAnalyticsDevData = ArenaAnalyticsDevData or {};
    ArenaAnalyticsDevData.classes = ArenaAnalyticsDevData.classes or {};
    ArenaAnalyticsDevData.classlessSpells = ArenaAnalyticsDevData.classlessSpells or {};

    DataCollector:RegisterEvents();

    DataCollector.isInitiated = true;
end

-------------------------------------------------------------------------
--- Local Event Handling

-- Midnight test events
local events = { };

local eventFrame = CreateFrame("Frame");

local function IsExcludedEvent(event)
	return not event or (API.excludedEvents and API.excludedEvents[event]);
end

function DataCollector:RegisterEvents()
	for _,event in ipairs(events) do
        if(IsExcludedEvent(event)) then
            Debug:LogForced("DataCollector skipping excluded event:", event);
        elseif(not C_EventUtils.IsEventValid(event)) then
            Debug:LogForced("DataCollector skipping invalid event:", event);
        else
            eventFrame:RegisterEvent(event);
        end
	end

	eventFrame:SetScript("OnEvent", DataCollector.HandleLocalEvents);
	eventFrame.hasRegisteredEvents = true;
end

function DataCollector:HandleLocalEvents(event, ...)
    Debug:LogForced("DataCollector test event:", event);
end

-------------------------------------------------------------------------