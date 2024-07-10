local _, ArenaAnalytics = ...; -- Namespace
ArenaAnalytics.Tooltips = {};
local Tooltips = ArenaAnalytics.Tooltips;

local Options = ArenaAnalytics.Options;

function Tooltips:DrawMinimapTooltip()
    GameTooltip:SetOwner(ArenaAnalyticsMinimapButton, "ANCHOR_BOTTOMLEFT");
    GameTooltip:AddDoubleLine(ArenaAnalytics:GetTitleColored(true), "|cff666666v" .. ArenaAnalytics:getVersion() .. "|r");
    GameTooltip:AddLine("|cffBBBBBB" .. "Left Click|r" .. " to toggle ArenaAnalytics");
    GameTooltip:AddLine("|cffBBBBBB" .. "Right Click|r".. " to open Options");
    GameTooltip:Show();
end

function Tooltips:DrawOptionTooltip(frame, tooltip)
    assert(tooltip);

    local name, description = tooltip[1], tooltip[2];

    -- Set the owner of the tooltip to the frame and anchor it at the cursor
    GameTooltip:SetOwner(ArenaAnalyticsScrollFrame, "ANCHOR_CURSOR");
    
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

function Tooltips:DrawPlayerTooltip(playerFrame)
    local matchIndex = playerFrame.matchIndex;
    local teamKey = playerFrame.team;
    local playerIndex = playerFrame.playerIndex;

    if(not matchIndex or not teamKey or not playerIndex) then
        return;
    end

    local match = ArenaAnalytics.filteredMatchHistory[matchIndex];
    local playerTable = match and match[teamKey] and match[teamKey][playerIndex] or nil;

    if(not playerTable) then
        return;
    end

    local playerName = playerTable["name"] or ""

    local _, realm = UnitFullName("player");
    if(realm and playerName:find(realm)) then
        playerName = playerName:match("(.*)-") or "";
    end

    local player = playerName or "???";
    local faction = playerTable["faction"] or "???";
    local race = playerTable["race"] or "???";
    local class = playerTable["class"] or "";
    local spec = playerTable["spec"] or "";
    local damage = playerTable["damage"] or "-";
    local healing = playerTable["healing"] or "-";
    local kills = playerTable["kills"] or "-";
    local deaths = playerTable["deaths"] or "-";

    local function ColorText(text)
        return "|cff999999" .. text or "" .. "|r";
    end

    local function ColorValue(text)
        return text or "" .. "|r";
    end

    local function FormatValue(value)
        value = tonumber(value) or "-";

        if (type(value) == "number") then
            -- TODO: Add option to shorten large numbers by suffix

            value = math.floor(value);

            while true do  
                value, k = string.gsub(value, "^(-?%d+)(%d%d%d)", '%1,%2')
                if (k==0) then
                    break
                end
            end
        end
        
        return "|cffffffff" .. value .. "|r";
    end

    -- Create the tooltip
    GameTooltip:SetOwner(playerFrame, "ANCHOR_RIGHT");
    GameTooltip:AddLine(player);    
    GameTooltip:AddDoubleLine(race, ArenaAnalytics:ApplyClassColor(spec .. " " .. class, class));

    GameTooltip:AddDoubleLine(ColorText("Damage: ") .. FormatValue(damage), ColorText("Healing: ") .. FormatValue(healing));
    GameTooltip:AddDoubleLine(ColorText("Kills: ") .. FormatValue(kills), ColorText("Deaths: ") .. FormatValue(deaths));

    local function ColorTips(key, text)
        return "|cff999999" .. key .. "|r|cffCCCCCC" .. text .. "|r";
    end

    if(not Options:Get("searchHideTooltipQuickSearch")) then
        GameTooltip:AddLine(" ");
        GameTooltip:AddLine("Quick Search:");
        GameTooltip:AddDoubleLine(ColorTips("LMB:", " Add value"), ColorTips("RMB:", " Add inversed"));
        GameTooltip:AddDoubleLine(ColorTips("Nomod:", " Player Name"), ColorTips("Shift:", " Class/Spec"));
        GameTooltip:AddDoubleLine(ColorTips("Ctrl:", " Race"), ColorTips("Alt:", " Append search"));
    end

    GameTooltip:Show();
end