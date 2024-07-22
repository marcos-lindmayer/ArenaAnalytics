local _, ArenaAnalytics = ...; -- Addon Namespace
local Dropdown = ArenaAnalytics.Dropdown;

-- Local module aliases
local Filters = ArenaAnalytics.Filters;

-------------------------------------------------------------------------
-- Test Dropdown Usage

local function SetFilterValue(dropdownButton, btn)
    if(btn == "RightButton") then
        Filters:Reset(dropdownButton.key);
    else
        Filters:Set(dropdownButton.key, (dropdownButton.value or dropdownButton.label));
    end

    Filters:Refresh();
    dropdownButton:Refresh();
end

local function ResetFilterValue(dropdownButton, btn)
    assert(dropdownButton.key ~= nil);

    Filters:Reset(dropdownButton.key);
    dropdownButton:Refresh();
end

local function IsFilterEntryChecked(dropdownButton)
    return Filters:Get(dropdownButton.key) == (dropdownButton.value or dropdownButton.label);
end

local function IsFilterActive(dropdownButton)
    assert(dropdownButton.key)
    return Filters:IsFilterActive(dropdownButton.key);
end

local function generateSeasonData()
    local currentSeason = GetCurrentArenaSeason()
    local seasons = {}

    tinsert(seasons, {
        label = "All",
        key = "Filter_Season",
        onClick = SetFilterValue,
    });

    local expansions = {
        {"The Burning Crusade", 1},
        {"Wrath of the Lich King", 5},
        {"Cataclysm", 9},
        {"Mists of Pandaria", 12},
        {"Warlords of Draenor", 16},
        {"Legion", 19},
        {"Battle for Azeroth", 26},
        {"Shadowlands", 30},
        {"Dragonflight", 34},
    }

    for season=1, lastSeason do
        local seasonText = "Season " .. season;

        for _,expansion in ipairs(expansions) do
            if(expansion[2] == season) then
                -- Add expansion title

                info.text = expansion[1];
                UIDropDownMenu_AddButton(info, level);
                break;
            end

            table.insert(seasons, {
                label = "Season " .. season,
                value = season,
                key = "Filter_Season",
                onClick = SetFilterValue,
                checked = function() return Filter:GetCurrent("Filter_Season") == season end,
            });
        end

        
    end

    for _, expansion in ipairs(expansions) do
        local title, firstSeason = expansion[1], expansion[2]
        table.insert(seasons, {label = title, type = "title"})
        for season = 1, currentSeason do
            table.insert(seasons, {
                label = "Season " .. season,
                value = "Season" .. season,
                onClick = SetFilterValue,
                checked = IsFilterEntryChecked,
            })
        end
    end

    return seasons
end

local function AddTestEntry(label)
return {
        label = label,
        key = "Filter_Map",
        nested = {
            { label = "All",                key = "Filter_Map",     onClick = SetFilterValue,   checked = IsFilterEntryChecked },
            { label = "Nagrand Arena",      key = "Filter_Map",     onClick = SetFilterValue,   checked = IsFilterEntryChecked },
            { label = "Blade's Edge Arena", key = "Filter_Map",     onClick = SetFilterValue,   checked = IsFilterEntryChecked },
            { label = "Dalaran Arena",      key = "Filter_Map",     onClick = SetFilterValue,   checked = IsFilterEntryChecked },
            { label = "Ruins of Lordaeron", key = "Filter_Map",     onClick = SetFilterValue,   checked = IsFilterEntryChecked }
        },
        onClick = ResetFilterValue,
        checked = IsFilterActive,
        tooltip = "Filter matches by map",
    };
end

local moreFiltersConfig = {
    mainButton = {
        label = "More Filters",
    },
    entries = {
        {
            label = "Season",
            key = "Filter_Season",
            nested = generateSeasonData,
            onClick = ResetFilterValue,
            checked = IsFilterActive,
            tooltip = "Filter matches by season"
        },
        {
            label = "Date",
            key = "Filter_Date",
            nested = {
                { label = "All Time",           key = "Filter_Date",    onClick = SetFilterValue,   checked = IsFilterEntryChecked },
                { label = "Current Session",    key = "Filter_Date",    onClick = SetFilterValue,   checked = IsFilterEntryChecked },
                { label = "Today",              key = "Filter_Date",    onClick = SetFilterValue,   checked = IsFilterEntryChecked },
                { label = "Last Week",          key = "Filter_Date",    onClick = SetFilterValue,   checked = IsFilterEntryChecked },
                { label = "Last Month",         key = "Filter_Date",    onClick = SetFilterValue,   checked = IsFilterEntryChecked }
            },
            onClick = ResetFilterValue,
            checked = IsFilterActive,
            tooltip = "Filter matches by date"
        },
        {
            label = "Maps",
            key = "Filter_Map",
            nested = {
                { label = "All",                key = "Filter_Map",     onClick = SetFilterValue,   checked = IsFilterEntryChecked },
                { label = "Nagrand Arena",      key = "Filter_Map",     onClick = SetFilterValue,   checked = IsFilterEntryChecked },
                { label = "Blade's Edge Arena", key = "Filter_Map",     onClick = SetFilterValue,   checked = IsFilterEntryChecked },
                { label = "Dalaran Arena",      key = "Filter_Map",     onClick = SetFilterValue,   checked = IsFilterEntryChecked },
                { label = "Ruins of Lordaeron", key = "Filter_Map",     onClick = SetFilterValue,   checked = IsFilterEntryChecked }
            },
            onClick = ResetFilterValue,
            checked = IsFilterActive,
            tooltip = "Filter matches by map",
        },
        AddTestEntry("Test1"),
        AddTestEntry("Test2"),
        AddTestEntry("Test3"),
        AddTestEntry("Test4"),
        AddTestEntry("Test5"),
        AddTestEntry("Test6"),
        AddTestEntry("Test7"),
        AddTestEntry("Test8"),
        AddTestEntry("Test9"),
        AddTestEntry("Test10"),
        AddTestEntry("Test11"),
        AddTestEntry("Test12"),
        AddTestEntry("Test13"),
        AddTestEntry("Test14"),
        AddTestEntry("Test15"),
        AddTestEntry("Test16"),
        AddTestEntry("Test17"),
        AddTestEntry("Last Entry"),
    }
}

Dropdown.testDropdown = nil;
function Dropdown:CreateTest()
    if(Dropdown.testDropdown) then
        Dropdown.testDropdown:Hide();

        if(Dropdown.testDropdown.selected:IsVisible()) then
            Dropdown.testDropdown.selected:Hide();
        else
            Dropdown.testDropdown.selected:Show();
        end
        return;
    end

    Dropdown.testDropdown = Dropdown:CreateNew("Simple", "TestDropdown", UIParent, 200, 25, moreFiltersConfig);
    Dropdown.testDropdown:SetPoint("CENTER", UIParent, "CENTER", 0, 350);
end