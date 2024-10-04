local _, ArenaAnalytics = ... -- Namespace
local TablePool = ArenaAnalytics.TablePool;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;

-------------------------------------------------------------------------

local MAX_POOL_SIZE = 100;  -- Set a reasonable limit for your case

function TablePool:Release(tbl)
    if tbl then
        -- Clear all data
        for k in pairs(tbl) do
            tbl[k] = nil
        end

        -- Only add the table if the pool hasn't reached max size
        if #self < MAX_POOL_SIZE then
            table.insert(self, tbl);
        else
            ArenaAnalytics:Log("TablePool: Max Pool Size reached! Discarding released table.");
        end
    end
end

-- Acquire a table from the pool or create a new one
function TablePool:Acquire(...)
    if #self > 0 then
        return table.remove(self)
    else
        return {}
    end
end

local function GetNameLower(index)
    if(not tonumber(index)) then
        ArenaAnalytics:Log("GetNameLower", type(index), index);
        return nil;
    end

    if(not ArenaAnalyticsDB.names[tonumber(index)]) then
        ArenaAnalytics:Log("GetNameLower", type(index), index, #ArenaAnalyticsDB.names);
        return nil;
    end

    return ArenaAnalyticsDB.names[tonumber(index)]:lower();
end

local function GetRealmLower(index)
    if(not tonumber(index)) then
        return nil;
    end

    if(not ArenaAnalyticsDB.realms[tonumber(index)]) then
        return nil;
    end

    return ArenaAnalyticsDB.realms[tonumber(index)]:lower();
end