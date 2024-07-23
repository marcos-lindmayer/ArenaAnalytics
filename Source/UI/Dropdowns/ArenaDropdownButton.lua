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

function Button:Create(parent, width, height, config)
    ValidateConfig(config);
    
    local self = setmetatable({}, Button);
    self.parent = parent;

    self.name = (parent:GetName() .. "Button");

    -- Temp for nested list
    self.width = width;
    self.height = height;

    -- Config
    self.label = config.label;
    self.key = config.key;
    self.value = config.value or config.label;
    self.onClick = config.onClick;
    
    self.template = config.template or "UIPanelButtonTemplate";
    self.btn = CreateFrame("Button", self.name, parent:GetOwner(), self.template); -- UIServiceButtonTemplate vs UIPanelButtonTemplate
    self.btn:SetSize(width, height);
    self.btn:SetText("");

    self.btn:SetPoint("CENTER", parent:GetFrame(), "CENTER");
    
    -- Font Objects
    self.btn:SetNormalFontObject("GameFontHighlight");
    self.btn:SetHighlightFontObject("GameFontHighlight");
    self.btn:SetDisabledFontObject("GameFontDisableSmall");

    -- When using UIServiceButtonTemplate, we need this:
    if(self.btn.money) then
        self.btn.money:Hide();
    end
    
    local Button = self;

    self.btn:RegisterForClicks("LeftButtonDown", "RightButtonDown");
    self.btn:SetScript("OnClick", function(self, button)
        if(Button.onClick) then
            Button.onClick(Button, button);
        end

        parent:Toggle();
    end);

    self:Refresh();

    return self;
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

    local display = Dropdown._internal:RetrieveValue(self.label, self);
    self:SetDisplay(display);
end

function Button:GetOwner()
    return self.owner;
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