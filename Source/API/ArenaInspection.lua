local _, ArenaAnalytics = ...; -- Addon Namespace
local Inspection = ArenaAnalytics.Inspection;

-- Local module aliases
local API = ArenaAnalytics.API;
local ArenaTracker = ArenaAnalytics.ArenaTracker;

-------------------------------------------------------------------------

-- The timer interval to use
local interval = 5;

local queue = {}
local currentInspectGUID = nil;
local timer = nil;

local lastNotifyInspect = 0;

local function IsInQueue(GUID)
    for _,guid in ipairs(queue) do
        if(guid == GUID) then
            return true;
        end
    end
    return false;
end

local function AddToQueue(GUID)
    if(GUID and not IsInQueue(GUID)) then
        tinsert(queue, GUID);
    end
end

local function RemoveFromQueue(GUID)
    if(GUID) then
        for i,guid in ipairs(queue) do
            if(guid == GUID) then
                table.remove(queue, i);
                return;
            end
        end
    end
end

local function GetUnitToken(GUID)
    if(not GUID) then
        return nil;
    end

    for i=1, 4 do
        local unitToken = "party"..i;
        if(UnitGUID(unitToken) == GUID) then
            return unitToken;
        end
    end

    return nil;
end

function Inspection:RequestSpec(unitToken)
    if(not API.GetInspectSpecialization) then
        return;
    end

    if(not unitToken or not API:IsInArena()) then
        return;
    end

    if(not CanInspect(unitToken)) then
        return;
    end

    local GUID = UnitGUID(unitToken);
    if(not IsInQueue(GUID)) then
        AddToQueue(GUID);
    end

    Inspection:TryStartTimer();
end

function Inspection:TryInspectNext()
    if(currentInspectGUID or (time() - lastNotifyInspect) < 4.9) then
        ArenaAnalytics:Log("Skipping inspect attempt: Already/still inspecting!");
        return;
    end

    for _,GUID in pairs(queue) do
        if(not ArenaTracker:HasSpec(GUID)) then
            local unitToken = GetUnitToken(GUID);
            if unitToken and CanInspect(unitToken) then
                ArenaAnalytics:Log("NotifyInspect:", unitToken, time());
                currentInspectGUID = GUID;
                NotifyInspect(unitToken);
                lastNotifyInspect = time();
                return;
            end
        end
    end
end

local function HandleInspect_Internal(GUID)
    if(not API.GetInspectSpecialization) then
        return;
    end

    if(not API:IsInArena()) then
        return;
    end

    local foundSpec = false;

    local unitToken = GetUnitToken(GUID);
    local spec_id = API:GetInspectSpecialization(unitToken);
    if(spec_id) then
        foundSpec = true;
        ArenaTracker:OnSpecDetected(GUID, spec_id);
        ArenaAnalytics:Log("Inspection: Detected Spec:", spec_id, "for:", unitToken, " currentInspectGUID:", currentInspectGUID);
    end

    if(IsInQueue(GUID)) then
        if(foundSpec) then
            RemoveFromQueue(GUID);
        end
    end
end

function Inspection:HandleInspectReady(GUID)
    HandleInspect_Internal(GUID);

    if(currentInspectGUID) then
        if(GUID == currentInspectGUID) then
            ClearInspectPlayer();
        else
            ArenaAnalytics:Log("WARNING: Inspection:HandleInspectReady with different GUID from valid currentInspectGUID! May fail to clean up?");
        end

        currentInspectGUID = nil;
    end
end

-------------------------------------------------------------------------

function Inspection:TryStartTimer()
    if(not API.GetInspectSpecialization) then
        return;
    end

    if(not API:IsInArena()) then
        ArenaAnalytics:Log("Inspection Timer rejected start: Not in arena!");
        Inspection:CancelTimer();
        return;
    end

    if(timer) then
        return;
    end

    ArenaAnalytics:Log("Starting new inspection ticker!");
    timer = C_Timer.NewTicker(interval, function()
        if(#queue == 0 or not API:IsInArena()) then
            ArenaAnalytics:Log("Inspection Timer shutting down!", #queue, API:IsInArena());
            Inspection:CancelTimer();
            return;
        end

        -- Begin inspecting next player in the queue
        Inspection:TryInspectNext();
    end)
end

function Inspection:CancelTimer()
    if(timer) then
        timer:Cancel();
        timer = nil;
        ArenaAnalytics:Log("Inspection Timer cancelled!");
    end
end

function Inspection:Clear()
    Inspection:CancelTimer();
    queue = {};
    
    if(currentInspectGUID) then
        ClearInspectPlayer();
    end
    currentInspectGUID = nil;

    ArenaAnalytics:Log("Inspection Cleared!");
end