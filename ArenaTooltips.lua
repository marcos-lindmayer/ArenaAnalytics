local _, ArenaAnalytics = ...; -- Namespace
ArenaAnalytics.Tooltips = {};
local Tooltips = ArenaAnalytics.Tooltips;

function Tooltips.DrawMinimapTooltip()
    GameTooltip:SetOwner(ArenaAnalyticsMinimapButton, "ANCHOR_BOTTOMLEFT");
    GameTooltip:AddDoubleLine(ArenaAnalytics:GetTitleColored(true), "|cff666666v" .. ArenaAnalytics:getVersion() .. "|r");
    GameTooltip:AddLine("|cffBBBBBB" .. "Left Click|r" .. " to toggle ArenaAnalytics");
    GameTooltip:AddLine("|cffBBBBBB" .. "Right Click|r".. " to open Options");
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
    race = playerTable["race"] or "Unknwon";
    class = playerTable["class"] or "Unknwon";
    spec = playerTable["spec"] or "Unknwon";
    damage = playerTable["damageDone"] or "-";
    healing = playerTable["healingDone"] or "-";
    kills = playerTable["kills"] or "-";
    deaths = playerTable["deaths"] or "-";

    local function ColorText(text)
        return "|cff999999" .. text or "" .. "|r";
    end

    local function ColorValue(text)
        return text or "" .. "|r";
    end

    local function FormatValue(value)
        if (value ~= "-") then
            value = value or 0;

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