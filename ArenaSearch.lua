local _, ArenaAnalytics = ... -- Namespace
ArenaAnalytics.Search = {}
local Search = ArenaAnalytics.Search;

-- DOCUMENTATION
-- Player Name
--  Charactername // name:Charactername // n:Charactername // Charactername-server // etc

-- Alts
--  altone|alttwo|altthree // name:ltone|alttwo|altthree // n:ltone|alttwo|altthree
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
--  player1 frost "death knigh, hunter beast master alt1"|alt2partial|"alt3"

---------------------------------
-- Prefix Data
---------------------------------

local PrefixTable = {
    ["name"] = { NoSpaces = true, Aliases = {"name", "n"} },
    ["class"] = { NoSpaces = false, Aliases = {"class", "c"} },
    ["spec"] = { NoSpaces = false, Aliases = {"spec", "s"} },
    ["subspec"] = { NoSpaces = false, Aliases = {"subspec", "ss"} },
    ["race"] = { NoSpaces = true, Aliases = {"race", "r"} },
    ["faction"] = { NoSpaces = true, Aliases = {"faction", "f"} }
}

-- Find the prefix key from the given token
function Search:GetTokenPrefixKey(token)
    -- Get value before colon
    -- Remove special symbols? (Double quotes, comma, space)?


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
            ["Druid"] = 0,
            [1] = { "restoration druid", "rdruid" }
            [2] = { "feral", "fdruid" }
            [3] = { "balance druid", "balance", "bdruid", "boomkin" }
            
            -- Paladin
            ["Paladin"] = 10,
            [11] = { "holy paladin", "holy pala", "hpal", "hpala", "hpaladin", "holypaladin", "holypala"}
            [12] = { "protection paladin", "prot paladin", "protection pala", "prot pala"}
            [13] = { "preg paladin", "preg pala", "preg" }
            [14] = { "retribution paladin", "retribution pala", "ret paladin", "ret pala", "rpala", "retribution", "ret" }
            
            -- Shaman
            ["Shaman"] = 20,
            [21] = { "restoration shaman", "restoration sham", "resto shaman", "resto sham", "rshaman", "rsham" }
            [22] = { "elemental shaman", "elemental sham", "ele shaman", "ele sham", "esham", , "elemental", "ele" }
            [23] = { "enhancement shaman", "enhancement sham", "enh shaman", "enh sham", "enh" }

            -- Death Knight
            ["Death Knight"] = 30,
            [31] = { "unholy", "uhdk", "udk", "uh" }
            [32] = { "frost death knight", "frost deathknight", "frost dk", "fdk" }
            [33] = { "bdk", "blood" }

            -- Hunter
            ["Hunter"] = 40,
            [41] = { "beast mastery", "beastmastery", "bm", "bmhunter", "bmhunt" }
            [42] = { "marksmanship", "mm", "mmhunter", "mmhunt" }
            [43] = { "survival", "surv", "shunter", "shunt", "sh" }

            -- Mage
            ["Mage"] = 50,
            [51] = { "frost mage" }
            [52] = { "fire" }
            [53] = { "arcane", "amage" }

            -- Rogue
            ["Rogue"] = 60,
            [61] = { "subtlety", "sub", "srogue", "srog" }
            [62] = { "assassination", "assa", "arogue", "arog" }
            [63] = { "Combat", "crogue", "crog" }
            [64] = { "Outlaw", "orogue" }

            -- Warlock
            ["Warlock"] = 70,
            [71] = { "affliction", "affli", "awarlock", "alock" }
            [72] = { "destruction", "destro" }
            [73] = { "demonology", "demo" }

            -- Warrior
            ["Warrior"] = 80,
            [81] = { "protection warrior", "protection warr", "prot warrior", "prot warr", "protection war", "prot war", "pwarrior", "pwarr", "pwar" }
            [82] = { "arms", "awarrior", "awarr", "awar" }
            [83] = { "fury", "fwarrior", "fwarr", "fwar" }
            
            -- Priest
            ["Priest"] = 90,
            [91] = { "discipline", "disc", "dpriest", "dp" }
            [92] = { "holy priest", "hpriest" }
            [93] = { "shadow", "spriest", "sp" }
        }
    },
    ["class"] = {
        ["noSpace"] = false,
        ["values"] = {
            ["Death Knight"] = {"death knight", "deathknight", "dk"},
            ["Demon Hunter"] = {"demon hunter", "demonhunter", "dh"},
            ["Druid"] = {"druid"},
            ["Hunter"] = {"hunter"},
            ["Mage"] = {"mage"},
            ["Monk"] = {"monk"},
            ["Paladin"] = {"paladin"},
            ["Priest"] = {"priest"},
            ["Rogue"] = {"rogue"},
            ["Shaman"] = {"shaman"},
            ["Warlock"] = {"warlock"},
            ["Warrior"] = {"warrior"}
        }
    },
    ["race"] = {
        ["noSpace"] = false,
        ["values"] = {
            ["Blood Elf"] = {"blood elf", "bloodelf"},
            ["Draenei"] = {"draenei"},
            ["Dwarf"] = {"dwarf"},
            ["Gnome"] = {"gnome"},
            ["Goblin"] = {"goblin"},
            ["Human"] = {"human"},
            ["Night Elf"] = {"night elf", "nightelf"},
            ["Orc"] = {"orc"},
            ["Pandaren"] = {"pandaren"},
            ["Tauren"] = {"tauren"},
            ["Troll"] = {"troll"},
            ["Undead"] = {"undead"},
            ["Worgen"] = {"worgen"},
            ["Void Elf"] = {"void elf", "voidelf"},
            ["Lightforged Draenei"] = {"lightforged draenei", "lightforgeddraenei"},
            ["Nightborne"] = {"nightborne"},
            ["Highmountain Tauren"] = {"highmountain tauren", "highmountaintauren"},
            ["Zandalari Troll"] = {"zandalari troll", "zandalaritroll"},
            ["Kul Tiran"] = {"kul tiran", "kultiran"},
            ["Dark Iron Dwarf"] = {"dark iron dwarf", "darkirondwarf"},
            ["Mag'har Orc"] = {"mag'har orc", "magharorc"},
            ["Mechagnome"] = {"mechagnome"},
            ["Vulpera"] = {"vulpera"}
        }
    },
    ["faction"] = {
        ["noSpace"] = true,
        ["values"] = {
            ["Alliance"] = {"Alliance"},
            ["Horde"] = {"Horde"},
        }
    }
}

-- Find typeKey, valueKey, noSpace from SearchTokenTypeTable
function Search:FindSearchValueDataForToken(token, isExactScope, optionalExplicitKey)
    assert(token);
    assert(token ~= "");

    local function FindTokenTypeKey(table, token, requireExact) 
        for key,typeTable in pairs(table) do
            if(typeTable ~= nil) then
                for _,value in ipairs(typeTable["values"]) do
                    assert(value);
                    local isMatch = requireExact and (token == value) or (value:containing(token));
                    if(isMatch) then
                        return key, typeTable["noSpace"];
                    end
                end
            end
        end
    end

    -- Look through the values for the explicit key
    if(optionalExplicitKey ~= nil) then
        local valueTable = SearchTokenTypeTable[optionalExplicitKey];
        if(valueTable) then
            local typeKey, noSpace = FindTokenTypeKey(valueTable, token, isExactScope);
            if(typeKey) then
                return optionalExplicitKey, typeKey, noSpace;
            end
        end
    else -- Look through all keys
        local typeKey = nil;
        for key,typeTables in pairs(SearchTokenTypeTable) do
            typeKey, noSpace = FindTokenTypeKey(typeTables, token, isExactScope);
            if(typeKey) then
                return key, typeKey, noSpace
            end
        end
    end
end

---------------------------------
-- Search API
---------------------------------

-- The current search data
Search.current = {
    ["raw"] = "", -- The raw search string
    ["display"] = "", -- Search string sanitized and colored(?) for display
    ["data"] = nil, -- Search data as a table for efficient comparisons
}

function Search:Get(key)
    if key then
        return key and Search.current[key];
    else
        return Search.current;
    end
end

function Search:IsEmpty()
    return Search.current["raw"] == "" and Search.current["display"] == "" and Search.current[data] == nil;
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

    -- Trigger filter refresh
end

function Search:DoesMatchPassSearch(match)
    if(Search:IsEmpty()) then
        return true;
    end


end

---------------------------------
-- Processing Pipeline
---------------------------------

local function GetScopeEndIndex(input, startIndex, endSymbol)
    assert(input ~= nil);
    assert(endSymbol ~= nil);

    for index = startIndex + 1, #input do
        local char = index:sub(index, index);
        if(char == endSymbol) then
            return index;
        elseif(char == ",") then
            return nil;
        end
    end
end

function Search:ProcessInput(input)
    if(input == nil or input == "") then
        Search:Reset();
        return;
    end

    local playerSegments = { }

    -- Data in the making
    local currentData = {
        ["segment"] = {}, 
        ["token"] = {}, 
        ["word"] = ""
    };

    local function CommitToken()
        tinsert(currentData["segment"], currentData["token"]);
        currentData["token"] = {}

        -- Prepare next word for token check
        if(currentData["word"] ~= "") then
            tinsert(currentData["token"], currentData["word"]);
            currentData["word"] = "";

            -- Check new token immediately
                -- TODO: Add token check function.
            if(not currentData["token"]) then
                -- Commit immediately, no chance of being a multi-word token
                CommitToken();
            end
        end
    end
    
    -- TODO: Rework for desired parsing logic
    local index = 1;
    while(index <= #input) do
        -- Loop through characters until segment ends
        while(index <= #input) do
            local char = input:sub(index,index);
            index = index + 1; -- Prepare for next iteration

            -- If segment ended, go to next
            if(char == ',') then
                isExactScope = false; -- End exact scope in same segment for now. (TODO: Consider what's preferrable)
                break;
            end

            -- Toggle exact scope
            if(char == '"') then
                isExactScope = not isExactScope;
            end

            nextWord = nextWord .. char;
        end
        tinsert(playerSegments, segment);
    end

end