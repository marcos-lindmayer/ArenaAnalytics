local _, ArenaAnalytics = ...; -- Addon Namespace
local ImportProgressFrame = ArenaAnalytics.ImportProgressFrame;

-- Local module aliases
local Import = ArenaAnalytics.Import;
local Sessions = ArenaAnalytics.Sessions;
local TablePool = ArenaAnalytics.TablePool;
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local Filters = ArenaAnalytics.Filters;
local Helpers = ArenaAnalytics.Helpers;
local Debug = ArenaAnalytics.Debug;
local Constants = ArenaAnalytics.Constants;

-------------------------------------------------------------------------

local updateInterval = 0.5;

local progressFrame = nil;
local progressToastFrame = nil;

function ImportProgressFrame:TryCreateProgressFrame()
    if (not progressFrame) then
        -- Create frame with backdrop
        progressFrame = Helpers:CreateDoubleBackdrop(ArenaAnalyticsScrollFrame, "ArenaAnalyticsPlayerTooltip", "TOOLTIP");
        progressFrame:SetPoint("CENTER");
        progressFrame:SetSize(400, 100); -- Increased height for better spacing of elements
        progressFrame:SetFrameStrata("TOOLTIP");
        progressFrame:SetFrameLevel(progressFrame:GetFrameLevel() + 49);
        progressFrame:EnableMouse(true);

        local padding = 5;

        -- Title
        progressFrame.title = ArenaAnalyticsCreateText(progressFrame, "TOPLEFT", progressFrame, "TOPLEFT", 10, -10, "ArenaAnalytics importing...", 18);

        -- Separator
        progressFrame.separator = progressFrame:CreateTexture(nil, "ARTWORK");
        progressFrame.separator:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent");
        progressFrame.separator:SetSize(progressFrame:GetWidth() - 20, 16);
        progressFrame.separator:SetPoint("TOPLEFT", progressFrame.title, "BOTTOMLEFT", 0, 3);

        -- Progress Text (e.g., "Imported X/Y matches")
        progressFrame.progressText = ArenaAnalyticsCreateText(progressFrame, "TOPLEFT", progressFrame.separator, "BOTTOMLEFT", 0.3, -padding, "", 12);

        -- Progress Bar
        progressFrame.progressBar = CreateFrame("StatusBar", nil, progressFrame, "TextStatusBar");
        progressFrame.progressBar:SetPoint("TOPLEFT", progressFrame.progressText, "BOTTOMLEFT", 0, -padding);
        progressFrame.progressBar:SetSize(progressFrame:GetWidth() - 20, 13);  -- Longer progress bar across the frame
        progressFrame.progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
        progressFrame.progressBar:SetStatusBarColor(0.0, 0.8, 1);
        progressFrame.progressBar:SetMinMaxValues(0, 100);
        progressFrame.progressBar:SetValue(0);

        -- Elapsed Time (e.g., "Elapsed: 10s")
        progressFrame.elapsedText = ArenaAnalyticsCreateText(progressFrame, "TOPLEFT", progressFrame.progressBar, "BOTTOMLEFT", 0, -padding, "", 12);

        -- Estimated Remaining Time (e.g., "Remaining: 20s")
        progressFrame.remainingText = ArenaAnalyticsCreateText(progressFrame, "TOPLEFT", progressFrame.progressBar, "BOTTOMRIGHT", -170.7, -padding, "", 12);
    end

    progressFrame:Show();
    return progressFrame;
end

function ImportProgressFrame:TryCreateToast()
    if(not progressToastFrame) then
        progressToastFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate");
        progressToastFrame:SetPoint("TOP", UIParent, "TOP", 0, -25);
        progressToastFrame:SetSize(420, 52);
        progressToastFrame:SetClipsChildren(false);

        progressToastFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        });
        progressToastFrame:SetBackdropColor(0, 0, 0, 0.8);

        -- Title
        progressToastFrame.title = progressToastFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
        progressToastFrame.title:SetPoint("TOPLEFT", progressToastFrame, "TOPLEFT", 10, -10);
        progressToastFrame.title:SetText("ArenaAnalytics importing...");

        -- Progress
        progressToastFrame.progressText = ArenaAnalyticsCreateText(progressToastFrame, "BOTTOMLEFT", progressToastFrame, "BOTTOMLEFT", 10, 10, "", 12);

        -- Estimated Time Remaining
        progressToastFrame.timeRemaining = progressToastFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
        progressToastFrame.timeRemaining:SetText("Estimated remaining: 0s");
        progressToastFrame.timeRemaining:SetPoint("BOTTOMLEFT", progressToastFrame, "BOTTOMRIGHT", -170.7, 10);
        
        -- Progress Bar
        progressToastFrame.progressBar = CreateFrame("StatusBar", nil, progressToastFrame, "TextStatusBar");
        progressToastFrame.progressBar:SetPoint("BOTTOMLEFT", progressToastFrame, "BOTTOMLEFT", 6, 3);
        progressToastFrame.progressBar:SetSize(progressToastFrame:GetWidth() - 12, 5);  -- Longer progress bar across the frame
        progressToastFrame.progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
        progressToastFrame.progressBar:SetStatusBarColor(0.0, 0.8, 1);
        progressToastFrame.progressBar:SetMinMaxValues(0, 100);
        progressToastFrame.progressBar:SetValue(99);
    end

    progressToastFrame:Show();
    return progressToastFrame;
end

function ImportProgressFrame:Update()
    -- Ensure import is active
    if(not Import.isImporting) then
        ImportProgressFrame:Stop();
        return;
    end

    if(not Import.state) then
        Import.state = {
            startTime = 0,
            index = 0,
            total = 0,
            existing = ArenaAnalyticsDB and #ArenaAnalyticsDB or 0,
            skippedArenaCount = 0,
        };
    end

    -- Fetch state data
    local state = Import.state;

    -- Get current time and calculate elapsed time
    local elapsedTime = GetTime() - state.startTime;

    -- Calculate percentage progress
    local progressPercentage = state.total > 0 and ((state.index / state.total) * 100) or 0;
    local percentageText = floor(progressPercentage) .. "%";

    -- Calculate estimated remaining time
    local progressRate = (state.index > 0) and (elapsedTime / state.index) or 0;
    local estimatedTimeRemaining = (state.total - state.index) * progressRate;

    -- Cache the estimated remaining time and update only if deviation is significant
    local dynamicThreshold = ceil(min(1, estimatedTimeRemaining * 0.1));
    if(not self.lastEstimatedTime or math.abs(self.lastEstimatedTime - estimatedTimeRemaining) > dynamicThreshold) then
        self.lastEstimatedTime = math.ceil(estimatedTimeRemaining);
    else
        -- Decrement the cached estimate (simulating countdown)
        self.lastEstimatedTime = self.lastEstimatedTime - updateInterval;
    end

    local function ColorText(textFormat, ...)
        textFormat = ArenaAnalytics:ColorText(textFormat, Constants.prefixColor)

        -- Gather the arguments into a table and color them with statsColor
        local coloredArgs = {...}
        for i = 1, #coloredArgs do
            coloredArgs[i] = ArenaAnalytics:ColorText(coloredArgs[i], Constants.statsColor)
        end

        -- Return the formatted string using the colored arguments
        return format(textFormat, unpack(coloredArgs))
    end

    local progressText = ColorText("Imported: %s/%s arenas  (%s)", state.index, state.total, percentageText);
    local simpleProgressText = ColorText("Progress: %s/%s  (%s)", state.index, state.total, percentageText);

    local elapsedText = ColorText("Elapsed: %s", SecondsToTime(math.floor(elapsedTime)));
    local remainingText = ColorText("Remaining: %s", (self.lastEstimatedTime > 3 and SecondsToTime(math.floor(self.lastEstimatedTime)) or "Few seconds"));

    -- Update Progress Frame if it exists
    if(progressFrame) then
        progressFrame.progressText:SetText(progressText);
        progressFrame.elapsedText:SetText(elapsedText);
        progressFrame.remainingText:SetText(remainingText);
        progressFrame.progressBar:SetValue(progressPercentage);
    end

    -- Update Toast Frame if it exists
    if(progressToastFrame) then
        if(state.total > 1000) then
            progressToastFrame.progressText:SetText(simpleProgressText);
            progressToastFrame.timeRemaining:SetText(remainingText);
            progressToastFrame.progressBar:SetValue(progressPercentage);
        else
            progressToastFrame:Hide();
            progressToastFrame = nil;
        end
    end

    -- Schedule the next update (every 1 second)
    C_Timer.After(updateInterval, function() self:Update() end);
end

function ImportProgressFrame:Stop()
    -- Hide and release both progress frames if they exist
    if progressFrame then
        progressFrame:Hide();
        progressFrame = nil;
    end

    if progressToastFrame then
        progressToastFrame:Hide();
        progressToastFrame = nil;
    end
end

function ImportProgressFrame:Start()
    ImportProgressFrame:TryCreateProgressFrame();
    ImportProgressFrame:TryCreateToast();

    -- Setup constants
    self:Update();
end
ImportProgressFrame:Start();
