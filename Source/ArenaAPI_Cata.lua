-- API adjusted functions to let calling code stay version agnostic.
local _, ArenaAnalytics = ...; -- Addon Namespace
local API = ArenaAnalytics.API;

-------------------------------------------------------------------------

API.defaultButtonTemplate = "UIServiceButtonTemplate";

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

-- Get Cata Brackets
function API:GetBrackets()
	return { 
		{ name = "2v2", key = "2v2"},
		{ name = "3v3", key = "3v3"},
		{ name = "5v5", key = "5v5"},
	};
end