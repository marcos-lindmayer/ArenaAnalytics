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

function Helpers:GetPlayerName(skipRealm)
    local name, realm = UnitFullName("player");
	if(name and realm and not skipRealm) then
		return name .. "-" .. realm;
	end
    return name;
end

function Helpers:RatingToText(rating, delta)
    rating = tonumber(rating);
    delta = tonumber(delta);
    if(rating ~= nil) then
        if(delta) then
            if(delta > 0) then
                delta = "+"..delta;
            end
            delta = " ("..delta..")";
        else
            delta = "";
        end
        return rating .. delta;
    end
    return "-";
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

    if(not name:find("-", 1, true)) then
        _,realm = UnitFullName("player"); -- Local player's realm
        name = realm and (name.."-"..realm) or name;
    end

    return name;
end

function Helpers:GetClassIcon(spec_id)
    return Internal:GetClassIcon(spec_id);
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

-------------------------------------------------------------------------
-- Debugging

function Helpers:DebugLogTable(table, level)
    if(not table) then
        ArenaAnalytics:Log("DebugLogTable: Nil table");
        return;
    end

    level = level or 0;
    local indentation = string.rep(" ", 3*level);

    if(type(table) ~= "table") then
        ArenaAnalytics:Log(indentation, table);
        return;
    end

    for key,value in pairs(table) do
        if(type(value) == "table") then
            ArenaAnalytics:Log(indentation, key);
            Helpers:DebugLogTable(value, level+1);
        else
            ArenaAnalytics:Log(indentation, key, value);
        end
    end
end

function Helpers:DebugLogFrameTime(context)
	if(not Options:Get("debuggingEnabled")) then
        return;
    end

    debugprofilestart();

    C_Timer.After(0, function()
        local elapsed = debugprofilestop();
        ArenaAnalytics:Log("DebugLogFrameTime:", elapsed, "Context:", context);
    end);
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

-- TEMP debugging

local statIDs = {}
local statNames = {}

function Helpers:PrintScoreboardStats(numPlayers)
    numPlayers = numPlayers or 1;

    for playerIndex=1, numPlayers do
        ArenaAnalytics:LogSpacer();

        local scoreInfo = C_PvP.GetScoreInfo(playerIndex);
        if(scoreInfo and scoreInfo.stats) then
            for i=1, #scoreInfo.stats do
                local stat = scoreInfo.stats[i];
                ArenaAnalytics:Log("Stat:", stat.pvpStatID, stat.pvpStatValue, stat.name);

                if(stat.pvpStatID) then
                    if(statIDs[stat.pvpStatID] and statIDs[stat.pvpStatID] ~= stat.name) then
                        ArenaAnalytics:Log("New stat name for ID!", stat.pvpStatID, stat.name);
                    end
                    statIDs[stat.pvpStatID] = stat.name;
                end
                
                if(stat.name) then
                    if(statIDs[stat.name] and statIDs[stat.name] ~= stat.pvpStatID) then
                        ArenaAnalytics:Log("New stat ID for name!", stat.pvpStatID, stat.name);
                    end
                    statNames[stat.name] = stat.pvpStatID;
                end
            end

            Helpers:DebugLogTable(scoreInfo and scoreInfo.stats);
        else
            ArenaAnalytics:Log("No current stats found!");
        end
    end
end