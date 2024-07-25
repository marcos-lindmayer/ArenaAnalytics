local _, ArenaAnalytics = ...; -- Addon Namespace
local Dropdown = ArenaAnalytics.Dropdown;

-- Setup local subclass
Dropdown.EntryFrame = {};
local EntryFrame = Dropdown.EntryFrame;
EntryFrame.__index = EntryFrame;

-------------------------------------------------------------------------

---------------------------------
-- Entry Button Core
---------------------------------

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
    self:SetConfig(config);

    -- Setup button
    self.btn = CreateFrame("Button", self.name, parent:GetFrame());

    -- Font Objects
    self.btn:SetNormalFontObject("GameFontHighlight");
    self.btn:SetHighlightFontObject("GameFontHighlight");
    self.btn:SetDisabledFontObject("GameFontDisableSmall");
    self.btn:SetSize(width, height);
    self.btn:SetText("");
    

    -- Create the highlight texture
    self.highlight = self.btn:CreateTexture(nil, "HIGHLIGHT");
    self.highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");
    self.highlight:SetBlendMode("ADD");
    self.highlight:SetAllPoints(self.btn);
    self.highlight:Hide();
    
    local entryFrame = self;

    self.btn:RegisterForClicks("LeftButtonDown", "RightButtonDown");
    self.btn:SetScript("OnClick", function(frame, button)
        if(entryFrame.onClick) then
            entryFrame.onClick(entryFrame, button);            
        end

        -- Refresh all active dropdowns
        Dropdown:RefreshAll("EntryFrame:Create");

        local selectedFrame = self:GetSelectedFrame();
        if(selectedFrame and selectedFrame.Refresh) then
            selectedFrame:Refresh("EntryFrame:Create Selected");
        end
    end);

    -- Hover Background
    self.btn:SetScript("OnEnter", function()
        self.highlight:Show();
        self:CreateNestedList();
    end);

    self.btn:SetScript("OnLeave", function()
        self.highlight:Hide();
    end);
    
    self:Refresh("EntryFrame:Create");

    return self;
end

function EntryFrame:SetConfig(config)
    self.label = config.label;
    self.key = config.key;
    self.value = config.value or config.label;
    self.displayFunc = config.displayFunc or Dropdown.SetTextDisplay;
    self.nested = config.nested;
    
    self.onClick = config.onClick;

    self.checked = config.checked;
    self.disabled = config.disabled;

    self.alignment = config.alignment;
    self.offsetX = config.offsetX;
    
    self.width = config.width or self.width;
    self.height = config.height or self.height;
    self.fontSize = config.fontSize;
    self.fontColor = config.fontColor;
end

function EntryFrame:CreateNestedList()
    if(self.nested ~= nil) then
        local parent = self.parent;

        nested = Dropdown:RetrieveValue(self.nested, self);
        assert(nested and #nested > 0);

        local newDropdown = Dropdown.List:Create(self, parent.level + 1, self.width, self.height, nested);
        newDropdown:SetPoint("TOPLEFT", self:GetFrame(), "TOPRIGHT", 0, 5 + Dropdown.List.verticalPadding);
        newDropdown:Show();
    end
end

function EntryFrame:Refresh(debugContext)
    --ArenaAnalytics:Log("Refreshing ", self:GetName(), " for context: ", debugContext);

    self:UpdateCheckbox();
    self:UpdateNestedArrow();

    Dropdown:CallSetDisplay(self);

    local desiredWidth = max(self.width, self:ComputeRequiredWidth());
    self:SetWidth(desiredWidth)
end

function EntryFrame:UpdateCheckbox()
    if(self.checked ~= nil) then
        if(not self.checkbox) then
            self.checkbox = self.btn:CreateTexture(nil, "OVERLAY");
            self.checkbox:SetTexture("Interface\\Common\\UI-DropDownRadioChecks");
            self.checkbox:SetPoint("LEFT", self.btn, "LEFT", 2, 0);
            self.checkbox:SetSize(16, 16);
            self.checkbox:Show();
        end

        local isChecked = Dropdown:RetrieveValue(self.checked, self);
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
    if(self.nested ~= nil) then
        self.arrow = self.btn:CreateTexture(nil, "OVERLAY");
        self.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow");
        self.arrow:SetPoint("RIGHT", self.btn, "RIGHT", -2, 0);
        self.arrow:SetSize(16, 16);
        self.arrow:Show();
    else
        self.arrow = nil;
    end
end

function EntryFrame:ComputeRequiredWidth()
    local minimumWidth = 20; -- Minimum padding

    -- Checkbox
    if(self.checkbox) then
        minimumWidth = minimumWidth + self.checkbox:GetWidth() + 4;
    end

    -- Nested arrow
    if(self.arrow) then
        minimumWidth = minimumWidth + self.arrow:GetWidth() + 4;
    end

    -- Display Width
    if(self.display) then
        assert(self.display.GetWidth, "Dropdown display must support GetWidth()");
        minimumWidth = minimumWidth + self.display:GetWidth();
    end

    minimumWidth = ceil(minimumWidth);

    return minimumWidth;
end

---------------------------------
-- Simple getters
---------------------------------

function EntryFrame:GetOwner()
    return self.parent:GetOwner();
end

function EntryFrame:GetSelectedFrame()
    return self.parent:GetSelectedFrame();
end

function EntryFrame:GetFrame()
    return self.btn;
end

function EntryFrame:GetName()
    return self.name;
end

function EntryFrame:GetDropdownType()
    return self.parent:GetDropdownType();
end

---------------------------------
-- Points
---------------------------------

function EntryFrame:SetPoint(...)
    self.btn:SetPoint(...);
end

function EntryFrame:GetSize()
    return self.btn:GetSize();
end

function EntryFrame:SetSize(width, height)
    self.btn:SetSize(width, height);
end

-- Width
function EntryFrame:GetWidth()
    return self.btn:GetWidth();
end

function EntryFrame:SetWidth(width)
    self.btn:SetWidth(width);
end

-- Height
function EntryFrame:GetHeight()
    return self.btn:GetHeight();
end

function EntryFrame:SetHeight(height)
    self.btn:SetHeight(height);
end

---------------------------------
-- Visibility
---------------------------------

function EntryFrame:IsShown()
    return self.btn:IsShown();
end

function EntryFrame:Show()
    self.btn:Show();
end

function EntryFrame:Hide()
    self.btn:Hide();
end