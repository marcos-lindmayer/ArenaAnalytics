local _, ArenaAnalytics = ...; -- Addon Namespace
local FilterTables = ArenaAnalytics.FilterTables;

-- Local module aliases
local API = ArenaAnalytics.API;
local Filters = ArenaAnalytics.Filters;

-------------------------------------------------------------------------


FilterTables.moreFilters = { }

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
                    fontColor = "FFD100",
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

local dates = {"All Time" , "Current Session", "Last Day", "Last Week", "Last Month", "Last 3 Months", "Last 6 Months", "Last Year"};
local function GenerateDateEntries(dates)
    local dateTable = {}

    for _,date in ipairs(dates) do
        tinsert(dateTable, {
            label = date or "???",
            key = "Filter_Date",
            onClick = FilterTables.SetFilterValue,
            checked = FilterTables.IsFilterEntryChecked,
        });
    end

    return dateTable;
end

local function GenerateMapEntries(maps)
    local mapTable = {}

    for _,map in ipairs(maps) do
        tinsert(mapTable, {
            label = map or "???",
            key = "Filter_Map",
            onClick = FilterTables.SetFilterValue,
            checked = FilterTables.IsFilterEntryChecked,
        });
    end

    return mapTable;
end

local function OnMainButtonClicked(dropdownContext, btn)
    if(btn == "RightButton") then
        Filters:Reset("Filter_Season", true);
        Filters:Reset("Filter_Date", true);
        Filters:Reset("Filter_Map", true);
    else
        dropdownContext.parent:Toggle();
    end
end

function FilterTables:Init_MoreFilters()
    FilterTables.moreFilters = {
        mainButton = {
            label = "More Filters",
            onClick = OnMainButtonClicked,
        },
        entries = {
            {
                label = "Season",
                key = "Filter_Season",
                nested = GenerateSeasonData,
                onClick = FilterTables.ResetFilterValue,
                checked = FilterTables.IsFilterActive,
            },
            {
                label = "Date",
                key = "Filter_Date",
                nested = GenerateDateEntries(dates), -- Generate immediately (Static)
                onClick = FilterTables.ResetFilterValue,
                checked = FilterTables.IsFilterActive,
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
            },
        }
    }
end