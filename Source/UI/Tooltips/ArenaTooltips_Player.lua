local _, ArenaAnalytics = ...; -- Addon Namespace
local PlayerTooltip = ArenaAnalytics.PlayerTooltip;
PlayerTooltip.__index = PlayerTooltip;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local Tooltips = ArenaAnalytics.Tooltips;
local ArenaIcon = ArenaAnalytics.ArenaIcon;
local Internal = ArenaAnalytics.Internal;
local Options = ArenaAnalytics.Options;
local Constants = ArenaAnalytics.Constants;
local TablePool = ArenaAnalytics.TablePool;
local API = ArenaAnalytics.API;

-------------------------------------------------------------------------

--[[
  Shuffle Tooltip
    Header
        Class/Spec icon
        Full Name
        Race
        Spec
        Faction Icon
    Separator line
    Statistics
        Kills
        Deaths
        Damage
        Healing
        DPS
        HPS
        Rating / Rating Delta (Retail rated only)
        MMR / MMR Delta (Retail rated only)
        Wins (Shuffle only)
    Quick Search shortcuts

--]]

-------------------------------------------------------------------------

local tooltipSingleton = nil;

-- Get existing shuffle tooltip, or create a new one
local function GetOrCreateSingleton()
    if(not tooltipSingleton) then
        local self = setmetatable({}, PlayerTooltip);

        self.frame = CreateFrame("Frame", "ArenaAnalyticsPlayerTooltip", ArenaAnalyticsScrollFrame, "TooltipBackdropTemplate");
        self.frame:SetSize(320, 200);
        self.frame:SetFrameStrata("TOOLTIP");
        self.frame:SetBackdropColor(0,0,0,1);

        self.icon = ArenaIcon:Create(self.frame, 36, true);
        self.icon:SetPoint("TOPLEFT", 9, -10);

        self.factionIcon = self.frame:CreateTexture(nil, "ARTWORK");
        self.factionIcon:SetSize(47,47);
        self.factionIcon:SetPoint("TOPRIGHT", -3, -8);
        self.factionIcon:SetTexture(134400);

        self.name = nil;
        self.info = ArenaAnalyticsCreateText(self.frame, "BOTTOMLEFT", self.icon, "BOTTOMRIGHT", 5, 1, "", 14);

        self.separator = self.frame:CreateTexture(nil, "ARTWORK")
        self.separator:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
        self.separator:SetSize(self.frame:GetWidth() - self.factionIcon:GetWidth() - 5, 16);
        self.separator:SetPoint("TOPLEFT", self.icon, "BOTTOMLEFT", 0, 3);

        self.stats = {}
        self.statsFrames = {};

        ArenaAnalytics:Log("Created new Shuffle Tooltip singleton!", #self.stats);
        tooltipSingleton = self;
    end

    assert(tooltipSingleton);
    return tooltipSingleton;
end

function PlayerTooltip:SetInfo(race_id, spec_id)
    local race = Internal:GetRace(race_id);
    if(race) then
        local factionColor = Internal:GetRaceFactionColor(race_id);
        race = ArenaAnalytics:ColorText(race, factionColor);
    end

    local class, spec = Internal:GetClassAndSpec(spec_id);

    local specialization = nil;
    if(class and spec) then
        specialization = string.format("%s %s", spec, class);
    else
        specialization = class or spec or "";
    end

    if(specialization ~= "") then
        local color = Internal:GetClassColor(spec_id) or "ffffff";
        specialization = ArenaAnalytics:ColorText(specialization, color);
    end

    local text = race and string.format("%s  %s", race, specialization) or specialization;

    local self = GetOrCreateSingleton(); -- Tooltip singleton
    self.info:SetText(text);
end

function PlayerTooltip:SetFaction(race_id)
    faction = tonumber(race_id) and tonumber(race_id) % 2;

    local texture = "";
    if(faction == 0) then
        texture = "Interface\\FriendsFrame\\PlusManz-Horde";
    elseif(faction == 1) then
        texture = "Interface\\FriendsFrame\\PlusManz-Alliance";
    end

    local self = GetOrCreateSingleton(); -- Tooltip singleton
    self.factionIcon:SetTexture(texture);
end

function PlayerTooltip:ClearStats()
    local self = GetOrCreateSingleton(); -- Tooltip singleton

    TablePool:Release(self.stats);
    self.stats = TablePool:Acquire();
end

function PlayerTooltip:AddStatistic(prefix, value)
    local self = GetOrCreateSingleton(); -- Tooltip singleton

    prefix = ArenaAnalytics:ColorText(prefix, Constants.prefixColor);
    tinsert(self.stats, prefix .. Helpers:FormatNumber(value));
end

-- Skips to new line, optionally adding a y offset.
function PlayerTooltip:AddSpacer(offset)
    offset = offset or 0;
    tinsert(self.stats, offset);
end

function PlayerTooltip:DrawStats()
    local self = GetOrCreateSingleton(); -- Tooltip singleton

    local xOffset = 10;
    local yOffset = 0
    local rowHeight = 15

    local isLeft = true
    local relativeFrame = self.separator;

    local maxIndex = max(#self.stats, #self.statsFrames)

    for i=1, maxIndex do
        local value = self.stats[i];

        if value == nil then
            -- Hide and clear the extra font strings
            if self.statsFrames[i] then
                self.statsFrames[i]:SetText("");
                self.statsFrames[i]:Hide();
            end
        elseif tonumber(value) then
            -- Adjust yOffset for numerical spacer values
            yOffset = yOffset - rowHeight - tonumber(value);
        else
            -- Create or reuse a font string for the stat
            if(not self.statsFrames[i]) then
                self.statsFrames[i] = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
            end
            local statFrame = self.statsFrames[i];
            statFrame:SetText(tostring(value));

            -- Position the stat in either the left or right column
            local realOffsetX = isLeft and xOffset or (self.frame:GetWidth() / 2);

            statFrame:SetPoint("TOPLEFT", relativeFrame, "BOTTOMLEFT", realOffsetX, yOffset);

            if(not isLeft) then
                yOffset = yOffset - rowHeight;
            end

            isLeft = not isLeft;
        end
    end
end

local function SetNameText(text)
    local self = GetOrCreateSingleton();
    if(self.name) then
        self.name:SetText("");
        self.name = nil;
    end

    -- Define desired and minimum sizes
    local desiredSize = 16;
    local maxLength = 20; -- Max characters before scaling down

    local size = desiredSize;

    if(#text > maxLength) then
        local minSize = 10;
        local scaleFactor = 0.5;
        
        local excessLength = #text - maxLength;
        size = desiredSize - (excessLength * scaleFactor);
        size = max(size, minSize);
    end

    self.name = ArenaAnalyticsCreateText(self.frame, "TOPLEFT", self.icon, "TOPRIGHT", 5, -1, text, size);
end

local function FormatRating(value, delta)
    local text = tonumber(value) or "-";

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

function PlayerTooltip:SetPlayerFrame(frame)
    if(not frame or not frame.player) then
        PlayerTooltip:Hide();
        return;
    end

    local self = GetOrCreateSingleton();

    local name = ArenaMatch:GetPlayerFullName(frame.player, true);
    local race_id = ArenaMatch:GetPlayerRace(frame.player);
    local spec_id = ArenaMatch:GetPlayerSpec(frame.player)

    self.icon:SetSpec(spec_id);
    SetNameText(name);
    PlayerTooltip:SetInfo(race_id, spec_id);
    PlayerTooltip:SetFaction(race_id);

    -- Reset stats
    PlayerTooltip:ClearStats();

    local kills, deaths, damage, healing = ArenaMatch:GetPlayerStats(frame.player);

    PlayerTooltip:AddStatistic("Kills: ", kills);
    PlayerTooltip:AddStatistic("Deaths: ", deaths);
    PlayerTooltip:AddStatistic("Damage: ", damage);
    PlayerTooltip:AddStatistic("Healing: ", healing);

    -- DPS / HPS
    local duration = ArenaMatch:GetDuration(frame.match);
    if(duration and duration > 0) then
        local dps = damage and damage / duration or "-";
        local hps = healing and healing / duration or "-";

        PlayerTooltip:AddStatistic("DPS: ", dps);
        PlayerTooltip:AddStatistic("HPS: ", hps);
    end

    -- Player Rating Info
    if(ArenaMatch:IsRated(frame.match)) then
        local rating, ratingDelta, mmr, mmrDelta = ArenaMatch:GetPlayerRatedInfo(frame.player);
        if(rating or API.showPerPlayerRatedInfo) then
            PlayerTooltip:AddStatistic("Rating: ", FormatRating(rating, ratingDelta));
        end

        if(mmr or API.showPerPlayerRatedInfo) then
            PlayerTooltip:AddStatistic("MMR: ", FormatRating(mmr, mmrDelta));
        end
    end

    if(ArenaMatch:IsShuffle(frame.match)) then
        PlayerTooltip:AddShuffleStats(frame);
    end

    -- Draw in the added stats
    PlayerTooltip:DrawStats();

    self.parent = frame;
    self.frame:SetPoint("TOPLEFT", frame, "BOTTOMLEFT");
    PlayerTooltip:Show();
end

function PlayerTooltip:AddShuffleStats(frame)
    local wins = ArenaMatch:GetPlayerVariableStats(player);
    PlayerTooltip:AddStatistic("Wins: ", wins);
end

function PlayerTooltip:SetPoint(...)
    local self = GetOrCreateSingleton();
    self.frame:SetPoint(...);
end

function PlayerTooltip:Show()
    local self = GetOrCreateSingleton();
    self.frame:Show();
end

function PlayerTooltip:Hide()
    local self = GetOrCreateSingleton();
    self.frame:Hide();
end

