local _, ArenaAnalytics = ... -- Namespace
local ArenaID = ArenaAnalytics.ArenaID;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;

-------------------------------------------------------------------------

function ArenaID:GetClassAndSpec(spec_id)
    if(not spec_id or not ArenaID.addonSpecializationIDs) then
        return nil;
    end

    if(Helpers:IsClassID(spec_id)) then
        local classInfo = ArenaID.addonClassIDs[spec_id];
        return classInfo and classInfo.name;
    end

    -- Class
    local class_id = Helpers:GetClassID(spec_id)
    local classInfo = ArenaID.addonClassIDs[class_id];
    local class = classInfo and classInfo.name;

    -- Spec
    local specInfo = ArenaID.addonSpecializationIDs[spec_id];
    local spec = specInfo and specInfo.spec;
    return class, spec;
end

-------------------------------------------------------------------------

local hasInitialized = nil;
function ArenaID:Initialize()
    if(hasInitialized) then
        return;
    end

    ArenaID:InitializeSpecIDs();

    hasInitialized = true;
end
