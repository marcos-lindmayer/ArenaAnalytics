-- Namespace for managing versions, including backwards compatibility and converting data
local _, ArenaAnalytics = ...;
ArenaAnalytics.Dropdown = {};
local Dropdown = ArenaAnalytics.Dropdown;

local baseName = "ArenaScrollableDropdown"

local defaultEntryHeight = 25;
local maxEntriesToShow = 15;

local function CreateButton(frameName, dropdown, parent, width, height, text)
    local button = CreateFrame("Button", frameName, (parent or dropdown), "UIServiceButtonTemplate")
    button.money:Hide();
    button:SetPoint("CENTER", parent or dropdown)
    button:SetSize(width, height)
    button:SetText(text);
    button:SetNormalFontObject("GameFontHighlight");
    button:SetHighlightFontObject("GameFontHighlight");
    button:SetDisabledFontObject("GameFontDisableSmall");
    button:SetAttribute("dropdown", dropdown);
    return button;
end

local function SetupScrollbar(dropdown, accumulatedHeight)
    -- Modern scrollbar visuals are handled by UIPanelScrollBarTemplate
    local scrollbar = dropdown.list.ScrollBar;
    scrollbar:SetWidth(16); -- Adjust width as needed
    scrollbar:ClearAllPoints();
    scrollbar:SetPoint("TOPLEFT", dropdown.list, "TOPRIGHT", -5, 3);
    scrollbar:SetPoint("BOTTOMLEFT", dropdown.list, "BOTTOMRIGHT", -5, -3);

    -- Hide the scroll up and down buttons
    if scrollbar.ScrollUpButton then
        scrollbar.ScrollUpButton:Hide();
        scrollbar.ScrollUpButton:SetAlpha(0);
    end
    if scrollbar.ScrollDownButton then
        scrollbar.ScrollDownButton:Hide();
        scrollbar.ScrollDownButton:SetAlpha(0);
    end

    local function UpdateScrollRange()
        local viewHeight = dropdown.list:GetHeight()
        local contentHeight = dropdown.list.content:GetHeight();
        local maxScroll = math.max(accumulatedHeight - viewHeight, 0)
        
        dropdown.list:UpdateScrollChildRect()
        dropdown.list:SetVerticalScroll(0)
        scrollbar:SetValue(0)
        scrollbar:SetMinMaxValues(0, maxScroll)
    end

    dropdown.list:HookScript("OnShow", UpdateScrollRange)
    dropdown.list:HookScript("OnSizeChanged", UpdateScrollRange)
    UpdateScrollRange()
end

-- Returns buttons for filter lists
local function createDropdownButton(info, dropdown, title, width)
    local parent = dropdown.list.content;
    local button = CreateFrame("Button", info.buttonName, parent, "UIServiceButtonTemplate");
    button.money:Hide();
    button:SetSize(width, defaultEntryHeight);
    button:SetPoint("CENTER");
    button:SetNormalFontObject("GameFontHighlight");
    button:SetHighlightFontObject("GameFontHighlight");
    button:SetAttribute("dropdown", dropdown);
    button:Show();
    button:SetFrameStrata("HIGH")
    
    if (info.display ~= "") then
        -- Comp filter (Has icons)
        button:SetHeight(27)
        if(info.text == "All" or info.textOffsetX == nil) then
            button:SetText(info.text);
        else
            button:SetText("");
            button.text = ArenaAnalyticsCreateText(button, "CENTER", button, "CENTER", info.textOffsetX, 0, info.text);
        end    
    else
        button:SetText(info.text);
    end

    button:SetScript("OnClick", function(args) 
        ArenaAnalytics.Filter:changeFilter(dropdown, info.text, info.display);
    end);

    return button;
end

-- TODO: Refactor this mess!
-- Returns a dropdown frame
-- Used for match filters
function Dropdown:Create_OLD(filter, entries, defaultValue, title, width, entryHeight)
    assert(filter);

    entries = entries or {}
    defaultValue = defaultValue or "Missing Default"
    width = width and max(width, 1) or 1; -- At least 1, to avoid content is considered visible
    entryHeight = entryHeight or defaultEntryHeight;

    local dropdownName = baseName .. "_".. filter;
    local isCompDropdown = filter == "Filter_Comp" and filter == "Filter_EnemyComp";
    local prioritizePlayerSpec = (filter == "Filter_Comp");

    local dropdown = CreateFrame("Frame", dropdownName, ArenaAnalyticsScrollFrame);
    dropdown:SetSize(width, defaultEntryHeight);
    dropdown.filter = filter;

    dropdown.list = CreateFrame("ScrollFrame", dropdownName .. "_list", dropdown, "UIPanelScrollFrameTemplate");
    dropdown.list:SetPoint("TOP", dropdown, "BOTTOM");
    dropdown.list:SetSize(width, maxEntriesToShow * defaultEntryHeight);
    dropdown.list:SetClipsChildren(true); -- Ensure content clipping
    dropdown.list.scrollBarHideable = true; -- Make scrollbar hideable when not needed
    dropdown.list.content = CreateFrame("Frame", dropdownName .. "_content", dropdown.list);
    dropdown.list.content:SetSize(width, (#entries * defaultEntryHeight));
    dropdown.list.content:SetPoint("TOP", dropdown.list)

    dropdown.list:SetScrollChild(dropdown.list.content);
    dropdown.list:SetFrameStrata("HIGH");
    
    if (title) then
        dropdown.title = dropdown:CreateFontString(nil, "OVERLAY")
        dropdown.title:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
        dropdown.title:SetPoint("TOPLEFT", 0, 15)
        dropdown.title:SetText(title);
    end

    isEnemyComp, _ = string.find(filter:lower(), "enemy")

    dropdown.entries = {}
    
    for i, entry in ipairs(entries) do 
        local text = entry["comp"] or entry;

        local info = {}
        info.text = text;
        info.display = "";
        local winrate = nil;
        local totalPlayed = nil;
        
        if(isCompDropdown) then
            if(info.text ~= "All") then
                info.display = entry["comp"];
                info.text = ArenaAnalytics.AAtable:getCompIconString(entry["comp"], not isEnemyComp and UnitClass("player") or nil);

                totalPlayed = entry["played"] or 0;
                local wins = entry["wins"] or 0;

                winrate = (totalPlayed > 0) and math.floor(wins * 100 / totalPlayed) or 0
                info.text = totalPlayed .. " " .. info.text .. " - " .. winrate .. "%";

                -- Make a temp font string to calculate width of the left and right added strings.
                local tmpWidthString = dropdown:CreateFontString(nil, "OVERLAY")
                tmpWidthString:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
                tmpWidthString:SetText("- " .. winrate .. "%");
                winrateWidth = tmpWidthString:GetStringWidth();
                tmpWidthString:SetText(totalPlayed);
                totalPlayedWidth = tmpWidthString:GetStringWidth();
                tmpWidthString = nil;

                info.textOffsetX = (winrateWidth - totalPlayedWidth) / 2;
            else
                info.display = "All";
            end
        end
        
        info.buttonName = dropdownName .. "_Entry" .. i;
        info.index = i;
        local newEntry = createDropdownButton(info, dropdown, titleText, width);
        newEntry.winrate = winrate;
        newEntry.totalPlayed = totalPlayed;
        table.insert(dropdown.entries, newEntry);
    end

    -- Order Comp filter by winrate
    if (isCompDropdown and #dropdown.entries) then
        table.sort(dropdown.entries, function(a,b)
            if(a and a:GetText() == "All" or b == nil) then
                return true;
            elseif(b and b:GetText() == "All" or a == nil) then
                return false;
            end

            local sortByTotal = ArenaAnalyticsSettings["sortCompFilterByTotalPlayed"];
            local value1 = tonumber(sortByTotal and a.totalPlayed or a.winrate);
            local value2 = tonumber(sortByTotal and b.totalPlayed or b.winrate);
            if(value1 and value2) then
                return value1 > value2;
            end
            return value1 ~= nil;
        end);

        -- Remove entries with lowest priority past the limit
        local limit = tonumber(ArenaAnalyticsSettings["compsLimit"]);
        if(limit and limit > 0) then
            limit = limit + 2;
            if(#dropdown.entries > limit) then
                for i=#dropdown.entries, limit, -1 do
                    local entry = dropdown.entries[i]
                    if(entry ~= nil) then
                        entry:Hide();
                        entry = nil;
                    end
                    tremove(dropdown.entries, i);
                end
            end
        end
    end

    dropdown.list:SetSize(width, (maxEntriesToShow * 25));
    dropdown:SetWidth(width)
    
    local totalHeight = 0;
    for i = 1, #dropdown.entries do
        local entry = dropdown.entries[i];
        totalHeight = totalHeight + entry:GetHeight();
        entry:SetPoint("TOPLEFT", 0, -(i - 1) * entry:GetHeight())
        entry:SetWidth(width)
    end

    local dropdownBg = dropdown:CreateTexture();
    dropdownBg:SetPoint("CENTER")
    dropdownBg:SetSize(width, defaultEntryHeight);
    dropdownBg:SetColorTexture(0.2, 0.2, 0.2, 0.5);
    
    dropdown.background = dropdown.list:CreateTexture();
    dropdown.background:SetPoint("TOP", dropdown.list)
    dropdown.background:SetSize(width, totalHeight);
    dropdown.background:SetColorTexture(0.2, 0.2, 0.2, 0.5);

    dropdown.list.content:SetHeight(totalHeight);

    dropdown.selected = CreateButton(dropdownName .. "_selected", dropdown, nil, width, defaultEntryHeight, defaultValue);
    dropdown.selected:SetPoint("CENTER");

    dropdown.selected:SetScript("OnClick", function (args)
        local dropdownList = args:GetAttribute("dropdown").list
        if (dropdownList:IsShown()) then
            dropdownList:Hide();
        else
            ArenaAnalytics.AAtable:closeFilterDropdowns();
            dropdownList:Show();
        end
    end);

    dropdown.reset = function(self)
        ArenaAnalytics.Filter:changeFilter(dropdown, defaultValue);
    end

    SetupScrollbar(dropdown);
    
    dropdown.list:Hide();

    return dropdown;
end






-----------------------------------------------------------------
-----------------------------------------------------------------
-----------------------------------------------------------------
-- Test function for simplified basic dropdown at center of the screen

-- Usage example:
local testEntries = { "All" }
for i = 1, 100 do
    table.insert(testEntries, "Entry " .. i);
end

local function HandleClick(dropdown, value, display)
    ArenaAnalytics.Filter:SetFilter(dropdown.filter, value, display);
        
    dropdown.selected:SetText(display or value);

    if(dropdown.list:IsShown()) then
        dropdown.list:Hide();
    end
end

local function SortDropdownEntries(entries, isPlayerPriority)
    table.sort(entries, function(a,b)
        if(a and a["comp"] == "All" or b == nil) then
            return true;
        elseif(b and b["comp"] == "All" or a == nil) then
            return false;
        end

        local sortByTotal = ArenaAnalyticsSettings["sortCompFilterByTotalPlayed"];
        local value1 = tonumber(sortByTotal and (a["played"] or 0) or (a["winrate"] or 0));
        local value2 = tonumber(sortByTotal and (b["played"] or 0) or (b["winrate"] or 0));
        if(value1 and value2) then
            return value1 > value2;
        end
        return value1 ~= nil;
    end);
end

local function ApplyEntryLimit(entries)
    -- Remove entries with lowest priority past the limit
    local limit = tonumber(ArenaAnalyticsSettings["compsLimit"]);
    if(limit and limit > 0) then
        limit = limit + 2;
        if(#entries > limit) then
            for i=#entries, limit, -1 do
                local entry = entries[i]
                if(entry ~= nil) then
                    entry = nil;
                end
                tremove(entries, i);
            end
        end
    end
end

-- Compute the offset required given strings left and right of center
local function ComputeStringOffset(dropdown, leftString, rightString)
    -- Make a temp font string to calculate width of the left and right added strings.
    local tmpWidthString = dropdown:CreateFontString(nil, "OVERLAY")
    tmpWidthString:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    tmpWidthString:SetText(leftString);
    leftWidth = tmpWidthString:GetStringWidth();
    tmpWidthString:SetText(rightString);
    rightWidth = tmpWidthString:GetStringWidth();
    tmpWidthString = nil; -- Clear temp FontString

    return (rightWidth - leftWidth) / 2;
end

local function CreateSimpleEntryButton(frameName, dropdown, filter, width, height, text)
    local button = CreateButton(frameName, dropdown, dropdown.list.content, width, height, text);

    button:SetScript("OnClick", function(args)
        HandleClick(dropdown, text);
    end);

    return button;
end

local function CreateCompEntryButton(frameName, dropdown, filter, width, height, entry, isPlayerPriority)
    local comp = entry["comp"]

    -- Skip complex setup when entry has no icons
    if(comp == "All") then
        return CreateSimpleEntryButton(frameName, dropdown, filter, width, height, "All");
    end
    
    local info = {}
    info.comp = comp;
    info.display = ArenaAnalytics.AAtable:getCompIconString(comp, isPlayerPriority);
    
    -- Setup string values (Prefix and suffix for total played and winrate)
    local played = entry["played"] or 0;
    local wins = entry["wins"] or 0;
    local winrate = entry["winrate"] or 0;
    
    local playedPrefix = played .. " ";
    local winrateSuffix = " - " .. winrate .. "%";

    -- Complete display string including icons
    info.display = playedPrefix .. (info.display or "") .. winrateSuffix; -- TODO: Consider custom icon management setup?
    info.textOffsetX = ComputeStringOffset(dropdown, playedPrefix, winrateSuffix);

    local button = CreateButton(frameName, dropdown, dropdown.list.content, width, height, "");
    button.text = ArenaAnalyticsCreateText(button, "CENTER", button, "CENTER", info.textOffsetX, 0, info.display);
    button:SetHeight(27)

    button:SetScript("OnClick", function(args)
        HandleClick(dropdown, info.comp, info.display);
    end);

    return button;
end

-- TEMP
function Dropdown:DebugScrollState(dropdown)
    if dropdown == nil or ArenaAnalytics.skipDebugLog then return end
    local scrollFrame, scrollbar = dropdown.list, dropdown.list.ScrollBar;

    -- Print ScrollFrame information
    print("=== ScrollFrame Information ===");
    print("ScrollFrame Name:", scrollFrame:GetName());
    print("ScrollFrame Size:", scrollFrame:GetSize());
    print("ScrollFrame ScrollChild Size:", scrollFrame:GetScrollChild():GetSize());
    print("ScrollFrame ScrollOffsets (x, y):", scrollFrame:GetHorizontalScroll(), scrollFrame:GetVerticalScroll());
    print("ScrollFrame Min Scroll:", scrollFrame.minScroll);
    print("ScrollFrame Max Scroll:", scrollFrame.maxScroll);

    -- Print ScrollBar information
    print("=== ScrollBar Information ===");
    print("ScrollBar Name:", scrollbar:GetName());
    print("ScrollBar Size:", scrollbar:GetSize());
    print("ScrollBar Orientation:", scrollbar:GetOrientation());
    print("ScrollBar Min/Max Values:", scrollbar:GetMinMaxValues());
    print("ScrollBar Current Value:", scrollbar:GetValue());
end

-- Create the dropdown frame
function Dropdown:Create(filter, entries, defaultValue, title, width, entryHeight)
    assert(filter);

    entries = entries or {}
    defaultValue = defaultValue or "Missing Default"
    width = width and max(width, 1) or 1; -- At least 1, to avoid content is considered visible
    entryHeight = entryHeight or defaultEntryHeight;

    local dropdownName = baseName .. "_".. filter;
    local isCompDropdown = filter == "Filter_Comp" or filter == "Filter_EnemyComp";
    local prioritizePlayerSpec = (filter == "Filter_Comp");

    -- Setup main dropdown frame
    local dropdown = CreateFrame("Frame", dropdownName, ArenaAnalyticsScrollFrame);
    dropdown:SetSize(width, entryHeight);
    dropdown.filter = filter;

    -- Setup dropdown list
    dropdown.list = CreateFrame("ScrollFrame", dropdownName .. "_List", dropdown, "UIPanelScrollFrameTemplate");
    dropdown.list:SetPoint("TOP", dropdown, "BOTTOM");
    dropdown.list:SetFrameStrata("HIGH");
    dropdown.list:SetClipsChildren(true); -- Ensure content clipping
    dropdown.list.scrollBarHideable = true; -- Make scrollbar hideable when not needed
    dropdown.list:SetSize(width, entryHeight * maxEntriesToShow);
    
    -- Setup list content
    dropdown.list.content = CreateFrame("Frame", dropdownName .. "_content", dropdown.list);
    dropdown.list.content:SetPoint("TOP", dropdown.list);
    dropdown.list:SetScrollChild(dropdown.list.content);
    dropdown.list.content:SetSize(width, entryHeight * #entries);
    ArenaAnalytics:Print(#entries)

    -- Setup Title (Optional)
    if title then
        dropdown.title = dropdown:CreateFontString(nil, "OVERLAY");
        dropdown.title:SetFont("Fonts\\FRIZQT__.TTF", 12, "");
        dropdown.title:SetPoint("TOPLEFT", 0, 15);
        dropdown.title:SetText(title);
    end

    -- Apply settings for comp filters
    if(isCompDropdown) then
        SortDropdownEntries(entries, prioritizePlayerSpec);
        ApplyEntryLimit(entries);
    end

    dropdown.entries = {}

    -- Create Entry Frames
    local accumulatedHeight = 0;
    for i, entry in ipairs(entries) do 
        local text = entry["comp"] or entry;

        local entryFrameName = dropdownName .. "_Entry" .. i;

        local newEntry = nil
        if isCompDropdown then
            newEntry = CreateCompEntryButton(entryFrameName, dropdown, filter, width, entryHeight, entry, prioritizePlayerSpec);
        else
            newEntry = CreateSimpleEntryButton(entryFrameName, dropdown, filter, width, entryHeight, text);
        end

        newEntry:SetPoint("TOPLEFT", 0, -accumulatedHeight);
        accumulatedHeight = accumulatedHeight + newEntry:GetHeight();

        table.insert(dropdown.entries, newEntry);
    end

    -- Update the content height to be precise
    dropdown.list.content:SetHeight(accumulatedHeight);

    -- Selected (main) button for this dropdown
    dropdown.selected = CreateButton(dropdownName .. "_selected", dropdown, nil, width, entryHeight, defaultValue);
    dropdown.selected:SetPoint("CENTER");
    
    dropdown.selected:SetScript("OnClick", function (args)
        local dropdownList = args:GetAttribute("dropdown").list
        if (dropdownList:IsShown()) then
            dropdownList:Hide();
        else
            ArenaAnalytics.AAtable:closeFilterDropdowns();
            dropdownList:Show();
        end
    end);

    -- Setup backgrounds
    dropdown.selected.selectedBackground = dropdown.selected:CreateTexture();
    dropdown.selected.selectedBackground:SetPoint("CENTER")
    dropdown.selected.selectedBackground:SetSize(width, entryHeight);
    dropdown.selected.selectedBackground:SetColorTexture(0, 0, 0, 0.7);
    
    dropdown.list.background = dropdown.list:CreateTexture();
    dropdown.list.background:SetPoint("TOP", dropdown.list.content)
    dropdown.list.background:SetSize(width, dropdown.list.content:GetHeight());
    dropdown.list.background:SetColorTexture(0, 0, 0, 0.95);

    SetupScrollbar(dropdown, accumulatedHeight);

    Dropdown:DebugScrollState(dropdown)
    
    dropdown.list:Hide();

    local totalHeight = 0;
    for i = 1, #dropdown.entries do
        local entry = dropdown.entries[i];
        totalHeight = totalHeight + entry:GetHeight();
        entry:SetPoint("TOPLEFT", 0, -(i - 1) * entry:GetHeight())
        entry:SetWidth(width)
    end

    -- Functions
    dropdown.Reset = function(self)
        HandleClick(self, defaultValue);
    end

    return dropdown;
end