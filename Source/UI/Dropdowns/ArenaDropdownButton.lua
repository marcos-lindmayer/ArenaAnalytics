local _, ArenaAnalytics = ...; -- Addon Namespace
local Dropdown = ArenaAnalytics.Dropdown;

-- Setup local subclass
Dropdown.Button = {};
local Button = Dropdown.Button;
Button.__index = Button;

-------------------------------------------------------------------------

local function ValidateConfig(config)
    assert(config);
    assert(config.nested == nil or (type(config.nested) == "table" or type(config.nested) == "function"), "Invalid nested value in config."); -- nil, table or function
    assert(not config.onClick or type(config.onClick) == "function");
end

function Button:Create(parent, isMainButton, index, width, height, config)
    ValidateConfig(config);
    
    local self = setmetatable({}, Button);

    self.name = (parent:GetName() .. "Button") .. (index and index or "");

    self.label = config.label;
    self.key = config.key;
    self.value = config.value or config.label;
    self.checked = config.checked;
    self.onClick = config.onClick;
    
    self.isNested = (config.nested ~= nil)
    
    local template = isMainButton and "UIServiceButtonTemplate" or nil;
    self.btn = CreateFrame("Button", self.name, parent:GetFrame(), template);
    self.btn:SetSize(width, height);
    self.btn:SetText("");

    if(isMainButton) then
        self.btn:SetPoint("CENTER", parent:GetFrame(), "CENTER");
    end

    -- Font Objects
    self.btn:SetNormalFontObject("GameFontHighlight");
    self.btn:SetHighlightFontObject("GameFontHighlight");
    self.btn:SetDisabledFontObject("GameFontDisableSmall");

    -- Create the highlight texture
    self.Highlight = self.btn:CreateTexture(nil, "HIGHLIGHT")
    self.Highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    self.Highlight:SetBlendMode("ADD")
    self.Highlight:SetAllPoints(self.btn)
    self.Highlight:Show()

    -- When using UIServiceButtonTemplate, we need this:
    if(self.btn.money) then
        self.btn.money:Hide();
    end
    
    local dropdownButton = self;

    self.btn:RegisterForClicks("LeftButtonDown", "RightButtonDown");
    self.btn:SetScript("OnClick", function(self, button)
        if(dropdownButton.onClick) then
            dropdownButton.onClick(dropdownButton, button);
        end

        if(isMainButton) then
            parent:Toggle();
        end
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

function Button:OnEnter()

end

function Button:OnLeave()

end

function Button:SetDisplay(display)
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

function Button:Refresh()
    -- TODO: Decide if checked and nested should go in SetDisplay

    self:UpdateCheckbox();
    self:UpdateNestedArrow();

    local display = Dropdown._internal:RetrieveValue(self.label, self);
    self:SetDisplay(display);
end

function Button:UpdateCheckbox()
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

function Button:UpdateNestedArrow()
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

function Button:GetFrame()
    return self.btn;
end

function Button:GetName()
    return self.name;
end

function Button:GetDropdownType()
    return parent:GetDropdownType();
end

function Button:SetPoint(...)
    self.btn:SetPoint(...);
end

function Button:GetHeight()
    return self.btn:GetHeight();
end

function Button:GetWidth()
    return self.btn:GetWidth();
end

function Button:IsVisible()
    return self.btn:IsVisible();
end

function Button:Show()
    self.btn:Show();
end

function Button:Hide()
    self.btn:Hide();
end