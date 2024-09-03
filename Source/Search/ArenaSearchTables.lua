local _, ArenaAnalytics = ... -- Addon Namespace
local Search = ArenaAnalytics.Search;

-- Local module aliases
local Options = ArenaAnalytics.Options;
local Constants = ArenaAnalytics.Constants;
local Helpers = ArenaAnalytics.Helpers;

-------------------------------------------------------------------------
-- Search Lookup Tables

local function CalculateMatchScore(searchInput, matchedValue, startIndex)
    local maxPartialSearchDiff = 5;

    local matchedCountScore = (#searchInput / #matchedValue);
    local differenceScore = 1 - ((#matchedValue - #searchInput) / maxPartialSearchDiff)
    local startIndexScore = 1 - ((startIndex * startIndex) / (#matchedValue * #matchedValue));

    -- Return weighted score
    return (matchedCountScore * 0.5) + (differenceScore * 0.3) + (startIndexScore * 0.2);
end

---------------------------------
-- Prefix Data
---------------------------------

-- Assume short form as first alias index!
local PrefixTable = {
    ["name"] = { NoSpaces = true, Aliases = {"n", "name"} },
    ["class"] = { NoSpaces = false, Aliases = {"c", "class"} },
    ["spec"] = { NoSpaces = false, Aliases = {"s", "spec"} },
    ["subspec"] = { NoSpaces = false, Aliases = {"ss", "subspec"} },
    ["role"] = {NoSpaces = true, Aliases = {"role" }},
    ["race"] = { NoSpaces = false, Aliases = {"r", "race"} },
    ["faction"] = { NoSpaces = true, Aliases = {"f", "faction"} },
    ["alts"] = { NoSpaces = true, Aliases = {"a", "alts"} },
    ["team"] = { NoSpaces = true, Aliases = {"t", "team"}}
}

-- Find the prefix key from the given token
function Search:GetTokenPrefixKey(text)
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

function Search:GetShortPrefix(prefix)
    assert(prefix);
    for key,data in pairs(PrefixTable) do
        assert(data.Aliases and #data.Aliases > 0);
        for _,alias in ipairs(data.Aliases) do
            if(prefix == alias) then
                return data.Aliases[1];
            end
        end
    end
    return prefix;
end

---------------------------------
-- Search Type Data tables
---------------------------------

SearchTokenTypeTable = {
    ["class"] = {
        noSpace = false,
        values = {
            [0] = {"druid"},
            [10] = {"paladin", "pala"},
            [20] = {"shaman", "sham"},
            [30] = {"death knight", "deathknight", "dk"},
            [40] = {"hunter", "hunt", "huntard"},
            [50] = {"mage"},
            [60] = {"rogue", "rog"},
            [70] = {"warlock", "lock", "wlock"},
            [80] = {"warrior"},
            [90] = {"priest"},
            [100] = {"monk"},
            [110] = {"demon hunter", "demonhunter", "dh"},
            [120] = {"evoker"},
        }
    },
    ["spec"] = {
        noSpace = false,
        values = {
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
        noSpace = false,
        values = {
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
        noSpace = true,
        values = {
            [1] = {"alliance"},
            [2] = {"horde"},
        }
    },
    ["role"] = {
        noSpace = true,
        values = { -- Bitmap indexes
            [1] = { "tank" },
            [2] = { "damage dealer", "damage", "dps" },
            [3] = { "healer"},
            [4] = { "caster" },
            [5] = { "ranged" },
            [6] = { "melee" },
        },
    },
    ["team"] = {
        requireExact = true,
        noSpace = true,
        values = {
            ["team"] = {"friend", "team", "ally", "help", "partner"},
            ["enemy"] = {"enemy", "foe", "harm"},
        }
    },
    ["logical"] = {
        requireExact = true,
        values = {
            ["not"] = { "not", "no", "inverse" },
            ["self"] = { "self", "me" }
        }
    }
}

-- Find typeKey, valueKey, noSpace from SearchTokenTypeTable
function Search:FindSearchValueDataForToken(token)
    assert(token);

    if(token.value == nil or #token.value < 2) then
        return;
    end

    local lowerCaseValue = Helpers:ToSafeLower(token.value);
    
    -- Cached info about the best match
    local bestMatch = nil;
    local function TryUpdateBestMatch(matchedValue, valueKey, typeKey, noSpace, startIndex)
        local score = CalculateMatchScore(token.value, matchedValue, startIndex);
        if(not bestMatch or score > bestMatch.score) then
            bestMatch = {
                ["score"] = score,
                
                ["typeKey"] = typeKey,
                ["valueKey"] = valueKey,
                ["noSpace"] = noSpace,
            }                                
        end
    end

    local function FindTokenValueKey(valueTable, searchType)
        assert(valueTable and valueTable.values);

        for valueKey, values in pairs(valueTable.values) do
            for _, value in ipairs(values) do
                assert(value);
                if(token.value == value) then
                    return valueKey, true, value;
                elseif(not token.exact and not valueTable.requireExact) then
                    local foundStartIndex = value:find(token.value);
                    if(foundStartIndex ~= nil) then
                        TryUpdateBestMatch(value, valueKey, searchType, valueTable.noSpace, foundStartIndex);
                    end
                end
            end
        end
    end

    -- Look through the values for the explicit key
    if token.explicitType then
        local valueTable = SearchTokenTypeTable[token.explicitType];
        if valueTable then
            local valueKey, isExactMatch = FindTokenValueKey(valueTable, token.explicitType)
            if isExactMatch then
                return token.explicitType, valueKey, valueTable.noSpace;
            end
        end
    else -- Look through all keys
        for typeKey, valueTable in pairs(SearchTokenTypeTable) do
            local valueKey, isExactMatch = FindTokenValueKey(valueTable, typeKey)
            if isExactMatch then
                return typeKey, valueKey, valueTable.noSpace;
            end
        end
    end

    -- Evaluate best match so far, if any.
    if(bestMatch) then
        return bestMatch.typeKey, bestMatch.valueKey, bestMatch.noSpace;
    end
end
