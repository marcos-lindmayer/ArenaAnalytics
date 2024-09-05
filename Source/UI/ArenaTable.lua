local _, ArenaAnalytics = ...; -- Addon Namespace
local AAtable = ArenaAnalytics.AAtable;
HybridScrollMixin = ArenaAnalytics.AAtable; -- HybridScroll.xml wants access to this

-- Local module aliases
local Options = ArenaAnalytics.Options;
local Filters = ArenaAnalytics.Filters;
local FilterTables = ArenaAnalytics.FilterTables;
local Search = ArenaAnalytics.Search;
local Dropdown = ArenaAnalytics.Dropdown;
local Selection = ArenaAnalytics.Selection;
local API = ArenaAnalytics.API;
local Import = ArenaAnalytics.Import;
local Tooltips = ArenaAnalytics.Tooltips;
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local Internal = ArenaAnalytics.Internal;
local Constants = ArenaAnalytics.Constants;
local ImportBox = ArenaAnalytics.ImportBox;

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
        Selection:ClearSelectedMatches();

        Filters:Refresh(function()
            AAtable:RefreshLayout();
        end);

        Dropdown:CloseAll();

        ArenaAnalyticsScrollFrame:Show();
    else
        ArenaAnalyticsScrollFrame:Hide();
    end
end

function AAtable:GetDropdownTemplate(overrideTemplate)
    return overrideTemplate or API.defaultButtonTemplate or "UIPanelButtonTemplate";
end

-- Returns button based on params
function AAtable:CreateButton(point, relativeFrame, relativePoint, xOffset, yOffset, text, template)
    local btn = CreateFrame("Button", nil, relativeFrame, AAtable:GetDropdownTemplate(template));
    btn:SetPoint(point, relativeFrame, relativePoint, xOffset, yOffset);
    btn:SetSize(120, 25);
    btn:SetText(text);
    btn:SetNormalFontObject("GameFontHighlight");
    btn:SetHighlightFontObject("GameFontHighlight");
    btn:SetDisabledFontObject("GameFontDisableSmall");
    
    if(btn.money) then
        btn.money:Hide();
    end
    
    return btn;
end

-- Returns string frame
function ArenaAnalyticsCreateText(parent, anchor, relativeFrame, relPoint, xOff, yOff, text, fontSize)
    local fontString = parent:CreateFontString(nil, "OVERLAY");
    fontString:SetFont("Fonts\\FRIZQT__.TTF", fontSize or 12, "");
    fontString:SetPoint(anchor, relativeFrame, relPoint, xOff, yOff);
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
    
    local deselectedCache = Selection.latestDeselect;
    local selectedTables = { Selection.latestMultiSelect, Selection.selectedGames }

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
        local match = ArenaAnalytics:GetFilteredMatch(index);
        if(match) then
            selectedGamesCount = selectedGamesCount + 1;
            if (ArenaMatch:IsVictory(match)) then
                selectedWins = selectedWins + 1;
            end
        else
            ArenaAnalytics:Log("Updating selected found index: ", index, " not found in filtered match history!");
        end
    end

    -- Update the UI
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

local function CreateFilterTitle(filterFrame, title, info, offsetX, size)
    filterFrame.title = filterFrame:CreateFontString(nil, "OVERLAY");
    filterFrame.title:SetFont("Fonts\\FRIZQT__.TTF", size or 12, "");
    filterFrame.title:SetPoint("TOPLEFT", offsetX or 2, 15);
    filterFrame.title:SetText(title);

    if(info) then
        filterFrame.title.info = filterFrame:CreateFontString(nil, "OVERLAY");
        filterFrame.title.info:SetFont("Fonts\\FRIZQT__.TTF", 8, "");
        filterFrame.title.info:SetPoint("TOPRIGHT", -5, 11);

        filterFrame.title.info:SetText("|cffbbbbbb" .. info .. "|r");

        if(not Options:Get("showCompDropdownInfoText")) then
            filterFrame.title.info:Hide();
        end
    end
end

-- Creates addOn text, filters, table headers
function AAtable:OnLoad()
    ArenaAnalyticsScrollFrame.ListScrollFrame.update = function() AAtable:RefreshLayout(); end
    
    ArenaAnalyticsScrollFrame.filterCompsDropdown = {}
    ArenaAnalyticsScrollFrame.filterEnemyCompsDropdown = {}

    HybridScrollFrame_SetDoNotHideScrollBar(ArenaAnalyticsScrollFrame.ListScrollFrame, true);
    ArenaAnalyticsScrollFrame.Bg:SetTexture(nil);
    ArenaAnalyticsScrollFrame.Bg:SetColorTexture(0, 0, 0, 0.8);
    
    ArenaAnalyticsScrollFrame.TitleBg:SetColorTexture(0,0,0,0.8);

    -- Add the addon title to the main frame
    ArenaAnalyticsScrollFrame.title = ArenaAnalyticsScrollFrame:CreateFontString(nil, "OVERLAY");
    ArenaAnalyticsScrollFrame.title:SetPoint("CENTER", ArenaAnalyticsScrollFrame.TitleBg, "CENTER", 0, 0);
    ArenaAnalyticsScrollFrame.title:SetFont("Fonts\\FRIZQT__.TTF", 12, "");
    ArenaAnalyticsScrollFrame.title:SetText("Arena Analytics");

    -- Add the version to the main frame header
    ArenaAnalyticsScrollFrame.titleVersion = ArenaAnalyticsScrollFrame:CreateFontString(nil, "OVERLAY");
    ArenaAnalyticsScrollFrame.titleVersion:SetPoint("CENTER", ArenaAnalyticsScrollFrame.TitleBg, "CENTER", 75, 0);
    ArenaAnalyticsScrollFrame.titleVersion:SetFont("Fonts\\FRIZQT__.TTF", 11, "");
    ArenaAnalyticsScrollFrame.titleVersion:SetText("|cff909090v" .. ArenaAnalytics:GetVersion() .. "|r");

    ArenaAnalyticsScrollFrame.teamBg = CreateFrame("Frame", nil, ArenaAnalyticsScrollFrame)
    ArenaAnalyticsScrollFrame.teamBg:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.TitleBg, "TOPLEFT", 340, -90);
    ArenaAnalyticsScrollFrame.teamBg:SetFrameStrata("LOW");
    ArenaAnalyticsScrollFrame.teamBg:SetSize(270, 413);
    
    ArenaAnalyticsScrollFrame.teamBgT = ArenaAnalyticsScrollFrame:CreateTexture()
    ArenaAnalyticsScrollFrame.teamBgT:SetColorTexture(0, 0, 0, 0.3)
    ArenaAnalyticsScrollFrame.teamBgT:SetSize(270, 413);
    ArenaAnalyticsScrollFrame.teamBgT:SetPoint("CENTER", ArenaAnalyticsScrollFrame.teamBg, "CENTER");

    ArenaAnalyticsScrollFrame.searchBox = CreateFrame("EditBox", "searchBox", ArenaAnalyticsScrollFrame, "SearchBoxTemplate")
    ArenaAnalyticsScrollFrame.searchBox:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame, "TOPLEFT", 35, -44);
    ArenaAnalyticsScrollFrame.searchBox:SetSize(225, 25);
    ArenaAnalyticsScrollFrame.searchBox:SetAutoFocus(false);
    ArenaAnalyticsScrollFrame.searchBox:SetMaxBytes(1024);

    local searchTitle = Options:Get("searchDefaultExplicitEnemy") and "Enemy Search" or "Search";
    CreateFilterTitle(ArenaAnalyticsScrollFrame.searchBox, searchTitle, nil, -5);
    
    ArenaAnalyticsScrollFrame.searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus();
        Search:CommitSearch(self:GetText());
    end);

    ArenaAnalyticsScrollFrame.searchBox:SetScript("OnEscapePressed", function(self) 
        self:SetText(Search:GetLastDisplay());
        self:ClearFocus();
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

    -- Filter Bracket Dropdown
    ArenaAnalyticsScrollFrame.filterBracketDropdown = nil;
    ArenaAnalyticsScrollFrame.filterBracketDropdown = Dropdown:Create(ArenaAnalyticsScrollFrame, "Simple", "FilterBracket", FilterTables.brackets, 55, 25);
    ArenaAnalyticsScrollFrame.filterBracketDropdown:SetPoint("LEFT", ArenaAnalyticsScrollFrame.searchBox, "RIGHT", 10, 0);

    CreateFilterTitle(ArenaAnalyticsScrollFrame.filterBracketDropdown, "Bracket");

    AAtable:CreateDropdownForFilterComps(false); -- isEnemyComp == false
    AAtable:CreateDropdownForFilterComps(true);

    ArenaAnalyticsScrollFrame.settingsButton = CreateFrame("Button", nil, ArenaAnalyticsScrollFrame, "GameMenuButtonTemplate");
    ArenaAnalyticsScrollFrame.settingsButton:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame, "TOPRIGHT", -46, -1);
    ArenaAnalyticsScrollFrame.settingsButton:SetText([[|TInterface\Buttons\UI-OptionsButton:0|t]]);
    ArenaAnalyticsScrollFrame.settingsButton:SetNormalFontObject("GameFontHighlight");
    ArenaAnalyticsScrollFrame.settingsButton:SetHighlightFontObject("GameFontHighlight");
    ArenaAnalyticsScrollFrame.settingsButton:SetSize(24, 19);
    ArenaAnalyticsScrollFrame.settingsButton:SetScript("OnClick", function()
        local enableOldSettings = false;
        if not enableOldSettings then
            Options:Open();
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
    ArenaAnalyticsScrollFrame.dateTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame,"TOPLEFT", ArenaAnalyticsScrollFrame, "TOPLEFT", 30, -75, "Date");
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
    
    AAtable:TryStartSessionDurationTimer();

    ArenaAnalyticsScrollFrame.clearSelected = AAtable:CreateButton("BOTTOMRIGHT", ArenaAnalyticsScrollFrame, "BOTTOMRIGHT", -30, 10, "Clear Selected", AAtable:GetDropdownTemplate());
    ArenaAnalyticsScrollFrame.clearSelected:SetWidth(110)
    ArenaAnalyticsScrollFrame.clearSelected:Hide();
    ArenaAnalyticsScrollFrame.clearSelected:SetScript("OnClick", function() Selection:ClearSelectedMatches() end);
    
    ArenaAnalyticsScrollFrame.unsavedWarning = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame, "BOTTOMRIGHT", ArenaAnalyticsScrollFrame, "BOTTOMRIGHT", -160, 13, unsavedWarningText);
    ArenaAnalyticsScrollFrame.unsavedWarning:Hide();
    ArenaAnalyticsScrollFrame.unsavedWarning:Show();

    -- First time user import popup if no matches are stored
    if (not ArenaAnalytics:HasStoredMatches()) then
        AAtable:TryShowimportDialogFrame(ArenaAnalyticsScrollFrame);
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
        Dropdown:CloseAll();
    end);

    ArenaAnalyticsScrollFrame.specFrames = {}
    ArenaAnalyticsScrollFrame.deathFrames = {}

    HybridScrollFrame_CreateButtons(ArenaAnalyticsScrollFrame.ListScrollFrame, "ArenaAnalyticsScrollListMatch");

    ArenaAnalyticsScrollFrame.moreFiltersDrodown = Dropdown:Create(ArenaAnalyticsScrollFrame, "Comp", "MoreFilters", FilterTables.moreFilters, 90, 25);
    ArenaAnalyticsScrollFrame.moreFiltersDrodown:SetPoint("LEFT", ArenaAnalyticsScrollFrame.filterEnemyCompsDropdown:GetFrame(), "RIGHT", 10, 0);
    
    ArenaAnalyticsScrollFrame.filterBtn_ClearFilters = AAtable:CreateButton("LEFT", ArenaAnalyticsScrollFrame.moreFiltersDrodown:GetFrame(), "RIGHT", 10, 0, "Clear", AAtable:GetDropdownTemplate());
    ArenaAnalyticsScrollFrame.filterBtn_ClearFilters:SetWidth(50);

    -- Clear all filters
    ArenaAnalyticsScrollFrame.filterBtn_ClearFilters:SetScript("OnClick", function() 
        ArenaAnalytics:Log("Clearing filters..");
        Filters:ResetAll(IsShiftKeyDown());
    end);
    
    -- Active Filters text count
    ArenaAnalyticsScrollFrame.activeFilterCountText = ArenaAnalyticsScrollFrame.moreFiltersDrodown:GetFrame():CreateFontString(nil, "OVERLAY")
    ArenaAnalyticsScrollFrame.activeFilterCountText:SetFont("Fonts\\FRIZQT__.TTF", 10, "");
    ArenaAnalyticsScrollFrame.activeFilterCountText:SetPoint("BOTTOM", ArenaAnalyticsScrollFrame.filterBtn_ClearFilters, "TOP", 0, 5);
    ArenaAnalyticsScrollFrame.activeFilterCountText:SetText("");

    hasLoaded = true;

    -- This will also update UI
    Filters:Refresh();

    -- Default to hidden
    ArenaAnalyticsScrollFrame:Hide();
end

function AAtable:TryShowimportDialogFrame(parent)
    if(true) then -- TODO: Implement updated import/export
        return;
    end

    if(ArenaAnalyticsScrollFrame.importDialogFrame == nil) then
        ArenaAnalyticsScrollFrame.importDialogFrame = CreateFrame("Frame", "ArenaAnalyticsImportFrame", parent or UIParent, "BasicFrameTemplateWithInset")
        ArenaAnalyticsScrollFrame.importDialogFrame:SetPoint("CENTER")
        ArenaAnalyticsScrollFrame.importDialogFrame:SetSize(475, 145)
        ArenaAnalyticsScrollFrame.importDialogFrame:SetFrameStrata("DIALOG");
        ArenaAnalyticsScrollFrame.importDialogFrame.title = ArenaAnalyticsScrollFrame.importDialogFrame:CreateFontString(nil, "OVERLAY");
        ArenaAnalyticsScrollFrame.importDialogFrame.title:SetPoint("TOP", ArenaAnalyticsScrollFrame.importDialogFrame, "TOP", -10, -5);
        ArenaAnalyticsScrollFrame.importDialogFrame.title:SetFont("Fonts\\FRIZQT__.TTF", 12, "");
        ArenaAnalyticsScrollFrame.importDialogFrame.title:SetText("Import");
        ArenaAnalyticsScrollFrame.importDialogFrame.Text1 = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.importDialogFrame, "CENTER", ArenaAnalyticsScrollFrame.importDialogFrame, "TOP", 0, -45, "Paste the ArenaStats or ArenaAnalytics export on the text box below.");
        ArenaAnalyticsScrollFrame.importDialogFrame.Text2 = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.importDialogFrame, "CENTER", ArenaAnalyticsScrollFrame.importDialogFrame, "TOP", 0, -65, "|cffCCCCCCNote:|r |cff888888Matches with missing specs detected won't show on comp filters.|r");
            
        ArenaAnalyticsScrollFrame.importDialogFrame.button = AAtable:CreateButton("TOPRIGHT", ArenaAnalyticsScrollFrame.importDialogFrame, "TOPRIGHT", -45, -80, "Import");
        ArenaAnalyticsScrollFrame.importDialogFrame.button:SetSize(115, 25);
        
        -- Import Edit Box
        ArenaAnalyticsScrollFrame.importDialogFrame.editbox = ImportBox:Create(parent, "ImportDialogBox", 255, 55);
        ArenaAnalyticsScrollFrame.importDialogFrame.editbox:SetPoint("RIGHT", ArenaAnalyticsScrollFrame.importDialogFrame.button, "LEFT", -10, 0);

        ArenaAnalyticsScrollFrame.importDataText3 = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.importDialogFrame, "CENTER", ArenaAnalyticsScrollFrame.importDialogFrame, "BOTTOM", 0, 25, "|cffff0000Do this NOW|r You won't be able to do this while you have stored arenas!");

        ArenaAnalyticsScrollFrame.importDialogFrame.button:SetScript("OnClick", function (i)
            ArenaAnalyticsScrollFrame.importDialogFrame.button:Disable();
            Import:parseRawData(ArenaImportPasteStringTable);
            ArenaImportPasteStringTable = {};
        end);
    end

    ArenaAnalyticsScrollFrame.importDialogFrame:SetParent(parent or UIParent);

    ArenaAnalyticsScrollFrame.importDialogFrame.button:Enable();
    ArenaAnalyticsScrollFrame.importDialogFrame:Show();
end

-- Creates the Export DB frame
function AAtable:CreateExportDialogFrame()
    if (not ArenaAnalytics:HasStoredMatches() or true) then -- TODO: Implement updated import/export
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
		ArenaAnalyticsScrollFrame.exportDialogFrame.totalText = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.exportDialogFrame,"TOPLEFT", ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame, "BOTTOMLEFT", -3, 0, "Total arenas: " .. #ArenaAnalyticsDB);
		ArenaAnalyticsScrollFrame.exportDialogFrame.lengthText = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.exportDialogFrame,"TOPRIGHT", ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame, "BOTTOMRIGHT", -3, 0, "Export length: 0");

		ArenaAnalyticsScrollFrame.exportDialogFrame.selectBtn = AAtable:CreateButton("BOTTOM", ArenaAnalyticsScrollFrame.exportDialogFrame, "BOTTOM", 0, 17, "Select All");
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
            ArenaAnalytics:Log("Garbage Collection forced by export frame.");
		end);
	end
    
    ArenaAnalyticsScrollFrame.exportDialogFrame:Show();
end

-- TODO: Consider using ArenaIcon to draw the class and spec icons.
local function setupTeamPlayerFrames(teamPlayerFrames, match, matchIndex, isEnemyTeam, scrollEntry)
    if(not match) then
        return;
    end

    for i = 1, #teamPlayerFrames do
        local playerFrame = teamPlayerFrames[i];
        assert(playerFrame);

        local player = ArenaMatch:GetPlayer(match, isEnemyTeam, i);
        local playerInfo = ArenaMatch:GetPlayerInfo(player, playerFrame.playerInfo);
        if (playerInfo) then
            playerFrame.playerInfo = playerInfo;

            if (playerFrame.texture == nil) then
                -- No textures? Set them
                playerFrame.texture = playerFrame:CreateTexture();
                playerFrame.texture:SetPoint("LEFT", playerFrame ,"RIGHT", -26, 0);
                playerFrame.texture:SetSize(26,26);
            end

            -- Set texture
            playerFrame.texture:SetTexture(Internal:GetClassIcon(playerInfo.spec_id) or 134400);
            playerFrame.tooltip = "";

            -- Add spec info
            if (not playerFrame.specOverlay) then
                playerFrame.specOverlay = CreateFrame("Frame", nil, playerFrame);
                playerFrame.specOverlay:SetPoint("BOTTOMRIGHT", playerFrame, "BOTTOMRIGHT");
                playerFrame.specOverlay:SetSize(12,12);
                
                playerFrame.specOverlay.texture = playerFrame.specOverlay:CreateTexture();
                playerFrame.specOverlay.texture:SetPoint("CENTER");
                playerFrame.specOverlay.texture:SetSize(12,12);
            end

            local specIcon = Constants:GetSpecIcon(playerInfo.spec_id);
            playerFrame.specOverlay.texture:SetTexture(specIcon or "");

            if (not Options:Get("alwaysShowSpecOverlay")) then
                playerFrame.specOverlay:Hide();
            end

            -- Add death overlay            
            if (ArenaMatch:IsPlayerFirstDeath(player)) then
                if (not playerFrame.deathOverlay) then
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
            elseif (playerFrame.deathOverlay) then
                playerFrame.deathOverlay:Hide();
            end

            playerFrame:SetScript("OnEnter", function(self)
                Tooltips:DrawPlayerTooltip(self);
            end);
            playerFrame:SetScript("OnLeave", function()
                Tooltips:HidePlayerTooltip();
            end);

            -- Quick Search
            playerFrame:RegisterForClicks("LeftButtonDown", "RightButtonDown");
            playerFrame:SetScript("OnClick", function(self, btn)
                Search:QuickSearch(self, btn);
            end);

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
        local playerFrame = matchData[i];
        assert(playerFrame);

        if (playerFrame.specOverlay) then
            if (visible or Options:Get("alwaysShowSpecOverlay")) then
                playerFrame.specOverlay:Show();
            else
                playerFrame.specOverlay:Hide();
            end
        end

        if (playerFrame.deathOverlay) then
            local isFirstDeath = playerFrame.playerInfo and playerFrame.playerInfo.isFirstDeath;
            if (isFirstDeath and (visible or Options:Get("alwaysShowDeathOverlay"))) then
                playerFrame.deathOverlay:Show();
            else
                playerFrame.deathOverlay:Hide();
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
        local delta = isOddSession and -0.07 or 0.07;
        alpha = alpha + delta;
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
function AAtable:CreateDropdownForFilterComps(isEnemyComp)
    local config = isEnemyComp and FilterTables.enemyComps or FilterTables.comps;
    local frameName = isEnemyComp and "FitlerEnemyComp" or "FilterComp";
    local newDropdown = Dropdown:Create(ArenaAnalyticsScrollFrame, "Comp", frameName, config, 235, 25);
    local relativeFrame = isEnemyComp and ArenaAnalyticsScrollFrame.filterCompsDropdown or ArenaAnalyticsScrollFrame.filterBracketDropdown;
    newDropdown:SetPoint("LEFT", relativeFrame:GetFrame(), "RIGHT", 10, 0);
        
    local title = isEnemyComp and "Enemy Comp" or "Comp"
    local info = nil;
    if(Options:Get("showCompDropdownInfoText")) then
        info = Options:Get("compDisplayAverageMmr") and "Games || Comp || Winrate || mmr" or "Games || Comp || Winrate";
    end
    
    CreateFilterTitle(newDropdown, title, info);
    

    if(isEnemyComp) then
        ArenaAnalyticsScrollFrame.filterEnemyCompsDropdown = newDropdown;
    else
        ArenaAnalyticsScrollFrame.filterCompsDropdown = newDropdown;
    end
end

-- Forcefully clear and recreate the comp filters for new filters. Optionally staying visible.
function AAtable:ForceRefreshFilterDropdowns()
    if(not hasLoaded) then
        ArenaAnalytics:Log("ForceRefresh called before OnLoad. Skipped.");
        return;
    end

    ArenaAnalyticsScrollFrame.filterBracketDropdown:Refresh();
    ArenaAnalyticsScrollFrame.filterCompsDropdown:Refresh();
    ArenaAnalyticsScrollFrame.filterEnemyCompsDropdown:Refresh();
end

function AAtable:CheckUnsavedWarningThreshold()
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
function AAtable:HandleArenaCountChanged()
    if(not hasLoaded) then
        -- Load will trigger call soon
        return;
    end

    Options:TriggerStateUpdates()
    AAtable:RefreshLayout();

    if(not ArenaAnalytics:HasStoredMatches() and ArenaAnalyticsScrollFrame.exportDialogFrame) then
        ArenaAnalyticsScrollFrame.exportDialogFrame:Hide();
    end

    wins, sessionGames, sessionWins = 0,0,0;
    -- Update arena count & winrate
    for i=ArenaAnalytics.filteredMatchCount, 1, -1 do
        local match, filteredSession = ArenaAnalytics:GetFilteredMatch(i);
        if(match) then 
            if(ArenaMatch:IsVictory(match)) then 
                wins = wins + 1; 
            end
            
            if (filteredSession == 1) then
                sessionGames = sessionGames + 1;
                if (ArenaMatch:IsVictory(match)) then
                    sessionWins = sessionWins + 1;
                end
            end
        end
    end

    -- Update displayed session stats text
    local _, expired = ArenaAnalytics:GetLatestSession();
    local sessionText = expired and "Last session: " or "Current session: ";
    sessionText = colorText(sessionText, bottomStatsPrefixColor);
    local winrateText = sessionGames > 0 and math.floor(sessionWins * 100 / sessionGames) or 0;
    local winsText =  "|cff00cc66" .. sessionWins .. "|r";
    local lossesText =  "|cffff0000" .. (sessionGames - sessionWins) .. "|r";

    local arenaText = " arena" .. (sessionGames ~= 1 and "s" or "");
    ArenaAnalyticsScrollFrame.sessionStats:SetText(sessionText .. sessionGames .. arenaText .. "   " .. winsText .. " / " .. lossesText .. "  " .. winrateText .. "% Winrate");

    -- Update the 
    local totalArenas = ArenaAnalytics.filteredMatchCount;
    local winrate = totalArenas > 0 and math.floor(wins * 100 / totalArenas) or 0;
    local winsColoured =  "|cff00cc66" .. wins .. "|r";
    local lossesColoured =  "|cffff0000" .. (totalArenas - wins) .. "|r";
    local text = colorText("Filtered total: ", bottomStatsPrefixColor);
    ArenaAnalyticsScrollFrame.totalArenaNumber:SetText(text .. totalArenas .. " arena" .. (totalArenas ~= 1 and "s" or ""));
    ArenaAnalyticsScrollFrame.winrate:SetText(winsColoured .. " / " .. lossesColoured .. "   " .. winrate .. "% Winrate");

    AAtable.CheckUnsavedWarningThreshold();
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
        local matchIndex = ArenaAnalytics.filteredMatchCount - (buttonIndex + offset - 1);

        local match, filteredSession = ArenaAnalytics:GetFilteredMatch(matchIndex);
        if (match ~= nil) then
            setColorForSession(button, filteredSession, matchIndex);

            local matchDate = ArenaMatch:GetDate(match);
            local map = ArenaMatch:GetMap(match);
            local duration = ArenaMatch:GetDuration(match);

            button.Date:SetText(matchDate and date("%d/%m/%y %H:%M:%S", matchDate) or "");
            button.Map:SetText(map or "");
            button.Duration:SetText(duration and SecondsToTime(duration) or "");

            local teamIconsFrames = {button.Team1, button.Team2, button.Team3, button.Team4, button.Team5}
            local enemyTeamIconsFrames = {button.EnemyTeam1, button.EnemyTeam2, button.EnemyTeam3, button.EnemyTeam4, button.EnemyTeam5}
            
            -- Setup player class frames
            setupTeamPlayerFrames(teamIconsFrames, match, matchIndex, false, button);
            setupTeamPlayerFrames(enemyTeamIconsFrames, match, matchIndex, true, button);

            -- Paint winner green, loser red
            local won = ArenaMatch:IsVictory(match);            
            local hex = nil;
            if(won == nil) then
                hex = "ff999999";
            else
                hex = won and "ff00cc66" or "ffff0000";
            end

            -- Party Rating & Delta
            local rating, ratingDelta = ArenaMatch:GetPartyRating(match), ArenaMatch:GetPartyRatingDelta(match);
            local ratingText = ratingToText(rating, ratingDelta) or "SKIRMISH";
            button.Rating:SetText("|c" .. hex .. ratingText .."|r");
            
            -- Party MMR
            button.MMR:SetText(ArenaMatch:GetPartyMMR(match) or "-");

            -- Enemy Rating & Delta
            local enemyRating, enemyRatingDelta = ArenaMatch:GetEnemyRating(match), ArenaMatch:GetEnemyRatingDelta(match);
            local enemyRatingText = ratingToText(enemyRating, enemyRatingDelta) or "-";
            button.EnemyRating:SetText(enemyRatingText);

            -- Enemy team MMR
            button.EnemyMMR:SetText(ArenaMatch:GetEnemyMMR(match) or "-");

            button:SetAttribute("won", ArenaMatch:IsVictory(match));

            local isSelected = Selection:isMatchSelected(matchIndex);
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
                    Selection:handleMatchEntryClicked(key, false, matchIndex);
                end
            end);

            button:SetScript("OnDoubleClick", function(args, key)
                Selection:handleMatchEntryClicked(key, true, matchIndex);
            end);

            AAtable:ToggleSpecsAndDeathOverlay(button);

            button:SetWidth(ArenaAnalyticsScrollFrame.ListScrollFrame.scrollChild:GetWidth());
            button:Show();
        else
            button:Hide();
        end
    end

    -- Adjust Team bg
    if (ArenaAnalytics.filteredMatchCount < 15) then
        local newHeight = (ArenaAnalytics.filteredMatchCount * 28) - 1;
        ArenaAnalyticsScrollFrame.teamBgT:SetHeight(newHeight);
        ArenaAnalyticsScrollFrame.teamBg:SetHeight(newHeight);
    else
        ArenaAnalyticsScrollFrame.teamBgT:SetHeight(413);
        ArenaAnalyticsScrollFrame.teamBg:SetHeight(413);
    end

    local buttonHeight = ArenaAnalyticsScrollFrame.ListScrollFrame.buttonHeight;
    local totalHeight = ArenaAnalytics.filteredMatchCount * buttonHeight;
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
    local _,expired, startTime, endTime = ArenaAnalytics:GetLatestSessionStartAndEndTime();

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

function AAtable:TryStartSessionDurationTimer()
    local _,expired, startTime, endTime = ArenaAnalytics:GetLatestSessionStartAndEndTime();
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