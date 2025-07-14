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

local BATCH_LIMIT = 0.05;
local BACKGROUND_BATCH_LIMIT = 0.01;
local NEW_BATCH_FORCE_MINIMUM = 25; -- Minimum matches before allowing forced new refresh. (To avoid UI jitter)

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

local function GetBatchLimit()
    if(Filters.forcedQuickRefresh) then
        return 0.2;
    end

    return ArenaAnalyticsScrollFrame:IsShown() and BATCH_LIMIT or BACKGROUND_BATCH_LIMIT;
end

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

function Filters:Init()
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

    Debug:LogTemp("Attempting to set filter:", filter, value, skipRefresh);
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

    changed = Filters:ResetFast(Filters.FilterKeys.Date, skipOverrides) or changed;
    changed = Filters:ResetFast(Filters.FilterKeys.Season, skipOverrides) or changed;
    changed = Filters:ResetFast(Filters.FilterKeys.Map) or changed;
    changed = Filters:ResetFast(Filters.FilterKeys.Outcome) or changed;
    changed = Filters:ResetFast(Filters.FilterKeys.Mirror) or changed;
    changed = Filters:ResetFast(Filters.FilterKeys.Bracket) or changed;
    changed = Filters:ResetFast(Filters.FilterKeys.TeamComp) or changed;
    changed = Filters:ResetFast(Filters.FilterKeys.EnemyComp) or changed;

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
    if(Filters:IsFilterActive(Filters.FilterKeys.Date, true)) then
        count = count + 1;
    end
    if(Filters:IsFilterActive(Filters.FilterKeys.Season, true)) then
        count = count + 1;
    end
    if(Filters:IsFilterActive(Filters.FilterKeys.Map, true)) then
        count = count + 1;
    end
    if(Filters:IsFilterActive(Filters.FilterKeys.Outcome, true)) then
        count = count + 1;
    end
    if(Filters:IsFilterActive(Filters.FilterKeys.Bracket, true)) then
        count = count + 1;
    end
    if(Filters:IsFilterActive(Filters.FilterKeys.TeamComp, true)) then
        count = count + 1;
    end
    if(Filters:IsFilterActive(Filters.FilterKeys.EnemyComp, true)) then
        count = count + 1;
    end
    return count;
end

-- check map filter
local function doesMatchPassFilter_Map(match)
    if match == nil then return false end;

    local filter = Filters:Get(Filters.FilterKeys.Map);
    if(not filter or filter == "All") then
        return true;
    end

    return ArenaMatch:GetMapID(match) == filter;
end

-- check outcome filter
local function doesMatchPassFilter_Outcome(match)
    if match == nil then
        return false;
    end

    local filter = Filters:Get(Filters.FilterKeys.Outcome);
    if(not filter or filter == "All") then
        return true;
    end

    return ArenaMatch:GetMatchOutcome(match) == filter;
end

-- check outcome filter
local function doesMatchPassFilter_Mirror(match)
    if match == nil then
        return false;
    end

    if(not Filters:Get(Filters.FilterKeys.Mirror)) then
        return true;
    end

    -- Team comp == enemy comp
    local teamComp = ArenaMatch:GetComp(match, false);
    local enemyComp = ArenaMatch:GetComp(match, true);

    -- Both valid and equal
    return teamComp and teamComp == enemyComp;
end

-- check bracket filter
local function doesMatchPassFilter_Bracket(match)
    if not match then
        return false;
    end

    if(Filters:Get(Filters.FilterKeys.Bracket) == "All") then
        return true;
    end

    return ArenaMatch:GetBracketIndex(match) == Filters:Get(Filters.FilterKeys.Bracket);
end

-- check season filter
local function doesMatchPassFilter_Date(match)
    if match == nil then return false end;

    local value = Filters:Get(Filters.FilterKeys.Date);
    value = Helpers:ToSafeLower(value);

    local seconds = 0;
    if(value == "all time" or value == "") then
        return true;
    elseif(value == "current session") then        
        return ArenaMatch:GetSession(match) == Sessions:GetLatestSession();
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

    return (ArenaMatch:GetDate(match) or 0) > (time() - seconds);
end

-- check season filter
local function doesMatchPassFilter_Season(match)
    if match == nil then return false end;

    local season = Filters:Get(Filters.FilterKeys.Season);
    Debug:Assert(season ~= nil);
    if(season == "All") then
        return true;
    end

    if(season == "Current Season") then
        return ArenaMatch:GetSeason(match) == API:GetCurrentSeason();
    end

    return ArenaMatch:GetSeason(match) == tonumber(season);
end

-- check comp filters (comp / enemy comp)
local function doesMatchPassFilter_Comp(match, isEnemyComp)
    if match == nil then
        return false;
    end

    -- Skip comp filter when no bracket is selected
    if(Filters:Get(Filters.FilterKeys.Bracket) == "All") then
        return true;
    end

    local compFilterKey = isEnemyComp and Filters.FilterKeys.EnemyComp or Filters.FilterKeys.TeamComp;
    local comp = Filters:Get(compFilterKey);

    local matchComp = ArenaMatch:GetComp(match, isEnemyComp);
    if(matchComp == "42|91" and isEnemyComp) then
        Debug:LogEscaped("doesMatchPassFilter_Comp", isEnemyComp, matchComp, comp, compFilterKey);
    end

    if(comp == "All") then
        return true;
    end

    return ArenaMatch:HasComp(match, comp, isEnemyComp);
end

function Filters:doesMatchPassGameSettings(match)
    local matchType = ArenaMatch:GetMatchType(match);
    if (not Options:Get("showSkirmish") and matchType == "skirmish") then
        return false;
    end

    if (not Options:Get("showWarGames") and matchType == "wargame") then
        return false;
    end

    return true;
end

-- check all filters
function Filters:DoesMatchPassAllFilters(match, excluded)
    if(not match) then
        return false;
    end

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

    -- Outcome
    if(not doesMatchPassFilter_Outcome(match)) then
        return false;
    end

    -- Bracket
    if(not doesMatchPassFilter_Bracket(match)) then
        return false;
    end

    -- TODO: Decide how this interacts with comp exclusions
    -- Mirror matches only
    if(not doesMatchPassFilter_Mirror(match)) then
        return false;
    end

    -- Comp
    if(excluded ~= "comps" and excluded ~= "comp" and not doesMatchPassFilter_Comp(match, false)) then
        return false;
    end

    -- Enemy Comp
    if(excluded ~= "comps" and excluded ~= "enemyComp" and not doesMatchPassFilter_Comp(match, true)) then
        return false;
    end

    -- Time frame
    if(not doesMatchPassFilter_Date(match)) then
        return false;
    end

    -- Search
    if(not Search:DoesMatchPassSearch(match)) then
        return false;
    end

    return true;
end


-------------------------------------------------------------------------
-- Refresh processing

local transientCompData = TablePool:Acquire();

local function ResetTransientCompData()
    TablePool:Release(transientCompData);

    transientCompData = {
        Filter_Comp = { ["All"] = TablePool:Acquire() },
        Filter_EnemyComp = { ["All"] = TablePool:Acquire() },
    };
end

local function SafeIncrement(table, key, delta)
    table[key] = (table[key] or 0) + (delta or 1);
end

local lastIndex = nil;
local function findOrAddCompValues(compsTable, comp, isWin, mmr, isEnemy)
    assert(compsTable);
    if comp == nil then
        return;
    end

    compsTable[comp] = compsTable[comp] or TablePool:Acquire();
    local compData = compsTable[comp];

    -- Played
    SafeIncrement(compData, "played");

    if(comp == "42|91" and isEnemy) then
        Debug:LogTemp("findOrAddCompValues for comp:", comp, compData.played, lastIndex, isEnemy);
    end

    -- Win count
    if isWin then
        SafeIncrement(compData, "wins");
    end

    -- MMR Data     (Used to convert mmr to average mmr later)
    if tonumber(mmr) then
        SafeIncrement(compData, "mmr", tonumber(mmr));
        SafeIncrement(compData, "mmrCount");
    end
end

local function AddToCompData(match, isEnemyTeam, index)
    assert(match);
    local compKey = isEnemyTeam and Filters.FilterKeys.EnemyComp or Filters.FilterKeys.TeamComp;
    transientCompData[compKey] = transientCompData[compKey] or TablePool:Acquire();

    local function AddData(comp, outcome, mmr)
        local isWin = (outcome == 1);

        -- Add to "All" data
        findOrAddCompValues(transientCompData[compKey], "All", isWin, mmr);

        -- Add comp specific data
        if(comp ~= nil) then
            findOrAddCompValues(transientCompData[compKey], comp, isWin, mmr, isEnemyTeam);
        end
    end

    if(ArenaMatch:IsShuffle(match)) then
        local rounds = ArenaMatch:GetRounds(match);
        local roundCount = rounds and #rounds or 0;

        for roundIndex=1, roundCount do
            local comp, outcome, mmr = ArenaMatch:GetCompInfo(match, isEnemyTeam, roundIndex);
            AddData(comp, outcome, mmr);
        end
    else
        local comp, outcome, mmr = ArenaMatch:GetCompInfo(match, isEnemyTeam);
        AddData(comp, outcome, mmr);
    end
end

local function FinalizeCompDataTables()
    local compKeys = { Filters.FilterKeys.TeamComp, Filters.FilterKeys.EnemyComp }
    for _,compKey in ipairs(compKeys) do
        -- Compute winrates and average mmr
        local compData = transientCompData[compKey];
        if(compData) then
            for _, compTable in pairs(compData) do
                -- Calculate winrate
                local played = tonumber(compTable.played) or 0;
                local wins = tonumber(compTable.wins) or 0;
                compTable.winrate = (played > 0) and math.floor(wins * 100 / played) or 0;

                -- Calculate average MMR
                local mmr = tonumber(compTable.mmr);
                local mmrCount = tonumber(compTable.mmrCount);
                if mmr and mmrCount and mmrCount > 0 then
                    compTable.mmr = math.floor(mmr / mmrCount);
                    compTable.mmrCount = nil;
                else
                    -- No MMR data
                    compTable.mmr = nil;
                    compTable.mmrCount = nil;
                end
            end
        end
    end
end

local function CommitTransientCompData()
    FinalizeCompDataTables();
    ArenaAnalytics:SetCurrentCompData(transientCompData);
    ResetTransientCompData();
end

local lastSession = nil;
local lastFilteredSession = nil;

local function ProcessMatchIndex(index)
    assert(index);

    local match = ArenaAnalytics:GetMatch(index);
    if(not match) then
        return;
    end

    if(not Filters:DoesMatchPassAllFilters(match, "comps")) then -- All except comps checked
        return;
    end

    local doesPassComp = doesMatchPassFilter_Comp(match, false);
    local doesPassEnemyComp = doesMatchPassFilter_Comp(match, true);

    if(Filters:IsFilterActive(Filters.FilterKeys.Bracket)) then
        lastIndex = index;

        if(doesPassEnemyComp) then
            AddToCompData(match, false);
        end

        if(doesPassComp) then
            AddToCompData(match, true, index);
        end
    end

    if(doesPassComp and doesPassEnemyComp) then
        -- Real match sessions
        local session = ArenaMatch:GetSession(match);

        -- New filtered session
        local filteredSession = lastFilteredSession or 0;
        if(session and session ~= lastSession) then
            filteredSession = filteredSession + 1;
        end

        local newIndex = ArenaAnalytics.filteredMatchCount + 1;

        -- Add to filtered history
        ArenaAnalytics.filteredMatchHistory[newIndex] = ArenaAnalytics.filteredMatchHistory[newIndex] or TablePool:Acquire();
        local entry = ArenaAnalytics.filteredMatchHistory[newIndex];
        entry.index = index;
        entry.filteredSession = filteredSession;

        ArenaAnalytics.filteredMatchCount = newIndex;

        -- Update last match cache
        lastSession = session;
        lastFilteredSession = filteredSession;
    end
end

Filters.isRefreshing = nil;
Filters.forceNewRefresh = nil;

local function Refresh_Internal()
    -- Reset tables
    ArenaAnalytics.filteredMatchCount = 0;
    Selection:ClearSelectedMatches();
    ResetTransientCompData();

    Filters.forceNewRefresh = nil;

    local currentIndex = #ArenaAnalyticsDB;
    lastSession = nil;
    lastFilteredSession = nil;

    local startTime = GetTimePreciseSec();

    AAtable:ForceRefreshFilterDropdowns(true);

    local function Finalize()
        Filters.forceNewRefresh = nil;
        Filters.isRefreshing = false;
        Filters.forcedQuickRefresh = nil;

        CommitTransientCompData();

        AAtable:ForceRefreshFilterDropdowns();
        AAtable:HandleArenaCountChanged();

        -- Log timing
        local newTime = GetTimePreciseSec();
        local elapsed = 1000 * (newTime - startTime);
        Debug:Log("Refreshed filters in:", elapsed, "ms.");

        Filters.isRefreshing = nil;
    end

    local function ProcessBatch()
        local batchEndTime = GetTimePreciseSec() + GetBatchLimit();

        while currentIndex > 0 do
            if(Filters.forceNewRefresh and currentIndex > NEW_BATCH_FORCE_MINIMUM) then
                -- Avoid flicker by letting slightly more than a full page pass before letting forceNewRefresh handle new refresh attempt
                break;
            end

            ProcessMatchIndex(currentIndex);
            currentIndex = currentIndex - 1;

            if(batchEndTime < GetTimePreciseSec()) then
                AAtable:HandleArenaCountChanged();
                C_Timer.After(0, ProcessBatch);
                return;
            end
        end

        if(Filters.forceNewRefresh) then
            -- Restart refresh next frame
            C_Timer.After(0, function()
                Debug:LogTemp("Forcing new refresh");
                Filters:Refresh_Internal();
            end);
            return;
        end

        Finalize();
    end

    -- Start processing batches
    ProcessBatch();
end

-- Returns matches applying current match filters
function Filters:Refresh(forcedQuickRefresh)
    if(Filters.isRefreshing ~= nil) then
        Debug:LogWarning("Refreshing called while locked. Has onComplete: ", Filters.forceNewRefresh);
        Filters.forceNewRefresh = true;
        return;
    end
    Filters.isRefreshing = true;
    Filters.forceNewRefresh = false;

    Filters.forcedQuickRefresh = forcedQuickRefresh and true;

    Refresh_Internal();
end