local _, ArenaAnalytics = ... -- Namespace
ArenaAnalytics.Filter = {}

local Filter = ArenaAnalytics.Filter;

-- Local variables
local isCompFilterOn = false;

-- Currently applied filters
Filter.currentFilters = {
    ["search"] = { 
        ["raw"] = "",
        ["data"] = { }
    },
    ["map"] = "All", 
    ["bracket"] = "All", 
    ["comps"] = "All",
    ["comps2v2"] = "All", 
    ["comps3v3"] = "All", 
    ["comps5v5"] = "All",
    ["enemycomps2v2"] = "All",
    ["enemycomps3v3"] = "All",
    ["enemycomps5v5"] = "All"
};

Filter.filterCompsOpts = {
    ["2v2"] = "",
    ["3v3"] = "",
    ["5v5"] = ""
}

Filter.filterEnemyCompsOpts = {
    ["2v2"] = "",
    ["3v3"] = "",
    ["5v5"] = ""
}

-- Updates comp filter if there's a new comp registered
-- and updates winrate
function Filter:checkForFilterUpdate(bracket)
    local frameByBracketTable = {
        ["2v2"] = ArenaAnalyticsScrollFrame.filterComps["2v2"],
        ["3v3"] = ArenaAnalyticsScrollFrame.filterComps["3v3"],
        ["5v5"] = ArenaAnalyticsScrollFrame.filterComps["5v5"],
    }
    frameByBracketTable[bracket].dropdownFrame:Hide();
    frameByBracketTable[bracket].dropdownFrame = nil;
    frameByBracketTable[bracket] = nil
    ArenaAnalytics.AAtable:createDropdownForFilterComps(bracket)

    local frameByEnemyBracketTable = {
        ["2v2"] = ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"],
        ["3v3"] = ArenaAnalyticsScrollFrame.filterEnemyComps["3v3"],
        ["5v5"] = ArenaAnalyticsScrollFrame.filterEnemyComps["5v5"],
    }
    frameByEnemyBracketTable[bracket].dropdownFrame:Hide();
    frameByEnemyBracketTable[bracket].dropdownFrame = nil;
    frameByEnemyBracketTable[bracket] = nil
    ArenaAnalytics.AAtable:createDropdownForFilterEnemyComps(bracket)
    --[[ ArenaAnalyticsScrollFrame.arenaTypeMenu.buttons[1]:Click() ]]
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

-- Return specific comp's total games
-- comp is a string of space-separated classes
function Filter:getCompTotalGames(comp, isEnemyComp, games) --asd
    local _, bracket = string.gsub(comp, "-", "-")
    local bracketSize = bracket + 1;
    bracket = bracketSize .. "v" .. bracketSize;
    local compType = isEnemyComp and "enemyComp" or "comp"
    local arenasWithCompTotal = 0
    local compFilterVal, enemyCompFilterVal, opponentComp;
    if (ArenaAnalyticsScrollFrame.filterComps[bracket]) then
        compFilterVal = Filter.currentFilters["comps" .. bracket]
    end
    if (ArenaAnalyticsScrollFrame.filterEnemyComps[bracket]) then
        enemyCompFilterVal = Filter.currentFilters["enemycomps" .. bracket]
    end
    if (compType == "enemyComp" and compFilterVal ~= "All" and compFilterVal ~= "Select bracket") then
        opponentComp = {compFilterVal, "comp"};
    end
    if (compType == "comp" and enemyCompFilterVal ~= "All" and enemyCompFilterVal ~= "Select bracket") then
        opponentComp = {enemyCompFilterVal, "enemyComp"};
    end
    for i = 1, #games do
        if (#games[i][compType] == bracketSize and Filter:doesGameMatchSettings(games[i])) then
            local currentComp = table.concat(games[i][compType], "-")
            if (comp == currentComp) then
                if (opponentComp ~= nil and opponentComp[1] == table.concat(games[i][opponentComp[2]], "-")) then
                    arenasWithCompTotal = arenasWithCompTotal + 1 
                elseif (opponentComp == nil) then
                    arenasWithCompTotal = arenasWithCompTotal + 1 
                end
            end
        end
    end
    return arenasWithCompTotal
end

-- Return specific comp's winrate
-- comp is a string of space-separated classes
function Filter:getCompWinrate(comp, isEnemyComp, games)
    local compType = isEnemyComp and "enemyComp" or "comp"
    local _, bracket = string.gsub(comp, "-", "-")
    local bracketSize = bracket + 1;
    bracket = bracketSize .. "v" .. bracketSize;
    local arenasWithCompIndex = {}
    for i = 1, #games do
        if (#games[i][compType] == bracketSize and Filter:doesGameMatchSettings(games[i])) then
            local currentComp = table.concat(games[i][compType], "-")
            if (comp == currentComp) then
                table.insert(arenasWithCompIndex, i)
            end
        end
    end

    local arenasWon = 0
    for c = 1,  #arenasWithCompIndex do
        if (games[arenasWithCompIndex[c]]["won"]) then
            arenasWon = arenasWon + 1
        end
    end
    local winrate = math.floor(arenasWon * 100 / #arenasWithCompIndex)
    if (#tostring(winrate) < 2) then
        winrate = winrate .. "%"
    elseif (#tostring(winrate) < 3) then
        winrate = winrate .. "%"
    else
        winrate = winrate .. "%"
    end
    
    return winrate
end

-- Changes the current filter upon selecting one from its dropdown
function Filter:changeFilter(args)
    ArenaAnalytics.AAtable:ClearSelectedMatches()
    local selectedFilter = args:GetAttribute("value")
    local currentFilter = args:GetAttribute("dropdownTable")
    local filterName = currentFilter.filterName
    currentFilter.selected:SetText(selectedFilter)

    if (args:GetAttribute("tooltip") ~= nil) then
        local indexOfSeparator, _ = string.find(selectedFilter, "-")
        local compIcons = selectedFilter:sub(1, indexOfSeparator - 1);
        currentFilter.selected:SetText(compIcons)
        selectedFilter = args:GetAttribute("tooltip")
    end

    Filter.currentFilters[string.lower(filterName)] = selectedFilter;
    if not currentFilter.dropdownList:IsShown() then   
        currentFilter.dropdownList:Show();
    else
        currentFilter.dropdownList:Hide();
    end

    if (selectedFilter == "2v2") then
        ArenaAnalyticsScrollFrame.filterComps["2v2"].selected:SetText("All")
        Filter.currentFilters["comps3v3"] = "All"
        Filter.currentFilters["comps5v5"] = "All"
        ArenaAnalyticsScrollFrame.filterComps["2v2"].dropdownFrame:Show();
        ArenaAnalyticsScrollFrame.filterComps["3v3"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterComps["5v5"].dropdownFrame:Hide();

        ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"].selected:SetText("All");
        Filter.currentFilters["enemycomps3v3"] = "All"
        Filter.currentFilters["enemycomps5v5"] = "All"
        ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"].dropdownFrame:Show();
        ArenaAnalyticsScrollFrame.filterEnemyComps["3v3"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterEnemyComps["5v5"].dropdownFrame:Hide();
    elseif (selectedFilter == "3v3") then
        ArenaAnalyticsScrollFrame.filterComps["3v3"].selected:SetText("All");
        Filter.currentFilters["comps2v2"] = "All"
        Filter.currentFilters["comps5v5"] = "All"
        ArenaAnalyticsScrollFrame.filterComps["2v2"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterComps["3v3"].dropdownFrame:Show();
        ArenaAnalyticsScrollFrame.filterComps["5v5"].dropdownFrame:Hide();
        
        ArenaAnalyticsScrollFrame.filterEnemyComps["3v3"].selected:SetText("All");
        Filter.currentFilters["enemycomps2v2"] = "All"
        Filter.currentFilters["enemycomps5v5"] = "All"
        ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterEnemyComps["3v3"].dropdownFrame:Show();
        ArenaAnalyticsScrollFrame.filterEnemyComps["5v5"].dropdownFrame:Hide();
    elseif (selectedFilter == "5v5") then
        ArenaAnalyticsScrollFrame.filterComps["5v5"].selected:SetText("All");
        Filter.currentFilters["comps2v2"] = "All"
        Filter.currentFilters["comps3v3"] = "All"
        ArenaAnalyticsScrollFrame.filterComps["2v2"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterComps["3v3"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterComps["5v5"].dropdownFrame:Show();
        
        ArenaAnalyticsScrollFrame.filterEnemyComps["5v5"].selected:SetText("All");
        Filter.currentFilters["enemycomps2v2"] = "All"
        Filter.currentFilters["enemycomps3v3"] = "All"
        ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterEnemyComps["3v3"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterEnemyComps["5v5"].dropdownFrame:Show();
    end

    if (filterName == "Bracket" and selectedFilter ~= "All") then
        ArenaAnalyticsScrollFrame.filterComps["2v2"].selected:Enable();
        ArenaAnalyticsScrollFrame.filterComps["2v2"].selected:SetText("All");
        ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"].selected:Enable();
        ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"].selected:SetText("All");
    elseif (filterName == "Bracket") then
        ArenaAnalyticsScrollFrame.filterComps["2v2"].dropdownFrame:Show();
        ArenaAnalyticsScrollFrame.filterComps["2v2"].selected:Disable();
        ArenaAnalyticsScrollFrame.filterComps["3v3"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterComps["5v5"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterComps["2v2"].selected:SetText("Select bracket");
        ArenaAnalyticsScrollFrame.filterComps["2v2"].selected:SetDisabledFontObject("GameFontDisableSmall")
        ArenaAnalyticsScrollFrame.filterComps["3v3"].selected:SetText("All");
        ArenaAnalyticsScrollFrame.filterComps["5v5"].selected:SetText("All");
        Filter.currentFilters["comps2v2"] = "All";
        Filter.currentFilters["comps3v3"] = "All";
        Filter.currentFilters["comps5v5"] = "All";
        
        ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"].dropdownFrame:Show();
        ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"].selected:Disable();
        ArenaAnalyticsScrollFrame.filterEnemyComps["3v3"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterEnemyComps["5v5"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"].selected:SetText("Select bracket");
        ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"].selected:SetDisabledFontObject("GameFontDisableSmall")
        ArenaAnalyticsScrollFrame.filterEnemyComps["3v3"].selected:SetText("All");
        ArenaAnalyticsScrollFrame.filterEnemyComps["5v5"].selected:SetText("All");
        Filter.currentFilters["enemycomps2v2"] = "All";
        Filter.currentFilters["enemycomps3v3"] = "All";
        Filter.currentFilters["enemycomps5v5"] = "All";
    end
    
    if (Filter.currentFilters["bracket"] ~= "All" and Filter.currentFilters["comps" .. Filter.currentFilters["bracket"]] ~= "All") then 
        isCompFilterOn = true;
    else
        isCompFilterOn = false;
    end
    
    if (Filter.currentFilters["bracket"] ~= "All" and Filter.currentFilters["enemycomps" .. Filter.currentFilters["bracket"]] ~= "All") then 
        isEnemyCompFilterOn = true;
    else
        isEnemyCompFilterOn = false;
    end

    if (string.find(filterName, "enemy")) then
        Filter:updateCompFilterByEnemyFilter(selectedFilter, filterName)
    elseif (string.find(filterName, "comp")) then
        Filter:updateEnemyFilterByCompFilter(selectedFilter, filterName)
    end

    ArenaAnalytics.AAtable:RefreshLayout(true);
end

function Filter:updateEnemyFilterByCompFilter(selectedFilter, filterName) 
    local bracket
    local filter = (selectedFilter ~= "All") and selectedFilter or nil;

    if (string.find(filterName, "2v2")) then
        bracket = "2v2"
    elseif (string.find(filterName, "3v3")) then
        bracket = "3v3"
    else
        bracket = "5v5"
    end

    local frameByBracketTable = {
        ["2v2"] = ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"],
        ["3v3"] = ArenaAnalyticsScrollFrame.filterEnemyComps["3v3"],
        ["5v5"] = ArenaAnalyticsScrollFrame.filterEnemyComps["5v5"],
    }
    
    frameByBracketTable[bracket].dropdownFrame:Hide();
    frameByBracketTable[bracket].dropdownFrame = nil;
    frameByBracketTable[bracket] = nil

    Filter.filterEnemyCompsOpts = {
        ['name']='Filter' .. bracket .. '_EnemyComps',
        ['parent'] = ArenaAnalyticsScrollFrame,
        ['title']='Enemy Comp: Games | Comp | Winrate',
        ['hasIcon']= true,
        ['matches'] = Filter:getEnemyPlayedCompsAndGames(bracket, filter)[1],
        ['games'] = Filter:getEnemyPlayedCompsAndGames(bracket, filter)[2],
        ['defaultVal'] = ArenaAnalyticsScrollFrame.filterEnemyComps[bracket].selected:GetText()
    }
    ArenaAnalyticsScrollFrame.filterEnemyComps[bracket] = ArenaAnalytics.AAtable:createDropdown(Filter.filterEnemyCompsOpts)
    ArenaAnalyticsScrollFrame.filterEnemyComps[bracket].dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.filterComps["2v2"].dropdownFrame, "RIGHT", 15, 0);
    ArenaAnalytics.AAtable:RefreshLayout(true)
end

function Filter:updateCompFilterByEnemyFilter(selectedFilter, filterName) 
    local bracket
    local filter
    if (selectedFilter == "All") then
        filter = nil
    else    
        filter = selectedFilter
    end
    if (string.find(filterName, "2v2")) then
        bracket = "2v2"
    elseif (string.find(filterName, "3v3")) then
        bracket = "3v3"
    else
        bracket = "5v5"
    end

    local frameByBracketTable = {
        ["2v2"] = ArenaAnalyticsScrollFrame.filterComps["2v2"],
        ["3v3"] = ArenaAnalyticsScrollFrame.filterComps["3v3"],
        ["5v5"] = ArenaAnalyticsScrollFrame.filterComps["5v5"],
    }

    frameByBracketTable[bracket].dropdownFrame:Hide();
    frameByBracketTable[bracket].dropdownFrame = nil;
    frameByBracketTable[bracket] = nil

    Filter.filterCompsOpts = {
        ['name']='Filter' .. bracket .. '_Comps',
        ['parent'] = ArenaAnalyticsScrollFrame,
        ['title']='Comp: Games | Comp | Winrate',
        ['hasIcon']= true,
        ['matches'] = Filter:getPlayerPlayedCompsAndGames(bracket, filter)[1],
        ['games'] = Filter:getPlayerPlayedCompsAndGames(bracket, filter)[2],
        ['defaultVal'] = ArenaAnalyticsScrollFrame.filterComps[bracket].selected:GetText()
    }
    ArenaAnalyticsScrollFrame.filterComps[bracket] = ArenaAnalytics.AAtable:createDropdown(Filter.filterCompsOpts)
    ArenaAnalyticsScrollFrame.filterComps[bracket].dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.filterMap.dropdownFrame, "RIGHT", 15, 0);
    ArenaAnalytics.AAtable:RefreshLayout(true)
end

-- Returns array with all unique played comps based on bracket
-- param received. Ignores incomplete comps. Removes outliers (settings param)
function Filter:getPlayerPlayedCompsAndGames(bracket, filterEnemyComp)
    local playedComps = {"All"};
    local games = {};
    local arenaSize = tonumber(string.sub(bracket, 1, 1))
    if (bracket == nil) then
        return playedComps;
    else
        for arenaNumber = 1, #ArenaAnalyticsDB[bracket] do   
            if (#ArenaAnalyticsDB[bracket][arenaNumber]["comp"] == arenaSize and ArenaAnalyticsDB[bracket][arenaNumber]["dateInt"]) then
                if (Filter:doesGameMatchSettings(ArenaAnalyticsDB[bracket][arenaNumber])) then
                    table.sort(ArenaAnalyticsDB[bracket][arenaNumber]["comp"], function(a,b)
                        local playerClassSpec = UnitClass("player") .. "|" .. ArenaAnalytics.AAmatch:getPlayerSpec()
                        local prioA = a == playerClassSpec and 1 or 2
                        local prioB = b == playerClassSpec and 1 or 2
                        return prioA < prioB or (prioA == prioB and a < b)
                    end)
                    local compString = table.concat(ArenaAnalyticsDB[bracket][arenaNumber]["comp"], "-");
                    local lastLetter = compString:sub(-#"%|" + 1)
                    if (not tContains(playedComps, compString) and string.find(compString, "%|%-") == nil and lastLetter ~= "|") then
                        local result = {}
                        for i,v in ipairs(ArenaAnalyticsDB[bracket]) do
                            if (table.concat(v["comp"], "-") == compString and Filter:doesGameMatchSettings(v)) then
                                if (filterEnemyComp and table.concat(v["enemyComp"], "-") == filterEnemyComp) then
                                    table.insert(result, v)
                                    table.insert(games, v)
                                elseif (filterEnemyComp == nil) then
                                    table.insert(result, v)
                                    table.insert(games, v)
                                end
                            end
                        end
                        if (#result >= tonumber(ArenaAnalyticsSettings["outliers"])) then
                            table.insert(playedComps, compString)
                        end
                    end
                end
            end
        end
    end
    return {playedComps, games};
end

-- Returns array with all unique enemy played comps based on bracket
-- param received. Ignores incomplete comps. Removes outliers (settings param)
function Filter:getEnemyPlayedCompsAndGames(bracket, filterComp)
    local playedComps = {"All"};
    local games = {};
    local arenaSize = tonumber(string.sub(bracket, 1, 1))
    if (bracket == nil) then
        return playedComps;
    else
        for arenaNumber = 1, #ArenaAnalyticsDB[bracket] do   
            if (#ArenaAnalyticsDB[bracket][arenaNumber]["enemyComp"] == arenaSize and ArenaAnalyticsDB[bracket][arenaNumber]["dateInt"]) then
                if (Filter:doesGameMatchSettings(ArenaAnalyticsDB[bracket][arenaNumber])) then
                    table.sort(ArenaAnalyticsDB[bracket][arenaNumber]["enemyComp"], function(a,b)
                        return (a < b)
                    end)
                    local compString = table.concat(ArenaAnalyticsDB[bracket][arenaNumber]["enemyComp"], "-");
                    local lastLetter = compString:sub(-#"%|" + 1) -- fix for corrupted matches
                    if (not tContains(playedComps, compString) and string.find(compString, "%|%-") == nil and lastLetter ~= "|") then
                        local result = {}
                        for i,v in ipairs(ArenaAnalyticsDB[bracket]) do
                            if (table.concat(v["enemyComp"], "-") == compString and Filter:doesGameMatchSettings(v)) then
                                if (filterComp and table.concat(v["comp"], "-") == filterComp) then
                                    table.insert(result, v)
                                    table.insert(games, v)
                                elseif (filterComp == nil) then
                                    table.insert(result, v)
                                    table.insert(games, v)
                                end
                            end
                        end
                        if (#result >= tonumber(ArenaAnalyticsSettings["outliers"])) then
                            table.insert(playedComps, compString)
                        end
                    end
                end
            end
        end
    end
    return {playedComps, games};
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

        ArenaAnalytics:Log("Refreshing...");
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

local function doesMatchPassSearchFilter(match)
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

-- Returns matches applying current match filters
function Filter:applyFilters(unfilteredDB)
    local holderDB = {
        ["2v2"] = {},
        ["3v3"] = {},
        ["5v5"] = {},
    };

    local brackets = {"2v2", "3v3", "5v5"};

    -- Filter map
    local arenaMaps = {{"Nagrand Arena","NA"}, {"Ruins of Lordaeron", "RoL"}, {"Blade Edge Arena", "BEA"}, {"Dalaran Arena", "DA"}}
    if (Filter.currentFilters["map"] == "All") then
        holderDB = CopyTable(unfilteredDB);
    else
        for _,arenaMap in ipairs(arenaMaps) do
            if (Filter.currentFilters["map"] == arenaMap[1]) then
                for _, bracket in ipairs(brackets) do
                    if (#unfilteredDB[bracket] > 0) then
                        for arenaNumber = 1, #unfilteredDB[bracket] do
                            if (unfilteredDB[bracket][arenaNumber]["map"] == arenaMap[2]) then
                                table.insert(holderDB[bracket], unfilteredDB[bracket][arenaNumber]);
                            end
                        end
                    end
                end
            end
        end
    end


    -- Filter comp
    if (Filter.currentFilters["bracket"] ~= "All" and isCompFilterOn) then
        local currentCompFilter = "comps" .. Filter.currentFilters["bracket"]
        local n2v2 = #holderDB["2v2"];
        local n3v3 = #holderDB["3v3"];
        local n5v5 = #holderDB["5v5"];
        if (Filter.currentFilters["bracket"] == "2v2") then
            for arena2v2Number = n2v2, 1, - 1 do
                if (holderDB["2v2"][arena2v2Number]) then
                    local DBCompAsString = table.concat(holderDB["2v2"][arena2v2Number]["comp"], "-");
                    if (DBCompAsString ~= Filter.currentFilters["comps2v2"]) then
                        table.remove(holderDB["2v2"], arena2v2Number)
                        n2v2 = n2v2 - 1
                    end
                end
            end
        end
        if (Filter.currentFilters["bracket"] == "3v3") then
        for arena3v3Number = n3v3, 1, -1 do
                if (holderDB["3v3"][arena3v3Number]) then
                    local DBCompAsString = table.concat(holderDB["3v3"][arena3v3Number]["comp"], "-");
                    if (DBCompAsString ~= Filter.currentFilters["comps3v3"]) then
                        table.remove(holderDB["3v3"], arena3v3Number)
                        n3v3 = n3v3 - 1
                    end
                end
            end
        end
        if (Filter.currentFilters["bracket"] == "5v5") then
            for arena5v5Number = n5v5, 1, -1 do
                if (holderDB["5v5"][arena5v5Number]) then
                    local DBCompAsString = table.concat(holderDB["5v5"][arena5v5Number]["comp"], "-");
                    if (DBCompAsString ~= Filter.currentFilters["comps5v5"]) then
                        table.remove(holderDB["5v5"], arena5v5Number)
                        n5v5 = n5v5 - 1
                    end
                end
            end
        end
    end

    -- Filter enemy comp
    if (Filter.currentFilters["bracket"] ~= "All" and isEnemyCompFilterOn) then
        local currentCompFilter = "enemycomps" .. Filter.currentFilters["bracket"]
        local n2v2 = #holderDB["2v2"];
        local n3v3 = #holderDB["3v3"];
        local n5v5 = #holderDB["5v5"];
        if (Filter.currentFilters["bracket"] == "2v2") then
            for arena2v2Number = n2v2, 1, - 1 do
                if (holderDB["2v2"][arena2v2Number]) then
                    local DBCompAsString = table.concat(holderDB["2v2"][arena2v2Number]["enemyComp"], "-");
                    if (DBCompAsString ~= Filter.currentFilters["enemycomps2v2"]) then
                        table.remove(holderDB["2v2"], arena2v2Number)
                        n2v2 = n2v2 - 1
                    end
                end
            end
        end
        if (Filter.currentFilters["bracket"] == "3v3") then
        for arena3v3Number = n3v3, 1, -1 do
                if (holderDB["3v3"][arena3v3Number]) then
                    local DBCompAsString = table.concat(holderDB["3v3"][arena3v3Number]["enemyComp"], "-");
                    if (DBCompAsString ~= Filter.currentFilters["enemycomps3v3"]) then
                        table.remove(holderDB["3v3"], arena3v3Number)
                        n3v3 = n3v3 - 1
                    end
                end
            end
        end
        if (Filter.currentFilters["bracket"] == "5v5") then
            for arena5v5Number = n5v5, 1, -1 do
                if (holderDB["5v5"][arena5v5Number]) then
                    local DBCompAsString = table.concat(holderDB["5v5"][arena5v5Number]["enemyComp"], "-");
                    if (DBCompAsString ~= Filter.currentFilters["enemycomps5v5"]) then
                        table.remove(holderDB["5v5"], arena5v5Number)
                        n5v5 = n5v5 - 1
                    end
                end
            end
        end
    end
    
    -- Filter bracket
    if(Filter.currentFilters["bracket"] == "2v2") then
        holderDB["3v3"] = {}
        holderDB["5v5"] = {}
    elseif(Filter.currentFilters["bracket"] == "3v3") then
        holderDB["2v2"] = {}
        holderDB["5v5"] = {}
    elseif(Filter.currentFilters["bracket"] == "5v5") then
        holderDB["3v3"] = {}
        holderDB["2v2"] = {}
    end

    -- Filter Skirmish
    if (ArenaAnalyticsSettings["skirmishIsChecked"] == false) then
        local n2v2 = #holderDB["2v2"];
        local n3v3 = #holderDB["3v3"];
        local n5v5 = #holderDB["5v5"];

        for arena2v2Number = n2v2, 1, -1 do
            if (holderDB["2v2"][arena2v2Number]) then
                if (not holderDB["2v2"][arena2v2Number]["isRanked"]) then
                    table.remove(holderDB["2v2"], arena2v2Number)
                    n2v2 = n2v2 - 1
                end
            end
        end
        for arena3v3Number = n3v3, 1, -1 do
            if (holderDB["3v3"][arena3v3Number]) then
                if (not holderDB["3v3"][arena3v3Number]["isRanked"]) then
                    table.remove(holderDB["3v3"], arena3v3Number)
                    n3v3 = n3v3 - 1
                end
            end
        end
        for arena5v5Number = n5v5, 1, -1 do
            if (holderDB["5v5"][arena5v5Number]) then
                if (not holderDB["5v5"][arena5v5Number]["isRanked"]) then
                    table.remove(holderDB["5v5"], arena5v5Number)
                    n5v5 = n5v5 - 1
                end
            end
        end
    end

    -- Filter Season (only show current season)
    if (ArenaAnalyticsSettings["seasonIsChecked"] == false) then
        local n2v2 = #holderDB["2v2"];
        local n3v3 = #holderDB["3v3"];
        local n5v5 = #holderDB["5v5"];
        for arena2v2Number = n2v2, 1, -1 do
            if (holderDB["2v2"][arena2v2Number]) then
                if (holderDB["2v2"][arena2v2Number]["dateInt"] < ArenaAnalytics.Constants.currentSeasonStartInt) then
                    table.remove(holderDB["2v2"], arena2v2Number)
                    n2v2 = n2v2 - 1
                end
            end
        end
        for arena3v3Number = n3v3, 1, -1 do
            if (holderDB["3v3"][arena3v3Number]) then
                if (holderDB["3v3"][arena3v3Number]["dateInt"] < ArenaAnalytics.Constants.currentSeasonStartInt) then
                    table.remove(holderDB["3v3"], arena3v3Number)
                    n3v3 = n3v3 - 1
                end
            end
        end
        for arena5v5Number = n5v5, 1, -1 do
            if (holderDB["5v5"][arena5v5Number]) then
                if (holderDB["5v5"][arena5v5Number]["dateInt"] < ArenaAnalytics.Constants.currentSeasonStartInt) then
                    table.remove(holderDB["5v5"], arena5v5Number)
                    n5v5 = n5v5 - 1
                end
            end
        end
    end

    if(Filter.currentFilters["search"]["data"] ~= "") then
        for _, bracket in ipairs(brackets) do
            for i = #holderDB[bracket], 1, -1 do
                if(not doesMatchPassSearchFilter(holderDB[bracket][i])) then
                    table.remove(holderDB[bracket], i);
                    i = i - 1;
                end
            end
        end
    end

    -- Get arenas from each bracket and sort by date 
    local sortedDB = {}; 

    for i = 1, #holderDB["2v2"] do
        table.insert(sortedDB, holderDB["2v2"][i]);
    end
    for i = 1, #holderDB["3v3"] do
        table.insert(sortedDB, holderDB["3v3"][i]);
    end
    for i = 1, #holderDB["5v5"] do
        table.insert(sortedDB, holderDB["5v5"][i]);
    end
    
    table.sort(sortedDB, function (k1,k2)
        if (k1["dateInt"] and k2["dateInt"]) then
            return k1["dateInt"] > k2["dateInt"];
        end
    end)

    return sortedDB;
end