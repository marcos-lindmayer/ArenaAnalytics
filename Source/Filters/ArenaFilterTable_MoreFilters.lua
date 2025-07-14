local _, ArenaAnalytics = ...; -- Addon Namespace
local FilterTables = ArenaAnalytics.FilterTables;

-- Local module aliases
local API = ArenaAnalytics.API;
local Filters = ArenaAnalytics.Filters;
local Internal = ArenaAnalytics.Internal;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------


FilterTables.moreFilters = {}

local function GenerateSeasonData()
    local currentSeason = API:GetCurrentSeason() or 0;

    local latestSeason = tonumber(ArenaAnalytics:GetLatestSeason()) or 0;
    latestSeason =  math.max(currentSeason, latestSeason, 0);

    if(latestSeason == nil or latestSeason == 0) then
        Debug:Log("Invalid latest season. Unable to add seasons");
        return;
    end

    local seasons = {
        {
            label = "All Seasons",
            alignment = "LEFT",
            key = Filters.FilterKeys.Season,
            value = "All",
            onClick = FilterTables.SetFilterValue,
            checked = FilterTables.IsFilterEntryChecked,
        },
        {
            label = "Current Season",
            alignment = "LEFT",
            key = Filters.FilterKeys.Season,
            onClick = FilterTables.SetFilterValue,
            checked = FilterTables.IsFilterEntryChecked,
        };
    };

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
        {"The War Within", 38},
    };

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
            key = Filters.FilterKeys.Season,
            onClick = FilterTables.SetFilterValue,
            checked = function() return Filters:Get(Filters.FilterKeys.Season) == season end,
        });
    end

    return seasons;
end

local function GenerateDateEntries(dates)
    local dateTable = {}

    for _,date in ipairs(dates) do
        assert(date and date ~= "", "Invalid Date in dates table.");

        tinsert(dateTable, {
            label = date,
            alignment = "LEFT",
            key = Filters.FilterKeys.Date,
            onClick = FilterTables.SetFilterValue,
            checked = FilterTables.IsFilterEntryChecked,
        });
    end

    return dateTable;
end

local function GenerateMapEntries()
    assert(API.availableMaps);

    local mapTable = {
        {
            label = "All Maps",
            alignment = "LEFT",
            key = Filters.FilterKeys.Map,
            value = "All",
            onClick = FilterTables.SetFilterValue,
            checked = FilterTables.IsFilterEntryChecked,
        },
    };

    for idx,token in ipairs(API.availableMaps) do
        local map_id = Internal:GetAddonMapID(token);
        assert(map_id, "Invalid map token in availableMaps: " .. (token or "nil") .. ", at index: " .. (idx or "nil"));

        tinsert(mapTable, {
            label = Internal:GetMapName(map_id),
            alignment = "LEFT",
            key = Filters.FilterKeys.Map,
            value = map_id,
            onClick = FilterTables.SetFilterValue,
            checked = FilterTables.IsFilterEntryChecked,
        });
    end

    return mapTable;
end

local function GenerateOutcomeEntries()
    local outcomes = {
        {label = "Any", value = "All"},
        {label = "Wins", value = 1},
        {label = "Losses", value = 0},
        {label = "Draws", value = 2}
    };

    local outcomeTable = {}

    for _, entry in ipairs(outcomes) do
        tinsert(outcomeTable, {
            label = entry.label,
            alignment = "LEFT",
            key = Filters.FilterKeys.Outcome,
            value = entry.value,
            onClick = FilterTables.SetFilterValue,
            checked = FilterTables.IsFilterEntryChecked,
        });
    end

    return outcomeTable;
end

local function OnMainButtonClicked(dropdownContext, btn)
    if(btn == "RightButton") then
        local changed = false;

        changed = Filters:ResetFast(Filters.FilterKeys.Season, true) or changed;
        changed = Filters:ResetFast(Filters.FilterKeys.Date, true) or changed;
        changed = Filters:ResetFast(Filters.FilterKeys.Map, true) or changed;
        changed = Filters:ResetFast(Filters.FilterKeys.Outcome, true) or changed;
        changed = Filters:ResetFast(Filters.FilterKeys.Mirror) or changed;

        if(changed) then
            Filters:Refresh();
        end
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
                key = Filters.FilterKeys.Season,
                nested = GenerateSeasonData,
                onClick = FilterTables.ResetFilterValue,
                checked = FilterTables.IsFilterActive,
            },
            {
                label = "Date",
                alignment = "LEFT",
                key = Filters.FilterKeys.Date,
                nested = GenerateDateEntries(dates), -- Generate immediately (Static)
                onClick = FilterTables.ResetFilterValue,
                checked = FilterTables.IsFilterActive,
            },
            {
                label = "Maps",
                alignment = "LEFT",
                key = Filters.FilterKeys.Map,
                nested = GenerateMapEntries(),
                onClick = FilterTables.ResetFilterValue,
                checked = FilterTables.IsFilterActive,
            },
            {
                label = "Result",
                alignment = "LEFT",
                key = Filters.FilterKeys.Outcome,
                nested = GenerateOutcomeEntries(),
                onClick = FilterTables.ResetFilterValue,
                checked = FilterTables.IsFilterActive,
            },
            {
                label = "Mirror",
                alignment = "LEFT",
                key = Filters.FilterKeys.Mirror,
                value = true,
                onClick = FilterTables.ToggleFilterValue,
                checked = FilterTables.IsFilterEntryChecked,
            },
        },        
    };
end