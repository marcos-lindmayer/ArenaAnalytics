local _, ArenaAnalytics = ... -- Namespace
ArenaAnalytics.DataSync = {}

local DataSync = ArenaAnalytics.DataSync;

-- DataTypes: Duration, TeamSpecs, EnemySpecs, MMR, EnemyMMR, EnemyRating, EnemyDeltaRating

-- Sync Format: Type|SenderGUID|Version|Payload
-- Example request: "Request|PlayerGUID|0.0.1|Specs"
-- Example sync: "Delivery|OtherPlayerGUID|0.0.1|Spec:PlayerGUID=Retribution

-- Request missing data for the last match through party or instance channel
function DataSync:requestSync()
    -- Determine if any channel is available for requesting sync
    if(not IsInInstance() or not IsInGroup(1)) then
        return false;
    end

    -- Determine missing data
    -- Convert to formatted msg
    -- Send msg in appropriate channel
end

-- Handle received sync message
function DataSync:handleSyncMessage(...)
    -- version, sender(player name), type(request/delivery), payload
    local _, msg = ...

    -- Parse the message
    local messageType, sender, version, payload;

    -- Check that sender wasn't the local player

    -- Check version (0.1.0) (0.1.15)
    
    -- Check that sender was in the last stored arena
end

function DataSync:CompareVersions(receivedVersion)
    local localVersion = GetAddOnMetadata("ArenaAnalytics", "Version") or nil;
    if(localVersion == nil) then
        return false;    
    end

    if(localVersion == receivedVersion) then
        return true;
    end
    
end

-- Update the provided data if we still miss it
function DataSync:handleSyncDelivery(payload)

end

-- Handles an incoming request for data
function DataSync:handleSyncRequest(payload)
    -- Send data sync message for each requested info (Or a compressed format where possible)
end

-- 
function DataSync:sendDataSync(requestedDataType)

end