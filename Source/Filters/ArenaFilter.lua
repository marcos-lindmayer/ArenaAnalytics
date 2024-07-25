local _, ArenaAnalytics = ...; -- Addon Namespace
local Filters = ArenaAnalytics.Filters;

-- Local module aliases
local Options = ArenaAnalytics.Options;

-------------------------------------------------------------------------

-- Currently applied filters
local currentFilters = {}
local defaults = {}

-- Adds a filter, setting current and default values
local function AddFilter(filter, default)
    assert(filter ~= nil);
    assert(default ~= nil, "Nil values for filters are not supported. Using values as display texts.");

    currentFilters[filter] = default;
    defaults[filter] = default;
end

AddFilter("Filter_Date", "All Time");
AddFilter("Filter_Season", "All");
AddFilter("Filter_Map", "All");
AddFilter("Filter_Bracket", "All");
AddFilter("Filter_Comp", "All");
AddFilter("Filter_EnemyComp", "All");

function Filters:IsValidCompKey(compKey)
    return compKey == "Filter_Comp" or compKey == "Filter_EnemyComp";
end

function Filters:Get(filter)
    assert(filter and currentFilters[filter], "Invalid filter: " .. (filter or "nil"));
    return currentFilters[filter];
end

function Filters:GetDefault(filter, skipOverrides)
    -- overrides
    if(not skipOverrides) then
        if(filter == "Filter_Date" and Options:Get("defaultCurrentSessionFilter")) then
            return "Current Session";
        end

        if(filter == "Filter_Season" and Options:Get("defaultCurrentSeasonFilter")) then
            return "Current Season";
        end
    end

    return defaults[filter];
end

function Filters:Set(filter, value)
    assert(filter and currentFilters[filter]);
    value = value or Filters:GetDefault(filter);

    -- Reset comp filters when bracket filter changes
    if (filter == "Filter_Bracket") then
        Filters:Reset("Filter_Comp");
        Filters:Reset("Filter_EnemyComp");
    end

    ArenaAnalytics:Log("Setting filter:", filter, "to value:", value);
    currentFilters[filter] = value;
    
    Filters:RefreshFilters();
end

function Filters:Reset(filter, skipOverrides)
    assert(currentFilters[filter] and defaults[filter], "Invalid filter: " .. (filter and filter or "nil"));
    currentFilters[filter] = Filters:GetDefault(filter, skipOverrides);

    Filters:RefreshFilters();
end

-- Clearing filters, optionally keeping filters explicitly applied through options
function Filters:ResetAll(forceDefaults)
    currentFilters = {
        ["Filter_Date"] = Filters:GetDefault("Filter_Date", forceDefaults),
        ["Filter_Season"] = Filters:GetDefault("Filter_Season", forceDefaults),
        ["Filter_Map"] = Filters:GetDefault("Filter_Map"),
        ["Filter_Bracket"] = Filters:GetDefault("Filter_Bracket"),
        ["Filter_Comp"] = Filters:GetDefault("Filter_Comp"),
        ["Filter_EnemyComp"] = Filters:GetDefault("Filter_EnemyComp"),
    };

    ArenaAnalytics.Search:Reset();
    Filters:RefreshFilters();
end

-- DEPRECATED
-- Get the current value, defaulting to 
function Filters:GetCurrent(filter, subcategory, fallback)
    if(filter ~= nil) then
        if(subcategory ~= nil) then
            return currentFilters[filter] and currentFilters[filter][subcategory] or defaults[filter][subcategory] or fallback;
        else
            return currentFilters[filter] or defaults[filter] or fallback;
        end
    end
end

-- DEPRECATED
function Filters:GetCurrentDisplay(filter)
    if(filter == nil) then
        return "";
    end

    return currentFilters[filter]["display"] or currentFilters[filter]["data"] or currentFilters[filter] or "";
end

-- DEPRECATED
function Filters:GetCurrentData(filter)
    if(filter == nil) then
        return "";
    end

    return currentFilters[filter]["data"] or currentFilters[filter] or "";
end

-- TODO: Simplify using Filters:Get(filter) and Filters:GetDefault(filter)
function Filters:IsFilterActive(filterName)
    local filter = currentFilters[filterName];
    if (filter ~= nil) then
        return filter ~= defaults[filterName];
    end

    ArenaAnalytics:Log("isFilterActive failed to find filter: ", filterName);
    return false;
end

function Filters:getActiveFilterCount()
    local count = 0;
    if(not ArenaAnalytics.Search:IsEmpty()) then
        count = count + 1;
    end
    if(Filters:IsFilterActive("Filter_Date")) then
        count = count + 1;
    end
    if(Filters:IsFilterActive("Filter_Season")) then
        count = count + 1;
    end
    if(Filters:IsFilterActive("Filter_Map")) then
        count = count + 1;
    end
    if(Filters:IsFilterActive("Filter_Bracket")) then
        count = count + 1;
    end
    if(Filters:IsFilterActive("Filter_Comp")) then
        count = count + 1;
    end
    if(Filters:IsFilterActive("Filter_EnemyComp")) then
        count = count + 1; 
    end
    return count;
end

-- TODO: Refactor when dropdown overhaul simplifies comp filters
function Filters:SetFilter(filter, value, display)
    if(filter == nil) then
        ArenaAnalytics:Log("SetFilter failed due to nil filter");
        return;
    end

    ArenaAnalytics:Log("Setting filter: ", filter, " -- ", value, " -- ", display)

    -- Reset comp filters when bracket filter changes
    if (filter == "Filter_Bracket") then
        Filters:Reset("Filter_Comp");
        Filters:Reset("Filter_EnemyComp");
    end
    
    if (display ~= nil) then
        currentFilters[filter] = {
            ["data"] = value;
            ["display"] = display;
        }
    else
        currentFilters[filter] = value;
    end
    
    ArenaAnalytics.Selection:ClearSelectedMatches();
    Filters:RefreshFilters();
end

function Filters:SetDisplay(filter, display)
    assert(filter ~= nil);
    assert(currentFilters[filter] ~= nil);
    assert(currentFilters[filter]["display"] ~= nil); -- TODO: Decide if we wanna assert this

    -- Update the display if 
    if(currentFilters[filter]["display"]) then
        currentFilters[filter]["display"] = display;
    end
end

function Filters:ResetToDefault(filter, skipOverrides)
    -- Update the filter for the new value
    local defaultValue = Filters:GetDefault(filter, skipOverrides);
    Filters:SetFilter(filter, defaultValue);
end

-- check map filter
local function doesMatchPassFilter_Map(match)
    if match == nil then return false end;

    if(currentFilters["Filter_Map"] == "All") then
        return true;
    end
    
    local filterMap = currentFilters["Filter_Map"];
    
    if(filterMap == nil) then
        filterMap = "All"
        currentFilters["Filter_Map"] = filterMap;
    end

    return match["map"] == filterMap;
end

-- check bracket filter
local function doesMatchPassFilter_Bracket(match)
    if match == nil then return false end;

    if(currentFilters["Filter_Bracket"] == "All") then
        return true;
    end
    
    return match["bracket"] == currentFilters["Filter_Bracket"];
end

-- check season filter
local function doesMatchPassFilter_Date(match)
    if match == nil then return false end;

    local value = currentFilters["Filter_Date"] and currentFilters["Filter_Date"] or "";
    value = value and value:lower() or "";
    local seconds = 0;
    if(value == "all time" or value == "") then
        return true;
    elseif(value == "current session") then        
        return match["session"] == ArenaAnalytics:GetLatestSession();
    elseif(value == "last day") then
        seconds = 86400;
    elseif(value == "last week") then
        seconds = 604800;
    elseif(value == "last month") then -- 31 days
        seconds = 2678400;        
    elseif(value == "last 3 months") then
        seconds = 7889400;
    elseif(value == "last 6 months") then
        seconds = 15778800;
    elseif(value == "last year") then
        seconds = 31536000;
    end

    return match["date"] > (time() - seconds);
end

-- check season filter
local function doesMatchPassFilter_Season(match)
    if match == nil then return false end;

    local season = currentFilters["Filter_Season"];
    ArenaAnalyticsDebugAssert(season ~= nil);
    if(season == "All") then
        return true;
    end
    
    if(season == "Current Season") then
        return match["season"] == GetCurrentArenaSeason();
    end
    
    return match["season"] == tonumber(season);
end

-- check comp filters (comp / enemy comp)
local function doesMatchPassFilter_Comp(match, isEnemyComp)
    if match == nil then return false end;

    -- Skip comp filter when no bracket is selected
    if(currentFilters["Filter_Bracket"] == "All") then
        return true;
    end
    
    local compFilterKey = isEnemyComp and "Filter_EnemyComp" or "Filter_Comp";
    if(currentFilters[compFilterKey] == "All") then
        return true;
    end
    
    local compKey = isEnemyComp and "enemyComp" or "comp";
    return match[compKey] == currentFilters[compFilterKey];
end

function Filters:doesMatchPassGameSettings(match)
    if (not Options:Get("showSkirmish") and not match["isRated"]) then
        return false;
    end

    return true;
end

-- check all filters
function Filters:doesMatchPassAllFilters(match, excluded)
    if(not Filters:doesMatchPassGameSettings(match)) then
        return false;
    end

    -- Season
    if(not doesMatchPassFilter_Season(match)) then
        return false;
    end

    -- Map
    if(not doesMatchPassFilter_Map(match)) then
        return false;
    end

    -- Bracket
    if(not doesMatchPassFilter_Bracket(match)) then
        return false;
    end

    -- Comp
    if(excluded ~= "comp" and not doesMatchPassFilter_Comp(match, false)) then
        return false;
    end

    -- Enemy Comp
    if(excluded ~= "enemyComp" and not doesMatchPassFilter_Comp(match, true)) then
        return false;
    end

    -- Time frame
    if(not doesMatchPassFilter_Date(match)) then
        return false;
    end

    -- Search
    if(not ArenaAnalytics.Search:DoesMatchPassSearch(match)) then
        return false;
    end

    return true;
end

-- Returns matches applying current match filters
function Filters:RefreshFilters_OLD()
    ArenaAnalytics.filteredMatchHistory = {}

    for i=1, #MatchHistoryDB do
        local match = MatchHistoryDB[i];
        if(match == nil) then
            ArenaAnalytics:Log("Invalid match at index: ", i);
        elseif(Filters:doesMatchPassAllFilters(match)) then
            table.insert(ArenaAnalytics.filteredMatchHistory, i);
        end
    end

    -- Assign session to filtered matches
    local session = 1
    for i = #ArenaAnalytics.filteredMatchHistory, 1, -1 do
        local current = ArenaAnalytics:GetFilteredMatch(i)
        local prev = ArenaAnalytics:GetFilteredMatch(i - 1)

        current["filteredSession"] = session;

        if ((not prev or prev["session"] ~= current["session"])) then
            session = session + 1;
        end
    end

    -- This will also call AAtable:ForceRefreshFilterDropdowns()
    ArenaAnalytics.AAtable:handleArenaCountChanged("RefreshFilters_OLD");
end

-- TODO: Fix up this, to support multi-frame refreshing
-- Returns matches applying current match filters
function Filters:RefreshFilters(onCompleteFunc)
    ArenaAnalytics.filteredMatchHistory = {}
    
    local currentIndex = 1
    local RefreshBatchSize = 3000

    local function Finalize()
        -- Assign session to filtered matches
        local session = 1
        for i = #ArenaAnalytics.filteredMatchHistory, 1, -1 do
            local current = ArenaAnalytics:GetFilteredMatch(i)
            local prev = ArenaAnalytics:GetFilteredMatch(i - 1)
    
            current["filteredSession"] = session
    
            if not prev or prev["session"] ~= current["session"] then
                session = session + 1
            end
        end
    
        -- This will also call AAtable:ForceRefreshFilterDropdowns()
        ArenaAnalytics.AAtable:handleArenaCountChanged("RefreshFilters")

        if(onCompleteFunc) then
            onCompleteFunc();
        end
    end

    local function ProcessBatch()
        local endIndex = forceSingleFrameUpdate and #MatchHistoryDB or min(currentIndex + RefreshBatchSize - 1, #MatchHistoryDB)
    
        for i = currentIndex, endIndex do
            local match = MatchHistoryDB[i]
            if match == nil then
                ArenaAnalytics:Log("Invalid match at index: ", i)
            elseif Filters:doesMatchPassAllFilters(match) then
                table.insert(ArenaAnalytics.filteredMatchHistory, i)
            end
        end

        currentIndex = endIndex + 1

        if currentIndex <= #MatchHistoryDB then
            C_Timer.After(0, ProcessBatch)
        else
            Finalize()
        end
    end

    -- Start processing batches
    ProcessBatch()
end
