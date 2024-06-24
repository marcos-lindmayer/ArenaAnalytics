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

local function SetupScrollbar(dropdown)
    -- Modern scrollbar visuals are handled by UIPanelScrollBarTemplate
    local scrollbar = dropdown.list.ScrollBar;
    scrollbar:SetWidth(16); -- Adjust width as needed
    scrollbar:ClearAllPoints();
    scrollbar:SetPoint("TOPLEFT", dropdown.list, "TOPRIGHT", -4, 3);
    scrollbar:SetPoint("BOTTOMLEFT", dropdown.list, "BOTTOMRIGHT", -4, -3);

    local function UpdateScrollRange()
        local viewHeight = dropdown.list:GetHeight()
        local contentHeight = dropdown.list.content:GetHeight();
        local maxScroll = max(contentHeight - viewHeight, 0)

        dropdown.list:UpdateScrollChildRect()
        dropdown.list:SetVerticalScroll(0)
        scrollbar:SetMinMaxValues(0, maxScroll)
        scrollbar:SetValue(0)
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
    
    if (info.tooltip ~= "") then
        -- Comp filter (Has icons)
        button:SetAttribute("tooltip", info.tooltip);
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
        ArenaAnalytics.Filter:changeFilter(dropdown, info.text, info.tooltip);
    end);

    return button;
end

-- TODO: Refactor this mess!
-- Returns a dropdown frame
-- Used for match filters
function Dropdown:Create(opts)
    local filterName = opts["name"];
    local dropdownName = baseName .. "_".. opts["name"];
    local entries = opts["entries"] or {};
    local isCompDropdown = opts["hasCompIcons"];
    local titleText = opts["title"] or "";
    local dropdownWidth = (filterName == "Filter_Comp" or filterName == "Filter_EnemyComp") and 265 or 1;
    local defaultValue = opts["defaultValue"] or "";

    local dropdown = CreateFrame("Frame", dropdownName, ArenaAnalyticsScrollFrame);
    dropdown:SetSize(dropdownWidth, defaultEntryHeight);

    dropdown.list = CreateFrame("ScrollFrame", dropdownName .. "_list", dropdown, "UIPanelScrollFrameTemplate");
    dropdown.list:SetPoint("TOP", dropdown, "BOTTOM");
    dropdown.list:SetSize(dropdownWidth, maxEntriesToShow * defaultEntryHeight);
    dropdown.list:SetClipsChildren(true); -- Ensure content clipping
    dropdown.list.scrollBarHideable = true; -- Make scrollbar hideable when not needed
    dropdown.list.content = CreateFrame("Frame", dropdownName .. "_content", dropdown.list);
    dropdown.list.content:SetSize(dropdownWidth, (#entries * defaultEntryHeight));
    dropdown.list.content:SetPoint("TOP", dropdown.list)

    dropdown.list:SetScrollChild(dropdown.list.content);
    dropdown.list:SetFrameStrata("HIGH");
    
    dropdown.title = dropdown:CreateFontString(nil, "OVERLAY")
    dropdown.title:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    dropdown.title:SetPoint("TOPLEFT", 0, 15)
    dropdown.title:SetText(titleText);

    isEnemyComp, _ = string.find(opts["name"]:lower(), "enemy")

    dropdown.filterName = filterName;

    dropdown.entries = {}
    
    for i, entry in ipairs(entries) do 
        local text = entry["comp"] or entry;

        local text_width = dropdown.title:GetStringWidth() + 50
        if (text_width > dropdownWidth and filterName ~= "Filter_Comp" and filterName ~= "Filter_EnemyComp") then
            dropdownWidth = text_width
        end

        local info = {}
        info.text = text;
        info.tooltip = "";
        local winrate = nil;
        local totalPlayed = nil;
        
        if(isCompDropdown) then
            if(info.text ~= "All") then
                info.tooltip = entry["comp"];
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
                info.tooltip = "All";
            end
        end
        
        info.buttonName = dropdownName .. "_Entry" .. i;
        info.index = i;
        local newEntry = createDropdownButton(info, dropdown, titleText, dropdownWidth);
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

    dropdown.list:SetSize(dropdownWidth, (maxEntriesToShow * 25));
    dropdown:SetWidth(dropdownWidth)
    
    local totalHeight = 0;
    for i = 1, #dropdown.entries do
        local entry = dropdown.entries[i];
        totalHeight = totalHeight + entry:GetHeight();
        entry:SetPoint("TOPLEFT", 0, -(i - 1) * entry:GetHeight())
        entry:SetWidth(dropdownWidth)
    end
    
    local dropdownBg = dropdown:CreateTexture();
    dropdownBg:SetPoint("CENTER")
    dropdownBg:SetSize(dropdownWidth, defaultEntryHeight);
    dropdownBg:SetColorTexture(0, 0, 0, 0.5);
    
    dropdown.background = dropdown.list:CreateTexture();
    dropdown.background:SetPoint("TOP", dropdown.list)
    dropdown.background:SetSize(dropdownWidth, totalHeight);
    dropdown.background:SetColorTexture(0, 0, 0, 0.5);

    dropdown.list.content:SetHeight(totalHeight);

    dropdown.selected = CreateButton(dropdownName .. "_selected", dropdown, nil, dropdownWidth, defaultEntryHeight, defaultValue);
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
    ArenaAnalytics.Filter:SetFilter(filter, text);
        
    dropdown.selected:SetText(info.comp);

    if(dropdown.list:IsShown()) then
        dropdown.list:Hide();
    end
end

local function SortDropdownEntries(entries, isPlayerPriority)
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
    info.display = ArenaAnalytics.AAtable:getCompIconString(entry["comp"], isPlayerPriority);
    
    -- Setup string values (Prefix and suffix for total played and winrate)
    local played = entry["played"] or 0;
    local wins = entry["wins"] or 0;
    local winrate = (played > 0) and math.floor(wins * 100 / played) or 0;
    
    local prefix = played .. " ";
    local suffix = " - " .. winrate .. "%";

    -- Complete display string including icons
    info.display = prefix .. info.display .. suffix; -- TODO: Consider custom icon management setup?
    info.textOffsetX = ComputeStringOffset(dropdown, prefix, suffix);

    local button = CreateButton(frameName, dropdown, dropdown.list.content, width, height, "");
    button.text = ArenaAnalyticsCreateText(button, "CENTER", button, "CENTER", info.textOffsetX, 0, info.text);

    button:SetScript("OnClick", function(args)
        HandleClick(dropdown, info.comp, info.display);
    end);

    return button;
end

function Dropdown:Create_Test(filter, entries, defaultValue, title, width, entryHeight)
    -- Selected (main) button for this dropdown
    local dropdownName = baseName .. "_".. filter;
    dropdown.selected = CreateButton(dropdownName .. "_selected", dropdown, nil, width, entryHeight, defaultValue);
    dropdown.selected:SetPoint("CENTER");
end

-- Create the dropdown frame
function Dropdown:Create_Simplified(filter, entries, defaultValue, title, width, entryHeight)
    assert(filter);

    ArenaAnalytics:Log("Create_Simplified(",filter, entries, defaultValue, title, width, entryHeight,")")

    entries = entries or {}
    defaultValue = defaultValue or "Missing Default"
    width = width and max(width, 1) or 1; -- At least 1, to avoid content is considered visible
    entryHeight = entryHeight or defaultEntryHeight;

    local dropdownName = baseName .. "_".. filter;
    local isCompDropdown = (entries["comp"] ~= nil);
    local prioritizePlayerSpec = (filter == "Filter_Comp");

    -- Setup main dropdown frame
    local dropdown = CreateFrame("Frame", dropdownName, ArenaAnalyticsScrollFrame);
    dropdown:SetWidth(width);

    -- Setup dropdown list
    dropdown.list = CreateFrame("ScrollFrame", dropdownName .. "_list", dropdown, "UIPanelScrollFrameTemplate");
    dropdown.list:SetPoint("TOP", dropdown, "BOTTOM");
    dropdown.list:SetFrameStrata("HIGH");
    dropdown.list:SetClipsChildren(false); -- Ensure content clipping
    dropdown.list.scrollBarHideable = true; -- Make scrollbar hideable when not needed
    dropdown.list:SetSize(width, entryHeight * maxEntriesToShow);
    
    -- Setup list content
    dropdown.list.content = CreateFrame("Frame", dropdownName .. "_content", dropdown.list);
    dropdown.list.content:SetPoint("TOP", dropdown.list);
    dropdown.list:SetScrollChild(dropdown.list.content);
    dropdown.list.content:SetSize(width, entryHeight * #entries);

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

    ArenaAnalytics:Log(#entries)

    -- Create Entry Frames
    local accumulatedHeight = 0;
    for i, entry in ipairs(entries) do 
        local text = entry["comp"] or entry;

        local entryFrameName = dropdownName .. "_Entry" .. i;

        local newEntry = nil
        if isCompDropdown then
            newEntry = CreateCompEntryButton(entryFrameName, dropdown, filter, width, entryHeight, entry, prioritizePlayerSpec);
        else
            ArenaAnalytics:Log(entryFrameName, dropdown, filter, width, entryHeight, text)
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
    dropdown.list.background:SetPoint("TOP", dropdown.list)
    dropdown.list.background:SetSize(width, accumulatedHeight);
    dropdown.list.background:SetColorTexture(0, 0, 0, 0.7);

    dropdown.reset = function(self)
        HandleClick(self, defaultValue);
    end

    SetupScrollbar(dropdown);
    
    dropdown.list:Hide();

    dropdown:Show()
    dropdown.list:Show()
    dropdown.selected:Show()
    for _, entry in ipairs(dropdown.entries) do
        entry:Show()
    end

    local totalHeight = 0;
    for i = 1, #dropdown.entries do
        local entry = dropdown.entries[i];
        totalHeight = totalHeight + entry:GetHeight();
        entry:SetPoint("TOPLEFT", 0, -(i - 1) * entry:GetHeight())
        entry:SetWidth(width)
    end

    return dropdown;
end

