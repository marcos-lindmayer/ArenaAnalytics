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
-- Test Data Generation

-- Initialize with empty table
Experimental.testItems = {}

-- Function to generate a new randomized entry
local function CreateNewTestItem()
    local id = #Experimental.testItems + 1
    local newItem = {
        id = id,
        description = "Match Data " .. id,
        timestamp = time() - (math.random(1, 72) * 3600), -- Random within 3 days
        rating = 800 + math.random(1, 1600), -- Random rating between 800-2400
        won = math.random() > 0.5 -- Random win/loss
    }
    
    table.insert(Experimental.testItems, newItem)

    return newItem
end

-- Initialize with starting items
local function InitializeTestItems()
    if #Experimental.testItems > 0 then
        return -- Already initialized
    end
    
    -- Create initial 100 items
    for i = 1, 5 do
        CreateNewTestItem()
    end
    
    Debug:LogTemp("Initialized with " .. #Experimental.testItems .. " test items")
end

-- Get test item by index
local function GetTestItem(index)
    if #Experimental.testItems == 0 then
        InitializeTestItems()
    end
    
    if index >= 1 and index <= #Experimental.testItems then
        return Experimental.testItems[index]
    end
    
    return nil
end

-------------------------------------------------------------------------
-- Virtual Data Provider

---@class dataprovider
local VirtualDataProviderMixin = CreateFromMixins(CallbackRegistryMixin)

function VirtualDataProviderMixin:Init()
    CallbackRegistryMixin.OnLoad(self)
end

function VirtualDataProviderMixin:GetSize()
    return #Experimental.testItems
end

function VirtualDataProviderMixin:Enumerate(indexBegin, indexEnd)
    local size = self:GetSize()
    indexBegin = indexBegin or 1
    indexEnd = indexEnd or size
    
    local current = indexBegin - 1
    return function()
        current = current + 1
        if current <= indexEnd and current <= size then
            return current, GetTestItem(current)
        end
    end
end

function VirtualDataProviderMixin:EnumerateEntireRange()
    return self:Enumerate(1, self:GetSize())
end

function VirtualDataProviderMixin:Find(index)
    return GetTestItem(index)
end

function VirtualDataProviderMixin:FindIndex(elementData)
    if elementData and elementData.id then
        local id = elementData.id
        if id >= 1 and id <= #Experimental.testItems then
            return id
        end
    end
    return nil
end

function VirtualDataProviderMixin:FindByPredicate(predicate)
    for i = 1, #Experimental.testItems do
        local data = GetTestItem(i)
        if data and predicate(data) then
            return i, data
        end
    end
    return nil
end

function VirtualDataProviderMixin:ContainsIndex(index)
    return index >= 1 and index <= #Experimental.testItems
end

-- Unsupported operations
function VirtualDataProviderMixin:Insert(...)
    error("Insert not supported by virtual data provider")
end

function VirtualDataProviderMixin:Remove(...)
    error("Remove not supported by virtual data provider")
end

function VirtualDataProviderMixin:Sort()
    -- No-op for virtual data
end

local function CreateVirtualDataProvider()
    local dataProvider = CreateFromMixins(VirtualDataProviderMixin)
    dataProvider:Init()
    return dataProvider
end

-------------------------------------------------------------------------
-- UI Element Management

local function InitializeRowFrame(frame)
    if frame.isInitialized then
        return
    end
    
    -- Set proper size
    frame:SetSize(360, 25)
    
    -- Background
    frame.background = frame:CreateTexture(nil, "BACKGROUND")
    frame.background:SetAllPoints()
    
    -- Highlight
    frame.highlight = frame:CreateTexture(nil, "HIGHLIGHT") 
    frame.highlight:SetAllPoints()
    frame.highlight:SetColorTexture(1, 1, 1, 0.1)
    
    -- Text elements
    frame.indexText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.indexText:SetPoint("LEFT", 5, 0)
    frame.indexText:SetSize(40, 20)
    frame.indexText:SetJustifyH("LEFT")
    
    frame.descText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.descText:SetPoint("LEFT", frame.indexText, "RIGHT", 5, 0)
    frame.descText:SetSize(180, 20)
    frame.descText:SetJustifyH("LEFT")
    
    frame.ratingText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.ratingText:SetPoint("LEFT", frame.descText, "RIGHT", 5, 0)
    frame.ratingText:SetSize(60, 20)
    frame.ratingText:SetJustifyH("LEFT")
    
    frame.resultText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.resultText:SetPoint("LEFT", frame.ratingText, "RIGHT", 5, 0)
    frame.resultText:SetSize(40, 20)
    frame.resultText:SetJustifyH("LEFT")
    
    -- Click handler
    frame:SetScript("OnClick", function(self)
        if self.elementData then
            Debug:LogTemp("Clicked item:", self.elementData.id, "Rating:", self.elementData.rating)
        end
    end)
    
    frame.isInitialized = true
end

local function UpdateRowFrame(frame, elementData)
    if not elementData then
        frame:Hide()
        return
    end

    frame:Show();
    
    -- Update text content
    frame.indexText:SetText("#" .. elementData.id)
    frame.descText:SetText(elementData.description)
    frame.ratingText:SetText(tostring(elementData.rating))
    frame.resultText:SetText(elementData.won and "WIN" or "LOSS")
    
    -- Color coding
    if elementData.won then
        frame.resultText:SetTextColor(0.2, 1, 0.2)
    else
        frame.resultText:SetTextColor(1, 0.3, 0.3)
    end
    
    -- Alternate row colors
    if elementData.id % 2 == 0 then
        frame.background:SetColorTexture(0.15, 0.15, 0.2, 0.7)
    else
        frame.background:SetColorTexture(0.2, 0.2, 0.3, 0.7)
    end
    
    frame.elementData = elementData
end

local function ElementInitializer(frame, elementData)
    InitializeRowFrame(frame)
    UpdateRowFrame(frame, elementData)
end

-------------------------------------------------------------------------
-- UI Creation Functions

local function CreateMainFrame()
    local testFrame = CreateFrame("Frame", "OptimizedScrollBoxTest", UIParent, "BackdropTemplate")
    testFrame:SetSize(420, 500)
    testFrame:SetPoint("CENTER", 100, 0)
    testFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    testFrame:SetBackdropColor(0.1, 0.1, 0.15, 0.9)
    testFrame:SetBackdropBorderColor(0.3, 0.3, 0.4, 1)
    
    -- Make it movable
    testFrame:SetMovable(true)
    testFrame:EnableMouse(true)
    testFrame:RegisterForDrag("LeftButton")
    testFrame:SetScript("OnDragStart", testFrame.StartMoving)
    testFrame:SetScript("OnDragStop", testFrame.StopMovingOrSizing)
    
    return testFrame
end

local function CreateFrameHeader(parent)
    -- Title
    Experimental.titleFrame = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    Experimental.titleFrame:SetPoint("TOP", 0, -15)
    Experimental.titleFrame:SetText("Virtual ScrollBox Test - " .. #Experimental.testItems .. " Items")
    Experimental.titleFrame:SetTextColor(1, 0.47, 0.8)
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        parent:Hide()
    end)
    
    return Experimental.titleFrame, closeButton
end

local function CreateControlButtons(parent, dataProvider, scrollBox)
    local controlsFrame = CreateFrame("Frame", nil, parent)
    controlsFrame:SetPoint("TOPLEFT", 10, -40)
    controlsFrame:SetPoint("TOPRIGHT", -10, -40)
    controlsFrame:SetHeight(60) -- Increased height for two rows
    
    local function UpdateScrollBox()
        scrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
        Experimental.titleFrame:SetText("Virtual ScrollBox Test - " .. #Experimental.testItems .. " Items")
    end
    
    local function CreateAddButton(text, amount, x, y)
        local button = CreateFrame("Button", nil, controlsFrame, "UIPanelButtonTemplate")
        button:SetSize(50, 25)
        button:SetPoint("TOPLEFT", x, y)
        button:SetText(text)
        button:SetScript("OnClick", function()
            for i = 1, amount do
                CreateNewTestItem()
            end
            UpdateScrollBox()
            Debug:LogTemp("Added " .. amount .. " items. Total: " .. #Experimental.testItems)
        end)
        return button
    end
    
    -- First row of buttons
    CreateAddButton("1", 1, 5, -5)
    CreateAddButton("5", 5, 60, -5)
    CreateAddButton("10", 10, 115, -5)
    CreateAddButton("100", 100, 170, -5)
    CreateAddButton("1k", 1000, 225, -5)
    CreateAddButton("10k", 10000, 280, -5)
    CreateAddButton("100k", 100000, 335, -5)
    
    -- Reset button on second row
    local resetButton = CreateFrame("Button", nil, controlsFrame, "UIPanelButtonTemplate")
    resetButton:SetSize(80, 25)
    resetButton:SetPoint("TOPLEFT", 5, -35)
    resetButton:SetText("Reset")
    resetButton:SetScript("OnClick", function()
        Experimental.testItems = {}
        InitializeTestItems()
        UpdateScrollBox()
        Debug:LogTemp("Reset to " .. #Experimental.testItems .. " items")
    end)
    
    return controlsFrame
end

local function CreateScrollBox(parent)
    -- ScrollBox 
    local scrollBox = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", 15, -110) -- Adjusted for larger controls area
    scrollBox:SetPoint("BOTTOMRIGHT", -35, 15)
    
    -- ScrollBar
    local scrollBar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 5, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 5, 0)
    
    return scrollBox, scrollBar
end

local function SetupScrollBoxView(scrollBox, scrollBar, dataProvider)
    -- Create view
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(25)
    view:SetElementInitializer("Button", ElementInitializer)
    
    -- Connect everything
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    scrollBox:SetDataProvider(dataProvider)
    
    return view
end

-------------------------------------------------------------------------
-- Main Interface

function Experimental:CreateFrame()
    -- Initialize test data
    InitializeTestItems()
    
    -- Create components
    local testFrame = CreateMainFrame()
    local title, closeButton = CreateFrameHeader(testFrame)
    local scrollBox, scrollBar = CreateScrollBox(testFrame)
    local dataProvider = CreateVirtualDataProvider()
    local view = SetupScrollBoxView(scrollBox, scrollBar, dataProvider)
    local controlsFrame = CreateControlButtons(testFrame, dataProvider, scrollBox)
    
    -- Initialize with data
    scrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
    
    -- Store references
    self.testFrame = testFrame
    self.testScrollBox = scrollBox
    self.testDataProvider = dataProvider
    
    Debug:LogTemp("ScrollBox created with " .. #Experimental.testItems .. " items")
    
    return testFrame
end

function Experimental:Toggle()
    if not self.testFrame then
        self:CreateFrame()
        self.testFrame:Show()
        Debug:LogTemp("Virtual ScrollBox test created and shown")
    else
        if self.testFrame:IsShown() then
            self.testFrame:Hide()
            Debug:LogTemp("Test frame hidden")
        else
            self.testFrame:Show()
            Debug:LogTemp("Test frame shown")
        end
    end
end

function Experimental:SimulateFilterChange()
    if not self.testDataProvider then
        Debug:LogTemp("No test frame created yet")
        return
    end
    
    local newCount = math.max(10, math.floor(#Experimental.testItems * 0.6))
    -- Simulate filtering by truncating the array
    local originalCount = #Experimental.testItems
    for i = originalCount, newCount + 1, -1 do
        table.remove(Experimental.testItems, i)
    end
    
    self.testScrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
    Experimental.titleFrame:SetText("Virtual ScrollBox Test - " .. #Experimental.testItems .. " Items")
    
    Debug:LogTemp("Simulated filter - showing " .. #Experimental.testItems .. " items")
end

function Experimental:CheckMemory()
    collectgarbage("collect")
    local mem = collectgarbage("count")
    Debug:LogTemp("Current memory usage: " .. string.format("%.2f", mem) .. " KB")
    Debug:LogTemp("Test items count: " .. #Experimental.testItems .. " items")
end

Debug:LogTemp("Virtual scrollframe loaded. Use :Toggle() to test.")