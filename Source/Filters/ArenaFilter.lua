local _, ArenaAnalytics = ...; -- Addon Namespace
local Filters = ArenaAnalytics.Filters;

-- Local module aliases
local Options = ArenaAnalytics.Options;
local Search = ArenaAnalytics.Search;
local Selection = ArenaAnalytics.Selection;
local AAtable = ArenaAnalytics.AAtable;
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local TablePool = ArenaAnalytics.TablePool;
local Sessions = ArenaAnalytics.Sessions;
local Debug = ArenaAnalytics.Debug;
local API = ArenaAnalytics.API;
local Helpers = ArenaAnalytics.Helpers;

-------------------------------------------------------------------------

Filters.FilterKeys = {
    Date = "Filter_Date",
    Season = "Filter_Season",
    Map = "Filter_Map",
    Outcome = "Filter_Outcome",
    Mirror = "Filter_Mirror",
    Bracket = "Filter_Bracket",
    EnemyComp = "Filter_EnemyComp",
    TeamComp = "Filter_Comp",
};

-- Currently applied filters
local currentFilters = {}
local defaults = {}

-- Adds a filter, setting current and default values
local function AddFilter(filter, default)
    assert(filter ~= nil);
    assert(default ~= nil, "Nil values for filters are not supported. Using values as display texts.");

    local override = Filters:GetOverride(filter);

    if(override ~= nil) then
        currentFilters[filter] = override;
    else
        currentFilters[filter] = default;
    end

    defaults[filter] = default;
end

function Filters:Initialize()
    AddFilter(Filters.FilterKeys.Date, "All Time");
    AddFilter(Filters.FilterKeys.Season, "All");
    AddFilter(Filters.FilterKeys.Map, "All");
    AddFilter(Filters.FilterKeys.Outcome, "All");
    AddFilter(Filters.FilterKeys.Mirror, false);
    AddFilter(Filters.FilterKeys.Bracket, "All");
    AddFilter(Filters.FilterKeys.TeamComp, "All");
    AddFilter(Filters.FilterKeys.EnemyComp, "All");
end

function Filters:IsValidCompKey(compKey)
    return compKey == Filters.FilterKeys.TeamComp or compKey == Filters.FilterKeys.EnemyComp;
end

function Filters:Get(filter)
    assert(filter, "Invalid filter in Filters:Get - Filter: " .. tostring(filter));

    if(currentFilters[filter] == nil) then
        currentFilters[filter] = Filters:GetDefault(filter);
    end

    return currentFilters[filter];
end

function Filters:GetOverride(filter)
    if(filter == Filters.FilterKeys.Date and Options:Get("defaultCurrentSessionFilter")) then
        return "Current Session";
    end

    if(filter == Filters.FilterKeys.Season and Options:Get("defaultCurrentSeasonFilter")) then
        return "Current Season";
    end
end

function Filters:GetDefault(filter, skipOverrides)
    -- overrides
    if(not skipOverrides) then
        local override = Filters:GetOverride(filter);
        if(override ~= nil) then
            return override;
        end
    end

    return defaults[filter];
end

function Filters:Set(filter, value, skipRefresh)
    assert(filter and currentFilters[filter] ~= nil);

    if(value == nil) then
        value = Filters:GetDefault(filter);
    end

    if(value == Filters:Get(filter)) then
        return false;
    end

    -- Reset comp filters when bracket filter changes
    if (filter == Filters.FilterKeys.Bracket) then
        Filters:ResetFast(Filters.FilterKeys.TeamComp);
        Filters:ResetFast(Filters.FilterKeys.EnemyComp);
    end

    Debug:LogEscaped("Setting filter:", filter, "to value:", value);
    currentFilters[filter] = value;

    if(not skipRefresh) then
        Filters:Refresh();
    end

    return true;
end

function Filters:ResetFast(filter, skipOverrides)
    assert(filter and currentFilters[filter] ~= nil and defaults[filter] ~= nil, "Invalid filter: " .. (filter and filter or "nil"));
    local default = Filters:GetDefault(filter, skipOverrides);

    -- Return true if value changed
    return Filters:Set(filter, default, true);
end

function Filters:Reset(filter, skipOverrides)
    local changed = Filters:ResetFast(filter, skipOverrides);

    if(changed) then
        Filters:Refresh();
    end

    return changed;
end

-- Clearing filters, optionally keeping filters explicitly applied through options
function Filters:ResetAll(skipOverrides)
    local changed = false;

    for _,filter in pairs(Filters.FilterKeys) do
        changed = Filters:ResetFast(filter, skipOverrides) or changed;
    end

    changed = Search:Reset() or changed;

    if(changed) then
        Debug:Log("Filters has been reset. Refreshing.");
        Filters:Refresh();
    end
end

function Filters:IsFilterActive(filter, ignoreOverrides)
    local current = Filters:Get(filter);
    if (current ~= nil) then
        return current ~= Filters:GetDefault(filter, ignoreOverrides);
    end

    Debug:LogWarning("isFilterActive failed to find filter: ", filter);
    return false;
end

function Filters:GetActiveFilterCount()
    local count = 0;

    if(not Search:IsEmpty()) then
        count = count + 1;
    end

    for _,filter in pairs(Filters.FilterKeys) do
        if(Filters:IsFilterActive(filter, true)) then
            count = count + 1;
        end
    end

    return count;
end

