local _, ArenaAnalytics = ... -- Namespace
local ArenaQueue = ArenaAnalytics.ArenaQueue;

-- Local module aliases
local API = ArenaAnalytics.API;
local Helpers = ArenaAnalytics.Helpers;
local Events = ArenaAnalytics.Events;
local TablePool = ArenaAnalytics.TablePool;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------
-- ArenaQueue
-- Responsible for tracking queue times for easy access
-------------------------------------------------------------------------

local function getQueueTimes()
	ArenaAnalyticsTransientDB.queueTimes = ArenaAnalyticsTransientDB.queueTimes or {};
    return ArenaAnalyticsTransientDB.queueTimes;
end


function ArenaQueue:UpdateQueueTimes()
    local queues = getQueueTimes();

    for index = 1, GetMaxBattlefieldID() do
        local queueTime = API:GetQueueTime(index);
        local status = API:GetBattlefieldStatus(index);

        if(queueTime == nil or status == "none") then
            queues[index] = nil;
            return;
        end

        queues[index] = queues[index] or {};
        local queue = queues[index];

        if(queue.startTime == nil or status == "queued") then
            queue.startTime = GetTime() - queueTime;
        end

        if(queue.endTime == nil and (status == "confirm" or status == "active")) then
            queue.endTime = GetTime();
        end

        queues[index] = queue;
    end
end


function ArenaQueue:GetQueueTime(battlefieldId)
    if(not battlefieldId) then
        return nil;
    end

    ArenaQueue:UpdateQueueTimes();

    local queues = getQueueTimes();
    local data = queues[battlefieldId];

    if(type(data) ~= "table" or not data.startTime or not data.endTime) then
        return nil;
    end

    local duration = Round(data.endTime - data.startTime);
    Debug:LogGreen("GetQueueTime:", duration);
    return duration;
end


function ArenaQueue:Clear(battlefieldId)
    local queues = getQueueTimes();

    if(battlefieldId) then
        queues[battlefieldId] = nil;
    else
        for index = 1, GetMaxBattlefieldID() do
            queues[index] = nil;
        end
    end
end