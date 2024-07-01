local _, ArenaAnalytics = ...; -- Namespace
ArenaAnalytics.Tooltips = {};
local Tooltips = ArenaAnalytics.Tooltips;

function Tooltips:DrawMinimapTooltip()
    GameTooltip:SetOwner(ArenaAnalyticsMinimapButton, "ANCHOR_BOTTOMLEFT");
    GameTooltip:AddDoubleLine(ArenaAnalytics:GetTitleColored(true), "|cff666666v" .. ArenaAnalytics:getVersion() .. "|r");
    GameTooltip:AddLine("|cffBBBBBB" .. "Left Click|r" .. " to toggle ArenaAnalytics");
    GameTooltip:AddLine("|cffBBBBBB" .. "Right Click|r".. " to open Options");
    GameTooltip:Show();
end

function Tooltips:DrawOptionTooltip(frame, tooltip)
    ArenaAnalytics:Log(name, description);
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

    player = playerName or "Unknown";
    faction = playerTable["faction"] or "Unknown";
    race = playerTable["race"] or "Unknown Race";
    class = playerTable["class"] or "";
    spec = playerTable["spec"] or "";
    damage = playerTable["damage"] or "-";
    healing = playerTable["healing"] or "-";
    kills = playerTable["kills"] or "-";
    deaths = playerTable["deaths"] or "-";

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

    GameTooltip:SetOwner(playerFrame, "ANCHOR_RIGHT");
    GameTooltip:AddLine(player);    
    GameTooltip:AddDoubleLine(race, ArenaAnalytics:ApplyClassColor(spec .. " " .. class, class));
    GameTooltip:AddLine("");
    GameTooltip:AddDoubleLine(ColorText("Damage: ") .. FormatValue(damage), ColorText("Healing: ") .. FormatValue(healing));
    GameTooltip:AddDoubleLine(ColorText("Kills: ") .. FormatValue(kills), ColorText("Deaths: ") .. FormatValue(deaths));
    GameTooltip:Show();
end