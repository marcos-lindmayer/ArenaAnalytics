local _, ArenaAnalytics = ... -- Namespace
local TablePool = ArenaAnalytics.TablePool;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;

-------------------------------------------------------------------------

local MAX_POOL_SIZE = 200;  -- Set a reasonable limit

function TablePool:Release(tbl)
    if type(tbl) == "table" then
        -- Clear all data
        for k in pairs(tbl) do
            tbl[k] = nil;
        end

        -- Only add the table if the pool hasn't reached max size
        if #self < MAX_POOL_SIZE then
            table.insert(self, tbl);
        end
    end
end

-- Acquire a table from the pool or create a new one
function TablePool:Acquire()
    return table.remove(self) or {};
end