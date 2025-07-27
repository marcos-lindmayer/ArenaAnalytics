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
-- Constants

local TabHeaderSize = 16;
local TabTitleSize = 18;
local GroupHeaderSize = 14;
local TextSize = 12;
local OptionsSpacing = 10;

-- Offset to use while creating settings tabs
local offsetY = 0;

-------------------------------------------------------------------------
-- Options Frames

function Options:SetupTooltip(owner, frames)
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

function Options:InitializeTab(parent)
    local addonNameText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    addonNameText:SetPoint("TOPLEFT", parent, "TOPLEFT", -5, 32)
    addonNameText:SetTextHeight(TabTitleSize);
    addonNameText:SetText(Colors:GetTitle() .. "   " .. Colors:GetVersionText());

    -- Reset Y offset
    offsetY = 0;
end

function Options:CreateSpace(explicit)
    offsetY = offsetY - max(0, explicit or 20)
end

function Options:CreateHeader(text, parent, relative, x, y)
    local frame = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame:SetPoint("TOPLEFT", relative or parent, "TOPLEFT", x, y)
    frame:SetTextHeight(TabHeaderSize);
    frame:SetText(text or "");

    offsetY = offsetY - OptionsSpacing - frame:GetHeight() + y;

    return frame;
end

function Options:CreateButton(setting, parent, x, width, text, func)
    assert(type(func) == "function");

    -- Create the button
    local button = CreateFrame("Button", "ArenaAnalyticsButton_" .. (setting or text or ""), parent, "UIPanelButtonTemplate");

    -- Set the button's position
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, offsetY);

    -- Set the button's size and text
    button:SetSize(width or 120, 30)
    button:SetText(text or "")

    -- Add a script for the button's click action
    button:SetScript("OnClick", function()
        func(setting);
    end)

    Options:SetupTooltip(button, nil);

    offsetY = offsetY - OptionsSpacing - button:GetHeight();

    return button;
end

function Options:CreateImportBox(parent, x, width, height)
    local ImportBox = ImportBox:Create(parent, "ArenaAnalyticsImportDialogBox", width, (height or 25));
    ImportBox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, offsetY);

    function ImportBox:stateFunc()
        if(Options:Get("allowImportDataMerge") or not ArenaAnalytics:HasStoredMatches()) then
            self.frame.editbox:Enable();
        else
            self:Disable();
        end
    end

    ImportBox:stateFunc();

    offsetY = offsetY - ImportBox:GetHeight();

    return ImportBox;
end

function Options:CreateCheckbox(setting, parent, x, text, func)
    assert(setting ~= nil);
    assert(type(setting) == "string");

    local checkbox = CreateFrame("CheckButton", "ArenaAnalyticsScrollFrame_"..setting, parent, "OptionsSmallCheckButtonTemplate");

    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, offsetY);

    checkbox.text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    checkbox.text:SetPoint("LEFT", checkbox, "RIGHT", 5);
    checkbox.text:SetTextHeight(TextSize);
    checkbox.text:SetText(text or "");

    checkbox:SetChecked(Options:Get(setting));

    checkbox:SetScript("OnClick", function()
		Options:Set(setting, checkbox:GetChecked());

        if(func) then
            func(setting);
        end
	end);

    Options:SetupTooltip(checkbox, {checkbox, checkbox.text});

    offsetY = offsetY - OptionsSpacing - checkbox:GetHeight() + 10;

    parent[setting] = checkbox;
    return checkbox;
end

function Options:CreateInputBox(setting, parent, x, text, func)
    offsetY = offsetY - 2; -- top padding

    local inputBox = CreateFrame("EditBox", "exportFrameScroll", parent, "InputBoxTemplate");
    inputBox:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 8, offsetY);
    inputBox:SetWidth(50);
    inputBox:SetHeight(20);
    inputBox:SetNumeric();
    inputBox:SetAutoFocus(false);
    inputBox:SetMaxLetters(5);
    inputBox:SetText(tonumber(Options:Get(setting)) or "");
    inputBox:SetCursorPosition(0);
    inputBox:HighlightText(0,0);    

    -- Text
    inputBox.text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    inputBox.text:SetPoint("LEFT", inputBox, "RIGHT", 5, 0);
    inputBox.text:SetTextHeight(TextSize);
    inputBox.text:SetText(text or "");

    inputBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus();
    end);

    inputBox:SetScript("OnEscapePressed", function(self)
		inputBox:SetText(Options:Get(setting) or "");
        self:ClearFocus();
    end);

    inputBox:SetScript("OnEditFocusLost", function(self)
		local oldValue = Helpers:ToSafeNumber(Options:Get(setting));
		local newValue = Helpers:ToSafeNumber(inputBox:GetText());
        Options:Set(setting, newValue or oldValue)
		inputBox:SetText(tonumber(Options:Get(setting)) or "");
        inputBox:SetCursorPosition(0);
		inputBox:HighlightText(0,0);

		AAtable:CheckUnsavedWarningThreshold();
    end);

    Options:SetupTooltip(inputBox, {inputBox, inputBox.text});

    if(func) then
        func(setting);
    end

    offsetY = offsetY - OptionsSpacing - inputBox:GetHeight() + 5;

    return inputBox;
end

function Options:CreateDropdown(setting, parent, x, text, entries, func)
    assert(setting and entries and #entries > 0);
    assert(Options:IsValid(setting));

    offsetY = offsetY - 2;

    local function SetSettingFromDropdown(dropdownContext, btn)
        if(btn == "RightButton") then
            Options:Reset(dropdownContext.key);
        else
            Options:Set(dropdownContext.key, (dropdownContext.value or dropdownContext.label));
        end

        if(func) then
            func(dropdownContext, btn, parent);
        end
    end

    local function IsSettingEntryChecked(dropdownContext)
        assert(dropdownContext ~= nil, "Invalid contextFrame");

        return Options:Get(dropdownContext.key) == (dropdownContext.value or dropdownContext.label);
    end

    local function ResetSetting(dropdownContext, btn)
        if(btn == "RightButton") then
            Options:Reset(dropdownContext.key);
            dropdownContext:Refresh();

            if(func) then
                func(dropdownContext, btn, parent);
            end
        else
            dropdownContext.parent:Toggle();
        end
    end

    local function GenerateEntries()
        local entryTable = {}
        for _,entry in ipairs(entries) do 
            if(entry) then
                tinsert(entryTable, {
                    label = entry,
                    alignment = "LEFT",
                    key = setting,
                    onClick = SetSettingFromDropdown,
                    checked = IsSettingEntryChecked,
                });
            end
        end
        return entryTable;
    end

    local function GetSelectedLabel(dropdownContext)
        local selected = Options:Get(dropdownContext.key) or "";
        if(selected == "None") then
            return "|cff555555" .. selected .. "|r";
        end
        return selected;
    end

    local config = {
        mainButton = {
            label = GetSelectedLabel,
            alignment = "CENTER",
            key = setting,
            onClick = ResetSetting
        },
        entries = GenerateEntries;
    }

    local newDropdown = Dropdown:Create(parent, "Setting", setting.."Dropdown", config, 150, 26) -- parent, dropdownType, frameName, config, width, height
    newDropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", x, offsetY);

    -- Text
    newDropdown.text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    newDropdown.text:SetPoint("LEFT", newDropdown:GetFrame(), "RIGHT", 5, 0);
    newDropdown.text:SetTextHeight(TextSize);
    newDropdown.text:SetText(text or "");

    offsetY = offsetY - OptionsSpacing - newDropdown:GetHeight() + 10;
    return newDropdown;
end
