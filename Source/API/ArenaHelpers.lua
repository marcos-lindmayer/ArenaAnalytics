local _, ArenaAnalytics = ...; -- Addon Namespace
local Helpers = ArenaAnalytics.Helpers;

-- Local module aliases
local Filters = ArenaAnalytics.Filters;
local AAtable = ArenaAnalytics.AAtable;
local Tooltips = ArenaAnalytics.Tooltips;
local Export = ArenaAnalytics.Export;
local API = ArenaAnalytics.API;

-------------------------------------------------------------------------
-- General Helpers

function Helpers:ToSafeLower(value)
    if(value and type(value) == "string") then
        return value:lower();
    end
    return value;
end

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

-- Used to draw a solid box texture over a frame for testing
function Helpers:DrawDebugBackground(frame, r, g, b, a)
	if(Options:Get("debuggingEnabled")) then
		-- TEMP testing
		frame.background = frame:CreateTexture();
		frame.background:SetPoint("CENTER")
		frame.background:SetSize(frame:GetWidth(), frame:GetHeight());
		frame.background:SetColorTexture(r or 1, g or 0, b or 0, a or 0.4);
	end
end

-------------------------------------------------------------------------
-- Data Helpers

function Helpers:GetFactionFromRaceID(raceID)

end


