local _, ArenaAnalytics = ...; -- Addon Namespace
local FilterTables = ArenaAnalytics.FilterTables;

-- Local module aliases
local API = ArenaAnalytics.API;
local Filters = ArenaAnalytics.Filters;

-------------------------------------------------------------------------


FilterTables.comps = { }
FilterTables.enemyComps = { }

local function DisplayComp(dropdownEntry)
    dropdownEntry.btn:SetText(dropdownEntry.label);
end

local function AddEntry(entryTable, comp, filterKey)
    tinsert(entryTable, {
        label = comp,
        key = filterKey,
        display = DisplayComp,
        onClick = FilterTables.SetFilterValue,
        checked = FilterTables.IsFilterEntryChecked,
    })
end

local function GenerateCompEntries(key)
    assert(key == "Filter_Comp" or key == "Filter_EnemyComp");
    local entryTable = {}

    AddEntry(entryTable, "All", key);
    
    local comps = ArenaAnalytics:GetCurrentCompData(key) or {};
    for comp,values in pairs(comps) do
        AddEntry(entryTable, comp, key);
    end

    return entryTable;
end

function FilterTables:Init_Comps()
    FilterTables.comps = {
        mainButton = {
            label = FilterTables.GetCurrentFilterValue,
            key = "Filter_Comp",
            onClick = FilterTables.ResetFilterValue,
        },
        entries = function() return GenerateCompEntries("Filter_Comp") end,
    }

    FilterTables.enemyComps = {
        mainButton = {
            label = FilterTables.GetCurrentFilterValue,
            key = "Filter_EnemyComp",
            onClick = FilterTables.ResetFilterValue,
        },
        entries = function() return GenerateCompEntries("Filter_EnemyComp") end,
    }
end