local _, ArenaAnalytics = ... -- Addon Namespace
local Search = ArenaAnalytics.Search;

-- Local module aliases
local Options = ArenaAnalytics.Options;
local Constants = ArenaAnalytics.Constants;
local Helpers = ArenaAnalytics.Helpers;
local ArenaMatch = ArenaAnalytics.ArenaMatch;

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

local function GetPlayerName(playerInfo)
    name = playerInfo.fullName or "";
    if(name:find('-')) then
        local includeRealmSetting = Options:Get("quickSearchIncludeRealm");
        local includeRealm = true;
        
        local _, realm = UnitFullName("player");
        local isMyRealm = realm and name:find(realm);

        if(includeRealmSetting == "All") then
            includeRealm = true;
        elseif(includeRealmSetting == "None") then
            includeRealm = false;
        elseif(includeRealmSetting == "Other Realms") then
            includeRealm = not isMyRealm;
        elseif(includeRealmSetting == "My Realm") then
            includeRealm = isMyRealm;
        end

        if(not includeRealm) then
            name = name:match("(.*)-") or name;
        end
    end
    
    return name;
end

local function AddSettingAction(actions, setting)
    assert(setting and actions);

    local action = Options:Get(setting);
    if(action and action ~= "None") then
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

local function AddValueByType(tokens, playerInfo, explicitType)
    assert(playerInfo);
    if(not explicitType) then
        return;
    end

    local newToken = nil;
    
    if(explicitType == "name") then
        newToken = Search:CreateToken(GetPlayerName(playerInfo));
    elseif(explicitType == "race") then
        local race = Search:GetShortQuickSearch(explicitType, playerInfo.race);
        newToken = Search:CreateToken(race);
    elseif(explicitType == "spec" and playerInfo.spec) then
        local value = Search:GetShortQuickSearchSpec(playerInfo.class, playerInfo.spec);
        newToken = Search:CreateToken(value);
    elseif(explicitType == "class") then
        local value = Search:GetShortQuickSearchSpec(playerInfo.class, nil);
        newToken = Search:CreateToken(value);
    elseif(explicitType == "faction") then
        local value = Search:GetShortQuickSearch(explicitType, playerInfo.faction);
        newToken = Search:CreateToken(value);
    end
    
    if(newToken) then
        tinsert(tokens, newToken);
    end
end

local function GetQuickSearchTokens(playerInfo, team, btn)
    assert(playerInfo);
    local tokens = {};
    local hasValue = false;

    -- Inverse
    local shortcut = Options:Get("quickSearchAction_Inverse");
    if(CheckShortcut(shortcut, btn)) then
        local newToken = Search:CreateToken("not");
        if(newToken) then
            tinsert(tokens, newToken);
        end
    end

    -- Team
    local newSimpleTeamToken = nil;
    if(CheckShortcut(Options:Get("quickSearchAction_ClickedTeam"), btn)) then
        newSimpleTeamToken = Search:CreateToken(Helpers:ToSafeLower(team));
    elseif(CheckShortcut(Options:Get("quickSearchAction_Team"), btn)) then
        newSimpleTeamToken = Search:CreateToken("team");
    elseif(CheckShortcut(Options:Get("quickSearchAction_Enemy"), btn)) then
        newSimpleTeamToken = Search:CreateToken("enemy");
    end

    if(newSimpleTeamToken) then
        tinsert(tokens, newSimpleTeamToken);
    end

    -- Name
    shortcut = Options:Get("quickSearchAction_Name");
    if(CheckShortcut(shortcut, btn)) then
        AddValueByType(tokens, playerInfo, "name");
        hasValue = true;
    end

    -- Spec
    shortcut = Options:Get("quickSearchAction_Spec");
    if(CheckShortcut(shortcut, btn)) then
        AddValueByType(tokens, playerInfo, "spec");
        hasValue = true;
    end

    -- Race
    shortcut = Options:Get("quickSearchAction_Race");
    if(CheckShortcut(shortcut, btn)) then
        AddValueByType(tokens, playerInfo, "race");
        hasValue = true;
    end
    
    -- Faction
    shortcut = Options:Get("quickSearchAction_Faction");
    if(CheckShortcut(shortcut, btn)) then
        AddValueByType(tokens, playerInfo, "faction");
        hasValue = true;
    end

    if(not hasValue) then
        local explicitType = Options:Get("quickSearchDefaultValue");
        AddValueByType(tokens, playerInfo, Helpers:ToSafeLower(explicitType));
    end

    return tokens;
end

local function DoesTokenMatchName(existingToken, newName)
    assert(existingToken and newName);
    if(existingToken.explicitType ~= "name") then
        return false;
    end

    local existingName = Helpers:ToSafeLower(existingToken.value);

    if(existingToken.value == newName) then
        return true, true;
    end

    if(not existingToken.exact) then
        local isPartialMatch = newName:find(existingName) ~= nil;
        return isPartialMatch, false;
    end

    return false;
end

local function FindExistingNameMatch(segments, newName)
    assert(segments);

    if(not newName or newName == "" or type(newName) ~= "string") then
        return nil, nil;
    end

    for i,segment in ipairs(segments) do
        for j,currentToken in ipairs(segment.tokens) do
            -- Compare name with current 
            local isMatch, isExact = DoesTokenMatchName(currentToken, newName);
            if(isMatch) then
                return i, j, isExact;
            end
        end
    end
end

local function RemoveSeparatorFromTokens(tokens)
    assert(tokens);

    for i=#tokens, 1, -1 do
        local token = tokens[i];
        
        if(token and token.isSeparator) then
            table.remove(tokens, i);
        end
    end
end

local function TokensContainExact(existingTokens, token)
    assert(existingTokens and token);

    for index,existingToken in ipairs(existingTokens) do
        if(existingToken.explicitType == token.explicitType and existingToken.value == token.value) then
            return true;
        end
    end
    
    return false;
end

local function DoesAllTokensMatchExact(segment, tokens, skipName)
    if(not segment or not tokens) then
        return false;
    end

    for _,token in ipairs(tokens) do
        if(not skipName or token.explicitType ~= "name") then
            if(not TokensContainExact(segment.tokens, token)) then
                return false;
            end    
        end
    end

    return true;
end

local locked = nil;
function Search:QuickSearch(playerFrame, mouseButton)
    if(not Options:Get("quickSearchEnabled")) then
        ArenaAnalytics:Log("QuickSearch: Disabled");
        return;
    end

    if(not playerFrame or not playerFrame.playerInfo) then
        ArenaAnalytics:Log("QuickSearch: invalid player frame");
        return;
    end

    if(locked) then
        return;
    end
    locked = true;

    team = isEnemyTeam and "enemy" or "team";
    local appendRule = GetAppendRule(mouseButton);
    local tokens = GetQuickSearchTokens(playerFrame.playerInfo, team, mouseButton);

    if(not tokens or #tokens == 0) then
        ArenaAnalytics:Log("QuickSearch: No tokens.");
        return;
    end

    -- Current Search Data
    local currentSegments = Search:GetCurrentSegments();

    if(appendRule == "New Search") then
        if(#currentSegments == 1 and DoesAllTokensMatchExact(currentSegments[1], tokens)) then
            Search:CommitEmptySearch();
            locked = false;
            return;
        end

        currentSegments = {};
    end

    local newSegment = {}
    local segmentIndex = 0;

    -- Check for name match
    local nameMatch = nil;
    local newName = nil;
    for _,token in ipairs(tokens) do
        if(token.explicitType == "name") then
            newName = token.value;
        end
    end

    if(newName) then
        local matchedSegmentIndex, matchedTokenIndex, isExactNameMatch = FindExistingNameMatch(currentSegments, newName);
        if(matchedSegmentIndex and matchedTokenIndex) then
            if(isExactNameMatch) then
                -- If all tokens match, and this was an existing named match, then remove the entire segment
                if(DoesAllTokensMatchExact(currentSegments[matchedSegmentIndex], tokens, true)) then
                    -- Remove separator from new last segment, if we are about to remove last segment
                    if(matchedSegmentIndex > 1 and matchedSegmentIndex == #currentSegments) then
                        local previousSegment = currentSegments[matchedSegmentIndex - 1];
                        if(previousSegment) then
                            RemoveSeparatorFromTokens(previousSegment.tokens);
                        end
                    end

                    table.remove(currentSegments, matchedSegmentIndex);

                    Search:CommitQuickSearch(currentSegments);
                    return;
                end

                nameMatch = "exact";
            else
                nameMatch = "partial";
            end
        end

        segmentIndex = matchedSegmentIndex;
    end

    if(not nameMatch) then
        if(#currentSegments > 0 and appendRule == "New Segment") then
            local newSeparatorToken = Search:CreateSymbolToken(', ', true);
            tinsert(currentSegments[#currentSegments].tokens, newSeparatorToken);
        end

        if(#currentSegments == 0 or appendRule ~= "Same Segment") then
            tinsert(currentSegments, Search:GetEmptySegment());
        end

        segmentIndex = #currentSegments;
    end

    Search:CommitQuickSearch(currentSegments, segmentIndex, tokens, appendRule, nameMatch);
end

function Search:CommitQuickSearch(currentSegments, segmentIndex, newTokens, appendRule, nameMatch)
    if(segmentIndex and newTokens) then
        -- For each new token, add, remove or replace based on type and value match
        for i,token in ipairs(newTokens) do
            if(token.explicitType and token.raw) then
                assert(token.explicitType and token.explicitType ~= "");
                assert(currentSegments[segmentIndex]);

                local isUniqueToken = true;

                local existingTokens = currentSegments[segmentIndex].tokens;
                for tokenIndex = #existingTokens, 1, -1 do
                    local existingToken = existingTokens[tokenIndex];

                    if(existingToken.explicitType == token.explicitType) then
                        isUniqueToken = false;
                        
                        -- Different values, replace with the new token
                        if(existingToken.value ~= token.value) then
                            existingTokens[tokenIndex] = token;
                        elseif(nameMatch ~= "partial" and token.explicitType ~= "name" and not (nameMatch or appendRule == "Same Segment")) then
                            table.remove(existingTokens, tokenIndex);
                        end
                        break;
                    end
                end

                -- If the token type is unique
                if(isUniqueToken) then
                    if(#existingTokens > 0) then
                        local newSpaceToken = Search:CreateSymbolToken(' ');
                        tinsert(existingTokens, newSpaceToken);
                    end

                    -- Add the new token
                    tinsert(existingTokens, token);
                end
            end
        end
    end

    Search:SetCurrentData(currentSegments);
    Search:CommitSearch();
    
    locked = false;
end