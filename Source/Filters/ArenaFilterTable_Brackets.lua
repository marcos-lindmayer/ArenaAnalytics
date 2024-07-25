local _, ArenaAnalytics = ...; -- Addon Namespace
local FilterTables = ArenaAnalytics.FilterTables;

-- Local module aliases
local API = ArenaAnalytics.API;
local Filters = ArenaAnalytics.Filters;

-------------------------------------------------------------------------


FilterTables.brackets = { }

local function AddBracket(bracket)
    tinsert(FilterTables.brackets.entries, {
        label = bracket.name or bracket,
        key = "Filter_Bracket",
        value = bracket.key,
        alignment = "CENTER",
        onClick = FilterTables.SetFilterValue,
        checked = FilterTables.IsFilterEntryChecked,
    })
end

function FilterTables:Init_Brackets()
    FilterTables.brackets = { 
        mainButton = {
            label = FilterTables.GetCurrentFilterValue,
            key = "Filter_Bracket",
            onClick = FilterTables.ResetFilterValue,
        },
        entries = {}
    }

    AddBracket("All");
    
    local brackets = API.GetBrackets() or {};
    for _,bracket in ipairs(brackets) do
        AddBracket(bracket);
    end
end

