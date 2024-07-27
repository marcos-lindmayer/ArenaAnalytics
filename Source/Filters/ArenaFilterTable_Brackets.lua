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
        alignment = "CENTER",
        fontSize = 12,
        key = "Filter_Bracket",
        value = bracket.key,
        onClick = FilterTables.SetFilterValue,
    })
end

function FilterTables:Init_Brackets()
    FilterTables.brackets = { 
        mainButton = {
            label = FilterTables.GetCurrentFilterValue,
            alignment = "CENTER",
            fontSize = 12,
            key = "Filter_Bracket",
            onClick = FilterTables.ResetFilterValue,
        },
        entries = {}
    }

    AddBracket("All");
    
    local brackets = API.availableBrackets or {};
    for _,bracket in ipairs(brackets) do
        AddBracket(bracket);
    end
end

