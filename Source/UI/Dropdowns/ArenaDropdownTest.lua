local _, ArenaAnalytics = ...; -- Addon Namespace
local Dropdown = ArenaAnalytics.Dropdown;

-- Local module aliases
local Filters = ArenaAnalytics.Filters;
local FilterTables = ArenaAnalytics.FilterTables;

-------------------------------------------------------------------------
-- Test Dropdown Usage

local function GenerateSeasonData()
    local currentSeason = GetCurrentArenaSeason()
    local latestSeason =  math.max(currentSeason, (tonumber(ArenaAnalytics:GetLatestSeason()) or 0));
    if(latestSeason == nil or latestSeason == 0) then
        ArenaAnalytics:Log("Invalid latest season. Unable to add seasons");
        return;
    end

    local seasons = {
        {
            label = "All",
            key = "Filter_Season",
            onClick = FilterTables.SetFilterValue,
            checked = FilterTables.IsFilterEntryChecked
        },
        {
            label = "Current Season",
            key = "Filter_Season",
            onClick = FilterTables.SetFilterValue,
            checked = FilterTables.IsFilterEntryChecked
        }
    }

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

    for season=1, latestSeason do
        local seasonText = "Season " .. season;

        for _,expansion in ipairs(expansions) do
            if(expansion[2] == season) then
                -- Add expansion title
                -- TODO: Implement title entries    
                table.insert(seasons, {
                    label = expansion[1],
                });
                break;
            end
        end

        table.insert(seasons, {
            label = "Season " .. season,
            value = season,
            key = "Filter_Season",
            onClick = FilterTables.SetFilterValue,
            checked = function() return Filters:GetCurrent("Filter_Season") == season end,
        });
    end

    return seasons
end

local function AddTestEntry(label)
    if(true) then
        return {
            label = label,
            key = "Filter_Map",
            nested = {
                { label = "All",                key = "Filter_Map",     onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked },
                { label = "Nagrand Arena",      key = "Filter_Map",     onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked },
                { label = "Blade's Edge Arena", key = "Filter_Map",     onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked },
                { label = "Dalaran Arena",      key = "Filter_Map",     onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked },
                { label = "Ruins of Lordaeron", key = "Filter_Map",     onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked }
            },
            onClick = FilterTables.ResetFilterValue,
            checked = FilterTables.IsFilterActive,
            tooltip = "Filter matches by map",
        };
    end
end

local moreFiltersConfig = {
    mainButton = {
        label = "More Filters"
    },
    entries = {
        {
            label = "Season",
            key = "Filter_Season",
            nested = GenerateSeasonData,
            onClick = FilterTables.ResetFilterValue,
            checked = FilterTables.IsFilterActive,
            tooltip = "Filter matches by season"
        },
        {
            label = "Date",
            key = "Filter_Date",
            nested = {
                { label = "All Time",           key = "Filter_Date",    onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked },
                { label = "Current Session",    key = "Filter_Date",    onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked },
                { label = "Last Day",           key = "Filter_Date",    onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked },
                { label = "Last Week",          key = "Filter_Date",    onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked },
                { label = "Last Month",         key = "Filter_Date",    onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked }
            },
            onClick = FilterTables.ResetFilterValue,
            checked = FilterTables.IsFilterActive,
            tooltip = "Filter matches by date"
        },
        {
            label = "Maps",
            key = "Filter_Map",
            nested = {
                { label = "All",                key = "Filter_Map",                 onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked },
                { label = "Nagrand Arena",      key = "Filter_Map", value = "NA",   onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked },
                { label = "Blade's Edge Arena", key = "Filter_Map", value = "BEA",  onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked },
                { label = "Dalaran Arena",      key = "Filter_Map", value = "DA",   onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked },
                { label = "Ruins of Lordaeron", key = "Filter_Map", value = "RoL",  onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked }
            },
            onClick = FilterTables.ResetFilterValue,
            checked = FilterTables.IsFilterActive,
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

        if(Dropdown.testDropdown.selected:IsShown()) then
            Dropdown.testDropdown.selected:Hide();
        else
            Dropdown.testDropdown.selected:Show();
        end
        return;
    end

    Dropdown.testDropdown = Dropdown:Create(UIParent, "Simple", "TestDropdown", moreFiltersConfig, 200, 25);
    Dropdown.testDropdown:SetPoint("CENTER", UIParent, "CENTER", 0, 350);
end

local moreFiltersConfig = {
    mainButton = {
        label = "More Filters"
    },
    entries = {
        {
            label = "Season",
            key = "Filter_Season",
            nested = GenerateSeasonData,
            onClick = FilterTables.ResetFilterValue,
            checked = FilterTables.IsFilterActive,
            tooltip = "Filter matches by season"
        },
        {
            label = "Date",
            key = "Filter_Date",
            nested = {
                { label = "All Time",           key = "Filter_Date",   onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked },
                { label = "Current Session",    key = "Filter_Date",   onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked },
                { label = "Last Day",           key = "Filter_Date",   onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked },
                { label = "Last Week",          key = "Filter_Date",   onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked },
                { label = "Last Month",         key = "Filter_Date",   onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked }
            },
            onClick = FilterTables.ResetFilterValue,
            checked = FilterTables.IsFilterActive,
            tooltip = "Filter matches by date"
        },
        {
            label = "Maps",
            key = "Filter_Map",
            nested = {
                { label = "All",                key = "Filter_Map",                   onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked },
                { label = "Nagrand Arena",      key = "Filter_Map",   value = "NA",   onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked },
                { label = "Blade's Edge Arena", key = "Filter_Map",   value = "BEA",  onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked },
                { label = "Dalaran Arena",      key = "Filter_Map",   value = "DA",   onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked },
                { label = "Ruins of Lordaeron", key = "Filter_Map",   value = "RoL",  onClick = FilterTables.SetFilterValue,   checked = FilterTables.IsFilterEntryChecked }
            },
            onClick = FilterTables.ResetFilterValue,
            checked = FilterTables.IsFilterActive,
            tooltip = "Filter matches by map",
        },
    }
}