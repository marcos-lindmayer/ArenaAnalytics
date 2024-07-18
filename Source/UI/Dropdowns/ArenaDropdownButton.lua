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

function Button:Create(parent, index, width, height, config)    
    ValidateConfig(config);
    
    local self = setmetatable({}, Button);

    self.name = (parent.name .. "Button") .. (index and index or "");
    self.config = config;
    self.onClick = config.onClick;
    
    self.isNested = (config.nested ~= nil)
    
    self.btn = CreateFrame("Button", self.name, parent:GetFrame(), "UIServiceButtonTemplate");
    self.btn:SetSize(width, height);

    -- Font Objects
    self.btn:SetNormalFontObject("GameFontHighlight");
    self.btn:SetHighlightFontObject("GameFontHighlight");
    self.btn:SetDisabledFontObject("GameFontDisableSmall");

    -- When using UIServiceButtonTemplate, we need this:
    if(self.btn.money) then
        self.btn.money:Hide();
    end

    self.btn:RegisterForClicks("LeftButtonDown", "RightButtonDown");
    self.btn:SetScript("OnClick", function(self, button)
        if(self.onClick) then
            self.onClick(self, button);
        end
	end);

    self:Refresh();

    return self;
end

function Button:GetFrame()
    return self.btn;
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

    local checked = Dropdown._internal:RetrieveValue(self.config.checked);
    if(checked ~= nil) then
        -- TODO: Add or keep checkable X offset, show checked or unchecked frames appropriately
    else
        -- TODO: Hide check/unchecked visual, and remove checkable X offset
    end

    if(self.isNested) then
        -- Show or add nest arrow
    else
        -- TODO: Hide nest arrow if it exists
    end

    local display = Dropdown._internal:RetrieveValue(self.config.display);
    self:SetDisplay(display);
end