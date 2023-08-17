local _, ArenaAnalytics = ... -- Namespace
ArenaAnalytics.Filter = {}

local Filter = ArenaAnalytics.Filter;

local currentFilter = {
    ["map"] = "All", 
    ["bracket"] = "All", 
    ["comp"] = "All",
    ["enemyComp"] = "All",
};

local filteredComps = {}
local filteredEnemyComps = {}

local filteredMatches = {}

function Filter:getCurrentFilter()
    return currentFilter;
end

local Filter:resetCurrentFilter()
    currentFilter["map"] = "All";
    currentFilter["bracket"] = "All";
    currentFilter["comps"] = "All";
    currentFilter["enemyComp"] = "All";

    Filter.updateFilteredMatches();
end

function Filter:updateFilteredMatches()
    filteredMatches = getFilteredMatchData(currentFilter)
end

-- Get filtered matches, wins and comp
function Filter:getFilteredMatchData(filter)
    local matches = {}
    local wins = 0
    local comp = filter["comp"] ~= nil and filter["comp"] or "All"; -- space separated 

    local bracket = filter["bracket"] ~= nil and filter["bracket"] or "All";
    
    -- 2v2
    for index = 1, #ArenaAnalyticsDB["2v2"] do
        local match = ArenaAnalyticsDB["2v2"][index];            
        if(Filter:doesMatchPassFilter(match, filter)) then
            table.insert(matches, match);

            if(match["won"]) then
                wins = wins + 1;
            end
        end
    end

    -- 3v3
    for index = 1, #ArenaAnalyticsDB["2v2"] do
        local match = ArenaAnalyticsDB["2v2"][index];            
        if(Filter:doesMatchPassFilter(match, filter)) then
            table.insert(matches, match);

            if(match["won"]) then
                wins = wins + 1;
            end
        end
    end

    -- 5v5
    for index = 1, #ArenaAnalyticsDB["2v2"] do
        local match = ArenaAnalyticsDB["2v2"][index];            
        if(Filter:doesMatchPassFilter(match, filter)) then
            table.insert(matches, match);

            if(match["won"]) then
                wins = wins + 1;
            end
        end
    end

    -- Sort
    table.sort(matches, function (k1,k2)
        if (k1["dateInt"] and k2["dateInt"]) then
            return k1["dateInt"] > k2["dateInt"];
        end
    end)

    return matches, wins, comp;
end

function Filter:doesMatchPassFilter(match, filter)
    if(match == nil or match["mapId"] == nil) then 
        return false;
    end

    if(filter == nil) then
        return true;
    end

    -- Check bracket filter
    local bracket = filter["bracket"] ~= nil and filter["bracket"] or "All";
    if(bracket ~= "All" and bracket ~= match["bracket"]) then
        return false;
    end

    -- Check map filter
    local map = filter["map"] ~= nil and filter["map"] or "All";
    if(map ~= "All" and map ~= match["map"]) then
        return false;
    end

    -- Check team comp filter
    local comp = filter["comp"] ~= nil and filter["comp"] or "All"; -- space separated
    if(comp ~= "All") then
        local DBCompAsString = table.concat(match["comp"], "-");
        if (DBCompAsString ~= currentFilters["comp"]) then
            return false;
        end
    end
    
    -- Check enemy comp filter
    local enemyComp = filter["enemyComp"] ~= nil and filter["enemyComp"] or "All"; -- space separated
    if(enemyComp ~= "All") then
        local DBCompAsString = table.concat(match["enemyComp"], "-");
        if (DBCompAsString ~= currentFilters["enemyComp"]) then
            return false;
        end
    end
    
    return true;
end

function Filter:getCompsForFilter()
    -- Filter without team comp
    local teamFilter = CopyTable(currentFilter);
    teamFilter["comp"] = nil;
    
    -- Filter without enemy comp
    local enemyFilter = CopyTable(currentFilter);
    enemyFilter["enemyComp"] = nil;

    -- 2v2
    for index = 1, #ArenaAnalyticsDB["2v2"] do
        local match = ArenaAnalyticsDB["2v2"][index];
        local won = match["won"] ~= nil and match["won"] or false;

        if(Filter:doesMatchPassFilter(match, teamFilter)) then
            Filter.conditionalAddCompData(filteredComps, match);
        end
        
        if(Filter:doesMatchPassFilter(match, enemyFilter)) then
            Filter.conditionalAddCompData(filteredComps, match);
        end
    end

    -- 3v3
    for index = 1, #ArenaAnalyticsDB["2v2"] do
        local match = ArenaAnalyticsDB["2v2"][index];            
        local won = match["won"] ~= nil and match["won"] or false;

        if(Filter:doesMatchPassFilter(match, teamFilter)) then
            Filter.conditionalAddCompData(filteredComps, match);
        end
        
        if(Filter:doesMatchPassFilter(match, enemyFilter)) then
            Filter.conditionalAddCompData(filteredComps, match);
        end
    end

    -- 5v5
    for index = 1, #ArenaAnalyticsDB["2v2"] do
        local match = ArenaAnalyticsDB["2v2"][index];            
        local won = match["won"] ~= nil and match["won"] or false;

        if(Filter:doesMatchPassFilter(match, teamFilter)) then
            Filter.conditionalAddCompData(filteredComps, match);
        end
        
        if(Filter:doesMatchPassFilter(match, enemyFilter)) then
            Filter.conditionalAddCompData(filteredComps, match);
        end
    end
end

function Filter:conditionalAddCompData(filteredCompTable, match)
    if(filteredCompTable == nil or match["comp"] == nil) then 
        return;
    end
        
    local won = match["won"] ~= nil and match["won"] or false;
    
    -- Find existing entry and update data
    for index = 1, #filteredCompTable do
        local existingComp = filteredCompTable[index]["comp"];
        if(existingComp ~= nil and existingComp == comp) then
            existingComp["gamesPlayed"] = existingComp["gamesPlayed"] + 1;
            
            if(won == true) then
                existingComp["wins"] = existingComp["wins"] + 1;
            end

            return;
        end
    end

    -- Else insert new entry
    local newEntry = {
        ["comp"] = comp,
        ["gamesPlayed"] = 1,
        ["wins"] = won and 1 or 0,
    }

    table.insert(filteredCompTable, newEntry);
end