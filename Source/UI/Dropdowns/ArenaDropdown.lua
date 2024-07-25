local _, ArenaAnalytics = ...; -- Addon Namespace
local Dropdown = ArenaAnalytics.Dropdown;
Dropdown.__index = Dropdown

-------------------------------------------------------------------------
-- Example table format to construct dropdowns:

-- Dropdown General Data
    -- ValueKey: The key to retrieve and set current (Filter or Setting)
    -- Getter func: A function to call, to retrieve the current value.
-- Dropdown Entry Data
    -- ValueKeyOverride: An entry specific override to the value key to alter
    -- OnClick func: Function to call on click, to alter the filter value appropriately
    -- checked: true/false/func/nil (Where nil = not checkable)
    -- nested: (optional) dropdown table or dataProvider func to generate it. Nil for no subdropdown for the button.
-- Optional nested dropdown table (Standard dropdown format)


-- Dropdown Types:
    -- Simple
    -- Comp
    -- Setting

-------------------------------------------------------------------------


---------------------------------
-- Helper Functions
---------------------------------

function Dropdown:RetrieveValue(valueOrFunc, contextFrame)
    assert(contextFrame ~= nil);
    
    if(type(valueOrFunc) == "function") then
        return valueOrFunc(contextFrame);
    end
    return valueOrFunc;
end

function Dropdown:CallSetDisplay(dropdownContext)
    if(dropdownContext and dropdownContext.displayFunc) then
        dropdownContext.displayFunc(dropdownContext);
        
        if(dropdownContext.display) then
            assert(dropdownContext.display.GetWidth, "Assertion failed: Dropdown display must support GetWidth(). Context: ", dropdownContext:GetName());
        end
    end
end

function Dropdown.SetTextDisplay(dropdownContext)
    assert(dropdownContext);
    --ArenaAnalytics:Log(dropdownContext:GetName(), "had its display set!");

    local label = Dropdown:RetrieveValue(dropdownContext.label, dropdownContext);
    assert(label);

    label = label:gsub("|", "||");

    local hex = dropdownContext.fontColor;
    if(hex) then
        label = "|cff" .. hex .. label .. "|r";
        ArenaAnalytics:Log(label);
    end

    if(true) then
        dropdownContext.btn:SetText(label);
        return;
    end

    local size = dropdownContext.fontSize;
    local offsetX = dropdownContext.offsetX or 0;
    local alignment = dropdownContext.alignment or "LEFT";

    if(dropdownContext.checkbox) then
        offsetX = offsetX + dropdownContext.checkbox:GetWidth();
    end

    dropdownContext.display = dropdownContext:GetFrame():CreateFontString(nil, "OVERLAY");
    dropdownContext.display:SetFont("Fonts\\FRIZQT__.TTF", size or 12, "");
    dropdownContext.display:SetPoint(alignment, offsetX + 5, 0);
    dropdownContext.display:SetText(label);

end

---------------------------------
-- Active Dropdowns
---------------------------------

-- Active dropdown lists
Dropdown.dropdownLevelFrames = {}

function Dropdown:IsActiveDropdownLevel(level)
    return level and Dropdown.dropdownLevelFrames[level] ~= nil or false;
end

function Dropdown:GetHighestActiveDropdownLevel()
    assert(Dropdown.dropdownLevelFrames[#Dropdown.dropdownLevelFrames]);

    return #Dropdown.dropdownLevelFrames;
end

-- Returns true of any active dropdown is mouseover
function Dropdown:IsAnyMouseOver()
    for i=1, #Dropdown.dropdownLevelFrames do
        local dropdown = Dropdown.dropdownLevelFrames[i]
        if(dropdown and dropdown:IsMouseOver()) then
            return true;
        end
    end

    return false;
end

function Dropdown:AddActiveDropdown(level, dropdown)
    Dropdown:HideActiveDropdownsFromLevel(level, true);

    for i=1, level-1 do
        assert(Dropdown.dropdownLevelFrames[i]);
    end

    Dropdown.dropdownLevelFrames[level] = dropdown;
end

function Dropdown:HideActiveDropdownsFromLevel(level, destroy)
    for i = #Dropdown.dropdownLevelFrames, level, -1 do
        if Dropdown.dropdownLevelFrames[i] then
            Dropdown.dropdownLevelFrames[i]:Hide();

            if(destroy) then
                Dropdown.dropdownLevelFrames[i] = nil;
                table.remove(Dropdown.dropdownLevelFrames, i);
            end
        end
    end
end

function Dropdown:CloseAll(destroy)
    Dropdown:HideActiveDropdownsFromLevel(1, destroy);
end

function Dropdown:RefreshAll()
    for i = #Dropdown.dropdownLevelFrames, 1, -1 do
        --ArenaAnalytics:Print("Refreshing all loop")
        Dropdown.dropdownLevelFrames[i]:Refresh("Dropdown:RefreshAll");
    end
end

function Dropdown:MakeListInfoTable(info, context)
    context = context or self;
    local retrievedInfo = Dropdown:RetrieveValue(info, context);

    local listInfo = {};
    listInfo.meta = retrievedInfo.meta or {};
    listInfo.entries = retrievedInfo.entries or retrievedInfo or {};

    return listInfo;
end

---------------------------------
-- Dropdown Core
---------------------------------

function Dropdown:Create(parent, dropdownType, frameName, config, width, height)
    local self = setmetatable({}, Dropdown);
    self.owner = parent;
    self.name = frameName.."Dropdown";

    self.width = width;
    self.height = height;

    self.frame = CreateFrame("Frame", self.name, parent);
    self.frame:SetPoint("CENTER");
    self.frame:SetSize(width, height);

    self.type = dropdownType;

    self.entries = config.entries;
    self.listInfo = self:MakeListInfoTable(config.entries);

    -- Update meta data, if any was explicitly provided
    self.listInfo.meta.width = width or self.listInfo.width;
    self.listInfo.meta.height = height or self.listInfo.height;

    -- Setup the button 
    if(config.mainButton ~= nil) then
        if(config.mainButton.isParent) then
            self.selected = parent;
        else
            self.selected = Dropdown.Button:Create(self, width, height, config.mainButton);
            self.owner = self.selected.btn;
        end
    end
    
    return self;
end

function Dropdown:Refresh(debugContext)
    if(self.selected) then
        self.selected:Refresh((debugContext or "??") .. " -> Dropdown:Refresh");
    end
    
    Dropdown:RefreshAll("Dropdown:Refresh RefreshAll");
end

---------------------------------
-- Simple getters
---------------------------------

function Dropdown:GetOwner()
    return self.owner;
end

function Dropdown:GetSelectedFrame()
    return self.selected;
end

function Dropdown:GetFrame()
    return self.frame;
end

function Dropdown:GetName()
    return self.name;
end

function Dropdown:GetDropdownType()
    return self.type;
end

---------------------------------
-- Enabled State
---------------------------------

function Dropdown:SetEnabled(state)
    if(state == false) then
        self:Hide();
    end

    if(state ~= self:IsEnabled()) then
        if(state) then
            self.selected:Enable();
        else
            self.selected:Disable();
        end
    end
end

function Dropdown:Disable()
    self:SetEnabled(false);
end

function Dropdown:Enable()
    self:SetEnabled(true);
end

function Dropdown:IsEnabled()
    return self.selected:IsEnabled();
end

---------------------------------
-- Points
---------------------------------

-- Set the point of the main dropdown button
function Dropdown:SetPoint(...)
    self.frame:SetPoint(...);
end

---------------------------------
-- Visibility
---------------------------------

function Dropdown:IsShown()
    return self.list and self.list:IsShown();
end

function Dropdown:Toggle()
    if(self:IsShown()) then
        self:Hide();
    else
        self:Show();
    end
end

function Dropdown:Show()
    if(not self:IsShown()) then
        self.list = Dropdown.List:Create(self, 1, self.width, self.height, self.entries);
        self.list:SetPoint("TOP", self.selected:GetFrame(), "BOTTOM");
        self.list:Show();
    end
end

function Dropdown:Hide()
    if(self.list) then
        self.list:Hide();
        self.list = nil;
    end
end

---------------------------------
-- Other
---------------------------------

function Dropdown:CreateFontString(...)
    return self.selected.btn:CreateFontString(...);
end