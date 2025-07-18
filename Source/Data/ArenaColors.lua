local _, ArenaAnalytics = ...; -- Addon Namespace
local Colors = ArenaAnalytics.Colors;

-- Local module aliases
local API = ArenaAnalytics.API;

-------------------------------------------------------------------------

-- Theme Color
Colors.themeColor = "ff00ccff";

-- Text colors
Colors.titleColor = "ffffffff";
Colors.versionColor = "ff909090";

Colors.headerColor = "ffd0d0d0";
Colors.prefixColor = "FFAAAAAA";
Colors.statsColor = "ffffffff";
Colors.valueColor = nil; -- f5f5f5 for white?
Colors.infoColor = "ffbbbbbb";

-- Outcome colors
Colors.winColor = "ff00cc66";
Colors.lossColor = "ffff0000";
Colors.drawColor = "ffefef00";
Colors.invalidColor = "ff999999";

-- Faction colors
Colors.allianceColor = "FF009DEC";
Colors.hordeColor = "ffE00A05";

-- Log Colors
Colors.logColor = "ffff6ec7";
Colors.logGreenColor = "ff1effa7";
Colors.warningColor = "ffffd700";
Colors.errorColor = "ffff1111";
Colors.tempColor = "fffe42ee";
Colors.slashCommandColor = "ff00cc66";

-- Explicit colors (Makes it easier to find and modify later)
Colors.white = "ffffffff";
Colors.red = "ffff0000";

-------------------------------------------------------------------------

function Colors:ColorText(text, color)
    text = text or "";

    if(not color) then
        return text;
    end

    if(#color == 6) then
        color = "ff" .. color;
    end

    return "|c" .. color .. text .. "|r"
end

function Colors:GetTitle(asSingleColor)
	if(asSingleColor) then
		return Colors:ColorText("ArenaAnalytics", Colors.themeColor);
	else
		return "Arena" .. Colors:ColorText("Analytics", Colors.themeColor);
	end
end

function Colors:GetVersionText(invalidText)
    local version = API and API:GetAddonVersion();

    if(version) then
        return Colors:ColorText("v" .. version, Colors.versionColor);
    end

    return Colors:ColorText(invalidText or "v???", Colors.versionColor);
end