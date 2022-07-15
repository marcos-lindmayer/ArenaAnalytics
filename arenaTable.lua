--[[ 
    CODE NOT YET COMMENTED
    (sorry)
 ]]

local _, core = ...;

local currentFilters = {
    ["map"] = "All", 
    ["bracket"] = "All", 
    ["comps"] = "All",
    ["comps2v2"] = "All", 
    ["comps3v3"] = "All", 
    ["comps5v5"] = "All",
    ["skirmishIsChecked"] = true
};

local isCompFilterOn;
local dropdownCounter = 1;
local filterComps2v2_opts, filterComps3v3_opts, filterComps5v5_opts
local totalArenas = #ArenaAnalyticsDB["2v2"] + #ArenaAnalyticsDB["3v3"] + #ArenaAnalyticsDB["5v5"] 

local selectedGames = {}

HybridScrollMixin = {};
core.arenaTable = HybridScrollMixin;

-- Toggles addOn view/hide
function core.arenaTable:Toggle()
    if not ArenaAnalyticsScrollFrame:IsShown() then  
        core.arenaTable:ClearSelectedMatches() 
        ArenaAnalyticsScrollFrame:Show();
    else
        ArenaAnalyticsScrollFrame:Hide();
    end
end

-- Returns button based on params
function core.arenaTable:CreateButton(point, relativeFrame, relativePoint, xOffset, yOffset, text)
	local btn = CreateFrame("Button", nil, relativeFrame, "UIServiceButtonTemplate");
	btn:SetPoint(point, relativeFrame, relativePoint, xOffset, yOffset);
	btn:SetSize(120, 25);
	btn:SetText(text);
    btn.money:Hide();
	btn:SetNormalFontObject("GameFontHighlight");
	btn:SetHighlightFontObject("GameFontHighlight");
	return btn;
end

-- Return specific comp's winrate
-- comp is a string of space-separated classes
local function getCompWinrate(comp)
    local _, bracket = string.gsub(comp, " ", " ")
    local bracketSize = bracket + 1;
    bracket = bracketSize .. "v" .. bracketSize;
    local arenasWithComp = {}
    for i = 1, #ArenaAnalyticsDB[bracket] do
        if (#ArenaAnalyticsDB[bracket][i]["comp"] == bracketSize) then
            local currentComp = table.concat(ArenaAnalyticsDB[bracket][i]["comp"], " ")
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
        winrate = winrate .. "%" .. "   "
    elseif (#tostring(winrate) < 3) then
        winrate = winrate .. "%" .. " "
    else
        winrate = winrate .. "%"
    end
    
    return winrate
end

local function hideSpecIcons()
    for specIconNumber = 1, #ArenaAnalyticsScrollFrame.specFrames do
        if (not ArenaAnalyticsScrollFrame.specFrames[specIconNumber][2]:GetAttribute("clicked")) then
            ArenaAnalyticsScrollFrame.specFrames[specIconNumber][1]:Hide()
        else
            ArenaAnalyticsScrollFrame.specFrames[specIconNumber][1]:Show()
        end
    end
end

function core.arenaTable:ClearSelectedMatches()
    local buttons = HybridScrollFrame_GetButtons(ArenaAnalyticsScrollFrame.ListScrollFrame)
    for i = 1, #buttons do
        buttons[i]:SetAttribute("clicked", false)
        buttons[i].Tooltip:Hide();
    end
    hideSpecIcons()
    selectedGames = {}
    core.arenaTable:UpdateSelected()
end

-- Changes the current filter upon selecting one from its dropdown
local function changeFilter(args)
    core.arenaTable:ClearSelectedMatches()
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
        ArenaAnalyticsScrollFrame.filterComps2v2.selected:SetText("All");
        currentFilters["comps3v3"] = "All"
        currentFilters["comps5v5"] = "All"
        ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame:Show();
        ArenaAnalyticsScrollFrame.filterComps3v3.dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterComps5v5.dropdownFrame:Hide();
    elseif (selectedFilter == "3v3") then
        ArenaAnalyticsScrollFrame.filterComps3v3.selected:SetText("All");
        currentFilters["comps2v2"] = "All"
        currentFilters["comps5v5"] = "All"
        ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterComps3v3.dropdownFrame:Show();
        ArenaAnalyticsScrollFrame.filterComps5v5.dropdownFrame:Hide();
    elseif (selectedFilter == "5v5") then
        ArenaAnalyticsScrollFrame.filterComps5v5.selected:SetText("All");
        currentFilters["comps2v2"] = "All"
        currentFilters["comps3v3"] = "All"
        ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterComps3v3.dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterComps5v5.dropdownFrame:Show();
    end

    if (filterName == "Bracket" and selectedFilter ~= "All") then
        ArenaAnalyticsScrollFrame.filterComps2v2.selected:Enable();
        ArenaAnalyticsScrollFrame.filterComps2v2.selected:SetText("All");
    elseif (filterName == "Bracket") then
        ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame:Show();
        ArenaAnalyticsScrollFrame.filterComps2v2.selected:Disable();
        ArenaAnalyticsScrollFrame.filterComps3v3.dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterComps5v5.dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterComps2v2.selected:SetText("Select bracket");
        ArenaAnalyticsScrollFrame.filterComps3v3.selected:SetText("All");
        ArenaAnalyticsScrollFrame.filterComps5v5.selected:SetText("All");
        currentFilters["comps2v2"] = "All";
        currentFilters["comps3v3"] = "All";
        currentFilters["comps5v5"] = "All";
    end
    
    if (currentFilters["bracket"] ~= "All" and currentFilters["comps" .. currentFilters["bracket"]] ~= "All") then 
        isCompFilterOn = true;
    else
        isCompFilterOn = false;
    end

    core.arenaTable:RefreshLayout();
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

-- Returns a dropdown frame
-- Used for match filters
local function createDropdown(opts)
    local dropdownTable = {};
    local dropdown_name ='$parent_' .. opts['name'] .. '_dropdown';
    local menu_items = opts['items'] or {};
    local hasIcon = opts["hasIcon"];
    local title_text = opts['title'] or '';
    local dropdown_width = title_text == "Comp" and 100 or 0;
    local default_val = opts['defaultVal'] or '';
    local change_func = opts['changeFunc'] or function (dropdown_val) end;

    local dropdown = CreateFrame("Frame", dropdown_name, opts['parent'])
    dropdownTable.dropdownFrame = dropdown;
    local dropdownList = CreateFrame("Frame", dropdown_name .. "_list", dropdownTable.dropdownFrame)
    dropdownTable.dropdownList = dropdownList
    dropdownTable.dropdownFrame:SetSize(500, 25);
    dropdownTable.dropdownList:SetPoint("TOPLEFT", dropdownTable.dropdownFrame, "BOTTOMLEFT")
    local dd_title = dropdownTable.dropdownFrame:CreateFontString(dropdownTable.dropdownFrame, 'OVERLAY', 'GameFontNormal')
    dropdownTable.dd_title = dd_title;
    if (hasIcon) then
        is2v2, _ = string.find(opts['name'], "2v2")
        if (is2v2) then
            dropdownTable.filterName = "comps2v2"
        else
            is3v3, _ = string.find(opts['name'], "3v3")
            if (is3v3) then
                dropdownTable.filterName = "comps3v3"
            else
                dropdownTable.filterName = "comps5v5"
            end
        end
        
    else 
        dropdownTable.filterName = title_text;
    end
    
    dropdownTable.dd_title:SetPoint("TOPLEFT", 0, 13)

    dropdownTable.buttons = {}
    -- Sets the dropdown width to the largest item string width.
    for _, item in pairs(menu_items) do 
        dropdownTable.dd_title:SetText(item)
        local text_width = dropdownTable.dd_title:GetStringWidth() + 30
        if text_width > dropdown_width then
            dropdown_width = text_width
        end
        local info = {}
        info.text = item;
        info.tooltip = "";
        if(hasIcon and info.text ~= "All") then
            local classInlineIcons = ""
            for arenaClass in string.gmatch(info.text, "([^%s]+)") do
                local arenaIconPath = ArenaAnalyticsGetClassIcon(arenaClass);
                local singleIcon = IconClass(arenaIconPath, 0, 0, 0, 0, 0, 0, 25, 25);
                classInlineIcons = classInlineIcons .. singleIcon:GetIconString() .. " ";
                info.tooltip = info.tooltip .. arenaClass .. " "
            end
            info.tooltip = info.tooltip:sub(1, -2)
            info.text = classInlineIcons .. " - " .. getCompWinrate(info.text);
        end
        table.insert(dropdownTable.buttons, createDropdownButton(info, dropdownTable, title_text, dropdown_width))
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
        return k1["date"] > k2["date"];
    end)

    for arenaN = 1, #allArenas do
        CSVString = CSVString 
        .. allArenas[arenaN]["date"] .. ","
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
-- param received. Ignores incomplete comps
local function getPlayerPlayedComps(bracket)
    local playedComps = {"All"};
    local arenaSize = tonumber(string.sub(bracket, 1, 1))
    if (bracket == nil) then
        return playedComps;
    else
        for arenaNumber = 1, #ArenaAnalyticsDB[bracket] do   
            if (#ArenaAnalyticsDB[bracket][arenaNumber]["comp"] == arenaSize) then
                table.sort(ArenaAnalyticsDB[bracket][arenaNumber]["comp"], function(a,b)
                    local prioA = a == UnitClass("player") and 1 or 2
                    local prioB = b == UnitClass("player") and 1 or 2
                    return prioA < prioB or (prioA == prioB and a < b)
                end)
                local compString = table.concat(ArenaAnalyticsDB[bracket][arenaNumber]["comp"], " ");

                if (not tContains(playedComps, compString)) then
                    table.insert(playedComps, compString)
                end
            end
        end
    end
    return playedComps;
end

-- Returns string frame
local function createText(relativeFrame, anchor, refFrame, relPoint, xOff, yOff, text)
    local fontString = relativeFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
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
    ArenaAnalyticsScrollFrame.exportFrame:SetAutoFocus(false);
    ArenaAnalyticsScrollFrame.exportFrame:SetCursorPosition(0);
    ArenaAnalyticsScrollFrame.exportFrame:SetFont("Fonts\\FRIZQT__.TTF", 10);
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

function core.arenaTable:UpdateSelected()
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
function core.arenaTable:OnLoad()

    ArenaAnalyticsScrollFrame.ListScrollFrame.update = function() core.arenaTable:RefreshLayout(); end

    HybridScrollFrame_SetDoNotHideScrollBar(ArenaAnalyticsScrollFrame.ListScrollFrame, true);
    ArenaAnalyticsScrollFrame.Bg:SetTexture(nil)
    ArenaAnalyticsScrollFrame.Bg:SetColorTexture(0, 0, 0, 0.5)
	ArenaAnalyticsScrollFrame.title = ArenaAnalyticsScrollFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	ArenaAnalyticsScrollFrame.title:SetPoint("CENTER", ArenaAnalyticsScrollFrame.TitleBg, "CENTER", 0, 0);
	ArenaAnalyticsScrollFrame.title:SetText("Arena Analytics");

    ArenaAnalyticsScrollFrame.ListScrollFrame.scrollBar:SetPoint("RIGHT", ArenaAnalyticsScrollFrame.ListScrollFrame, "RIGHT", 1, 0)

    ArenaAnalyticsScrollFrame.TitleBg:SetColorTexture(0,0,0,0.8)
    ArenaAnalyticsScrollFrame.teamBg = CreateFrame("Frame", nil, ArenaAnalyticsScrollFrame)
	ArenaAnalyticsScrollFrame.teamBg:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame, "TOPLEFT", 340, -90);
    ArenaAnalyticsScrollFrame.teamBg:SetFrameStrata("LOW");
    ArenaAnalyticsScrollFrame.teamBgT = ArenaAnalyticsScrollFrame.teamBg:CreateTexture()
    ArenaAnalyticsScrollFrame.teamBgT:SetColorTexture(0, 0, 0, 0.3)
	ArenaAnalyticsScrollFrame.teamBgT:SetSize(270, 413);
	ArenaAnalyticsScrollFrame.teamBg:SetSize(270, 413);
	ArenaAnalyticsScrollFrame.teamBgT:SetPoint("CENTER", ArenaAnalyticsScrollFrame.teamBg, "CENTER");

    ArenaAnalyticsScrollFrame.export = core.arenaTable:CreateButton("TOPLEFT", ArenaAnalyticsScrollFrame, "TOPLEFT", 20, -35, "Export");
    ArenaAnalyticsScrollFrame.export:SetScript("OnClick", exportDB);

    -- Set export DB CSV frame layout
    createExportFrame();

    local arenaBracket_opts = {
        ['name']='Arena_Bracket',
        ['parent'] = ArenaAnalyticsScrollFrame,
        ['title']='Bracket',
        ['icon']= false,
        ['items'] = {'All' ,'2v2', '3v3', '5v5' },
        ['defaultVal'] ='All', 
    }

    ArenaAnalyticsScrollFrame.arenaTypeMenu = createDropdown(arenaBracket_opts)
    ArenaAnalyticsScrollFrame.arenaTypeMenu.dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.export, "RIGHT", 15, 0);

    local filterMap_opts = {
        ['name']='Filter_Map',
        ['parent'] = ArenaAnalyticsScrollFrame,
        ['title']='Map',
        ['icon']= false,
        ['items'] = {'All' ,'Nagrand Arena' ,'Ruins of Lordaeron', 'Blade Edge Arena'},
        ['defaultVal'] ='All'
    }
    
    ArenaAnalyticsScrollFrame.filterMap = createDropdown(filterMap_opts)
    ArenaAnalyticsScrollFrame.filterMap.dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.arenaTypeMenu.dropdownFrame, "RIGHT", 15, 0);

    

    ArenaAnalyticsScrollFrame.skirmishToggle = CreateFrame("CheckButton", "ArenaAnalyticsScrollFrame_skirmishToggle", ArenaAnalyticsScrollFrame, "OptionsSmallCheckButtonTemplate");
    ArenaAnalyticsScrollFrame.skirmishToggle:SetPoint("TOPRIGHT", ArenaAnalyticsScrollFrame, "TOPRIGHT", -120, -40);
    ArenaAnalyticsScrollFrame_skirmishToggleText:SetText("Show Skirmish");
    ArenaAnalyticsScrollFrame.skirmishToggle:SetChecked(true);

    ArenaAnalyticsScrollFrame.skirmishToggle:SetScript("OnClick", 
        function()
            currentFilters["skirmishIsChecked"] = ArenaAnalyticsScrollFrame.skirmishToggle:GetChecked();
            core.arenaTable:RefreshLayout();
        end
    );
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
    ArenaAnalyticsScrollFrame.settingsFrame = CreateFrame("Frame", nil, ArenaAnalyticsScrollFrame, "BasicFrameTemplateWithInset")
    ArenaAnalyticsScrollFrame.settingsFrame:SetPoint("CENTER")
    ArenaAnalyticsScrollFrame.settingsFrame:SetSize(250, 100)
    ArenaAnalyticsScrollFrame.settingsFrame:SetFrameStrata("HIGH");
    ArenaAnalyticsScrollFrame.settingsFrame:Hide();

    ArenaAnalyticsScrollFrame.resetWarning = createText(ArenaAnalyticsScrollFrame.settingsFrame, "TOP", ArenaAnalyticsScrollFrame.settingsFrame, "TOP", 0, -30, "Warning! \n This will reset all match history");
    ArenaAnalyticsScrollFrame.resetBtn = core.arenaTable:CreateButton("CENTER", ArenaAnalyticsScrollFrame.settingsFrame, "CENTER", 0, -25, "Reset");
    ArenaAnalyticsScrollFrame.resetBtn:SetScript("OnClick", function (i) 
        ArenaAnalyticsDB = {}; 
        print("ArenaAnalytics match history deleted!");
        core.arenaTable:RefreshLayout(); 
    end);
    

    -- Table headers
    ArenaAnalyticsScrollFrame.dateTitle = createText(ArenaAnalyticsScrollFrame,"TOPLEFT", ArenaAnalyticsScrollFrame.export, "TOPLEFT", 5, -40, "Date");
    ArenaAnalyticsScrollFrame.mapTitle = createText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.dateTitle, "TOPLEFT", 145, 0, "Map");
    ArenaAnalyticsScrollFrame.durationTitle = createText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.mapTitle, "TOPLEFT", 60, 0, "Duration");
    ArenaAnalyticsScrollFrame.teamTitle = createText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.durationTitle, "TOPLEFT", 120, 0, "Team");
    ArenaAnalyticsScrollFrame.ratingTitle = createText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.teamTitle, "TOPLEFT", 130, 0, "Rating");
    ArenaAnalyticsScrollFrame.mmrTitle = createText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.ratingTitle, "TOPLEFT", 85, 0, "MMR");
    ArenaAnalyticsScrollFrame.enemyTeamTitle = createText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.mmrTitle, "TOPLEFT", 70, 0, "Enemy Team");
    ArenaAnalyticsScrollFrame.enemyRatingTitle = createText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.enemyTeamTitle, "TOPLEFT", 140, 0, "Enemy Rating");
    ArenaAnalyticsScrollFrame.enemyMmrTitle = createText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.enemyRatingTitle, "TOPLEFT", 125, 0, "Enemy MMR");


    -- Recorded arena number and winrate
    ArenaAnalyticsScrollFrame.totalArenaNumber = createText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame, "BOTTOMLEFT", 15, 30, "");
    ArenaAnalyticsScrollFrame.winrate = createText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.totalArenaNumber, "TOPRIGHT", 20, 0, "");
    ArenaAnalyticsScrollFrame.selectedWinrate = createText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.winrate, "TOPRIGHT", 20, 0, "Selected: (click matches to select)");
    ArenaAnalyticsScrollFrame.clearSelected = core.arenaTable:CreateButton("TOPLEFT", ArenaAnalyticsScrollFrame, "TOPRIGHT", 0, 0, "Clear selection");
    ArenaAnalyticsScrollFrame.clearSelected:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.selectedWinrate, "TOPRIGHT", 20, 5);
    ArenaAnalyticsScrollFrame.clearSelected:Hide();
    ArenaAnalyticsScrollFrame.clearSelected:SetScript("OnClick", function () core.arenaTable:ClearSelectedMatches()end)


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

    core.arenaTable:OnShow();
end

function core.arenaTable:OnShow()
    HybridScrollFrame_CreateButtons(ArenaAnalyticsScrollFrame.ListScrollFrame, "ArenaAnalyticsScrollListItem");
    core.arenaTable:RefreshLayout();
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

-- Creates a icon-based string with the match's comp with name and spec tooltips
local function setClassTextureWithTooltip(teamIconsFrames, item, itemKey, button)
    for teamIconIndex = 1, #teamIconsFrames do
        if (item[itemKey][teamIconIndex]) then
            -- Reset textures
            if (teamIconsFrames[teamIconIndex].texture) then
                teamIconsFrames[teamIconIndex].texture:SetTexture(nil)
            else
                local teamTexture = teamIconsFrames[teamIconIndex]:CreateTexture();
                teamIconsFrames[teamIconIndex].texture = teamTexture
                teamIconsFrames[teamIconIndex].texture:SetPoint("LEFT", teamIconsFrames[teamIconIndex] ,"RIGHT", -26, 0);
                teamIconsFrames[teamIconIndex].texture:SetSize(26,26)
            end
            teamIconsFrames[teamIconIndex].texture:SetTexture(item[itemKey][teamIconIndex] and item[itemKey][teamIconIndex]["classIcon"] or nil);
    
            teamIconsFrames[teamIconIndex].tooltip = ""

            local spec = item[itemKey][teamIconIndex]["spec"]
            -- Check for spec
            if (spec ~= "-") then
                addSpecFrame(button, teamIconsFrames[teamIconIndex], spec, item[itemKey][teamIconIndex]["class"])
                teamIconsFrames[teamIconIndex].tooltip = item[itemKey][teamIconIndex]["name"] .. " | " .. spec;
            else
                if (teamIconsFrames[teamIconIndex].spec) then
                    teamIconsFrames[teamIconIndex].spec = nil;
                end
                teamIconsFrames[teamIconIndex].tooltip = item[itemKey][teamIconIndex]["name"];
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
local function checkForFilterUpdate(bracket)
    local filterByBracketTable = {
        ["2v2"] = filterComps2v2_opts,
        ["3v3"] = filterComps3v3_opts,
        ["5v5"] = filterComps5v5_opts,
    }
    local frameByBracketTable = {
        ["2v2"] = ArenaAnalyticsScrollFrame.filterComps2v2,
        ["3v3"] = ArenaAnalyticsScrollFrame.filterComps3v3,
        ["5v5"] = ArenaAnalyticsScrollFrame.filterComps5v5,
    }
    local totalPlayedComps = #getPlayerPlayedComps(bracket)
    local totalCompsInFilter = #filterByBracketTable[bracket]['items']
    if (totalPlayedComps > totalCompsInFilter) then
        local info = {}
        local newComp = getPlayerPlayedComps(bracket)[totalPlayedComps];
        table.insert(filterByBracketTable[bracket]['items'], newComp)
        info.text = newComp;
        info.tooltip = ""

        local classInlineIcons = ""
        for arenaClass in string.gmatch(info.text, "([^%s]+)") do
            local arenaIconPath = ArenaAnalyticsGetClassIcon(arenaClass);
            local singleIcon = IconClass(arenaIconPath, 0, 0, 0, 0, 0, 0, 25, 25);
            classInlineIcons = classInlineIcons .. singleIcon:GetIconString() .. " ";
            info.tooltip = info.tooltip .. arenaClass .. " "
        end
        info.tooltip = info.tooltip:sub(1, -2)
        info.text = classInlineIcons .. " - " .. getCompWinrate(info.text);
        local filter = "comps" .. bracket;
        local dropdownTable = frameByBracketTable[bracket]
        local selectedWidth = frameByBracketTable[bracket].selected:GetWidth()
        local newCompButton = createDropdownButton(info, dropdownTable, filter, selectedWidth)
        table.insert(frameByBracketTable[bracket].buttons, newCompButton)
        local totalButtons = #frameByBracketTable[bracket].buttons;
        frameByBracketTable[bracket].buttons[totalButtons]:SetPoint("TOPLEFT", 0, -(totalButtons - 1) * 25)
    elseif (totalPlayedComps < totalCompsInFilter) then
         local amountToRemove = totalCompsInFilter - totalPlayedComps;
         for b = 1, amountToRemove do
            table.remove(filterByBracketTable[bracket]['items'], totalCompsInFilter - (b - 1))
            frameByBracketTable[bracket].buttons[totalCompsInFilter - (b - 1)]:Hide();
            table.remove(frameByBracketTable[bracket].buttons, totalCompsInFilter - (b - 1))
         end
    end

    -- Update winrates
    -- Check last game
    if (ArenaAnalyticsScrollFrame.items[1]) then
        local lastGame = ArenaAnalyticsScrollFrame.items[1];
        --DevTools_Dump(ArenaAnalyticsScrollFrame.items[#ArenaAnalyticsScrollFrame.items])
        local lastGameBracket = #lastGame["team"] .. "v" .. #lastGame["team"];
        local lastGameComp = table.concat(lastGame["comp"], " ");
        local updatedWinrate = getCompWinrate(lastGameComp);
    
        for i = 1, #frameByBracketTable[bracket].buttons do
            if(frameByBracketTable[bracket].buttons[i]:GetAttribute("tooltip") == lastGameComp) then
                local oldButtonValue = frameByBracketTable[bracket].buttons[i]:GetText()
                local indexOfSeparator, _ = string.find(oldButtonValue, "-")
                local compIcons = oldButtonValue:sub(1, indexOfSeparator - 1);
                local newButtonValue = compIcons .. "- " .. updatedWinrate
                frameByBracketTable[bracket].buttons[i]:SetText(newButtonValue)
                break
            end
        end
    end
end

-- Returns matches applying current match filters
local function applyFilters(unfilteredDB)

    local filteredDB = {
        ["2v2"] = {},
        ["3v3"] = {},
        ["5v5"] = {},
    };

    -- Filter map
    local arenaMaps = {{"Nagrand Arena","NA"}, {"Ruins of Lordaeron", "RoL"}, {"Blade Edge Arena", "BEA"}}
    if (currentFilters["map"] == "All") then
        filteredDB = CopyTable(unfilteredDB);
    else
        for _,arenaMap in ipairs(arenaMaps) do
            if (currentFilters["map"] == arenaMap[1]) then
                local brackets = {"2v2", "3v3", "5v5"};
                for _, bracket in ipairs(brackets) do
                    if (#unfilteredDB[bracket] > 0) then
                        for arenaNumber = 1, #unfilteredDB[bracket] do
                            if (unfilteredDB[bracket][arenaNumber]["map"] == arenaMap[2]) then
                                table.insert(filteredDB[bracket], unfilteredDB[bracket][arenaNumber]);
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
        local n2v2 = #filteredDB["2v2"];
        local n3v3 = #filteredDB["3v3"];
        local n5v5 = #filteredDB["5v5"];
        if (currentFilters["bracket"] == "2v2") then
            for arena2v2Number = n2v2, 1, - 1 do
                if (filteredDB["2v2"][arena2v2Number]) then
                    local DBCompAsString = table.concat(filteredDB["2v2"][arena2v2Number]["comp"], " ");
                    if (DBCompAsString ~= currentFilters["comps2v2"]) then
                        table.remove(filteredDB["2v2"], arena2v2Number)
                        n2v2 = n2v2 - 1
                    end
                end
            end
        end
        if (currentFilters["bracket"] == "3v3") then
        for arena3v3Number = n3v3, 1, -1 do
                if (filteredDB["3v3"][arena3v3Number]) then
                    local DBCompAsString = table.concat(filteredDB["3v3"][arena3v3Number]["comp"], " ");
                    if (DBCompAsString ~= currentFilters["comps3v3"]) then
                        table.remove(filteredDB["3v3"], arena3v3Number)
                        n3v3 = n3v3 - 1
                    end
                end
            end
        end
        if (currentFilters["bracket"] == "5v5") then
            for arena5v5Number = n5v5, 1, -1 do
                if (filteredDB["5v5"][arena5v5Number]) then
                    local DBCompAsString = table.concat(filteredDB["5v5"][arena5v5Number]["comp"], " ");
                    if (DBCompAsString ~= currentFilters["comps5v5"]) then
                        table.remove(filteredDB["5v5"], arena5v5Number)
                        n5v5 = n5v5 - 1
                    end
                end
            end
        end
    end

    
    -- Filter bracket
    if(currentFilters["bracket"] == "2v2") then
        filteredDB["3v3"] = {}
        filteredDB["5v5"] = {}
    elseif(currentFilters["bracket"] == "3v3") then
        filteredDB["2v2"] = {}
        filteredDB["5v5"] = {}
    elseif(currentFilters["bracket"] == "5v5") then
        filteredDB["3v3"] = {}
        filteredDB["2v2"] = {}
    end

    -- Filter Skirmish
    if (currentFilters["skirmishIsChecked"] == false) then
        local n2v2 = #filteredDB["2v2"];
        local n3v3 = #filteredDB["3v3"];
        local n5v5 = #filteredDB["5v5"];

        for arena2v2Number = n2v2, 1, -1 do
            if (filteredDB["2v2"][arena2v2Number]) then
                if (not filteredDB["2v2"][arena2v2Number]["isRanked"]) then
                    table.remove(filteredDB["2v2"], arena2v2Number)
                    n2v2 = n2v2 - 1
                end
            end
        end
        for arena3v3Number = n3v3, 1, -1 do
            if (filteredDB["3v3"][arena3v3Number]) then
                if (not filteredDB["3v3"][arena3v3Number]["isRanked"]) then
                    table.remove(filteredDB["3v3"], arena3v3Number)
                    n3v3 = n3v3 - 1
                end
            end
        end
        for arena5v5Number = n5v5, 1, -1 do
            if (filteredDB["5v5"][arena5v5Number]) then
                if (not filteredDB["5v5"][arena5v5Number]["isRanked"]) then
                    table.remove(filteredDB["5v5"], arena5v5Number)
                    n5v5 = n5v5 - 1
                end
            end
        end
    end

    -- Get arenas from each bracket and sort by date 
    local sortedDB = {}; 

    for b = 1, #filteredDB["2v2"] do
        table.insert(sortedDB, filteredDB["2v2"][b]);
    end
    for n = 1, #filteredDB["3v3"] do
        table.insert(sortedDB, filteredDB["3v3"][n]);
    end
    for m = 1, #filteredDB["5v5"] do
        table.insert(sortedDB, filteredDB["5v5"][m]);
    end
    
    table.sort(sortedDB, function (k1,k2)
        if (k1["dateInt"] and k2["dateInt"]) then
            return k1["dateInt"] > k2["dateInt"];
        end
        -- TODO: Remove on next version
        local date1 = ""
        local date2 = ""
        for digitDate in string.gmatch(k1["date"], "([^%s]+)") do
            if (string.find(digitDate, "/")) then
                for subDigitDate in string.gmatch(digitDate, "[^%\/]+") do
                    date1 = subDigitDate .. date1;
                end
            else
                date1 = date1 .. " " .. digitDate
            end
        end
        for digitDate2 in string.gmatch(k2["date"], "([^%s]+)") do
            if (string.find(digitDate2, "/")) then
                for subDigitDate2 in string.gmatch(digitDate2, "[^%\/]+") do
                    date2 = subDigitDate2 .. date2;
                end
            else
                date2 = date2 .. " " .. digitDate2
            end
        end
        return date1 > date2;
    end)

    return sortedDB;
end

function ArenaAnalyticsToggleSpecs(match, visible)
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


-- Refreshes matches table
function core.arenaTable:RefreshLayout()
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

    local filteredDB = applyFilters(ArenaAnalyticsDB);
    ArenaAnalyticsScrollFrame.items = filteredDB;

    local items = ArenaAnalyticsScrollFrame.items;
    local buttons = HybridScrollFrame_GetButtons(ArenaAnalyticsScrollFrame.ListScrollFrame);
    local offset = HybridScrollFrame_GetOffset(ArenaAnalyticsScrollFrame.ListScrollFrame);
    local wins = 0;

    for buttonIndex = 1, #buttons do
        local button = buttons[buttonIndex];
        local itemIndex = buttonIndex + offset;


        if itemIndex <= #items then
            local item = items[itemIndex];
            --button:SetID(itemIndex);
            button.Date:SetText(item["date"] or "");
            button.Map:SetText(item["map"] or "");
            button.Duration:SetText(item["duration"] or "");

            local teamIconsFrames = {button.Team1, button.Team2, button.Team3, button.Team4, button.Team5}
            local enemyTeamIconsFrames = {button.EnemyTeam1, button.EnemyTeam2, button.EnemyTeam3, button.EnemyTeam4, button.EnemyTeam5}
            
            local ratingPrevFrame = setClassTextureWithTooltip(teamIconsFrames, item, "team", button)
            
            -- Paint winner green, loser red
            if (item["won"]) then
                button.Rating:SetText("|cff00cc66" .. item["rating"] .. "|r");
            else
                button.Rating:SetText("|cffff0000" .. item["rating"] .. "|r");
            end

            button.MMR:SetText(item["mmr"] or "");

            local enemyRatingPrevFrame = setClassTextureWithTooltip(enemyTeamIconsFrames, item, "enemyTeam", button)
            
            button.EnemyRating:SetText(item["enemyRating"] or "");
            button.EnemyMMR:SetText(item["enemyMmr"] or "");

            
            button:SetAttribute("won", item["won"]);

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
                    core.arenaTable:UpdateSelected();
                    ArenaAnalyticsToggleSpecs(args, true)
                else
                    args:SetAttribute("clicked", false)
                    selectedGames[args.Date:GetText()] = nil;
                    args.Tooltip:Hide();
                    core.arenaTable:UpdateSelected();
                    ArenaAnalyticsToggleSpecs(args, false)
                end
            end
            )

            button:SetWidth(ArenaAnalyticsScrollFrame.ListScrollFrame.scrollChild:GetWidth());
            button:Show();
        else
            button:Hide();
        end
    end
    

    if (ArenaAnalyticsScrollFrame.filterComps2v2 == nil) then
        
        filterComps2v2_opts = {
            ['name']='Filter2v2_Comps',
            ['parent'] = ArenaAnalyticsScrollFrame,
            ['title']='Comp',
            ['hasIcon']= true,
            ['items'] = getPlayerPlayedComps("2v2"),
            ['defaultVal'] ='All'
        }

        -- TODO: make custom tailored dropdowns for comp filter
        ArenaAnalyticsScrollFrame.filterComps2v2 = createDropdown(filterComps2v2_opts)
        
        -- Set tooltip when comp is disabled
        ArenaAnalyticsScrollFrame.filterComps2v2.selected:Disable();
        ArenaAnalyticsScrollFrame.filterComps2v2.selected:SetDisabledFontObject("GameFontDisableSmall")
        ArenaAnalyticsScrollFrame.filterComps2v2.selected:SetText("Select bracket");
        ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.filterMap.dropdownFrame, "RIGHT", 15, 0);
    elseif (newArenaPlayed) then
        checkForFilterUpdate("2v2");
    end
    if (ArenaAnalyticsScrollFrame.filterComps3v3 == nil) then
        filterComps3v3_opts = {
            ['name']='Filter3v3_Comps',
            ['parent'] = ArenaAnalyticsScrollFrame,
            ['title']='Comp',
            ['hasIcon']= true,
            ['items'] = getPlayerPlayedComps("3v3"),
            ['defaultVal'] ='All'
        }
        ArenaAnalyticsScrollFrame.filterComps3v3 = createDropdown(filterComps3v3_opts)
        ArenaAnalyticsScrollFrame.filterComps3v3.dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.filterMap.dropdownFrame, "RIGHT", 15, 0);
        ArenaAnalyticsScrollFrame.filterComps3v3.dropdownFrame:Hide();
    elseif (newArenaPlayed) then
        checkForFilterUpdate("3v3");
    end
    if (ArenaAnalyticsScrollFrame.filterComps5v5 == nil) then
        filterComps5v5_opts = {
            ['name']='Filter5v5_Comps',
            ['parent'] = ArenaAnalyticsScrollFrame,
            ['title']='Comp',
            ['hasIcon']= true,
            ['items'] = getPlayerPlayedComps("5v5"),
            ['defaultVal'] ='All'
        }
        ArenaAnalyticsScrollFrame.filterComps5v5 = createDropdown(filterComps5v5_opts)
        ArenaAnalyticsScrollFrame.filterComps5v5.dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.filterMap.dropdownFrame, "RIGHT", 15, 0);
        ArenaAnalyticsScrollFrame.filterComps5v5.dropdownFrame:Hide();
    elseif (newArenaPlayed) then
        checkForFilterUpdate("5v5");
    end

    -- Adjust Team bg
    if (#items < 15) then
        local newHeight = (#items * 28) - 1;
        ArenaAnalyticsScrollFrame.teamBgT:SetHeight(newHeight);
        ArenaAnalyticsScrollFrame.teamBg:SetHeight(newHeight);
    else
        ArenaAnalyticsScrollFrame.teamBgT:SetHeight(413);
        ArenaAnalyticsScrollFrame.teamBg:SetHeight(413);
    end
    
    -- Update arena count & winrate
    for n = 1, #items do
        if(items[n]["won"]) then wins = wins + 1; end
    end

    local totalArenas = #ArenaAnalyticsScrollFrame.items;
    local winrate = totalArenas > 0 and math.floor(wins * 100 / totalArenas) or 0;
    local winsColoured =  "|cff00cc66" .. wins .. "|r";
    ArenaAnalyticsScrollFrame.totalArenaNumber:SetText("Total: " .. totalArenas .. " arenas");
    ArenaAnalyticsScrollFrame.winrate:SetText(winsColoured .. "/" .. (totalArenas - wins) .. " | " .. winrate .. "% Winrate");


    local buttonHeight = ArenaAnalyticsScrollFrame.ListScrollFrame.buttonHeight;
    local totalHeight = #items * buttonHeight;
    local shownHeight = #buttons * buttonHeight;

    -- Hide spec icons
    hideSpecIcons()

    HybridScrollFrame_Update(ArenaAnalyticsScrollFrame.ListScrollFrame, totalHeight, shownHeight);
    
end