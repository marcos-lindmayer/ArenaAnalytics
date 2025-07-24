local _, ArenaAnalytics = ...; -- Addon Namespace
local Options = ArenaAnalytics.Options;

-- Local module aliases
local Filters = ArenaAnalytics.Filters;
local AAtable = ArenaAnalytics.AAtable;
local Tooltips = ArenaAnalytics.Tooltips;
local Dropdown = ArenaAnalytics.Dropdown;
local Helpers = ArenaAnalytics.Helpers;
local API = ArenaAnalytics.API;
local PlayerTooltip = ArenaAnalytics.PlayerTooltip;
local ImportBox = ArenaAnalytics.ImportBox;
local Debug = ArenaAnalytics.Debug;
local Commands = ArenaAnalytics.Commands;
local Colors = ArenaAnalytics.Colors;

-------------------------------------------------------------------------

function Options:RegisterCategory(frame, name, parent)
    assert(frame)

    frame.name = name;

    if parent and parent.category then
        local parentcategory = Settings.GetCategory(parent)
        frame.category = Settings.RegisterCanvasLayoutSubcategory(parent.category, frame, name);
    else
        frame.category = Settings.RegisterCanvasLayoutCategory(frame, name);
        Settings.RegisterAddOnCategory(frame.category);
    end
end

function Options:OpenCategory(frame)
    if(not frame or not frame.category) then
        Debug:Log("Options: Invalid options frame, cannot open.");
        return;
    end

    Settings.OpenToCategory(frame.category.ID);
end

local ArenaAnalyticsOptionsFrame = nil;
function Options:Open()
    Options:OpenCategory(ArenaAnalyticsOptionsFrame);
end

-------------------------------------------------------------------------
-- Standardized Updated Option Response Functions

local function HandleSettingsChanged()
    Filters:ResetAll(false);
    PlayerTooltip:OnSettingsChanged();
end

-------------------------------------------------------------------------

-- User settings
ArenaAnalyticsSharedSettingsDB = ArenaAnalyticsSharedSettingsDB or {};

local defaults = {};

-- Adds a setting with loaded or default value.
local function AddSetting(setting, default)
    assert(setting ~= nil);
    assert(default ~= nil, "Nil values for settings are not supported.");

    if(ArenaAnalyticsSharedSettingsDB[setting] == nil) then
        ArenaAnalyticsSharedSettingsDB[setting] = default;
        Debug:Log("Added setting:", setting, default);
    end
    assert(ArenaAnalyticsSharedSettingsDB[setting] ~= nil);

    -- Cache latest defaults
    defaults[setting] = default;
end

local function RemoveSetting(setting)
    assert(setting ~= nil);
    if(ArenaAnalyticsSharedSettingsDB[setting] == nil) then
        return;
    end

    ArenaAnalyticsSharedSettingsDB[setting] = nil;
    defaults[setting] = nil;
end

-- Adds a setting that does not save across reloads. (Use with caution)
local function AddTransientSetting(setting, default)
    ArenaAnalyticsSharedSettingsDB[setting] = default;
end

local hasOptionsLoaded = nil;
function Options:LoadSettings()
    if hasOptionsLoaded then return end; -- Load only once

    Debug:Log("Loading settings..");

    -- General
    AddSetting("fullSizeSpecIcons", true);
    AddSetting("alwaysShowDeathOverlay", true);
    AddSetting("alwaysShowSpecOverlay", false);
    AddSetting("unsavedWarningThreshold", 10);

    AddSetting("compactLargeNumbers", true);
    AddSetting("hideZeroRatingDelta", true);
    AddSetting("hidePlayerTooltipZeroRatingDelta", false);
    --AddSetting("ignoreGroupForSkirmishSession", true);

    AddSetting("muteArenaDialogSounds", false);

    if(API:HasSurrenderAPI()) then
        AddSetting("surrenderByMiddleMouseClick", false);
        AddSetting("enableSurrenderAfkOverride", true);
        AddSetting("enableDoubleAfkToLeave", true);
        AddSetting("enableSurrenderGoodGameCommand", true);
    end

    AddSetting("hideMinimapButton", false);
    AddSetting("hideFromCompartment", false);

    AddSetting("printAsSystem", true);

    -- Language
    AddSetting("language", "enGB");
    AddSetting("languageLogging", false); -- Enables logging relevant for translators

    -- Filters
    AddSetting("defaultCurrentSeasonFilter", false);
    AddSetting("defaultCurrentSessionFilter", false);

    AddSetting("showSkirmish", true);
    AddSetting("showWarGames", true);

    AddSetting("showCompDropdownInfoText", true);

    AddSetting("sortCompFilterByTotalPlayed", true);
    AddSetting("compDisplayAverageMmr", true);
    AddSetting("showSelectedCompStats", false);

    AddSetting("minimumCompsPlayed", 0); -- Minimum games to appear on comp dropdowns
    AddSetting("compDropdownVisibileLimit", 10);
    AddSetting("dropdownScrollStep", 1);

    -- Selection (NYI)
    AddSetting("selectionControlModInversed", false);

    -- Import/Export
    AddSetting("allowImportDataMerge", false);

    -- Search
    AddSetting("searchDefaultExplicitEnemy", false);

    -- Quick Search
    AddSetting("quickSearchEnabled", true);
    AddSetting("searchShowTooltipQuickSearch", true);

    AddSetting("quickSearchIncludeRealm", "Other Realms"); -- None, All, Other Realms, My Realm
    AddSetting("quickSearchDefaultAppendRule", "New Search"); -- New Search, New Segment, Same Segment
    AddSetting("quickSearchDefaultValue", "Name");

    AddSetting("quickSearchAppendRule_NewSearch", "None");
    AddSetting("quickSearchAppendRule_NewSegment", "Shift");
    AddSetting("quickSearchAppendRule_SameSegment", "None");

    AddSetting("quickSearchAction_Inverse", "Alt");

    AddSetting("quickSearchAction_Team", "None");
    AddSetting("quickSearchAction_Enemy", "RMB");
    AddSetting("quickSearchAction_ClickedTeam", "LMB");

    AddSetting("quickSearchAction_Name", "None");
    AddSetting("quickSearchAction_Spec", "Ctrl");
    AddSetting("quickSearchAction_Race", "None");
    AddSetting("quickSearchAction_Faction", "None");

    -- Debugging
    AddSetting("debuggingLevel", 0);
    AddSetting("hideErrorLogs", false);

    -- Temp Fix (No longer needed, removing from save files)
    RemoveSetting("enableMoPHealerCharacterPanelFix");

    hasOptionsLoaded = true;
    Debug:Log("Settings loaded successfully.");
    return true;
end

function Options:HasLoaded()
    return hasOptionsLoaded;
end

function Options:IsValid(setting)
    return setting and ArenaAnalyticsSharedSettingsDB[setting] ~= nil;
end

function Options:IsDefault(setting)
    assert(Options:IsValid(setting));

    return ArenaAnalyticsSharedSettingsDB[setting] == defaults[setting];
end

-- Gets a setting, regardless of location between 
function Options:Get(setting)
    assert(setting);

    if(hasOptionsLoaded == false) then
        Debug:Log("Force loaded settings to immediately get:", setting);
        local successful = Options:LoadSettings();
        if not successful then return end;
    end

    local value = ArenaAnalyticsSharedSettingsDB[setting];

    if(value == nil) then
        Debug:Log("Setting not found: ", setting, value)
        return nil;
    end

    return value;
end

function Options:Set(setting, value)
    assert(setting and hasOptionsLoaded);
    assert(ArenaAnalyticsSharedSettingsDB[setting] ~= nil, "Setting invalid option: " .. (setting or "nil"));

    if(value == nil) then
        value = defaults[setting];
    end
    assert(value ~= nil);

    if(value == ArenaAnalyticsSharedSettingsDB[setting]) then
        return;
    end

    local oldValue = ArenaAnalyticsSharedSettingsDB[setting];
    ArenaAnalyticsSharedSettingsDB[setting] = value;
    Debug:Log("Setting option:   ", setting, "  new:", value, "  old:", oldValue);

    HandleSettingsChanged();
end

function Options:Reset(setting)
    Options:Set(setting, nil);
end

local exportOptionsFrame = nil;

function Options:TriggerStateUpdates()
    if(exportOptionsFrame and exportOptionsFrame.ImportBox and exportOptionsFrame.ImportBox.stateFunc) then
        exportOptionsFrame.ImportBox:stateFunc();
    end
end

local TabHeaderSize = 16;

-------------------------------------------------------------------
-- General Tab
-------------------------------------------------------------------

local function SetupTab_General()
    -- Title
    Options:InitializeTab(ArenaAnalyticsOptionsFrame);
    local parent = ArenaAnalyticsOptionsFrame;
    if(not parent) then
        return;
    end

    local offsetX = 20;

    parent.tabHeader = Options:CreateHeader("General", parent, nil, 15, -15);

    -- Setup options
    Options:CreateCheckbox("hideMinimapButton", parent, offsetX, "Hide minimap icon.", ArenaAnalytics.MinimapButton.Update);

    if(AddonCompartmentFrame) then
        Options:CreateCheckbox("hideFromCompartment", parent, offsetX, "Hide from addon compartment.", ArenaAnalytics.MinimapButton.Update);
    end

    Options:CreateSpace();

    Options:CreateCheckbox("printAsSystem", parent, offsetX, "Print messages using system messages.    |cffaaaaaa(Alternative is general chat only prints)|r");
    Options:CreateCheckbox("hideErrorLogs", parent, offsetX, "Hide error logging in chat.     |cffaaaaaa(Consider reporting errors instead)|r");

    Options:CreateSpace();

    Options:CreateCheckbox("fullSizeSpecIcons", parent, offsetX, "Full size spec icons.");
    Options:CreateCheckbox("alwaysShowDeathOverlay", parent, offsetX, "Always show death overlay (Otherwise mouseover only)");
    Options:CreateCheckbox("alwaysShowSpecOverlay", parent, offsetX, "Always show spec (Otherwise mouseover only)");
    Options:CreateInputBox("unsavedWarningThreshold", parent, offsetX, "Unsaved games threshold before showing |cff00cc66/reload|r warning.");

    Options:CreateSpace();

    Options:CreateCheckbox("compactLargeNumbers", parent, offsetX, "Compact large numbers.");
    Options:CreateCheckbox("hideZeroRatingDelta", parent, offsetX, "Hide delta for unchanged rating.");
    Options:CreateCheckbox("hidePlayerTooltipZeroRatingDelta", parent, offsetX, "Hide delta for unchanged rating on player tooltips.");
    --CreateCheckbox("ignoreGroupForSkirmishSession", parent, offsetX, "Sessions ignore skirmish team check.");

    Options:CreateSpace();

    Options:CreateCheckbox("muteArenaDialogSounds", parent, offsetX, "Mute dialog sound during arena.", API.UpdateDialogueVolume);

    if(API:HasSurrenderAPI()) then
        local function UpdateDoubleAfkState()
            if(parent.enableDoubleAfkToLeave) then
                if(Options:Get("enableSurrenderAfkOverride")) then
                    parent.enableDoubleAfkToLeave:Enable();
                else
                    parent.enableDoubleAfkToLeave:Disable();
                end
            end
        end

        Options:CreateSpace();
        Options:CreateCheckbox("surrenderByMiddleMouseClick", parent, offsetX, "Surrender by middle mouse clicking the minimap icon.");
        Options:CreateCheckbox("enableSurrenderGoodGameCommand", parent, offsetX, "Register |cff00ccff/gg|r surrender command.", Commands.UpdateSurrenderCommands);
        Options:CreateCheckbox("enableSurrenderAfkOverride", parent, offsetX, "Enable |cff00ccff/afk|r surrender override.", function()
            UpdateDoubleAfkState();
            Commands.UpdateSurrenderCommands();
        end);
        Options:CreateCheckbox("enableDoubleAfkToLeave", parent, offsetX*2, "Double |cff00ccff/afk|r to leave the arena.    |cffaaaaaa(Type |cff00ccff/afk|r twice within 5 seconds to confirm.)|r");
        UpdateDoubleAfkState();
    end
end

-------------------------------------------------------------------
-- General Tab
-------------------------------------------------------------------

local function SetupTab_Language()
    -- Title
    Options:InitializeTab(ArenaAnalyticsOptionsFrame);
    local parent = ArenaAnalyticsOptionsFrame;
    if(not parent) then
        return;
    end

    local offsetX = 20;

    parent.tabHeader = Options:CreateHeader("General", parent, nil, 15, -15);
end

-------------------------------------------------------------------
-- Filter Tab
-------------------------------------------------------------------

local function SetupTab_Filters()
    local filterOptionsFrame = CreateFrame("frame");
    Options:RegisterCategory(filterOptionsFrame, "Filters", ArenaAnalyticsOptionsFrame);

    -- Title
    Options:InitializeTab(filterOptionsFrame);
    local parent = filterOptionsFrame;
    local offsetX = 20;

    parent.tabHeader = Options:CreateHeader("Filters", parent, nil, 15, -15);

    Options:CreateCheckbox("showSkirmish", parent, offsetX, "Show Skirmish in match history.");
    Options:CreateCheckbox("showWarGames", parent, offsetX, "Show War Games in match history.");

    Options:CreateSpace();

    -- Setup options
    Options:CreateCheckbox("defaultCurrentSeasonFilter", parent, offsetX, "Apply current season filter by default.");
    Options:CreateCheckbox("defaultCurrentSessionFilter", parent, offsetX, "Apply latest session only by default.");

    Options:CreateSpace();

    Options:CreateCheckbox("showCompDropdownInfoText", parent, offsetX, "Show info text by comp dropdown titles.", function()
        local function forceUpdateInfoVisibility(frame)
            if(frame and frame.title and frame.title.info) then
                if(Options:Get("showCompDropdownInfoText")) then
                    frame.title.info:Show();
                else
                    frame.title.info:Hide();
                end
            end
        end

        forceUpdateInfoVisibility(ArenaAnalyticsScrollFrame.filterCompsDropdown:GetFrame());
        forceUpdateInfoVisibility(ArenaAnalyticsScrollFrame.filterEnemyCompsDropdown:GetFrame());
    end);

    Options:CreateSpace();

    Options:CreateCheckbox("sortCompFilterByTotalPlayed", parent, offsetX, "Sort comp filter dropdowns by total played.");
    Options:CreateCheckbox("showSelectedCompStats", parent, offsetX, "Show played and winrate for selected comp in filters.");
    Options:CreateCheckbox("compDisplayAverageMmr", parent, offsetX, "Show average mmr in comp dropdown.", function()
        local info = Options:Get("compDisplayAverageMmr") and "Games || Comp || Winrate || mmr" or "Games || Comp || Winrate";
        info = Colors:ColorText(info, Colors.infoColor);

        local function forceUpdateInfoText(frame)
            if(frame and frame.title and frame.title.info) then
                frame.title.info:SetText(info or "");
            end
        end

        forceUpdateInfoText(ArenaAnalyticsScrollFrame.filterCompsDropdown:GetFrame())
        forceUpdateInfoText(ArenaAnalyticsScrollFrame.filterEnemyCompsDropdown:GetFrame());
    end);

    parent.minimumCompsPlayed = Options:CreateInputBox("minimumCompsPlayed", parent, offsetX, "Minimum games required to appear on comp filter.");
    parent.compDropdownVisibileLimit = Options:CreateInputBox("compDropdownVisibileLimit", parent, offsetX, "Maximum comp dropdown entries visible.");
    parent.dropdownScrollStep = Options:CreateInputBox("dropdownScrollStep", parent, offsetX, "Dropdown entries to scroll past per through per step.");
end

-------------------------------------------------------------------
-- Search Tab
-------------------------------------------------------------------

local function SetupTab_Search()
    local filterOptionsFrame = CreateFrame("frame");
    --filterOptionsFrame.name = "Search";
    Options:RegisterCategory(filterOptionsFrame, "Search", ArenaAnalyticsOptionsFrame);

    -- Title
    Options:InitializeTab(filterOptionsFrame);
    local parent = filterOptionsFrame;
    local offsetX = 20;

    parent.tabHeader = Options:CreateHeader("Search", parent, nil, 15, -15);

    -- Setup options
    -- TODO: Convert to explicit team dropdown (Any, Team, Enemy)
    Options:CreateCheckbox("searchDefaultExplicitEnemy", parent, offsetX, "Search defaults enemy team.   |cffaaaaaa(Override by adding keyword: '|cff00ccffteam|r' for explicit friendly team.)|r", function()
        if(Debug:Assert(ArenaAnalyticsScrollFrame.searchBox.title)) then
            local explicitEnemyText = Options:Get("searchDefaultExplicitEnemy") and "Enemy Search" or "Search";
            ArenaAnalyticsScrollFrame.searchBox.title:SetText(Colors:ColorText(explicitEnemyText, Colors.headerColor));
        end
    end);
end

-------------------------------------------------------------------
-- Quick Search Tab
-------------------------------------------------------------------

local function ForceUniqueAppendRuleShortcut(dropdownContext, _, parent)
    local setting = dropdownContext and dropdownContext.key or nil;

    if(Options:IsValid(setting)) then
        local value = Options:Get(setting);

        local appendRuleFrames = { "quickSearchAppendRule_NewSearch", "quickSearchAppendRule_NewSegment", "quickSearchAppendRule_SameSegment" }
        for _,appendRule in ipairs(appendRuleFrames) do
            if(appendRule ~= setting) then
                local appendRuleValue = Options:Get(appendRule);

                -- Clear the existing append rule shortcut, if it's being reused now.
                if(appendRuleValue == value) then
                    Options:Set(appendRule, "None");

                    local otherDropdown = parent and parent[appendRule];
                    if(otherDropdown and otherDropdown.Refresh) then
                        otherDropdown:Refresh();
                    end
                end
            end
        end
    end
end

local function SetupTab_QuickSearch()
    local filterOptionsFrame = CreateFrame("frame");
    --filterOptionsFrame.name = "Quick Search";
    Options:RegisterCategory(filterOptionsFrame, "Quick Search", ArenaAnalyticsOptionsFrame);

    -- Title
    Options:InitializeTab(filterOptionsFrame);
    local parent = filterOptionsFrame;
    local offsetX = 20;

    parent.tabHeader = Options:CreateHeader("Quick Search", parent, nil, 15, -15);

    -- Setup options
    Options:CreateCheckbox("quickSearchEnabled", parent, offsetX, "Enable Quick Search");
    Options:CreateCheckbox("searchShowTooltipQuickSearch", parent, offsetX, "Show Quick Search shortcuts in Player Tooltips");

    Options:CreateSpace(15);

    local includeRealmOptions = { "None", "All", "Other Realms", "My Realm" };
    parent.includeRealmDropdown = Options:CreateDropdown("quickSearchIncludeRealm", parent, offsetX, "Include realms from Quick Search.", includeRealmOptions);

    local appendRules = { "New Search", "New Segment", "Same Segment" };
    parent.defaultAppendRuleDropdown = Options:CreateDropdown("quickSearchDefaultAppendRule", parent, offsetX, "Default append rule, if not overridden by shortcuts.", appendRules);

    local valueOptions = { "Name", "Spec", "Race", "Faction" };
    parent.defaultValueDropdown = Options:CreateDropdown("quickSearchDefaultValue", parent, offsetX, "Default value to add, if not overridden by shortcuts.", valueOptions);

    Options:CreateSpace(15);

    local shortcuts = { "None", "LMB", "RMB", "Nomod", "Shift", "Ctrl", "Alt" };

    parent.quickSearchAppendRule_NewSearch = Options:CreateDropdown("quickSearchAppendRule_NewSearch", parent, offsetX, "New Search append rule shortcut.", shortcuts, ForceUniqueAppendRuleShortcut);
    parent.quickSearchAppendRule_NewSegment = Options:CreateDropdown("quickSearchAppendRule_NewSegment", parent, offsetX, "New Segment append rule shortcut.", shortcuts, ForceUniqueAppendRuleShortcut);
    parent.quickSearchAppendRule_SameSegment = Options:CreateDropdown("quickSearchAppendRule_SameSegment", parent, offsetX, "Same Segment append rule shortcut.", shortcuts, ForceUniqueAppendRuleShortcut);

    Options:CreateSpace(15);

    parent.inverseValueDropdown = Options:CreateDropdown("quickSearchAction_Inverse", parent, offsetX, "Inverse segment shortcut.", shortcuts);

    Options:CreateSpace(15);

    parent.clickedTeamValueDropdown = Options:CreateDropdown("quickSearchAction_ClickedTeam", parent, offsetX, "Team of clicked player shortcut.", shortcuts);
    parent.teamValueDropdown = Options:CreateDropdown("quickSearchAction_Team", parent, offsetX, "Team shortcut.", shortcuts);
    parent.enemyValueDropdown = Options:CreateDropdown("quickSearchAction_Enemy", parent, offsetX, "Enemy shortcut.", shortcuts);

    Options:CreateSpace(15);

    parent.nameValueDropdown = Options:CreateDropdown("quickSearchAction_Name", parent, offsetX, "Name shortcut.", shortcuts);
    parent.specValueDropdown = Options:CreateDropdown("quickSearchAction_Spec", parent, offsetX, "Spec shortcut.", shortcuts);
    parent.raceValueDropdown = Options:CreateDropdown("quickSearchAction_Race", parent, offsetX, "Race shortcut.", shortcuts);
    parent.factionValueDropdown = Options:CreateDropdown("quickSearchAction_Faction", parent, offsetX, "Faction shortcut.", shortcuts);
end

-------------------------------------------------------------------
-- Import/Export Tab
-------------------------------------------------------------------

local function SetupTab_ImportExport()
    exportOptionsFrame = CreateFrame("frame");
    Options:RegisterCategory(exportOptionsFrame, "Import / Export", ArenaAnalyticsOptionsFrame);

    Options:InitializeTab(exportOptionsFrame);
    local parent = exportOptionsFrame;
    local offsetX = 20;

    parent.tabHeader = Options:CreateHeader("Import / Export", parent, nil, 15, -15);

    parent.exportButton = Options:CreateButton(nil, parent, offsetX, 120, "Export", function() end);
    parent.exportButton:Disable(); -- TODO: Add export
    parent.exportButton.tooltip = { "ArenaAnalytics Export", "Not Yet Implemented" }

    Options:CreateSpace();

    -- Import button (Might want an option at some point for whether we'll allow importing to merge with existing entries)
    parent.ImportBox = Options:CreateImportBox(parent, offsetX, 380);

    local frame = Options:CreateCheckbox("allowImportDataMerge", parent, offsetX, "Allow Import Merge", function()
        parent.ImportBox:stateFunc();
    end);
    frame.tooltip = { "Allow Import Merge", "Enables importing with stored matches.\nSkip matches within 24 hours of first and last arena, and matches between the two dates.\n\n|cffff0000Experimental! It is recommended to backup character specific SavedVariable first." }

    Options:CreateSpace();

    parent.purgeButton = Options:CreateButton(nil, parent, offsetX, 213, "Purge Match History", ArenaAnalytics.ShowPurgeConfirmationDialog);

    exportOptionsFrame:SetScript("OnShow", function() parent.ImportBox:stateFunc() end);
end

-------------------------------------------------------------------
-- Initialize Options Menu
-------------------------------------------------------------------

function Options:Initialize()
    Options:LoadSettings();

    if not ArenaAnalyticsOptionsFrame then
        ArenaAnalyticsOptionsFrame = CreateFrame("Frame");
        Options:RegisterCategory(ArenaAnalyticsOptionsFrame, "Arena|cff00ccffAnalytics|r");

        -- Setup tabs
        SetupTab_General();
        SetupTab_Filters();
        SetupTab_Search();
        SetupTab_QuickSearch();
        SetupTab_ImportExport();   -- TODO: Implement updated import/export
    end
end