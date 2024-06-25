local _, ArenaAnalytics = ... -- Namespace
ArenaAnalytics.Filter = {}

local Filter = ArenaAnalytics.Filter;

-- Currently applied filters
local currentFilters = {}

local defaults = {
    ["Filter_Date"] = "All Time",
    ["Filter_Season"] = "All",
    ["Filter_Map"] = "All",
    ["Filter_Bracket"] = "All",
    ["Filter_Comp"] = "All",
    ["Filter_EnemyComp"] = "All",
}

function Filter:GetDefault(filter, skipOverrides)
    -- overrides
    if(not skipOverrides) then
        if(filter == "Filter_Date" and ArenaAnalyticsSettings["defaultCurrentSessionFilter"]) then
            return "Current Session";
        end

        if(filter == "Filter_Season" and ArenaAnalyticsSettings["defaultCurrentSeasonFilter"]) then
            return "Current Season";
        end
    end

    return defaults[filter];
end

-- Clearing filters, optionally keeping filters explicitly applied through options
function Filter:resetFilters(forceDefaults)
    currentFilters = {
        ["Filter_Search"] = { 
            ["raw"] = "",
            ["data"] = {}
        },
        ["Filter_Date"] = not forceDefaults and ArenaAnalyticsSettings["defaultCurrentSessionFilter"] and "Current Session" or defaults["Filter_Date"],
        ["Filter_Season"] = not forceDefaults and ArenaAnalyticsSettings["defaultCurrentSeasonFilter"] and "Current Season" or defaults["Filter_Season"],
        ["Filter_Map"] = defaults["Filter_Map"], 
        ["Filter_Bracket"] = defaults["Filter_Bracket"], 
        ["Filter_Comp"] = {
            ["data"] = defaults["Filter_Comp"],
            ["display"] = defaults["Filter_Comp"]
        },
        ["Filter_EnemyComp"] = {
            ["data"] = defaults["Filter_EnemyComp"],
            ["display"] = defaults["Filter_EnemyComp"]
        }
    };
end
Filter:resetFilters(false);

-- Get the current value, defaulting to 
function Filter:GetCurrent(filter, subcategory, default)
    if(filter ~= nil) then
        if(subcategory ~= nil) then
            return currentFilters[filter] and currentFilters[filter][subcategory] or default;
        else
            return currentFilters[filter] or default;
        end
    end
end

function Filter:isFilterActive(filterName)
    if(filterName == "Filter_Search") then
        return currentFilters["Filter_Search"]["raw"] ~= "";
    elseif(filterName == "Filter_Comp" or filterName == "Filter_EnemyComp") then
        return currentFilters[filterName]["data"] ~= defaults["Filter_Comp"];
    end
    
    local filter = currentFilters[filterName];
    if (filter) then
        return filter ~= defaults[filterName];
    end

    ArenaAnalytics:Log("isFilterActive failed to find filter: ", filterName);
    return false;
end

function Filter:getActiveFilterCount()
    local count = 0;
    if(Filter:isFilterActive("Filter_Search")) then 
        count = count + 1;
    end
    if(Filter:isFilterActive("Filter_Date")) then
        count = count + 1;
    end
    if(Filter:isFilterActive("Filter_Season")) then
        count = count + 1;
    end
    if(Filter:isFilterActive("Filter_Map")) then
        count = count + 1;
    end
    if(Filter:isFilterActive("Filter_Bracket")) then
        count = count + 1;
    end
    if(Filter:isFilterActive("Filter_Comp")) then
        count = count + 1;
    end
    if(Filter:isFilterActive("Filter_EnemyComp")) then
        count = count + 1; 
    end
    return count;
end

-- Changes the current filter upon selecting one from its dropdown
function Filter:changeFilter(dropdown, value, tooltip)
    ArenaAnalytics.Selection:ClearSelectedMatches();

    dropdown.selected:SetText(value);
    
    Filter:SetFilter(dropdown.filterName, value, tooltip);

    if dropdown.list:IsShown() then   
        dropdown.list:Hide();
    end    
end

function Filter:SetFilter(filter, value, display)
    if(filter == nil) then
        ArenaAnalytics:Log("SetFilter failed due to nil filter");
        return;
    end

    display = display or value;

    -- Reset comp filters when bracket filter changes
    if (filter == "Filter_Bracket") then
        currentFilters["Filter_Comp"] = {
            ["data"] = "All",
            ["display"] = "All"
        };
        currentFilters["Filter_EnemyComp"] = {
            ["data"] = "All",
            ["display"] = "All"
        };
    end
    
    if (filter == "Filter_Comp" or filter == "Filter_EnemyComp") then
        currentFilters[filter] = {
            ["data"] = value;
            ["display"] = display;
        }
    else
        currentFilters[filter] = value;
    end
    
    ArenaAnalytics.Selection:ClearSelectedMatches();
    Filter:refreshFilters();
end

local function findOrAddCompValues(comps, comp, isWin)
    if(comp == nil) then return end;

    for i,existingComp in ipairs(comps) do
        if (existingComp["comp"] == comp) then
            existingComp["played"] = existingComp["played"] + 1;

            if (isWin) then
                existingComp["wins"] = existingComp["wins"] + 1;
            end
            return;
        end
    end

    tinsert(comps, {
        ["comp"] = comp,
        ["played"] = 1,
        ["wins"] = isWin and 1 or 0
    });
end

-- Get all played comps with total played and total wins for matches that pass filters
function Filter:getPlayedCompsWithTotalAndWins(isEnemyComp)
    local compKey = isEnemyComp and "enemyComp" or "comp";
    local playedComps = {
        { ["comp"] = "All" }
    };

    local bracket = currentFilters["Filter_Bracket"];
    if(bracket ~= "All") then        
        for i=1, #MatchHistoryDB do
            local match = MatchHistoryDB[i];
            if(match and match["bracket"] == bracket and Filter:doesMatchPassAllFilters(match, compKey)) then
                local comp = match[compKey];

                if(comp ~= nil) then
                    findOrAddCompValues(playedComps, comp, match["won"]);
                end
            end
        end

        -- Compute winrates
        for i=#playedComps, 1, -1 do
            local compTable = playedComps[i];

            local played = compTable["played"] or 0;
            local wins = compTable["wins"] or 0;
            compTable["winrate"] = (played > 0) and math.floor(wins * 100 / played) or 0;
        end
    end
    return playedComps;
end

function Filter:commitSearch(search)
    search = search or "";
    
    -- Get search table from search
    local searchFilter = {
        ["raw"] = string.gsub(search, "%s%s+", " "),
        ["data"] = {}
    };

    -- Search didn't change
    if(searchFilter["raw"] == currentFilters["Filter_Search"]["raw"]) then
        return;
    end

    search = string.gsub(search, "%s+", "");

    if(search ~= "") then
        search:gsub("([^,]*)", function(player)
            if(player ~= nil and player ~= "") then
                player = player:gsub(',', '');

                local playerTable = {
                    ["alts"] = {},
                    ["explicitTeam"] = "any"
                }

                -- Parse for alts and explicit teams
                -- If first symbol is + or -, specify explicit team for the player
                local prefix = player:sub(1, 1);

                if(prefix == "+") then
                    player = player:sub(2);
                    playerTable["explicitTeam"] = "team";
                elseif(prefix == "-") then
                    player = player:sub(2);
                    playerTable["explicitTeam"] = "enemyTeam";
                end

                player:gsub("([^|]*)", function(alt)
                    alt = alt:gsub('|', '');
                    if(alt ~= nil and alt ~= "") then
                        table.insert(playerTable["alts"], alt:lower());
                    end
                end);

                table.insert(searchFilter["data"], playerTable);
            end
        end);
    end

    -- Commit search
    if(searchFilter ~= currentFilters["Filter_Search"]) then
        currentFilters["Filter_Search"] = searchFilter;
		Filter:refreshFilters();
    end
end

local function checkSearchMatch(playerName, search, team)
    if(search == nil) then
        ArenaAnalytics:Log("Empty search reached checkSearchMatch!");
        return true;
    end

    if(playerName == nil or playerName == "") then
        return false;
    end

    local stringToSearch = string.gsub(playerName:lower(), "%s+", "");

    for i=1, #search do
        local altSearch = search[i];
        if(altSearch ~= nil and altSearch ~= "") then
            local isExactSearch = #altSearch > 1 and altSearch:sub(1, 1) == '"' and altSearch:sub(-1) == '"';
            altSearch = altSearch:gsub('"', '');
            
            -- If search term is surrounded by quotation marks, check exact search
            if(isExactSearch) then
                if(not string.find(altSearch, "-")) then
                    -- Exclude server when it was excluded for an exact search term
                    stringToSearch = string.match(stringToSearch, "[^-]+");
                end
                
                if(altSearch == stringToSearch) then
                    return true;
                end
            else
                -- Fix special characters
                altSearch = altSearch:gsub("-", "%%-");
                
                if(stringToSearch:find(altSearch) ~= nil) then
                    return true;
                end
            end
        end
    end

    return false;
end

local function doesMatchPassFilter_Search(match)
    if match == nil then return false end;

    if(currentFilters["Filter_Search"]["data"] == "") then
        return true;
    end

    if(match ~= nil) then
        if(currentFilters["Filter_Search"]["data"] == nil) then
            return true;
        end
        for k=1, #currentFilters["Filter_Search"]["data"] do
            local foundMatch = false;
            local search = currentFilters["Filter_Search"]["data"][k];
            if(search ~= nil and search["alts"] ~= nil and #search["alts"] > 0) then
                local teams = (search["explicitTeam"] ~= "any") and { search["explicitTeam"] } or {"team", "enemyTeam"};
                for _, team in ipairs(teams) do
                    for j = 1, #match[team] do
                        local player = match[team][j];
                        if(player ~= nil) then
                            -- keep match if player name match the search
                            if(checkSearchMatch(player["name"]:lower(), search["alts"], team)) then
                                foundMatch = true;
                            end
                        end
                    end
                end
            else
                -- Invalid or empty search element, skipping.
                foundMatch = true;
            end

            -- Search element had no match
            if(not foundMatch) then
                return false;
            end
        end
        return true;
    end

    return false;
end

-- check map filter
local function doesMatchPassFilter_Map(match)
    if match == nil then return false end;

    if(currentFilters["Filter_Map"] == "All") then
        return true;
    end
    
    local arenaMaps = {
        ["Nagrand Arena"] = "NA", 
        ["Ruins of Lordaeron"] = "RoL", 
        ["Blade Edge Arena"] = "BEA", 
        ["Dalaran Arena"] = "DA"
    }
    local filterMap = arenaMaps[currentFilters["Filter_Map"]];
    
    if(filterMap == nil) then
        ArenaAnalytics:Log("Map filter did not match a valid map. Filter: ", currentFilters["Filter_Map"]);
        filterMap = "All"
        currentFilters["Filter_Map"] = filterMap;
        ArenaAnalyticsScrollFrame.filterMap.selected = filterMap;
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

-- check skirmish filter
local function doesMatchPassFilter_Skirmish(match)
    if match == nil then return false end;

    ForceDebugNilError(currentFilters["Filter_Map"]);
    if(ArenaAnalyticsSettings["showSkirmish"]) then
        return true;
    end
    return match["isRated"];
end

-- check season filter
local function doesMatchPassFilter_Date(match)
    if match == nil then return false end;

    local value = currentFilters["Filter_Date"] and currentFilters["Filter_Date"] or "";
    value = value:lower();
    local seconds = 0;
    if(value == "all time" or value == "") then
        return true;
    elseif(value == "current session") then        
        return match["session"] == ArenaAnalytics:getLastSession();
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
    ForceDebugNilError(season);
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
    if(currentFilters[compFilterKey]["data"] == "All") then
        return true;
    end
    
    local compKey = isEnemyComp and "enemyComp" or "comp";
    return match[compKey] == currentFilters[compFilterKey]["data"];
end

function Filter:doesMatchPassGameSettings(match)
    if (not ArenaAnalyticsSettings["showSkirmish"] and not match["isRated"]) then
        return false;
    end

    return true;
end

-- check all filters
function Filter:doesMatchPassAllFilters(match, excluded)
    if(not Filter:doesMatchPassGameSettings(match)) then
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

    -- Skirmish
    if(not doesMatchPassFilter_Skirmish(match)) then
        return false;
    end
    
    -- Season
    if(not doesMatchPassFilter_Season(match)) then
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
    if(not doesMatchPassFilter_Search(match)) then
        return false;
    end

    return true;
end

-- Returns matches applying current match filters
function Filter:refreshFilters()
    ArenaAnalytics.filteredMatchHistory = {}

    for i=1, #MatchHistoryDB do
        local match = MatchHistoryDB[i];
        if(match == nil) then
            ArenaAnalytics:Log("Invalid match at index: ", i);
        elseif(Filter:doesMatchPassAllFilters(match)) then
            table.insert(ArenaAnalytics.filteredMatchHistory, match);
        end
    end

    -- Assign session to filtered matches
    local session = 1
    for i = #ArenaAnalytics.filteredMatchHistory, 1, -1 do
        local current = ArenaAnalytics.filteredMatchHistory[i];
        local prev = ArenaAnalytics.filteredMatchHistory[i - 1];

        ArenaAnalytics.filteredMatchHistory[i]["filteredSession"] = session;

        if ((not prev or prev["session"] ~= current["session"])) then
            session = session + 1;
        end
    end

    -- This will also call AAtable:forceCompFilterRefresh()
    ArenaAnalytics.AAtable:handleArenaCountChanged();
end