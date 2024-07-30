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

local currentActions = {}
local locked = nil;

local function ResetQuickSearch()
    currentActions = {};
    locked = nil;
end

--AddSetting("quickSearchShortcut_LMB", "Team");
--AddSetting("quickSearchShortcut_RMB", "Enemy");
--AddSetting("quickSearchShortcut_Nomod", "Name");
--AddSetting("quickSearchShortcut_Shift", "New Segment");
--AddSetting("quickSearchShortcut_Ctrl", "Spec");
--AddSetting("quickSearchShortcut_Alt", "Inverse");

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

local function GetQuickSearchActions(btn)
    local actions = {};
    
    if(btn == "LeftButton") then
        AddSettingAction(actions, "quickSearchShortcut_LMB");
    elseif(btn == "RightButton") then
        AddSettingAction(actions, "quickSearchShortcut_RMB");
    end

    if(IsShiftKeyDown()) then
        AddSettingAction(actions, "quickSearchShortcut_Shift");
    end

    if(IsControlKeyDown()) then
        AddSettingAction(actions, "quickSearchShortcut_Ctrl");
    end
    
    if(IsAltKeyDown()) then
        AddSettingAction(actions, "quickSearchShortcut_Alt");
    end

    return actions;
end

local function GetCurrentSegments()
    if(HasAction("New Search")) then
        return Search:GetEmptySegment();
    end
    
    assert(Search.current and Search.current["data"]);
    return Search.current["data"].segments or Search:GetEmptySegment();
end 

function Search:QuickSearch(mouseButton, player, team)
    if(locked) then
        return;
    end
    locked = true;

    team = (team == "team") and "Team" or "Enemy";
    currentActions = GetQuickSearchActions(mouseButton);
    tokens = {}

    -- Current Search Data
    assert(Search.current and Search.current["data"]);
    local segments = not HasAction("New Search") and Search.current["data"].segments or Search:GetEmptySegment();
    if(#segments > 0 and #segments[1].tokens > 0 and HasAction("New Segment")) then
        tinsert(segments, { tokens = {} });
    end
    local currentIndex = #segments;


    if(HasAction("Inverse")) then
        tinsert(tokens, "not");
    end

    if(HasAction("Friend")) then
        tinsert(tokens, "Team");
    elseif(HasAction("Enemy")) then
        tinsert(tokens, "Enemy");
    elseif(HasAction("Clicked Team")) then
        tinsert(tokens, team);
    end

    if(HasAction("Name")) then
        tinsert(tokens, GetPlayerName(player));
    else
        if(HasAction("Faction")) then
            local faction = Constants:GetFactionByRace(player["race"]) or "";
            tinsert(tokens, faction);
        end

        if(HasAction("Race")) then
            local race = Search:GetShortQuickSearch("race", player["race"]);
            tinsert(tokens, race);
        end
        
        if(HasAction("Spec")) then
            local token = Search:GetShortQuickSearchSpec(player["class"], player["spec"]);
            tinsert(tokens, token);
        end
    end

    Search:CommitQuickSearch(tokens);
end

function Search:CommitQuickSearch(tokens)



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