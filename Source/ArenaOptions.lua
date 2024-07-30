local _, ArenaAnalytics = ...; -- Addon Namespace
local Options = ArenaAnalytics.Options;

-- Local module aliases
local Filters = ArenaAnalytics.Filters;
local AAtable = ArenaAnalytics.AAtable;
local Tooltips = ArenaAnalytics.Tooltips;
local Export = ArenaAnalytics.Export;
local API = ArenaAnalytics.API;

-------------------------------------------------------------------------
-- Standardized Updated Option Response Functions

local function HandleSettingsChanged()
    ArenaAnalytics:Log("Settings changed..")
    Filters:ResetAll(false);
end

-------------------------------------------------------------------------


-- TODO: Consider making some settings character specific (For cases like one char having lots of games desiring different comp filter limits)
-- User settings
ArenaAnalyticsSettings = ArenaAnalyticsSettings or {};

-- Unused.
ArenaAnalyticsCharacterSettings = ArenaAnalyticsCharacterSettings or {}

local defaults = {};

-- Adds a setting with loaded or default value.
local function AddSetting(setting, default)
    assert(setting ~= nil);
    assert(default ~= nil, "Nil values for settings are not supported.");

    if(ArenaAnalyticsSettings[setting] == nil) then
        ArenaAnalyticsSettings[setting] = default;
    end
    assert(ArenaAnalyticsSettings[setting] ~= nil);

    -- Cache latest defaults
    defaults[setting] = default;
end

-- Adds a setting that does not save across reloads. (Use with caution)
local function AddTransientSetting(setting, default)
    ArenaAnalyticsSettings[setting] = default;
end

local hasOptionsLoaded = nil;
function Options:LoadSettings()
    if hasOptionsLoaded then return end;

    ArenaAnalytics:Log("Loading settings..");
    
    -- General
    AddSetting("unsavedWarningThreshold", 10);
    AddSetting("alwaysShowDeathOverlay", false);
    AddSetting("alwaysShowSpecOverlay", false);
    
    -- Filters
    AddSetting("defaultCurrentSeasonFilter", false);
    AddSetting("defaultCurrentSessionFilter", false);
    
    AddSetting("showSkirmish", false);

    AddSetting("showCompDropdownInfoText", true);

    AddSetting("sortCompFilterByTotalPlayed", false);
    AddSetting("compDisplayAverageMmr", true);
    AddSetting("showSelectedCompStats", false);

    AddSetting("outliers", 0); -- Minimum games to appear on comp dropdowns
    AddSetting("dropdownVisibileLimit", 10);
    
    -- Selection (NYI)
    AddSetting("selectionControlModInversed", false);
    
    -- Import/Export
    AddSetting("allowImportDataMerge", false);

    -- Search
    AddSetting("searchDefaultExplicitEnemy", false);
    AddSetting("searchHideTooltipQuickSearch", false);

    
    -- Quick Search
    AddSetting("quickSearchExcludeAnyRealm", false);
    AddSetting("quickSearchExcludeMyRealm", false);

    AddSetting("quickSearchShortcut_LMB", "Team");
    AddSetting("quickSearchShortcut_RMB", "Enemy");
    AddSetting("quickSearchShortcut_Nomod", "Name");
    AddSetting("quickSearchShortcut_Shift", "New Segment");
    AddSetting("quickSearchShortcut_Ctrl", "Spec");
    AddSetting("quickSearchShortcut_Alt", "Inverse");

    -- Debugging
    AddSetting("debuggingEnabled", false);

    hasOptionsLoaded = true;
    ArenaAnalytics:Log("Settings loaded successfully.");
    return true;
end

function Options:HasLoaded()
    return hasOptionsLoaded;
end

-- Gets a setting, regardless of location between 
function Options:Get(setting)
    assert(setting);

    if(hasOptionsLoaded == false) then
        ArenaAnalytics:Log("Force loaded settings to immediately get:", setting);
        local successful = Options:LoadSettings();
        if not successful then return end;
    end
    
    local value = ArenaAnalyticsSettings[setting];

    if(value == nil) then
        ArenaAnalytics:Log("Setting not found: ", setting, value)
        return nil;
    end

    return value;
end

function Options:Set(setting, value)
    assert(setting);

    if(hasOptionsLoaded == false) then
        ArenaAnalytics:Log("Force loaded settings to immediately set:", setting, " to value: ", value);
        local successful = Options:LoadSettings();
        if not successful then return end;
    end

    ArenaAnalyticsDebugAssert(ArenaAnalyticsSettings[setting] ~= nil, "Setting invalid option: " .. (setting or "nil"));
    
    if(setting and ArenaAnalyticsSettings[setting] ~= nil) then
        if(value == nil) then
            value = defaults[setting];
        end
        assert(value ~= nil);

        if(value == ArenaAnalyticsSettings[setting]) then
            return;
        end

        local oldValue = ArenaAnalyticsSettings[setting];
        ArenaAnalyticsSettings[setting] = value;
        ArenaAnalytics:Log("Setting option: ", setting, "new:", value, "old:", oldValue);
        
        HandleSettingsChanged();
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
-- Helper Functions
-------------------------------------------------------------------

local function SetupTooltip(owner, frames)
    assert(owner ~= nil);

    frames = frames or owner;
    frames = (type(frames) == "table" and frames or { frames });

    for i,frame in ipairs(frames) do
        frame:SetScript("OnEnter", function ()
            if(owner.tooltip) then
                Tooltips:DrawOptionTooltip(owner, owner.tooltip);
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

local function CreateSpace(explicit)
    offsetY = offsetY - max(0, explicit or 25)
end

local function CreateHeader(text, size, parent, relative, x, y, icon)
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
    local button = CreateFrame("Button", "ArenaAnalyticsButton_" .. (setting or text or ""), parent, "UIPanelButtonTemplate");
    
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

local function CreateCheckbox(setting, parent, x, text, func)
    assert(setting ~= nil);
    assert(type(setting) == "string");

    local checkbox = CreateFrame("CheckButton", "ArenaAnalyticsScrollFrame_"..setting, parent, "OptionsSmallCheckButtonTemplate");
    
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, offsetY);

    checkbox.text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    checkbox.text:SetPoint("LEFT", checkbox, "RIGHT", 5);
    checkbox.text:SetTextHeight(TextSize);
    checkbox.text:SetText(text);

    checkbox:SetChecked(Options:Get(setting));

    checkbox:SetScript("OnClick", function()
		Options:Set(setting, checkbox:GetChecked());
        
        if(func) then
            func(setting);
        end
	end);

    SetupTooltip(checkbox, {checkbox, checkbox.text});

    offsetY = offsetY - OptionsSpacing - checkbox:GetHeight() + 10;

    return checkbox;
end

local function CreateInputBox(setting, parent, x, text, func)
    offsetY = offsetY - 2; -- top padding

    local inputBox = CreateFrame("EditBox", "exportFrameScroll", parent, "InputBoxTemplate");
    inputBox:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 8, offsetY);
    inputBox:SetWidth(50);
    inputBox:SetHeight(20);
    inputBox:SetNumeric();
    inputBox:SetAutoFocus(false);
    inputBox:SetMaxLetters(5);
    inputBox:SetText(tonumber(Options:Get(setting)));
    inputBox:SetCursorPosition(0);
    inputBox:HighlightText(0,0);    
    
    -- Text
    inputBox.text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    inputBox.text:SetPoint("LEFT", inputBox, "RIGHT", 5, 0);
    inputBox.text:SetTextHeight(TextSize);
    inputBox.text:SetText(text);
    
    inputBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus();
    end);
	
    inputBox:SetScript("OnEscapePressed", function(self)
		inputBox:SetText(Options:Get(setting) or "");
        self:ClearFocus();
    end);

    inputBox:SetScript("OnEditFocusLost", function(self)
		local oldValue = tonumber(Options:Get(setting));
		local newValue = tonumber(inputBox:GetText());
        Options:Set(setting, newValue or oldValue)
		inputBox:SetText(tonumber(Options:Get(setting)));
        inputBox:SetCursorPosition(0);
		inputBox:HighlightText(0,0);
        
		AAtable:CheckUnsavedWarningThreshold();
    end);

    SetupTooltip(inputBox, {inputBox, inputBox.text});

    if(func) then
        func(setting);
    end

    offsetY = offsetY - OptionsSpacing - inputBox:GetHeight() + 5;

    return inputBox;
end

-------------------------------------------------------------------
-- General Tab
-------------------------------------------------------------------
function SetupTab_General()
    -- Title
    InitializeTab(ArenaAnalyticsOptionsFrame);
    local parent = ArenaAnalyticsOptionsFrame;
    local offsetX = 20;    

    parent.tabHeader = CreateHeader("General", TabHeaderSize, parent, nil, 15, -15);

    -- Setup options
    parent.showDeathOverlay = CreateCheckbox("alwaysShowDeathOverlay", parent, offsetX, "Always show death overlay (Otherwise mouseover only)");
    parent.showDeathOverlay = CreateCheckbox("alwaysShowSpecOverlay", parent, offsetX, "Always show spec (Otherwise mouseover only)");
    parent.unsavedWarning = CreateInputBox("unsavedWarningThreshold", parent, offsetX, "Unsaved games threshold before showing |cff00cc66/reload|r warning.");
end

-------------------------------------------------------------------
-- Filter Tab
-------------------------------------------------------------------
function SetupTab_Filters()
    local filterOptionsFrame = CreateFrame("frame");
    filterOptionsFrame.name = "Filters";
    filterOptionsFrame.parent = ArenaAnalyticsOptionsFrame.name;
    InterfaceOptions_AddCategory(filterOptionsFrame);
    
    -- Title
    InitializeTab(filterOptionsFrame);
    local parent = filterOptionsFrame;
    local offsetX = 20;
    
    parent.tabHeader = CreateHeader("Filters", TabHeaderSize, parent, nil, 15, -15);
    
    parent.showSkirmish = CreateCheckbox("showSkirmish", parent, offsetX, "Show Skirmish in match history.");
    
    CreateSpace();
    
    -- Setup options
    parent.defaultCurrentSeasonFilter = CreateCheckbox("defaultCurrentSeasonFilter", parent, offsetX, "Apply current season filter by default.");
    parent.defaultCurrentSessionFilter = CreateCheckbox("defaultCurrentSessionFilter", parent, offsetX, "Apply latest session only by default.");
    
    CreateSpace();
    
    parent.compFilterSortByTotal = CreateCheckbox("showCompDropdownInfoText", parent, offsetX, "Show info text by comp dropdown titles.", function()
        local dropdownFrame = ArenaAnalyticsScrollFrame.filterCompsDropdown;
        if(dropdownFrame and dropdownFrame.title and dropdownFrame.info) then
            if(Options:Get("showCompDropdownInfoText")) then
                dropdownFrame.title.info:Show();
            else
                dropdownFrame.title.info:Hide();
            end
        end

        dropdownFrame = ArenaAnalyticsScrollFrame.filterEnemyCompsDropdown;
        if(dropdownFrame and dropdownFrame.title and dropdownFrame.info) then
            if(Options:Get("showCompDropdownInfoText")) then
                dropdownFrame.title.info:Show();
            else
                dropdownFrame.title.info:Hide();
            end
        end
    end);

    CreateSpace();

    parent.compFilterSortByTotal = CreateCheckbox("sortCompFilterByTotalPlayed", parent, offsetX, "Sort comp filter dropdowns by total played.");
    parent.showSelectedCompStats = CreateCheckbox("showSelectedCompStats", parent, offsetX, "Show played and winrate for selected comp in filters.");
    parent.compFilterSortByTotal = CreateCheckbox("compDisplayAverageMmr", parent, offsetX, "Show average mmr in comp dropdown.", function()
        local info = Options:Get("compDisplayAverageMmr") and "Games || Comp || Winrate || mmr" or "Games || Comp || Winrate";
        
        local dropdownFrame = ArenaAnalyticsScrollFrame.filterCompsDropdown;
        if(dropdownFrame and dropdownFrame.title and dropdownFrame.info) then
            dropdownFrame.title.info:SetText(info);
        end
        
        dropdownFrame = ArenaAnalyticsScrollFrame.filterEnemyCompsDropdown;
        if(dropdownFrame and dropdownFrame.title and dropdownFrame.info) then
            dropdownFrame.title.info:SetText(info);
        end
    end);

    parent.unsavedWarning = CreateInputBox("outliers", parent, offsetX, "Minimum games required to appear on comp filter.");
    parent.unsavedWarning = CreateInputBox("dropdownVisibileLimit", parent, offsetX, "Maximum comp dropdown entries visible.");
end

-------------------------------------------------------------------
-- Search Tab
-------------------------------------------------------------------
function SetupTab_Search()
    local filterOptionsFrame = CreateFrame("frame");
    filterOptionsFrame.name = "Search";
    filterOptionsFrame.parent = ArenaAnalyticsOptionsFrame.name;
    InterfaceOptions_AddCategory(filterOptionsFrame);
    
    -- Title
    InitializeTab(filterOptionsFrame);
    local parent = filterOptionsFrame;
    local offsetX = 20;
    
    parent.tabHeader = CreateHeader("Search", TabHeaderSize, parent, nil, 15, -15);

    -- Setup options
    parent.searchDefaultExplicitEnemy = CreateCheckbox("searchDefaultExplicitEnemy", parent, offsetX, "Search defaults enemy team.   |cffaaaaaa(Override by adding keyword: '|cff00ccffteam|r' for explicit friendly team.)|r", function()
        if(ArenaAnalyticsDebugAssert(ArenaAnalyticsScrollFrame.searchbox.title)) then
            ArenaAnalyticsScrollFrame.searchBox.title:SetText(Options:Get("searchDefaultExplicitEnemy") and "Enemy Search" or "Search");
        end
    end);

    parent.searchDefaultExplicitEnemy = CreateCheckbox("searchHideTooltipQuickSearch", parent, offsetX, "Hide Quick Search shortcuts on player tooltips.");

    CreateSpace();

    -- Exclude any realm
    parent.quickSearchExcludeAnyRealm = CreateCheckbox("quickSearchExcludeAnyRealm", parent, offsetX, "Quick Search excludes realms.", function()
        filterOptionsFrame.quickSearchExcludeMyRealm:stateFunc();
    end);

    -- Exclude my realm
    parent.quickSearchExcludeMyRealm = CreateCheckbox("quickSearchExcludeMyRealm", parent, offsetX, "Quick Search excludes my realm.");
    parent.quickSearchExcludeMyRealm.stateFunc = function()
        if(not Options:Get("quickSearchExcludeAnyRealm")) then
            filterOptionsFrame.quickSearchExcludeMyRealm:Enable();
        else
            filterOptionsFrame.quickSearchExcludeMyRealm:Disable();
        end
    end
    parent.quickSearchExcludeMyRealm:stateFunc();
end

-------------------------------------------------------------------
-- Import/Export Tab
-------------------------------------------------------------------
function SetupTab_ImportExport()
    exportOptionsFrame = CreateFrame("frame");
    exportOptionsFrame.name = "Import / Export";
    exportOptionsFrame.parent = ArenaAnalyticsOptionsFrame.name;
    InterfaceOptions_AddCategory(exportOptionsFrame);

    InitializeTab(exportOptionsFrame);
    local parent = exportOptionsFrame;
    local offsetX = 20;

    parent.tabHeader = CreateHeader("Import / Export", TabHeaderSize, parent, nil, 15, -15);

    parent.exportButton = CreateButton(nil, parent, offsetX, 120, "Export", function() Export:combineExportCSV() end);
    
    CreateSpace();

    -- Import button (Might want an option at some point for whether we'll allow importing to merge with existing entries)
    parent.importButton = CreateButton(nil, parent, offsetX, 120, "Import", function() AAtable:TryShowimportDialogFrame(parent) end);
    parent.importButton.stateFunc = function()
        if(Options:Get("allowImportDataMerge") or not ArenaAnalytics:HasStoredMatches()) then
            exportOptionsFrame.importButton:Enable();
        else
            exportOptionsFrame.importButton:Disable();
        end
    end
    parent.importButton.stateFunc();

    parent.importAllowMerge = CreateCheckbox("allowImportDataMerge", parent, offsetX, "Allow Import Merge", function()
        parent.importButton.stateFunc();
    end);
    parent.importAllowMerge.tooltip = { "Allow Import Merge", "Enables importing with stored matches.\nThis will add matches before and after already stored matches.\n\n|cffff0000Experimental! - Use at own risk.|r\nBackup SavedVariables recommended." }

    
    exportOptionsFrame:SetScript("OnShow", function() parent.importButton.stateFunc() end);
end

-------------------------------------------------------------------
-- Initialize Options Menu
-------------------------------------------------------------------

function Options:Init()
    if not ArenaAnalyticsOptionsFrame then
        ArenaAnalyticsOptionsFrame = CreateFrame("Frame");
        ArenaAnalyticsOptionsFrame.name = "Arena|cff00ccffAnalytics|r";
        InterfaceOptions_AddCategory(ArenaAnalyticsOptionsFrame);

        -- Setup tabs
        SetupTab_General();
        SetupTab_Filters();
        SetupTab_Search();
        SetupTab_ImportExport();
    end
end