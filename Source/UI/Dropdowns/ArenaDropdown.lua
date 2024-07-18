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

-- Internal functions
Dropdown._internal = {}
local internal = Dropdown._internal;

function internal:RetrieveValue(valueOrFunc)
    if(type(valueOrFunc) == "function") then
        return valueOrFunc();
    end
    return valueOrFunc;
end


function Dropdown:CreateNew(dropdownType, frameName, parent, width, height, config)
    local self = setmetatable({}, Dropdown);
    self.frame = CreateFrame("Frame", frameName.."Frame", parent);

    self.name = frameName;
    self.type = dropdownType;

    -- Setup the button 
    self.selected = Dropdown.Button:Create(self, nil, width, height, config.mainButton);

    -- Setup the main dropdown level
    self.list = Dropdown.List:Create(self, width, config.entries);



    return self
end

function Dropdown:GetFrame()
    return self.frame;
end

function Dropdown:Toggle()
    self.list:Toggle();
end

function Dropdown:IsVisible()
    self.list:IsVisible();
end