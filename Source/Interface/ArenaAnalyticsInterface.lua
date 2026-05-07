-- API adjusted functions to let calling code stay version agnostic.
local _, ArenaAnalytics = ...; -- Addon Namespace
local Interface = ArenaAnalytics.Interface;

-- Local module aliases
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local Interface_Internal = ArenaAnalytics.Interface_Internal;

-------------------------------------------------------------------------
--- Accessible interface for external AddOns.
--- Including events and direct function access.
--- Note: The Interface namespace is intended to be kept reliable. (Currently experimental!)
-------------------------------------------------------------------------

ARENAANALYTICS_GLOBAL_API = Interface;

-------------------------------------------------------------------------
--- Direct module access 
--- NOTE: Access at own risk. These are not stable.

-- All modules are accessible within the main namespace.
function Interface:GetArenaAnalyticsNamespace()
    return ArenaAnalytics;
end

function Interface:GetMatchInterface()
    return ArenaMatch;
end


-------------------------------------------------------------------------
--- Events

-- List of events triggered through EventRegistry:TriggerEvent(event, ...)
-- Register functions through EventRegistry:RegisterCallback(event, func)
-- Callback function params: func(ownerID, ...)

Interface.Events = {}

Interface.Events.MatchHistoryChanged = "Event.ArenaAnalytics.MatchHistoryChanged";
Interface.Events.FiltersRefreshed = "Event.ArenaAnalytics.FiltersRefreshed";
Interface.Events.OptionsChanged = "Event.ArenaAnalytics.OptionsChanged";

Interface.Events.RatingFixed = "Event.ArenaAnalytics.RatingFixed";  -- Payload: matchIndex


-------------------------------------------------------------------------
--- Functions

function Interface:GetMatchCount()
    return #ArenaAnalyticsDB;
end

-- Not yet implemented
function Interface:GetMatch(index)
    local match = ArenaAnalytics:GetMatch(index);
    return Interface_Internal:ConvertToReadableMatch(match);
end


function Interface:GetFilteredMatchCount()
    return ArenaAnalytics.filteredMatchCount;
end

-- Not yet implemented
function Interface:GetFilteredMatch(index)
    local filteredMatch = ArenaAnalytics:GetFilteredMatch(index);
    return Interface_Internal:ConvertToReadableMatch(filteredMatch);
end