local _, ArenaAnalytics = ...; -- Addon Namespace
local FilterCache = ArenaAnalytics.FilterCache;

-- Local module aliases
local Options = ArenaAnalytics.Options;
local Search = ArenaAnalytics.Search;
local Selection = ArenaAnalytics.Selection;
local AAtable = ArenaAnalytics.AAtable;
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local TablePool = ArenaAnalytics.TablePool;
local Sessions = ArenaAnalytics.Sessions;
local Debug = ArenaAnalytics.Debug;
local API = ArenaAnalytics.API;
local Helpers = ArenaAnalytics.Helpers;

-------------------------------------------------------------------------

--[[
    Cache data structure:
     - MMR Sum
     - Wins
     - Total Played
     - Commit Computations:
       - MMR Average (Sum / Total)
       - Winrate ((wins / total) * 100)

    Bottom Stats:
     - Session Duration
     - Selected Stats (Managed exclusively through Selection module!)
       - CacheData structure
     - Session Stats
       - IsCurrent
       - CacheData structure
     - Total Stats
       - IsFiltered
       - CacheData structure
--]]


--[[
Search
 - No cache?

Bracket
 - HasShuffles?
 - CacheData per bracket

Comps
 - CacheData structure per comp, including "All"

More Filters
 - Season
   - CacheData per season
 - Date
   - CacheData per timeframe
 - Maps
   - CacheData per map
 - Result
   - Total matches per outcome
 - Mirror
   - CacheData for mirror matches?
--]]



FilterCache.data = {};

function FilterCache:Reset()
    wipe(FilterCache.data);
end


function FilterCache:AddMatchData(match, filter)
    
end


-- Add 
function FilterCache:AddAllMatchData(match)

end