local _, ArenaAnalytics = ... -- Namespace
local Lookup = ArenaAnalytics.Lookup;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;
local API = ArenaAnalytics.API;
local GroupSorter = ArenaAnalytics.GroupSorter;
local TablePool = ArenaAnalytics.TablePool;

-------------------------------------------------------------------------

local compLookupTables = {};


-- Unused
local lastSortedSpec = nil; -- The role comp data was last sorted for.
local function TryResortComps()
    local mySpec = ArenaAnalytics:GetLocalPlayerSpec();
    if(not mySpec or mySpec == lastSortedSpec) then
        -- Already sorted for current specialization
        return;
    end

    lastSortedSpec = mySpec;

    local playerInfo = ArenaAnalytics:GetLocalPlayerInfo();
    for comp,specs in pairs(compLookupTables) do
        -- TODO: Sort comp specs
        GroupSorter:SortSpecs(specs, playerInfo);
    end
end


local function TryResortCompSpecs(comp)
    local data = compLookupTables[comp];
    if(not data) then
        return;
    end

    local playerInfo = ArenaAnalytics:GetLocalPlayerInfo();
    if(playerInfo.spec_id and playerInfo.spec_id == data.lastSortedSpec) then
        return;
    end

    GroupSorter:SortSpecs(data, playerInfo);
    data.lastSortedSpec = playerInfo.spec_id;
end


function Lookup:FindOrAddCompLookup(comp, skipResort)
    if(not compLookupTables[comp]) then
        local specs = TablePool:Acquire();

        -- Add each player spec icon
        for spec_id in comp:gmatch("([^|]+)") do
            if(tonumber(spec_id)) then
                tinsert(specs, tonumber(spec_id));
            end
        end

        -- Force sorting new comps
        skipResort = false;

        -- Assign sorted 
        compLookupTables[comp] = specs;
    end

    if(not skipResort) then
        TryResortCompSpecs(comp);
    end

    return compLookupTables[comp];
end
