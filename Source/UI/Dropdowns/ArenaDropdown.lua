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

function internal:RetrieveValue(valueOrFunc, dropdownButton)
    if(type(valueOrFunc) == "function") then
        return valueOrFunc(dropdownButton);
    end
    return valueOrFunc;
end

function Dropdown:CreateNew(dropdownType, frameName, parent, width, height, config)
    local self = setmetatable({}, Dropdown);
    self.frame = CreateFrame("Frame", frameName.."Frame", parent);
    self.frame:SetPoint("CENTER");
    self.frame:SetSize(width, height);

    self.name = frameName;
    self.type = dropdownType;

    -- Setup the button 
    self.selected = Dropdown.Button:Create(self, true, nil, width, height, config.mainButton);
    
    -- Setup the main dropdown level
    self.list = Dropdown.List:Create(self, true, width, height, config.entries);

    return self
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

function Dropdown:DebugPrint()
    local function log(level, ...)
        description = description or "nil";
        value = value or "nil";
        level = tonumber(level) or 0;

        local indentation = "";
        for i=1, level do
            indentation = indentation .. "   ";
        end

        ArenaAnalytics:Log(indentation, ...);
    end

    print(" ");
    log(0, "Arena Dropdown");
    log(1, "name:", self.name);
    log(1, "parent:", self.frame:GetParent():GetName(), "  (", self.frame:GetParent(), ")");
    log(1, "point:", self.frame:GetPoint());
    log(1, "visible:", self.frame:IsVisible());

    
    log(2, "btn visible:", self.selected.btn:IsVisible());
    log(2, "btn size:", self.selected.btn:GetSize());
    log(2, "btn point", self.selected.btn:GetPoint());
    log(2, "btn parent:", self.selected.btn:GetParent():GetName());
end