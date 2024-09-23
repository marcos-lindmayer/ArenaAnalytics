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

function Helpers:DebugLogTable(table, level)
    if(not table) then
        ArenaAnalytics:Log("DebugLogTable: Nil table");
        return;
    end

    level = level or 0;
    local indentation = string.rep(" ", 3*level);

    for key,value in pairs(table) do
        if(type(value) == "table") then
            ArenaAnalytics:Log(indentation .. key);
            Helpers:DebugLogTable(value, level+1);
        else
            ArenaAnalytics:Log(indentation .. key, value);
        end
    end
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

function Helpers:GetUnitFullName(unitToken)
    local name, realm = UnitNameUnmodified(unitToken);

    if (name == nil or name == "Unknown") then
        return nil;
    end

    if(realm == nil or realm == "") then
        _,realm = UnitFullName("player"); -- Local player's realm
    end

    if(not realm) then
        ArenaAnalytics:Log("Helpers:GetUnitFullName failed to retrieve any realm!");
        return name;
    end

    return name.."-"..realm;
end

function Helpers:ToFullName(name)
    if(not name) then
        return nil;
    end

    if(not name:find("-")) then
        _,realm = UnitFullName("player"); -- Local player's realm
        name = realm and (name.."-"..realm) or name;
    end

    return name;
end

function Helpers:GetClassIcon(spec_id)
    return Internal:GetClassIcon(spec_id);
end

-- Gets the name, and realm if not local realm from player info
function Helpers:GetNameFromPlayerInfo(playerInfo)
    if(not playerInfo) then
        return "";
    end

    local isLocalRealm = ArenaAnalytics:IsLocalRealm(playerInfo.realm);
    return isLocalRealm and playerInfo.name or playerInfo.fullName or "";
end

function Helpers:GetClassID(spec_id)
    return spec_id and floor(spec_id / 10) * 10;
end

function Helpers:IsClassID(spec_id)
    return spec_id and (spec_id % 10 == 0);
end

function Helpers:IsSpecID(spec_id)
    return spec_id and (spec_id % 10 > 0);
end