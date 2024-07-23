local _, ArenaAnalytics = ...; -- Addon Namespace
local Dropdown = ArenaAnalytics.Dropdown;

-- Setup local subclass
Dropdown.EntryFrame = {};
local EntryFrame = Dropdown.EntryFrame;
EntryFrame.__index = EntryFrame;

-------------------------------------------------------------------------

local function ValidateConfig(config)
    assert(config);
    assert(config.nested == nil or (type(config.nested) == "table" or type(config.nested) == "function"), "Invalid nested value in config."); -- nil, table or function
    assert(not config.onClick or type(config.onClick) == "function");
end

function EntryFrame:Create(parent, index, width, height, config)
    ValidateConfig(config);
    
    local self = setmetatable({}, EntryFrame);
    self.parent = parent;

    self.name = (parent:GetName() .. "Entry") .. (index and index or "");

    -- Temp for nested list
    self.width = width;
    self.height = height;

    -- Config
    self.label = config.label;
    self.key = config.key;
    self.value = config.value or config.label;
    self.checked = config.checked;
    self.onClick = config.onClick;
    self.nested = config.nested;    
    self.isNested = (config.nested ~= nil)

    -- Setup button
    self.btn = CreateFrame("Button", self.name, parent:GetFrame());

    -- Font Objects
    self.btn:SetNormalFontObject("GameFontHighlight");
    self.btn:SetHighlightFontObject("GameFontHighlight");
    self.btn:SetDisabledFontObject("GameFontDisableSmall");
    self.btn:SetSize(width, height);
    self.btn:SetText("");
    

    -- Create the highlight texture
    self.highlight = self.btn:CreateTexture(nil, "HIGHLIGHT")
    self.highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    self.highlight:SetBlendMode("ADD")
    self.highlight:SetAllPoints(self.btn)
    self.highlight:Hide()

    -- When using UIServiceButtonTemplate, we need this:
    if(self.btn.money) then
        self.btn.money:Hide();
    end
    
    local entryFrame = self;

    self.btn:RegisterForClicks("LeftButtonDown", "RightButtonDown");
    self.btn:SetScript("OnClick", function(self, button)
        if(entryFrame.onClick) then
            entryFrame.onClick(entryFrame, button);
        end

        --parent:Refresh();
    end);

    -- Hover Background
    self.btn:SetScript("OnEnter", function()
        self:OnEnter();
    end);

    self.btn:SetScript("OnLeave", function()
        self:OnLeave();
    end);
    
    self:Refresh();

    return self;
end

function EntryFrame:OnEnter()
    self.highlight:Show();
    self:CreateNestedList();
end

function EntryFrame:OnLeave()
    self.highlight:Hide();
end

function EntryFrame:CreateNestedList()
    if(self.nested ~= nil) then
        local parent = self.parent;

        nested = Dropdown._internal:RetrieveValue(self.nested, self);
        assert(nested and #nested > 0);

        local newDropdown = Dropdown.List:Create(self, parent.level + 1, self.width, self.height, nested);
        newDropdown:SetPoint("TOPLEFT", self:GetFrame(), "TOPRIGHT", 0, 5 + Dropdown.List.verticalPadding);
        newDropdown:Show();
    end
end

function EntryFrame:SetDisplay(display)
    if(self.dropdownType == "Comp" and false) then -- TODO: Implement this
        self.btn:SetText("");
        
        -- TODO: Set comp display with comps and details tex (Assume param: display is a comp string.)
        self.display = CreateFrame("Frame", (self.btn:GetName().."Display"),  self);
        self.display.playedText = ""; -- Replace with text frame
        -- TODO: Add class/spec icons
        self.display.winrate = "100%"; -- Replace with text frame
        self.display.mmr = "3074"; -- Replace with text frame

        --  TODO: Implement appropriate comp dropdown options above (Show stats / Show average MMR)
    else
        self.btn:SetText(display);
        self.display = nil;
    end
end

function EntryFrame:Refresh()
    -- TODO: Decide if checked and nested should go in SetDisplay

    self:UpdateCheckbox();
    self:UpdateNestedArrow();

    local display = Dropdown._internal:RetrieveValue(self.label, self);
    self:SetDisplay(display);
end

function EntryFrame:UpdateCheckbox()
    if(self.checked ~= nil) then
        if(not self.checkbox) then
            self.checkbox = self.btn:CreateTexture(nil, "OVERLAY");
            self.checkbox:SetTexture("Interface\\Common\\UI-DropDownRadioChecks");
            self.checkbox:SetPoint("LEFT", self.btn, "LEFT", 1, 0);
            self.checkbox:SetSize(16, 16);
            self.checkbox:Show();
        end

        local isChecked = Dropdown._internal:RetrieveValue(self.checked, self);
        if(isChecked) then
            self.checkbox:SetTexCoord(0, 0.5, 0.5, 1.0);
        else
            self.checkbox:SetTexCoord(0.5, 1.0, 0.5, 1.0);
        end
    else
        self.checkbox = nil;
    end
end

function EntryFrame:UpdateNestedArrow()
    if(self.isNested) then
        self.arrow = self.btn:CreateTexture(nil, "OVERLAY");
        self.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow");
        self.arrow:SetPoint("RIGHT", self.btn, "RIGHT", -1, 0);
        self.arrow:SetSize(16, 16);
        self.arrow:Show();
    else
        self.arrow = nil;
    end
end

function EntryFrame:GetOwner()
    return self.parent:GetOwner();
end

function EntryFrame:GetFrame()
    return self.btn;
end

function EntryFrame:GetName()
    return self.name;
end

function EntryFrame:GetDropdownType()
    return parent:GetDropdownType();
end

function EntryFrame:SetPoint(...)
    self.btn:SetPoint(...);
end

function EntryFrame:GetHeight()
    return self.btn:GetHeight();
end

function EntryFrame:GetWidth()
    return self.btn:GetWidth();
end

function EntryFrame:IsVisible()
    return self.btn:IsVisible();
end

function EntryFrame:Show()
    self.btn:Show();
end

function EntryFrame:Hide()
    self.btn:Hide();
end