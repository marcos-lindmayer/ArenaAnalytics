-- API adjusted functions to let calling code stay version agnostic.
local _, ArenaAnalytics = ...; -- Addon Namespace
local Interface_Internal = ArenaAnalytics.Interface_Internal;

-- Local module aliases
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local Helpers = ArenaAnalytics.Helpers;

-------------------------------------------------------------------------
-- Internal implementation of AA implementation
-------------------------------------------------------------------------

local function ConvertPlayerToReadable(player)
    local readablePlayer = {
        fullname = ArenaMatch:GetPlayerFullName(player),
        race = ArenaMatch:GetPlayerRace(player),
        spec = ArenaMatch:GetPlayerSpec(player),
        role = ArenaMatch:GetPlayerRole(player),
        isSelf = ArenaMatch:GetPlayerIsSelf(player),
        isFirstDeath = ArenaMatch:GetPlayerIsFirstDeath(player),
        isFemale = ArenaMatch:GetPlayerIsFemale(player),
        -- Rated Info structure
        -- Stats structure
        -- Variable Stats structure
    };

    return readablePlayer;
end

local function FillReadableTeams(match)

end

-- TODO: Reuse Export formatting?
function Interface_Internal:ConvertToReadableMatch(match)
    local readableMatch = {};



    FillReadableTeams(match);

    -- TODO: Fill and return readable match
    return Helpers:DeepCopy(match);
end