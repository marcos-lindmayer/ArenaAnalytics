local _, ArenaAnalytics = ...; -- Addon Namespace
local FilterTables = ArenaAnalytics.FilterTables;

-- Local module aliases
local API = ArenaAnalytics.API;
local Filters = ArenaAnalytics.Filters;
local Internal = ArenaAnalytics.Internal;

-------------------------------------------------------------------------


FilterTables.moreFilters = {}

local function GenerateSeasonData()
    local currentSeason = GetCurrentArenaSeason()
    local latestSeason =  math.max(currentSeason, (tonumber(ArenaAnalytics:GetLatestSeason()) or 0));
    if(latestSeason == nil or latestSeason == 0) then
        ArenaAnalytics:Log("Invalid latest season. Unable to add seasons");
        return;
    end

    local seasons = {
        {
            label = "All Seasons",
            alignment = "LEFT",
            key = "Filter_Season",
            value = "All",
            onClick = FilterTables.SetFilterValue,
            checked = FilterTables.IsFilterEntryChecked,
        },
        {
            label = "Current Season",
            alignment = "LEFT",
            key = "Filter_Season",
            onClick = FilterTables.SetFilterValue,
            checked = FilterTables.IsFilterEntryChecked,
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
        -- Add expansion title
        for _,expansion in ipairs(expansions) do
            if(expansion[2] == season) then
                table.insert(seasons, {
                    isTitle = true,
                    label = expansion[1],
                    offsetX = 7,
                    fontColor = "FFD100",
                    alignment = "LEFT",
                });
                break;
            end
        end

        table.insert(seasons, {
            label = "Season " .. season,
            alignment = "LEFT",
            value = season,
            key = "Filter_Season",
            onClick = FilterTables.SetFilterValue,
            checked = function() return Filters:Get("Filter_Season") == season end,
        });
    end

    return seasons
end

local function GenerateDateEntries(dates)
    local dateTable = {}

    for _,date in ipairs(dates) do
        assert(date and date ~= "", "Invalid Date in dates table.");

        tinsert(dateTable, {
            label = date,
            alignment = "LEFT",
            key = "Filter_Date",
            onClick = FilterTables.SetFilterValue,
            checked = FilterTables.IsFilterEntryChecked,
        });
    end

    return dateTable;
end

local function GenerateMapEntries(maps)
    local mapTable = {}

    for _,data in ipairs(maps) do
        assert(data and data.name ~= "", "Invalid map in available maps table.");

        tinsert(mapTable, {
            label = data.name,
            alignment = "LEFT",
            key = "Filter_Map",
            value = Internal:GetAddonMapID(data.key),
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
    local dates = {"All Time" , "Current Session", "Last Day", "Last Week", "Last Month", "Last 3 Months", "Last 6 Months", "Last Year"};

    FilterTables.moreFilters = {
        mainButton = {
            label = "More Filters",
            alignment = "CENTER",
            onClick = OnMainButtonClicked,
        },
        entries = {
            {
                label = "Season",
                alignment = "LEFT",
                key = "Filter_Season",
                nested = GenerateSeasonData,
                onClick = FilterTables.ResetFilterValue,
                checked = FilterTables.IsFilterActive,
            },
            {
                label = "Date",
                alignment = "LEFT",
                key = "Filter_Date",
                nested = GenerateDateEntries(dates), -- Generate immediately (Static)
                onClick = FilterTables.ResetFilterValue,
                checked = FilterTables.IsFilterActive,
            },
            {
                label = "Maps",
                alignment = "LEFT",
                key = "Filter_Map",
                nested = GenerateMapEntries(API.availableMaps),
                onClick = FilterTables.ResetFilterValue,
                checked = FilterTables.IsFilterActive,
            },
        },        
    }
end