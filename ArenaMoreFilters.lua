local _, ArenaAnalytics = ...;
ArenaAnalytics.MoreFilters = {};

local MoreFilters = ArenaAnalytics.MoreFilters;

-------------------------------------------------------------------------

-- Main dropdown menu items (In reverse order!)
local dropdownInfo = {
    ["Filter_Date"] = { ["text"] = "Date", ["options"] = {"All Time" , "Current Session", "Last day", "Last week", "Last Month", "Last 3 months", "Last 6 months", "Last year"} },
    ["Filter_Season"] = { ["text"] = "Season", ["options"] = {"All" , "Current Season"} },
    ["Filter_Map"] = { ["text"] = "Maps", ["options"] = {"All" ,"Nagrand Arena" ,"Ruins of Lordaeron", "Blade Edge Arena", "Dalaran Arena"} },
}

-------------------------------------------------------------------------

local titlePrefix = "Title:";
local function addDynamicOptions_Season(self, level, filter, info, settings)
    -- TODO: Custom logic for filling out season (Group by expansion and disable/hide if no matches were played that season?)
    local lastSeason =  math.max(GetCurrentArenaSeason(), (tonumber(ArenaAnalytics:getLastSeason()) or 0));
    if(lastSeason == nil or lastSeason == 0) then
        ArenaAnalytics:Log("Invalid last season. Unable to add seasons");
        return;
    end

    -- First season of each expansion
    local expansions = {
        {"The Burning Crusade", 1},
        {"Wrath of the Lich King", 5},
        {"Cataclysm", 9},
    }

    -- Add seasons
    for season=1, lastSeason do
        local seasonText = "Season " .. season;

        for _,expansion in ipairs(expansions) do
            if(expansion[2] == season) then
                -- Add expansion title
                info.isTitle = true;
                info.notCheckable = true;
                info.disabled = false;

                info.text = expansion[1];
                UIDropDownMenu_AddButton(info, level);
                break;
            end
        end

        info.isTitle = false;
        info.notCheckable = false;
        info.disabled = false;
        info.func = self.SetValue;
        info.arg1 = filter;
        info.arg2 = season;
        info.checked = (season == ArenaAnalytics.Filter.currentFilters[filter]);
        info.text = seasonText;

        UIDropDownMenu_AddButton(info, level);
    end
end
 
-- Create the dropdown, and configure its appearance
MoreFilters.dropdown = CreateFrame("Frame", "MoreFiltersDropdownFrame", ArenaAnalyticsScrollFrame.filterBtn_MoreFilters, "UIDropDownMenuTemplate")

-- Create and bind the initialization function to the dropdown menu
UIDropDownMenu_Initialize(MoreFilters.dropdown, function(self, level, filter)
    local info = UIDropDownMenu_CreateInfo()
    
    if ((level or 1) == 1) then
        -- Fill dropdown menu with filters
        for key,values in pairs(dropdownInfo) do
            info.text = values["text"];
            info.notCheckable = false;
            info.menuList = key;
            info.hasArrow = values["options"] and #values["options"] > 0;
            UIDropDownMenu_AddButton(info);
        end
        return;
    end
    
    local settings = dropdownInfo[filter];
    if(settings == nil) then
        return;
    end

    local options = (settings and settings["options"]) and settings["options"] or {}
    
    if(options and #options > 0) then
        for _,option in ipairs(options) do
            info.isTitle = false;
            info.notCheckable = false;
            info.disabled = false;
            info.topPadding = 1;
            info.func = self.SetValue;
            info.arg1 = filter;
            info.arg2 = option;
            info.checked = (option == ArenaAnalytics.Filter.currentFilters[filter]);

            info.text = option;
            UIDropDownMenu_AddButton(info, level);
        end
    else
        ArenaAnalytics:Log("MoreFilters dropdown submenu failed to find options for filter: ", filter);
    end

    -- Add dynamic options
    if (filter == "Filter_Season") then
        addDynamicOptions_Season(self, level, filter, info, settings);
    end
end);

-- Implement the function to change the value for a given filter
function MoreFilters.dropdown:SetValue(filter, newValue)
    -- Update the filter for the new value
    ArenaAnalytics.Filter:updateFilter(filter, newValue);
    ArenaAnalytics:Log("MoreFiltersDropdown SetValue(", filter, ",", newValue, ")");
    CloseDropDownMenus();
end

-------------------------------------------------------------------------