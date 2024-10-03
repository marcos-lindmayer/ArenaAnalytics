local _, ArenaAnalytics = ... -- Addon Namespace
local Search = ArenaAnalytics.Search;

-- Local module aliases
local Options = ArenaAnalytics.Options;
local Filters = ArenaAnalytics.Filters;
local Constants = ArenaAnalytics.Constants;
local Bitmap = ArenaAnalytics.Bitmap;
local Helpers = ArenaAnalytics.Helpers;
local ArenaMatch = ArenaAnalytics.ArenaMatch;

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


function Search:GetEmptySegment()
    return { tokens = {} };
end

function Search:GetEmptyData()
    return { segments = {}, nonInversedCount = 0 }
end

-- The current search data
Search.current = {
    display = "", -- Search string sanitized and colored(?) for display
    segments = {} -- Tokenized player segments
}

function Search:GetCurrentSegments()
    assert(Search.current);
    return Search.current.segments or {};
end

function Search:GetCurrentSegmentCount()
    return #Search:GetCurrentSegments();
end

local lastCommittedSearchDisplay = "";
local activeSearchData = Search:GetEmptyData();

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

function Search:GetLastDisplay()
    return lastCommittedSearchDisplay or "";
end

function Search:GetDisplay()
    return Search.current.display or "";
end

function Search:IsEmpty()
    return Search.current.display == "" and #Search.current.segments == 0 and #activeSearchData.segments == 0;
end

function Search:Reset()
    if(Search:IsEmpty()) then
        return;
    end

    Search:CommitSearch("");
end

function Search:Update(input)
    local searchBox = ArenaAnalyticsScrollFrame.searchBox;
    local oldCursorPosition = searchBox:GetCursorPosition();

    local newSearchData = Search:ProcessInput(input, oldCursorPosition);
    Search:SetCurrentData(newSearchData);
end

function Search:SetCurrentData(tokenizedSegments)
    Search.current.segments = tokenizedSegments or {};
    Search:SetCurrentDisplay();
end

local function LogSearchData()
    ArenaAnalytics:LogSpacer();
    ArenaAnalytics:Log("Committing Search..", #activeSearchData.segments, " (" .. activeSearchData.nonInversedCount .. ")");

    for i,segment in ipairs(activeSearchData.segments) do
        for j,token in ipairs(segment.tokens) do
            assert(token and token.value);
            ArenaAnalytics:Log("  Token:", j, "Segment:",i..":", token.value, (token.explicitType or ""), (token.exact and " exact" or ""), (token.negated and " Negated" or ""), (segment.isEnemyTeam or ""), (segment.inversed and "Inversed" or ""));
        end
    end
end

local function GetPersistentData()
    local persistentData = Search:GetEmptyData();

    for i,segment in ipairs(Search:GetCurrentSegments()) do
        assert(segment.tokens);
        local persistentSegment = Search:GetEmptySegment();

        for j,token in ipairs(segment.tokens) do
            -- Process transient tokens for logic only
            if(token.value and token.value ~= "") then
                if(token.transient) then
                    if(token.explicitType == "logical") then
                        if(token.value == "not") then
                            persistentSegment.inversed = true;
                        end
                    elseif(token.explicitType == "team") then
                        persistentSegment.isEnemyTeam = (token.value == "enemy");
                    end
                else -- Persistent tokens, kept for direct comparisons
                    tinsert(persistentSegment.tokens, token);
                end
            end
        end
        
        if(persistentSegment.isEnemyTeam == nil and Options:Get("searchDefaultExplicitEnemy")) then
            persistentSegment.isEnemyTeam = true;
        end
        
        if(not persistentSegment.inversed) then
            persistentData.nonInversedCount = persistentData.nonInversedCount + 1;
        end

        tinsert(persistentData.segments, persistentSegment);
    end


    return persistentData;
end

function Search:CommitEmptySearch()
    Search:SetCurrentData();
    Search:CommitSearch();
end

function Search:CommitSearch(input)
    Search.isCommitting = true;

    -- Update active search filter
    if(input) then
        Search:Update(input);
    end

    lastCommittedSearchDisplay = Search.current.display;
    
    -- Add all segments and non-transient tokens to the active data
    activeSearchData = GetPersistentData();

    LogSearchData();

    -- Force filter refresh
    Filters:Refresh();

    Search.isCommitting = nil;
end

---------------------------------
-- Search matching logic
---------------------------------

local function CheckPlayerName(fullName, searchValue, isExact)
    if(not fullName or fullName == "" or not searchValue or true) then
        return false;
    end

    local name, realm = strsplit('-', fullName, 2);
    
    -- Convert to string based name
    name = Helpers:ToSafeLower(ArenaAnalytics:GetName(name));
    
    if(not name) then
        return false;
    end
    
    local searchName, searchRealm = strsplit('-', searchValue, 2);
    
    if(isExact) then
        if(searchName ~= name) then
            return false;
        end
    elseif(not name:find(searchName, 1, true)) then
        return false;
    end
    
    if(searchRealm) then
        -- Convert to string based realm
        realm = Helpers:ToSafeLower(ArenaAnalytics:GetRealm(realm));
        ArenaAnalytics:Log("   ", realm);

        if(not realm) then
            return false;
        end

        if(isExact) then
            if(searchRealm ~= realm) then
                return false;
            end
        elseif(not realm:find(searchRealm, 1, true)) then
            return false;
        end
    end

    return true;
end

-- NOTE: This is the main part to modify to handle actual token matching logic
-- Returns true if a given type on a player matches the given value
local function CheckTypeForPlayer(searchType, token, playerInfo)
    assert(token and token.value and token.value ~= "", "Invalid token reached search! Token raw: " .. (token and token.raw or "nil"));
    assert(playerInfo ~= nil);

    if(searchType == nil) then
        ArenaAnalytics:Log("Invalid type reached CheckTypeForPlayer for search.");
        return;
    end

    -- Names
    if(searchType == "alts" or searchType == "name") then
        if(token.value:find('/', 1, true)) then
            -- Split value into table
            for value in token.value:gmatch("([^/]+)") do
                if(CheckPlayerName(playerInfo.name, value, token.exact)) then
                    return true;
                end
            end
        elseif(CheckPlayerName(playerInfo.name, token.value, token.exact)) then
            return true;
        end

        -- We already checked all name cases
        return false;
    end

    if(searchType == "class" or searchType == "spec") then
        return Search:CheckSpecMatch(token.value, playerInfo.spec);
    elseif (searchType == "faction") then
        return playerInfo.race and token.value == (playerInfo.race % 2);
    elseif(searchType == "role") then
        return Bitmap:HasBitByIndex(playerInfo.role, roleIndex);
    elseif(searchType == "logical") then
        if(token.value == "self") then
            return ArenaMatch:IsPlayerSelf(playerInfo);
        end
    elseif(searchType == "race") then
        -- Overrides to treat neutral races as same ID
        return tonumber(token.value) == Search:GetNormalizedRace(playerInfo.race);
    end

    local playerValue = playerInfo[searchType];
    if(not playerValue or playerValue == "") then
        return false;
    end

    -- Class and Spec IDs may be numbers in the token
    if(tonumber(playerValue) or tonumber(token.value)) then
        return tonumber(playerValue) == tonumber(token.value);
    else
        return not token.exact and playerValue:find(token.value, 1, true) or (token.value == playerValue);
    end
end

local function CheckTokenForPlayer(token, playerInfo)
    assert(token and playerInfo);

    if(token.explicitType) then
        if(CheckTypeForPlayer(token.explicitType, token, playerInfo)) then
            return true;
        end
    else -- Loop through all types
        ArenaAnalytics:Log("Looping through all types for search!");

        local types = { "name", "spec", "class", "race", "faction" }
        for _,searchType in ipairs(types) do
            if(CheckTypeForPlayer(searchType, token, playerInfo)) then
                return true;
            end
        end
    end
    return false;
end

local function CheckSegmentForPlayer(segment, playerInfo)
    assert(segment and playerInfo);

    if(not playerInfo.name) then
        return false;
    end

    for i,token in ipairs(segment.tokens) do
        local successValue = not token.negated;
        if(CheckTokenForPlayer(token, playerInfo) ~= successValue) then
            return false;
        end
    end

    return true;
end

---------------------------------
-- Simple Pass
---------------------------------

local function CheckSegmentForMatch(segment, match, alreadyMatchedPlayers)
    assert(match);

    if(not segment) then
        return false;
    end

    local teams = segment.isEnemyTeam ~= nil and {segment.isEnemyTeam} or {false, true};
    local foundConflictMatch = false;

    local playerInfo = nil;

    for _,isEnemyTeam in ipairs(teams) do
        local team = ArenaMatch:GetTeam(match, isEnemyTeam);
        for _, player in ipairs(team) do
            playerInfo = ArenaMatch:GetPlayerInfo(player, playerInfo);
            if(CheckSegmentForPlayer(segment, playerInfo)) then
                ArenaAnalyticsDebugAssert(playerInfo.name, "Player passed search with invalid full name.");

                if(not alreadyMatchedPlayers or segment.inversed or not playerInfo.name) then
                    -- Skip conflict handling
                    return true;
                elseif(alreadyMatchedPlayers[playerInfo.name] == nil) then
                    alreadyMatchedPlayers[playerInfo.name] = true;
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
    assert(match);

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

---------------------------------
-- Advanced Pass
---------------------------------

local function PruneUniqueMatches(segmentMatches, playerMatches)
    if(#segmentMatches == 0 and #playerMatches == 0) then
        return;
    end
    
    local changed = true;

    local function PruneLockedValues(tableToPrune, valueToRemove)
        for i = #tableToPrune, 1, -1 do
            local matches = tableToPrune[i];
            
            for j = #matches, 1, -1 do
                local value = matches[j];
                if(value and value == valueToRemove) then
                    if(#matches == 1) then
                        table.remove(tableToPrune, i);
                    else
                        table.remove(matches, j);
                    end

                    changed = true;
                    break;
                end
            end
        end
    end

    local function LockUniqueMatches(tableToCheck, pairedTable)
        for i = #tableToCheck, 1, -1 do
            local matches = tableToCheck[i];
            
            if #matches == 1 then
                local value = matches[1];
                if(pairedTable[value] ~= nil and #pairedTable[value] > 0) then
                    table.remove(tableToCheck, i);
                    
                    PruneLockedValues(tableToCheck, value);
                    pairedTable[value] = nil;
                else
                    return false;
                end
            end
        end
        return true;
    end

    while changed do
        changed = false

        -- Find segments with only one matched player
        if(LockUniqueMatches(segmentMatches, playerMatches) == false) then
            return false;
        end

        -- Find players with only one matched segment
        if(LockUniqueMatches(playerMatches, segmentMatches) == false) then
            return false;
        end
    end
end

local function recursivelyMatchSegments(segmentMatches, segmentIndex, alreadyMatchedPlayers)
    if segmentIndex > #segmentMatches then
        return true;
    end

    local segment = segmentMatches[segmentIndex];
    if(#segment == 0) then
        ArenaAnalytics:Log("Recursion found empty segment matches")
        return false;
    end

    for _, player in ipairs(segment) do
        if not alreadyMatchedPlayers[player] then
            alreadyMatchedPlayers[player] = true;
            if recursivelyMatchSegments(segmentMatches, segmentIndex + 1, alreadyMatchedPlayers) then
                return true;
            end
            alreadyMatchedPlayers[player] = nil;
        end
    end

    return false;
end

local function CheckAdvancedPass(match)
    local segmentMatches, playerMatches = {}, {}

    local matchedTables = {}
    local currentIndex = 1;

    local playerInfo = nil;

    -- Fill matched tables
    for segmentIndex, segment in ipairs(activeSearchData.segments) do
        local teams = segment.isEnemyTeam ~= nil and {segment.isEnemyTeam} or {false, true};

        for _,isEnemyTeam in ipairs(teams) do
            local team = ArenaMatch:GetTeam(match, isEnemyTeam);
            for playerIndex, player in ipairs(team) do
                playerInfo = ArenaMatch:GetPlayerInfo(player, playerInfo);

                local segmentResult = CheckSegmentForPlayer(segment, playerInfo);
                if(segmentResult) then
                    if(segment.inversed) then
                        -- Inverse segments fail the pass if they match
                        return false;
                    end

                    local playerKey = (isEnemyTeam and "enemy" or "team") .. playerIndex;

                    -- Add player to segment matches
                    segmentMatches[currentIndex] = segmentMatches[currentIndex] or {};
                    tinsert(segmentMatches[currentIndex], playerKey);

                    -- Add segment to player matches
                    playerMatches[playerKey] = playerMatches[playerKey] or {};
                    tinsert(playerMatches[playerKey], currentIndex);
                end
            end
        end

        -- Failed to find a match for the segment
        if(not segment.inversed and not segmentMatches[currentIndex]) then
            return false;
        end

        currentIndex = currentIndex + 1;
    end

    -- If all segment matches were removed by pruning, then unique matches were found
    if(#segmentMatches == 0) then
        return true;
    end

    table.sort(segmentMatches, function(a, b)
        return #a < #b;
    end);

    local alreadyMatchedPlayers = {};
    return recursivelyMatchSegments(segmentMatches, 1, alreadyMatchedPlayers);
end

---------------------------------
-- Check Match for Search
---------------------------------

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
    if(activeSearchData.nonInversedCount > ArenaMatch:GetPlayerCount(match)) then
        return false;
    end

    -- Simple pass first
    local simplePassResult = CheckSimplePass(match);
    if(simplePassResult == false) then
        -- Simple pass failed explicitly
        return false;
    end

    -- Advanced pass in case of segment conflict from simple pass
    if(simplePassResult == nil and not CheckAdvancedPass(match)) then
        return false;
    end

    return true;
end