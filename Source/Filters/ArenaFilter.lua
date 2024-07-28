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

function Filters:Init() 
    AddFilter("Filter_Date", "All Time");
    AddFilter("Filter_Season", "All");
    AddFilter("Filter_Map", "All");
    AddFilter("Filter_Bracket", "All");
    AddFilter("Filter_Comp", "All");
    AddFilter("Filter_EnemyComp", "All");
end

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

    if(value == currentFilters[filter]) then
        return;
    end

    -- Reset comp filters when bracket filter changes
    if (filter == "Filter_Bracket") then
        Filters:Reset("Filter_Comp");
        Filters:Reset("Filter_EnemyComp");
    end

    --ArenaAnalytics:Log("Setting filter:", filter, "to value:", (type(value) == "string" and value:gsub("|", "||") or "nil"));
    currentFilters[filter] = value;
    
    Filters:Refresh();
end

function Filters:Reset(filter, skipOverrides)
    assert(currentFilters[filter] and defaults[filter], "Invalid filter: " .. (filter and filter or "nil"));
    local default = Filters:GetDefault(filter, skipOverrides);
    Filters:Set(filter, default);
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

    Filters:Refresh();
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
    
    Filters:Refresh();
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

    -- Bracket
    if(not doesMatchPassFilter_Bracket(match)) then
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
    if(not ArenaAnalytics.Search:DoesMatchPassSearch(match)) then
        return false;
    end

    return true;
end


-------------------------------------------------------------------------
-- Refresh processing

-- Add to ArenaHelpers.lua to help debugging cases?
local function LogTableContents(tbl, indent)
    if not indent then indent = 0 end
    local formatting = string.rep("  ", indent)
    
    for key, value in pairs(tbl) do
        if type(value) == "table" then
            ArenaAnalytics:Log(formatting .. tostring(key) .. ":")
            LogTableContents(value, indent + 1)
        else
            ArenaAnalytics:Log(formatting .. tostring(key) .. ": " .. tostring(value))
        end
    end
end

local transientCompData = {}

local function ResetTransientCompData()
    transientCompData = {
        Filter_Comp = { ["All"] = {} },
        Filter_EnemyComp = { ["All"] = {} },
    }
end

local function SafeIncrement(table, key, delta)
    table[key] = (table[key] or 0) + (delta or 1);
end

local function findOrAddCompValues(compsTable, comp, isWin, mmr)
    assert(compsTable);
    if comp == nil then return end

    compsTable[comp] = compsTable[comp] or {};
    
    -- Played
    SafeIncrement(compsTable[comp], "played");
    
    -- Win count
    if isWin then
        SafeIncrement(compsTable[comp], "wins");
    end

    -- MMR Data     (Used to convert mmr to average mmr later)
    if tonumber(mmr) then
        SafeIncrement(compsTable[comp], "mmr", tonumber(mmr));
        SafeIncrement(compsTable[comp], "mmrCount");
    end
end

local function AddToCompData(compKey, match)
    assert(compKey and transientCompData[compKey] and match);

    -- Add to "All" data
    findOrAddCompValues(transientCompData[compKey], "All", match["won"], match["mmr"]);
    
    -- Add comp specific data
    local matchCompKey = (compKey == "Filter_Comp") and "comp" or "enemyComp";
    local comp = match[matchCompKey];
    if(comp ~= nil) then
        findOrAddCompValues(transientCompData[compKey], comp, match["won"], match["mmr"]);
    end
end

local function FinalizeCompDataTables(compData)
    local compKeys = { "Filter_Comp", "Filter_EnemyComp" }
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

local function UpdateFilteredSessions()
    local session = 1
    for i = #ArenaAnalytics.filteredMatchHistory, 1, -1 do
        local current = ArenaAnalytics:GetFilteredMatch(i);
        local prev = ArenaAnalytics:GetFilteredMatch(i - 1);

        current["filteredSession"] = session;

        if not prev or prev["session"] ~= current["session"] then
            session = session + 1;
        end
    end
end

local function ProcessMatchIndex(index)
    local match = ArenaAnalytics:GetMatch(index);
    if(match and Filters:DoesMatchPassAllFilters(match, "comps")) then
        local doesPassComp = doesMatchPassFilter_Comp(match, false);
        local doesPassEnemyComp = doesMatchPassFilter_Comp(match, true);

        if(Filters:IsFilterActive("Filter_Bracket")) then
            if(doesPassEnemyComp) then
                AddToCompData("Filter_Comp", match);
            end
            
            if(doesPassComp) then
                AddToCompData("Filter_EnemyComp", match);
            end
        end

        if(doesPassComp and doesPassEnemyComp) then
            table.insert(ArenaAnalytics.filteredMatchHistory, index);
        end
    end

end

Filters.isRefreshing = nil;
-- Returns matches applying current match filters
function Filters:Refresh(onCompleteFunc)
    if(Filters.isRefreshing) then
        ArenaAnalytics:Log("Refreshing called while locked. Has onComplete: ", onCompleteFunc ~= nil);
        return;
    end
    Filters.isRefreshing = true;
    
    -- Reset tables
    ArenaAnalytics.filteredMatchHistory = {}
    ArenaAnalytics.Selection:ClearSelectedMatches();
    ResetTransientCompData();
    
    local currentIndex = 1;
    local batchDurationLimit = 0.05;

    local function Finalize()
        -- Assign session to filtered matches
        UpdateFilteredSessions();

        FinalizeCompDataTables();
        ArenaAnalytics:SetCurrentCompData(transientCompData);
        ResetTransientCompData();
    
        ArenaAnalytics.AAtable:ForceRefreshFilterDropdowns();
        ArenaAnalytics.AAtable:handleArenaCountChanged();

        if(onCompleteFunc) then
            onCompleteFunc();
        end

        Filters.isRefreshing = nil;
    end

    local function ProcessBatch()
        local batchEndTime = GetTime() + batchDurationLimit;

        while currentIndex <= #MatchHistoryDB do
            ProcessMatchIndex(currentIndex);
            currentIndex = currentIndex + 1;

            if(batchEndTime < GetTime()) then
                C_Timer.After(0, ProcessBatch);
                return;
            end
        end
        
        Finalize();
    end

    -- Start processing batches
    ProcessBatch()
end


-----------------------------------------------------------------------------
-- DEPRECATED


-- DEPRECATED
local function findOrAddCompValues_DEPRECATED(compsTable, comp, isWin, mmr)
	assert(compsTable ~= nil);	
    if(comp == nil) then return end;

	if(existingComp ~= nil) then
		compsTable[comp].played = compsTable[comp].played + 1;

		if(isWin) then
			compsTable[comp].wins = compsTable[comp].wins + 1;
		end

		if(tonumber(mmr)) then
			compsTable[comp].mmr = compsTable[comp].mmr + tonumber(mmr);
			compsTable[comp].mmrCount = compsTable[comp].mmrCount + 1;
		end
	else -- Insert new
		compsTable[comp] = {
			played = 1,
			wins = isWin and 1 or 0,
			mmr = tonumber(mmr) or 0,
			mmrCount = tonumber(mmr) and 1 or 0, -- Separated in case of missing mmr
		};
	end    
end

-- DEPRECAED
-- Get all played comps with total played and total wins for matches that pass filters
function ArenaAnalytics:GetPlayedCompsWithTotalAndWins(isEnemyComp)
    local compKey = isEnemyComp and "enemyComp" or "comp";
    local playedComps = { };
	
    local bracket = Filters:Get("Filter_Bracket");
    if(bracket == "All") then
		-- Always include an entry for "All"
		playedComps["All"] = {};

		return playedComps;
	end

	-- Make sure there's at least one entry
	findOrAddCompValues(playedComps, "All");

	-- Combine comp data
	for i=1, #MatchHistoryDB do
		local match = MatchHistoryDB[i];
		if(match and Filters:DoesMatchPassAllFilters(match, compKey)) then
            assert(match["bracket"] == bracket); -- This should be the case if it passes filters

			-- Add to "All" data
			findOrAddCompValues(playedComps, "All", match["won"], match["mmr"]);
			
			-- Add comp specific data
			local comp = match[compKey];
			if(comp ~= nil) then
				findOrAddCompValues(playedComps, comp, match["won"], match["mmr"]);
			end
		end
	end

	-- Compute winrates and average mmr
	for comp, compTable in pairs(playedComps) do
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

    return playedComps;
end