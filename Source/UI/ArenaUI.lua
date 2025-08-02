local _, ArenaAnalytics = ...; -- Addon Namespace
local UI = ArenaAnalytics.UI;

-- Local module aliases
local Options = ArenaAnalytics.Options;
local Helpers = ArenaAnalytics.AAtable;
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local Debug = ArenaAnalytics.Debug;

------------------------------------------------------------------

function UI:CreateMainFrame()
    -- Intentionally Global 
    -- TODO: Test: (Might be implicitly global from the frame name? TBD!)
    ArenaAnalyticsPanel = CreateFrame("Frame", "ArenaAnalyticsPanel", UIParent);
    ArenaAnalyticsPanel:SetFrameStrata("HIGH");
    ArenaAnalyticsPanel:SetFrameLevel(666);
    ArenaAnalyticsPanel:SetScale(1); -- TODO: Add as option
    ArenaAnalyticsPanel:SetSize(1000, 540); -- TODO: Compute dynamically

    -- TODO: Change to use 
    ArenaAnalyticsPanel.backdrop = Helpers:CreateDoubleBackdrop(ArenaAnalyticsPanel, self.name, "DIALOG");
end