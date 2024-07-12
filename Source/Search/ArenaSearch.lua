local _, ArenaAnalytics = ... -- Addon Namespace
local Search = ArenaAnalytics.Search;

-- Local module aliases
local Options = ArenaAnalytics.Options;
local Constants = ArenaAnalytics.Constants;

-------------------------------------------------------------------------

-- DOCUMENTATION
-- Player Name
--  Charactername // name:Charactername // n:Charactername // Charactername-server // etc

-- Alts
--  altone/alttwo/altthree // name:ltone/alttwo/altthree // n:ltone/alttwo/altthree
--  Consider support for space separated alts?

-- Class
--  Death Knight // DK // class:Death Knight // class:DeathKnight // class:DK // c:DK // etc

-- Spec
--  Frost // spec:frost // spec:frost // s:frost
--  Frost Mage // spec:frost mage // s:frost mage
 
-- Race
--  Undead // race:undead // r:undead

-- Role
--  Tank // Healer // Damage // role:healer // etc

-- Logical keywords
--  not: placed anywhere in a player segment to inverse the value
--  ! (exclamation mark) prefixes tokens to fails if the token would've passed

-- Team
--  Team:Friend // t:team // t:enemy // t:foe // !t:foe

-- Exact Search:
--  Wrap one or more terms in quotation marks to require an exact match
--  Decide what to do when exact search start and end among different players


-- Helper function 
function Search:SafeToLower(value)
    if(value and type(value) == "string") then
        return value:lower();
    end
    return value;
end

-- The current search data
Search.current = {
    ["raw"] = "", -- The raw search string
    ["display"] = "", -- Search string sanitized and colored(?) for display
    ["data"] = nil, -- Search data as a table for efficient comparisons
}

local activeSearchData = {};

local function ResetActiveData()
    activeSearchData = { segments = {}, nonInversedCount = 0 }
end
ResetActiveData();

---------------------------------
-- Search matching logic
---------------------------------

local function CheckPlayerName(playerName, searchValue, isExact)    
    if(not playerName or not searchValue or searchValue == "") then
        return false;
    end

    playerName = playerName:lower();

    if(isExact) then
        if(not searchValue:find("-")) then
            return searchValue == playerName:match("[^-]+");
        else
            return searchValue == playerName:gsub("-", "%%-");
        end
    end

    -- Not exact (Partial search token)
    return playerName:gsub("-", "%-"):find(searchValue) ~= nil;
end

-- NOTE: This is the main part to modify to handle actual token matching logic
-- Returns true if a given type on a player matches the given value
local function CheckTypeForPlayer(searchType, token, player)
    assert(token and token["value"] and token["value"] ~= "");
    assert(player ~= nil);
    
    if(searchType == nil) then
        ArenaAnalytics:Log("Invalid type reached CheckTypeForPlayer for search.");
        return;
    end
    -- Alt search
    if (searchType == "alts") then
        if(token["value"]:find('/') ~= nil) then
            local name = Search:SafeToLower(player["name"]);
            if(not name) then
                return false;
            end

            -- Split value into table
            for value in token["value"]:gmatch("([^/]+)") do
                --local isAltMatch = not token["exact"] and playerName:find(value) or (value == playerName);
                if(CheckPlayerName(name, value, token["exact"])) then
                    return true;
                end
            end
            
            return false;
        else
            -- Not a table, assume it's a single name
            searchType = "name";
        end
    elseif (searchType == "faction") then
        local playerFaction = player["faction"] or Constants:GetFactionByRace(player["race"]) or "";
        if(playerFaction ~= "") then
            local isFactionMatch = not token["exact"] and playerFaction:find(token["value"]) or (token["value"] == playerFaction:lower());
            return isFactionMatch;
        else
            return false;
        end
    elseif(searchType == "role") then
        local playerSpecID = Constants:getAddonSpecializationID(player["class"], player["spec"], false);
        local role = Constants:GetSpecRole(playerSpecID);
        return role and role:lower() == token["value"];
    end

    if(searchType == "name") then
        return CheckPlayerName(player["name"], token["value"], token["exact"]);
    end

    local playerValue = Search:SafeToLower(player[searchType]);
    if(not playerValue) then
        return false;
    end
    
    -- Class and Spec IDs may be numbers in the token
    if(tonumber(token["value"])) then
        local playerSpecID = Constants:getAddonSpecializationID(player["class"], player["spec"], false);
        return playerSpecID == token["value"];
    else
        return not token["exact"] and playerValue:find(token["value"]) or (token["value"] == playerValue);
    end
end

local function CheckTokenForPlayer(token, player)
    local explicitType = token["explicitType"];
    if(explicitType) then
        if(CheckTypeForPlayer(explicitType, token, player)) then
            return true;
        end
    else -- Loop through all types
        local types = { "name", "spec", "class", "race", "faction" }
        local foundMatch = false;
        for _,searchType in ipairs(types) do
            if(CheckTypeForPlayer(searchType, token, player)) then
                return true;
            end
        end
    end
    return false;
end

local function CheckSegmentForPlayer(segment, player)
    assert(segment ~= nil);
    assert(player ~= nil);

    for i,token in ipairs(segment.Tokens) do
        local successValue = not token["negated"];
        if(CheckTokenForPlayer(token, player) ~= successValue) then
            return false;
        end
    end

    return true;
end

local function CheckSegmentForMatch(segment, match, alreadyMatchedPlayers)
    local teams = segment.team and {segment.team} or {"team", "enemyTeam"};
    local foundConflictMatch = false;

    for _,team in ipairs(teams) do
        for _, player in ipairs(match[team]) do
            if(CheckSegmentForPlayer(segment, player)) then
                if(not alreadyMatchedPlayers or segment.inversed) then
                    -- Skip conflict handling
                    return true;
                elseif(alreadyMatchedPlayers[player["name"]] == nil) then
                    alreadyMatchedPlayers[player["name"]] = true;
                    return true;
                else
                    foundConflictMatch = true;
                end
            end
        end
    end

    -- In case of no unique matches above
    if(foundConflictMatch) then
        return nil; -- No final result
    else
        return false; -- Failed to pass
    end
end

-- Returns true/false depending on whether it passed, or nil if it could not yet be determined
local function CheckSimplePass(match)
    -- Cache found matches
    local alreadyMatchedPlayers = {}

    -- Look for segments with no matches or no unique matches
    for _,segment in ipairs(activeSearchData.segments) do
        local segmentResult = CheckSegmentForMatch(segment, match, alreadyMatchedPlayers);

        if(segmentResult == nil) then
            return nil; -- Segment detected conflict
        end
        
        local successValue = not segment.inversed;
        if(segmentResult ~= successValue) then
            return false; -- Failed to pass.
        end    
    end
    
    -- All segments passed without conflict
    return true;
end

-- Main Matching Function to Check Feasibility
function Search:DoesMatchPassSearch(match)
    if(#activeSearchData.segments == 0) then
        return true;
    end

    if(match == nil) then
        ArenaAnalytics:Log("Nil match reached search filter.")
        return false;
    end

    -- Cannot match a search with more players than the match has data for.
    local matchPlayerCount = #match["team"] + #match["enemyTeam"];
    if(activeSearchData.nonInversedCount > matchPlayerCount) then
        return false;
    end

    -- Simple pass first
    local simplePassResult = CheckSimplePass(match);
    if(simplePassResult) then
        return true; -- All segments passed through simple pass
    end

    if(simplePassResult == nil) then
        -- Run advanced pass
        ArenaAnalytics:Log("Search simple pass got no final result. Falling back to advanced check pass. NYI.");
        return false;
    elseif(simplePassResult == false) then
        return false;
    end

    return true;
end

---------------------------------
-- Search API
---------------------------------

function Search:Get(key)
    if key then
        return key and Search.current[key];
    else
        return Search.current;
    end
end

function Search:GetDisplay()
    return Search.current["display"] or Search.current["raw"] or "";
end

function Search:IsEmpty()
    return Search.current["raw"] == "" and Search.current["display"] == "" and Search.current[data] == nil and #activeSearchData.segments == 0;
end

function Search:Reset()
    if(Search:IsEmpty()) then
        return;
    end

    Search.current = {
        ["raw"] = "",
        ["display"] = "",
        ["data"] = nil,
    }
    ResetActiveData();

    -- Trigger filter refresh
    ArenaAnalytics.Filters:RefreshFilters();
end

function Search:CommitSearch(input)
    Search.isCommitting = true;

    -- Update active search filter
    Search:Update(input);
    activeSearchData = Search.current["data"];
    
    ArenaAnalytics:Log("Committing Search..", #activeSearchData.segments, " (" .. (activeSearchData.nonInversedCount or 0) .. ")");

    for i,segment in ipairs(activeSearchData.segments) do
        for j,token in ipairs(segment.Tokens) do
            assert(token and token["value"]);
            ArenaAnalytics:Log("  Token", j, "in segment",i, "  Values:", token["value"], (token["exact"] and " exact" or ""), (token["explicitType"] and (" Type:"..token["explicitType"]) or ""), (token["negated"] and " Negated" or ""), (segment.team and (" "..segment.team) or ""), (segment.inversed and "Inversed" or ""));
        end
    end

    -- Force filter refresh
    ArenaAnalytics.Filters:RefreshFilters();

    Search.isCommitting = nil;
end

function Search:Update(input)
    local searchBox = ArenaAnalyticsScrollFrame.searchBox;

    local oldCursorPosition = searchBox:GetCursorPosition();
    local newSearchData, display, raw, newCursorPosition = Search:ProcessInput(input, oldCursorPosition);

    Search.current["raw"] = raw;
    Search.current["display"] = display;
    Search.current["data"] = newSearchData;

    -- Update the searchbox
    searchBox:SetText(display);
    searchBox:SetCursorPosition(newCursorPosition);
end