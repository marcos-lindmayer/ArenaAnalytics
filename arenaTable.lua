local _, ArenaAnalytics = ...;
HybridScrollMixin = {};
ArenaAnalytics.AAtable = HybridScrollMixin;

local AAtable = ArenaAnalytics.AAtable
local Filter = ArenaAnalytics.Filter;

local filteredDB = nil;

local totalArenas = #ArenaAnalyticsDB["2v2"] + #ArenaAnalyticsDB["3v3"] + #ArenaAnalyticsDB["5v5"] 
function AAtable:resetTotalArenas()
    totalArenas = 0;
end

local selectedGames = {}

-- Toggles addOn view/hide
function AAtable:Toggle()
    if not ArenaAnalyticsScrollFrame:IsShown() then  
        AAtable:ClearSelectedMatches();
        ArenaAnalytics.AAtable:RefreshLayout(true);
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

-- Hides spec's icon on bottom-right class' icon and death highlight
local function hideSpecIconsAndDeathBg()
    for specIconNumber = 1, #ArenaAnalyticsScrollFrame.specFrames do
        if (not ArenaAnalyticsScrollFrame.specFrames[specIconNumber][2]:GetAttribute("clicked")) then
            ArenaAnalyticsScrollFrame.specFrames[specIconNumber][1]:Hide()
        else
            ArenaAnalyticsScrollFrame.specFrames[specIconNumber][1]:Show()
        end
    end
    for deathIconNumber = 1, #ArenaAnalyticsScrollFrame.deathFrames do
        if (not ArenaAnalyticsScrollFrame.deathFrames[deathIconNumber][2]:GetAttribute("clicked") and ArenaAnalyticsSettings["alwaysShowDeathBg"] == false) then
            ArenaAnalyticsScrollFrame.deathFrames[deathIconNumber][1]:Hide()
        else
            ArenaAnalyticsScrollFrame.deathFrames[deathIconNumber][1]:Show()
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
    hideSpecIconsAndDeathBg()
    selectedGames = {}
    AAtable:UpdateSelected()
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
    button:SetScript("OnClick", function(args) ArenaAnalytics.Filter:changeFilter(args) end);
    return button;
end

-- Returns button string (icons) and tooltip for comp filter
local function setIconsOnCompFilter(itext, itooltip, isEnemyComp, games) 
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
        --TODO: Add preg
        inlineIcons = inlineIcons .. singleClassSpecIcon:GetIconString() .. " ";
        infoTooltip = infoTooltip .. arenaClass .. "|" .. arenaSpec .."-"
    end
    infoTooltip = infoTooltip:sub(1, -2)
    infoText = ArenaAnalytics.Filter:getCompTotalGames(infoText, isEnemyComp, games) .. " " .. inlineIcons .. " - " .. ArenaAnalytics.Filter:getCompWinrate(infoText, isEnemyComp, games);
    return infoText, infoTooltip;
end

-- Returns a dropdown frame
-- Used for match filters
function AAtable:createDropdown(opts)
    local dropdownTable = {};
    local dropdown_name ='$parent_' .. opts['name'] .. '_dropdown';
    local menu_matches = opts['matches'] or {};
    local games = opts['games'] or {};
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
    
    dropdownTable.dd_title:SetPoint("TOPLEFT", 0, 15)

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
            info.text, info.tooltip = setIconsOnCompFilter(info.text, info.tooltip, isEnemyComp, games)
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
    end);

    dropdownTable.dropdownList:Hide();

    return dropdownTable
end


-- Returns a CSV-formatted string using ArenaAnalyticsDB info
function ArenaAnalytics:getCsvFromDB()
    if(not ArenaAnalytics:hasStoredMatches()) then
        return "";
    end

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
        local match = allArenas[arenaN];
        
        local arenaDateString = date("%d/%m/%y %H:%M:%S", match["dateInt"]);
        CSVString = CSVString 
        .. arenaDateString .. ","
        .. (match["map"] or "??") .. ","
        .. (match["duration"] or "") .. ","
        .. (match["won"] and "yes" or "no") .. ","
        .. (match["isRanked"] and "yes" or "no") .. ","
        .. (match["team"][1]["name"] or "") .. ","
        .. (match["team"][2] and match["team"][2]["name"] or "") .. ","
        .. (match["team"][3] and match["team"][3]["name"] or "") .. ","
        .. (match["team"][4] and match["team"][4]["name"] or "") .. ","
        .. (match["team"][5] and match["team"][5]["name"] or "") .. ","
        .. (match["rating"] or "").. ","
        .. (match["mmr"] or "") .. ","
        .. (match["enemyTeam"][1] and match["enemyTeam"][1]["name"] or "") .. ","
        .. (match["enemyTeam"][2] and match["enemyTeam"][2]["name"] or "") .. ","
        .. (match["enemyTeam"][3] and match["enemyTeam"][3]["name"] or "") .. ","
        .. (match["enemyTeam"][4] and match["enemyTeam"][4]["name"] or "") .. ","
        .. (match["enemyTeam"][5] and match["enemyTeam"][5]["name"] or "") .. ","
        .. (match["enemyRating"] or "") .. ","
        .. (match["enemyMmr"] or "") .. ","
        CSVString = CSVString .. "\n";
    end
    return CSVString;
end

-- Returns string frame
function ArenaAnalyticsCreateText(relativeFrame, anchor, refFrame, relPoint, xOff, yOff, text)
    local fontString = relativeFrame:CreateFontString(nil, "OVERLAY");
    fontString:SetFont("Fonts\\FRIZQT__.TTF", 12, "");
    fontString:SetPoint(anchor, refFrame, relPoint, xOff, yOff);
    fontString:SetText(text);
    return fontString
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

    ArenaAnalyticsScrollFrame.searchBox = CreateFrame("EditBox", "searchBox", ArenaAnalyticsScrollFrame, "SearchBoxTemplate")
    ArenaAnalyticsScrollFrame.searchBox:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame, "TOPLEFT", 30, -27);
    ArenaAnalyticsScrollFrame.searchBox:SetSize(155, 55);
    ArenaAnalyticsScrollFrame.searchBox:SetAutoFocus(false);
    ArenaAnalyticsScrollFrame.searchBox:SetMaxBytes(513);

    ArenaAnalyticsScrollFrame.searchTitle = ArenaAnalyticsScrollFrame.searchBox:CreateFontString(nil, 'OVERLAY');
    ArenaAnalyticsScrollFrame.searchTitle:SetPoint("TOPLEFT", -4, 0);
    ArenaAnalyticsScrollFrame.searchTitle:SetFont("Fonts\\FRIZQT__.TTF", 12, "");
    ArenaAnalyticsScrollFrame.searchTitle:SetText("Player Search");

    ArenaAnalyticsScrollFrame.searchBox:SetScript('OnEnterPressed', function()
        ArenaAnalyticsScrollFrame.searchBox:ClearFocus();
    end);

    ArenaAnalyticsScrollFrame.searchBox:SetScript('OnEscapePressed', function() 
        ArenaAnalyticsScrollFrame.searchBox:SetText(ArenaAnalytics.Filter.currentFilters["search"]["raw"]);
        ArenaAnalyticsScrollFrame.searchBox:ClearFocus();
    end);
        
    ArenaAnalyticsScrollFrame.searchBox:SetScript('OnTextSet', function(self) 
        if(self:GetText() == "" and currentFilters["search"]["raw"] ~= "") then
            ArenaAnalytics:updateSearchFilterData("");
            self:SetText("");
        end
    end);
        
    ArenaAnalyticsScrollFrame.searchBox:SetScript('OnEditFocusLost', function() 
        -- Clear white spaces
        local search = ArenaAnalyticsScrollFrame.searchBox:GetText();

        ArenaAnalytics.Filter:updateSearchFilterData(search);

        -- Compact double spaces to single spaces in the search box
        ArenaAnalyticsScrollFrame.searchBox:SetText(ArenaAnalytics.Filter.currentFilters["search"]["raw"]);
    end);

    local arenaBracket_opts = {
        ['name']='Arena_Bracket',
        ['parent'] = ArenaAnalyticsScrollFrame,
        ['title']='Bracket',
        ['icon']= false,
        ['matches'] = {'All' ,'2v2', '3v3', '5v5' },
        ['defaultVal'] ='All', 
    }

    ArenaAnalyticsScrollFrame.arenaTypeMenu = AAtable:createDropdown(arenaBracket_opts)
    ArenaAnalyticsScrollFrame.arenaTypeMenu.dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.searchBox, "RIGHT", 15, 0);

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
    ArenaAnalyticsScrollFrame.settingsButton:SetScript("OnClick", function()
        if not  ArenaAnalyticsScrollFrame.settingsFrame:IsShown() then  
            ArenaAnalyticsScrollFrame.settingsFrame:Show();
            ArenaAnalyticsScrollFrame.allowReset:SetChecked(false);
            ArenaAnalyticsScrollFrame.resetBtn:Disable();
        else
            ArenaAnalyticsScrollFrame.settingsFrame:Hide();
        end
    end);

    -- Settings window
    ArenaAnalyticsSettingsFrame()    

    -- Table headers
    ArenaAnalyticsScrollFrame.dateTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame,"TOPLEFT", ArenaAnalyticsScrollFrame.searchBox, "TOPLEFT", -5, -47, "Date");
    ArenaAnalyticsScrollFrame.mapTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.dateTitle, "TOPLEFT", 145, 0, "Map");
    ArenaAnalyticsScrollFrame.durationTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.mapTitle, "TOPLEFT", 60, 0, "Duration");
    ArenaAnalyticsScrollFrame.teamTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.durationTitle, "TOPLEFT", 118, 0, "Team");
    ArenaAnalyticsScrollFrame.ratingTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.teamTitle, "TOPLEFT", 132, 0, "Rating");
    ArenaAnalyticsScrollFrame.mmrTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.ratingTitle, "TOPLEFT", 88, 0, "MMR");
    ArenaAnalyticsScrollFrame.enemyTeamTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.mmrTitle, "TOPLEFT", 67, 0, "Enemy Team");
    ArenaAnalyticsScrollFrame.enemyRatingTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.enemyTeamTitle, "TOPLEFT", 141, 0, "Enemy MMR");
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

    -- First time user import popup if no matches are stored
    AAtable:tryShowimportFrame();

    -- Add esc to close frame
    _G["ArenaAnalyticsScrollFrame"] = ArenaAnalyticsScrollFrame 
    tinsert(UISpecialFrames, ArenaAnalyticsScrollFrame:GetName()) 

    -- Make frame draggable
    ArenaAnalyticsScrollFrame:SetMovable(true)
    ArenaAnalyticsScrollFrame:EnableMouse(true)
    ArenaAnalyticsScrollFrame:RegisterForDrag("LeftButton")
    ArenaAnalyticsScrollFrame:SetScript("OnDragStart", ArenaAnalyticsScrollFrame.StartMoving)
    ArenaAnalyticsScrollFrame:SetScript("OnDragStop", ArenaAnalyticsScrollFrame.StopMovingOrSizing)
    ArenaAnalyticsScrollFrame:SetScript("OnHide", function()
		ArenaAnalyticsScrollFrame.allowReset:SetChecked(false);
		ArenaAnalyticsScrollFrame.resetBtn:Disable();
    end);

    ArenaAnalyticsScrollFrame:SetScript("OnShow", function()
		ArenaAnalyticsScrollFrame.allowReset:SetChecked(false);
		ArenaAnalyticsScrollFrame.resetBtn:Disable();
        AAtable:tryShowimportFrame();
    end);

    ArenaAnalyticsScrollFrame.specFrames = {}
    ArenaAnalyticsScrollFrame.deathFrames = {}

    AAtable:OnShow();
end

function AAtable:tryShowimportFrame()
    if (not ArenaAnalytics:hasStoredMatches()) then
        if(ArenaAnalyticsScrollFrame.importFrame == nil) then
            ArenaAnalyticsScrollFrame.importFrame = CreateFrame("Frame", nil, ArenaAnalyticsScrollFrame, "BasicFrameTemplateWithInset")
            ArenaAnalyticsScrollFrame.importFrame:SetPoint("CENTER")
            ArenaAnalyticsScrollFrame.importFrame:SetSize(475, 150)
            ArenaAnalyticsScrollFrame.importFrame:SetFrameStrata("HIGH");
            ArenaAnalyticsScrollFrame.importFrametitle = ArenaAnalyticsScrollFrame.importFrame:CreateFontString(nil, "OVERLAY");
            ArenaAnalyticsScrollFrame.importFrametitle:SetPoint("TOP", ArenaAnalyticsScrollFrame.importFrame, "TOP", -10, -5);
            ArenaAnalyticsScrollFrame.importFrametitle:SetFont("Fonts\\FRIZQT__.TTF", 12, "");
            ArenaAnalyticsScrollFrame.importFrametitle:SetText("Import from ArenaStats");
            ArenaAnalyticsScrollFrame.importDataText1 = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.importFrame, "CENTER", ArenaAnalyticsScrollFrame.importFrame, "TOP", 0, -45, "Paste the ArenaStats export on the text box below.");
            ArenaAnalyticsScrollFrame.importDataText2 = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.importFrame, "CENTER", ArenaAnalyticsScrollFrame.importFrame, "TOP", 0, -60, "Note: ArenaStats data won't be available for comp filters.");
                
            ArenaAnalyticsScrollFrame.importDataBtn = ArenaAnalytics.AAtable:CreateButton("TOPRIGHT", ArenaAnalyticsScrollFrame.importFrame, "TOPRIGHT", -70, -80, "Import");
            ArenaAnalyticsScrollFrame.importDataBtn:SetSize(115, 25)
            ArenaAnalyticsScrollFrame.importDataBtn:SetDisabledFontObject("GameFontDisableSmall")
            
            ArenaAnalyticsScrollFrame.importDataBox = CreateFrame("EditBox", "exportFrameScroll", ArenaAnalyticsScrollFrame.importDataBtn, "InputBoxTemplate")
            ArenaAnalyticsScrollFrame.importDataBox:SetPoint("RIGHT", ArenaAnalyticsScrollFrame.importDataBtn, "LEFT", -10, 0);
            ArenaAnalyticsScrollFrame.importDataBox:SetFrameStrata("HIGH");
            ArenaAnalyticsScrollFrame.importDataBox:SetSize(213, 55);
            ArenaAnalyticsScrollFrame.importDataBox:SetAutoFocus(false);
            ArenaAnalyticsScrollFrame.importDataBox:SetMaxBytes(50);

            ArenaAnalyticsScrollFrame.importDataText3 = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.importFrame, "CENTER", ArenaAnalyticsScrollFrame.importFrame, "BOTTOM", 0, 25, "|cffff0000Do this NOW|r You won't be able to do this while you have stored arenas!");

            
            local pasteBuffer, lastPasteTime, index = {}, 0, 0;

            local function onCharAdded(self, c)
                if(ArenaAnalyticsScrollFrame.importDataBox:IsEnabled()) then
                    ArenaAnalyticsScrollFrame.importDataBox:Disable();
                    pasteBuffer, index = {}, 0;

                    ArenaAnalyticsScrollFrame.importDataBox:SetScript('OnChar', nil);
                    ArenaAnalyticsScrollFrame.importDataBox:SetText("");
                    ArenaAnalyticsScrollFrame.importDataBox:SetScript('OnChar', onCharAdded);

                    C_Timer.After(0, function()
                        ArenaAnalyticsScrollFrame.importDataBox:Enable();
                        ArenaImportPasteString = string.trim(table.concat(pasteBuffer));
                        pasteBuffer = {}
                        index = 0;

                        -- Update text: 1) Prevent OnChar for changing text
                        ArenaAnalyticsScrollFrame.importDataBox:SetScript('OnChar', nil);
                        ArenaAnalyticsScrollFrame.importDataBox:SetText(ArenaAnalytics.AAimport:determineImportSource(ArenaImportPasteString) .. " import detected...");
                        ArenaAnalyticsScrollFrame.importDataBox:SetScript('OnChar', onCharAdded);
                    end);
                end

                index = index + 1;
                pasteBuffer[index] = c;
            end

            ArenaAnalyticsScrollFrame.importDataBox:SetScript('OnChar', onCharAdded);
            ArenaAnalyticsScrollFrame.importDataBox:SetScript('OnEditFocusGained', function()
                ArenaAnalyticsScrollFrame.importDataBox:HighlightText();
            end);

            ArenaAnalyticsScrollFrame.importDataBtn:SetScript("OnClick", function (i) 
                ArenaAnalyticsScrollFrame.importDataBtn:Disable();
                ArenaAnalytics.AAimport:parseRawData(ArenaImportPasteString);
                ArenaImportPasteString = "";
            end);

            ArenaAnalyticsScrollFrame.importDataBox:SetScript("OnEnterPressed", function(self)
                self:ClearFocus();
            end);
            ArenaAnalyticsScrollFrame.importDataBox:SetScript("OnEscapePressed", function(self)
                self:ClearFocus();
            end);
        end

        ArenaAnalyticsScrollFrame.importDataBtn:Enable();
        ArenaAnalyticsScrollFrame.importFrame:Show();
    end
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

---TODO: Consider removing. No longer used. (Replaced by search box)
-- Displayes a small window with the clicked player's name
-- for easy copy/paste
local function showClickedName(classFrame)
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

            local playerName = match[matchKey][teamIconIndex] and match[matchKey][teamIconIndex]["name"] or ""
            teamIconsFrames[teamIconIndex]:SetAttribute("name", playerName)

            local function updateSearchForPlayer(previousSearch, prefix, search)
                previousSearch = previousSearch or "";
                search = search or "";

                local newSearch = prefix .. search;
                local existingSearch = search:gsub("-", "%%-");
                if(previousSearch ~= "" and previousSearch:find(search:gsub("-", "%%-")) ~= nil) then
                    -- Clear existing prefix
                    previousSearch = previousSearch:gsub("-"..existingSearch, search);
                    previousSearch = previousSearch:gsub("+"..existingSearch, search);

                    newSearch = previousSearch:gsub(existingSearch, newSearch);
                else
                    if(previousSearch ~= "" and previousSearch:sub(-1) ~= '|') then
                        previousSearch = previousSearch .. ", ";
                    end
                    
                    newSearch = previousSearch .. newSearch;
                end
                
                ArenaAnalytics.Filter:updateSearchFilterData(newSearch);
                ArenaAnalyticsScrollFrame.searchBox:SetText(ArenaAnalytics.Filter.currentFilters["search"]["raw"]);
            end

            -- Set click to copy name
            if (teamIconsFrames[teamIconIndex]) then
                teamIconsFrames[teamIconIndex]:RegisterForClicks("LeftButtonDown", "RightButtonDown");
                teamIconsFrames[teamIconIndex]:SetScript("OnClick", function(frame, btn)
                    -- Specify explicit team prefix for search
                    local prefix = '';
                    if(IsControlKeyDown()) then
                        -- Search for this player on your team
                        prefix = '+';
                    elseif(IsAltKeyDown()) then
                        -- Search for this player on enemy team
                        prefix = '-'
                    elseif (btn == "RightButton") then
                        prefix = matchKey == "team" and '+' or '-';                        
                    end

                    if(IsShiftKeyDown()) then
                        -- Search for this player on any team
                        updateSearchForPlayer(ArenaAnalyticsScrollFrame.searchBox:GetText(), prefix, playerName);
                    else
                        -- Search for the player
                        updateSearchForPlayer("", prefix, playerName);
                    end
                end);
            end

            -- Add tooltip with player name and class colored spec/class
            local spec = match[matchKey][teamIconIndex]["spec"]
            local class = match[matchKey][teamIconIndex]["class"];
            ForceDebugNilError(class);
            if (class ~= nil and spec ~= nil) then
                addSpecFrame(button, teamIconsFrames[teamIconIndex], spec, class);
                local tooltipSpecText = #spec > 2 and spec or class;
                local coloredSpecText = string.format("|c%s%s|r", ArenaAnalyticsGetClassColor(class):upper(), tooltipSpecText);
                teamIconsFrames[teamIconIndex].tooltip = match[matchKey][teamIconIndex]["name"] .. " | " .. coloredSpecText;
            else
                if (teamIconsFrames[teamIconIndex].spec) then
                    teamIconsFrames[teamIconIndex].spec = nil;
                end
                teamIconsFrames[teamIconIndex].tooltip = match[matchKey][teamIconIndex]["name"];
            end

            -- Check if first to die
            if (teamIconsFrames[teamIconIndex].death) then
                teamIconsFrames[teamIconIndex].death.texture:SetTexture(nil);
            end
            if (match["firstDeath"] and string.find(match[matchKey][teamIconIndex]["name"], match["firstDeath"])) then
                local deathFrame = CreateFrame("Frame", nil, teamIconsFrames[teamIconIndex])
                teamIconsFrames[teamIconIndex].death = deathFrame;
                teamIconsFrames[teamIconIndex].death:SetPoint("BOTTOMRIGHT", teamIconsFrames[teamIconIndex], "BOTTOMRIGHT")
                teamIconsFrames[teamIconIndex].death:SetSize(26,26)
                local deathTexture = teamIconsFrames[teamIconIndex].death:CreateTexture()
                teamIconsFrames[teamIconIndex].death.texture = deathTexture;
                teamIconsFrames[teamIconIndex].death.texture:SetPoint("CENTER")
                teamIconsFrames[teamIconIndex].death.texture:SetSize(26,26)
                teamIconsFrames[teamIconIndex].death.texture:SetColorTexture(1, 0, 0, 0.2);
                if (ArenaAnalyticsSettings["alwaysShowDeathBg"] == false) then
                    teamIconsFrames[teamIconIndex].death:Hide();
                end
                table.insert(ArenaAnalyticsScrollFrame.deathFrames, {teamIconsFrames[teamIconIndex].death, button})  
            end
            teamIconsFrames[teamIconIndex]:Show()
        else
            teamIconsFrames[teamIconIndex]:Hide()
        end
    end
end

-- Hide/Shows Spec icons on the class' bottom-right corner
function AAtable:ToggleSpecsAndDeathBg(match, visible)
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
        if (matchData[i].death) then
            if (visible) then
                matchData[i].death:Show();
            elseif (match:GetAttribute("clicked")) then
                matchData[i].death:Show();
            else
                matchData[i].death:Hide();
            end
        end
        if (matchData[i].death and ArenaAnalyticsSettings["alwaysShowDeathBg"]) then
            matchData[i].death:Show();
        end
    end
end

-- Checks if 2 arenas have the same party members
local function arenasHaveSameParty(arena, prevArena)
    if(arena["bracket"] ~= prevArena["bracket"]) then
        return false;
    end

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
    ArenaAnalytics.Filter.filterCompsOpts[bracket] = {
        ['name']='Filter' .. bracket .. '_Comps',
        ['parent'] = ArenaAnalyticsScrollFrame,
        ['title']='Comp: Games | Comp | Winrate',
        ['hasIcon']= true,
        ['matches'] = ArenaAnalytics.Filter:getPlayerPlayedCompsAndGames(bracket, nil)[1],
        ['games'] = ArenaAnalytics.Filter:getPlayerPlayedCompsAndGames(bracket, nil)[2],
        ['defaultVal'] ='All'
    }

    ArenaAnalyticsScrollFrame.filterComps[bracket] = AAtable:createDropdown(ArenaAnalytics.Filter.filterCompsOpts[bracket])
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
    ArenaAnalytics.Filter.filterEnemyCompsOpts[bracket] = {
        ['name']='Filter' .. bracket .. '_EnemyComps',
        ['parent'] = ArenaAnalyticsScrollFrame,
        ['title']='Enemy Comp: Games | Comp | Winrate',
        ['hasIcon']= true,
        ['matches'] = ArenaAnalytics.Filter:getEnemyPlayedCompsAndGames(bracket, nil)[1],
        ['games'] = ArenaAnalytics.Filter:getEnemyPlayedCompsAndGames(bracket, nil)[2],
        ['defaultVal'] ='All'
    }

    ArenaAnalyticsScrollFrame.filterEnemyComps[bracket] = AAtable:createDropdown(ArenaAnalytics.Filter.filterEnemyCompsOpts[bracket])
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

-- Returns array of last game played
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
function AAtable:RefreshLayout(updateFilter)
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

    if(ArenaAnalytics:hasStoredMatches()) then
        ArenaAnalyticsScrollFrame.exportBtn:Enable();
    else
        ArenaAnalyticsScrollFrame.exportBtn:Disable();
        ArenaAnalyticsScrollFrame.exportFrame:SetText("");
        ArenaAnalyticsScrollFrame.exportFrameContainer:Hide();
    end
    
    local lastGame = AAtable:getLastGame()
    
    if (updateFilter or filteredDB == nil or newArenaPlayed) then
        filteredDB = ArenaAnalytics.Filter:applyFilters(ArenaAnalyticsDB);
    end
    
    ArenaAnalyticsScrollFrame.matches = filteredDB;

    local matches = ArenaAnalyticsScrollFrame.matches;
    local buttons = HybridScrollFrame_GetButtons(ArenaAnalyticsScrollFrame.ListScrollFrame);
    local offset = HybridScrollFrame_GetOffset(ArenaAnalyticsScrollFrame.ListScrollFrame);
    local wins = 0;

    setSessions(matches)

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
                AAtable:ToggleSpecsAndDeathBg(args, true)
            end)
            button:SetScript("OnLeave", function (args)
                AAtable:ToggleSpecsAndDeathBg(args, false)
            end)
            local teamIconsFrames = {button.Team1, button.Team2, button.Team3, button.Team4, button.Team5}
            local enemyTeamIconsFrames = {button.EnemyTeam1, button.EnemyTeam2, button.EnemyTeam3, button.EnemyTeam4, button.EnemyTeam5}
            
            setClassTextureWithTooltip(teamIconsFrames, match, "team", button)
            local enemyDelta
            -- Paint winner green, loser red 
            if (match["won"]) then
                local delta = (match["ratingDelta"] and match["ratingDelta"] ~= "") and " (+" .. match["ratingDelta"] .. ")" or ""
                enemyDelta = (match["enemyRatingDelta"] and match["enemyRatingDelta"] ~= "") and " (-" .. match["enemyRatingDelta"] .. ")" or ""
                if (match["rating"]) then
                    button.Rating:SetText("|cff00cc66" .. match["rating"] .. delta .. "|r");
                end
            else
                local delta = (match["ratingDelta"] and match["ratingDelta"] ~= "") and " (" .. match["ratingDelta"] .. ")" or ""
                enemyDelta = (match["enemyRatingDelta"] and match["enemyRatingDelta"] ~= "") and " (+" .. match["enemyRatingDelta"] .. ")" or ""
                if (match["rating"]) then
                    button.Rating:SetText("|cffff0000" .. match["rating"] .. delta .."|r");
                end                
            end

            button.MMR:SetText(match["mmr"] or "");

            setClassTextureWithTooltip(enemyTeamIconsFrames, match, "enemyTeam", button)
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
                    AAtable:ToggleSpecsAndDeathBg(args, true)
                else
                    args:SetAttribute("clicked", false)
                    selectedGames[args.Date:GetText()] = nil;
                    args.Tooltip:Hide();
                    AAtable:UpdateSelected();
                    AAtable:ToggleSpecsAndDeathBg(args, false)
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
    hideSpecIconsAndDeathBg()

    HybridScrollFrame_Update(ArenaAnalyticsScrollFrame.ListScrollFrame, totalHeight, shownHeight);
end