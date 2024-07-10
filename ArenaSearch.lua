local _, ArenaAnalytics = ... -- Namespace
ArenaAnalytics.Search = {}
local Search = ArenaAnalytics.Search;

local Options = ArenaAnalytics.Options;
local Constants = ArenaAnalytics.Constants;

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

local function ColorizeSymbol(text)
    return text and "|cff00ccff" .. text .. "|r" or "";
end

local function ColorizeToken(token)
    if(token == nil) then
        return "";
    end

    local text = token["value"];
    return text and "|cffFFFFFF" .. text .. "|r" or "";
end

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
    if(spec) then
        local specKey = class .. "|" .. spec;
        shortName = QuickSearchValueTable["spec"][specKey:lower()];
    else
        shortName = QuickSearchValueTable["class"][class:lower()];
    end

    ArenaAnalytics:Log("Short name for class: ", class, " and spec: ", spec, "=",shortName);

    return shortName;
end

---------------------------------
-- Prefix Data
---------------------------------

local PrefixTable = {
    ["name"] = { NoSpaces = true, Aliases = {"name", "n"} },
    ["class"] = { NoSpaces = false, Aliases = {"class", "c"} },
    ["spec"] = { NoSpaces = false, Aliases = {"spec", "s"} },
    ["subspec"] = { NoSpaces = false, Aliases = {"subspec", "ss"} },
    ["role"] = {NoSpaces = true, Aliases = { "role" }},
    ["race"] = { NoSpaces = false, Aliases = {"race", "r"} },
    ["faction"] = { NoSpaces = true, Aliases = {"faction", "f"} },
    ["alts"] = { NoSpaces = true, Aliases = {"alts", "a"} },
    ["team"] = { NoSpaces = true, Aliases = {"team", "t"}}
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
    return nil, (value or text), true;
end

---------------------------------
-- Search Type Data tables
---------------------------------

-- TODO: Update to allow order here to determine priority for shared keywords 
    -- (E.g., "Frost" would match first found here (Death Knight or Mage))
    -- For now, it's sorted by the spec ID forcing constant priority here.
SearchTokenTypeTable = {
    ["class"] = {
        ["noSpace"] = false,
        ["values"] = {
            ["death knight"] = {"death knight", "deathknight", "dk"},
            ["demon hunter"] = {"demon hunter", "demonhunter", "dh"},
            ["druid"] = {"druid"},
            ["hunter"] = {"hunter", "hunt", "huntard"},
            ["mage"] = {"mage"},
            ["monk"] = {"monk"},
            ["paladin"] = {"paladin", "pala"},
            ["priest"] = {"priest"},
            ["rogue"] = {"rogue", "rog"},
            ["shaman"] = {"shaman", "sham"},
            ["warlock"] = {"warlock", "lock", "wlock"},
            ["warrior"] = {"warrior"},
        }
    },
    ["spec"] = {
        ["noSpace"] = false,
        ["values"] = {
            -- Ambiguous
            ["frost"] = {"frost"},
            ["restoration"] = {"restoration", "resto"},
            ["holy"] = {"holy"},
            ["protection"] = {"protection", "prot"},

            -- Druid
            [1] = { "restoration druid", "resto druid", "rdruid", "rd" },
            [2] = { "feral", "fdruid" },
            [3] = { "balance", "bdruid", "moonkin", "boomkin", "boomy" },
            
            -- Paladin
            [11] = { "holy paladin", "holy pala", "holy pal", "hpal", "hpala", "hpaladin", "holypaladin", "holypala"},
            [12] = { "protection paladin", "prot paladin", "protection pala", "prot pala"},
            [13] = { "preg" },
            [14] = { "retribution", "retribution", "ret", "rpala" },
            
            -- Shaman
            [21] = { "restoration shaman", "restoration sham", "resto shaman", "resto sham", "rshaman", "rsham" },
            [22] = { "elemental", "elemental", "ele", "ele" },
            [23] = { "enhancement", "enhancement", "enh", "enh" },

            -- Death Knight
            [31] = { "unholy", "uhdk", "udk", "uh" },
            [32] = { "frost death knight", "frost deathknight", "frost dk", "fdk" },
            [33] = { "bdk", "blood" },

            -- Hunter
            [41] = { "beast mastery", "beastmastery", "bm", "bmhunter", "bmhunt" },
            [42] = { "marksmanship", "marksman", "mm", "mmhunter", "mmhunt" },
            [43] = { "survival", "surv", "shunter", "shunt", "sh" },

            -- Mage
            [51] = { "frost mage"},
            [52] = { "fire" },
            [53] = { "arcane", "amage" },

            -- Rogue
            [61] = { "subtlety", "sub", "srogue", "srog" },
            [62] = { "assassination", "assa", "arogue" },
            [63] = { "combat", "crogue" },
            [64] = { "outlaw", "orogue" },

            -- Warlock
            [71] = { "affliction", "affli", "awarlock", "alock" },
            [72] = { "destruction", "destro" },
            [73] = { "demonology", "demo" },

            -- Warrior
            [81] = { "protection warrior", "protection warr", "prot warrior", "prot warr", "protection war", "prot war", "pwarrior", "pwarr" },
            [82] = { "arms", "awarrior", "awarr" },
            [83] = { "fury", "fwarrior", "fwarr", "fwar" },
            
            -- Priest
            [91] = { "discipline", "disc", "dpriest", "dp" },
            [92] = { "holy priest", "hpriest" },
            [93] = { "shadow", "spriest", "sp" },
        },
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
    },
    ["team"] = {
        ["noSpace"] = true,
        ["values"] = {
            ["team"] = {"friend", "team", "ally", "help", "partner"},
            ["enemyTeam"] = {"enemy", "foe", "harm"},
        }
    },
    ["role"] = {
        ["noSpace"] = true,
        ["values"] = {
            ["tank"] = {"tank"},
            ["healer"] = {"healer"},
            ["dps"] = {"damage dealer", "damage", "dps"},
        },
    },
    ["logical"] = {
        ["requireExact"] = true,
        ["values"] = {
            ["not"] = { "not", "inverse" }
        }
    }
}

local function CalculateMatchScore(searchInput, matchedValue, startIndex)
    local maxPartialSearchDiff = 5;

    local matchedCountScore = (#searchInput / #matchedValue);
    local differenceScore = 1 - ((#matchedValue - #searchInput) / maxPartialSearchDiff)
    local startIndexScore = 1 - ((startIndex * startIndex) / (#matchedValue * #matchedValue));

    -- Return weighted score
    return (matchedCountScore * 0.5) + (differenceScore * 0.3) + (startIndexScore * 0.2);
end

-- TODO: Look for best match, not just first unless it's exact.
-- Find typeKey, valueKey, noSpace from SearchTokenTypeTable
local function FindSearchValueDataForToken(token)
    assert(token);

    if(token["value"] == nil or #token["value"] < 2) then
        return;
    end

    local lowerCaseValue = token["value"]:lower();
    
    -- Cached info about the best match
    local bestMatch = nil;
    local function TryUpdateBestMatch(matchedValue, valueKey, typeKey, noSpace, startIndex)
        local score = CalculateMatchScore(lowerCaseValue, matchedValue, startIndex);
        if(not bestMatch or score > bestMatch["score"]) then
            bestMatch = {
                ["score"] = score,
                
                ["typeKey"] = typeKey,
                ["valueKey"] = valueKey,
                ["noSpace"] = noSpace,
            }                                
        end
    end

    local function FindTokenValueKey(valueTable, searchType)
        assert(valueTable and valueTable["values"]);

        for valueKey, values in pairs(valueTable["values"]) do
            for _, value in ipairs(values) do
                assert(value);
                if(lowerCaseValue == value) then
                    return valueKey, true, value;
                elseif(not token["exact"] and not valueTable["requireExact"]) then
                    local foundStartIndex = value:find(lowerCaseValue);
                    if(foundStartIndex ~= nil) then
                        TryUpdateBestMatch(value, valueKey, searchType, valueTable["noSpace"], foundStartIndex);
                    end
                end
            end
        end
    end

    -- Look through the values for the explicit key
    if token["type"] then
        local valueTable = SearchTokenTypeTable[token["type"]];
        if valueTable then
            local valueKey, isExactMatch = FindTokenValueKey(valueTable, token["type"])
            if isExactMatch then
                return token["type"], valueKey, valueTable["noSpace"];
            end
        end
    else -- Look through all keys
        for typeKey, valueTable in pairs(SearchTokenTypeTable) do
            local valueKey, isExactMatch = FindTokenValueKey(valueTable, typeKey)
            if isExactMatch then
                return typeKey, valueKey, valueTable["noSpace"];
            end
        end
    end

    -- Evaluate best match so far, if any.
    if(bestMatch) then
        return bestMatch["typeKey"], bestMatch["valueKey"], bestMatch["noSpace"];
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
            local name = ToLower(player["name"]);
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

    local playerValue = ToLower(player[searchType]);
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
        if(CheckTokenForPlayer(token, player) == (token["negated"] or false)) then
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
            local checkResult = CheckSegmentForPlayer(segment, player);
            if(checkResult) then
                if(alreadyMatchedPlayers[player["name"]] == nil) then
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
    for _,segment in ipairs(activePlayerSegments) do
        local segmentResult = CheckSegmentForMatch(segment, match, alreadyMatchedPlayers);

        if(segment.inversed) then
            return (segmentResult == false);
        elseif(segmentResult == nil) then
            return nil; -- Segment detected conflict
        elseif(not segmentResult) then
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
    
    newToken["explicitType"] = tokenType;
    newToken["value"] = tokenValue;
    newToken["exact"] = isExact;
    newToken["noSpace"] = noSpace;

    if(newToken["explicitType"] == "alts" or newToken["value"]:find('/') ~= nil) then
        newToken["explicitType"] = "alts";
    elseif(newToken["explicitType"] ~= "name") then
        -- Check for keywords
        local typeKey, valueKey, noSpace = FindSearchValueDataForToken(newToken);
        if(typeKey and valueKey) then
            newToken["noSpace"] = noSpace;
            newToken["explicitType"] = typeKey;
            newToken["keyword"] = valueKey;
        elseif(not newToken["explicitType"] and newToken["value"]:find(' ') == nil) then
            -- Tokens without spaces fall back to name type
            ArenaAnalytics:Log("Search: Forced fallback to name search type.")
            newToken["explicitType"] = "name";
            newToken["noSpace"] = true;
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

    return newToken;
end

local function SanitizeInput(input)
    if(not input or input == "" or input == " ") then
        return "";
    end

    local output = input:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "");
    output = output:gsub("%s%s+", " ");
    return output;
end

-- Process the input string for symbols: Double quotation marks, commas, parenthesis, spaces
local function ProcessInput(input)
    local playerSegments = {}

    local currentSegment = { Tokens = {}}
    local currentToken = nil;
    local currentWord = ""

    local isTokenNegated = false;

    local index = 1;

    local displayString = "";

    input = SanitizeInput(input);
    if(input == "") then
        return playerSegments, displayString, input;
    end

    ----------------------------
    -- internal functions

    local function CommitCurrentSegment()
        if(currentSegment and #currentSegment.Tokens > 0) then
            if(not currentSegment.team and Options:Get("searchDefaultExplicitEnemy")) then
                currentSegment.team = "enemyTeam";
            end

            tinsert(playerSegments, currentSegment);
        end

        currentSegment = { Tokens = {}}
    end

    local function CommitCurrentToken()
        if(not currentToken) then
            return;
        end

        currentToken["value"] = ToLower(currentToken["keyword"] or currentToken["value"]);

        if(currentToken["explicitType"] == "logical") then
            if(currentToken["value"] == "not") then
                ArenaAnalytics:Log("Inversed segment!")
                currentSegment.inversed = true;
            end
        elseif(currentToken["explicitType"] == "team") then
            if(currentToken["value"] == "team") then
                currentSegment.team = "team";
            elseif(currentToken["value"] == "team") then
                currentSegment.team = "enemyTeam";
            end
        else -- Commit a real search token
            currentToken["negated"] = isTokenNegated or nil;
            
            if(currentToken["value"] and currentToken["value"] ~= "") then
                tinsert(currentSegment.Tokens, currentToken);
            end
        end
        currentToken = nil;
        isTokenNegated = false;
    end

    local function CommitCurrentWord()
        if(not currentWord or currentWord == "") then
            return;
        end

        if(currentToken) then
            local combinedValue = currentToken["value"] .. " " .. currentWord;
            local newCombinedToken = CreateToken(combinedValue);
            
            if(newCombinedToken) then
                ArenaAnalytics:Log("Updating token for combined word: ", combinedValue);
                currentToken = newCombinedToken;
                currentWord = ""; -- Already added to the token
            else
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
            if ((#currentSegment.Tokens == 0 and currentWord == "") and lastChar ~= '+' and lastChar ~= '-') then
                currentSegment.team = "team";
                displayString = displayString .. ColorizeSymbol(char);
            else
                displayString = displayString .. ColorizeInvalid(char);
            end
        elseif char == '-' then
            if (lastChar ~= '+' and lastChar ~= '-') then
                if(#currentSegment.Tokens == 0 and currentWord == "") then
                    currentSegment.team = "enemyTeam";
                    displayString = displayString .. ColorizeSymbol(char);
                else
                    displayString = displayString .. char;
                    currentWord = currentWord .. char;
                end
            else
                displayString = displayString .. ColorizeInvalid(char);
            end
        elseif char == '!' then
            if((currentWord == "" or lastChar == ':') and lastChar ~= '!') then
                CommitCurrentToken();
                isTokenNegated = true;
                displayString = displayString .. ColorizeSymbol(char);
            else
                displayString = displayString .. ColorizeInvalid(char);
            end
        elseif char == ' ' then
            CommitCurrentWord()
            displayString = displayString .. char;
        elseif char == ',' or char == '.' or char == ';' then
            CommitCurrentWord()
            CommitCurrentToken()
            CommitCurrentSegment()

            displayString = displayString .. ColorizeSymbol(char);
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

                -- Commit the new token immediately
                CommitCurrentToken();
                                
                index = endIdx
                
                displayString = displayString .. ColorizeSymbol('"') .. scope .. ColorizeSymbol('"');
            else -- Invalid scope
                -- TODO: Add red color
                displayString = displayString .. ColorizeInvalid(char);
            end
        elseif char == ":" then
            CommitCurrentToken()
            currentWord = currentWord .. char;
            displayString = displayString .. ColorizeSymbol(char);
        elseif char == "(" then
            local endIdx = GetScopeEndIndex(')')
            if endIdx then
                if(lastChar ~= ':') then
                    CommitCurrentWord();
                end
                CommitCurrentToken();

                local scope = input:sub(index + 1, endIdx - 1)
                currentToken = CreateToken(currentWord .. scope);
                currentWord = "";

                -- Commit the new token immediately
                CommitCurrentToken();
                                
                index = endIdx
                displayString = displayString .. ColorizeSymbol('(') .. scope .. ColorizeSymbol(')');
            else -- Invalid scope
                displayString = displayString .. ColorizeInvalid(char);
            end
        elseif char == ")" then
            -- Ignore invalid closing of scope
            displayString = displayString .. ColorizeInvalid(char);
        elseif char == '/' then
            currentWord = currentWord .. char
            displayString = displayString .. ColorizeSymbol(char);
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

    return playerSegments, displayString, input;
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
    ArenaAnalytics.Filter:RefreshFilters();
end

function Search:CommitSearch(input)
    -- Update active search filter
    Search:Update(input);
    activePlayerSegments = Search.current["data"];
    
    ArenaAnalytics:Log("Committing Search..", #activePlayerSegments);

    for i,segment in ipairs(activePlayerSegments) do
        for j,token in ipairs(segment.Tokens) do
            assert(token and token["value"]);
            ArenaAnalytics:Log("  Token", j, "in segment",i, "has values:", token["value"], token["exact"], token["explicitType"], token["negated"], segment.team, segment.inversed);
        end
    end

    -- Force filter refresh
    ArenaAnalytics.Filter:RefreshFilters();
end

function Search:Update(input)
    local playerrSegments, display, raw = ProcessInput(input);

    Search.current["raw"] = raw;
    Search.current["display"] = display;
    Search.current["data"] = playerrSegments;

    ArenaAnalyticsScrollFrame.searchBox:SetText(display);
end

---------------------------------
-- Quick Search
---------------------------------

function Search:QuickSearch(mouseButton, name, class, spec, race, team)
    local prefix, tokens = '', {};
    local isNegated = (mouseButton == "RightButton");

    if(team == "team") then
        prefix = '+';
    elseif(team == "enemyTeam") then
        prefix = '-';
    end

    if(not IsShiftKeyDown() and not IsControlKeyDown()) then
        local shouldHideMyRealm = true;
        local shouldHideAnyRealm = true;

        if(shouldHideAnyRealm) then
            name = name:match("(.*)-") or "";
        elseif(shouldHideMyRealm) then
            local _, realm = UnitFullName("player");
            if(realm and name:find(realm)) then
                name = name:match("(.*)-") or "";
            end
        end

        if(name == "") then
            return;
        end

        -- Add name only
        tinsert(tokens, name);
    else
        if(IsControlKeyDown() and race ~= nil) then
            -- Add race if available
            local shortName = Search:GetShortQuickSearchSpec("race", race);
            tinsert(tokens, "r:"..(shortName or race));
        end
        
        if(IsShiftKeyDown() and class ~= nil) then
            local shortName = Search:GetShortQuickSearchSpec(class, spec);
            if(ForceDebugNilError(shortName)) then
                local shortNamePrefix = spec and "s:" or "c:";
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

    Search:CommitQuickSearch(prefix, tokens, isNegated);
end

local function SplitAtLastComma(input)
    local before, after = input:match("^(.*),%s*(.*)$");
    
    if before then
        before = before .. ",";
    else
        before = "";
        after = input;
    end

    return before, after;
end

function Search:CommitQuickSearch(prefix, tokens, isNegated)
    assert(tokens and #tokens > 0);
    
    local previousSearch = IsAltKeyDown() and SanitizeInput(Search.current["display"] or "") or "";
    local previousSegments, currentSegment = SplitAtLastComma(previousSearch);
    
    local negatedSymbol = isNegated and '!' or '';
    
    -- Add, replace or skip each token
    -- Split value into table
    for _,token in ipairs(tokens) do
        local escapedToken = token:gsub("-", "%-");
        ArenaAnalytics:Print(token)

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
    local isNewSegment = previousSearch == "" or previousSearch:match(",[%s!]*$");
    if(isNewSegment) then
        currentSegment = prefix .. currentSegment;
    end
    
    Search:CommitSearch(previousSegments .. currentSegment);
end