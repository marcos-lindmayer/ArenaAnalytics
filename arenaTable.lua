--[[ 
CODE NOT YET COMMENTED
(sorry)
]]

local _, ArenaAnalytics = ...;

local currentFilters = {
    ["map"] = "All", 
    ["bracket"] = "All", 
    ["comps"] = "All",
    ["comps2v2"] = "All", 
    ["comps3v3"] = "All", 
    ["comps5v5"] = "All",
    ["enemycomps2v2"] = "All",
    ["enemycomps3v3"] = "All",
    ["enemycomps5v5"] = "All"
};

local isCompFilterOn;
local filteredDB = nil;
local dropdownCounter = 1;
local currentSeasonStartInt = 1673916461;
local filterCompsOpts = {
    ["2v2"] = "",
    ["3v3"] = "",
    ["5v5"] = ""
}
local filterEnemyCompsOpts = {
    ["2v2"] = "",
    ["3v3"] = "",
    ["5v5"] = ""
}
local totalArenas = #ArenaAnalyticsDB["2v2"] + #ArenaAnalyticsDB["3v3"] + #ArenaAnalyticsDB["5v5"] 

local selectedGames = {}

HybridScrollMixin = {};
ArenaAnalytics.AAtable = HybridScrollMixin;
local AAtable = ArenaAnalytics.AAtable


-- Toggles addOn view/hide
function AAtable:Toggle()
    if not ArenaAnalyticsScrollFrame:IsShown() then  
        AAtable:ClearSelectedMatches() 
        ArenaAnalyticsScrollFrame:Show();
    else
        ArenaAnalyticsScrollFrame:Hide();
    end
end

-- Returns button based on params
function AAtable:CreateButton(point, relativeFrame, relativePoint, xOffset, yOffset, text)
    local btn = CreateFrame("Button", nil, relativeFrame, "UIServiceButtonTemplate");
    btn:SetPoint(point, relativeFrame, relativePoint, xOffset, yOffset);
    btn:SetSize(120, 25);
    btn:SetText(text);
    btn.money:Hide();
    btn:SetNormalFontObject("GameFontHighlight");
    btn:SetHighlightFontObject("GameFontHighlight");
    return btn;
end

local function doesGameMatchSettings(arenaGame)
    local seasonCondition = false
    if ((ArenaAnalyticsSettings["seasonIsChecked"] == false and arenaGame["dateInt"] > currentSeasonStartInt) or ArenaAnalyticsSettings["seasonIsChecked"]) then
        seasonCondition = true
    end
    local skirmishCondition = false
    if ((ArenaAnalyticsSettings["skirmishIsChecked"] == false and arenaGame["isRanked"]) or ArenaAnalyticsSettings["skirmishIsChecked"]) then
        skirmishCondition = true
    end
    return seasonCondition and skirmishCondition
end

-- Return specific comp's winrate
-- comp is a string of space-separated classes
local function getCompWinrate(comp, isEnemyComp)
    local compType = isEnemyComp and "enemyComp" or "comp"
    local _, bracket = string.gsub(comp, "-", "-")
    local bracketSize = bracket + 1;
    bracket = bracketSize .. "v" .. bracketSize;
    local arenasWithComp = {}
    for i = 1, #ArenaAnalyticsDB[bracket] do
        if (#ArenaAnalyticsDB[bracket][i][compType] == bracketSize and doesGameMatchSettings(ArenaAnalyticsDB[bracket][i])) then
            local currentComp = table.concat(ArenaAnalyticsDB[bracket][i][compType], "-")
            if (comp == currentComp) then
                table.insert(arenasWithComp, ArenaAnalyticsDB[bracket][i])
            end
        end
    end

    local arenasWon = 0
    for c = 1,  #arenasWithComp do
        if (arenasWithComp[c]["won"]) then
            arenasWon = arenasWon + 1
        end
    end
    local winrate = math.floor(arenasWon * 100 / #arenasWithComp)
    if (#tostring(winrate) < 2) then
        winrate = winrate .. "%"
    elseif (#tostring(winrate) < 3) then
        winrate = winrate .. "%"
    else
        winrate = winrate .. "%"
    end
    
    return winrate
end

-- Return specific comp's total games
-- comp is a string of space-separated classes
local function getCompTotalGames(comp, isEnemyComp)
    local _, bracket = string.gsub(comp, "-", "-")
    local bracketSize = bracket + 1;
    bracket = bracketSize .. "v" .. bracketSize;
    local compType = isEnemyComp and "enemyComp" or "comp"
    local arenasWithComp = {}
    for i = 1, #ArenaAnalyticsDB[bracket] do
        if (#ArenaAnalyticsDB[bracket][i][compType] == bracketSize and doesGameMatchSettings(ArenaAnalyticsDB[bracket][i])) then
            local currentComp = table.concat(ArenaAnalyticsDB[bracket][i][compType], "-")
            if (comp == currentComp) then
                table.insert(arenasWithComp, ArenaAnalyticsDB[bracket][i])
            end
        end
    end
    return #arenasWithComp
end
-- Hides spec's icon on bottom-right class' icon
local function hideSpecIcons()
    for specIconNumber = 1, #ArenaAnalyticsScrollFrame.specFrames do
        if (not ArenaAnalyticsScrollFrame.specFrames[specIconNumber][2]:GetAttribute("clicked")) then
            ArenaAnalyticsScrollFrame.specFrames[specIconNumber][1]:Hide()
        else
            ArenaAnalyticsScrollFrame.specFrames[specIconNumber][1]:Show()
        end
    end
end

-- Clears current selection of matches
function AAtable:ClearSelectedMatches()
    local buttons = HybridScrollFrame_GetButtons(ArenaAnalyticsScrollFrame.ListScrollFrame)
    for i = 1, #buttons do
        buttons[i]:SetAttribute("clicked", false)
        buttons[i].Tooltip:Hide();
    end
    hideSpecIcons()
    selectedGames = {}
    AAtable:UpdateSelected()
end

-- Changes the current filter upon selecting one from its dropdown
local function changeFilter(args)
    AAtable:ClearSelectedMatches()
    local selectedFilter = args:GetAttribute("value")
    local currentFilter = args:GetAttribute("dropdownTable")
    local filterName = currentFilter.filterName
    currentFilter.selected:SetText(selectedFilter)

    if (args:GetAttribute("tooltip") ~= nil) then
        local indexOfSeparator, _ = string.find(selectedFilter, "-")
        local compIcons = selectedFilter:sub(1, indexOfSeparator - 1);
        currentFilter.selected:SetText(compIcons)
        selectedFilter = args:GetAttribute("tooltip")
    end

    currentFilters[string.lower(filterName)] = selectedFilter;
    if not currentFilter.dropdownList:IsShown() then   
        currentFilter.dropdownList:Show();
    else
        currentFilter.dropdownList:Hide();
    end

    if (selectedFilter == "2v2") then
        ArenaAnalyticsScrollFrame.filterComps["2v2"].selected:SetText("All")
        currentFilters["comps3v3"] = "All"
        currentFilters["comps5v5"] = "All"
        ArenaAnalyticsScrollFrame.filterComps["2v2"].dropdownFrame:Show();
        ArenaAnalyticsScrollFrame.filterComps["3v3"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterComps["5v5"].dropdownFrame:Hide();

        ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"].selected:SetText("All");
        currentFilters["enemycomps3v3"] = "All"
        currentFilters["enemycomps5v5"] = "All"
        ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"].dropdownFrame:Show();
        ArenaAnalyticsScrollFrame.filterEnemyComps["3v3"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterEnemyComps["5v5"].dropdownFrame:Hide();
    elseif (selectedFilter == "3v3") then
        ArenaAnalyticsScrollFrame.filterComps["3v3"].selected:SetText("All");
        currentFilters["comps2v2"] = "All"
        currentFilters["comps5v5"] = "All"
        ArenaAnalyticsScrollFrame.filterComps["2v2"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterComps["3v3"].dropdownFrame:Show();
        ArenaAnalyticsScrollFrame.filterComps["5v5"].dropdownFrame:Hide();
        
        ArenaAnalyticsScrollFrame.filterEnemyComps["3v3"].selected:SetText("All");
        currentFilters["enemycomps2v2"] = "All"
        currentFilters["enemycomps5v5"] = "All"
        ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterEnemyComps["3v3"].dropdownFrame:Show();
        ArenaAnalyticsScrollFrame.filterEnemyComps["5v5"].dropdownFrame:Hide();
    elseif (selectedFilter == "5v5") then
        ArenaAnalyticsScrollFrame.filterComps["5v5"].selected:SetText("All");
        currentFilters["comps2v2"] = "All"
        currentFilters["comps3v3"] = "All"
        ArenaAnalyticsScrollFrame.filterComps["2v2"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterComps["3v3"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterComps["5v5"].dropdownFrame:Show();
        
        ArenaAnalyticsScrollFrame.filterEnemyComps["5v5"].selected:SetText("All");
        currentFilters["enemycomps2v2"] = "All"
        currentFilters["enemycomps3v3"] = "All"
        ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterEnemyComps["3v3"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterEnemyComps["5v5"].dropdownFrame:Show();
    end

    if (filterName == "Bracket" and selectedFilter ~= "All") then
        ArenaAnalyticsScrollFrame.filterComps["2v2"].selected:Enable();
        ArenaAnalyticsScrollFrame.filterComps["2v2"].selected:SetText("All");
        ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"].selected:Enable();
        ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"].selected:SetText("All");
    elseif (filterName == "Bracket") then
        ArenaAnalyticsScrollFrame.filterComps["2v2"].dropdownFrame:Show();
        ArenaAnalyticsScrollFrame.filterComps["2v2"].selected:Disable();
        ArenaAnalyticsScrollFrame.filterComps["3v3"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterComps["5v5"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterComps["2v2"].selected:SetText("Select bracket");
        ArenaAnalyticsScrollFrame.filterComps["2v2"].selected:SetDisabledFontObject("GameFontDisableSmall")
        ArenaAnalyticsScrollFrame.filterComps["3v3"].selected:SetText("All");
        ArenaAnalyticsScrollFrame.filterComps["5v5"].selected:SetText("All");
        currentFilters["comps2v2"] = "All";
        currentFilters["comps3v3"] = "All";
        currentFilters["comps5v5"] = "All";
        
        ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"].dropdownFrame:Show();
        ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"].selected:Disable();
        ArenaAnalyticsScrollFrame.filterEnemyComps["3v3"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterEnemyComps["5v5"].dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"].selected:SetText("Select bracket");
        ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"].selected:SetDisabledFontObject("GameFontDisableSmall")
        ArenaAnalyticsScrollFrame.filterEnemyComps["3v3"].selected:SetText("All");
        ArenaAnalyticsScrollFrame.filterEnemyComps["5v5"].selected:SetText("All");
        currentFilters["enemycomps2v2"] = "All";
        currentFilters["enemycomps3v3"] = "All";
        currentFilters["enemycomps5v5"] = "All";
    end
    
    if (currentFilters["bracket"] ~= "All" and currentFilters["comps" .. currentFilters["bracket"]] ~= "All") then 
        isCompFilterOn = true;
    else
        isCompFilterOn = false;
    end
    
    if (currentFilters["bracket"] ~= "All" and currentFilters["enemycomps" .. currentFilters["bracket"]] ~= "All") then 
        isEnemyCompFilterOn = true;
    else
        isEnemyCompFilterOn = false;
    end

    if (string.find(filterName, "enemy")) then
        AAtable:updateCompFilterByEnemyFilter(selectedFilter, filterName)
    elseif (string.find(filterName, "comp")) then
        AAtable:updateEnemyFilterByCompFilter(selectedFilter, filterName)
    end

    AAtable:RefreshLayout(true);
end


function AAtable:updateEnemyFilterByCompFilter(selectedFilter, filterName) 
    local bracket
    local filter
    if (selectedFilter == "All") then
        filter = nil
    else    
        filter = selectedFilter
    end
    print(filter)
    if (string.find(filterName, "2v2")) then
        bracket = "2v2"
    elseif (string.find(filterName, "3v3")) then
        bracket = "3v3"
    else
        bracket = "5v5"
    end

    local frameByBracketTable = {
        ["2v2"] = ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"],
        ["3v3"] = ArenaAnalyticsScrollFrame.filterEnemyComps["3v3"],
        ["5v5"] = ArenaAnalyticsScrollFrame.filterEnemyComps["5v5"],
    }
--asd
    
    frameByBracketTable[bracket].dropdownFrame:Hide();
    frameByBracketTable[bracket].dropdownFrame = nil;
    frameByBracketTable[bracket] = nil

    local newFilterEnemyCompsOpts = {
        ['name']='Filter' .. bracket .. '_EnemyComps',
        ['parent'] = ArenaAnalyticsScrollFrame,
        ['title']='Enemy Comp: Games | Comp | Winrate',
        ['hasIcon']= true,
        ['matches'] = AAtable:getEnemyPlayedComps(bracket, filter),
        ['defaultVal'] = ArenaAnalyticsScrollFrame.filterEnemyComps[bracket].selected:GetText()
    }
    ArenaAnalyticsScrollFrame.filterEnemyComps[bracket] = AAtable:createDropdown(newFilterEnemyCompsOpts)
    ArenaAnalyticsScrollFrame.filterEnemyComps[bracket].dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.filterComps["2v2"].dropdownFrame, "RIGHT", 15, 0);
    AAtable:RefreshLayout(true)
end

function AAtable:updateCompFilterByEnemyFilter(selectedFilter, filterName) 
    local bracket
    local filter
    if (selectedFilter == "All") then
        filter = nil
    else    
        filter = selectedFilter
    end
    print(filter)
    if (string.find(filterName, "2v2")) then
        bracket = "2v2"
    elseif (string.find(filterName, "3v3")) then
        bracket = "3v3"
    else
        bracket = "5v5"
    end

    local frameByBracketTable = {
        ["2v2"] = ArenaAnalyticsScrollFrame.filterComps["2v2"],
        ["3v3"] = ArenaAnalyticsScrollFrame.filterComps["3v3"],
        ["5v5"] = ArenaAnalyticsScrollFrame.filterComps["5v5"],
    }

    frameByBracketTable[bracket].dropdownFrame:Hide();
    frameByBracketTable[bracket].dropdownFrame = nil;
    frameByBracketTable[bracket] = nil

    local newFilterCompsOpts = {
        ['name']='Filter' .. bracket .. '_Comps',
        ['parent'] = ArenaAnalyticsScrollFrame,
        ['title']='Comp: Games | Comp | Winrate',
        ['hasIcon']= true,
        ['matches'] = AAtable:getPlayerPlayedComps(bracket, filter),
        ['defaultVal'] = ArenaAnalyticsScrollFrame.filterComps[bracket].selected:GetText()
    }
    ArenaAnalyticsScrollFrame.filterComps[bracket] = AAtable:createDropdown(newFilterCompsOpts)
    ArenaAnalyticsScrollFrame.filterComps[bracket].dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.filterMap.dropdownFrame, "RIGHT", 15, 0);
    AAtable:RefreshLayout(true)
end

-- Returns buttons for filter lists
local function createDropdownButton(info, dropdownTable, filter, dropdown_width)
    local button = CreateFrame("Button", filter .. "_" .. info.text, dropdownTable.dropdownList, "UIServiceButtonTemplate");
    button.money:Hide();
    button:SetPoint("LEFT", dropdownTable.dropdownList);
    button:SetSize(dropdown_width, 25);
    button:SetText(info.text);
    button:SetNormalFontObject("GameFontHighlight");
    button:SetHighlightFontObject("GameFontHighlight");
    if (info.tooltip ~= "") then
        button:SetAttribute("tooltip", info.tooltip);
        button:SetHeight(30)
    end
    button:SetAttribute("value", info.text);
    button:SetAttribute("dropdownTable", dropdownTable);
    button:SetScript("OnClick", function (args)changeFilter(args)end);
    return button;
end

-- Returns button string (icons) and tooltip for comp filter
local function setIconsOnCompFilter(itext, itooltip, isEnemyComp) 
    local inlineIcons = ""
    local infoText = itext;
    local infoTooltip = itooltip;
    if (string.find(infoText, "-") == nil) then
        return "","";
    end
    for arenaClassSpec in string.gmatch(infoText, "([^%-]+)") do
        local indexOfSeparator = string.find(arenaClassSpec, "|")
        local arenaClass = arenaClassSpec:sub(1, indexOfSeparator - 1)
        local arenaSpec = arenaClassSpec:sub(indexOfSeparator + 1)
        local iconPath = "Interface\\AddOns\\ArenaAnalytics\\icon\\" .. arenaClass .. "\\" .. arenaSpec;
        local singleClassSpecIcon = IconClass(iconPath, 0, 0, 0, 0, 0, 0, 25, 25);
        inlineIcons = inlineIcons .. singleClassSpecIcon:GetIconString() .. " ";
        infoTooltip = infoTooltip .. arenaClass .. "|" .. arenaSpec .."-"
    end
    infoTooltip = infoTooltip:sub(1, -2)
    infoText = getCompTotalGames(infoText, isEnemyComp) .. " " .. inlineIcons .. " - " .. getCompWinrate(infoText, isEnemyComp);
    return infoText, infoTooltip;
end

-- Returns a dropdown frame
-- Used for match filters
function AAtable:createDropdown(opts)
    local dropdownTable = {};
    local dropdown_name ='$parent_' .. opts['name'] .. '_dropdown';
    local menu_matches = opts['matches'] or {};
    local hasIcon = opts["hasIcon"];
    local title_text = opts['title'] or '';
    local dropdown_width = (title_text == "Comp: Games | Comp | Winrate" or title_text == "Enemy Comp: Games | Comp | Winrate") and 250 or 0;
    local default_val = opts['defaultVal'] or '';
    local change_func = opts['changeFunc'] or function (dropdown_val) end;

    local dropdown = CreateFrame("Frame", dropdown_name, opts['parent'])
    dropdownTable.dropdownFrame = dropdown;
    local dropdownList = CreateFrame("Frame", dropdown_name .. "_list", dropdownTable.dropdownFrame)
    dropdownTable.dropdownList = dropdownList
    dropdownTable.dropdownFrame:SetSize(500, 25);
    dropdownTable.dropdownList:SetPoint("TOPLEFT", dropdownTable.dropdownFrame, "BOTTOMLEFT")
    local dd_title = dropdownTable.dropdownFrame:CreateFontString(nil, 'OVERLAY')
    dd_title:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    dropdownTable.dd_title = dd_title;
    isEnemyComp, _ = string.find(opts['name'], "Enemy")
    if (hasIcon) then
        is2v2, _ = string.find(opts['name'], "2v2")
        if (is2v2) then
            dropdownTable.filterName = isEnemyComp and "enemycomps2v2" or "comps2v2"
        else
            is3v3, _ = string.find(opts['name'], "3v3")
            if (is3v3) then
                dropdownTable.filterName = isEnemyComp and "enemycomps3v3" or "comps3v3"
            else
                dropdownTable.filterName = isEnemyComp and "enemycomps5v5" or "comps5v5"
            end
        end
        
    else 
        dropdownTable.filterName = title_text;
    end
    
    dropdownTable.dd_title:SetPoint("TOPLEFT", 0, 13)

    dropdownTable.buttons = {}
    
    for _, match in pairs(menu_matches) do 
        dropdownTable.dd_title:SetText(match)
        local text_width = dropdownTable.dd_title:GetStringWidth() + 50
        if (text_width > dropdown_width and title_text ~= "Comp: Games | Comp | Winrate" and title_text ~= "Enemy Comp: Games | Comp | Winrate") then
            dropdown_width = text_width
        end
        local info = {}
        info.text = match;
        info.tooltip = "";
        if(hasIcon and info.text ~= "All") then
            info.text, info.tooltip = setIconsOnCompFilter(info.text, info.tooltip, isEnemyComp)
        end
        table.insert(dropdownTable.buttons, createDropdownButton(info, dropdownTable, title_text, dropdown_width))
    end
    -- Order Comp filter by winrate
    if(hasIcon) then
        table.sort(dropdownTable.buttons, function (k1,k2)
            if k1 and k1:GetText() == "All" then return true end;
            if (k2 and k2:GetText() == "All") or k1 == nil or k2 == nil then return false end;
            if (k1:GetText() and k2:GetText()) then
                local indexOfSeparatork1, _ = string.find(k1:GetText(), "-")
                local winratek1 = k1:GetText():sub(indexOfSeparatork1 + 2, string.len(k1:GetText()) - 1);
                local indexOfSeparatork2, _ = string.find(k2:GetText(), "-")
                local winratek2 = k2:GetText():sub(indexOfSeparatork2 + 2, string.len(k2:GetText()) - 1);
                return tonumber(winratek1) > tonumber(winratek2)
            end
            return true;
        end)
    end
    dropdownTable.dd_title:SetText(title_text)
    dropdownTable.dropdownList:SetSize(dropdown_width, (#dropdownTable.buttons * 25));
    dropdownTable.dropdownFrame:SetWidth(dropdown_width)
    
    for i = 1, #dropdownTable.buttons do
        dropdownTable.buttons[i]:SetPoint("TOPLEFT", 0, -(i - 1) * 25)
        dropdownTable.buttons[i]:SetWidth(dropdown_width)
    end
    
    local dropdownBg = dropdownTable.dropdownFrame:CreateTexture();
    dropdownBg:SetPoint("CENTER")
    dropdownBg:SetSize(dropdown_width, 25);
    dropdownBg:SetColorTexture(0, 0, 0, 0.5);
    
    local dropdownListBg = dropdownTable.dropdownList:CreateTexture();
    dropdownListBg:SetPoint("CENTER")
    dropdownListBg:SetSize(dropdown_width, (#dropdownTable.buttons * 25));
    dropdownListBg:SetColorTexture(0, 0, 0, 0.9);

    dropdownTable.selected = CreateFrame("Button", dropdown_name .. "_selected", dropdownTable.dropdownFrame, "UIServiceButtonTemplate")
    dropdownTable.selected.money:Hide();
    dropdownTable.selected:SetPoint("CENTER")
    dropdownTable.selected:SetSize(dropdown_width, 25)
    dropdownTable.selected:SetText(default_val);
    dropdownTable.selected:SetNormalFontObject("GameFontHighlight");
    dropdownTable.selected:SetHighlightFontObject("GameFontHighlight");
    dropdownTable.selected:SetAttribute("name", dropdownTable)
    dropdownTable.selected:SetScript("OnClick", function (args)
        local dropdownList = args:GetAttribute("name").dropdownList
        if not dropdownList:IsShown() then   
            dropdownList:Show();
        else
            dropdownList:Hide();
        end
    end)

    dropdownTable.dropdownList:Hide();

    return dropdownTable
end


-- Returns a CSV-formatted string using ArenaAnalyticsDB info
local function getCsvFromDB()
    local CSVString = "date,map,duration,won,isRanked,team1Name,team2Name,team3Name,team4Name,team5Name,rating,mmr," .. 
    "enemyTeam1Name,enemyTeam2Name,enemyTeam3Name,enemyTeam4Name,enemyTeam5Name,enemyRating, enemyMMR" .. "\n";
    -- Get all arenas ordered by date
    local allArenas = {}
    for arenaN2v2 = 1, #ArenaAnalyticsDB["2v2"] do
        table.insert(allArenas, ArenaAnalyticsDB["2v2"][arenaN2v2]);
    end
    for arenaN3v3 = 1, #ArenaAnalyticsDB["3v3"] do
        table.insert(allArenas, ArenaAnalyticsDB["3v3"][arenaN3v3]);
    end
    for arenaN5v5 = 1, #ArenaAnalyticsDB["5v5"] do
        table.insert(allArenas, ArenaAnalyticsDB["5v5"][arenaN5v5]);
    end
    table.sort(allArenas, function (k1,k2)
        return k1["dateInt"] > k2["dateInt"];
    end)

    for arenaN = 1, #allArenas do
        local arenaDateString = date("%d/%m/%y %H:%M:%S", match["dateInt"]);
        CSVString = CSVString 
        .. arenaDateString .. ","
        .. allArenas[arenaN]["map"] .. ","
        .. allArenas[arenaN]["duration"] .. ","
        .. (allArenas[arenaN]["won"] and "yes" or "no") .. ","
        .. (allArenas[arenaN]["isRanked"] and "yes" or "no") .. ","
        .. allArenas[arenaN]["team"][1]["name"] .. ","
        .. (allArenas[arenaN]["team"][2] and allArenas[arenaN]["team"][2]["name"] or "") .. ","
        .. (allArenas[arenaN]["team"][3] and allArenas[arenaN]["team"][3]["name"] or "") .. ","
        .. (allArenas[arenaN]["team"][4] and allArenas[arenaN]["team"][4]["name"] or "") .. ","
        .. (allArenas[arenaN]["team"][5] and allArenas[arenaN]["team"][5]["name"] or "") .. ","
        .. allArenas[arenaN]["rating"] .. ","
        .. allArenas[arenaN]["mmr"] .. ","
        .. (allArenas[arenaN]["enemyTeam"][1] and allArenas[arenaN]["enemyTeam"][1]["name"] or "") .. ","
        .. (allArenas[arenaN]["enemyTeam"][2] and allArenas[arenaN]["enemyTeam"][2]["name"] or "") .. ","
        .. (allArenas[arenaN]["enemyTeam"][3] and allArenas[arenaN]["enemyTeam"][3]["name"] or "") .. ","
        .. (allArenas[arenaN]["enemyTeam"][4] and allArenas[arenaN]["enemyTeam"][4]["name"] or "") .. ","
        .. (allArenas[arenaN]["enemyTeam"][5] and allArenas[arenaN]["enemyTeam"][5]["name"] or "") .. ","
        .. allArenas[arenaN]["enemyRating"] .. ","
        .. allArenas[arenaN]["enemyMmr"] .. ","
        CSVString = CSVString .. "\n";
    end
    return CSVString;
end

-- Toggle Export DB frame
local function exportDB() 
    if not ArenaAnalyticsScrollFrame.exportFrameContainer:IsShown() then   
        ArenaAnalyticsScrollFrame.exportFrameContainer:Show();
        ArenaAnalyticsScrollFrame.exportFrame:SetText(getCsvFromDB())
        ArenaAnalyticsScrollFrame.exportFrame:HighlightText()
    else
        ArenaAnalyticsScrollFrame.exportFrameContainer:Hide();
    end
end

-- Returns array with all unique played comps based on bracket
-- param received. Ignores incomplete comps. Removes outliers (settings param)
function AAtable:getPlayerPlayedComps(bracket, filterEnemyComp)
    local playedComps = {"All"};
    local arenaSize = tonumber(string.sub(bracket, 1, 1))
    if (bracket == nil) then
        return playedComps;
    else
        for arenaNumber = 1, #ArenaAnalyticsDB[bracket] do   
            if (#ArenaAnalyticsDB[bracket][arenaNumber]["comp"] == arenaSize and ArenaAnalyticsDB[bracket][arenaNumber]["dateInt"]) then
                if (doesGameMatchSettings(ArenaAnalyticsDB[bracket][arenaNumber])) then
                    table.sort(ArenaAnalyticsDB[bracket][arenaNumber]["comp"], function(a,b)
                        local playerClassSpec = UnitClass("player") .. "|" .. ArenaAnalytics.AAmatch:getPlayerSpec()
                        local prioA = a == playerClassSpec and 1 or 2
                        local prioB = b == playerClassSpec and 1 or 2
                        return prioA < prioB or (prioA == prioB and a < b)
                    end)
                    local compString = table.concat(ArenaAnalyticsDB[bracket][arenaNumber]["comp"], "-");
                    local lastLetter = compString:sub(-#"%|" + 1)
                    if (not tContains(playedComps, compString) and string.find(compString, "%|%-") == nil and lastLetter ~= "|") then
                        local result = {}
                        for i,v in ipairs(ArenaAnalyticsDB[bracket]) do
                            if (table.concat(v["comp"], "-") == compString and doesGameMatchSettings(v)) then
                                if (filterEnemyComp and table.concat(v["enemyComp"], "-") == filterEnemyComp) then
                                    table.insert(result, v)
                                elseif (filterEnemyComp == nil) then
                                    table.insert(result, v)
                                end
                            end
                        end
                        if (#result > tonumber(ArenaAnalyticsSettings["outliers"])) then
                            table.insert(playedComps, compString)
                        end
                    end
                end
            end
        end
    end
    return playedComps;
end
-- Returns array with all unique enemy played comps based on bracket
-- param received. Ignores incomplete comps. Removes outliers (settings param)
function AAtable:getEnemyPlayedComps(bracket, filterComp)
    local playedComps = {"All"};
    local arenaSize = tonumber(string.sub(bracket, 1, 1))
    if (bracket == nil) then
        return playedComps;
    else
        for arenaNumber = 1, #ArenaAnalyticsDB[bracket] do   
            if (#ArenaAnalyticsDB[bracket][arenaNumber]["enemyComp"] == arenaSize and ArenaAnalyticsDB[bracket][arenaNumber]["dateInt"]) then
                if (doesGameMatchSettings(ArenaAnalyticsDB[bracket][arenaNumber])) then
                    table.sort(ArenaAnalyticsDB[bracket][arenaNumber]["enemyComp"], function(a,b)
                        return (a < b)
                    end)
                    local compString = table.concat(ArenaAnalyticsDB[bracket][arenaNumber]["enemyComp"], "-");
                    local lastLetter = compString:sub(-#"%|" + 1)
                    if (not tContains(playedComps, compString) and string.find(compString, "%|%-") == nil and lastLetter ~= "|") then
                        local result = {}
                        for i,v in ipairs(ArenaAnalyticsDB[bracket]) do
                            if (table.concat(v["enemyComp"], "-") == compString and doesGameMatchSettings(v)) then
                                if (filterComp and table.concat(v["comp"], "-") == filterComp) then
                                    table.insert(result, v)
                                elseif (filterComp == nil) then
                                    table.insert(result, v)
                                end
                            end
                        end
                        if (#result > tonumber(ArenaAnalyticsSettings["outliers"])) then
                            table.insert(playedComps, compString)
                        end
                    end
                end
            end
        end
    end
    return playedComps;
end

-- Returns string frame
function ArenaAnalyticsCreateText(relativeFrame, anchor, refFrame, relPoint, xOff, yOff, text)
    local fontString = relativeFrame:CreateFontString(nil, "OVERLAY");
    fontString:SetFont("Fonts\\FRIZQT__.TTF", 12, "");
    fontString:SetPoint(anchor, refFrame, relPoint, xOff, yOff);
    fontString:SetText(text);
    return fontString
end

-- Creates the Export DB frame
local function createExportFrame()
    ArenaAnalyticsScrollFrame.exportFrameContainer = CreateFrame("Frame", nil, ArenaAnalyticsScrollFrame, "BasicFrameTemplateWithInset")
    ArenaAnalyticsScrollFrame.exportFrameContainer:SetFrameStrata("HIGH");
    ArenaAnalyticsScrollFrame.exportFrameContainer:SetPoint("CENTER", ArenaAnalyticsScrollFrame, "CENTER", 0, 0);
    ArenaAnalyticsScrollFrame.exportFrameContainer:SetSize(510, 150);
    ArenaAnalyticsScrollFrame.exportFrameScroll = CreateFrame("ScrollFrame", "exportFrameScroll", ArenaAnalyticsScrollFrame.exportFrameContainer, "UIPanelScrollFrameTemplate");
    ArenaAnalyticsScrollFrame.exportFrameScroll:SetPoint("CENTER", ArenaAnalyticsScrollFrame.exportFrameContainer, "CENTER");
    ArenaAnalyticsScrollFrame.exportFrameScroll:SetSize(500, 100);
    ArenaAnalyticsScrollFrame.exportFrameScroll.ScrollBar:Hide();
    ArenaAnalyticsScrollFrame.exportFrameScrollBg = ArenaAnalyticsScrollFrame.exportFrameContainer:CreateTexture()
    ArenaAnalyticsScrollFrame.exportFrameScrollBg:SetSize(500, 100);
    ArenaAnalyticsScrollFrame.exportFrameScrollBg:SetPoint("CENTER", ArenaAnalyticsScrollFrame.exportFrameScroll, "CENTER");
    ArenaAnalyticsScrollFrame.exportFrame = CreateFrame("EditBox", "exportFrameScroll", nil, "BackdropTemplate");
    ArenaAnalyticsScrollFrame.exportFrameScroll:SetScrollChild(ArenaAnalyticsScrollFrame.exportFrame);
    ArenaAnalyticsScrollFrame.exportFrame:SetWidth(InterfaceOptionsFramePanelContainer:GetWidth()-18);
    ArenaAnalyticsScrollFrame.exportFrame:SetMultiLine(true);
    ArenaAnalyticsScrollFrame.exportFrame:SetAutoFocus(true);
    ArenaAnalyticsScrollFrame.exportFrame:SetFont("Fonts\\FRIZQT__.TTF", 10, "");
    ArenaAnalyticsScrollFrame.exportFrame:SetJustifyH("LEFT");
    ArenaAnalyticsScrollFrame.exportFrame:SetJustifyV("CENTER");
    ArenaAnalyticsScrollFrame.exportFrame:HighlightText();
    ArenaAnalyticsScrollFrame.exportFrameContainer:Hide();
    
    -- Make frame draggable
    ArenaAnalyticsScrollFrame.exportFrameContainer:SetMovable(true)
    ArenaAnalyticsScrollFrame.exportFrameContainer:EnableMouse(true)
    ArenaAnalyticsScrollFrame.exportFrameContainer:RegisterForDrag("LeftButton")
    ArenaAnalyticsScrollFrame.exportFrameContainer:SetScript("OnDragStart", ArenaAnalyticsScrollFrame.exportFrameContainer.StartMoving)
    ArenaAnalyticsScrollFrame.exportFrameContainer:SetScript("OnDragStop", ArenaAnalyticsScrollFrame.exportFrameContainer.StopMovingOrSizing)
end

function AAtable:UpdateSelected()
    local newSelectedText = ""
    local selectedGamesCount = 0;
    local selectedWins = 0;
    for timestamp in pairs(selectedGames) do 
        selectedGamesCount = selectedGamesCount + 1 
        if (selectedGames[timestamp]:GetAttribute("won")) then
            selectedWins = selectedWins + 1;
        end 
    end
    if (selectedGamesCount > 0) then
        local winrate = math.floor(selectedWins * 100 / selectedGamesCount)
        newSelectedText = "Selected: " .. selectedGamesCount .. " arenas " .. selectedWins .. "/" .. (selectedGamesCount - selectedWins) .. " | " .. winrate .. "% Winrate"
        ArenaAnalyticsScrollFrame.clearSelected:Show();
    else
        newSelectedText = "Selected: (click matches to select)"
        ArenaAnalyticsScrollFrame.clearSelected:Hide();
    end
    ArenaAnalyticsScrollFrame.selectedWinrate:SetText(newSelectedText)
end

-- Creates addOn text, filters, table headers
function AAtable:OnLoad()
    ArenaAnalyticsScrollFrame.ListScrollFrame.update = function() AAtable:RefreshLayout(); end

    ArenaAnalyticsScrollFrame.filterComps = {}
    ArenaAnalyticsScrollFrame.filterEnemyComps = {}

    HybridScrollFrame_SetDoNotHideScrollBar(ArenaAnalyticsScrollFrame.ListScrollFrame, true);
    ArenaAnalyticsScrollFrame.Bg:SetTexture(nil)
    ArenaAnalyticsScrollFrame.Bg:SetColorTexture(0, 0, 0, 0.5)
    ArenaAnalyticsScrollFrame.title = ArenaAnalyticsScrollFrame:CreateFontString(nil, "OVERLAY");
    ArenaAnalyticsScrollFrame.title:SetPoint("CENTER", ArenaAnalyticsScrollFrame.TitleBg, "CENTER", 0, 0);
    ArenaAnalyticsScrollFrame.title:SetFont("Fonts\\FRIZQT__.TTF", 12, "");
    ArenaAnalyticsScrollFrame.title:SetText("Arena Analytics");

    ArenaAnalyticsScrollFrame.TitleBg:SetColorTexture(0,0,0,0.8)
    ArenaAnalyticsScrollFrame.teamBg = CreateFrame("Frame", nil, ArenaAnalyticsScrollFrame)
    ArenaAnalyticsScrollFrame.teamBg:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame, "TOPLEFT", 340, -90);
    ArenaAnalyticsScrollFrame.teamBg:SetFrameStrata("LOW");
    ArenaAnalyticsScrollFrame.teamBgT = ArenaAnalyticsScrollFrame.teamBg:CreateTexture()
    ArenaAnalyticsScrollFrame.teamBgT:SetColorTexture(0, 0, 0, 0.3)
    ArenaAnalyticsScrollFrame.teamBgT:SetSize(270, 413);
    ArenaAnalyticsScrollFrame.teamBg:SetSize(270, 413);
    ArenaAnalyticsScrollFrame.teamBgT:SetPoint("CENTER", ArenaAnalyticsScrollFrame.teamBg, "CENTER");

    ArenaAnalyticsScrollFrame.export = AAtable:CreateButton("TOPLEFT", ArenaAnalyticsScrollFrame, "TOPLEFT", 20, -35, "Export");
    ArenaAnalyticsScrollFrame.export:SetScript("OnClick", exportDB);

    -- Set export DB CSV frame layout
    createExportFrame();

    local arenaBracket_opts = {
        ['name']='Arena_Bracket',
        ['parent'] = ArenaAnalyticsScrollFrame,
        ['title']='Bracket',
        ['icon']= false,
        ['matches'] = {'All' ,'2v2', '3v3', '5v5' },
        ['defaultVal'] ='All', 
    }

    ArenaAnalyticsScrollFrame.arenaTypeMenu = AAtable:createDropdown(arenaBracket_opts)
    ArenaAnalyticsScrollFrame.arenaTypeMenu.dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.export, "RIGHT", 15, 0);

    local filterMap_opts = {
        ['name']='Filter_Map',
        ['parent'] = ArenaAnalyticsScrollFrame,
        ['title']='Map',
        ['icon']= false,
        ['matches'] = {'All' ,'Nagrand Arena' ,'Ruins of Lordaeron', 'Blade Edge Arena', 'Dalaran Arena'},
        ['defaultVal'] ='All'
    }
    
    ArenaAnalyticsScrollFrame.filterMap = AAtable:createDropdown(filterMap_opts)
    ArenaAnalyticsScrollFrame.filterMap.dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.arenaTypeMenu.dropdownFrame, "RIGHT", 15, 0);

    

    ArenaAnalyticsScrollFrame.settingsButton = CreateFrame("Button", nil, ArenaAnalyticsScrollFrame, "GameMenuButtonTemplate");
    ArenaAnalyticsScrollFrame.settingsButton:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame, "TOPRIGHT", -46, -1);
    ArenaAnalyticsScrollFrame.settingsButton:SetText([[|TInterface\Buttons\UI-OptionsButton:0|t]]);
    ArenaAnalyticsScrollFrame.settingsButton:SetNormalFontObject("GameFontHighlight");
    ArenaAnalyticsScrollFrame.settingsButton:SetHighlightFontObject("GameFontHighlight");
    ArenaAnalyticsScrollFrame.settingsButton:SetSize(24, 19);
    ArenaAnalyticsScrollFrame.settingsButton:SetScript("OnClick", function ()
        if not  ArenaAnalyticsScrollFrame.settingsFrame:IsShown() then  
            ArenaAnalyticsScrollFrame.settingsFrame:Show();
        else
            ArenaAnalyticsScrollFrame.settingsFrame:Hide();
        end
    end
    )

    -- Settings window
    ArenaAnalyticsSettingsFrame()    

    -- Table headers
    ArenaAnalyticsScrollFrame.dateTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame,"TOPLEFT", ArenaAnalyticsScrollFrame.export, "TOPLEFT", 5, -40, "Date");
    ArenaAnalyticsScrollFrame.mapTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.dateTitle, "TOPLEFT", 145, 0, "Map");
    ArenaAnalyticsScrollFrame.durationTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.mapTitle, "TOPLEFT", 60, 0, "Duration");
    ArenaAnalyticsScrollFrame.teamTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.durationTitle, "TOPLEFT", 120, 0, "Team");
    ArenaAnalyticsScrollFrame.ratingTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.teamTitle, "TOPLEFT", 130, 0, "Rating");
    ArenaAnalyticsScrollFrame.mmrTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.ratingTitle, "TOPLEFT", 85, 0, "MMR");
    ArenaAnalyticsScrollFrame.enemyTeamTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.mmrTitle, "TOPLEFT", 70, 0, "Enemy Team");
    ArenaAnalyticsScrollFrame.enemyRatingTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.enemyTeamTitle, "TOPLEFT", 140, 0, "Enemy MMR");
    ArenaAnalyticsScrollFrame.enemyMmrTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.enemyRatingTitle, "TOPLEFT", 125, 0, "Enemy Rating");


    -- Recorded arena number and winrate
    ArenaAnalyticsScrollFrame.totalArenaNumber = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame, "BOTTOMLEFT", 15, 30, "");
    ArenaAnalyticsScrollFrame.winrate = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.totalArenaNumber, "TOPRIGHT", 10, 0, "");
    ArenaAnalyticsScrollFrame.sessionWinrate = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.winrate, "TOPRIGHT", 20, 0, "");
    ArenaAnalyticsScrollFrame.selectedWinrate = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.sessionWinrate, "TOPRIGHT", 20, 0, "Selected: (click matches to select)");
    ArenaAnalyticsScrollFrame.clearSelected = AAtable:CreateButton("TOPLEFT", ArenaAnalyticsScrollFrame, "TOPRIGHT", 0, 0, "Clear");
    ArenaAnalyticsScrollFrame.clearSelected:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.selectedWinrate, "TOPRIGHT", 20, 5);
    ArenaAnalyticsScrollFrame.clearSelected:Hide();
    ArenaAnalyticsScrollFrame.clearSelected:SetScript("OnClick", function () AAtable:ClearSelectedMatches()end)


    -- Add esc to close frame
    _G["ArenaAnalyticsScrollFrame"] = ArenaAnalyticsScrollFrame 
    tinsert(UISpecialFrames, ArenaAnalyticsScrollFrame:GetName()) 

    -- Make frame draggable
    ArenaAnalyticsScrollFrame:SetMovable(true)
    ArenaAnalyticsScrollFrame:EnableMouse(true)
    ArenaAnalyticsScrollFrame:RegisterForDrag("LeftButton")
    ArenaAnalyticsScrollFrame:SetScript("OnDragStart", ArenaAnalyticsScrollFrame.StartMoving)
    ArenaAnalyticsScrollFrame:SetScript("OnDragStop", ArenaAnalyticsScrollFrame.StopMovingOrSizing)

    ArenaAnalyticsScrollFrame.specFrames = {}

    AAtable:OnShow();
end

function AAtable:OnShow()
    HybridScrollFrame_CreateButtons(ArenaAnalyticsScrollFrame.ListScrollFrame, "ArenaAnalyticsScrollListMatch");
    AAtable:RefreshLayout(true);
    ArenaAnalyticsScrollFrame:Hide();
end

-- Creates a frame and a texture with the class' spec
-- and places it on the bottom right corner of the class icon
local function addSpecFrame(button, classIconFrame, spec, class)
    if (classIconFrame.spec) then
        classIconFrame.spec.texture:SetTexture(nil)
    else
        local specFrame = CreateFrame("Frame", nil, classIconFrame)
        classIconFrame.spec = specFrame;
        classIconFrame.spec:SetPoint("BOTTOMRIGHT", classIconFrame, "BOTTOMRIGHT")
        classIconFrame.spec:SetSize(12,12)
        local specTexture = classIconFrame.spec:CreateTexture()
        classIconFrame.spec.texture = specTexture;
        classIconFrame.spec.texture:SetPoint("CENTER")
        classIconFrame.spec.texture:SetSize(12,12)
    end
    local specIconString = ArenaAnalyticsGetSpecIcon(spec, class)
    classIconFrame.spec.texture:SetTexture(specIconString and specIconString or nil)
    classIconFrame.spec:Hide();
    table.insert(ArenaAnalyticsScrollFrame.specFrames, {classIconFrame.spec, button})    
end

-- Displayes a small window with the clicked player's name
-- for easy copy/paste
function showClickedName(classFrame)
    local name = classFrame:GetAttribute("name");
    if (not ArenaAnalyticsScrollFrame.clickedNameFrame) then
        ArenaAnalyticsScrollFrame.clickedNameFrame = CreateFrame("Frame", nil, ArenaAnalyticsScrollFrame, "BasicFrameTemplateWithInset")
        ArenaAnalyticsScrollFrame.clickedNameFrame:SetFrameStrata("HIGH");
        ArenaAnalyticsScrollFrame.clickedNameFrame:SetSize(160, 60);
        ArenaAnalyticsScrollFrame.clickedNameFrame.text = CreateFrame("EditBox", nil, ArenaAnalyticsScrollFrame.clickedNameFrame, "BackdropTemplate");
        ArenaAnalyticsScrollFrame.clickedNameFrame.text:SetFrameStrata("HIGH");
        ArenaAnalyticsScrollFrame.clickedNameFrame.text:SetPoint("TOP", ArenaAnalyticsScrollFrame.clickedNameFrame, "TOP", 15, -35);
        ArenaAnalyticsScrollFrame.clickedNameFrame.text:SetWidth(160);
        ArenaAnalyticsScrollFrame.clickedNameFrame.text:SetMultiLine(true);
        ArenaAnalyticsScrollFrame.clickedNameFrame.text:SetAutoFocus(true);
        ArenaAnalyticsScrollFrame.clickedNameFrame.text:SetFont("Fonts\\FRIZQT__.TTF", 12, "");
        ArenaAnalyticsScrollFrame.clickedNameFrame.text:SetJustifyH("LEFT");
        ArenaAnalyticsScrollFrame.clickedNameFrame.text:SetJustifyV("CENTER");
    end
    ArenaAnalyticsScrollFrame.clickedNameFrame:SetPoint("TOPRIGHT", classFrame, "CENTER", 0, 0);
    ArenaAnalyticsScrollFrame.clickedNameFrame.text:SetText(name)
    ArenaAnalyticsScrollFrame.clickedNameFrame.text:HighlightText();
    ArenaAnalyticsScrollFrame.clickedNameFrame:Show()
end


-- Creates a icon-based string with the match's comp with name and spec tooltips
local function setClassTextureWithTooltip(teamIconsFrames, match, matchKey, button)
    for teamIconIndex = 1, #teamIconsFrames do
        if (match[matchKey][teamIconIndex]) then
            if (teamIconsFrames[teamIconIndex].texture) then
                -- Reset textures
                teamIconsFrames[teamIconIndex].texture:SetTexture(nil)
            else
                -- No textures? Set them
                local teamTexture = teamIconsFrames[teamIconIndex]:CreateTexture();
                teamIconsFrames[teamIconIndex].texture = teamTexture
                teamIconsFrames[teamIconIndex].texture:SetPoint("LEFT", teamIconsFrames[teamIconIndex] ,"RIGHT", -26, 0);
                teamIconsFrames[teamIconIndex].texture:SetSize(26,26)
            end

            -- Set texture (if classicon available)
            teamIconsFrames[teamIconIndex].texture:SetTexture(match[matchKey][teamIconIndex] and match[matchKey][teamIconIndex]["classIcon"] or nil);
            teamIconsFrames[teamIconIndex].tooltip = ""

            teamIconsFrames[teamIconIndex]:SetAttribute("name", match[matchKey][teamIconIndex] and match[matchKey][teamIconIndex]["name"] or "")

            -- Set click to copy name
            if (teamIconsFrames[teamIconIndex]) then
                teamIconsFrames[teamIconIndex]:SetScript("OnClick", function (args)
                    showClickedName(args);
                end
                )
            end

            local spec = match[matchKey][teamIconIndex]["spec"]
            -- Check for spec
            if (spec ~= "-") then
                addSpecFrame(button, teamIconsFrames[teamIconIndex], spec, match[matchKey][teamIconIndex]["class"])
                teamIconsFrames[teamIconIndex].tooltip = match[matchKey][teamIconIndex]["name"] .. " | " .. spec;
            else
                if (teamIconsFrames[teamIconIndex].spec) then
                    teamIconsFrames[teamIconIndex].spec = nil;
                end
                teamIconsFrames[teamIconIndex].tooltip = match[matchKey][teamIconIndex]["name"];
            end
            teamIconsFrames[teamIconIndex]:Show()
        else
            teamIconsFrames[teamIconIndex]:Hide()
        end

    end
    return teamIconsFrames[#teamIconsFrames];
end

-- Updates comp filter if there's a new comp registered
-- and updates winrate
function AAtable:checkForFilterUpdate(bracket)
    local frameByBracketTable = {
        ["2v2"] = ArenaAnalyticsScrollFrame.filterComps["2v2"],
        ["3v3"] = ArenaAnalyticsScrollFrame.filterComps["3v3"],
        ["5v5"] = ArenaAnalyticsScrollFrame.filterComps["5v5"],
    }
    frameByBracketTable[bracket].dropdownFrame:Hide();
    frameByBracketTable[bracket].dropdownFrame = nil;
    frameByBracketTable[bracket] = nil
    AAtable:createDropdownForFilterComps(bracket)

    local frameByEnemyBracketTable = {
        ["2v2"] = ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"],
        ["3v3"] = ArenaAnalyticsScrollFrame.filterEnemyComps["3v3"],
        ["5v5"] = ArenaAnalyticsScrollFrame.filterEnemyComps["5v5"],
    }
    frameByEnemyBracketTable[bracket].dropdownFrame:Hide();
    frameByEnemyBracketTable[bracket].dropdownFrame = nil;
    frameByEnemyBracketTable[bracket] = nil
    AAtable:createDropdownForFilterEnemyComps(bracket)
    --[[ ArenaAnalyticsScrollFrame.arenaTypeMenu.buttons[1]:Click() ]]
end

-- Returns matches applying current match filters
local function applyFilters(unfilteredDB)

    local holderDB = {
        ["2v2"] = {},
        ["3v3"] = {},
        ["5v5"] = {},
    };

    -- Filter map
    local arenaMaps = {{"Nagrand Arena","NA"}, {"Ruins of Lordaeron", "RoL"}, {"Blade Edge Arena", "BEA"}, {"Dalaran Arena", "DA"}}
    if (currentFilters["map"] == "All") then
        holderDB = CopyTable(unfilteredDB);
    else
        for _,arenaMap in ipairs(arenaMaps) do
            if (currentFilters["map"] == arenaMap[1]) then
                local brackets = {"2v2", "3v3", "5v5"};
                for _, bracket in ipairs(brackets) do
                    if (#unfilteredDB[bracket] > 0) then
                        for arenaNumber = 1, #unfilteredDB[bracket] do
                            if (unfilteredDB[bracket][arenaNumber]["map"] == arenaMap[2]) then
                                table.insert(holderDB[bracket], unfilteredDB[bracket][arenaNumber]);
                            end
                        end
                    end
                end
            end
        end
    end


    -- Filter comp
    if (currentFilters["bracket"] ~= "All" and isCompFilterOn) then
        local currentCompFilter = "comps" .. currentFilters["bracket"]
        local n2v2 = #holderDB["2v2"];
        local n3v3 = #holderDB["3v3"];
        local n5v5 = #holderDB["5v5"];
        if (currentFilters["bracket"] == "2v2") then
            for arena2v2Number = n2v2, 1, - 1 do
                if (holderDB["2v2"][arena2v2Number]) then
                    local DBCompAsString = table.concat(holderDB["2v2"][arena2v2Number]["comp"], "-");
                    if (DBCompAsString ~= currentFilters["comps2v2"]) then
                        table.remove(holderDB["2v2"], arena2v2Number)
                        n2v2 = n2v2 - 1
                    end
                end
            end
        end
        if (currentFilters["bracket"] == "3v3") then
        for arena3v3Number = n3v3, 1, -1 do
                if (holderDB["3v3"][arena3v3Number]) then
                    local DBCompAsString = table.concat(holderDB["3v3"][arena3v3Number]["comp"], "-");
                    if (DBCompAsString ~= currentFilters["comps3v3"]) then
                        table.remove(holderDB["3v3"], arena3v3Number)
                        n3v3 = n3v3 - 1
                    end
                end
            end
        end
        if (currentFilters["bracket"] == "5v5") then
            for arena5v5Number = n5v5, 1, -1 do
                if (holderDB["5v5"][arena5v5Number]) then
                    local DBCompAsString = table.concat(holderDB["5v5"][arena5v5Number]["comp"], "-");
                    if (DBCompAsString ~= currentFilters["comps5v5"]) then
                        table.remove(holderDB["5v5"], arena5v5Number)
                        n5v5 = n5v5 - 1
                    end
                end
            end
        end
    end

    -- Filter enemy comp
    if (currentFilters["bracket"] ~= "All" and isEnemyCompFilterOn) then
        local currentCompFilter = "enemycomps" .. currentFilters["bracket"]
        local n2v2 = #holderDB["2v2"];
        local n3v3 = #holderDB["3v3"];
        local n5v5 = #holderDB["5v5"];
        if (currentFilters["bracket"] == "2v2") then
            for arena2v2Number = n2v2, 1, - 1 do
                if (holderDB["2v2"][arena2v2Number]) then
                    local DBCompAsString = table.concat(holderDB["2v2"][arena2v2Number]["enemyComp"], "-");
                    if (DBCompAsString ~= currentFilters["enemycomps2v2"]) then
                        table.remove(holderDB["2v2"], arena2v2Number)
                        n2v2 = n2v2 - 1
                    end
                end
            end
        end
        if (currentFilters["bracket"] == "3v3") then
        for arena3v3Number = n3v3, 1, -1 do
                if (holderDB["3v3"][arena3v3Number]) then
                    local DBCompAsString = table.concat(holderDB["3v3"][arena3v3Number]["enemyComp"], "-");
                    if (DBCompAsString ~= currentFilters["enemycomps3v3"]) then
                        table.remove(holderDB["3v3"], arena3v3Number)
                        n3v3 = n3v3 - 1
                    end
                end
            end
        end
        if (currentFilters["bracket"] == "5v5") then
            for arena5v5Number = n5v5, 1, -1 do
                if (holderDB["5v5"][arena5v5Number]) then
                    local DBCompAsString = table.concat(holderDB["5v5"][arena5v5Number]["enemyComp"], "-");
                    if (DBCompAsString ~= currentFilters["enemycomps5v5"]) then
                        table.remove(holderDB["5v5"], arena5v5Number)
                        n5v5 = n5v5 - 1
                    end
                end
            end
        end
    end

    
    -- Filter bracket
    if(currentFilters["bracket"] == "2v2") then
        holderDB["3v3"] = {}
        holderDB["5v5"] = {}
    elseif(currentFilters["bracket"] == "3v3") then
        holderDB["2v2"] = {}
        holderDB["5v5"] = {}
    elseif(currentFilters["bracket"] == "5v5") then
        holderDB["3v3"] = {}
        holderDB["2v2"] = {}
    end

    -- Filter Skirmish
    if (ArenaAnalyticsSettings["skirmishIsChecked"] == false) then
        local n2v2 = #holderDB["2v2"];
        local n3v3 = #holderDB["3v3"];
        local n5v5 = #holderDB["5v5"];

        for arena2v2Number = n2v2, 1, -1 do
            if (holderDB["2v2"][arena2v2Number]) then
                if (not holderDB["2v2"][arena2v2Number]["isRanked"]) then
                    table.remove(holderDB["2v2"], arena2v2Number)
                    n2v2 = n2v2 - 1
                end
            end
        end
        for arena3v3Number = n3v3, 1, -1 do
            if (holderDB["3v3"][arena3v3Number]) then
                if (not holderDB["3v3"][arena3v3Number]["isRanked"]) then
                    table.remove(holderDB["3v3"], arena3v3Number)
                    n3v3 = n3v3 - 1
                end
            end
        end
        for arena5v5Number = n5v5, 1, -1 do
            if (holderDB["5v5"][arena5v5Number]) then
                if (not holderDB["5v5"][arena5v5Number]["isRanked"]) then
                    table.remove(holderDB["5v5"], arena5v5Number)
                    n5v5 = n5v5 - 1
                end
            end
        end
    end


    -- Filter Season (only show current season)
    if (ArenaAnalyticsSettings["seasonIsChecked"] == false) then
        local n2v2 = #holderDB["2v2"];
        local n3v3 = #holderDB["3v3"];
        local n5v5 = #holderDB["5v5"];
        for arena2v2Number = n2v2, 1, -1 do
            if (holderDB["2v2"][arena2v2Number]) then
                if (holderDB["2v2"][arena2v2Number]["dateInt"] < currentSeasonStartInt) then
                    table.remove(holderDB["2v2"], arena2v2Number)
                    n2v2 = n2v2 - 1
                end
            end
        end
        for arena3v3Number = n3v3, 1, -1 do
            if (holderDB["3v3"][arena3v3Number]) then
                if (holderDB["3v3"][arena3v3Number]["dateInt"] < currentSeasonStartInt) then
                    table.remove(holderDB["3v3"], arena3v3Number)
                    n3v3 = n3v3 - 1
                end
            end
        end
        for arena5v5Number = n5v5, 1, -1 do
            if (holderDB["5v5"][arena5v5Number]) then
                if (holderDB["5v5"][arena5v5Number]["dateInt"] < currentSeasonStartInt) then
                    table.remove(holderDB["5v5"], arena5v5Number)
                    n5v5 = n5v5 - 1
                end
            end
        end
    end

    -- Get arenas from each bracket and sort by date 
    local sortedDB = {}; 

    for b = 1, #holderDB["2v2"] do
        table.insert(sortedDB, holderDB["2v2"][b]);
    end
    for n = 1, #holderDB["3v3"] do
        table.insert(sortedDB, holderDB["3v3"][n]);
    end
    for m = 1, #holderDB["5v5"] do
        table.insert(sortedDB, holderDB["5v5"][m]);
    end
    
    table.sort(sortedDB, function (k1,k2)
        if (k1["dateInt"] and k2["dateInt"]) then
            return k1["dateInt"] > k2["dateInt"];
        end
    end)

    return sortedDB;
end

-- Hide/Shows Spec icons on the class' bottom-right corner
function AAtable:ToggleSpecs(match, visible)
    local matchData = { match:GetChildren() };
    for i = 1, #matchData do
        if (matchData[i].spec) then
            if (visible) then
                matchData[i].spec:Show();
            elseif (match:GetAttribute("clicked")) then
                matchData[i].spec:Show();
            else
                matchData[i].spec:Hide();
            end
        end
    end
end

-- Checks if 2 arenas have the same party members
local function arenasHaveSameParty(arena, prevArena)
    for i = 1, #arena["team"] do
        if (prevArena["team"][i] and arena["team"][i]["name"] ~= prevArena["team"][i]["name"]) then
            return false;
        end
    end
    return true;
end

-- Adds value(int) ["session"] to each match
-- If the previous match was more than 1h ago, or
-- with different teammates (ranked only) then a new session is assigned
local function setSessions(matches)
    local session = 1
    for i = 1, #matches do
        local prev = matches[i - 1]
        if (prev and (matches[i]["dateInt"] + 3600 < prev["dateInt"] or (not arenasHaveSameParty(matches[i], prev) and (matches[i]["isRanked"] or prev["isRanked"])))) then
            session = session + 1
        end
        matches[i]["session"] = session;
    end
    
end

-- Sets button row's background according to session
local function setColorForSession(button, session)
    local c = session%2/10;
    local a = 0.5;
    button.Background:SetColorTexture(c, c, c, a)
end

-- Create dropdowns for the Comp filters
function AAtable:createDropdownForFilterComps(bracket)
    filterCompsOpts[bracket] = {
        ['name']='Filter' .. bracket .. '_Comps',
        ['parent'] = ArenaAnalyticsScrollFrame,
        ['title']='Comp: Games | Comp | Winrate',
        ['hasIcon']= true,
        ['matches'] = AAtable:getPlayerPlayedComps(bracket, nil),
        ['defaultVal'] ='All'
    }

    ArenaAnalyticsScrollFrame.filterComps[bracket] = AAtable:createDropdown(filterCompsOpts[bracket])
    ArenaAnalyticsScrollFrame.filterComps[bracket].dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.filterMap.dropdownFrame, "RIGHT", 15, 0);

    if(bracket == "2v2") then
        -- Set tooltip when comp is disabled
        ArenaAnalyticsScrollFrame.filterComps[bracket].selected:Disable();
        ArenaAnalyticsScrollFrame.filterComps[bracket].selected:SetDisabledFontObject("GameFontDisableSmall")
        ArenaAnalyticsScrollFrame.filterComps[bracket].selected:SetText("Select bracket");
    else
        ArenaAnalyticsScrollFrame.filterComps[bracket].dropdownFrame:Hide();
    end
end
-- Create dropdowns for the Comp Enemy filters
function AAtable:createDropdownForFilterEnemyComps(bracket)
    filterEnemyCompsOpts[bracket] = {
        ['name']='Filter' .. bracket .. '_EnemyComps',
        ['parent'] = ArenaAnalyticsScrollFrame,
        ['title']='Enemy Comp: Games | Comp | Winrate',
        ['hasIcon']= true,
        ['matches'] = AAtable:getEnemyPlayedComps(bracket, nil),
        ['defaultVal'] ='All'
    }


    ArenaAnalyticsScrollFrame.filterEnemyComps[bracket] = AAtable:createDropdown(filterEnemyCompsOpts[bracket])
    ArenaAnalyticsScrollFrame.filterEnemyComps[bracket].dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.filterComps["2v2"].dropdownFrame, "RIGHT", 15, 0);
    
    if(bracket == "2v2") then
        -- Set tooltip when comp is disabled
        ArenaAnalyticsScrollFrame.filterEnemyComps[bracket].selected:Disable();
        ArenaAnalyticsScrollFrame.filterEnemyComps[bracket].selected:SetDisabledFontObject("GameFontDisableSmall")
        ArenaAnalyticsScrollFrame.filterEnemyComps[bracket].selected:SetText("Select bracket");
        ArenaAnalyticsScrollFrame.filterEnemyComps[bracket].dropdownFrame:Show()
    else
        ArenaAnalyticsScrollFrame.filterEnemyComps[bracket].dropdownFrame:Hide();
    end
end


-- Searches for a match by its dateInt
-- returns match as table and bracket as string
function AAtable:getDBMatchByDateInt(dateInt)
    local DBmatch, bracket;
    local brackets = {"2v2", "3v3", "5v5"}
    for i = 1, #brackets do
        for j = 1, #ArenaAnalyticsDB[brackets[i]] do
            if (ArenaAnalyticsDB[brackets[i]][j]["dateInt"] == dateInt) then
                DBmatch = ArenaAnalyticsDB[brackets[i]][j];
                bracket = brackets[i];
                break;
            end
        end
        if (DBmatch ~= nil) then break end;        
    end
    return DBmatch, bracket
end

-- Fix rating gains for a specific game
function AAtable:fixRatingGains(tableMatch)
    local DBmatch, bracket = AAtable:getDBMatchByDateInt(tableMatch["dateInt"])
    local teamId
    if (string.find(bracket, "2")) then
        teamId = 1
    elseif (string.find(bracket, "3")) then 
        teamId = 2
    else
        teamId = 3
    end
    local personalRating, _, _, _, _, _, _, _, _, _, _ = GetPersonalRatedInfo(teamId)
    print(personalRating, DBmatch["rating"])
    if (personalRating ~= DBmatch["rating"]) then
        if (DBmatch["won"] == true) then
            DBmatch["ratingDelta"] = personalRating - DBmatch["rating"]
            tableMatch["ratingDelta"] = personalRating - tableMatch["rating"]
            DBmatch["rating"] = DBmatch["rating"] + DBmatch["ratingDelta"]
            tableMatch["rating"] = DBmatch["rating"] + DBmatch["ratingDelta"]
        else
            DBmatch["ratingDelta"] = DBmatch["rating"] - personalRating
            tableMatch["ratingDelta"] = tableMatch["rating"] - personalRating
            DBmatch["rating"] = DBmatch["rating"] - DBmatch["ratingDelta"]
            tableMatch["rating"] = DBmatch["rating"] - DBmatch["ratingDelta"]
        end
        DBmatch["check"] = true;
        tableMatch["check"] = true;
        print(tableMatch["ratingDelta"], DBmatch["ratingDelta"])
        AAtable:RefreshLayout()
    end
end

function AAtable:getLastGame()
    local lastGame2v2 = ArenaAnalyticsDB["2v2"][#ArenaAnalyticsDB["2v2"]] and ArenaAnalyticsDB["2v2"][#ArenaAnalyticsDB["2v2"]] or nil
    local lastGame3v3 = ArenaAnalyticsDB["3v3"][#ArenaAnalyticsDB["3v3"]] and ArenaAnalyticsDB["3v3"][#ArenaAnalyticsDB["3v3"]] or nil
    local lastGame5v5 = ArenaAnalyticsDB["5v5"][#ArenaAnalyticsDB["5v5"]] and ArenaAnalyticsDB["5v5"][#ArenaAnalyticsDB["5v5"]] or nil
    if(lastGame2v2) then
        if(lastGame3v3) then
            if(lastGame5v5) then
                if (lastGame2v2["dateInt"] > lastGame3v3["dateInt"] and lastGame2v2["dateInt"] > lastGame5v5["dateInt"]) then
                    return lastGame2v2
                elseif (lastGame3v3["dateInt"] > lastGame2v2["dateInt"] and lastGame3v3["dateInt"] > lastGame5v5["dateInt"]) then
                    return lastGame3v3
                else
                    return lastGame5v5
                end
            elseif (lastGame2v2["dateInt"] > lastGame3v3["dateInt"]) then
                return lastGame3v3
            end
        elseif (lastGame5v5 and lastGame2v2["dateInt"] > lastGame5v5["dateInt"]) then
            return lastGame2v2
        else
            return lastGame2v2
        end
    elseif (lastGame3v3) then
        if(lastGame5v5) then
            if (lastGame3v3["dateInt"] > lastGame5v5["dateInt"]) then
                return lastGame3v3
            else
                return lastGame5v5
            end
        else
            return lastGame3v3
        end
    elseif (lastGame5v5) then
        return lastGame5v5
    end
    return nil
end

-- Refreshes matches table
function AAtable:RefreshLayout(filter)
    ArenaAnalyticsDB = ArenaAnalyticsDB["2v2"] ~= nil and ArenaAnalyticsDB or {
        ["2v2"] = {},
        ["3v3"] = {},
        ["5v5"] = {},
    };
    local newArenaPlayed = false;
    local currentTotalArenas = #ArenaAnalyticsDB["2v2"] + #ArenaAnalyticsDB["3v3"] + #ArenaAnalyticsDB["5v5"]
    if (currentTotalArenas > totalArenas) then
        newArenaPlayed = true;
        totalArenas = currentTotalArenas;
    end

    if (filter or filteredDB == nil or newArenaPlayed) then
        filteredDB = applyFilters(ArenaAnalyticsDB)
    end
    
    ArenaAnalyticsScrollFrame.matches = filteredDB;

    local matches = ArenaAnalyticsScrollFrame.matches;
    local buttons = HybridScrollFrame_GetButtons(ArenaAnalyticsScrollFrame.ListScrollFrame);
    local offset = HybridScrollFrame_GetOffset(ArenaAnalyticsScrollFrame.ListScrollFrame);
    local wins = 0;

    setSessions(matches)

    local lastGame = AAtable:getLastGame()
    
    if (lastGame and lastGame["check"] == false and lastGame["isRanked"] == true and not IsActiveBattlefieldArena()) then
        print("fixing rating last game")
        AAtable:fixRatingGains(lastGame);
    end

    for buttonIndex = 1, #buttons do
        local button = buttons[buttonIndex];
        local matchIndex = buttonIndex + offset;

        if matchIndex <= #matches then
            local match = matches[matchIndex];
            setColorForSession(button, match["session"])
            button.Date:SetText(date("%d/%m/%y %H:%M:%S", match["dateInt"]) or "");
            button.Map:SetText(match["map"] or "");
            button.Duration:SetText(match["duration"] or "");

            button:SetScript("OnEnter", function (args)
            AAtable:ToggleSpecs(args, true)
            end)
            button:SetScript("OnLeave", function (args)
                AAtable:ToggleSpecs(args, false)
            end)
            local teamIconsFrames = {button.Team1, button.Team2, button.Team3, button.Team4, button.Team5}
            local enemyTeamIconsFrames = {button.EnemyTeam1, button.EnemyTeam2, button.EnemyTeam3, button.EnemyTeam4, button.EnemyTeam5}
            
            local ratingPrevFrame = setClassTextureWithTooltip(teamIconsFrames, match, "team", button)
            local enemyDelta
            -- Paint winner green, loser red 
            if (match["won"]) then
                local delta = (match["ratingDelta"] and match["ratingDelta"] ~= "") and " (+" .. match["ratingDelta"] .. ")" or ""
                enemyDelta = (match["enemyRatingDelta"] and match["enemyRatingDelta"] ~= "") and " (-" .. match["enemyRatingDelta"] .. ")" or ""
                if (match["rating"]) then
                    button.Rating:SetText("|cff00cc66" .. match["rating"] .. delta .. "|r");
                end
            else
                local delta = (match["ratingDelta"] and match["ratingDelta"] ~= "") and " (-" .. match["ratingDelta"] .. ")" or ""
                enemyDelta = (match["enemyRatingDelta"] and match["enemyRatingDelta"] ~= "") and " (+" .. match["enemyRatingDelta"] .. ")" or ""
                if (match["rating"]) then
                    button.Rating:SetText("|cffff0000" .. match["rating"] .. delta .."|r");
                end
                
            end

            button.MMR:SetText(match["mmr"] or "");

            local enemyRatingPrevFrame = setClassTextureWithTooltip(enemyTeamIconsFrames, match, "enemyTeam", button)
            local enemyRating = match["enemyRating"] and match["enemyRating"] or ""
            button.EnemyRating:SetText(enemyRating .. enemyDelta or "");
            button.EnemyMMR:SetText(match["enemyMmr"] or "");

            
            button:SetAttribute("won", match["won"]);

            if (selectedGames[button.Date:GetText()]) then
                button:SetAttribute("clicked", true)
                button.Tooltip:Show()
            else
                button:SetAttribute("clicked", false)
                button.Tooltip:Hide()
            end

            button:SetScript("OnClick", function (args)
                if (not args:GetAttribute("clicked")) then
                    args:SetAttribute("clicked", true)
                    args.Tooltip:Show();
                    selectedGames[args.Date:GetText()] = args;
                    AAtable:UpdateSelected();
                    AAtable:ToggleSpecs(args, true)
                else
                    args:SetAttribute("clicked", false)
                    selectedGames[args.Date:GetText()] = nil;
                    args.Tooltip:Hide();
                    AAtable:UpdateSelected();
                    AAtable:ToggleSpecs(args, false)
                end
            end
            )

            button:SetWidth(ArenaAnalyticsScrollFrame.ListScrollFrame.scrollChild:GetWidth());
            button:Show();
        else
            button:Hide();
        end
    end

    if (ArenaAnalyticsScrollFrame.filterComps["2v2"] == nil) then
        AAtable:createDropdownForFilterComps("2v2")
    elseif (newArenaPlayed) then
        AAtable:checkForFilterUpdate("2v2");
    end
    if (ArenaAnalyticsScrollFrame.filterComps["3v3"] == nil) then
        AAtable:createDropdownForFilterComps("3v3")
    elseif (newArenaPlayed) then
        AAtable:checkForFilterUpdate("3v3");
    end
    if (ArenaAnalyticsScrollFrame.filterComps["5v5"] == nil) then
        AAtable:createDropdownForFilterComps("5v5")
    elseif (newArenaPlayed) then
        AAtable:checkForFilterUpdate("5v5");
    end

    if (ArenaAnalyticsScrollFrame.filterEnemyComps["2v2"] == nil) then
        AAtable:createDropdownForFilterEnemyComps("2v2")
    end
    if (ArenaAnalyticsScrollFrame.filterEnemyComps["3v3"] == nil) then
        AAtable:createDropdownForFilterEnemyComps("3v3")
    end
    if (ArenaAnalyticsScrollFrame.filterEnemyComps["5v5"] == nil) then
        AAtable:createDropdownForFilterEnemyComps("5v5")
    end

    -- Adjust Team bg
    if (#matches < 15) then
        local newHeight = (#matches * 28) - 1;
        ArenaAnalyticsScrollFrame.teamBgT:SetHeight(newHeight);
        ArenaAnalyticsScrollFrame.teamBg:SetHeight(newHeight);
    else
        ArenaAnalyticsScrollFrame.teamBgT:SetHeight(413);
        ArenaAnalyticsScrollFrame.teamBg:SetHeight(413);
    end
    
    local sessionWins = 0;
    local sessionGames = 0;

    -- Update arena count & winrate
    for n = 1, #matches do
        if(matches[n]["won"]) then wins = wins + 1; end
        if (matches[n]["session"] == 1 ) then
            sessionGames = sessionGames + 1;
            if (matches[n]["won"]) then
                sessionWins = sessionWins + 1;
            end
        end
    end

    local totalArenas = #ArenaAnalyticsScrollFrame.matches;
    local winrate = totalArenas > 0 and math.floor(wins * 100 / totalArenas) or 0;
    local winsColoured =  "|cff00cc66" .. wins .. "|r";
    ArenaAnalyticsScrollFrame.totalArenaNumber:SetText("Total: " .. totalArenas .. " arenas");
    ArenaAnalyticsScrollFrame.winrate:SetText(winsColoured .. "/" .. (totalArenas - wins) .. " | " .. winrate .. "% Winrate");

    local sessionWinrate = sessionGames > 0 and math.floor(sessionWins * 100 / sessionGames) or 0;
    local sessionWinsColoured =  "|cff00cc66" .. sessionWins .. "|r";
    ArenaAnalyticsScrollFrame.sessionWinrate:SetText("Current session: " .. sessionGames .. " arenas   " .. sessionWinsColoured .. "/" .. (sessionGames - sessionWins) .. " | " .. sessionWinrate .. "% Winrate");



    local buttonHeight = ArenaAnalyticsScrollFrame.ListScrollFrame.buttonHeight;
    local totalHeight = #matches * buttonHeight;
    local shownHeight = #buttons * buttonHeight;

    -- Hide spec icons
    hideSpecIcons()

    HybridScrollFrame_Update(ArenaAnalyticsScrollFrame.ListScrollFrame, totalHeight, shownHeight);
    
end