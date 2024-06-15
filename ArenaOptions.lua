local _, ArenaAnalytics = ...; -- Namespace
ArenaAnalytics.Options = {};
local Options = ArenaAnalytics.Options;

ArenaAnalyticsOptionsFrame = nil;

local TabTitleSize = 18;
local TabHeaderSize = 16;
local GroupHeaderSize = 14;
local TextSize = 12;

local OptionsSpacing = 25;

-- Offset to use while creating settings tabs
local offsetY = 0;

function Options:Open()
    if(ArenaAnalyticsOptionsFrame and ArenaAnalyticsOptionsFrame.name) then
        InterfaceOptionsFrame_OpenToCategory(ArenaAnalyticsOptionsFrame.name);
        InterfaceOptionsFrame_OpenToCategory(ArenaAnalyticsOptionsFrame.name);
    end
end

-------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------

local function InitializeTab(parent)
    local addonNameText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    addonNameText:SetPoint("TOPLEFT", parent, "TOPLEFT", -5, 32)
    addonNameText:SetTextHeight(TabTitleSize);
    addonNameText:SetText("Arena|cff00ccffAnalytics|r   |cff666666v" .. ArenaAnalytics:getVersion() .. "|r");
    
    --ArenaAnalytics:Print(addonNameText:GetLineHeight())

    -- Reset Y offset
    offsetY = 0;
end

local function createHeader(text, size, parent, relative, x, y, icon)
    local frame = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame:SetPoint("TOPLEFT", relative or parent, "TOPLEFT", x, y)
    frame:SetTextHeight(size);
    frame:SetText(text);

    offsetY = offsetY - size - OptionsSpacing;

    return frame;
end

local function createCheckbox(setting, parent, x, text, relative, isSingleLine)
    assert(setting ~= nil and type(setting) == "string");

    local checkbox = CreateFrame("CheckButton", "ArenaAnalyticsScrollFrame_"..setting, parent, "OptionsSmallCheckButtonTemplate");
    
    if isSingleLine and relative then
        _,_,_,_,relativeY = relative:GetPoint();
        checkbox:SetPoint("LEFT", relative or parent, "RIGHT", relative:GetWrappedWidth() + 5, relativeY);
    else
        checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, offsetY);
    end

    checkbox.text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    checkbox.text:SetPoint("LEFT", checkbox, "RIGHT", 5);
    checkbox.text:SetTextHeight(TextSize);
    checkbox.text:SetText(text);

    checkbox:SetChecked(ArenaAnalyticsSettings[setting]);

    checkbox:SetScript("OnClick", function()
		ArenaAnalyticsSettings[setting] = checkbox:GetChecked();
		ArenaAnalytics:Log("Show Previous Seasons: ", ArenaAnalyticsSettings[setting]);
		ArenaAnalytics.Filter:refreshFilters();
		ArenaAnalytics.AAtable:forceCompFilterRefresh();
	end);

    offsetY = offsetY - 25;

    return checkbox;
end

local function createInputBox(setting, parent, x, text)
    local inputBox = CreateFrame("EditBox", "exportFrameScroll", parent, "InputBoxTemplate");
    inputBox:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 8, offsetY);
    inputBox:SetWidth(50);
    inputBox:SetHeight(20);
    inputBox:SetNumeric();
    inputBox:SetAutoFocus(false);
    inputBox:SetMaxLetters(5);
    inputBox:SetText(tonumber(ArenaAnalyticsSettings[setting]));
    inputBox:SetCursorPosition(0);
    inputBox:HighlightText(0,0);    

    ArenaAnalytics:Print(ArenaAnalyticsSettings[setting])
    
    -- Text
    inputBox.text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    inputBox.text:SetPoint("LEFT", inputBox, "RIGHT", 50);
    inputBox.text:SetTextHeight(TextSize);
    inputBox.text:SetText(text);
    
    inputBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus();
    end);
	
    inputBox:SetScript("OnEscapePressed", function(self)
		inputBox:SetText(ArenaAnalyticsSettings[setting] or "");
        self:ClearFocus();
    end);

    inputBox:SetScript("OnEditFocusLost", function(self)
		local oldValue = tonumber(ArenaAnalyticsSettings[setting]) or 213;
		local newValue = tonumber(inputBox:GetText());
        ArenaAnalyticsSettings[setting] = newValue or oldValue;
		inputBox:SetText(tonumber(ArenaAnalyticsSettings[setting]));
        inputBox:SetCursorPosition(0);
		inputBox:HighlightText(0,0);
        
		ArenaAnalytics.AAtable:checkUnsavedWarningThreshold();
    end);

    offsetY = offsetY - OptionsSpacing;

    return inputBox;
end

-------------------------------------------------------------------
-- General Options
-------------------------------------------------------------------
function createTab_General()
    -- Title
    InitializeTab(ArenaAnalyticsOptionsFrame);
    local parent = ArenaAnalyticsOptionsFrame;
    local offsetX = 20;    

    parent.tabHeader = createHeader("General", TabHeaderSize, parent, nil, 15, -15);

    -- Setup options
    parent.showDeathOverlay = createCheckbox("alwaysShowDeathOverlay", parent, offsetX, "Always show death overlay (Otherwise mouseover only)");
    parent.unsavedWarning = createInputBox("unsavedWarningThreshold", parent, offsetX, "Unsaved games threshold before showing |cff00cc66/reload|r warning.");
end

-------------------------------------------------------------------
-- Filter Options Tab
-------------------------------------------------------------------
function setupTab_Filters()
    local filterOptionsFrame = CreateFrame("frame");
    filterOptionsFrame.name = "Filters";
    filterOptionsFrame.parent = ArenaAnalyticsOptionsFrame.name;
    InterfaceOptions_AddCategory(filterOptionsFrame);
    
    -- Title
    InitializeTab(filterOptionsFrame);
    local parent = filterOptionsFrame;
    local offsetX = 20;
    
    parent.tabHeader = createHeader("Filters", TabHeaderSize, parent, nil, 15, -15);

    -- Setup options
    parent.showSkirmish = createCheckbox("showSkirmish", parent, offsetX, "Show Skirmish");
    parent.defaultCurrentSeasonFilter = createCheckbox("defaultCurrentSeasonFilter", parent, offsetX, "Apply current season filter by default.");
    parent.defaultCurrentSessionFilter = createCheckbox("defaultCurrentSessionFilter", parent, offsetX, "Apply latest session only by default.");
    parent.compFilterSortByTotal = createCheckbox("sortCompFilterByTotalPlayed", parent, offsetX, "Sort comp filter dropdowns by total played.");

    parent.unsavedWarning = createInputBox("outliers", parent, offsetX, "Minimum games required to appear on comp filter");
    parent.unsavedWarning = createInputBox("compsLimit", parent, offsetX, "Maximum comps to appear in comp filter dropdowns (0 = unlimited)");
end

-------------------------------------------------------------------
-- Export Options Tab
-------------------------------------------------------------------
function setupTab_Export()
    local exportOptionsFrame = CreateFrame("frame");
    exportOptionsFrame.name = "Export";
    exportOptionsFrame.parent = ArenaAnalyticsOptionsFrame.name;
    InterfaceOptions_AddCategory(exportOptionsFrame);

    InitializeTab(exportOptionsFrame);
    local parent = exportOptionsFrame;

    parent.tabHeader = createHeader("Export", TabHeaderSize, parent, nil, 15, -15);

end

-------------------------------------------------------------------
-- Initialize Options Menu
-------------------------------------------------------------------
function Options.Initialzie()
    if not ArenaAnalyticsOptionsFrame then
        ArenaAnalyticsOptionsFrame = CreateFrame("Frame");
        ArenaAnalyticsOptionsFrame.name = "Arena|cff00ccffAnalytics|r";
        InterfaceOptions_AddCategory(ArenaAnalyticsOptionsFrame);

        -- Setup tabs
        createTab_General();
        setupTab_Filters();
    end
end