local _, ArenaAnalytics = ...; -- Namespace
ArenaAnalytics.Options = {};
local Options = ArenaAnalytics.Options;

-- TODO: Consider making some settings character specific (For cases like one char having lots of games desiring different comp filter limits)
-- User settings
ArenaAnalyticsSettings = ArenaAnalyticsSettings and ArenaAnalyticsSettings or {};

-- Adds a setting that 
local function AddSetting(setting, default)
    ArenaAnalyticsSettings[setting] = ArenaAnalyticsSettings[setting] ~= nil and ArenaAnalyticsSettings[setting] or default;
end

-- Adds a setting that does not save across reloads. (Use with caution)
local function AddTransientSetting(setting, default)
    ArenaAnalyticsSettings[setting] = default;
end

function Options:LoadSettings()
    AddSetting("outliers", 0);
    AddSetting("dropdownVisibileLimit", 10);
    AddSetting("defaultCurrentSeasonFilter", false);
    AddSetting("defaultCurrentSessionFilter", false);
    AddSetting("showSkirmish", false);
    AddSetting("alwaysShowDeathOverlay", false);
    AddSetting("alwaysShowSpecOverlay", false);
    AddSetting("unsavedWarningThreshold", 10);
    AddSetting("showSelectedCompStats", false);
    AddSetting("sortCompFilterByTotalPlayed", false);
    AddSetting("selectionControlModInversed", false);
    AddSetting("allowImportDataMerge", false);
end

-- Gets a setting, regardless of location between 
function Options:GetSetting(setting)
    assert(setting ~= nil);

    local value = ArenaAnalyticsSettings[setting];
    if(value == nil) then
        ArenaAnalytics:Log("Attempted to get setting: ", setting, " but got nil result.");
    end
end

local exportOptionsFrame = nil;
local ArenaAnalyticsOptionsFrame = nil;

function Options:TriggerStateUpdates()
    if(exportOptionsFrame and exportOptionsFrame.importButton and exportOptionsFrame.importButton.stateFunc) then
        exportOptionsFrame.importButton.stateFunc();
    end        
end


local TabTitleSize = 18;
local TabHeaderSize = 16;
local GroupHeaderSize = 14;
local TextSize = 12;

local OptionsSpacing = 10;

-- Offset to use while creating settings tabs
local offsetY = 0;

function Options:Open()
    if(ArenaAnalyticsOptionsFrame) then
        InterfaceOptionsFrame_OpenToCategory(ArenaAnalyticsOptionsFrame);
        InterfaceOptionsFrame_OpenToCategory(ArenaAnalyticsOptionsFrame);
    end
end

-------------------------------------------------------------------
-- Standardized Updated Option Response Functions
-------------------------------------------------------------------

local function HandleFiltersUpdated()
    ArenaAnalytics.Filter:resetFilters(false);
    ArenaAnalytics.Filter:refreshFilters();
    ArenaAnalytics.AAtable:forceCompFilterRefresh();
end

-------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------

local function SetupTooltip(owner, frames)
    assert(owner ~= nil);

    frames = frames or owner;
    frames = (type(frames) == "table" and frames or { frames });

    for i,frame in ipairs(frames) do
        frame:SetScript("OnEnter", function ()
            if(owner.tooltip) then
                ArenaAnalytics.Tooltips:DrawOptionTooltip(owner, owner.tooltip);
            end
        end);

        frame:SetScript("OnLeave", function ()
            if(owner.tooltip) then
                GameTooltip:Hide();
            end
        end);
    end
end

local function InitializeTab(parent)
    local addonNameText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    addonNameText:SetPoint("TOPLEFT", parent, "TOPLEFT", -5, 32)
    addonNameText:SetTextHeight(TabTitleSize);
    addonNameText:SetText("Arena|cff00ccffAnalytics|r   |cff666666v" .. ArenaAnalytics:getVersion() .. "|r");
    
    -- Reset Y offset
    offsetY = 0;
end

local function createSpace(explicit)
    offsetY = offsetY - max(0, explicit or 25)
end

local function createHeader(text, size, parent, relative, x, y, icon)
    local frame = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame:SetPoint("TOPLEFT", relative or parent, "TOPLEFT", x, y)
    frame:SetTextHeight(size);
    frame:SetText(text);

    offsetY = offsetY - OptionsSpacing - frame:GetHeight() + y;

    return frame;
end

local function CreateButton(setting, parent, x, width, text, func)
    assert(type(func) == "function");

    -- Create the button
    local button = CreateFrame("Button", "ArenaAnalyticsButton_" .. (setting or text or ""), parent, "UIPanelButtonTemplate")
    
    -- Set the button's position
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, offsetY);
    
    -- Set the button's size and text
    button:SetSize(width or 120, 30)
    button:SetText(text)
    
    -- Add a script for the button's click action
    button:SetScript("OnClick", function()
        func(setting);
    end)

    SetupTooltip(button, nil);

    offsetY = offsetY - button:GetHeight() - OptionsSpacing;

    return button;
end

local function createCheckbox(setting, parent, x, text, func)
    assert(setting ~= nil);
    assert(type(setting) == "string");

    local checkbox = CreateFrame("CheckButton", "ArenaAnalyticsScrollFrame_"..setting, parent, "OptionsSmallCheckButtonTemplate");
    
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, offsetY);

    checkbox.text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    checkbox.text:SetPoint("LEFT", checkbox, "RIGHT", 5);
    checkbox.text:SetTextHeight(TextSize);
    checkbox.text:SetText(text);

    checkbox:SetChecked(ArenaAnalyticsSettings[setting]);

    checkbox:SetScript("OnClick", function()
		ArenaAnalyticsSettings[setting] = checkbox:GetChecked();
        
        if(func) then
            func(setting);
        else
            HandleFiltersUpdated();
        end

		ArenaAnalytics:Log(setting .. ": ", ArenaAnalyticsSettings[setting]);
	end);

    SetupTooltip(checkbox, {checkbox, checkbox.text});

    offsetY = offsetY - OptionsSpacing - checkbox:GetHeight() + 10;

    return checkbox;
end

local function createInputBox(setting, parent, x, text, func)
    offsetY = offsetY - 2; -- top padding

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
		local oldValue = tonumber(ArenaAnalyticsSettings[setting]) or 25;
		local newValue = tonumber(inputBox:GetText());
        ArenaAnalyticsSettings[setting] = newValue or oldValue;
		inputBox:SetText(tonumber(ArenaAnalyticsSettings[setting]));
        inputBox:SetCursorPosition(0);
		inputBox:HighlightText(0,0);
        
		ArenaAnalytics.AAtable:checkUnsavedWarningThreshold();

        ArenaAnalytics:Log("Setting ", setting, " changed to: ", newValue, ". Old value: ", oldValue);
    end);

    SetupTooltip(inputBox, {inputBox, inputBox.text});

    if(func) then
        func(setting);
    else
        HandleFiltersUpdated();
    end

    offsetY = offsetY - OptionsSpacing - inputBox:GetHeight() + 5;

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
    parent.showDeathOverlay = createCheckbox("alwaysShowSpecOverlay", parent, offsetX, "Always show spec (Otherwise mouseover only)");
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
    parent.defaultCurrentSeasonFilter = createCheckbox("defaultCurrentSeasonFilter", parent, offsetX, "Apply current season filter by default.");
    parent.defaultCurrentSessionFilter = createCheckbox("defaultCurrentSessionFilter", parent, offsetX, "Apply latest session only by default.");
    
    createSpace();
    
    parent.showSkirmish = createCheckbox("showSkirmish", parent, offsetX, "Show Skirmish in match history.");
    
    createSpace();
    
    parent.compFilterSortByTotal = createCheckbox("sortCompFilterByTotalPlayed", parent, offsetX, "Sort comp filter dropdowns by total played.");
    parent.showSelectedCompStats = createCheckbox("showSelectedCompStats", parent, offsetX, "Show played and winrate for selected comp in filters.");
    parent.unsavedWarning = createInputBox("outliers", parent, offsetX, "Minimum games required to appear on comp filter.");
    parent.unsavedWarning = createInputBox("dropdownVisibileLimit", parent, offsetX, "Maximum comp dropdown entries visible.");
end

-------------------------------------------------------------------
-- Import/Export Options Tab
-------------------------------------------------------------------
function setupTab_ImportExport()
    exportOptionsFrame = CreateFrame("frame");
    exportOptionsFrame.name = "Import / Export";
    exportOptionsFrame.parent = ArenaAnalyticsOptionsFrame.name;
    InterfaceOptions_AddCategory(exportOptionsFrame);

    InitializeTab(exportOptionsFrame);
    local parent = exportOptionsFrame;
    local offsetX = 20;

    parent.tabHeader = createHeader("Import / Export", TabHeaderSize, parent, nil, 15, -15);

    parent.exportButton = CreateButton(nil, parent, offsetX, 120, "Export", function() ArenaAnalytics.Export:combineExportCSV() end);
    
    createSpace();

    -- Import button (Might want an option at some point for whether we'll allow importing to merge with existing entries)
    parent.importButton = CreateButton(nil, parent, offsetX, 120, "Import", function() ArenaAnalytics.AAtable:tryShowimportDialogFrame() end);
    parent.importButton.stateFunc = function()
        if(ArenaAnalyticsSettings["allowImportDataMerge"] or not ArenaAnalytics:hasStoredMatches()) then
            exportOptionsFrame.importButton:Enable();
        else
            exportOptionsFrame.importButton:Disable();
        end
    end
    parent.importButton.stateFunc();

    parent.importAllowMerge = createCheckbox("allowImportDataMerge", parent, offsetX, "Allow Import Merge", function()
        parent.importButton.stateFunc();
    end);
    parent.importAllowMerge.tooltip = { "Allow Import Merge", "Enables importing with stored matches.\nThis will add matches before and after already stored matches.\n\n|cffff0000Untested! - Use at own risk.|r\nBackup SavedVariables recommended." }

    
    exportOptionsFrame:SetScript("OnShow", function() parent.importButton.stateFunc() end);
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
        setupTab_ImportExport();
    end
end