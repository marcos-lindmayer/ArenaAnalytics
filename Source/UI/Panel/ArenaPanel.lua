local _, ArenaAnalytics = ...; -- Addon Namespace

-- Local module aliases
local UI = ArenaAnalytics.UI;

-------------------------------------------------------------------------

local PANEL_WIDTH, PANEL_HEIGHT = 1000, 540;

local templates = {
    "DefaultPanelTemplate",
    "BasicFrameTemplate",
    "BasicFrameTemplateWithInset",
    "SimplePanelTemplate",

    "InsetFrameTemplate",
    "DialogBorderTemplate",
    "SettingsFrameTemplate",
};

local testIndex = #templates;
function GetNextTemplate()
    local index = testIndex;
    ArenaAnalytics:LogTemp("TemplateIndex:", index)
    testIndex = ((testIndex + 1) % #templates) + 1;
    return templates[index];
end

local function CreateTitle(parent)
    -- Title
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", parent, "TOP", 0, -3)
    title:SetText("Arena Analytics");

    -- Version
    title.version = UI:CreateText
    title.version:SetPoint("TOP", title, "TOP", 0, -3)
    title.version:SetText("|cff909090v" .. API:GetAddonVersion() .. "|r"); -- TODO: Assign text style to determine color

        -- Add the version to the main frame header
        ArenaAnalyticsScrollFrame.titleVersion = ArenaAnalyticsScrollFrame:CreateFontString(nil, "OVERLAY");
        ArenaAnalyticsScrollFrame.titleVersion:SetPoint("LEFT", ArenaAnalyticsScrollFrame.title, "RIGHT", 10, -1);
        ArenaAnalyticsScrollFrame.titleVersion:SetFont("Fonts\\FRIZQT__.TTF", 11, "");
        ArenaAnalyticsScrollFrame.titleVersion:SetText("|cff909090v" .. API:GetAddonVersion() .. "|r");
end

local function CreateOptionsButton(parent)
    local frame = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate");
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -24, -1);
    frame:SetSize(22, 20);
    frame:SetText([[|TInterface\Buttons\UI-OptionsButton:0|t]]);
    frame:SetNormalFontObject("GameFontHighlight");
    frame:SetHighlightFontObject("GameFontHighlight");
    frame:SetScript("OnClick", function()
        Options:Open();
    end);

    return frame;
end

-- Create the main panel frame
function ArenaAnalytics:Load_NEW()
    if(UI.MainFrame) then
        return;
    end

    local frame = CreateFrame("Frame", "ArenaAnalyticsPanel", UIParent, "BasicFrameTemplate");
    frame:SetSize(PANEL_WIDTH, PANEL_HEIGHT);

    if(frame.Bg and frame.Bg.SetColorTexture) then 
        frame.Bg:SetColorTexture(0, 0, 0, 0.97);
    end

    if(frame.TitleBg and frame.TitleBg.SetColorTexture) then
        frame.TitleBg:SetColorTexture(0,0,0,0.97);
    end

    frame:SetFrameStrata("HIGH");
    frame:SetFrameLevel(5);
    frame.CloseButton:SetFrameLevel(frame:GetFrameLevel() + 5);

    frame:SetPoint("CENTER");
    frame:SetMovable(true);
    frame:EnableMouse(true);
    frame:RegisterForDrag("LeftButton");
    frame:SetScript("OnDragStart", frame.StartMoving);
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing);

    -- Add esc to close frame
    _G[ArenaAnalyticsPanel:GetName()] = frame;
    tinsert(UISpecialFrames, ArenaAnalyticsPanel:GetName());

    -- Add a title
    frame.Title = CreateTitle(frame);

    frame.OptionsButton = CreateOptionsButton(frame);

    -- Close button
    --local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    --closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    -- Create a tab system
    --ArenaAnalytics:RegisterTabs();

    -- Store the frame reference for future use
    UI.MainFrame = frame;
end

ArenaAnalytics:Load_NEW();

function ArenaAnalytics:Reload()
    if(UI.MainFrame) then
        UI.MainFrame:Hide();
        UI.MainFrame = nil;
    end

    ArenaAnalytics:Load_NEW();
end

function ArenaAnalytics:Refresh()
    -- Refresh current tab, called each frame during filter refresh.
end

function ArenaAnalytics:ToggleNew(index)
    testIndex = tonumber(index) or testIndex;
    ArenaAnalytics:Reload();

    if(not UI.MainFrame) then
        ArenaAnalytics:Load_NEW();
    end
    UI.MainFrame:Show();
end

function ArenaAnalytics:RegisterTab(key, index, layout)

end