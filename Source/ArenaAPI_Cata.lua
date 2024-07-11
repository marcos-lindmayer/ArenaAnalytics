-- API adjusted functions to let calling code stay version agnostic.
local _, ArenaAnalytics = ...; -- Addon Namespace
local API = ArenaAnalytics.API;

-------------------------------------------------------------------------

-- Get local player current spec
function API:GetMySpec()
    local spec = nil
	local currentSpecPoints = 0

    for i = 1, 3 do
        local _, name, _, _, pointsSpent = GetTalentTabInfo(i);
		if (pointsSpent > currentSpecPoints) then
			currentSpecPoints = pointsSpent;
			spec = name;
		end
 	end

	spec = spec == "Feral Combat" and "Feral" or spec

    return spec;
end