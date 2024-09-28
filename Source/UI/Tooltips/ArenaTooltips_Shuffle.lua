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
local Constants = ArenaAnalytics.Constants;

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
    local newFrame = CreateFrame("Frame", nil, parent);

    local height = 30;
    local borderWidth = 3.5;
    local width = parent:GetWidth() - 2 * borderWidth;

    local yOffset = 10;

    -- Set the size and position for the row (width should match parent)
    newFrame:SetSize(parent:GetWidth(), height)
    newFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", borderWidth, -(height * index + yOffset)) -- Stack vertically

    -- Create the left faction background texture
    newFrame.bgLeft = newFrame:CreateTexture(nil, "BACKGROUND");
    newFrame.bgLeft:SetTexture("Interface\\WorldStateFrame\\WorldStateFinalScore-Highlight");
    newFrame.bgLeft:SetTexCoord(0, 0.9, 0, 1); -- Use part of the texture (you can tweak it)
    newFrame.bgLeft:SetPoint("TOPLEFT", newFrame, "TOPLEFT");
    newFrame.bgLeft:SetSize(width / 2, height);

    -- Create the right faction background texture
    newFrame.bgRight = newFrame:CreateTexture(nil, "BACKGROUND");
    newFrame.bgRight:SetTexture("Interface\\WorldStateFrame\\WorldStateFinalScore-Highlight");
    newFrame.bgRight:SetTexCoord(1, 0.1, 0, 1); -- Mirror the texture for the right side
    newFrame.bgRight:SetPoint("TOPLEFT", newFrame.bgLeft, "TOPRIGHT");
    newFrame.bgRight:SetSize(width / 2, height);

    -- Add a label for the round number
    newFrame.roundText = newFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
    newFrame.roundText:SetPoint("LEFT", newFrame, "LEFT", 10, 0);
    ArenaAnalytics:SetFrameText(newFrame.roundText, ((index or "?") .. ":"), Constants.valueColor)

    -- Duration
    newFrame.duration = newFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
    newFrame.duration:SetPoint("RIGHT", newFrame, "RIGHT", -15, 0);

    -- Separator
    newFrame.separator = newFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
    newFrame.separator:SetPoint("CENTER", newFrame, -40, 0);
    ArenaAnalytics:SetFrameText(newFrame.separator, "  vs  ", Constants.valueColor);

    -- Teams
    newFrame.team = {};
    newFrame.enemyTeam = {};

    local playerPadding = 4;
    local separatorPadding = 15;

    -- Team
    local lastFrame = newFrame.separator;
    for i=3, 1, -1 do
        local iconFrame = ArenaIcon:Create(newFrame, 24);

        iconFrame:SetPoint("RIGHT", lastFrame, "LEFT", -2, 0);
        lastFrame = iconFrame;

        newFrame.team[i] = iconFrame;
    end

    -- Enemies
    lastFrame = newFrame.separator;
    for i=1, 3 do
        local iconFrame = ArenaIcon:Create(newFrame, 22);
        iconFrame:SetPoint("LEFT", lastFrame, "RIGHT", 2, 0);
        lastFrame = iconFrame;

        tinsert(newFrame.enemyTeam, iconFrame);
    end

    function newFrame:SetData(data, team, enemy, firstDeath, duration, isWin, selfPlayer, players)
        self:SetIsWin(isWin);

        duration = tonumber(duration);
        ArenaAnalytics:SetFrameText(self.duration, (duration and SecondsToTime(duration)), Constants.valueColor)

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
    function newFrame:SetIsWin(isWin)
        if(isWin == nil) then -- Grey for unknown
            newFrame.bgLeft:SetVertexColor(0.7, 0.7, 0.7, 0.8);
            newFrame.bgRight:SetVertexColor(0.7, 0.7, 0.7, 0.8);
        elseif(isWin) then -- Green for win
            newFrame.bgLeft:SetVertexColor(0.19, 0.57, 0.11, 0.8);
            newFrame.bgRight:SetVertexColor(0.19, 0.57, 0.11, 0.8);
        else -- Red for loss
            newFrame.bgLeft:SetVertexColor(0.52, 0.075, 0.18, 0.8);
            newFrame.bgRight:SetVertexColor(0.52, 0.075, 0.18, 0.8);
        end
    end

    return newFrame;
end

-- Get existing shuffle tooltip, or create a new one
local function GetOrCreateSingleton()
    if(not tooltipSingleton) then
        local self = setmetatable({}, ShuffleTooltip);

        self.frame = CreateFrame("Frame", self.name, ArenaAnalyticsScrollFrame, "TooltipBackdropTemplate");
        self.frame:SetSize(320, 100);
        self.frame:SetFrameStrata("TOOLTIP");

        -- TODO: fill out the tooltip
        self.title = ArenaAnalyticsCreateText(self.frame, "TOPLEFT", self.frame, "TOPLEFT", 10, -10, ArenaAnalytics:ColorText("Solo Shuffle", Constants.titleColor), 18);
        self.winsText = ArenaAnalyticsCreateText(self.frame, "TOPRIGHT", self.frame, "TOPRIGHT", -10, -10, "", 15);

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

    if(not ArenaMatch:IsShuffle(match)) then
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

        local roundData = ArenaMatch:GetRoundDataRaw(currentRounds[i]);
        if(roundData) then
            newHeight = newHeight + roundFrame:GetHeight();

            local team, enemy, firstDeath, duration = ArenaMatch:SplitRoundData(roundData);

            local isWin;
            if(tonumber(firstDeath)) then
                firstDeath = tonumber(firstDeath);

                if(firstDeath == 0 or (team and team:find(firstDeath))) then
                    isWin = false;
                elseif(enemy and enemy:find(firstDeath)) then
                    isWin = true;
                end

                deaths[firstDeath] = (deaths[firstDeath] or 0) + 1;
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
        
        local classColor = Internal:GetClassColor(spec_id);
        deathText = ArenaAnalytics:ColorText(fullName, classColor);
        deathText = deathText .. " " .. ArenaAnalytics:ColorText(highestValue, Constants.valueColor);
    end

    -- Clear previous most deaths text
    if(self.mostDeaths) then
        self.mostDeaths:SetText("");
    end

    local text = ArenaAnalytics:ColorText("Most Deaths: ", Constants.prefixColor) .. deathText;
    self.mostDeaths = ArenaAnalyticsCreateText(self.frame, "BOTTOMLEFT", self.frame, "BOTTOMLEFT", 10, 15, text, 12);

    -- Win color
    local hex = Constants.invalidColor;
    if(wins ~= nil) then
        if(wins == 3) then
            hex = Constants.drawColor;
        else
            hex = (wins > 3) and Constants.winColor or Constants.lossColor;
        end
    end

    -- Set total wins text
    ArenaAnalytics:SetFrameText(self.winsText, "Wins: " .. wins, hex)

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

