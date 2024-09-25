local _, ArenaAnalytics = ...; -- Addon Namespace
local ShuffleTooltip = ArenaAnalytics.ShuffleTooltip;
ShuffleTooltip.__index = ShuffleTooltip;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local Tooltips = ArenaAnalytics.Tooltips;
local ArenaIcon = ArenaAnalytics.ArenaIcon;
local Internal = ArenaAnalytics.Internal;
local Options = ArenaAnalytics.Options;

-------------------------------------------------------------------------

--[[
  Shuffle Tooltip
    Summary
                Total Wins
        Average Round Duration?
        Most Deaths   (player name)
    Per round
                Round Number
                Duration
                Win/Loss 
                Team
                Enemy Team
        First Death
--]]

-------------------------------------------------------------------------

local tooltipSingleton = nil;
local currentRounds = nil;

local function CreateRoundEntryFrame(index, parent)
    -- Create a frame for the round entry
    local frame = CreateFrame("Frame", nil, parent);

    local height = 30;
    local borderWidth = 3.5;
    local width = parent:GetWidth() - 2 * borderWidth;

    local yOffset = 10;

    -- Set the size and position for the row (width should match parent)
    frame:SetSize(parent:GetWidth(), height)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", borderWidth, -(height * index + yOffset)) -- Stack vertically

    -- Create the left faction background texture
    frame.bgLeft = frame:CreateTexture(nil, "BACKGROUND");
    frame.bgLeft:SetTexture("Interface\\WorldStateFrame\\WorldStateFinalScore-Highlight");
    frame.bgLeft:SetTexCoord(0, 0.9, 0, 1); -- Use part of the texture (you can tweak it)
    frame.bgLeft:SetPoint("TOPLEFT", frame, "TOPLEFT");
    frame.bgLeft:SetSize(width / 2, height);

    -- Create the right faction background texture
    frame.bgRight = frame:CreateTexture(nil, "BACKGROUND");
    frame.bgRight:SetTexture("Interface\\WorldStateFrame\\WorldStateFinalScore-Highlight");
    frame.bgRight:SetTexCoord(1, 0.1, 0, 1); -- Mirror the texture for the right side
    frame.bgRight:SetPoint("TOPLEFT", frame.bgLeft, "TOPRIGHT");
    frame.bgRight:SetSize(width / 2, height);

    -- Add a label for the round number
    frame.roundText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
    frame.roundText:SetPoint("LEFT", frame, "LEFT", 10, 0);
    frame.roundText:SetText((index or "?") .. ":");

    -- Duration
    frame.duration = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
    frame.duration:SetPoint("RIGHT", frame, "RIGHT", -15, 0);
    frame.duration:SetText("2 Min 57 Sec");

    -- Separator
    frame.separator = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
    frame.separator:SetPoint("CENTER", frame, -40, 0);
    frame.separator:SetText("  vs  ")

    -- Teams
    frame.team = {};
    frame.enemyTeam = {};

    local playerPadding = 4;
    local separatorPadding = 15;

    -- Team
    local lastFrame = frame.separator;
    for i=1, 3 do
        local iconFrame = ArenaIcon:Create(frame, 24);

        iconFrame:SetPoint("RIGHT", lastFrame, "LEFT", 0, 0);
        lastFrame = iconFrame;

        frame.team[i] = iconFrame;
    end

    -- Enemies
    lastFrame = frame.separator;
    for i=1, 3 do
        local iconFrame = ArenaIcon:Create(frame, 22);
        iconFrame:SetPoint("LEFT", lastFrame, "RIGHT", 0, 0);
        lastFrame = iconFrame;

        tinsert(frame.enemyTeam, iconFrame);
    end

    function frame:SetText(text)
        frame.data:SetText(text);
    end

    function frame:SetData(data, team, enemy, firstDeath, duration, isWin, selfPlayer, players)
        self:SetIsWin(isWin);

        duration = tonumber(duration);
        self.duration:SetText(duration and SecondsToTime(duration) or "");

        for i=2, 0, -1 do
            local spec_id, isFirstDeath;

            if(team ~= nil) then
                local playerIndex = (i == 0) and 0 or tonumber(team:sub(i,i));
                if(playerIndex) then
                    local player = (playerIndex==0) and selfPlayer or players[playerIndex];
                    spec_id = ArenaMatch:GetPlayerValue(player, "spec_id");
                    isFirstDeath = (playerIndex == tonumber(firstDeath));
                end
            end

            local playerIcon = self.team[i+1];
            playerIcon:SetSpec(spec_id);
            playerIcon:SetIsFirstDeath(isFirstDeath, true);
        end

        for i=1, 3 do
            local spec_id, isFirstDeath;

            if(enemy ~= nil) then
                local playerIndex = tonumber(enemy:sub(i,i));
                if(playerIndex) then
                    local player = players[playerIndex];
                    spec_id = ArenaMatch:GetPlayerValue(player, "spec_id");
                    isFirstDeath = (playerIndex == tonumber(firstDeath));
                end
            end

            local playerIcon = self.enemyTeam[i];
            playerIcon:SetSpec(spec_id);
            playerIcon:SetIsFirstDeath(isFirstDeath, true);
        end

        return isWin;
    end

    -- Set background color based on round win or loss
    function frame:SetIsWin(isWin)
        if(isWin == nil) then -- Grey for unknown
            frame.bgLeft:SetVertexColor(0.7, 0.7, 0.7, 0.8);
            frame.bgRight:SetVertexColor(0.7, 0.7, 0.7, 0.8);
        elseif(isWin) then -- Green for win
            frame.bgLeft:SetVertexColor(0.19, 0.57, 0.11, 0.8);
            frame.bgRight:SetVertexColor(0.19, 0.57, 0.11, 0.8);
        else -- Red for loss
            frame.bgLeft:SetVertexColor(0.52, 0.075, 0.18, 0.8);
            frame.bgRight:SetVertexColor(0.52, 0.075, 0.18, 0.8);
        end
    end

    return frame;
end

-- Get existing shuffle tooltip, or create a new one
local function GetOrCreateSingleton()
    if(not tooltipSingleton) then
        local self = setmetatable({}, ShuffleTooltip);

        self.frame = CreateFrame("Frame", self.name, ArenaAnalyticsScrollFrame, "TooltipBackdropTemplate");
        self.frame:SetSize(320, 100);
        self.frame:SetFrameStrata("TOOLTIP");

        -- TODO: fill out the tooltip
        self.title = ArenaAnalyticsCreateText(self.frame, "TOPLEFT", self.frame, "TOPLEFT", 10, -10, "|cffffcc00Solo Shuffle|r", 18);
        self.winsText = ArenaAnalyticsCreateText(self.frame, "TOPRIGHT", self.frame, "TOPRIGHT", -10, -10, " ", 15);

        self.rounds = {}

        for i=1, 6 do
            self.rounds[i] = CreateRoundEntryFrame(i, self.frame);
        end

        self.mostDeaths = nil; -- NOTE: For now, it'll be recreated any time it changes anyways (To fix russian names)

        ArenaAnalytics:Log("Created new Shuffle Tooltip singleton!", #self.rounds);
        tooltipSingleton = self;
    end

    assert(tooltipSingleton);
    return tooltipSingleton;
end

function ShuffleTooltip:SetMatch(match)
    local self = GetOrCreateSingleton();

    local bracket = ArenaMatch:GetBracket(match);
    if(bracket ~= "shuffle") then
        ShuffleTooltip:Hide();
        return;
    end

    Tooltips:HideAll();

    currentRounds = ArenaMatch:GetRounds(match);

    if(not currentRounds or #currentRounds == 0) then
        -- TODO: Custom visual informing user that currentRounds are missing
        ShuffleTooltip:Hide(); -- TEMP
        return;
    end

    local newHeight = 75;

    local wins = 0;

    local deaths = {}

    local selfPlayer = ArenaMatch:GetSelf(match);
    local players = ArenaMatch:GetTeam(match, true);

    for i=1, 6 do
        local roundFrame = self.rounds[i];
        assert(roundFrame, "ShuffleTooltip should always have 6 round frames!" .. (self.rounds and #self.rounds or "nil"));

        local roundData = ArenaMatch:GetRoundData(currentRounds[i]);
        if(roundData) then
            newHeight = newHeight + roundFrame:GetHeight();

            local team, enemy, firstDeath, duration = string.match(roundData, "([^%-]*)%-([^%-]*)%-([^%-]*)%-([^%-]*)");

            local isWin;
            if(tonumber(firstDeath)) then
                firstDeath = tonumber(firstDeath);

                if(team and team:find(firstDeath)) then
                    isWin = false;
                elseif(enemy and enemy:find(firstDeath)) then
                    isWin = true;
                end

                deaths[firstDeath] = (deaths[firstDeath] or 0) + 1;
            elseif(type(firstDeath) == "string") then
                if(firstDeath:upper() == "W") then
                    isWin = true;
                elseif(firstDeath:upper() == "L") then
                    isWin = false;
                end
            end

            roundFrame:SetData(roundData, team, enemy, firstDeath, duration, isWin, selfPlayer, players);

            if(isWin) then
                wins = wins + 1;
            end

            roundFrame:Show();
        else
            roundFrame:Hide();
        end
    end

    -- Most Deaths
    local bestIndex, highestValue;
    for playerIndex, deaths in pairs(deaths) do
        if(not bestIndex or highestValue and highestValue < deaths) then
            bestIndex = playerIndex;
            highestValue = deaths;
        end
    end

    local deathText = "";
    if(bestIndex and highestValue) then
        local player = (bestIndex == 0) and selfPlayer or players[bestIndex];
        local fullName = ArenaMatch:GetPlayerFullName(player);
        local spec_id = ArenaMatch:GetPlayerValue(player, "spec_id");

        local color = Internal:GetClassColor(spec_id);

        deathText = fullName and ("|c" .. color .. fullName .. "|r ") or "";
        deathText = deathText .. ("|cffffffff" .. highestValue .. "|r");
    end

    local text = "|cff999999".. "Most Deaths: " .. "|r" .. deathText .. "|r";
    if(self.mostDeaths) then
        self.mostDeaths:SetText("");
    end
    self.mostDeaths = ArenaAnalyticsCreateText(self.frame, "BOTTOMLEFT", self.frame, "BOTTOMLEFT", 10, 15, text, 12);

    -- Win color
    local hex = "ff999999";
    if(wins ~= nil) then
        if(wins == 3) then
            hex = "ffffcc00";
        else
            hex = (wins > 3) and "ff00cc66" or "ffff0000";
        end
    end

    -- Set total wins text
    self.winsText:SetText("|c"..hex .. "Wins: " .. (wins or "") .. "|r");
    
    -- Update dynamic background height
    self.frame:SetHeight(newHeight);
end

function ShuffleTooltip:SetEntryFrame(frame)
    if(not frame) then
        ShuffleTooltip:Hide();
        return;
    end

    local self = GetOrCreateSingleton();
    self.parent = frame;

    -- TODO: Put it on top if the dropdown would go off screen
    local doesFitUnder = true; -- Temp

    if(doesFitUnder) then
        self.frame:SetPoint("TOPLEFT", frame, "BOTTOMLEFT");
    else
        self.frame:SetPoint("BOTTOMLEFT", frame, "TOPLEFT");
    end
end

function ShuffleTooltip:Show()
    local self = GetOrCreateSingleton();
    self.frame:Show();
end

function ShuffleTooltip:Hide()
    local self = GetOrCreateSingleton();
    self.frame:Hide();
end

