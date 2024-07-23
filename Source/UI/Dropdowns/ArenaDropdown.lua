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
-- Internal Functions
---------------------------------

Dropdown._internal = {}
local internal = Dropdown._internal;

function internal:RetrieveValue(valueOrFunc, dropdownEntryFrame)
    if(type(valueOrFunc) == "function") then
        return valueOrFunc(dropdownEntryFrame);
    end
    return valueOrFunc;
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
    Dropdown:HideActiveDropdownsFromLevel(level+1, true);

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
            end
        end
    end
end

function Dropdown:CloseAllDropdowns(destroy)
    Dropdown:HideActiveDropdownsFromLevel(1, destroy);
end

---------------------------------
-- Check Match for Search
---------------------------------

function Dropdown:CreateNew(parent, dropdownType, frameName, width, height, config)
    local self = setmetatable({}, Dropdown);
    self.owner = parent;

    self.frame = CreateFrame("Frame", frameName.."Frame", parent);
    self.frame:SetPoint("CENTER");
    self.frame:SetSize(width, height);

    self.name = frameName;
    self.type = dropdownType;

    -- Setup the button 
    if(config.mainButton ~= nil) then
        self.selected = Dropdown.Button:Create(self, width, height, config.mainButton);
        self.owner = self.selected.btn;
    end
    
    -- Setup the main dropdown level
    self.list = Dropdown.List:Create(self, 1, width, height, config.entries);
    self.list:SetPoint("TOP", self.selected:GetFrame(), "BOTTOM");

    return self
end

function Dropdown:GetOwner()
    return self.owner;
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

-- Set the point of the main dropdown button
function Dropdown:SetPoint(...)
    self.frame:SetPoint(...);
end

function Dropdown:Toggle()
    self.list:Toggle();
end

function Dropdown:Hide()
    self.list:Hide();
end

function Dropdown:IsVisible()
    self.list:IsVisible();
end