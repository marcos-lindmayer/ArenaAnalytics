local _, ArenaAnalytics = ...; -- Addon Namespace
local Helpers = ArenaAnalytics.Helpers;

-- Local module aliases
local Filters = ArenaAnalytics.Filters;
local AAtable = ArenaAnalytics.AAtable;
local Tooltips = ArenaAnalytics.Tooltips;
local Export = ArenaAnalytics.Export;
local API = ArenaAnalytics.API;

-------------------------------------------------------------------------

function Helpers:DeepCopy(original)
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            copy[k] = Helpers:DeepCopy(v);
        else
            copy[k] = v;
        end
    end
    return copy;
end

function Helpers:GetPlayerName(skipRealm)
    local name, realm = UnitFullName("player");
	if(name and realm and not skipRealm) then
		return name .. "-" .. realm;
	end
    return name;
end