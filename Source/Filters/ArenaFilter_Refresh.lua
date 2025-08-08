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
local FilterCache = ArenaAnalytics.FilterCache;

-------------------------------------------------------------------------

local BATCH_LIMIT = 0.05;
local BACKGROUND_BATCH_LIMIT = 0.01;
local NEW_BATCH_FORCE_MINIMUM = 25; -- Minimum matches before allowing forced new refresh. (To avoid UI jitter)

local function GetBatchLimit()
    if(Filters.forcedQuickRefresh) then
        return 0.15;
    end

    return ArenaAnalyticsScrollFrame:IsShown() and BATCH_LIMIT or BACKGROUND_BATCH_LIMIT;
end

-------------------------------------------------------------------------

local cachedActiveFilters = {};

-- Custom date filter conversion & possible func override
local function CacheActiveFilter_Date(value, func)
    local seconds = 0;

    if(value == "all time" or value == "") then
        return true;
    elseif(value == "current session") then
        -- LastSession, funcOverride
        return Sessions:GetLatestSession(), Filters.DoesMatchPassFilter_Session;
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

    return (time() - seconds), func;
end


local function CacheActiveFilter(filter, func)
    assert(filter and type(func) == "function");

    if(not Filters:IsFilterActive(filter, true)) then
        return;
    end

    local value = Filters:Get(filter);
    value = tonumber(value) or Helpers:ToSafeLower(value);

    if(filter == Filters.FilterKeys.Date) then
        -- Optionally override func
        value, func = CacheActiveFilter_Date(value, func);
    elseif(filter == Filters.FilterKeys.Season) then
        if(value == "current season") then
            value = API:GetCurrentSeason();
        end
    end

    -- Combine cache data
    local data = TablePool:Acquire();
    data.filter = filter;
    data.value = value;
    data.doesMatchPassFunc = func;

    tinsert(cachedActiveFilters, data);
end


-- Cache sanitized active filters, in order of processing during refresh pass. (Fast to slow)
function Filters:UpdateActiveCache()
    wipe(cachedActiveFilters);

    local keys = Filters.FilterKeys;

    cachedActiveFilters.hasBracketFilter = Filters:IsFilterActive(keys.Bracket);

    -- Fast to slow filter keys
    CacheActiveFilter(keys.Date,          Filters.DoesMatchPassFilter_Date);
    CacheActiveFilter(keys.Season,        Filters.DoesMatchPassFilter_Season);
    CacheActiveFilter(keys.Map,           Filters.DoesMatchPassFilter_Map);
    CacheActiveFilter(keys.Outcome,       Filters.DoesMatchPassFilter_Outcome);
    CacheActiveFilter(keys.Bracket,       Filters.DoesMatchPassFilter_Bracket);

    -- Comps
    CacheActiveFilter(keys.Mirror,        Filters.DoesMatchPassFilter_Mirror);
    CacheActiveFilter(keys.TeamComp,      Filters.DoesMatchPassFilter_Comp);
    CacheActiveFilter(keys.EnemyComp,     Filters.DoesMatchPassFilter_EnemyComp);

    -- Search handled differently. TBD.
    cachedActiveFilters.hasActiveSearch = not Search:IsEmpty();

    Debug:Log("Updated active cache.", #cachedActiveFilters);
end


-------------------------------------------------------------------------
-- Per filter passes


-- Check map filter
function Filters:DoesMatchPassFilter_Map(match, filterValue)
    return filterValue == ArenaMatch:GetMapID(match);
end


-- Check outcome filter
function Filters:DoesMatchPassFilter_Outcome(match, filterValue)
    return filterValue == ArenaMatch:GetMatchOutcome(match);
end


-- Check outcome filter
function Filters:DoesMatchPassFilter_Mirror(match)
    -- Team comp == enemy comp
    local teamComp = ArenaMatch:GetComp(match, false);
    local enemyComp = ArenaMatch:GetComp(match, true);

    -- Both valid and equal
    return teamComp and teamComp == enemyComp;
end


-- Check bracket filter
function Filters:DoesMatchPassFilter_Bracket(match, filterValue)
    return filterValue == ArenaMatch:GetBracketIndex(match);
end


-- Check season filter
function Filters:DoesMatchPassFilter_Date(match, filterValue)
    return filterValue < (ArenaMatch:GetDate(match) or 0);
end


-- Check session (Used as override for current session Date filter)
function Filters:DoesMatchPassFilter_Session(match, filterValue)
    return filterValue == ArenaMatch:GetSession(match);
end


-- Check season filter
function Filters:DoesMatchPassFilter_Season(match, filterValue)
    return filterValue == ArenaMatch:GetSeason(match);
end


-- Check team comp
function Filters:DoesMatchPassFilter_Comp(match, comp)
    return ArenaMatch:HasComp(match, comp, false);
end


-- Check enemy comp
function Filters:DoesMatchPassFilter_EnemyComp(match, comp)
    return ArenaMatch:HasComp(match, comp, true);
end


-- Check addon settings for filters
function Filters:DoesMatchPassSettings(match)
    local matchType = ArenaMatch:GetMatchType(match);

    if (not Options:Get("showSkirmish") and matchType == "skirmish") then
        return false;
    end

    if (not Options:Get("showWarGames") and matchType == "wargame") then
        return false;
    end

    return true;
end


-------------------------------------------------------------------------


function Filters:DoesMatchPass(match)
    if(not match) then
        return nil;
    end

    -- TODO: Convert to multi-select MoreFilters?
    if(not Filters:DoesMatchPassSettings(match)) then
        return false;
    end

    -- Check all active filters
    local failedFilter = nil;
    for i,data in ipairs(cachedActiveFilters) do
        if(not data:doesMatchPassFunc(match, data.value)) then
            if(failedFilter ~= nil) then
                -- Second failed, no cache data required
                return false;
            end

            failedFilter = data.filter;
        end
    end

    -- Check search
    if(cachedActiveFilters.hasActiveSearch) then
        if(not Search:DoesMatchPassSearch(match)) then
            if(failedFilter ~= nil) then
                return false;
            end

            return false, "search";
        end
    end

    if(not failedFilter) then
        return true;
    end

    return false, failedFilter;
end

-------------------------------------------------------------------------
-- Refresh processing
-- TODO: Move comp data to FilterCache module

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
                compTable.winrate = Helpers:GetSafePercentage(wins, played, 3); -- Keep 3 decimals for sorting accuracy. (Rounded by UI)

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

    local success, failedContext = Filters:DoesMatchPass(match);

    if(cachedActiveFilters.hasBracketFilter) then
        if(success or failedContext == Filters.FilterKeys.TeamComp) then
            AddToCompData(match, false);
        end

        if(success or failedContext == Filters.FilterKeys.EnemyComp) then
            AddToCompData(match, true, index);
        end
    end

    if(success) then
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
    Filters:UpdateActiveCache();

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
            C_Timer.After(0, function() Filters:Refresh_Internal() end);
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