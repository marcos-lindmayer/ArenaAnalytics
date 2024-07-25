local _, ArenaAnalytics = ...; -- Addon Namespace
local Dropdown = ArenaAnalytics.Dropdown;

-- Setup local subclass
Dropdown.Button = {};
local Button = Dropdown.Button;
Button.__index = Button;

-- Local module aliases
local API = ArenaAnalytics.API;
local AAtable = ArenaAnalytics.AAtable;

-------------------------------------------------------------------------

---------------------------------
-- Core
---------------------------------

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
    self.displayFunc = config.displayFunc or Dropdown.SetTextDisplay;
    self.onClick = config.onClick;

    self.alignment = config.alignment;
    
    self.template = AAtable:GetDropdownTemplate(config.template);
    self.btn = CreateFrame("Button", self.name, parent:GetOwner(), self.template);
    self.btn:SetSize(width, height);
    self.btn:SetText("");
    self.btn:Show();

    self.btn:SetPoint("CENTER", parent:GetFrame(), "CENTER");
    
    -- Font Objects
    self.btn:SetNormalFontObject("GameFontHighlight");
    self.btn:SetHighlightFontObject("GameFontHighlight");
    self.btn:SetDisabledFontObject("GameFontDisableSmall");

    -- When using UIServiceButtonTemplate, we need this:
    if(self.btn.money) then
        self.btn.money:Hide();
    end
    
    self.btn:RegisterForClicks("LeftButtonDown", "RightButtonDown");
    self.btn:SetScript("OnClick", function(frame, button)
        if(self.onClick) then
            self.onClick(self, button);
        else
            parent:Toggle();
        end

    end);

    self:Refresh("Button:Create");

    return self;
end

function Button:Refresh(debugContext)
    if(self:GetName() == "FilterCompDropdownButton") then  
        --ArenaAnalytics:Print("Refreshing ", self:GetName(), " for context: ", debugContext);
    end

    Dropdown:CallSetDisplay(self);
end

---------------------------------
-- Simple getters
---------------------------------

function Button:GetOwner()
    return self.owner;
end

function Button:GetSelectedFrame()
    return self.parent:GetSelectedFrame();
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

---------------------------------
-- Enabled State
---------------------------------

function Button:SetEnabled(state)
    if(state == false) then
        self:Hide();
    end

    if(state ~= self:IsEnabled()) then
        if(state) then
            self.btn:Enable();
        else
            self.btn:Disable();
        end
    end
end

function Button:Disable()
    self:SetEnabled(false);
end

function Button:Enable()
    self:SetEnabled(true);
end

function Button:IsEnabled()
    return self.btn:IsEnabled();
end

---------------------------------
-- Points
---------------------------------

function Button:SetPoint(...)
    self.btn:SetPoint(...);
end

function Button:GetHeight()
    return self.btn:GetHeight();
end

function Button:GetWidth()
    return self.btn:GetWidth();
end

---------------------------------
-- Visibility
---------------------------------

function Button:Show()
    self.btn:Show();
end

function Button:Hide()
    self.btn:Hide();
end

function Button:IsShown()
    return self.btn:IsShown();
end