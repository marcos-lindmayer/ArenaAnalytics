local _, ArenaAnalytics = ... -- Namespace
ArenaAnalytics.Search = {}
local Search = ArenaAnalytics.Search;

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

-- OTHER: Setup to allow adding desired search conditions

-- Exact Search:
--  Wrap one or more terms in quotation marks to require an exact match
--  Decide what to do when exact search start and end among different players


-- Complex search examples:
--  player1 frost "death knigh, hunter beast master alt1"/alt2partial/"alt3"

-- Helper function 
local function ToLower(value)
    if(value and type(value) == "string") then
        return value:lower();
    end
    return value;
end

---------------------------------
-- Search Colors
---------------------------------

local function ColorizeInvalid(text)
    return text and "|cffFF0000" .. text .. "|r" or "";
end

local function ColorizeToken(token)
    if(token == nil) then
        return "";
    end

    local text = token["value"];
    return text and "|cffFFFFFF" .. text .. "|r" or "";
end

---------------------------------
-- Prefix Data
---------------------------------

local PrefixTable = {
    ["name"] = { NoSpaces = true, Aliases = {"name", "n"} },
    ["class"] = { NoSpaces = false, Aliases = {"class", "c"} },
    ["spec"] = { NoSpaces = false, Aliases = {"spec", "s"} },
    ["subspec"] = { NoSpaces = false, Aliases = {"subspec", "ss"} },
    ["race"] = { NoSpaces = true, Aliases = {"race", "r"} },
    ["faction"] = { NoSpaces = true, Aliases = {"faction", "f"} },
    ["alts"] = { NoSpaces = true, Aliases = {"alts", "a"} },
}

-- Find the prefix key from the given token
local function GetTokenPrefixKey(text)
    local prefix, value = text:match("([^:]+):(.+)");
    if prefix then
        for key,data in pairs(PrefixTable) do
            assert(data.Aliases and #data.Aliases > 0);
            
            for _,alias in ipairs(data.Aliases) do
                if(prefix == alias) then
                    return key, value, data.NoSpaces;
                end
            end
        end
    end
    return nil, (value or text), false;
end

---------------------------------
-- Search Type Data tables
---------------------------------

-- TODO: Convert spec keys to AA spec IDs (?)
SearchTokenTypeTable = {
    ["spec"] = {
        ["noSpace"] = false,
        ["values"] = {
            -- Druid
            [1] = { "restoration druid", "rdruid" },
            [2] = { "feral", "fdruid" },
            [3] = { "balance druid", "balance", "bdruid", "boomkin" },
            
            -- Paladin
            [11] = { "holy paladin", "holy pala", "hpal", "hpala", "hpaladin", "holypaladin", "holypala"},
            [12] = { "protection paladin", "prot paladin", "protection pala", "prot pala"},
            [13] = { "preg paladin", "preg pala", "preg" },
            [14] = { "retribution paladin", "retribution pala", "ret paladin", "ret pala", "rpala", "retribution", "ret" },
            
            -- Shaman
            [21] = { "restoration shaman", "restoration sham", "resto shaman", "resto sham", "rshaman", "rsham" },
            [22] = { "elemental shaman", "elemental sham", "ele shaman", "ele sham", "esham", "elemental", "ele" },
            [23] = { "enhancement shaman", "enhancement sham", "enh shaman", "enh sham", "enh" },

            -- Death Knight
            [31] = { "unholy", "uhdk", "udk", "uh" },
            [32] = { "frost death knight", "frost deathknight", "frost dk", "fdk" },
            [33] = { "bdk", "blood" },

            -- Hunter
            [41] = { "beast mastery", "beastmastery", "bm", "bmhunter", "bmhunt" },
            [42] = { "marksmanship", "marksman", "mm", "mmhunter", "mmhunt" },
            [43] = { "survival", "surv", "shunter", "shunt", "sh" },

            -- Mage
            [51] = { "frost mage" },
            [52] = { "fire" },
            [53] = { "arcane", "amage" },

            -- Rogue
            [61] = { "subtlety", "sub", "srogue", "srog" },
            [62] = { "assassination", "assa", "arogue", "arog" },
            [63] = { "Combat", "crogue", "crog" },
            [64] = { "Outlaw", "orogue" },

            -- Warlock
            [71] = { "affliction", "affli", "awarlock", "alock" },
            [72] = { "destruction", "destro" },
            [73] = { "demonology", "demo" },

            -- Warrior
            [81] = { "protection warrior", "protection warr", "prot warrior", "prot warr", "protection war", "prot war", "pwarrior", "pwarr", "pwar" },
            [82] = { "arms", "awarrior", "awarr", "awar" },
            [83] = { "fury", "fwarrior", "fwarr", "fwar" },
            
            -- Priest
            [91] = { "discipline", "disc", "dpriest", "dp" },
            [92] = { "holy priest", "hpriest" },
            [93] = { "shadow", "spriest", "sp" },
        },
    },
    ["class"] = {
        ["noSpace"] = false,
        ["values"] = {
            ["death knight"] = {"death knight", "deathknight", "dk"},
            ["demon hunter"] = {"demon hunter", "demonhunter", "dh"},
            ["druid"] = {"druid"},
            ["hunter"] = {"hunter"},
            ["mage"] = {"mage"},
            ["monk"] = {"monk"},
            ["paladin"] = {"paladin"},
            ["priest"] = {"priest"},
            ["rogue"] = {"rogue"},
            ["shaman"] = {"shaman"},
            ["warlock"] = {"warlock"},
            ["warrior"] = {"warrior"}
        }
    },
    ["race"] = {
        ["noSpace"] = false,
        ["values"] = {
            ["blood elf"] = {"blood elf", "bloodelf", "belf"},
            ["draenei"] = {"draenei"},
            ["dwarf"] = {"dwarf"},
            ["gnome"] = {"gnome"},
            ["goblin"] = {"goblin"},
            ["human"] = {"human"},
            ["night elf"] = {"night elf", "nightelf", "nelf"},
            ["orc"] = {"orc"},
            ["pandaren"] = {"pandaren"},
            ["tauren"] = {"tauren"},
            ["troll"] = {"troll"},
            ["undead"] = {"undead"},
            ["worgen"] = {"worgen"},
            ["void elf"] = {"void elf", "voidelf", "velf"},
            ["lightforged draenei"] = {"lightforged draenei", "lightforgeddraenei", "ldraenei"},
            ["nightborne"] = {"nightborne"},
            ["highmountain tauren"] = {"highmountain tauren", "highmountaintauren", "htauran"},
            ["zandalari troll"] = {"zandalari troll", "zandalaritroll", "ztroll"},
            ["kul tiran"] = {"kul tiran", "kultiran"},
            ["dark iron dwarf"] = {"dark iron dwarf", "darkirondwarf", "didwarf", "ddwarf"},
            ["mag'har orc"] = {"mag'har orc", "magharorc", "morc"},
            ["mechagnome"] = {"mechagnome", "mgnome"},
            ["vulpera"] = {"vulpera"}
        }
    },
    ["faction"] = {
        ["noSpace"] = true,
        ["values"] = {
            ["alliance"] = {"alliance"},
            ["horde"] = {"horde"},
        }
    }
}

-- Find typeKey, valueKey, noSpace, matchedValue from SearchTokenTypeTable
local function FindSearchValueDataForToken(token)
    assert(token);

    if(token["value"] == nil or token["value"] == "") then
        return;
    end

    local lowerCaseValue = token["value"]:lower();

    local function FindTokenValueKey(valueTable, requireExact)
        for valueKey, values in pairs(valueTable["values"]) do
            for _, value in ipairs(values) do
                assert(value)
                local isMatch = not token["exact"] and (value:find(lowerCaseValue) ~= nil) or (lowerCaseValue == value);
                if isMatch then
                    return valueKey, valueTable["noSpace"], value
                end
            end
        end
    end

    -- Look through the values for the explicit key
    if token["type"] and token["type"] ~= "any" then
        local valueTable = SearchTokenTypeTable[token["type"]];
        if valueTable then
            local valueKey, noSpace, matchedValue = FindTokenValueKey(valueTable, lowerCaseValue, isExactScope)
            if valueKey then
                return token["type"], valueKey, noSpace, matchedValue;
            end
        end
    else -- Look through all keys
        for typeKey, valueTable in pairs(SearchTokenTypeTable) do
            local valueKey, noSpace, matchedValue = FindTokenValueKey(valueTable, lowerCaseValue, isExactScope)
            if valueKey then
                return typeKey, valueKey, noSpace, matchedValue;
            end
        end
    end
end

-- The current search data
Search.current = {
    ["raw"] = "", -- The raw search string
    ["display"] = "", -- Search string sanitized and colored(?) for display
    ["data"] = nil, -- Search data as a table for efficient comparisons
}

activePlayerSegments = {};

---------------------------------
-- Search matching logic
---------------------------------

-- Returns true if a given type on a player matches the given value
local function CheckTypeForPlayer(searchType, token, player)
    assert(token and token["value"] and token["value"] ~= "");
    assert(player ~= nil);
    
    if(searchType == nil or searchType == "any") then
        ArenaAnalytics:Log("Invalid type reached CheckTypeForPlayer for search.");
        return;
    end
    -- Alt search
    if (searchType == "alts") then
        if(token["value"]:find('/') ~= nil) then
            local playerName = ToLower(player["name"]);
            if(not playerName) then
                return false;
            end

            -- Split value into table
            for value in token["value"]:gmatch("([^/]+)") do
                local isAltMatch = not token["exact"] and playerName:find(value) or (value == playerName);
                if(isAltMatch) then
                    return true;
                end
            end
            
            return false;
        else
            -- Not a table, assume it's a single name
            searchType = "name";
        end
    elseif (searchType == "faction") then
        local playerFaction = player["faction"] or ArenaAnalytics.Constants:GetFactionByRace(player["race"]) or "";
        if(playerFaction ~= "") then
            local isFactionMatch = not token["exact"] and playerFaction:find(token["value"]) or (token["value"] == playerFaction:lower());
            return isFactionMatch;
        else
            return false;
        end
    end

    local playerValue = ToLower(player[searchType]);
    if(not playerValue) then
        return false;
    end
    
    -- Class and Spec IDs may be numbers in the token
    if(tonumber(token["value"])) then
        local playerSpecID = ArenaAnalytics.Constants:getAddonSpecializationID(player["class"], player["spec"], false);
        return playerSpecID == token["value"];
    else
        return not token["exact"] and playerValue:find(token["value"]) or (token["value"] == playerValue);
    end
end

local function CheckTokenForPlayer(token, player)
    local explicitType = token["explicitType"];
    if(explicitType and explicitType ~= "any") then
        if(CheckTypeForPlayer(explicitType, token, player)) then
            return true;
        end
    else -- Loop through all types
        local types = { "spec", "class", "race", "faction", "name", "alts" }
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
    if(player == nil) then
        return;
    end

    for i,token in ipairs(segment.Tokens) do
        if(not CheckTokenForPlayer(token, player)) then
            return false;
        end
    end
    return true;
end

local function CheckSegmentForMatch(segment, match, matchedPlayers)
    local teams = segment.team and {segment.team} or {"team", "enemyTeam"};
    local foundConflictMatch = false;

    for _,team in ipairs(teams) do
        for _, player in ipairs(match[team]) do
            if CheckSegmentForPlayer(segment, player) then
                if(matchedPlayers[player["name"]] == nil) then
                    matchedPlayers[player["name"]] = true;
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
    local matchedPlayers = {}

    -- Look for segments with no matches or no unique matches
    for _,segment in ipairs(activePlayerSegments) do
        local segmentResult = CheckSegmentForMatch(segment, match, matchedPlayers);
        if(segmentResult == nil) then
            return nil; -- Segment detected conflict
        elseif(segmentResult == false) then
            return false; -- Failed to pass.
        end
    end

    -- All segments found a match without conflict
    return true;
end

-- Main Matching Function to Check Feasibility
function Search:DoesMatchPassSearch(match)
    if(#activePlayerSegments == 0) then
        return true;
    end

    if(match == nil) then
        ArenaAnalytics:Log("Nil match reached search filter.")
        return false;
    end

    -- Cannot match a search with more players than the match has data for.
    local matchPlayerCount = #match["team"] + #match["enemyTeam"];
    if(#activePlayerSegments > matchPlayerCount) then
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
-- Search Parsing Logic
---------------------------------

local function CreateToken(text, isExact)
    local newToken = {}
    local tokenType, tokenValue, noSpace = GetTokenPrefixKey(text);
    
    newToken["explicitType"] = tokenType and tokenType or nil;
    newToken["value"] = ToLower(tokenValue);
    newToken["exact"] = isExact;
    newToken["noSpace"] = noSpace;

    if(newToken["explicitType"] == "alts" or newToken["value"]:find('/') ~= nil) then
        newToken["explicitType"] = "alts";
    else
        -- Check for keywords
        local typeKey, valueKey, noSpace, matchedValue = FindSearchValueDataForToken(newToken);
        if(typeKey and valueKey) then
            newToken["noSpace"] = noSpace;
            newToken["explicitType"] = typeKey;
            newToken["keyword"] = ToLower(valueKey);
        end
    end

    -- Invalid token if noSpace is true while it has a space.
    if(newToken["noSpace"] and newToken["value"]:find(' ') ~= nil) then
        ArenaAnalytics:Log("CreateToken made invalid token: ", newToken["value"]);
        return nil;
    end

    if(type(newToken["value"]) == "string") then
        newToken["value"] = newToken["value"]:gsub("-", "%%-");
    end

    ArenaAnalytics:Log("Created token: ", tokenValue);
    return newToken;
end

local function SanitizeInput(input)
    if(not input or input == "") then
        return "";
    end

    -- TODO: Ignore if there's two vertical bars in a row?
    return input:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "");
end

-- Process the input string for symbols: Double quotation marks, commas, parenthesis, spaces
local function ProcessInput(input)
    local playerSegments = {}

    local currentSegment = { Tokens = {}, explicitTeam = nil }
    local currentToken = {}
    local currentWord = ""

    local index = 1;

    local displayString = "";

    input = SanitizeInput(input);
    if(input == "") then
        return playerSegments, displayString, input;
    end

    ----------------------------
    -- internal functions

    local function CommitCurrentSegment()
        if(#currentSegment.Tokens > 0) then
            tinsert(playerSegments, currentSegment);
        end

        currentSegment = { Tokens = {}, explicitTeam = nil }
    end

    local function CommitCurrentToken()
        currentToken["value"] = currentToken["keyword"] or currentToken["value"];

        if(currentToken["value"] and currentToken["value"] ~= "") then
            tinsert(currentSegment.Tokens, currentToken);
        end
        currentToken = {}
    end

    local function CommitCurrentWord()
        if(currentWord == "") then
            return;
        end

        if(currentToken["value"] and currentToken["value"] ~= "") then
            local combinedValue = currentToken["value"] .. " " .. currentWord;
            local newCombinedToken = CreateToken(combinedValue);
            
            if(newCombinedToken) then
                currentToken = newCombinedToken;
                currentWord = ""; -- Already added to the token
            else
                ArenaAnalytics:Log("Committing old token.");
                CommitCurrentToken();
            end
        end
        
        -- Might have been added to token by now
        if(currentWord ~= "") then
            currentToken = CreateToken(currentWord);

            -- Commit immediately if no space is allowed
            if(currentToken and currentToken["noSpace"]) then
                -- Commit new token immediately
                CommitCurrentToken();
            end
        end
        currentWord = "";
    end

    local function GetScopeEndIndex(endSymbol)
        assert(endSymbol ~= nil);
        
        for scopeIndex = index + 1, #input do
            local char = input:sub(scopeIndex, scopeIndex);
            if(char == endSymbol) then
                return scopeIndex;
            elseif(char == ",") then
                return nil;
            end
        end
    end

    local lastChar = nil;
    while index <= #input do
        local char = input:sub(index, index)
        
        if char == "+" then
            if #currentSegment.Tokens == 0 and currentWord == "" then
                currentSegment.team = "team";
                displayString = displayString .. char;
            else
                displayString = displayString .. ColorizeInvalid(char);
            end
        elseif char == '-' then
            if #currentSegment.Tokens == 0 and currentWord == "" then
                currentSegment.team = "enemyTeam";
            else
                currentWord = currentWord .. "-";
            end
            displayString = displayString .. char;
        elseif char == ' ' then
            CommitCurrentWord()
            
            displayString = displayString .. char;
        elseif char == ',' then
            CommitCurrentWord()
            CommitCurrentToken()
            CommitCurrentSegment()

            displayString = displayString .. char;
        elseif char == '"' then
            local endIdx = GetScopeEndIndex('"')
            if endIdx then
                if(lastChar ~= ':') then
                    CommitCurrentWord();
                end
                CommitCurrentToken();

                local scope = input:sub(index + 1, endIdx - 1);
                currentToken = CreateToken(currentWord .. scope, true);
                currentWord = "";
                                
                index = endIdx
                
                displayString = displayString .. '"' .. scope .. '"';
            else -- Invalid scope
                -- TODO: Add red color
                displayString = displayString .. "|cffff0000" .. char .. "|r";
            end
        elseif char == ":" then
            CommitCurrentToken()
            currentWord = currentWord .. char;
            displayString = displayString .. char;
        elseif char == "(" then
            local endIdx = GetScopeEndIndex(')')
            if endIdx then
                if(lastChar ~= ':') then
                    ArenaAnalytics:Print("test: ", lastChar)
                    CommitCurrentWord();
                end
                CommitCurrentToken();

                local scope = input:sub(index + 1, endIdx - 1)
                currentToken = CreateToken(currentWord .. scope, false);
                currentWord = "";
                                
                index = endIdx
                displayString = displayString .. '(' .. scope .. ')';
            else -- Invalid scope
                -- TODO: Add red color
                displayString = displayString .. "|cffff0000" .. char .. "|r";
            end
        elseif char == ")" then
            -- Ignore invalid closing of scope
            displayString = displayString .. "|cffff0000" .. char .. "|r";
        else
            currentWord = currentWord .. char
            displayString = displayString .. char;
        end
        
        lastChar = char;
        index = index + 1
    end

    -- Final commit for any remaining data
    CommitCurrentWord()
    CommitCurrentToken()
    CommitCurrentSegment()

    return playerSegments, displayString, input
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
    return Search.current["display"] or Search.current["raw"] or "???";
end

function Search:IsEmpty()
    return Search.current["raw"] == "" and Search.current["display"] == "" and Search.current[data] == nil and #activePlayerSegments == 0;
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
    activePlayerSegments = {}

    -- Trigger filter refresh
    ArenaAnalytics.Filter:refreshFilters();
end

function Search:CommitSearch(input)
    -- Update active search filter
    Search:Update(input);
    activePlayerSegments = Search.current["data"];
    
    ArenaAnalytics:Log("Committing Search..", #activePlayerSegments);

    for i,segment in ipairs(activePlayerSegments) do
        for j,token in ipairs(segment.Tokens) do
            assert(token and token["value"]);
            ArenaAnalytics:Log("Token", j, "in segment",i, "has values:", token["value"], token["exact"], token["explicitType"], segment.team);
        end
    end

    -- Force filter refresh
    ArenaAnalytics.Filter:refreshFilters();
end

function Search:Update(input)
    local playerrSegments, display, raw = ProcessInput(input);

    Search.current["raw"] = raw;
    Search.current["display"] = display;
    Search.current["data"] = playerrSegments;
end
