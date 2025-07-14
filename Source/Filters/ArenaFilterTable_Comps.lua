local _, ArenaAnalytics = ...; -- Addon Namespace
local FilterTables = ArenaAnalytics.FilterTables;

-- Local module aliases
local API = ArenaAnalytics.API;
local Filters = ArenaAnalytics.Filters;
local TablePool = ArenaAnalytics.TablePool;
local Options = ArenaAnalytics.Options;

local Dropdown = ArenaAnalytics.Dropdown;
local Display = Dropdown.Display;

-------------------------------------------------------------------------


FilterTables.comps = {}
FilterTables.enemyComps = {}

local function IsDisabled()
    return not Filters:IsFilterActive(Filters.FilterKeys.Bracket);
end

local function MakeMainButtonTable(key)
    return {
        label = FilterTables.GetCurrentFilterValue,
        displayFunc = Display.SetComp,
        disabled = IsDisabled,
        disabledText = "Select bracket to enable filter",
        disabledSize = 9,
        alignment = "CENTER",
        key = key,
        onClick = FilterTables.ResetFilterValue,
    };
end

local function AddEntry(entryTable, comp, filterKey)
    tinsert(entryTable, {
        label = comp,
        displayFunc = Display.SetComp,
        alignment = "CENTER",
        key = filterKey,
        onClick = FilterTables.SetFilterValue,
    });
end

local function GenerateCompEntries(compKey)
    assert(compKey == Filters.FilterKeys.TeamComp or compKey == Filters.FilterKeys.EnemyComp);
    local entryTable = TablePool:Acquire();
    entryTable.maxVisibleEntries = Options:Get("compDropdownVisibileLimit");

    local requiredPlayedCount = Options:Get("minimumCompsPlayed") or 0;
    local comps = ArenaAnalytics:GetCurrentCompDataSorted(compKey);
    for _,compData in ipairs(comps) do
        if(not compData.played or compData.played >= requiredPlayedCount) then
            AddEntry(entryTable, compData.comp, compKey);
        end
    end

    return entryTable;
end

function FilterTables:Init_Comps()
    FilterTables.comps = {
        mainButton = MakeMainButtonTable(Filters.FilterKeys.TeamComp),
        entries = function() return GenerateCompEntries(Filters.FilterKeys.TeamComp) end,
    };

    FilterTables.enemyComps = {
        mainButton = MakeMainButtonTable(Filters.FilterKeys.EnemyComp),
        entries = function() return GenerateCompEntries(Filters.FilterKeys.EnemyComp) end,
    };
end