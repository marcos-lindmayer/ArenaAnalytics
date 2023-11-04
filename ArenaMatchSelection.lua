local _, ArenaAnalytics = ...;
ArenaAnalytics.Selection = {};

local Selection = ArenaAnalytics.Selection;

------------------------------------------------------------------

Selection.selectedGames = {}

-- Initialize latestSelectionInfo and latestMultiSelect
local latestSelectionInfo = {
    ["isDeselecting"] = false,
    ["start"] = {
        ["index"] = nil,
        ["isSessionSelect"] = false
    },
    ["end"] = {
        ["index"] = nil,
        ["isSessionSelect"] = false
    }
}

Selection.latestMultiSelect = {}
Selection.latestDeselect = {}

local function getMatch(matchIndex)
    return ArenaAnalytics.filteredMatchHistory[matchIndex];
end

local function selectMatchByIndex(index, autoCommit, isDeselect)
    autoCommit = autoCommit or IsControlKeyDown();
    if(getMatch(index) ~= nil) then
        if (isDeselect) then
            if autoCommit then
                Selection.selectedGames[index] = nil;
            else
                Selection.latestDeselect[index] = true;
            end
        else
            Selection.latestDeselect[index] = nil;
            if autoCommit then
                Selection.selectedGames[index] = true;
            else
                Selection.latestMultiSelect[index] = true;
            end
        end
    end
end

local function resetLatestSelection(keepStart, resetDeselectState)
    if (keepStart) then
        latestSelectionInfo["end"]["index"] = nil;
        latestSelectionInfo["end"]["isSessionSelect"] = false;
    else
        latestSelectionInfo["start"] = {
            ["index"] = nil,
            ["isSessionSelect"] = false
        }
        latestSelectionInfo["end"] = {
            ["index"] = nil,
            ["isSessionSelect"] = false
        }
    end

    if (resetDeselectState) then
        latestSelectionInfo["isDeselecting"] = false;
        Selection.latestDeselect = {}
    end

    Selection.latestMultiSelect = {}
end
resetLatestSelection();

local function getMultiSelectStart()
    -- return index/session and boolean for isSessionSelect for the start. Nil when invalid
    if(latestSelectionInfo["start"]) then
        return latestSelectionInfo["start"]["index"], latestSelectionInfo["start"]["isSessionSelect"];
    end
    return nil, nil;
end

local function getMultiSelectEnd()
    -- return index/session and boolean for isSessionSelect for the end. Nil when invalid
    if(latestSelectionInfo["end"]) then
        return latestSelectionInfo["start"]["index"], latestSelectionInfo["start"]["isSessionSelect"];
    end
    return nil, nil;
end

-- returns true if two given indices are for matches with the same session. False if either is nil.
function Selection:isMatchesSameSession(index, otherIndex)
    local match = getMatch(index);
    local otherMatch = getMatch(otherIndex);
    if(match == nil or otherMatch == nil) then
        return false;
    end

    return match["session"] == otherMatch["session"];
end

function Selection:isMatchSelected(matchIndex)
    return not Selection.latestDeselect[matchIndex] and (Selection.selectedGames[matchIndex] or Selection.latestMultiSelect[matchIndex]);
end

-- Helper function to select a range of matches
local function selectRange(startIndex, endIndex, includeStartSession, includeEndSession, isDeselect)
    local minIndex = math.min(startIndex, endIndex)
    local maxIndex = math.max(startIndex, endIndex)
    local startSession = ArenaAnalytics.filteredMatchHistory[startIndex]["session"]
    local endSession = ArenaAnalytics.filteredMatchHistory[endIndex]["session"]
    
    for i = minIndex, maxIndex do
        -- Skip matches that belong to the same session as the start and end index,
        -- unless includeStartSession or includeEndSession is true
        local session = ArenaAnalytics.filteredMatchHistory[i]["session"];
        local isStartSession = session == startSession;
        local isEndSession = session == endSession;
        if ((includeStartSession and (isStartSession or not isEndSession)) or (includeEndSession and isEndSession)) then
            selectMatchByIndex(i, false, isDeselect);
        end
    end
end

-- Helper function to select or deselect a session by index
local function selectSessionByIndex(index, autoCommit, isDeselect)
    local session = MatchHistoryDB[index]["session"]

    -- Select or deselect the match at the given index using selectMatchByIndex
    selectMatchByIndex(index, autoCommit, isDeselect)

    -- Table with delta values
    local deltas = {-1, 1}

    -- Nested for loops to expand in both directions until reaching a match with a different session
    for _, delta in ipairs(deltas) do
        local i = index + delta
        local potentialMatch = getMatch(i)
        while potentialMatch and potentialMatch["session"] == session do
            selectMatchByIndex(i, autoCommit, isDeselect)
            i = i + delta
            potentialMatch = getMatch(i)
        end
    end
end 

-- TODO: Move to ArenaMatchSelection.lua
-- Clears current selection of matches
function Selection:ClearSelectedMatches()
    Selection.selectedGames = {}
    Selection.latestMultiSelect = {}
    resetLatestSelection();

    ArenaAnalytics.AAtable:RefreshLayout();
end

local function commitLatestSelections()
    for i in pairs(Selection.latestMultiSelect) do
        Selection.selectedGames[i] = true;
    end
    
    for i in pairs(Selection.latestDeselect) do
        Selection.selectedGames[i] = nil;
        Selection.latestMultiSelect[i] = nil;
    end
    Selection.latestMultiSelect = {}
    Selection.latestDeselect = {}
end

local function clearLatestSelections()
    Selection.latestMultiSelect = {}
    Selection.latestDeselect = {}
end

-- Main function to handle click events on match entries
function Selection:handleMatchEntryClicked(key, isDoubleClick, index)
    -- whether we're changing the endpoint of a multiselect
    local startIndex = latestSelectionInfo["start"] and latestSelectionInfo["start"]["index"] or nil;
    local isStartSessionSelect = latestSelectionInfo["start"] and latestSelectionInfo["start"]["isSessionSelect"];
    local selectedByStartSession = isStartSessionSelect and Selection:isMatchesSameSession(index, startIndex);

    local changeMultiSelectEndpoint = IsShiftKeyDown() and tonumber(startIndex) ~= nil and not selectedByStartSession and isDeselect == wasDeselecting;
    local existingIsDeselect = changeMultiSelectEndpoint and latestSelectionInfo["isDeselecting"] and false; -- TODO: FIX

    local isDeselect = (existingIsDeselect or (key == "RightButton") or Selection:isMatchSelected(index)) or false;
    local session = ArenaAnalytics.filteredMatchHistory[index]["session"]

    -- If Ctrl is not pressed, clear the previous selection and latestMultiSelect.
    if not IsControlKeyDown() and not IsShiftKeyDown() and not ArenaAnalyticsSettings["stickySelection"] then
        Selection.selectedGames = {}
        resetLatestSelection(true);
    end

    -- Single or session select? (Single vs double click)
    local isSessionSelect = isDoubleClick or IsAltKeyDown();
    
    local wasDeselecting = latestSelectionInfo["isDeselecting"];
    if (isDeselect ~= wasDeselecting) then
        latestSelectionInfo["isDeselecting"] = isDeselect;
    end
    
    -- Clear the last uncommitted multiselect endpoint and selection
    if (changeMultiSelectEndpoint) then
        clearLatestSelections();
        latestSelectionInfo["end"]["index"] = nil;
        latestSelectionInfo["end"]["isSessionSelect"] = false;
    else -- Commit previous multiselect
        commitLatestSelections();
    end
    
    -- Update selection
    if changeMultiSelectEndpoint then
        selectRange(startIndex, index, true, not isSessionSelect, isDeselect) -- Select range between start and current index
        if (isSessionSelect) then
            selectSessionByIndex(index, false, isDeselect);
        end
        latestSelectionInfo["end"]["index"] = index -- Update the end point of multi-select.
        latestSelectionInfo["end"]["isSessionSelect"] = isSessionSelect -- Update whether it's a session select.
    else -- change start point
        if (isSessionSelect) then
            selectSessionByIndex(index, true, isDeselect) -- Select session by index
        else
            selectMatchByIndex(index, true, isDeselect) -- Select match by index
        end
        
        latestSelectionInfo["start"]["index"] = index -- Update the start point of multi-select.
        latestSelectionInfo["start"]["isSessionSelect"] = isSessionSelect -- Set this to false as we're selecting a single match now.
    end

    -- Update UI
    ArenaAnalytics.AAtable:UpdateSelected();
    ArenaAnalytics.AAtable:RefreshLayout();
end