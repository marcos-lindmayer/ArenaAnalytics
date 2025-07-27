local _, ArenaAnalytics = ...; -- Addon Namespace
local Experimental = ArenaAnalytics.Experimental;

-- Local module aliases
local TablePool = ArenaAnalytics.TablePool;
local ArenaID = ArenaAnalytics.ArenaID;
local Localization = ArenaAnalytics.Localization;
local Lookup = ArenaAnalytics.Lookup;
local Helpers = ArenaAnalytics.Helpers;
local Colors = ArenaAnalytics.Colors;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------
-- Simple ScrollBox + MinimalScrollBar Proof of Concept

function Experimental:CreateFrame()
    -- Create test frame
    local testFrame = CreateFrame("Frame", "ScrollBoxTest", UIParent, "BackdropTemplate")
    testFrame:SetSize(300, 400)
    testFrame:SetPoint("CENTER")
    testFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    testFrame:SetBackdropColor(0, 0, 0, 0.8)

    -- Create ScrollBox
    local scrollBox = CreateFrame("Frame", nil, testFrame, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", 10, -10)
    scrollBox:SetPoint("BOTTOMRIGHT", -30, 10)

    -- Create MinimalScrollBar
    local scrollBar = CreateFrame("EventFrame", nil, testFrame, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 5, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 5, 0)

    -- Create view with better pooling configuration
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(25)

    -- Try to configure pooling explicitly
    if view.SetPadding then
        view:SetPadding(0, 0, 0, 0, 2) -- top, bottom, left, right, spacing
    end

    -- Set up pooling limits if available
    if view.SetElementPoolLimit then
        view:SetElementPoolLimit(20) -- Limit pool to reasonable size
    end

    -- Element initializer with better pooling practices
    view:SetElementInitializer("Button", function(button, elementData)
        -- Only create UI elements once
        if not button.isInitialized then
            button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            button.text:SetPoint("LEFT", 5, 0)
            button.isInitialized = true
        end
        
        -- Always update the text (this gets called when pooled buttons are reused)
        button.text:SetText("Item " .. elementData.index .. " - Test Data")
        
        -- Clear any previous state that might cause memory issues
        button:SetScript("OnClick", nil)
    end)

    -- Connect everything
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

    -- Add test data using the correct method
    local dataProvider = CreateDataProvider();
    dataProvider:Init()
    for i = 1, 100 do
        dataProvider:Insert({ index = i })
    end
    scrollBox:SetDataProvider(dataProvider)

    -- Show frame
    testFrame:Show()

    print("ScrollBox test loaded - check for frame on screen")
end
