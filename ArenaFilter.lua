local _, ArenaAnalytics = ... -- Namespace
ArenaAnalytics.Filter = {}

local Filter = ArenaAnalytics.Filter;

-- Currently applied filters
Filter.currentFilters = {
    ["search"] = { 
        ["raw"] = "",
        ["data"] = { }
    },
    ["season"] = "All",
    ["map"] = "All", 
    ["bracket"] = "All", 
    ["comp"] = "All",
    ["enemyComp"] = "All"
};

-- Updates comp filter if there's a new comp registered
-- and updates winrate
function Filter:checkForFilterUpdate()
    if(ArenaAnalyticsScrollFrame.filterComps.dropdownFrame ~= nil) then
        -- Comp Filter
        ArenaAnalyticsScrollFrame.filterComps.dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterComps.dropdownFrame = nil;
    end
    ArenaAnalyticsScrollFrame.filterComps = nil
    ArenaAnalytics.AAtable:createDropdownForFilterComps(false);

    -- Enemy Comp Filter
    if(ArenaAnalyticsScrollFrame.filterEnemyComps.dropdownFrame ~= nil) then
        ArenaAnalyticsScrollFrame.filterEnemyComps.dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterEnemyComps.dropdownFrame = nil;
    end
    ArenaAnalyticsScrollFrame.filterEnemyComps = nil;

    ArenaAnalytics.AAtable:createDropdownForFilterComps(true);
end

function Filter:doesGameMatchSettings(arenaGame)
    local seasonCondition = false
    if ((ArenaAnalyticsSettings["seasonIsChecked"] == false and arenaGame["dateInt"] > ArenaAnalytics.Constants.currentSeasonStartInt) or ArenaAnalyticsSettings["seasonIsChecked"]) then
        seasonCondition = true
    end
    local skirmishCondition = false
    if ((ArenaAnalyticsSettings["skirmishIsChecked"] == false and arenaGame["isRanked"]) or ArenaAnalyticsSettings["skirmishIsChecked"]) then
        skirmishCondition = true
    end
    return seasonCondition and skirmishCondition
end

-- Changes the current filter upon selecting one from its dropdown
function Filter:changeFilter(args)
    ArenaAnalytics.AAtable:ClearSelectedMatches()
    local selectedFilter = args:GetAttribute("value")
    local currentFilter = args:GetAttribute("dropdownTable")
    local filterName = currentFilter.filterName
    currentFilter.selected:SetText(selectedFilter);

    ArenaAnalytics:Log(selectedFilter);

    if (filterName:find("comp") and args:GetAttribute("tooltip") ~= nil) then
        currentFilter.selected:SetText(selectedFilter)
        selectedFilter = args:GetAttribute("tooltip")
    end

    Filter.currentFilters[filterName:lower()] = selectedFilter;
    
    if currentFilter.dropdownList:IsShown() then   
        currentFilter.dropdownList:Hide();
    else
        currentFilter.dropdownList:Show();
    end

    if (filterName == "Bracket") then
        Filter.currentFilters["comp"] = "All";
        Filter.currentFilters["enemyComp"] = "All";
        ArenaAnalyticsScrollFrame.filterComps.selected:SetText("All")
        ArenaAnalyticsScrollFrame.filterEnemyComps.selected:SetText("All");

        if (selectedFilter ~= "All") then
            ArenaAnalyticsScrollFrame.filterComps.selected:Enable();
            ArenaAnalyticsScrollFrame.filterComps.selected:SetText(Filter.currentFilters["comp"]);
            ArenaAnalyticsScrollFrame.filterEnemyComps.selected:Enable();
            ArenaAnalyticsScrollFrame.filterEnemyComps.selected:SetText(Filter.currentFilters["enemyComp"]);
        else
            ArenaAnalyticsScrollFrame.filterComps.dropdownFrame:Hide();
            ArenaAnalyticsScrollFrame.filterComps.dropdownFrame = nil;
            ArenaAnalyticsScrollFrame.filterComps.selected:Disable();
            ArenaAnalyticsScrollFrame.filterComps.selected:SetText("Select bracket");
            ArenaAnalyticsScrollFrame.filterComps.selected:SetDisabledFontObject("GameFontDisableSmall")
            
            ArenaAnalyticsScrollFrame.filterEnemyComps.dropdownFrame:Hide();
            ArenaAnalyticsScrollFrame.filterEnemyComps.dropdownFrame = nil;
            ArenaAnalyticsScrollFrame.filterEnemyComps.selected:Disable();
            ArenaAnalyticsScrollFrame.filterEnemyComps.selected:SetText("Select bracket");
            ArenaAnalyticsScrollFrame.filterEnemyComps.selected:SetDisabledFontObject("GameFontDisableSmall")
        end
        
        Filter:checkForFilterUpdate();
    end
    

    ArenaAnalytics.AAtable:RefreshLayout(true);
end

function Filter:updateCompFilterFrame(isEnemyFilter)
    --ArenaAnalyticsScrollFrame.filterComps.dropdownFrame:Hide();
    --ArenaAnalyticsScrollFrame.filterComps.dropdownFrame = nil;
    --ArenaAnalyticsScrollFrame.filterComps = nil

    ArenaAnalytics.AAtable:createDropdownForFilterComps(isEnemyFilter);
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

    local bracket = ArenaAnalytics.Filter.currentFilters["bracket"];
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

        -- Filter out comps by too few matches
        for i=#playedComps, 1, -1 do
            local compTable = playedComps[i];
            if(compTable and compTable["comp"] ~= "All" and compTable["played"] <= tonumber(ArenaAnalyticsSettings["outliers"])) then
                tremove(playedComps, i);
                i = i - 1;
            end
        end
    end
    return playedComps;
end

function Filter:updateSearchFilterData(search)
    search = search or "";
    
    -- Get search table from search
    local searchFilter = {
        ["raw"] = string.gsub(search, "%s%s+", " "),
        ["data"] = {}
    };

    -- Search didn't change
    if(searchFilter["raw"] == Filter.currentFilters["search"]["raw"]) then
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
    if(searchFilter ~= Filter.currentFilters["search"]) then
        Filter.currentFilters["search"] = searchFilter;
        ArenaAnalytics.AAtable:RefreshLayout(true);
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

    if(Filter.currentFilters["search"]["data"] == "") then
        return true;
    end

    if(match ~= nil) then
        if(Filter.currentFilters["search"]["data"] == nil) then
            return true;
        end
        for k=1, #Filter.currentFilters["search"]["data"] do
            local foundMatch = false;
            local search = Filter.currentFilters["search"]["data"][k];
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

    ForceDebugNilError(Filter.currentFilters["map"]);
    if(Filter.currentFilters["map"] == "All") then
        return true;
    end
    
    local arenaMaps = {
        ["Nagrand Arena"] = "NA", 
        ["Ruins of Lordaeron"] = "RoL", 
        ["Blade Edge Arena"] = "BEA", 
        ["Dalaran Arena"] = "DA"
    }
    local filterMap = arenaMaps[Filter.currentFilters["map"]];
    if(filterMap == nil) then
        ArenaAnalytics:Log("Map filter did not match a valid map. Filter: ", Filter.currentFilters["map"]);
        -- TODO: Set current filter to All
    end

    return match["map"] == filterMap;
end

-- check bracket filter
local function doesMatchPassFilter_Bracket(match)
    if match == nil then return false end;

    if(Filter.currentFilters["bracket"] == "All") then
        return true;
    end
    return match["bracket"] == Filter.currentFilters["bracket"];
end

-- check skirmish filter
local function doesMatchPassFilter_Skirmish(match)
    if match == nil then return false end;

    ForceDebugNilError(Filter.currentFilters["map"]);
    if(ArenaAnalyticsSettings["skirmishIsChecked"]) then
        return true;
    end
    return match["isRated"];
end

-- check season filter
local function doesMatchPassFilter_Season(match)
    if match == nil then return false end;

    ForceDebugNilError(Filter.currentFilters["map"]);
    if(Filter.currentFilters["season"] == "All") then
        return true;
    end
    return match["season"] == Filter.currentFilters["season"];
end

-- check comp filters (comp / enemy comp)
local function doesMatchPassFilter_Comp(match, CompKey)
    if match == nil then return false end;

    -- Skip comp filter when no bracket is selected
    ForceDebugNilError(Filter.currentFilters["bracket"]);
    if(Filter.currentFilters["bracket"] == "All") then
        return true;
    end
    
    ArenaAnalytics:Log(Filter.currentFilters[CompKey]);
    if(Filter.currentFilters[CompKey] == "All") then
        return true;
    end

    return match[CompKey] == Filter.currentFilters[CompKey];
end

-- check all filters
function Filter:doesMatchPassAllFilters(match, excluded)
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
    if(excluded ~= "comp" and not doesMatchPassFilter_Comp(match, "comp")) then
        return false;
    end

    -- Enemy Comp
    if(excluded ~= "enemyComp" and not doesMatchPassFilter_Comp(match, "enemyComp")) then
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
    for i = 1, #ArenaAnalytics.filteredMatchHistory do
        local current = ArenaAnalytics.filteredMatchHistory[i];
        local prev = ArenaAnalytics.filteredMatchHistory[i - 1];

        if (prev and ((current["date"] + 3600 < prev["date"]) or not ArenaAnalytics:arenasHaveSameParty(current, prev))) then
            session = session + 1;
        end
        ArenaAnalytics.filteredMatchHistory[i]["session"] = session;
    end

    ArenaAnalytics:Log("refreshFilter() ", #ArenaAnalytics.filteredMatchHistory)
end