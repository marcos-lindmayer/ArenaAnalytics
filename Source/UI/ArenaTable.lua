local _, ArenaAnalytics = ...; -- Addon Namespace
local AAtable = ArenaAnalytics.AAtable;
HybridScrollMixin = ArenaAnalytics.AAtable; -- HybridScroll.xml wants access to this

-- Local module aliases
local Options = ArenaAnalytics.Options;
local Filters = ArenaAnalytics.Filters;
local Search = ArenaAnalytics.Search;

-------------------------------------------------------------------------

local hasLoaded = false;

local bottomStatsPrefixColor = "FF909090"
local function colorText(text, color)
    text = text or "";
    color = color or "FFFFFFFF";

    return "|c" .. color .. text .. "|r"
end

-- Filtered stats
local wins, sessionGames, sessionWins = 0, 0, 0;

-- Toggles addOn view/hide
function ArenaAnalytics:Toggle()
    if (not ArenaAnalyticsScrollFrame:IsShown()) then  
        ArenaAnalytics.Selection:ClearSelectedMatches();
        Filters:RefreshFilters(function()
            AAtable:RefreshLayout();
        end);

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
    btn:SetDisabledFontObject("GameFontDisableSmall");
    return btn;
end

-- TODO: Prioritize spec too
-- Get a string representing the comp, 
function AAtable:getCompIconString(comp, isPlayerPriority)
    if(comp == nil or comp:find('|') == nil) then
        return "";
    end

    local myClass, mySpec;
    if(isPlayerPriority) then
        myClass = UnitClass("player");
        mySpec = ArenaAnalytics.API:GetMySpec();
    end

    local classTable = { }

    comp:gsub("([^|]+)", function(specID)
        local class, spec = ArenaAnalytics.Constants:getClassAndSpec(specID);

        if(specID and class and spec) then
            tinsert(classTable, {specID, class, spec});
        end
    end);

    table.sort(classTable, function(a, b)
        local classA, classB = a[2], b[2];
        local specA, specB = a[3], b[3];

        if(isPlayerPriority) then
            if(myClass) then
                local priorityA = (classA == myClass) and 1 or 0;
                local priorityB = (classB == myClass) and 1 or 0;

                if(mySpec) then
                    priorityA = priorityA + ((specA == mySpec) and 2 or 0);
                    priorityB = priorityB + ((specB == mySpec) and 2 or 0);
                end

                return priorityA > priorityB;
            end


            if (myClass) then 
                if(classA == myClass) then 
                    return true;
                elseif(classB == myClass) then
                    return false;
                end
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
            output = output .. singleClassSpecIcon:GetIconString();
        end
    end
    return output;
end

-- Returns string frame
function ArenaAnalyticsCreateText(relativeFrame, anchor, refFrame, relPoint, xOff, yOff, text, fontSize)
    local fontString = relativeFrame:CreateFontString(nil, "OVERLAY");
    fontString:SetFont("Fonts\\FRIZQT__.TTF", fontSize or 12, "");
    fontString:SetPoint(anchor, refFrame, relPoint, xOff, yOff);
    fontString:SetText(text);
    return fontString
end

function AAtable:UpdateSelected()
    if(not hasLoaded) then
        -- Load will trigger call soon
        return;
    end
    
    local newSelectedText = ""
    local selectedGamesCount, selectedWins = 0, 0;
    
    local deselectedCache = ArenaAnalytics.Selection.latestDeselect;
    local selectedTables = { ArenaAnalytics.Selection.latestMultiSelect, ArenaAnalytics.Selection.selectedGames }

    -- Merge the selected tables to prevent duplicates, excluding deselected
    local uniqueSelected = {}
    for _, selectedTable in ipairs(selectedTables) do
        for index in pairs(selectedTable) do 
            if (not deselectedCache[index]) then
                uniqueSelected[index] = true;
            end
        end
    end

    for index in pairs(uniqueSelected) do
        if(ArenaAnalytics:GetFilteredMatch(index)) then
            selectedGamesCount = selectedGamesCount + 1;
            if (ArenaAnalytics:GetFilteredMatch(index)["won"]) then
                selectedWins = selectedWins + 1;
            end
        else
            ArenaAnalytics:Log("Debug: Updating selected found index: ", index, " not found in filtered match history!")
        end
    end

    local selectedPrefixText = colorText("Selected: ", bottomStatsPrefixColor);
    if (selectedGamesCount > 0) then
        local winrate = math.floor(selectedWins * 100 / selectedGamesCount)
        local winsColoured =  "|cff00cc66" .. selectedWins .. "|r";
        local lossesColoured =  "|cffff0000" .. (selectedGamesCount - selectedWins) .. "|r";
        newSelectedText = selectedPrefixText .. selectedGamesCount .. " arenas   " .. winsColoured .. " / " .. lossesColoured .. "   " .. winrate .. "% Winrate"
        ArenaAnalyticsScrollFrame.clearSelected:Show();
    else
        newSelectedText = selectedPrefixText .. "(click matches to select)"
        ArenaAnalyticsScrollFrame.clearSelected:Hide();
    end
    ArenaAnalyticsScrollFrame.selectedStats:SetText(newSelectedText)
end

function AAtable:closeFilterDropdowns()
    if(ArenaAnalyticsScrollFrame.filterMapDropdown) then
        ArenaAnalyticsScrollFrame.filterMapDropdown.list:Hide();
    end
    if(ArenaAnalyticsScrollFrame.filterBracketDropdown) then
        ArenaAnalyticsScrollFrame.filterBracketDropdown.list:Hide();
    end
    if(ArenaAnalyticsScrollFrame.filterCompsDropdown) then
        ArenaAnalyticsScrollFrame.filterCompsDropdown.list:Hide();
    end
    if(ArenaAnalyticsScrollFrame.filterEnemyCompsDropdown) then
        ArenaAnalyticsScrollFrame.filterEnemyCompsDropdown.list:Hide();
    end
end

-- Creates addOn text, filters, table headers
function AAtable:OnLoad()
    ArenaAnalyticsScrollFrame.ListScrollFrame.update = function() AAtable:RefreshLayout(); end
    
    ArenaAnalyticsScrollFrame.filterCompsDropdown = {}
    ArenaAnalyticsScrollFrame.filterEnemyCompsDropdown = {}

    HybridScrollFrame_SetDoNotHideScrollBar(ArenaAnalyticsScrollFrame.ListScrollFrame, true);
    ArenaAnalyticsScrollFrame.Bg:SetTexture(nil)
    ArenaAnalyticsScrollFrame.Bg:SetColorTexture(0, 0, 0, 0.8)
    ArenaAnalyticsScrollFrame.title = ArenaAnalyticsScrollFrame:CreateFontString(nil, "OVERLAY");
    ArenaAnalyticsScrollFrame.title:SetPoint("CENTER", ArenaAnalyticsScrollFrame.TitleBg, "CENTER", 0, 0);
    ArenaAnalyticsScrollFrame.title:SetFont("Fonts\\FRIZQT__.TTF", 12, "");
    ArenaAnalyticsScrollFrame.title:SetText("Arena Analytics");
    ArenaAnalyticsScrollFrame.TitleBg:SetColorTexture(0,0,0,0.8)

    ArenaAnalyticsScrollFrame.teamBg = CreateFrame("Frame", nil, ArenaAnalyticsScrollFrame)
    ArenaAnalyticsScrollFrame.teamBg:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.TitleBg, "TOPLEFT", 340, -90);
    ArenaAnalyticsScrollFrame.teamBg:SetFrameStrata("LOW");
    ArenaAnalyticsScrollFrame.teamBg:SetSize(270, 413);
    
    ArenaAnalyticsScrollFrame.teamBgT = ArenaAnalyticsScrollFrame:CreateTexture()
    ArenaAnalyticsScrollFrame.teamBgT:SetColorTexture(0, 0, 0, 0.3)
    ArenaAnalyticsScrollFrame.teamBgT:SetSize(270, 413);
    ArenaAnalyticsScrollFrame.teamBgT:SetPoint("CENTER", ArenaAnalyticsScrollFrame.teamBg, "CENTER");

    ArenaAnalyticsScrollFrame.searchBox = CreateFrame("EditBox", "searchBox", ArenaAnalyticsScrollFrame, "SearchBoxTemplate")
    ArenaAnalyticsScrollFrame.searchBox:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame, "TOPLEFT", 30, -27);
    ArenaAnalyticsScrollFrame.searchBox:SetSize(220, 55);
    ArenaAnalyticsScrollFrame.searchBox:SetAutoFocus(false);
    ArenaAnalyticsScrollFrame.searchBox:SetMaxBytes(1024);

    ArenaAnalyticsScrollFrame.searchTitle = ArenaAnalyticsScrollFrame.searchBox:CreateFontString(nil, "OVERLAY");
    ArenaAnalyticsScrollFrame.searchTitle:SetPoint("TOPLEFT", -4, 0);
    ArenaAnalyticsScrollFrame.searchTitle:SetFont("Fonts\\FRIZQT__.TTF", 12, "");
    ArenaAnalyticsScrollFrame.searchTitle:SetText(Options:Get("searchDefaultExplicitEnemy") and "Enemy Search" or "Search");

    ArenaAnalyticsScrollFrame.searchBox:SetScript("OnEnterPressed", function()
        ArenaAnalyticsScrollFrame.searchBox:ClearFocus();
    end);

    ArenaAnalyticsScrollFrame.searchBox:SetScript("OnEscapePressed", function() 
        ArenaAnalyticsScrollFrame.searchBox:SetText(Search:GetDisplay());
        ArenaAnalyticsScrollFrame.searchBox:ClearFocus();
    end);

    local superOnTextChanged = ArenaAnalyticsScrollFrame.searchBox:GetScript("OnTextChanged");
    ArenaAnalyticsScrollFrame.searchBox:SetScript("OnTextChanged", function(self)
        assert(superOnTextChanged);
        superOnTextChanged(self);

        Search:Update(self:GetText());
    end);

    ArenaAnalyticsScrollFrame.searchBox:SetScript("OnTextSet", function(self) 
        if(self:GetText() == "" and not Search:IsEmpty()) then
            ArenaAnalytics:Log("Clearing search..");
            Search:CommitSearch("");
            self:SetText("");
        end
    end);
        
    ArenaAnalyticsScrollFrame.searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus();
        Search:CommitSearch(self:GetText());
    end);

    -- Dropdown data
    local title = "Bracket";
    local filter = "Filter_Bracket";
    local default = "All"
    local entries = { "All", "2v2", "3v3", "5v5" };

    ArenaAnalyticsScrollFrame.filterBracketDropdown = nil;
    ArenaAnalyticsScrollFrame.filterBracketDropdown = ArenaAnalytics.Dropdown:Create(filter, entries, default, title, 65, 25);
    ArenaAnalyticsScrollFrame.filterBracketDropdown:SetPoint("LEFT", ArenaAnalyticsScrollFrame.searchBox, "RIGHT", 10, 0);    

    ArenaAnalyticsScrollFrame.settingsButton = CreateFrame("Button", nil, ArenaAnalyticsScrollFrame, "GameMenuButtonTemplate");
    ArenaAnalyticsScrollFrame.settingsButton:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame, "TOPRIGHT", -46, -1);
    ArenaAnalyticsScrollFrame.settingsButton:SetText([[|TInterface\Buttons\UI-OptionsButton:0|t]]);
    ArenaAnalyticsScrollFrame.settingsButton:SetNormalFontObject("GameFontHighlight");
    ArenaAnalyticsScrollFrame.settingsButton:SetHighlightFontObject("GameFontHighlight");
    ArenaAnalyticsScrollFrame.settingsButton:SetSize(24, 19);
    ArenaAnalyticsScrollFrame.settingsButton:SetScript("OnClick", function()
        local enableOldSettings = false;
        if not enableOldSettings then
            ArenaAnalytics.Options:Open();
        else
            if (not ArenaAnalyticsScrollFrame.settingsFrame:IsShown()) then  
                ArenaAnalyticsScrollFrame.settingsFrame:Show();
                ArenaAnalyticsScrollFrame.allowReset:SetChecked(false);
                ArenaAnalyticsScrollFrame.resetBtn:Disable();
            else
                ArenaAnalyticsScrollFrame.settingsFrame:Hide();
            end
        end
    end);

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
    ArenaAnalyticsScrollFrame.sessionStats = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "BOTTOMLEFT", ArenaAnalyticsScrollFrame, "BOTTOMLEFT", 30, 27, "");
    
    ArenaAnalyticsScrollFrame.totalArenaNumber = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "BOTTOMLEFT", ArenaAnalyticsScrollFrame, "BOTTOMLEFT", 30, 10, "");
    ArenaAnalyticsScrollFrame.winrate = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.totalArenaNumber, "TOPRIGHT", 10, 0, "");

    local coloredSessionPrefix = colorText("Session Duration: ", bottomStatsPrefixColor);
    ArenaAnalyticsScrollFrame.sessionDuration = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "BOTTOMLEFT", ArenaAnalyticsScrollFrame, "BOTTOM", -65, 27, coloredSessionPrefix);

    local selectedPrefixText = colorText("Selected: ", bottomStatsPrefixColor);
    ArenaAnalyticsScrollFrame.selectedStats = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "BOTTOMLEFT", ArenaAnalyticsScrollFrame, "BOTTOM", -65, 10, selectedPrefixText .. " (click matches to select)");
    
    AAtable:tryStartSessionDurationTimer();

    ArenaAnalyticsScrollFrame.clearSelected = AAtable:CreateButton("BOTTOMRIGHT", ArenaAnalyticsScrollFrame, "BOTTOMRIGHT", -30, 10, "Clear Selected");
    ArenaAnalyticsScrollFrame.clearSelected:SetWidth(110)
    ArenaAnalyticsScrollFrame.clearSelected:Hide();
    ArenaAnalyticsScrollFrame.clearSelected:SetScript("OnClick", function() ArenaAnalytics.Selection:ClearSelectedMatches() end);
    
    ArenaAnalyticsScrollFrame.unsavedWarning = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "BOTTOMRIGHT", ArenaAnalyticsScrollFrame, "BOTTOMRIGHT", -160, 13, unsavedWarningText);
    ArenaAnalyticsScrollFrame.unsavedWarning:Hide();
    ArenaAnalyticsScrollFrame.unsavedWarning:Show();

    -- First time user import popup if no matches are stored
    if (not ArenaAnalytics:HasStoredMatches()) then
        AAtable:tryShowimportDialogFrame(ArenaAnalyticsScrollFrame);
    end

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
        CloseDropDownMenus();
    end);

    ArenaAnalyticsScrollFrame:SetScript("OnShow", function()
        -- AAtable:tryShowimportDialogFrame();
    end);

    ArenaAnalyticsScrollFrame.specFrames = {}
    ArenaAnalyticsScrollFrame.deathFrames = {}

    HybridScrollFrame_CreateButtons(ArenaAnalyticsScrollFrame.ListScrollFrame, "ArenaAnalyticsScrollListMatch");

    hasLoaded = true;

    ArenaAnalytics.AAtable:handleArenaCountChanged();

    ArenaAnalyticsScrollFrame.filterBtn_MoreFilters = AAtable:CreateButton("LEFT", ArenaAnalyticsScrollFrame, "RIGHT", 10, 0, "More Filters");
    ArenaAnalyticsScrollFrame.filterBtn_MoreFilters:SetPoint("LEFT", ArenaAnalyticsScrollFrame.filterEnemyCompsDropdown, "RIGHT", 10, 0);
    ArenaAnalyticsScrollFrame.filterBtn_MoreFilters:SetWidth(90);

    ArenaAnalyticsScrollFrame.filterBtn_MoreFilters:RegisterForClicks("LeftButtonDown", "RightButtonDown");

    ArenaAnalyticsScrollFrame.filterBtn_MoreFilters:SetScript("OnClick", function(frame, btn)
        if(btn == "RightButton") then
            -- Clear all filters related to this
            ArenaAnalytics.MoreFilters:ResetAll();
        else
            ToggleDropDownMenu(1, nil, ArenaAnalytics.MoreFilters.dropdown, "cursor", 3, -10);
        end
    end);

    ArenaAnalyticsScrollFrame.filterBtn_ClearFilters = AAtable:CreateButton("LEFT", ArenaAnalyticsScrollFrame.filterBtn_MoreFilters, "RIGHT", 10, 0, "Clear");
    ArenaAnalyticsScrollFrame.filterBtn_ClearFilters:SetWidth(50);

    -- Clear all filters
    ArenaAnalyticsScrollFrame.filterBtn_ClearFilters:SetScript("OnClick", function() 
        ArenaAnalytics:Log("Clearing filters..");

        Filters:ResetAll(IsShiftKeyDown());

        -- Reset filters UI
        ArenaAnalyticsScrollFrame.searchBox:SetText("");
        ArenaAnalyticsScrollFrame.filterBracketDropdown:Reset();
        AAtable:forceCompFilterRefresh();
        
        Filters:RefreshFilters();
        CloseDropDownMenus();
    end);
    
    -- Active Filters text count
    ArenaAnalyticsScrollFrame.activeFilterCountText = ArenaAnalyticsScrollFrame.filterBtn_MoreFilters:CreateFontString(nil, "OVERLAY")
    ArenaAnalyticsScrollFrame.activeFilterCountText:SetFont("Fonts\\FRIZQT__.TTF", 10, "");
    ArenaAnalyticsScrollFrame.activeFilterCountText:SetPoint("BOTTOM", ArenaAnalyticsScrollFrame.filterBtn_ClearFilters, "TOP", 0, 5);
    ArenaAnalyticsScrollFrame.activeFilterCountText:SetText("");

    Filters:RefreshFilters(function()
        AAtable:UpdateSelected();
    end);

    AAtable:OnShow();
end

function AAtable:tryShowimportDialogFrame(parent)
    if(ArenaAnalyticsScrollFrame.importDialogFrame == nil) then       
        ArenaAnalyticsScrollFrame.importDialogFrame = CreateFrame("Frame", "ArenaAnalyticsImportFrame", parent or UIParent, "BasicFrameTemplateWithInset")
        ArenaAnalyticsScrollFrame.importDialogFrame:SetPoint("CENTER")
        ArenaAnalyticsScrollFrame.importDialogFrame:SetSize(475, 145)
        ArenaAnalyticsScrollFrame.importDialogFrame:SetFrameStrata("HIGH");
        ArenaAnalyticsScrollFrame.importDialogFrame.title = ArenaAnalyticsScrollFrame.importDialogFrame:CreateFontString(nil, "OVERLAY");
        ArenaAnalyticsScrollFrame.importDialogFrame.title:SetPoint("TOP", ArenaAnalyticsScrollFrame.importDialogFrame, "TOP", -10, -5);
        ArenaAnalyticsScrollFrame.importDialogFrame.title:SetFont("Fonts\\FRIZQT__.TTF", 12, "");
        ArenaAnalyticsScrollFrame.importDialogFrame.title:SetText("Import");
        ArenaAnalyticsScrollFrame.importDialogFrame.Text1 = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.importDialogFrame, "CENTER", ArenaAnalyticsScrollFrame.importDialogFrame, "TOP", 0, -45, "Paste the ArenaStats or ArenaAnalytics export on the text box below.");
        ArenaAnalyticsScrollFrame.importDialogFrame.Text2 = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.importDialogFrame, "CENTER", ArenaAnalyticsScrollFrame.importDialogFrame, "TOP", 0, -65, "|cffCCCCCCNote:|r |cff888888Matches with missing specs detected won't show on comp filters.|r");
            
        ArenaAnalyticsScrollFrame.importDialogFrame.button = ArenaAnalytics.AAtable:CreateButton("TOPRIGHT", ArenaAnalyticsScrollFrame.importDialogFrame, "TOPRIGHT", -70, -80, "Import");
        ArenaAnalyticsScrollFrame.importDialogFrame.button:SetSize(115, 25);
        
        ArenaAnalyticsScrollFrame.importDialogFrame.editbox = CreateFrame("EditBox", "exportFrameScroll", ArenaAnalyticsScrollFrame.importDialogFrame.button, "InputBoxTemplate")
        ArenaAnalyticsScrollFrame.importDialogFrame.editbox:SetPoint("RIGHT", ArenaAnalyticsScrollFrame.importDialogFrame.button, "LEFT", -10, 0);
        ArenaAnalyticsScrollFrame.importDialogFrame.editbox:SetFrameStrata("HIGH");
        ArenaAnalyticsScrollFrame.importDialogFrame.editbox:SetSize(213, 55);
        ArenaAnalyticsScrollFrame.importDialogFrame.editbox:SetAutoFocus(false);
        ArenaAnalyticsScrollFrame.importDialogFrame.editbox:SetMaxBytes(50);

        ArenaAnalyticsScrollFrame.importDataText3 = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.importDialogFrame, "CENTER", ArenaAnalyticsScrollFrame.importDialogFrame, "BOTTOM", 0, 25, "|cffff0000Do this NOW|r You won't be able to do this while you have stored arenas!");

        
        local pasteBuffer, lastPasteTime, index = {}, 0, 0;

        local function onCharAdded(self, c)
            if(ArenaAnalyticsScrollFrame.importDialogFrame == nil) then
                return;
            end

            if(ArenaAnalyticsScrollFrame.importDialogFrame.editbox:IsEnabled()) then
                ArenaAnalyticsScrollFrame.importDialogFrame.editbox:Disable();
                pasteBuffer, index = {}, 0;

                ArenaAnalyticsScrollFrame.importDialogFrame.editbox:SetScript("OnChar", nil);
                ArenaAnalyticsScrollFrame.importDialogFrame.editbox:SetText("");
                ArenaAnalyticsScrollFrame.importDialogFrame.editbox:SetScript("OnChar", onCharAdded);

                C_Timer.After(0, function()
                    if(ArenaAnalyticsScrollFrame.importDialogFrame == nil) then
                        return;
                    end

                    ArenaAnalytics:Log("Finalizing import paste.");
                    ArenaImportPasteStringTable = {}
                    tinsert(ArenaImportPasteStringTable, (string.trim(table.concat(pasteBuffer)) or ""));
                    ArenaAnalytics:Log(#ArenaImportPasteStringTable);

                    if(#ArenaImportPasteStringTable[1] > 0) then
                        ArenaAnalyticsScrollFrame.importDialogFrame.editbox:Enable();
                    end

                    pasteBuffer = {}
                    index = 0;

                    -- Update text: 1) Prevent OnChar for changing text
                    ArenaAnalyticsScrollFrame.importDialogFrame.editbox:SetScript("OnChar", nil);
                    ArenaAnalyticsScrollFrame.importDialogFrame.editbox:SetText(ArenaAnalytics.Import:determineImportSource(ArenaImportPasteStringTable) .. " import detected...");
                    ArenaAnalyticsScrollFrame.importDialogFrame.editbox:SetScript("OnChar", onCharAdded);
                end);
            end

            index = index + 1;
            pasteBuffer[index] = c;
        end

        ArenaAnalyticsScrollFrame.importDialogFrame.editbox:SetScript("OnChar", onCharAdded);
        ArenaAnalyticsScrollFrame.importDialogFrame.editbox:SetScript("OnEditFocusGained", function()
            ArenaAnalyticsScrollFrame.importDialogFrame.editbox:HighlightText();
        end);

        ArenaAnalyticsScrollFrame.importDialogFrame.button:SetScript("OnClick", function (i) 
            ArenaAnalyticsScrollFrame.importDialogFrame.button:Disable();
            ArenaAnalytics.Import:parseRawData(ArenaImportPasteStringTable);
            ArenaImportPasteStringTable = {};
        end);

        ArenaAnalyticsScrollFrame.importDialogFrame.editbox:SetScript("OnEnterPressed", function(self)
            self:ClearFocus();
        end);
        ArenaAnalyticsScrollFrame.importDialogFrame.editbox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus();
        end);

		-- Clear text
		ArenaAnalyticsScrollFrame.importDialogFrame.editbox:SetScript("OnHide", function(self)
			-- Garbage collect
			self:SetText("");
            collectgarbage("collect");
		end);
    end

    ArenaAnalyticsScrollFrame.importDialogFrame.button:Enable();
    ArenaAnalyticsScrollFrame.importDialogFrame:Show();
end

-- Creates the Export DB frame
function AAtable:CreateExportDialogFrame()
    if (not ArenaAnalytics:HasStoredMatches()) then
        return;
    end

	if(ArenaAnalyticsScrollFrame.exportDialogFrame == nil) then
		ArenaAnalyticsScrollFrame.exportDialogFrame = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
		ArenaAnalyticsScrollFrame.exportDialogFrame:SetFrameStrata("DIALOG");
		ArenaAnalyticsScrollFrame.exportDialogFrame:SetFrameLevel(10);
		ArenaAnalyticsScrollFrame.exportDialogFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
		ArenaAnalyticsScrollFrame.exportDialogFrame:SetSize(400, 150);

		-- Make frame draggable
		ArenaAnalyticsScrollFrame.exportDialogFrame:SetMovable(true)
		ArenaAnalyticsScrollFrame.exportDialogFrame:EnableMouse(true)
		ArenaAnalyticsScrollFrame.exportDialogFrame:RegisterForDrag("LeftButton")
		ArenaAnalyticsScrollFrame.exportDialogFrame:SetScript("OnDragStart", ArenaAnalyticsScrollFrame.exportDialogFrame.StartMoving)
		ArenaAnalyticsScrollFrame.exportDialogFrame:SetScript("OnDragStop", ArenaAnalyticsScrollFrame.exportDialogFrame.StopMovingOrSizing)

		ArenaAnalyticsScrollFrame.exportDialogFrame.Title = ArenaAnalyticsScrollFrame.exportDialogFrame:CreateFontString(nil, "OVERLAY");
		ArenaAnalyticsScrollFrame.exportDialogFrame.Title:SetPoint("TOP", ArenaAnalyticsScrollFrame.exportDialogFrame, "TOP", -10, -5);
		ArenaAnalyticsScrollFrame.exportDialogFrame.Title:SetFont("Fonts\\FRIZQT__.TTF", 12, "");
		ArenaAnalyticsScrollFrame.exportDialogFrame.Title:SetText("ArenaAnalytics Export");

		ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame = CreateFrame("EditBox", "exportFrameEditbox", ArenaAnalyticsScrollFrame.exportDialogFrame, "InputBoxTemplate");
		ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame:SetPoint("CENTER", ArenaAnalyticsScrollFrame.exportDialogFrame, "CENTER");
		ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame:SetSize(350, 25);
		ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame:SetAutoFocus(true);
		ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame:SetFont("Fonts\\FRIZQT__.TTF", 10, "");
		ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame:SetMultiLine(false);
		ArenaAnalyticsScrollFrame.exportDialogFrame:Hide();
		
		ArenaAnalyticsScrollFrame.exportDialogFrame.WarningText = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.exportDialogFrame,"BOTTOM", ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame, "TOP", 13, 0, "|cffff0000Warning:|r Pasting long string here will crash WoW!");
		ArenaAnalyticsScrollFrame.exportDialogFrame.totalText = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.exportDialogFrame,"TOPLEFT", ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame, "BOTTOMLEFT", -3, 0, "Total arenas: " .. #MatchHistoryDB);
		ArenaAnalyticsScrollFrame.exportDialogFrame.lengthText = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.exportDialogFrame,"TOPRIGHT", ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame, "BOTTOMRIGHT", -3, 0, "Export length: 0");

		ArenaAnalyticsScrollFrame.exportDialogFrame.selectBtn = ArenaAnalytics.AAtable:CreateButton("BOTTOM", ArenaAnalyticsScrollFrame.exportDialogFrame, "BOTTOM", 0, 17, "Select All");
		ArenaAnalyticsScrollFrame.exportDialogFrame.selectBtn:SetScript("OnClick", function() ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame:HighlightText() end);
		
		-- Escape to close
		ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame:SetScript("OnEscapePressed", function(self)
			ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame:ClearFocus();
			ArenaAnalyticsScrollFrame.exportDialogFrame:Hide();
		end);

		ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame:SetScript("OnEnterPressed", function(self)
			self:ClearFocus();
		end);

		-- Highlight on focus gained
		ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame:SetScript("OnEditFocusGained", function(self)
			self:HighlightText();
		end);

		-- Clear text
		ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame:SetScript("OnHide", function(self)
			-- Garbage collect
			self:SetText("");
            ArenaAnalyticsScrollFrame.exportDialogFrame = nil;
            ArenaAnalytics:Log("Export Frame going away..")
            collectgarbage("collect");
		end);
	end
    
    ArenaAnalyticsScrollFrame.exportDialogFrame:Show();
end

function AAtable:OnShow()
    AAtable:RefreshLayout();
    ArenaAnalyticsScrollFrame:Hide();
end

local function setupTeamPlayerFrames(teamPlayerFrames, match, matchIndex, teamKey, scrollEntry)
    if(match == nil or match[teamKey] == nil) then
        return;
    end

    for i = 1, #teamPlayerFrames do
        local player = match[teamKey][i];
        local playerFrame = teamPlayerFrames[i];
        if (player and playerFrame) then
            playerFrame.team = teamKey;
            playerFrame.playerIndex = i;
            playerFrame.matchIndex = matchIndex;
            
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
                playerName = playerName:match("(.*)-") or "";
            end

            playerFrame:SetAttribute("name", playerName);

            -- Quick Search
            playerFrame:RegisterForClicks("LeftButtonDown", "RightButtonDown");
            playerFrame:SetScript("OnClick", function(frame, btn)
                Search:QuickSearch(btn, player, teamKey);
            end);

            -- Add spec info
            if(class) then
                if (playerFrame.specOverlay == nil) then
                    playerFrame.specOverlay = CreateFrame("Frame", nil, playerFrame);
                    playerFrame.specOverlay:SetPoint("BOTTOMRIGHT", playerFrame, "BOTTOMRIGHT")
                    playerFrame.specOverlay:SetSize(12,12)
                    
                    playerFrame.specOverlay.texture = playerFrame.specOverlay:CreateTexture();
                    playerFrame.specOverlay.texture:SetPoint("CENTER")
                    playerFrame.specOverlay.texture:SetSize(12,12)
                else
                    playerFrame.specOverlay.texture:SetTexture(nil);
                end

                local specIcon = spec and ArenaAnalyticsGetSpecIcon(spec, class) or nil;
                playerFrame.specOverlay.texture:SetTexture(specIcon);

                if (not Options:Get("alwaysShowSpecOverlay")) then
                    playerFrame.specOverlay:Hide();
                end
            else
                if (playerFrame.specOverlay) then
                    playerFrame.specOverlay:SetTexture(nil);
                    playerFrame.specOverlay:Hide();
                end
            end

            playerFrame:SetScript("OnEnter", function ()
                ArenaAnalytics.Tooltips:DrawPlayerTooltip(playerFrame);
            end);
            playerFrame:SetScript("OnLeave", function ()
                GameTooltip:Hide();
            end);

            -- Add death overlay            
            local firstDeath = match["firstDeath"] and match["firstDeath"]:gsub("-", "%%-") or nil;
            if (firstDeath and string.find(player["name"], firstDeath)) then
                if (playerFrame.deathOverlay == nil) then
                    playerFrame.deathOverlay = CreateFrame("Frame", nil, playerFrame);
                    playerFrame.deathOverlay:SetPoint("BOTTOMRIGHT", playerFrame, "BOTTOMRIGHT")
                    playerFrame.deathOverlay:SetSize(26,26)

                    playerFrame.deathOverlay.texture = playerFrame.deathOverlay:CreateTexture();
                    playerFrame.deathOverlay.texture:SetPoint("CENTER")
                    playerFrame.deathOverlay.texture:SetSize(26,26)
                    playerFrame.deathOverlay.texture:SetColorTexture(1, 0, 0, 0.27);
                end
                if (not Options:Get("alwaysShowDeathOverlay")) then
                    playerFrame.deathOverlay:Hide();
                end
            elseif (playerFrame.deathOverlay ~= nil) then
                playerFrame.deathOverlay:Hide();
                playerFrame.deathOverlay.texture:SetTexture(nil);
                playerFrame.deathOverlay = nil;
            end

            playerFrame:Show()
        else
            playerFrame:Hide();
        end
    end
end

-- Hide/Shows Spec icons on the class' bottom-right corner
function AAtable:ToggleSpecsAndDeathOverlay(entry)
    if (entry == nil) then
        return;
    end

    local matchData = { entry:GetChildren() };
    local visible = entry:GetAttribute("selected") or entry:GetAttribute("hovered");

    for i = 1, #matchData do
        if (matchData[i].specOverlay) then
            if (visible or Options:Get("alwaysShowSpecOverlay")) then
                matchData[i].specOverlay:Show();
            else
                matchData[i].specOverlay:Hide();
            end
        end
        if (matchData[i].deathOverlay) then
            if (visible or Options:Get("alwaysShowDeathOverlay")) then
                matchData[i].deathOverlay:Show();
            else
                matchData[i].deathOverlay:Hide();
            end
        end
    end
end

-- Sets button row's background according to session
local function setColorForSession(button, session, index)
    local isOddSession = (session or 0) % 2 == 1;
    local oddAlpha, evenAlpha = 0.8, 0.4;
    
    local alpha = isOddSession and oddAlpha or evenAlpha;

    local isOddIndex = (index or 0) % 2 == 1;
    if(isOddIndex) then
        if(isOddSession) then
            alpha = alpha - 0.07;
        else
            alpha = alpha + 0.07;
        end
    end

    if isOddSession then
        local c = 0.05;
        button.Background:SetColorTexture(c, c, c, min(alpha, 1))
    else
        local c = 0.25;
        button.Background:SetColorTexture(c, c, c, min(alpha, 1))
    end
end

-- Create dropdowns for the Comp filters
function AAtable:createDropdownForFilterComps(isEnemyComp)
    if(not hasLoaded) then
        return;
    end

    local isDisabled = Filters:GetCurrent("Filter_Bracket") == "All";
    local disabledText = "Select bracket to enable filter"

    -- Dropdown data
    local filter = isEnemyComp and "Filter_EnemyComp" or "Filter_Comp";
    local title = isEnemyComp and "Enemy Comp:" or "Comp:";
    local entries = Filters:getPlayedCompsWithTotalAndWins(isEnemyComp);
    local default = isDisabled and disabledText or nil;

    local dropdown = ArenaAnalytics.Dropdown:Create(filter, entries, default, title, 235, 25);
    local parent = isEnemyComp and ArenaAnalyticsScrollFrame.filterCompsDropdown or ArenaAnalyticsScrollFrame.filterBracketDropdown;
    dropdown:SetPoint("LEFT", parent, "RIGHT", 10, 0);

    if(isDisabled) then
        -- Set tooltip when comp is disabled
        dropdown.list:Hide();
        dropdown.selected:Disable();
    end

    if(isEnemyComp) then
        ArenaAnalyticsScrollFrame.filterEnemyCompsDropdown = dropdown;
    else
        ArenaAnalyticsScrollFrame.filterCompsDropdown = dropdown;
    end
end

-- Forcefully clear and recreate the comp filters for new filters. Optionally staying visible.
function AAtable:forceCompFilterRefresh(keepVisibility)
    local wasCompFilterVisible, wasEnemyCompFilterVisible = false, false

    -- Clear existing comp frame
    if(ArenaAnalyticsScrollFrame.filterCompsDropdown and ArenaAnalyticsScrollFrame.filterCompsDropdown.list) then
        wasCompFilterVisible = ArenaAnalyticsScrollFrame.filterCompsDropdown.list:IsShown();
        ArenaAnalyticsScrollFrame.filterCompsDropdown:Hide();
        ArenaAnalyticsScrollFrame.filterCompsDropdown = nil;
    end
    ArenaAnalyticsScrollFrame.filterCompsDropdown = nil;
    
    -- Clear existing enemy comp frame
    if(ArenaAnalyticsScrollFrame.filterEnemyCompsDropdown ~= nil and ArenaAnalyticsScrollFrame.filterEnemyCompsDropdown.list) then
        wasEnemyCompFilterVisible = ArenaAnalyticsScrollFrame.filterEnemyCompsDropdown.list:IsShown();
        ArenaAnalyticsScrollFrame.filterEnemyCompsDropdown:Hide();
        ArenaAnalyticsScrollFrame.filterEnemyCompsDropdown = nil;
    end
    ArenaAnalyticsScrollFrame.filterCompsDropdown = nil;
    
    -- Create updated frames (Friendly first!)
    AAtable:createDropdownForFilterComps(false); -- isEnemyComp == false
    AAtable:createDropdownForFilterComps(true);

    -- Update visibility to match previous visibility, if desired
    if(keepVisibility == true) then
        if (wasCompFilterVisible == true) then
            ArenaAnalyticsScrollFrame.filterCompsDropdown:ShowDropdown();
        end

        if(wasEnemyCompFilterVisible == true) then
            ArenaAnalyticsScrollFrame.filterEnemyCompsDropdown:ShowDropdown();
        end
    end

    if(ArenaAnalyticsScrollFrame.filterBtn_MoreFilters ~= nil) then
        ArenaAnalyticsScrollFrame.filterBtn_MoreFilters:SetPoint("LEFT", ArenaAnalyticsScrollFrame.filterEnemyCompsDropdown, "RIGHT", 10, 0);
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

function AAtable:checkUnsavedWarningThreshold()
    if(ArenaAnalytics.unsavedArenaCount >= Options:Get("unsavedWarningThreshold")) then
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
    if(not hasLoaded) then
        -- Load will trigger call soon
        return;
    end

    ArenaAnalytics.Options:TriggerStateUpdates()

    AAtable:RefreshLayout();
    AAtable:forceCompFilterRefresh();

    if(not ArenaAnalytics:HasStoredMatches() and ArenaAnalyticsScrollFrame.exportDialogFrame) then
        ArenaAnalyticsScrollFrame.exportDialogFrame:Hide();
    end

    wins, sessionGames, sessionWins = 0,0,0;
    -- Update arena count & winrate
    for i=#ArenaAnalytics.filteredMatchHistory, 1, -1 do
        local match = ArenaAnalytics:GetFilteredMatch(i);
        if(match) then 
            if(match["won"]) then 
                wins = wins + 1; 
            end
            
            if (match["filteredSession"] == 1) then
                sessionGames = sessionGames + 1;
                if (match["won"]) then
                    sessionWins = sessionWins + 1;
                end
            end
        end
    end

    -- Update displayed session stats text
    local _, expired = ArenaAnalytics:getLastSession();
    local sessionText = expired and "Last session: " or "Current session: ";
    sessionText = colorText(sessionText, bottomStatsPrefixColor);
    local sessionStats = sessionGames > 0 and math.floor(sessionWins * 100 / sessionGames) or 0;
    local sessionWinsColoured =  "|cff00cc66" .. sessionWins .. "|r";
    local sessionLossesColoured =  "|cffff0000" .. (sessionGames - sessionWins) .. "|r";
    ArenaAnalyticsScrollFrame.sessionStats:SetText(sessionText .. sessionGames .. " arena" .. (sessionGames ~= 1 and "s" or "") .. "   " .. sessionWinsColoured .. " / " .. sessionLossesColoured .. "  " .. sessionStats .. "% Winrate");

    -- Update the 
    local totalArenas = #ArenaAnalytics.filteredMatchHistory;
    local winrate = totalArenas > 0 and math.floor(wins * 100 / totalArenas) or 0;
    local winsColoured =  "|cff00cc66" .. wins .. "|r";
    local lossesColoured =  "|cffff0000" .. (totalArenas - wins) .. "|r";
    local text = colorText("Filtered total: ", bottomStatsPrefixColor);
    ArenaAnalyticsScrollFrame.totalArenaNumber:SetText(text .. totalArenas .. " arena" .. (totalArenas ~= 1 and "s" or ""));
    ArenaAnalyticsScrollFrame.winrate:SetText(winsColoured .. " / " .. lossesColoured .. "   " .. winrate .. "% Winrate");

    ArenaAnalytics.AAtable.checkUnsavedWarningThreshold();
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

-- Refreshes matches table
function AAtable:RefreshLayout()
    if(not hasLoaded) then
        -- Load will trigger call soon
        return;
    end

    if(ArenaAnalyticsScrollFrame.filterBtn_ClearFilters) then
        local activeFilterCount = Filters:getActiveFilterCount();
        if(activeFilterCount > 0) then
            ArenaAnalyticsScrollFrame.activeFilterCountText:SetText("(" .. activeFilterCount .." active)");
            ArenaAnalyticsScrollFrame.filterBtn_ClearFilters:Enable();
        else
            ArenaAnalyticsScrollFrame.activeFilterCountText:SetText("");

            if(not Options:Get("defaultCurrentSeasonFilter") and not Options:Get("defaultCurrentSessionFilter")) then
                ArenaAnalyticsScrollFrame.filterBtn_ClearFilters:Disable();
            end
        end
    end

    local buttons = HybridScrollFrame_GetButtons(ArenaAnalyticsScrollFrame.ListScrollFrame);
    local offset = HybridScrollFrame_GetOffset(ArenaAnalyticsScrollFrame.ListScrollFrame);

    for buttonIndex = 1, #buttons do
        local button = buttons[buttonIndex];
        local matchIndex = #ArenaAnalytics.filteredMatchHistory - (buttonIndex + offset - 1);

        local match = ArenaAnalytics:GetFilteredMatch(matchIndex);
        if (match ~= nil) then
            setColorForSession(button, match["filteredSession"], matchIndex);
            button.Date:SetText(date("%d/%m/%y %H:%M:%S", match["date"]) or "");
            button.Map:SetText(match["map"] or "");
            button.Duration:SetText(SecondsToTime(match["duration"]) or "");

            local teamIconsFrames = {button.Team1, button.Team2, button.Team3, button.Team4, button.Team5}
            local enemyTeamIconsFrames = {button.EnemyTeam1, button.EnemyTeam2, button.EnemyTeam3, button.EnemyTeam4, button.EnemyTeam5}
            
            -- Setup player class frames
            setupTeamPlayerFrames(teamIconsFrames, match, matchIndex, "team", button);
            setupTeamPlayerFrames(enemyTeamIconsFrames, match, matchIndex, "enemyTeam", button);

            local enemyDelta
            -- Paint winner green, loser red
            local hex
            if(match["won"] == nil) then
                hex = "ff999999";
            else
                hex = match["won"] and "ff00cc66" or "ffff0000"
            end
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

            local isSelected = ArenaAnalytics.Selection:isMatchSelected(matchIndex);
            button:SetAttribute("selected", isSelected);
            if(isSelected) then
                button.Tooltip:Show();
                AAtable:ToggleSpecsAndDeathOverlay(button);
            else
                button.Tooltip:Hide();
            end

            button:SetScript("OnEnter", function(args)
                args:SetAttribute("hovered", true);
                AAtable:ToggleSpecsAndDeathOverlay(args);
            end);

            button:SetScript("OnLeave", function(args) 
                args:SetAttribute("hovered", false);
                AAtable:ToggleSpecsAndDeathOverlay(args);
            end);
            
            button:RegisterForClicks("LeftButtonDown", "RightButtonDown", "LeftButtonUp", "RightButtonUp");
            button:SetScript("OnClick", function(args, key, down)
                if down then
                    ArenaAnalytics.Selection:handleMatchEntryClicked(key, false, matchIndex);
                end
            end);

            button:SetScript("OnDoubleClick", function(args, key)
                ArenaAnalytics.Selection:handleMatchEntryClicked(key, true, matchIndex);
            end);

            AAtable:ToggleSpecsAndDeathOverlay(button);

            button:SetWidth(ArenaAnalyticsScrollFrame.ListScrollFrame.scrollChild:GetWidth());
            button:Show();
        else
            button:Hide();
        end
    end

    -- Adjust Team bg
    if (#ArenaAnalytics.filteredMatchHistory < 15) then
        local newHeight = (#ArenaAnalytics.filteredMatchHistory * 28) - 1;
        ArenaAnalyticsScrollFrame.teamBgT:SetHeight(newHeight);
        ArenaAnalyticsScrollFrame.teamBg:SetHeight(newHeight);
    else
        ArenaAnalyticsScrollFrame.teamBgT:SetHeight(413);
        ArenaAnalyticsScrollFrame.teamBg:SetHeight(413);
    end

    local buttonHeight = ArenaAnalyticsScrollFrame.ListScrollFrame.buttonHeight;
    local totalHeight = #ArenaAnalytics.filteredMatchHistory * buttonHeight;
    local shownHeight = #buttons * buttonHeight;
    HybridScrollFrame_Update(ArenaAnalyticsScrollFrame.ListScrollFrame, totalHeight, shownHeight);
end

----------------------------------------------------------------------------------------------------------------------------
-- Session Duration
local isSessionTimerActive = false;
local function formatSessionDuration(duration)
    if(tonumber(duration) == nil) then
        return "";
    end

    local hours = math.floor(duration / 3600) .. "h"
    local minutes = string.format("%02dm", math.floor((duration % 3600) / 60));
    local seconds = string.format("%02ds", duration % 60);

    if duration < 3600 then
        return minutes .. " " .. seconds;
    else
        return hours .. " " .. minutes;
    end
end

local function setLatestSessionDurationText(expired, startTime, endTime)
    endTime = expired and endTime or time();
    local duration = startTime and endTime - startTime or nil;

    local text = expired and "Last Session Duration: " or "Session Duration: ";
    text = colorText(text, bottomStatsPrefixColor);
    ArenaAnalyticsScrollFrame.sessionDuration:SetText(text .. formatSessionDuration(duration));
end

local function handleSessionDurationTimer()
    local _,expired, startTime, endTime = ArenaAnalytics:getLastSessionStartAndEndTime();

    isSessionTimerActive = false;
    
    -- Update text
    setLatestSessionDurationText(expired, startTime, endTime);

    if (startTime and not expired and not isSessionTimerActive) then
        local duration = endTime - startTime;
        local desiredInterval = (duration > 3600) and 60 or 1;
        isSessionTimerActive = true;
        C_Timer.After(desiredInterval, function() handleSessionDurationTimer() end);
    end
end

function AAtable:tryStartSessionDurationTimer()
    local _,expired, startTime, endTime = ArenaAnalytics:getLastSessionStartAndEndTime();
    -- Update text
    setLatestSessionDurationText(expired, startTime, endTime);
    
    if (startTime and not expired and not isSessionTimerActive) then
        local duration = time() - startTime;
        local desiredInterval = (duration > 3600) and 60 or 1;
        local firstInterval = desiredInterval - duration % desiredInterval;
        isSessionTimerActive = true;
        C_Timer.After(firstInterval, function() handleSessionDurationTimer() end);
    end
end