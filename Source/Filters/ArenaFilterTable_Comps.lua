local _, ArenaAnalytics = ...; -- Addon Namespace
local FilterTables = ArenaAnalytics.FilterTables;

-- Local module aliases
local API = ArenaAnalytics.API;
local Filters = ArenaAnalytics.Filters;
local TablePool = ArenaAnalytics.TablePool;
local Options = ArenaAnalytics.Options;
local Debug = ArenaAnalytics.Debug;

local Dropdown = ArenaAnalytics.Dropdown;
local Display = Dropdown.Display;

-------------------------------------------------------------------------


FilterTables.comps = {};
FilterTables.enemyComps = {};

local function IsDisabled()
    return not Filters:IsFilterActive(Filters.FilterKeys.Bracket);
end

local function MakeMainButtonTable(key)
    local config = TablePool:Acquire();
    config.key = key;
    config.label = FilterTables.GetCurrentFilterValue;

    config.displayFunc = Display.SetComp;
    config.alignment = "CENTER";
    config.offsetY = -1;

    config.disabled = IsDisabled;
    config.disabledText = "Select bracket to enable filter";
    config.disabledSize = 9;

    config.onClick = FilterTables.ResetFilterValue;

    return config;
end

local function AddEntry(entryTable, comp, filterKey)
    local config = TablePool:Acquire();
    config.key = filterKey;
    config.label = comp;

    config.displayFunc = Display.SetComp;
    config.alignment = "CENTER";
    config.offsetY = 0.75;

    config.onClick = FilterTables.SetFilterValue;

    tinsert(entryTable, config);
end

local function GenerateCompEntries(compKey)
    assert(compKey == Filters.FilterKeys.TeamComp or compKey == Filters.FilterKeys.EnemyComp);
    local entryTable = TablePool:Acquire();
    entryTable.maxVisibleEntries = Options:Get("compDropdownVisibileLimit");

    local requiredPlayedCount = Options:Get("minimumCompsPlayed") or 0;
    local comps = ArenaAnalytics:GetCurrentCompDataSorted(compKey);
    for i,compData in ipairs(comps) do
        if(not compData.played or compData.played >= requiredPlayedCount) then
            AddEntry(entryTable, compData.comp, compKey);
        end
    end

    Debug:LogTemp("GenerateCompEntries  ", compKey, #entryTable)
    return entryTable;
end

function FilterTables:Init_Comps()
    FilterTables.comps = FilterTables.comps or TablePool:Acquire();
    FilterTables.comps.mainButton = MakeMainButtonTable(Filters.FilterKeys.TeamComp);
    FilterTables.comps.entries = function() return GenerateCompEntries(Filters.FilterKeys.TeamComp) end;

    FilterTables.enemyComps = FilterTables.enemyComps or TablePool:Acquire();
    FilterTables.enemyComps.mainButton = MakeMainButtonTable(Filters.FilterKeys.EnemyComp);
    FilterTables.enemyComps.entries = function() return GenerateCompEntries(Filters.FilterKeys.EnemyComp) end;
end