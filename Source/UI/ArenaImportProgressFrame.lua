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

local updateInterval = 0.1;

local progressFrame = nil;
local progressToastFrame = nil;

function ImportProgressFrame:TryCreateProgressFrame()
    if (not progressFrame) then
        -- Create frame with backdrop
        progressFrame = Helpers:CreateDoubleBackdrop(ArenaAnalyticsScrollFrame, "ArenaAnalyticsPlayerTooltip", "TOOLTIP");
        progressFrame:SetPoint("CENTER");
        progressFrame:SetSize(500, 140); -- Increased height for better spacing of elements
        progressFrame:SetFrameStrata("TOOLTIP");
        progressFrame:SetFrameLevel(progressFrame:GetFrameLevel() + 49);
        progressFrame:EnableMouse(true);

        -- Title
        progressFrame.title = ArenaAnalyticsCreateText(progressFrame, "TOPLEFT", progressFrame, "TOPLEFT", 10, -10, "ArenaAnalytics Import Progress", 18);

        -- Separator
        progressFrame.separator = progressFrame:CreateTexture(nil, "ARTWORK");
        progressFrame.separator:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent");
        progressFrame.separator:SetSize(480, 1);
        progressFrame.separator:SetPoint("TOPLEFT", progressFrame.title, "BOTTOMLEFT", 0, -2);

        -- Progress Bar
        progressFrame.progressBar = CreateFrame("StatusBar", nil, progressFrame, "TextStatusBar");
        progressFrame.progressBar:SetSize(460, 10);  -- Longer progress bar across the frame
        progressFrame.progressBar:SetPoint("BOTTOM", progressFrame, "BOTTOM", 0, 10);
        progressFrame.progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
        progressFrame.progressBar:SetStatusBarColor(0.0, 0.65, 0.0);
        progressFrame.progressBar:SetMinMaxValues(0, 100);
        progressFrame.progressBar:SetValue(0);

        -- Progress Text (e.g., "Imported X/Y matches")
        progressFrame.progressText = ArenaAnalyticsCreateText(progressFrame, "TOPLEFT", progressFrame.separator, "BOTTOMLEFT", 8, -8, "", 12);

        -- Elapsed Time (e.g., "Elapsed: 10s")
        progressFrame.elapsedText = ArenaAnalyticsCreateText(progressFrame, "TOPLEFT", progressFrame.progressText, "BOTTOMLEFT", 8, -8, "", 12);

        -- Estimated Remaining Time (e.g., "Remaining: 20s")
        progressFrame.remainingText = ArenaAnalyticsCreateText(progressFrame, "TOPLEFT", progressFrame.elapsedText, "BOTTOMLEFT", 8, -8, "", 12);
    end

    progressFrame:Show();
    return progressFrame;
end

function ImportProgressFrame:TryCreateToast()
    if(not progressToastFrame) then
        progressToastFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate");
        progressToastFrame:SetPoint("TOP", UIParent, "TOP", 0, -25);
        progressToastFrame:SetSize(420, 52);

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

    if(not Import.current) then
        Import.current = {}
    end

    if(not Import.current.state) then
        Import.current.state = {
            startTime = GetTime() - 5000,
            index = 99998,
            total = 99999,
            existing = ArenaAnalyticsDB and #ArenaAnalyticsDB or 0,
            skippedArenaCount = 0,
        };
    end

    -- Fetch state data
    local state = Import.current.state;

    -- Get current time and calculate elapsed time
    local elapsedTime = GetTime() - state.startTime;
    local progress = state.index;
    local total = state.total;

    -- Calculate percentage progress
    local progressPercentage = (progress / total) * 100;
    local percentageText = floor(progressPercentage) .. "%";

    -- Calculate estimated remaining time
    local progressRate = (progress > 0) and (elapsedTime / progress) or 0;
    local estimatedTimeRemaining = (total - progress) * progressRate;

    -- Cache the estimated remaining time and update only if deviation is significant
    local dynamicThreshold = ceil(min(3, estimatedTimeRemaining * 0.1));
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

    local progressText = ColorText("Imported: %s/%s arenas  (%s)", progress, total, percentageText);
    local simpleProgressText = ColorText("Progress: %s/%s  (%s)", progress, total, percentageText);

    local elapsedText = ColorText("Elapsed: %s", SecondsToTime(math.floor(elapsedTime)));
    local remainingText = ColorText("Remaining: %s", SecondsToTime(math.floor(self.lastEstimatedTime)));

    -- Update Progress Frame if it exists
    if progressFrame then
        progressFrame.progressText:SetText(progressText);
        progressFrame.elapsedText:SetText(elapsedText);
        progressFrame.remainingText:SetText(remainingText);
        progressFrame.progressBar:SetValue(progressPercentage);
    end

    -- Update Toast Frame if it exists
    if progressToastFrame then
        progressToastFrame.progressText:SetText(simpleProgressText);
        progressToastFrame.timeRemaining:SetText(remainingText);
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
