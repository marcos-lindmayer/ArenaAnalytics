local _, ArenaAnalytics = ...;
HybridScrollMixin = {};
ArenaAnalytics.AAtable = HybridScrollMixin;

local AAtable = ArenaAnalytics.AAtable
local Filter = ArenaAnalytics.Filter;

local filteredDB = nil;

ArenaAnalytics.filteredMatchHistory = nil;

local selectedGames = {}

-- Toggles addOn view/hide
function AAtable:Toggle()
    if (not ArenaAnalyticsScrollFrame:IsShown()) then  
        AAtable:ClearSelectedMatches();
        ArenaAnalytics.AAtable:RefreshLayout(true);

        AAtable:closeFilterDropdowns();

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

-- TODO: Move to updated setup & remove this
-- Hides spec's icon on bottom-right class' icon and death highlight
local function hideSpecIconsAndDeathBg()
    if(true) then return end

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
    button:SetHeight(25);
    button:SetPoint("CENTER", dropdownTable.dropdownList);
    button:SetNormalFontObject("GameFontHighlight");
    button:SetHighlightFontObject("GameFontHighlight");
    button:SetAttribute("value", info.text);
    button:SetAttribute("dropdownTable", dropdownTable);
    button:SetScript("OnClick", function(args) ArenaAnalytics.Filter:changeFilter(args) end);

    if (info.tooltip ~= "") then
        -- Comp filter (Has icons)
        button:SetAttribute("tooltip", info.tooltip);
        button:SetHeight(27)
        if(info.text == "All" or info.textOffsetX == nil) then
            button:SetText(info.text);
        else
            button:SetText("");
            button.text = ArenaAnalyticsCreateText(button, "CENTER", button, "CENTER", info.textOffsetX, 0, info.text);
        end    
    else
        button:SetText(info.text);
    end

    return button;
end

-- Get a string representing the comp, 
function AAtable:getCompIconString(comp, priorityClass, prioritySpec)
    if(comp == nil or comp:find('|') == nil) then
        return "";
    end

    local classTable = { }

    comp:gsub("([^|]+)", function(specID)
        local class, spec = ArenaAnalytics.Constants:getClassAndSpec(specID);

        if(specID and class and spec) then
            tinsert(classTable, {specID, class, spec});
        end
    end);

    table.sort(classTable, function(a, b)
        local classA = a[2];
        local classB = b[2];

        if (priorityClass) then 
            if(classA == priorityClass) then 
                return true;
            elseif(classB == priorityClass) then
                return false;
            end
        end

        local priorityValueA = ArenaAnalytics.Constants:getSpecPriorityValue(a[1]);
        local priorityValueB = ArenaAnalytics.Constants:getSpecPriorityValue(b[1]);

        return priorityValueA > priorityValueB;
    end);

    local output = "";

    for _,entry in ipairs(classTable) do
        local class, spec = entry[2], entry[3];
        if(class and spec) then
            -- Replace with game folder icons
            local iconPath = "Interface\\AddOns\\ArenaAnalytics\\icon\\" .. class .. "\\" .. spec;
            local singleClassSpecIcon = IconClass(iconPath, 0, 0, 0, 0, 0, 0, 25, 25);
            output = output .. singleClassSpecIcon:GetIconString() .. " ";
        end
    end
    return output;
end

-- Returns a dropdown frame
-- Used for match filters
function AAtable:createDropdown(opts)
    local dropdownTable = {};
    local filterName = opts["name"];
    local dropdown_name ="$parent_" .. opts["name"] .. "_dropdown";
    local entries = opts["entries"] or {};
    local hasIcon = opts["hasIcon"];
    local title_text = opts["title"] or "";
    local dropdown_width = (filterName == "Filter_Comp" or filterName == "Filter_EnemyComp") and 250 or 0;
    local default_val = opts["defaultVal"] or "";

    local dropdown = CreateFrame("Frame", dropdown_name, opts["parent"])
    dropdownTable.dropdownFrame = dropdown;
    local dropdownList = CreateFrame("Frame", dropdown_name .. "_list", dropdownTable.dropdownFrame)
    dropdownTable.dropdownList = dropdownList
    dropdownTable.dropdownFrame:SetSize(500, 25);
    dropdownTable.dropdownList:SetPoint("TOP", dropdownTable.dropdownFrame, "BOTTOM")
    local dd_title = dropdownTable.dropdownFrame:CreateFontString(nil, 'OVERLAY')
    dd_title:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    dropdownTable.dd_title = dd_title;
    isEnemyComp, _ = string.find(opts["name"]:lower(), "enemy")
    dropdownTable.filterName = filterName;
    
    dropdownTable.dd_title:SetPoint("TOPLEFT", 0, 15)

    dropdownTable.entries = {}
    
    for _, entry in pairs(entries) do 
        local text = entry["comp"] or entry;
        dropdownTable.dd_title:SetText(text);
        local text_width = dropdownTable.dd_title:GetStringWidth() + 50
        if (text_width > dropdown_width and filterName ~= "Filter_Comp" and filterName ~= "Filter_EnemyComp") then
            dropdown_width = text_width
        end
        local info = {}
        info.text = text;
        info.tooltip = "";
        local winrate = nil;
        local totalPlayed = nil;
        if(hasIcon) then
            if(info.text ~= "All") then
                info.tooltip = entry["comp"];
                info.text = AAtable:getCompIconString(entry["comp"], not isEnemyComp and UnitClass("player") or nil);

                totalPlayed = entry["played"] or 0;
                local wins = entry["wins"] or 0;

                winrate = (totalPlayed > 0) and math.floor(wins * 100 / totalPlayed) or 0
                info.text = totalPlayed .. " " .. info.text .. " - " .. winrate .. "%";

                -- Make a temp font string to calculate width of the left and right added strings.
                local tmpWidthString = dropdownTable.dropdownFrame:CreateFontString(nil, 'OVERLAY')
                tmpWidthString:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
                tmpWidthString:SetText("- " .. winrate .. "%");
                winrateWidth = tmpWidthString:GetStringWidth();
                tmpWidthString:SetText(totalPlayed);
                totalPlayedWidth = tmpWidthString:GetStringWidth();
                tmpWidthString = nil;

                info.textOffsetX = (winrateWidth - totalPlayedWidth) / 2
            else
                info.tooltip = "All";
            end
        end

        local newEntry = createDropdownButton(info, dropdownTable, title_text, dropdown_width);
        newEntry.winrate = winrate;
        newEntry.totalPlayed = totalPlayed;
        table.insert(dropdownTable.entries, newEntry);
    end

    -- TODO: Fix sorting
    -- Order Comp filter by winrate
    if (hasIcon and #dropdownTable.entries) then
        table.sort(dropdownTable.entries, function(a,b)
            if(a and a:GetText() == "All") then
                return true;
            elseif(b and b:GetText() == "All") then
                return false;
            end

            local winrate1 = a and tonumber(a.winrate) or -1;
            local winrate2 = b and tonumber(b.winrate) or -1;
            if(winrate1 and winrate2) then
                return winrate1 > winrate2;
            end
            return winrate1 ~= nil;
        end);

        -- Remove entries with lowest priority past the limit
        local limit = tonumber(ArenaAnalyticsSettings["compsLimit"]);
        if(limit and limit > 0) then
            limit = limit + 2;
            if(#dropdownTable.entries > limit) then
                for i=#dropdownTable.entries, limit, -1 do
                    local entry = dropdownTable.entries[i]
                    if(entry ~= nil) then
                        entry:Hide();
                        entry = nil;
                    end
                    tremove(dropdownTable.entries, i);
                end
            end
        end
    end

    dropdownTable.dd_title:SetText(title_text)
    dropdownTable.dropdownList:SetSize(dropdown_width, (#dropdownTable.entries * 25));
    dropdownTable.dropdownFrame:SetWidth(dropdown_width)
    
    local totalHeight = 0;
    for i = 1, #dropdownTable.entries do
        local entry = dropdownTable.entries[i];
        totalHeight = totalHeight + entry:GetHeight();
        entry:SetPoint("TOPLEFT", 0, -(i - 1) * entry:GetHeight())
        entry:SetWidth(dropdown_width)
    end
    
    local dropdownBg = dropdownTable.dropdownFrame:CreateTexture();
    dropdownBg:SetPoint("CENTER")
    dropdownBg:SetSize(dropdown_width, 25);
    dropdownBg:SetColorTexture(0, 0, 0, 0.7);
    
    local dropdownListBg = dropdownTable.dropdownList:CreateTexture();
    dropdownListBg:SetPoint("TOP")
    dropdownListBg:SetSize(dropdown_width, totalHeight);
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
        if (not dropdownList:IsShown()) then
            ArenaAnalytics.AAtable:closeFilterDropdowns(); -- TODO: Decide if this is desirable.
            dropdownList:Show();
        else
            dropdownList:Hide();
        end
    end);

    dropdownTable.dropdownList:Hide();

    return dropdownTable;
end

-- Returns a CSV-formatted string using MatchHistoryDB info
function ArenaAnalytics:getCsvFromDB()
    if(not ArenaAnalytics:hasStoredMatches()) then
        return "No games to export!";
    end

    local CSVString = "date,map,duration,won,isRanked,team1Name,team2Name,team3Name,team4Name,team5Name,rating,mmr," .. 
    "enemyTeam1Name,enemyTeam2Name,enemyTeam3Name,enemyTeam4Name,enemyTeam5Name,enemyRating,enemyMMR" .. "\n";

    for i = 1, #MatchHistoryDB do
        local match = MatchHistoryDB[i];
        CSVString = CSVString
        .. match["date"] .. ","
        .. (match["map"] or "") .. ","
        .. (match["duration"] or "") .. ","
        .. (match["won"] and "1" or "0") .. ","
        .. (match["isRanked"] and "1" or "0") .. ","
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
        .. "\n";
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
    for index in pairs(selectedGames) do 
        if(selectedGames[index]) then
            selectedGamesCount = selectedGamesCount + 1 
            if (selectedGames[index]:GetAttribute("won")) then
                selectedWins = selectedWins + 1;
            end 
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
    ArenaAnalyticsScrollFrame.selectedStats:SetText(newSelectedText)
end

function AAtable:closeFilterDropdowns()
    if(ArenaAnalyticsScrollFrame.filterMap) then
        ArenaAnalyticsScrollFrame.filterMap.dropdownList:Hide();
    end
    if(ArenaAnalyticsScrollFrame.filterBracket) then
        ArenaAnalyticsScrollFrame.filterBracket.dropdownList:Hide();
    end
    if(ArenaAnalyticsScrollFrame.filterComps) then
        ArenaAnalyticsScrollFrame.filterComps.dropdownList:Hide();
    end
    if(ArenaAnalyticsScrollFrame.filterEnemyComps) then
        ArenaAnalyticsScrollFrame.filterEnemyComps.dropdownList:Hide();
    end
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
        ArenaAnalyticsScrollFrame.searchBox:SetText(ArenaAnalytics.Filter.currentFilters["Filter_Search"]["raw"]);
        ArenaAnalyticsScrollFrame.searchBox:ClearFocus();
    end);
        
    ArenaAnalyticsScrollFrame.searchBox:SetScript('OnTextSet', function(self) 
        if(self:GetText() == "" and ArenaAnalytics.Filter.currentFilters["Filter_Search"]["raw"] ~= "") then
            ArenaAnalytics.Filter:updateSearchFilterData("");
            self:SetText("");
        end
    end);
        
    ArenaAnalyticsScrollFrame.searchBox:SetScript('OnEditFocusLost', function() 
        -- Clear white spaces
        local search = ArenaAnalyticsScrollFrame.searchBox:GetText();

        ArenaAnalytics.Filter:updateSearchFilterData(search);

        -- Compact double spaces to single spaces in the search box
        ArenaAnalyticsScrollFrame.searchBox:SetText(ArenaAnalytics.Filter.currentFilters["Filter_Search"]["raw"]);
    end);

    local arenaBracket_opts = {
        ["name"] ='Filter_Bracket',
        ["parent"] = ArenaAnalyticsScrollFrame,
        ["title"] ='Bracket',
        ["icon"] = false,
        ["entries"] = {"All" ,'2v2', '3v3', '5v5' },
        ["defaultVal"] ="All", 
    }

    ArenaAnalyticsScrollFrame.filterBracket = AAtable:createDropdown(arenaBracket_opts)
    ArenaAnalyticsScrollFrame.filterBracket.dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.searchBox, "RIGHT", 15, 0);

    local filterMap_opts = {
        ["name"] ='Filter_Map',
        ["parent"] = ArenaAnalyticsScrollFrame,
        ["title"] ='Map',
        ["icon"] = false,
        ["entries"] = {"All" ,'Nagrand Arena' ,'Ruins of Lordaeron', 'Blade Edge Arena', 'Dalaran Arena'},
        ["defaultVal"] ="All"
    }
    
    ArenaAnalyticsScrollFrame.filterMap = AAtable:createDropdown(filterMap_opts)
    ArenaAnalyticsScrollFrame.filterMap.dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.filterBracket.dropdownFrame, "RIGHT", 15, 0);

    AAtable:forceCompFilterRefresh();

    ArenaAnalyticsScrollFrame.settingsButton = CreateFrame("Button", nil, ArenaAnalyticsScrollFrame, "GameMenuButtonTemplate");
    ArenaAnalyticsScrollFrame.settingsButton:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame, "TOPRIGHT", -46, -1);
    ArenaAnalyticsScrollFrame.settingsButton:SetText([[|TInterface\Buttons\UI-OptionsButton:0|t]]);
    ArenaAnalyticsScrollFrame.settingsButton:SetNormalFontObject("GameFontHighlight");
    ArenaAnalyticsScrollFrame.settingsButton:SetHighlightFontObject("GameFontHighlight");
    ArenaAnalyticsScrollFrame.settingsButton:SetSize(24, 19);
    ArenaAnalyticsScrollFrame.settingsButton:SetScript("OnClick", function()
        if (not ArenaAnalyticsScrollFrame.settingsFrame:IsShown()) then  
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
    ArenaAnalyticsScrollFrame.enemyMmrTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.enemyRatingTitle, "TOPLEFT", 110, 0, "Enemy Rating");

    -- Recorded arena number and winrate
    ArenaAnalyticsScrollFrame.totalArenaNumber = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "BOTTOMLEFT", ArenaAnalyticsScrollFrame, "BOTTOMLEFT", 30, 27, "");
    ArenaAnalyticsScrollFrame.winrate = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.totalArenaNumber, "TOPRIGHT", 10, 0, "");

    ArenaAnalyticsScrollFrame.sessionStats = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "BOTTOMLEFT", ArenaAnalyticsScrollFrame, "BOTTOMLEFT", 30, 10, "");

    ArenaAnalyticsScrollFrame.selectedStats = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "BOTTOMLEFT", ArenaAnalyticsScrollFrame, "BOTTOM", -70, 27, "Selected: (click matches to select)");
    --ArenaAnalyticsScrollFrame.selectedSessionStats = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "BOTTOMLEFT", ArenaAnalyticsScrollFrame, "BOTTOM", -70, 10, "Selected Session: 666/1305 | 71% Winrate");

    ArenaAnalyticsScrollFrame.unsavedWarning = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "BOTTOMRIGHT", ArenaAnalyticsScrollFrame, "BOTTOMRIGHT", -150, 13, "");
    ArenaAnalyticsScrollFrame.unsavedWarning:Hide();

    ArenaAnalyticsScrollFrame.clearSelected = AAtable:CreateButton("BOTTOMRIGHT", ArenaAnalyticsScrollFrame, "BOTTOMRIGHT", -30, 10, "Clear");
    ArenaAnalyticsScrollFrame.clearSelected:SetWidth(90)
    ArenaAnalyticsScrollFrame.clearSelected:Hide();
    ArenaAnalyticsScrollFrame.clearSelected:SetScript("OnClick", function () AAtable:ClearSelectedMatches() end);

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

    HybridScrollFrame_CreateButtons(ArenaAnalyticsScrollFrame.ListScrollFrame, "ArenaAnalyticsScrollListMatch");
    AAtable:handleArenaCountChanged();
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
    AAtable:RefreshLayout(true);
    ArenaAnalyticsScrollFrame:Hide();
end

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
    ArenaAnalyticsScrollFrame.searchBox:SetText(ArenaAnalytics.Filter.currentFilters["Filter_Search"]["raw"]);
end

local function setupTeamPlayerFrames(teamPlayerFrames, match, matchKey, scrollEntry)
    if(match == nil or match[matchKey] == nil) then
        return;
    end

    for i = 1, #teamPlayerFrames do
        local player = match[matchKey][i];
        local playerFrame = teamPlayerFrames[i];
        if (player and playerFrame) then
            local class = player["class"];
            local spec = player["spec"];

            if (playerFrame.texture == nil) then
                -- No textures? Set them
                local teamTexture = playerFrame:CreateTexture();
                playerFrame.texture = teamTexture
                playerFrame.texture:SetPoint("LEFT", playerFrame ,"RIGHT", -26, 0);
                playerFrame.texture:SetSize(26,26)
            end
            
            -- Set texture
            playerFrame.texture:SetTexture(ArenaAnalyticsGetClassIcon(class));
            playerFrame.tooltip = ""

            local playerName = player["name"] or ""

            local _, realm = UnitFullName("player");
            if(realm and playerName:find(realm)) then
                playerName = playerName:match("(.*)-");
            end

            playerFrame:SetAttribute("name", playerName);

            -- Set click to copy name
            if (playerFrame) then
                playerFrame:RegisterForClicks("LeftButtonDown", "RightButtonDown");
                playerFrame:SetScript("OnClick", function(frame, btn)
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

                    -- Include server with quick search shortcut? (Requires old data to be updated to be included)
                    if(IsShiftKeyDown()) then
                        -- Search for this player on any team
                        updateSearchForPlayer(ArenaAnalyticsScrollFrame.searchBox:GetText(), prefix, playerName);
                    else
                        -- Search for the player
                        updateSearchForPlayer("", prefix, playerName);
                    end
                end);
            end

            -- Add spec info
            if(class and spec) then
                if (playerFrame.specOverlay == nil) then
                    playerFrame.specOverlay = playerFrame:CreateTexture();
                    playerFrame.specOverlay:SetPoint("BOTTOMRIGHT", playerFrame, "BOTTOMRIGHT");
                    playerFrame.specOverlay:SetSize(12,12);
                end
                playerFrame.specOverlay:SetTexture(ArenaAnalyticsGetSpecIcon(spec, class));
                playerFrame.specOverlay:Hide();

                local tooltipSpecText = #spec > 2 and spec or class;
                local coloredSpecText = string.format("|c%s%s|r", ArenaAnalyticsGetClassColor(class), tooltipSpecText);
                playerFrame.tooltip = playerName .. " | " .. coloredSpecText;
            else
                if (playerFrame.specOverlay) then
                    playerFrame.specOverlay:SetTexture(nil);
                    playerFrame.specOverlay:Hide();
                end
                playerFrame.tooltip = playerName;
            end

            -- Add death overlay
            if (match["firstDeath"] and string.find(player["name"], match["firstDeath"])) then
                if (playerFrame.deathOverlay == nil) then
                    playerFrame.deathOverlay = playerFrame:CreateTexture();
                    playerFrame.deathOverlay:SetPoint("BOTTOMRIGHT", playerFrame, "BOTTOMRIGHT")
                    playerFrame.deathOverlay:SetSize(26,26)
                    playerFrame.deathOverlay:SetColorTexture(1, 0, 0, 0.2);
                end
                if (ArenaAnalyticsSettings["alwaysShowDeathBg"] == false) then
                    playerFrame.deathOverlay:Hide();
                end
            end

            playerFrame:Show()
        else
            playerFrame:Hide();
        end
    end
end

-- Hide/Shows Spec icons on the class' bottom-right corner
function AAtable:ToggleSpecsAndDeathBg(entry)
    local matchData = { entry:GetChildren() };
    local visible = entry:GetAttribute("clicked") or entry:GetAttribute("hovered");

    for i = 1, #matchData do
        if (matchData[i].specOverlay) then
            if (visible) then
                matchData[i].specOverlay:Show();
            else
                matchData[i].specOverlay:Hide();
            end
        end
        if (matchData[i].deathOverlay) then
            if (visible or ArenaAnalyticsSettings["alwaysShowDeathBg"]) then
                matchData[i].deathOverlay:Show();
            else
                matchData[i].deathOverlay:Hide();
            end
        end
    end
end

-- Checks if 2 arenas have the same party members
function ArenaAnalytics:arenasHaveSameParty(arena, prevArena)
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
        if (prev and (matches[i]["date"] + 3600 < prev["date"] or (not ArenaAnalytics:arenasHaveSameParty(matches[i], prev) and (matches[i]["isRated"] or prev["isRated"])))) then
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
function AAtable:createDropdownForFilterComps(isEnemyComp)
    local isDisabled = ArenaAnalytics.Filter.currentFilters["Filter_Bracket"] == "All";
    local disabledText = "Select bracket to enable filter"

    local filter = isEnemyComp and "Filter_EnemyComp" or "Filter_Comp";

    local filterCompsOpts = {
        ["name"] = filter,
        ["parent"] = ArenaAnalyticsScrollFrame,
        ["title"] = "Comp: Games | Comp | Winrate",
        ["hasIcon"]= true,
        ["entries"] = ArenaAnalytics.Filter:getPlayedCompsWithTotalAndWins(isEnemyComp),
        ["defaultVal"] = isDisabled and disabledText or ArenaAnalytics.Filter.currentFilters[filter]["display"]
    }

    if (isEnemyComp) then
        ArenaAnalyticsScrollFrame.filterEnemyComps = AAtable:createDropdown(filterCompsOpts);
        ArenaAnalyticsScrollFrame.filterEnemyComps.dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.filterComps.dropdownFrame, "RIGHT", 15, 0);

        if(isDisabled) then
            -- Set tooltip when comp is disabled
            ArenaAnalyticsScrollFrame.filterEnemyComps.dropdownList:Hide();
            ArenaAnalyticsScrollFrame.filterEnemyComps.selected:Disable();
            ArenaAnalyticsScrollFrame.filterEnemyComps.selected:SetDisabledFontObject("GameFontDisableSmall");
        end
    else
        ArenaAnalyticsScrollFrame.filterComps = AAtable:createDropdown(filterCompsOpts);
        ArenaAnalyticsScrollFrame.filterComps.dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.filterMap.dropdownFrame, "RIGHT", 15, 0);
    
        if(isDisabled) then
            -- Set tooltip when comp is disabled
            ArenaAnalyticsScrollFrame.filterComps.dropdownList:Hide();
            ArenaAnalyticsScrollFrame.filterComps.selected:Disable();
            ArenaAnalyticsScrollFrame.filterComps.selected:SetDisabledFontObject("GameFontDisableSmall");
        end
    end
end

-- Forcefully clear and recreate the comp filters for new filters. Optionally staying visible.
function AAtable:forceCompFilterRefresh(keepVisibility)
    local wasCompFilterVisible, wasEnemyCompFilterVisible = false, false

    -- Clear existing comp frame
    if(ArenaAnalyticsScrollFrame.filterComps and ArenaAnalyticsScrollFrame.filterComps.dropdownList) then
        wasCompFilterVisible = ArenaAnalyticsScrollFrame.filterComps.dropdownList:IsShown();
        ArenaAnalyticsScrollFrame.filterComps.dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterComps.dropdownFrame = nil;
    end
    ArenaAnalyticsScrollFrame.filterComps = nil;
    
    -- Clear existing enemy comp frame
    if(ArenaAnalyticsScrollFrame.filterEnemyComps ~= nil and ArenaAnalyticsScrollFrame.filterEnemyComps.dropdownList) then
        wasEnemyCompFilterVisible = ArenaAnalyticsScrollFrame.filterEnemyComps.dropdownList:IsShown();
        ArenaAnalyticsScrollFrame.filterEnemyComps.dropdownFrame:Hide();
        ArenaAnalyticsScrollFrame.filterEnemyComps.dropdownFrame = nil;
    end
    ArenaAnalyticsScrollFrame.filterComps = nil;
    
    -- Create updated frames (Friendly first!)
    AAtable:createDropdownForFilterComps(false);
    AAtable:createDropdownForFilterComps(true);

    -- Update visibility to match previous visibility, if desired
    if(keepVisibility == true) then
        if (wasCompFilterVisible == true) then
            ArenaAnalyticsScrollFrame.filterComps.dropdownList:Show();
        end

        if(wasEnemyCompFilterVisible == true) then
            ArenaAnalyticsScrollFrame.filterEnemyComps.dropdownList:Show();
        end
    end
end

-- Searches for a match by its date (unix time)
-- returns match as table and bracket as string
function AAtable:getDBMatchByDate(date)
    for i=1, #MatchHistoryDB do
        local arena = MatchHistoryDB[i];
        if(arena and arena["date"] == date) then
            return arena, arena["bracket"];
        end
    end
    return nil, nil
end

-- Returns last match played
function AAtable:getLastGame(skipSkirmish)
    for i=#MatchHistoryDB, 1, -1 do
        local match = MatchHistoryDB[i];
        if(match ~= nil and (not skipSkirmish or match["isRated"])) then
            return match;
        end
    end
    return nil;
end

local function checkUnsavedWarningThreshold()
    if(ArenaAnalytics.unsavedArenaCount >= ArenaAnalyticsSettings["unsavedWarningThreshold"]) then
        -- Show and update unsaved arena threshold
        local unsavedWarningText = "|cffff0000" .. ArenaAnalytics.unsavedArenaCount .." unsaved matches!\n |cff00cc66/reload|r |cffff0000to save!|r"
        ArenaAnalyticsScrollFrame.unsavedWarning:SetText(unsavedWarningText);
        ArenaAnalyticsScrollFrame.unsavedWarning:Show();
    else
        ArenaAnalyticsScrollFrame.unsavedWarning:Hide();
    end
end

-- Updates the displayed data for a new match
function AAtable:handleArenaCountChanged()
    AAtable:RefreshLayout(true);
    AAtable:forceCompFilterRefresh(true);

    if(ArenaAnalytics:hasStoredMatches()) then
        ArenaAnalyticsScrollFrame.exportBtn:Enable();
    else
        ArenaAnalyticsScrollFrame.exportBtn:Disable();
        ArenaAnalyticsScrollFrame.exportFrame:SetText("");
        ArenaAnalyticsScrollFrame.exportFrameContainer:Hide();
    end

    local wins = 0;
    local sessionGames = 0;
    local sessionWins = 0;

    local matches = ArenaAnalytics.filteredMatchHistory;

    -- Update arena count & winrate
    for i = 1, #ArenaAnalytics.filteredMatchHistory do
        local match = ArenaAnalytics.filteredMatchHistory[i];
        if(match) then 
            if(match["won"]) then 
                wins = wins + 1; 
            end
            
            if (match["session"] == 1 ) then
                sessionGames = sessionGames + 1;
                if (match["won"]) then
                    sessionWins = sessionWins + 1;
                end
            end
        end
    end

    local totalArenas = #ArenaAnalyticsScrollFrame.matches;
    local winrate = totalArenas > 0 and math.floor(wins * 100 / totalArenas) or 0;
    local winsColoured =  "|cff00cc66" .. wins .. "|r";
    ArenaAnalyticsScrollFrame.totalArenaNumber:SetText("Total: " .. totalArenas .. " arenas");
    ArenaAnalyticsScrollFrame.winrate:SetText(winsColoured .. "/" .. (totalArenas - wins) .. " | " .. winrate .. "% Winrate");

    local sessionStats = sessionGames > 0 and math.floor(sessionWins * 100 / sessionGames) or 0;
    local sessionWinsColoured =  "|cff00cc66" .. sessionWins .. "|r";
    ArenaAnalyticsScrollFrame.sessionStats:SetText("Current session: " .. sessionGames .. " arenas   " .. sessionWinsColoured .. "/" .. (sessionGames - sessionWins) .. " | " .. sessionStats .. "% Winrate");
end

local function ratingToText(rating, delta)
    rating = tonumber(rating);
    delta = tonumber(delta);
    if(rating ~= nil) then
        if(delta) then
            if(delta > 0) then
                delta = "+"..delta;
            end
            delta = " ("..delta..")";
        else
            delta = "";
        end
        return rating .. delta;
    end
    return nil;
end

local isRefreshing = false;
local hasPendingRefresh = true;
local hasPendingFilterRefresh = true;

-- Refreshes matches table
function AAtable:RefreshLayout(updateFilter)
    if(isRefreshing) then
        hasPendingRefresh = true;
        hasPendingFilterRefresh = updateFilter;
        return;
    end

    isRefreshing = true;
    hasPendingRefresh = false;
    hasPendingFilterRefresh = false;

    checkUnsavedWarningThreshold();

    if (updateFilter or #ArenaAnalytics.filteredMatchHistory == 0 and #MatchHistoryDB) then
        -- TODO: Optimize this across multiple frames?
        ArenaAnalytics.Filter:refreshFilters(MatchHistoryDB);
    end
    
    ArenaAnalyticsScrollFrame.matches = ArenaAnalytics.filteredMatchHistory;

    local matches = ArenaAnalyticsScrollFrame.matches;
    local buttons = HybridScrollFrame_GetButtons(ArenaAnalyticsScrollFrame.ListScrollFrame);
    local offset = HybridScrollFrame_GetOffset(ArenaAnalyticsScrollFrame.ListScrollFrame);

    for buttonIndex = 1, #buttons do
        local button = buttons[buttonIndex];
        local matchIndex = #ArenaAnalyticsScrollFrame.matches - (buttonIndex + offset - 1);

        local match = matches[matchIndex];
        if (match ~= nil) then
            setColorForSession(button, match["session"])
            button.Date:SetText(date("%d/%m/%y %H:%M:%S", match["date"]) or "");
            button.Map:SetText(match["map"] or "");
            button.Duration:SetText(SecondsToTime(match["duration"]) or "");

            local teamIconsFrames = {button.Team1, button.Team2, button.Team3, button.Team4, button.Team5}
            local enemyTeamIconsFrames = {button.EnemyTeam1, button.EnemyTeam2, button.EnemyTeam3, button.EnemyTeam4, button.EnemyTeam5}
            
            -- Setup player class frames
            setupTeamPlayerFrames(teamIconsFrames, match, "team", button);
            setupTeamPlayerFrames(enemyTeamIconsFrames, match, "enemyTeam", button);

            local enemyDelta
            -- Paint winner green, loser red
            local hex = match["won"] and "ff00cc66" or "ffff0000"
            local ratingText = ratingToText(match["rating"], match["ratingDelta"]) or "SKIRMISH";
            button.Rating:SetText("|c" .. hex .. ratingText .."|r");
            
            -- Team MMR
            button.MMR:SetText(tonumber(match["mmr"]) or "-");

            -- Enemy Rating & Delta
            local enemyRatingText = ratingToText(match["enemyRating"], match["enemyRatingDelta"]) or "-";
            button.EnemyRating:SetText(enemyRatingText);

            -- Enemy team MMR
            button.EnemyMMR:SetText(tonumber(match["enemyMmr"]) or "-");
            
            button:SetAttribute("won", match["won"]);

            if (selectedGames[matchIndex]) then
                button:SetAttribute("clicked", true)
                button.Tooltip:Show()
            else
                button:SetAttribute("clicked", false)
                button.Tooltip:Hide()
            end

            button:SetScript("OnEnter", function(self)
                self:SetAttribute("hovered", true);
                AAtable:ToggleSpecsAndDeathBg(self);
            end);

            button:SetScript("OnLeave", function(self) 
                self:SetAttribute("hovered", false);
                AAtable:ToggleSpecsAndDeathBg(self);
            end);
            
            button:SetScript("OnClick", function (self)
                if (self:GetAttribute("clicked")) then
                    self:SetAttribute("clicked", false)
                    selectedGames[matchIndex] = nil;
                    self.Tooltip:Hide();
                    AAtable:UpdateSelected();
                    AAtable:ToggleSpecsAndDeathBg(self);
                else
                    self:SetAttribute("clicked", true)
                    self.Tooltip:Show();
                    selectedGames[matchIndex] = self;
                    AAtable:UpdateSelected();
                    AAtable:ToggleSpecsAndDeathBg(self);
                end
            end);

            AAtable:ToggleSpecsAndDeathBg(button);

            button:SetWidth(ArenaAnalyticsScrollFrame.ListScrollFrame.scrollChild:GetWidth());
            button:Show();
        else
            button:Hide();
        end
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

    -- TODO: Optimize
    -- Hide spec icons
    hideSpecIconsAndDeathBg()

    local buttonHeight = ArenaAnalyticsScrollFrame.ListScrollFrame.buttonHeight;
    local totalHeight = #matches * buttonHeight;
    local shownHeight = #buttons * buttonHeight;
    HybridScrollFrame_Update(ArenaAnalyticsScrollFrame.ListScrollFrame, totalHeight, shownHeight);

    -- Run pending refresh next frame
    if(hasPendingRefresh) then
        C_Timer.After(1, function() AAtable:RefreshLayout(hasPendingFilterRefresh) end);
    else
        isRefreshing = false;
    end
end