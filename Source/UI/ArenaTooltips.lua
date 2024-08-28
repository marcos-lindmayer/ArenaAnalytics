local _, ArenaAnalytics = ...; -- Addon Namespace
local Tooltips = ArenaAnalytics.Tooltips;

-- Local module aliases
local Options = ArenaAnalytics.Options;
local Helpers = ArenaAnalytics.Helpers;
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local Internal = ArenaAnalytics.Internal;

-------------------------------------------------------------------------

function Tooltips:DrawMinimapTooltip()
    GameTooltip:SetOwner(ArenaAnalyticsMinimapButton, "ANCHOR_BOTTOMLEFT");
    GameTooltip:AddDoubleLine(ArenaAnalytics:GetTitleColored(true), "|cff666666v" .. ArenaAnalytics:GetVersion() .. "|r");
    GameTooltip:AddLine("|cffBBBBBB" .. "Left Click|r" .. " to toggle ArenaAnalytics");
    GameTooltip:AddLine("|cffBBBBBB" .. "Right Click|r".. " to open Options");
    GameTooltip:Show();
end

function Tooltips:DrawOptionTooltip(frame, tooltip)
    assert(tooltip);

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

local lastPlayerFrame = nil;
local function UnbindPlayerFrameModifierChanged()
    if(lastPlayerFrame) then
        lastPlayerFrame:UnregisterEvent("MODIFIER_STATE_CHANGED");
        lastPlayerFrame:SetScript("OnEvent", nil);
    end
    lastPlayerFrame = nil;
end

local function BindPlayerFrameModifierChanged(playerFrame)
    --  Try unbind last player frame
    UnbindPlayerFrameModifierChanged()

    -- Bind new frame
    playerFrame:RegisterEvent("MODIFIER_STATE_CHANGED");    
    playerFrame:SetScript("OnEvent", function(self)
        Tooltips:DrawPlayerTooltip(self);
    end);

    lastPlayerFrame = playerFrame;
end

function Tooltips:DrawPlayerTooltip(playerFrame)
    if(not playerFrame) then
        return;
    end
    
    if(playerFrame ~= lastPlayerFrame) then
        BindPlayerFrameModifierChanged(playerFrame);
    end

    local matchIndex = playerFrame.matchIndex;
    local isEnemyTeam = playerFrame.isEnemyTeam;
    local playerIndex = playerFrame.playerIndex;
    
    if(not matchIndex or not playerIndex or isEnemyTeam == nil) then
        return;
    end
    
    local match = ArenaAnalytics:GetFilteredMatch(matchIndex);
    local player = match and ArenaMatch:GetPlayer(match, isEnemyTeam, playerIndex);
    local playerInfo = ArenaMatch:GetPlayerInfo(player);

    if(not playerInfo) then
        return;
    end

    local function ColorText(text)
        return "|cff999999" .. text or "" .. "|r";
    end

    local function ColorClass(text, spec_id)
        local classIndex = Internal:GetClassIndex(playerInfo.spec_id);
        return ArenaAnalytics:ApplyClassColor(text, classIndex);
    end

    local function ColorFaction(text, race_id)
        local color = Internal:GetRaceFactionColor(race_id) or "ffffffff";
        return text and ("|c" .. color .. text .. "|r") or " ";
    end

    local function FormatValue(value)
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
        
        return "|cffffffff" .. value .. "|r";
    end

    local playerName = Helpers:GetNameFromPlayerInfo(playerInfo);
    local race = playerInfo.race or " ";
    
    local specialization = nil;
    if(playerInfo.class and playerInfo.spec) then
        specialization = playerInfo.spec .. " " .. playerInfo.class;
    else
        specialization = playerInfo.spec or playerInfo.class or " ";
    end

    -- Create the tooltip
    GameTooltip:SetOwner(playerFrame, "ANCHOR_NONE");
    GameTooltip:SetPoint("TOPRIGHT", playerFrame, "TOPLEFT");
    GameTooltip:ClearLines();

    GameTooltip:AddLine(playerName);
    GameTooltip:AddDoubleLine(ColorFaction(playerInfo.race, playerInfo.race_id), ColorClass(specialization, playerInfo.spec_id));

    GameTooltip:AddDoubleLine(ColorText("Damage: ") .. FormatValue(playerInfo.damage), ColorText("Healing: ") .. FormatValue(playerInfo.healing));
    GameTooltip:AddDoubleLine(ColorText("Kills: ") .. FormatValue(playerInfo.kills), ColorText("Deaths: ") .. FormatValue(playerInfo.deaths));

    -- Quick Search Shortcuts
    TryAddQuickSearchShortcutTips();

    GameTooltip:Show();
end

function Tooltips:HidePlayerTooltip()    
    UnbindPlayerFrameModifierChanged();
    GameTooltip:Hide();
end