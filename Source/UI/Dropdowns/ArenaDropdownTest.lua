local _, ArenaAnalytics = ...; -- Addon Namespace
local Dropdown = ArenaAnalytics.Dropdown;

-------------------------------------------------------------------------
-- Test Dropdown Usage

local function SetFilterValue(entry, btn)
    if(btn == "RightButton") then
        Filters:Reset(entry.key);
    else
        Filters:Set(entry.key, (entry.value or entry.label));
    end
end

local function ResetFilterValue(entry, btn)
    Filters:Reset(entry.key);
end

local function IsFilterEntryChecked(entry)
    return Filters:Get(entry.key) == (entry.value or entry.label);
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

local moreFiltersData = {
    mainButton = {
        label = "More Filters",
        onClick = function() ArenaAnalytics:Log("More Filters clicked") end,
    },
    entries = {
        {
            label = "Season",
            value = "Season",
            key = "Filter_Season",
            nested = generateSeasonData,
            onClick = ResetFilterValue,
            checked = nil,
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
            checked = nil,
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
            checked = nil,
            tooltip = "Filter matches by map",
        }
    }
}

function Dropdown:CreateTest()
    Dropdown:CreateNew("Simple", "TestDropdown", UIParent, 100, 50, moreFiltersData);
end