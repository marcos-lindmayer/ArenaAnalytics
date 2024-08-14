local _, ArenaAnalytics = ... -- Addon Namespace
local Search = ArenaAnalytics.Search;

-- Local module aliases
local Options = ArenaAnalytics.Options;
local Constants = ArenaAnalytics.Constants;
local Helpers = ArenaAnalytics.Helpers;

-------------------------------------------------------------------------
-- Short Names

local QuickSearchValueTable = {
    ["class"] = {
        ["death knight"] = "DK",
        ["demon hunter"] = "DH",
        ["druid"] = "Druid",
        ["hunter"] = "Hunt",
        ["mage"] = "Mage",
        ["monk"] = "Monk",
        ["paladin"] = "Pala",
        ["priest"] = "Priest",
        ["rogue"] = "Rog",
        ["shaman"] = "Sham",
        ["warlock"] = "Lock",
        ["warrior"] = "Warrior"
    },
    ["spec"] = {
        -- Druid
        ["druid|restoration"] = "RDruid",
        ["druid|feral"] = "Feral",
        ["druid|balance"] = "Balance",
        -- Paladin
        ["paladin|holy"] = "HPala",
        ["paladin|protection"] = "Prot Pala",
        ["paladin|preg"] = "Preg",
        ["paladin|retribution"] = "Ret",
        -- Shaman
        ["shaman|restoration"] = "RSham",
        ["shaman|elemental"] = "Ele",
        ["shaman|enhancement"] = "Enh",
        -- Death Knight
        ["death knight|unholy"] = "UH",
        ["death knight|frost"] = "Frost DK",
        ["death knight|blood"] = "Blood",
        -- Hunter
        ["hunter|beast mastery"] = "BM",
        ["hunter|marksmanship"] = "MM",
        ["hunter|survival"] = "Surv",
        -- Mage
        ["mage|frost"] = "Frost Mage",
        ["mage|fire"] = "Fire",
        ["mage|arcane"] = "Arcane",
        -- Rogue
        ["rogue|subtlety"] = "Sub",
        ["rogue|assassination"] = "Assa",
        ["rogue|combat"] = "Combat",
        ["rogue|outlaw"] = "Outlaw",
        -- Warlock
        ["warlock|affliction"] = "Affli",
        ["warlock|destruction"] = "Destro",
        ["warlock|demonology"] = "Demo",
        -- Warrior
        ["warrior|protection"] = "Prot War",
        ["warrior|arms"] = "Arms",
        ["warrior|fury"] = "Fury",
        -- Priest
        ["priest|discipline"] = "Disc",
        ["priest|holy"] = "HPriest",
        ["priest|shadow"] = "Shadow"
    },
    ["race"] = {
        ["blood elf"] = "Belf",
        ["draenei"] = "Draenei",
        ["dwarf"] = "Dwarf",
        ["gnome"] = "Gnome",
        ["goblin"] = "Goblin",
        ["human"] = "Human",
        ["night elf"] = "Nelf",
        ["orc"] = "Orc",
        ["pandaren"] = "Pandaren",
        ["tauren"] = "Tauren",
        ["troll"] = "Troll",
        ["undead"] = "Undead",
        ["worgen"] = "Worgen",
        ["void elf"] = "Velf",
        ["lightforged draenei"] = "LDraenei",
        ["nightborne"] = "Nightborne",
        ["highmountain tauren"] = "HTauren",
        ["zandalari troll"] = "ZTroll",
        ["kul tiran"] = "KTiran",
        ["dark iron dwarf"] = "DIDwarf",
        ["mag'har orc"] = "MOrc",
        ["mechagnome"] = "MGnome",
        ["vulpera"] = "Vulpera"
    },
}

function Search:GetShortQuickSearch(typeKey, longValue)
    assert(QuickSearchValueTable[typeKey]);
    longValue = longValue or "";
    return QuickSearchValueTable[typeKey][longValue:lower()] or longValue;
end

function Search:GetShortQuickSearchSpec(class, spec)
    local shortName = nil;
    if(spec and spec ~= "") then
        local specKey = class .. "|" .. spec;
        shortName = QuickSearchValueTable["spec"][specKey:lower()];
    elseif(class and class ~= "") then
        shortName = QuickSearchValueTable["class"][class:lower()];
    end

    return shortName;
end

---------------------------------
-- Quick Search
---------------------------------

local currentActions = {}
local locked = nil;

local function ResetQuickSearch()
    currentActions = {};
    locked = nil;
end

local function CheckShortcut(shortcut, btn)
    if(not shortcut or shortcut == "None") then
        return false;
    end

    if(shortcut == "Any") then
        return true;
    end

    if(shortcut == "LMB") then
        return btn == "LeftButton";
    end
    
    if(shortcut == "RMB") then
        return btn == "RightButton";
    end

    if(shortcut == "Shift") then
        return IsShiftKeyDown();
    end

    if(shortcut == "Ctrl") then
        return IsControlKeyDown();
    end
    
    if(shortcut == "Alt") then
        return IsAltKeyDown();
    end
    
    if(shortcut == "Nomod") then
        return not IsShiftKeyDown() and not IsControlKeyDown() and not IsAltKeyDown();
    end

    return false;
end

--AddSetting("quickSearchAction_NewSearch", "Nomod");
--AddSetting("quickSearchAction_NewSegment", "None");
--AddSetting("quickSearchAction_SameSegment", "Shift");
--AddSetting("quickSearchAction_Inverse", "Alt");

--AddSetting("quickSearchAction_Team", "LMB");
--AddSetting("quickSearchAction_Enemy", "RMB");
--AddSetting("quickSearchAction_ClickedTeam", "None");

--AddSetting("quickSearchAction_Name", "Nomod");
--AddSetting("quickSearchAction_Spec", "Ctrl");
--AddSetting("quickSearchAction_Race", "None");
--AddSetting("quickSearchAction_Faction", "None");

local function GetPlayerName(player)
    name = player["name"] or "";
    if(name:find('-')) then
        -- TODO: Convert to options
        if(Options:Get("quickSearchExcludeAnyRealm")) then
            name = name:match("(.*)-") or name;
        elseif(Options:Get("quickSearchExcludeMyRealm")) then
            local _, realm = UnitFullName("player");
            if(realm and name:find(realm)) then
                name = name:match("(.*)-") or name;
            end
        end
    end
    
    return name or "";
end

local function HasAction(action)
    assert(action);
    return currentActions[action] or false;
end

local function AddSettingAction(actions, setting)
    assert(setting and actions);

    local action = Options:Get(setting);
    if(action and action ~= "None") then
        ArenaAnalytics:Log("Adding action: ", action)
        actions[action] = true;
    end
end

local function GetAppendRule(btn)
    if(CheckShortcut(Options:Get("quickSearchAppendRule_NewSearch"), btn)) then
        return "New Search";
    end

    if(CheckShortcut(Options:Get("quickSearchAppendRule_NewSegment"), btn)) then
        return "New Segment";
    end

    if(CheckShortcut(Options:Get("quickSearchAppendRule_SameSegment"), btn)) then
        return "Same Segment";
    end

    return Options:Get("quickSearchDefaultAppendRule");
end

local function AddValueByType(tokens, player, typeKey)
    if(not typeKey) then
        return;
    end

    if(typeKey == "name") then
        assert(player["name"]);
        tinsert(tokens, { typeKey = typeKey, value = player["name"] });
    elseif(typeKey == "race") then
        local race = Search:GetShortQuickSearch(typeKey, player["race"]);
        if(race) then
            tinsert(tokens, { typeKey = typeKey, value = race });
        end
    elseif(typeKey == "spec") then
        local class, spec = player["class"], player["spec"];
        local value = Search:GetShortQuickSearchSpec(class, spec);
        if(value) then
            local actualType = (spec and spec ~= "") and "spec" or "class";
            tinsert(tokens, { typeKey = actualType, value = value});
        end
    elseif(typeKey == "class") then
        local class = player["class"];
        local value = Search:GetShortQuickSearchSpec(class, nil);
        if(value) then
            tinsert(tokens, { typeKey = typeKey, value = value });
        end
    elseif(typeKey == "faction") then
        local faction = Constants:GetFactionByRace(player["race"]);
        local value = Search:GetShortQuickSearch(typeKey, faction);
        if(value) then
            tinsert(tokens, { typeKey = typeKey, value = value })
        end
    end
end

local function GetQuickSearchTokens(player, team, btn)
    assert(player);
    local tokens = {};

    -- Inverse
    local shortcut = Options:Get("quickSearchAction_Inverse");
    if(CheckShortcut(shortcut, btn)) then
        tokens["inverse"] = "not";
    end

    -- Team
    if(CheckShortcut(Options:Get("quickSearchAction_ClickedTeam"), btn)) then
        tinsert(tokens, { typeKey = "team", value = team});
    elseif(CheckShortcut(Options:Get("quickSearchAction_Team"), btn)) then
        tinsert(tokens, { typeKey = "team", value = "Team"});
    elseif(CheckShortcut(Options:Get("quickSearchAction_Enemy"), btn)) then
        tinsert(tokens, { typeKey = "team", value = "Enemy"});
    end

    -- Name
    shortcut = Options:Get("quickSearchAction_Name");
    if(CheckShortcut(shortcut, btn)) then
        AddValueByType(tokens, player, "name")
    end

    -- Spec
    shortcut = Options:Get("quickSearchAction_Spec");
    if(CheckShortcut(shortcut, btn)) then
        AddValueByType(tokens, player, "spec");
    end

    -- Race
    shortcut = Options:Get("quickSearchAction_Race");
    if(CheckShortcut(shortcut, btn)) then
        AddValueByType(tokens, player, "race")
    end
    
    -- Faction
    shortcut = Options:Get("quickSearchAction_Faction");
    if(CheckShortcut(shortcut, btn)) then
        AddValueByType(tokens, player, "faction")
    end

    if(#tokens == 0) then
        local typeKey = Options:Get("quickSearchDefaultValue");
        AddValueByType(tokens, player, "name");
    end

    return tokens;
end

local function GetCurrentSegments()
    if(HasAction("New Search")) then
        return Search:GetEmptySegment();
    end
    
    assert(Search.current and Search.current["data"]);
    return Search.current["data"].segments or Search:GetEmptySegment();
end

local function DoesTokenMatchName(existingToken, newName)
    assert(existingToken);
    if(existingToken["explicitType"] ~= "name") then
        return false;
    end

    local existingName = existingToken["value"];
    if(existingToken == newName) then
        return true;
    end

    if(not existingToken["exact"]) then
        return newName:find(existingName:gsub('-', "%-"));
    end

    return false;
end

local function FindExistingNameMatch(segments, newName)
    assert(segments);

    if(not newName or newName == "") then
        return nil, nil;
    end

    for i,segment in ipairs(segments) do
        for _,currentToken in ipairs(segment.tokens) do
            -- Compare name with current 
            if(DoesTokenMatchName(currentToken, newName)) then
                return i, j;
            end
        end
    end
end

local function DoesAllTokensMatchExact(segments, tokens)
    assert(segments);

    if(not token) then
        return false;
    end

    for _,segment in ipairs(segments) do
        for i,existingToken in ipairs(segment.tokens) do
            if(existingToken.explicitType == token.type and existingToken.value == token.value) then
                return true;
            end
        end
    end

    return false;
end

function Search:QuickSearch(mouseButton, player, team)
    if(locked) then
        return;
    end
    locked = true;

    team = (team == "team") and "Team" or "Enemy";
    appendRule = GetAppendRule(mouseButton);
    tokens = GetQuickSearchTokens(player, team, mouseButton);
    
    local currentSegments = Helpers:DeepCopy(Search:GetCurrentSegments());

    local newSegment = {}
    local segmentIndex = 0;

    -- Current Search Data
    currentSegments = Search:GetCurrentSegments();
    
    if(appendRule == "New Search") then
        Search:Update("");
        currentSegments = {}
    end
    
    -- Check for name match
    local foundNameMatchingSegment = false;
    if(#currentSegments > 0) then
        local newName = nil;
        for _,token in ipairs(tokens) do
            if(token.type == "name") then
                newName = token.value;
            end
        end

        if(newName) then
            local matchedSegmentIndex, matchedTokenIndex = FindExistingNameMatch(currentSegments, newName);
            if(matchedSegmentIndex and matchedTokenIndex) then
                foundNameMatchingSegment = true;
                segmentIndex = matchedSegmentIndex;
            end
        end
    end

    -- 
    if(not foundNameMatchingSegment) then
        if(#currentSegments == 0) then
            tinsert(currentSegments, { tokens = {} });            
        elseif(appendRule == "New Segment") then
            ArenaAnalytics:Log("Adding new separator from quick search!")
            local newSeparatorToken = Search:CreateSymbolToken(', ');
            tinsert(currentSegments[#currentSegments].tokens, newSeparatorToken);

            tinsert(currentSegments, { tokens = {} });
        end

        segmentIndex = #currentSegments;
    end

    -- If all tokens match, and this was an existing named match, then remove the entire segment
    if(foundNameMatchingSegment) then
        -- For each new token, check for an exact match
        if(DoesAllTokensMatchExact(currentSegments[segmentIndex], tokens)) then
            table.remove(currentSegments, segmentIndex);
            Search:CommitQuickSearch(currentSegments);
            return;
        end
    end
    
    -- TODO: Implement per token Add/Replace/Remove logic
    -- For each new token, look for a type match
    for i,token in ipairs(tokens) do
        ArenaAnalytics:Log("Processing quick search token: ", token.typeKey, ":", token.value);

        if(token.typeKey and token.value) then
            assert(token.typeKey and token.typeKey ~= "");
            assert(currentSegments[segmentIndex]);
            
            local newTokenText = Search:GetShortPrefix(token.typeKey) .. ":" .. token.value;
            local newToken = Search:CreateToken(newTokenText);

            newToken["value"] = Search:SafeToLower(newToken["keyword"] or newToken["value"]);
            newToken["keyword"] = nil;
            
            local isUniqueToken = true;
            
            for j,existingToken in ipairs(currentSegments[segmentIndex]) do
                ArenaAnalytics:Log("Quick Search token types:", existingToken.explicitType, token.typeKey)
                if(existingToken.explicitType == token.typeKey) then
                    ArenaAnalytics:Log("Found existing type match in segment: ", segmentIndex, " of type: ", existingToken.explicitType);
                    isUniqueToken = false;
                    
                    -- If value is same, remove existing
                    
                    
                    -- If value is different, replace with the new token
                    
                    break;
                end
            end
            
            -- If the token type is unique
            if(isUniqueToken) then
                if(#currentSegments > 0 or #currentSegments[segmentIndex].tokens > 0) then
                    ArenaAnalytics:Log("Adding space from quick search", i, #tokens)
                    local newSpaceToken = Search:CreateSymbolToken(' ');
                    tinsert(currentSegments[segmentIndex].tokens, newSpaceToken);
                end

                -- Add the new token
                tinsert(currentSegments[segmentIndex].tokens, newToken);
            end
        end
    end

    Search:CommitQuickSearch(currentSegments);
end

function Search:CommitQuickSearch(segments)
    print(" ")
    ArenaAnalytics:Log("Committing Quick Search.", #segments, "segments.");
    for _,segment in ipairs(segments) do
        for _,token in ipairs(segment.tokens) do
            ArenaAnalytics:Log("   Raw:", token.raw);
        end
    end

    Search:SetCurrentData(segments);

    ResetQuickSearch()
end



function Search:QuickSearch_OLD(mouseButton, player, team)
    assert(player);

    local prefix, tokens = '', {};
    local isNegated = (mouseButton == "RightButton");

    if(isNegated) then
        tinsert(tokens, "not");
    end

    if(team == "team") then
        tinsert(tokens, "team");
    elseif(team == "enemyTeam") then
        tinsert(tokens, "enemy");
    end

    if(not IsAltKeyDown() and not IsControlKeyDown()) then
        name = GetPlayerName(player);

        -- Add name only
        tinsert(tokens, name);
    else
        if(IsAltKeyDown() and player["race"] ~= nil) then
            -- Add race if available
            local race =  player["race"];
            local shortName = Search:GetShortQuickSearch("race", race);
            tinsert(tokens, "r:"..(shortName or race));
        end
        
        if(IsControlKeyDown() and player["class"] ~= nil) then
            local class = player["class"];
            local spec = player["spec"];

            local shortName = Search:GetShortQuickSearchSpec(class, spec);
            if(ArenaAnalyticsDebugAssert(shortName ~= nil, ("No shortname found for class: " .. (class or "nil") .. " spec: " .. (spec or "nil")))) then
                local shortNamePrefix = (spec and spec ~= "") and "s:" or "c:";
                tinsert(tokens, shortNamePrefix .. shortName);
            else
                local simpleToken = "";
                -- Add spec
                if(spec ~= nil and spec ~= "") then
                    simpleToken = simpleToken .. negatedPrefix .. " ";
                end

                -- Add class
                tinsert(tokens, simpleToken.."c:"..class);
            end
        end
    end

    currentActions = {}

    Search:CommitQuickSearch_OLD(tokens, false);
end

local function SplitAtLastComma(input)
    local before, after = input:match("^(.*),%s*(.*)$");
    
    if before then
        before = before .. ", ";
    else
        before = "";
        after = input;
    end

    return before, after;
end

function Search:CommitQuickSearch_OLD(tokens, isNegated)
    assert(tokens and #tokens > 0);
    
    local previousSearch = IsShiftKeyDown() and Search:SanitizeInput(Search.current["display"] or "") or "";
    
    local isNewSegment = previousSearch == "" or previousSearch:match(",[%s!]*$");

    -- TODO: Consider if we want an option for this
    -- Forces new segment per quick search.
    local forceNewSegment = true;
    if(forceNewSegment and not isNewSegment) then
        previousSearch = previousSearch .. ", ";
        isNewSegment = true;
    end

    local previousSegments, currentSegment = SplitAtLastComma(previousSearch);
    
    local negatedSymbol = isNegated and '!' or '';
    
    -- Add, replace or skip each token
    -- Split value into table
    for _,token in ipairs(tokens) do
        local escapedToken = token:gsub("-", "%-");

        -- TODO: Look for existing token of same explicit type instead? (Avoids cases of requiring multiple of the same race. Possibly allowing multiple negated but only one non-negated?)
        if(currentSegment:find(escapedToken)) then
            if(isNegated) then
                if(not currentSegment:find('!'..escapedToken)) then
                    currentSegment = currentSegment:gsub(escapedToken, '!'..token);
                end
            else
                currentSegment = currentSegment:gsub('!'..escapedToken, token);
            end
        else -- Unique token, add directly
            if(currentSegment ~= "") then
                currentSegment = currentSegment .. " ";
            end
            currentSegment =  currentSegment .. negatedSymbol .. token;
        end
    end
    
    -- No previous segment, or a previous segment that ends with comma and only exclamation marks or spaces after
    if(isNewSegment) then
        currentSegment = currentSegment;
    end
    
    ArenaAnalyticsScrollFrame.searchBox:ClearFocus();
    Search:CommitSearch(previousSegments .. currentSegment);
end