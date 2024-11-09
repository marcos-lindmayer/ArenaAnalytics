local _, ArenaAnalytics = ...; -- Addon Namespace
local Helpers = ArenaAnalytics.Helpers;

-- Local module aliases
local Filters = ArenaAnalytics.Filters;
local AAtable = ArenaAnalytics.AAtable;
local Tooltips = ArenaAnalytics.Tooltips;
local Export = ArenaAnalytics.Export;
local API = ArenaAnalytics.API;
local Internal = ArenaAnalytics.Internal;
local Localization = ArenaAnalytics.Localization;
local Options = ArenaAnalytics.Options;
local Constants = ArenaAnalytics.Constants;

-------------------------------------------------------------------------
-- General Helpers

function Helpers:ToSafeLower(value)
    if(type(value) == "string") then
        return value:lower();
    end

    return value;
end

function Helpers:ToSafeNumber(value)
    if(not value or value == "inf" or value == "nan") then
        return nil; -- Assume non-nil values will be kept if needed elsewhere
    end

    return tonumber(value);
end

function Helpers:DeepCopy(original)
    local copy = {}

    if(not original) then
        return nil;
    end

    if(type(original) ~= "table") then
        return original;
    end

    for k, v in pairs(original) do
        if type(v) == "table" then
            copy[k] = Helpers:DeepCopy(v);
        else
            copy[k] = v;
        end
    end

    return copy;
end

function Helpers:RatingToText(rating, delta)
    rating = tonumber(rating);
    delta = tonumber(delta);

    if(Options:Get("hideZeroRatingDelta") and delta == 0) then
        if(rating ~= nil) then
            delta = nil;
        end
    end

    if(not rating and not delta) then
        return nil;
    end
    
    -- Add + for positive numbers
    if(delta) then
        if(delta > 0) then
            delta = "+"..delta;
        end
    end

    if(not rating) then
        return string.format("(%s)", delta);
    elseif(not delta) then
        return rating;
    end

    return string.format("%d (%s)", rating, delta);
end

function Helpers:FormatNumber(value)
    value = tonumber(value) or "-";

    if (type(value) == "number") then
        -- TODO: Add option to shorten large numbers by suffix

        value = math.floor(value);

        while true do  
            value, k = string.gsub(value, "^(-?%d+)(%d%d%d)", '%1,%2')
            if (k==0) then
                break;
            end
        end
    end

    return ArenaAnalytics:ColorText(value, Constants.statsColor);
end

function Helpers:FormatDate(value)
    return value and date("%d.%m.%y  %H:%M", value);
end

-- Create two layers of backdrop, for an extra low transparency
function Helpers:CreateDoubleBackdrop(parent, name, strata, level)
    local frame = CreateFrame("Frame", name, parent, "TooltipBackdropTemplate");
    frame:SetSize(1, 1);
    frame:SetBackdropColor(0,0,0,1);

    if(strata) then
        frame:SetFrameStrata(strata);
    end

    if(level) then
        frame:SetFrameLevel(level);
    end

    local function AddBackgroundLayer(index)
        frame["bg"..index] = CreateFrame("Frame", (name and name .. "Bg" .. index), frame, "TooltipBackdropTemplate");
        frame["bg"..index]:SetAllPoints(frame:GetPoint());
        frame["bg"..index]:SetFrameLevel(frame:GetFrameLevel() - 1);
        frame["bg"..index]:SetBackdropColor(0,0,0,1);
    end

    AddBackgroundLayer(1);

    if(API.useThirdTooltipBackdrop) then
        AddBackgroundLayer(2);
    end

    return frame;
end

-------------------------------------------------------------------------
-- Data Helpers

-- Get Addon Race ID from unit
function Helpers:GetUnitRace(unit)
    local _,token = UnitRace(unit);
    local faction = UnitFactionGroup(unit);

    local factionIndex = nil;
    if(faction) then
        factionIndex = (faction == "Alliance") and 1 or 0;
    end

    return Internal:GetAddonRaceIDByToken(token, factionIndex);
end

-- Get Addon Class ID from unit
function Helpers:GetUnitClass(unit)
    local _,token = UnitClass(unit);
    return Internal:GetAddonClassID(token);
end

function Helpers:GetPlayerName(skipRealm)
    local name = UnitNameUnmodified("player");
    local realm = select(2, UnitFullName("player"));

	if(not skipRealm and name and realm) then
		return format("%s-%s", name, realm);
	end

    return name;
end

function Helpers:GetUnitFullName(unitToken)
    local name = UnitNameUnmodified(unitToken);
    local realm = select(2, UnitFullName(unitToken));

    if (name == nil or name == "Unknown") then
        return nil;
    end

    if(realm == nil or realm == "") then
        realm = select(2, UnitFullName("player")); -- Local player's realm
    end

    if(not realm) then
        ArenaAnalytics:LogWarning("Helpers:GetUnitFullName failed to retrieve any realm!");
        return name;
    end

    return format("%s-%s", name, realm);
end

function Helpers:GetFullNameByGUID(GUID)
    if(not GUID) then
        return nil;
    end

    local _, _, _, _, _, name, realm = GetPlayerInfoByGUID(GUID);

    if(not realmName) then
        realm = select(2, UnitFullName("player")); -- Local player's realm
    end

    if(not realm) then
        ArenaAnalytics:LogWarning("Helpers:GetFullNameByGUID failed to retrieve any realm!");
        return name;
    end

    return format("%s-%s", name, realm);
end

function Helpers:ToFullName(name)
    if(not name) then
        return nil;
    end

    if(not name:find("-", 1, true)) then
        realm = select(2, UnitFullName("player")); -- Local player's realm
        name = realm and (name.."-"..realm) or name;
    end

    return name;
end

function Helpers:GetClassID(spec_id)
    spec_id = tonumber(spec_id);
    return spec_id and floor(spec_id / 10) * 10;
end

function Helpers:IsClassID(spec_id)
    spec_id = tonumber(spec_id);
    return spec_id and (spec_id % 10 == 0);
end

function Helpers:IsSpecID(spec_id)
    spec_id = tonumber(spec_id);
    return spec_id and (spec_id % 10 > 0);
end