local _, ArenaAnalytics = ...; -- Addon Namespace
local FilterTables = ArenaAnalytics.FilterTables;

-- Local module aliases
local API = ArenaAnalytics.API;
local Filters = ArenaAnalytics.Filters;

local Dropdown = ArenaAnalytics.Dropdown;
local Display = Dropdown.Display;

-------------------------------------------------------------------------


FilterTables.comps = { }
FilterTables.enemyComps = { }

local function AddEntry(entryTable, comp, filterKey)
    tinsert(entryTable, {
        label = comp,
        displayFunc = Display.SetComp,
        alignment = "CENTER",
        key = filterKey,
        onClick = FilterTables.SetFilterValue,
    })
end

local function GenerateCompEntries(key)
    assert(key == "Filter_Comp" or key == "Filter_EnemyComp");
    local entryTable = {}
    
    local comps = ArenaAnalytics:GetCurrentCompDataSorted(key);
    for _,compData in ipairs(comps) do
        AddEntry(entryTable, compData.comp, key);
    end

    return entryTable;
end

function FilterTables:Init_Comps()
    FilterTables.comps = {
        mainButton = {
            label = FilterTables.GetCurrentFilterValue,
            displayFunc = Display.SetComp,
            alignment = "CENTER",
            key = "Filter_Comp",
            onClick = FilterTables.ResetFilterValue,
        },
        entries = function() return GenerateCompEntries("Filter_Comp") end,
    }

    FilterTables.enemyComps = {
        mainButton = {
            label = FilterTables.GetCurrentFilterValue,
            displayFunc = Display.SetComp,
            alignment = "CENTER",
            key = "Filter_EnemyComp",
            onClick = FilterTables.ResetFilterValue,
        },
        entries = function() return GenerateCompEntries("Filter_EnemyComp") end,
    }
end