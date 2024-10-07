local _, ArenaAnalytics = ...; -- Addon Namespace
local Tooltips = ArenaAnalytics.Tooltips;

-- Local module aliases
local Options = ArenaAnalytics.Options;
local Helpers = ArenaAnalytics.Helpers;
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local Internal = ArenaAnalytics.Internal;
local API = ArenaAnalytics.API;
local ShuffleTooltip = ArenaAnalytics.ShuffleTooltip;
local Constants = ArenaAnalytics.Constants;
local PlayerTooltip = ArenaAnalytics.PlayerTooltip;

-------------------------------------------------------------------------

function Tooltips:HideAll()
    Tooltips:UnbindPlayerFrameModifierChanged();
    ShuffleTooltip:Hide();
    GameTooltip:Hide();
end

function Tooltips:DrawMinimapTooltip()
    Tooltips:HideAll();

    GameTooltip:SetOwner(ArenaAnalyticsMinimapButton, "ANCHOR_BOTTOMLEFT");
    GameTooltip:AddDoubleLine(ArenaAnalytics:GetTitleColored(true), "|cff666666v" .. API:GetAddonVersion() .. "|r");
    GameTooltip:AddLine("|cffBBBBBB" .. "Left Click|r" .. " to toggle ArenaAnalytics");
    GameTooltip:AddLine("|cffBBBBBB" .. "Right Click|r".. " to open Options");
    GameTooltip:Show();
end

function Tooltips:DrawOptionTooltip(frame, tooltip)
    assert(tooltip);

    Tooltips:HideAll();

    local name, description = tooltip[1], tooltip[2];

    -- Set the owner of the tooltip to the frame and anchor it at the cursor
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT");
    
    -- Clear previous tooltip content
    GameTooltip:ClearLines();
    
    -- Add the title with a larger font size
    GameTooltip:AddLine(name, 1, 1, 1, true);
    GameTooltipTextLeft1:SetFont(GameTooltipTextLeft1:GetFont(), 13);
    
    -- Add the description with a smaller font size
    GameTooltip:AddLine(description, nil, nil, nil, true);
    GameTooltipTextLeft2:SetFont(GameTooltipTextLeft2:GetFont(), 11);
    
    -- Width
    GameTooltip:SetWidth(500);

    -- Show the tooltip
    GameTooltip:Show();
end

local function TryAddQuickSearchShortcutTips()
    if(not Options:Get("quickSearchEnabled")) then
        return;
    end

    if(not Options:Get("searchShowTooltipQuickSearch")) then
        return;
    end
        
    if(not IsShiftKeyDown()) then
        return;
    end

    local function ColorTips(key, text)
        assert(key);

        if(not text) then
            return " ";
        end

        text = (text ~= "None") and text or "-";

        return "|cff999999" .. key .. "|r|cffCCCCCC" .. text .. "|r";
    end

    GameTooltip:AddLine(" ");
    GameTooltip:AddLine("Quick Search:");

    local defaultAppendRule = Options:Get("quickSearchDefaultAppendRule") or "None";
    local defaultValue = Options:Get("quickSearchDefaultValue") or "None";

    local newSearchRuleShortcut = Options:Get("quickSearchAppendRule_NewSearch") or "None";
    local newSegmentRuleShortcut = Options:Get("quickSearchAppendRule_NewSegment") or "None";
    local sameSegmentRuleShortcut = Options:Get("quickSearchAppendRule_SameSegment") or "None";

    local inverseShortcut = Options:Get("quickSearchAction_Inverse") or "None";

    local teamShortcut = Options:Get("quickSearchAction_Team") or "None";
    local enemyShortcut = Options:Get("quickSearchAction_Enemy") or "None";

    local nameShortcut = Options:Get("quickSearchAction_Name") or "None";
    local specShortcut = Options:Get("quickSearchAction_Spec") or "None";
    local raceShortcut = Options:Get("quickSearchAction_Race") or "None";
    local factionShortcut = Options:Get("quickSearchAction_Faction") or "None";

    local specialValues = {}

    local function TryInsertShortcut(descriptor, shortcut)
        if(shortcut ~= "None") then
            tinsert(specialValues, ColorTips(descriptor, shortcut));
        end
    end

    TryInsertShortcut("Default Rule: ", defaultAppendRule);
    TryInsertShortcut("Default Value: ", defaultValue);

    TryInsertShortcut("New Search: ", newSearchRuleShortcut);
    TryInsertShortcut("New Segment: ", newSegmentRuleShortcut);
    TryInsertShortcut("Same Segment: ", sameSegmentRuleShortcut);
    TryInsertShortcut("Inversed: ", inverseShortcut);

    -- Add the values
    if(#specialValues > 0) then
        GameTooltip:AddDoubleLine(specialValues[1] or " ", specialValues[2] or " ");

        if(#specialValues > 2) then
            GameTooltip:AddDoubleLine(specialValues[3] or " ", specialValues[4] or " ");
        end
        
        if(#specialValues > 4) then
            GameTooltip:AddDoubleLine(specialValues[5] or " ", specialValues[6] or " ");
        end

        GameTooltip:AddLine(" ");
    end

    GameTooltip:AddDoubleLine(ColorTips("Team: ", teamShortcut), ColorTips("Enemy: ", enemyShortcut));
    GameTooltip:AddDoubleLine(ColorTips("Name: ", nameShortcut), ColorTips("Spec: ", specShortcut));
    GameTooltip:AddDoubleLine(ColorTips("Race: ", raceShortcut), ColorTips("Faction: ", factionShortcut));
end

-------------------------------------------------------------------------
-- Player Tooltip

local lastPlayerFrame = nil;
function Tooltips:UnbindPlayerFrameModifierChanged()
    if(lastPlayerFrame) then
        lastPlayerFrame:UnregisterEvent("MODIFIER_STATE_CHANGED");
        lastPlayerFrame:SetScript("OnEvent", nil);
    end
    lastPlayerFrame = nil;
end

local function BindPlayerFrameModifierChanged(playerFrame)
    --  Try unbind last player frame
    Tooltips:UnbindPlayerFrameModifierChanged()

    -- Bind new frame
    playerFrame:RegisterEvent("MODIFIER_STATE_CHANGED");    
    playerFrame:SetScript("OnEvent", function(self) Tooltips:DrawPlayerTooltip(self) end);

    lastPlayerFrame = playerFrame;
end

local function ColorPrefix(text)
    return ArenaAnalytics:ColorText(text, Constants.prefixColor);
end

local function ColorClass(text, spec_id)
    local color = Internal:GetClassColor(spec_id);
    if(color) then
        return "|c" .. color .. text .."|r";
    end
    return text;
end

local function ColorFaction(text, race_id)
    local color = Internal:GetRaceFactionColor(race_id) or "ffffffff";
    return text and ("|c" .. color .. text .. "|r") or " ";
end

local function AddVariableStats_Shuffle(player)
    local wins = ArenaMatch:GetPlayerVariableStats(player) or "";

    GameTooltip:AddLine(ColorPrefix("Wins: ") .. Helpers:FormatNumber(wins));
end

function Tooltips:DrawPlayerTooltip(playerFrame)
    if(not playerFrame) then
        return;
    end

    Tooltips:HideAll();

    PlayerTooltip:SetPlayerFrame(playerFrame);

    if(not playerFrame.player) then
        return;
    end

    if(playerFrame ~= lastPlayerFrame) then
        BindPlayerFrameModifierChanged(playerFrame);
    end

    local function FormatRating(value, delta)
        local text = ArenaAnalytics:ColorText(tonumber(value) or "-", Constants.statsColor);
        
        delta = tonumber(delta);
        if(delta) then
            local hex = nil;
            if(delta > 0) then
                delta = "+"..delta;
                hex = Constants.winColor;
            else
                hex = (delta < 0) and Constants.lossColor or Constants.drawColor;
            end
            text = text .. ArenaAnalytics:ColorText(" ("..delta..")", hex);
        end

        return text;
    end

    -- Name
    local playerName = ArenaMatch:GetPlayerFullName(playerFrame.player, true);

    -- Race
    local race_id = ArenaMatch:GetPlayerRace(playerFrame.player);
    local race = Internal:GetRace(race_id) or " ";

    local specialization = nil;
    local spec_id = ArenaMatch:GetPlayerSpec(playerFrame.player)
    local class, spec = Internal:GetClassAndSpec(spec_id);
    if(class and spec) then
        specialization = spec .. " " .. class;
    else
        specialization = spec or class or " ";
    end

    -- Stats
    local kills, deaths, damage, healing = ArenaMatch:GetPlayerStats(playerFrame.player);

    -- Create the tooltip
    GameTooltip:SetOwner(playerFrame, "ANCHOR_NONE");
    GameTooltip:SetPoint("TOPRIGHT", playerFrame, "TOPLEFT");
    GameTooltip:ClearLines();

    GameTooltip:AddLine(ArenaAnalytics:ColorText(playerName, Constants.titleColor));
    GameTooltip:AddDoubleLine(ColorFaction(race, race_id), ColorClass(specialization, spec_id));

    GameTooltip:AddDoubleLine(ColorPrefix("Damage: ") .. Helpers:FormatNumber(damage), ColorPrefix("Healing: ") .. Helpers:FormatNumber(healing));
    
    local duration = ArenaMatch:GetDuration(playerFrame.match);
    if(duration and duration > 0) then
        local dps = damage and damage / duration or "-";
        local hps = healing and healing / duration or "-";
        GameTooltip:AddDoubleLine(ColorPrefix("DPS: ") .. Helpers:FormatNumber(dps), ColorPrefix("HPS: ") .. Helpers:FormatNumber(hps));
    end

    GameTooltip:AddDoubleLine(ColorPrefix("Kills: ") .. Helpers:FormatNumber(kills), ColorPrefix("Deaths: ") .. Helpers:FormatNumber(deaths));

    -- Player Rating Info
    if(ArenaMatch:IsRated(playerFrame.match)) then
        local rating, ratingDelta, mmr, mmrDelta = ArenaMatch:GetPlayerRatedInfo(playerFrame.player);
        if(rating or API.showPerPlayerRatedInfo) then
            GameTooltip:AddDoubleLine(ColorPrefix("Rating: ") .. FormatRating(rating, ratingDelta), ColorPrefix("MMR: ") .. FormatRating(mmr, mmrDelta));
        end
    end

    if(ArenaMatch:IsShuffle(playerFrame.match)) then
        AddVariableStats_Shuffle(playerFrame.player);
    end

    -- Quick Search Shortcuts
    TryAddQuickSearchShortcutTips();

    GameTooltip:Show();
end

-------------------------------------------------------------------------
-- Solo Shuffle Tooltips

function Tooltips:DrawShuffleTooltip(entryFrame, match)
    Tooltips:HideAll();

    if(not entryFrame or not match) then
        return;
    end

    ShuffleTooltip:SetMatch(match);
    ShuffleTooltip:SetEntryFrame(entryFrame);
    ShuffleTooltip:Show();
end

function Tooltips:HideShuffleTooltip()
    ShuffleTooltip:Hide();
end