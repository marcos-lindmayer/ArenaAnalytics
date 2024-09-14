local _, ArenaAnalytics = ...; -- Addon Namespace
local Inspection = ArenaAnalytics.Inspection;
Inspection.isInitialized = true;

-- Local module aliases
local API = ArenaAnalytics.API;
local ArenaTracker = ArenaAnalytics.ArenaTracker;

-------------------------------------------------------------------------

local queue = {}
local isInspecting = false;
local isTimerRunning = false;

local function IsInQueue(GUID)
    return GUID and queue[GUID] ~= nil;
end

local function AddToQueue(GUID)
    if(GUID) then
        queue[GUID] = time();
    end
end

local function RemoveFromQueue(GUID)
    if(GUID) then
        queue[GUID] = nil;
    end
end 

function Inspection:RequestSpec(unitToken)
    if(not unitToken or not API:IsInArena()) then
        return;
    end

    local GUID = UnitGUID(unitToken);
    if(IsInQueue(GUID)) then
        return;
    end

    if(not CanInspect(unitToken)) then
        return;
    end
end

function Inspection:TryInspectNext()
    if(isInspecting) then 
        return;
    end
    isInspecting = true;

    
end

function Inspection:HandleInspectReady(GUID)
    if(not API:IsInArena()) then
        return;
    end
    isInspecting = false;

    for i=1, 4 do
        local unit = "party"..i;
        if(UnitGUID(unit) == GUID) then
            local specID = GetInspectSpecialization(unit);
            local spec_id = API:GetMappedAddonSpecID(specID);
            if(spec_id) then
                ArenaTracker:OnSpecDetected(GUID, spec_id);
            end
        end
    end
end