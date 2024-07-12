local _, ArenaAnalytics = ... -- Addon Namespace
local Search = ArenaAnalytics.Search;

-- Local module aliases
local Options = ArenaAnalytics.Options;
local Constants = ArenaAnalytics.Constants;

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

function Search:QuickSearch(mouseButton, player, team)
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

    if(not IsShiftKeyDown() and not IsControlKeyDown()) then
        name = player["name"] or "";
        if(name:find('-')) then
            -- TODO: Convert to options
            if(Options:Get("quickSearchExcludeAnyRealm")) then
                name = name:match("(.*)-") or name or "";
            elseif(Options:Get("quickSearchExcludeMyRealm")) then
                local _, realm = UnitFullName("player");
                if(realm and name:find(realm)) then
                    name = name:match("(.*)-") or name or "";
                end
            end
        end

        if(name == "") then
            return;
        end

        -- Add name only
        tinsert(tokens, name);
    else
        if(IsControlKeyDown() and player["race"] ~= nil) then
            -- Add race if available
            local race =  player["race"];
            local shortName = Search:GetShortQuickSearch("race", race);
            tinsert(tokens, "r:"..(shortName or race));
        end
        
        if(IsShiftKeyDown() and player["class"] ~= nil) then
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

    Search:CommitQuickSearch(prefix, tokens, false);
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
    
    local previousSearch = IsAltKeyDown() and Search:SanitizeInput(Search.current["display"] or "") or "";
    
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
        currentSegment = prefix .. currentSegment;
    end
    
    Search:CommitSearch(previousSegments .. currentSegment);
end