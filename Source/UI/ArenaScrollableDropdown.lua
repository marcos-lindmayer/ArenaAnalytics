local _, ArenaAnalytics = ...; -- Addon Namespace
local Dropdown = ArenaAnalytics.Dropdown;

-- Local module aliases
local Options = ArenaAnalytics.Options;
local Filter = ArenaAnalytics.Filters;

-------------------------------------------------------------------------

local baseName = "ArenaScrollableDropdown";
local defaultEntryHeight = 25;

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
    scrollbar:ClearAllPoints();
    scrollbar:SetPoint("TOPLEFT", dropdown.list, "TOPRIGHT", -5, 3);
    scrollbar:SetPoint("BOTTOMLEFT", dropdown.list, "BOTTOMRIGHT", -5, -3);

    -- Workaround for scrollbar not hiding automatically
    local viewHeight = dropdown.list:GetHeight()
    local contentHeight = dropdown.list.content:GetHeight();
    if (viewHeight < contentHeight) then
        scrollbar.ScrollUpButton:SetAlpha(1);
        scrollbar:SetWidth(16); -- Adjust width as needed
    else
        scrollbar.ScrollUpButton:SetAlpha(0);
        scrollbar:SetWidth(0);
    end

    -- Hide the scroll up and down buttons
    if scrollbar.ScrollUpButton then
        scrollbar.ScrollUpButton:Hide();
        scrollbar.ScrollUpButton:SetAlpha(0);
    end
    if scrollbar.ScrollDownButton then
        scrollbar.ScrollDownButton:Hide();
        scrollbar.ScrollDownButton:SetAlpha(0);
    end
end

-- Compute the offset required given strings left and right of center
local function ComputeStringOffset(leftString, rightString)
    -- Make a temp font string to calculate width of the left and right added strings.
    local tmpWidthString = ArenaAnalyticsScrollFrame:CreateFontString(nil, "OVERLAY")
    tmpWidthString:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    tmpWidthString:SetText(leftString);
    leftWidth = tmpWidthString:GetStringWidth();
    tmpWidthString:SetText(rightString);
    rightWidth = tmpWidthString:GetStringWidth();
    tmpWidthString = nil; -- Clear temp FontString

    return (rightWidth - leftWidth) / 2;
end

-- Form a comp string for the given comp entry
-- optionally adjusting by options for current selected text
local function GetCompDisplayString(compEntry, isPlayerPriority, isSelectedDisplay)
    local comp = compEntry and compEntry["comp"] or nil
    if (comp == nil) then
        return "", 0;
    end

    if(comp == "All") then
        return "All", 0;
    end

    local display = ArenaAnalytics.AAtable:getCompIconString(comp, isPlayerPriority) or "???";

    -- Skip adding stats for selected, if option desires them hidden
    if(isSelectedDisplay and not Options:Get("showSelectedCompStats")) then
        return display, 0, nil;
    end

    -- Setup string values (Prefix and suffix for total played and winrate)
    local played = compEntry["played"] or "|cffff0000" .. "0" .. "|r";
    --local wins = compEntry["wins"] or 0;
    local winrate = compEntry["winrate"];
    local averageMMR = compEntry["mmr"] and "|cffcccccc" .. compEntry["mmr"] .. "|r";
    
    local playedPrefix = played and (played .. "  ") or "|cffff0000" .. "0  " .. "|r";
    local winrateSuffix = winrate and ("  " .. winrate .. "%") or "|cffff0000" .. "  0%" .. "|r";

    -- Complete display string including icons
    display = playedPrefix .. display .. winrateSuffix; -- TODO: Consider custom icon management setup?
    local textOffsetX = ComputeStringOffset(playedPrefix, winrateSuffix);

    if(Options:Get("compDisplayAverageMmr")) then
        textOffsetX = textOffsetX - 12;
    end

    return display, textOffsetX, averageMMR;
end

local function AddAverageMMR(frame, mmr)
    assert(frame);

    if(Options:Get("compDisplayAverageMmr") and mmr) then
        frame.mmrText = ArenaAnalyticsCreateText(frame, "RIGHT", frame, "RIGHT", -5, -1.25, mmr, 9);
    else
        frame.mmrText = nil;
    end
end

local function HandleClick(dropdown, value, display)
    Filter:SetFilter(dropdown.filter, value, display);
    
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

        local sortByTotal = Options:Get("sortCompFilterByTotalPlayed");
        local value1 = tonumber(sortByTotal and (a["played"] or 0) or (a["winrate"] or 0));
        local value2 = tonumber(sortByTotal and (b["played"] or 0) or (b["winrate"] or 0));
        if(value1 and value2) then
            return value1 > value2;
        end
        return value1 ~= nil;
    end);
end

local function RemoveEntriesByOptions(entries)
    local outlierLimit = tonumber(Options:Get("outliers")) or 0
    if(outlierLimit > 0) then
        -- Filter out comps by too few matches
        for i=#entries, 1, -1 do
            local compTable = entries[i];
            if(compTable and compTable["comp"] ~= "All" and compTable["played"] < outlierLimit) then
                tremove(entries, i);
                i = i - 1;
            end
        end
    end
end

local function SetSelectedText(selectedFrame, entry, isPlayerPriority, filter)
    local display, offsetX, averageMMR = GetCompDisplayString(entry, isPlayerPriority, true);
    local fontSize = (display == "All" and 12 or 11);
    selectedFrame.text = ArenaAnalyticsCreateText(selectedFrame, "CENTER", selectedFrame, "CENTER", offsetX, -1.25, display, fontSize);
    AddAverageMMR(selectedFrame, averageMMR);

    selectedFrame:SetText("");

    Filter:SetDisplay(filter, display);
end

-- TODO: Improve the update logic
-- Updating selected comp text
local function UpdateSelectedCompText(selectedFrame, selectedText, filter, entries, isPlayerPriority)
    if (selectedText ~= nil) then
        return;
    end

    if(#entries > 1) then
        for i, entry in ipairs(entries) do 
            local text = entry["comp"] or entry;

            -- Update the currently displayed entry with new values
            if(text == Filter:GetCurrentData(filter)) then
                SetSelectedText(selectedFrame, entry, isPlayerPriority, filter);
                return;
            end            
        end
    end

    -- No entries contained data for selected comp with current filters
    if(Filter:GetCurrentData(filter) ~= "All" ) then
        local lastFilter = {["comp"] = Filter:GetCurrentData(filter)};
        SetSelectedText(selectedFrame, lastFilter, isPlayerPriority, filter);
        return;
    end

    local text = Filter:GetCurrentDisplay(filter);
    ArenaAnalytics:Log("Current Display: ", text)
    selectedFrame:SetText(text);
    selectedFrame.text = nil;
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
    height = 27;

    -- Skip complex setup when entry has no icons
    if(comp == "All") then
        return CreateSimpleEntryButton(frameName, dropdown, filter, width, height, "All");
    end
    
    local info = {}
    info.comp = comp;
    info.display, info.textOffsetX, averageMMR = GetCompDisplayString(entry, isPlayerPriority);

    local button = CreateButton(frameName, dropdown, dropdown.list.content, width, height, "");
    button.text = ArenaAnalyticsCreateText(button, "CENTER", button, "CENTER", info.textOffsetX, -1.25, info.display, 11);
    AddAverageMMR(button, averageMMR);

    button:SetScript("OnClick", function(args)
        HandleClick(dropdown, info.comp, info.display);
    end);

    return button;
end

-- Create the dropdown frame
function Dropdown:Create(filter, entries, selectedText, title, width, entryHeight)
    assert(filter);

    entries = entries or {}

    width = width and max(width, 1) or 1; -- At least 1, to avoid content is considered visible
    entryHeight = entryHeight or defaultEntryHeight;

    local dropdownName = baseName .. "_".. filter;
    local isCompDropdown = filter == "Filter_Comp" or filter == "Filter_EnemyComp";
    local isPlayerPriority = (filter == "Filter_Comp");
    local maxVisibleEntries = isCompDropdown and Options:Get("dropdownVisibileLimit") or 10;

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
    dropdown.list:SetSize(width, entryHeight * maxVisibleEntries);
    
    -- Update scrollbar max
	dropdown.list:SetScript("OnScrollRangeChanged", function(scrollFrame)
        local viewHeight = scrollFrame:GetHeight()
        local contentHeight = scrollFrame.content:GetHeight();
        local maxScroll = math.max(contentHeight - viewHeight, 0)
        
        scrollFrame:UpdateScrollChildRect()
        scrollFrame.ScrollBar:SetMinMaxValues(0, maxScroll)
    end);

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

        if(isCompDropdown) then
            dropdown.title.details = dropdown:CreateFontString(nil, "OVERLAY");
            dropdown.title.details:SetFont("Fonts\\FRIZQT__.TTF", 8.25, "");
            dropdown.title.details:SetPoint("TOPRIGHT", -4, 13);

            local details = Options:Get("compDisplayAverageMmr") and "Games || Comp || Winrate || mmr" or "Games || Comp || Winrate"
            dropdown.title.details:SetText(details);

            if(Options:Get("showCompDropdownInfoText")) then
                dropdown.title.details:Show();
            else
                dropdown.title.details:Hide();
            end
        end
    end

    -- Selected (main) button for this dropdown
    dropdown.selected = CreateButton(dropdownName .. "_selected", dropdown, nil, width, entryHeight, (selectedText or ""));
    dropdown.selected:SetPoint("CENTER");
    dropdown.selected:RegisterForClicks("LeftButtonDown", "RightButtonDown");
    dropdown.selected:SetScript("OnClick", function (frame, btn)
        if(btn == "RightButton") then
            -- Clear all filters related to this
            Filter:ResetToDefault(filter, true);
            dropdown.selected:SetText(Filter:GetCurrentDisplay(filter));
            ArenaAnalytics.AAtable:closeFilterDropdowns();
        else
            local dropdown = frame:GetAttribute("dropdown")
            if (dropdown.list:IsShown()) then
                dropdown.list:Hide();
            else
                ArenaAnalytics.AAtable:closeFilterDropdowns();
                dropdown:ShowDropdown();
            end
        end
    end);

    -- Apply settings for comp filters
    if(isCompDropdown) then
        SortDropdownEntries(entries, isPlayerPriority);
        RemoveEntriesByOptions(entries);
        UpdateSelectedCompText(dropdown.selected, selectedText, filter, entries, isPlayerPriority);
    end

    dropdown.entries = {}

    -- Create Entry Frames
    local accumulatedHeight = 0;
    for i, entry in ipairs(entries) do 
        local text = entry["comp"] or entry;

        local entryFrameName = dropdownName .. "_Entry" .. i;
        local newEntry = nil
        if isCompDropdown then
            newEntry = CreateCompEntryButton(entryFrameName, dropdown, filter, width, entryHeight, entry, isPlayerPriority);
        else
            newEntry = CreateSimpleEntryButton(entryFrameName, dropdown, filter, width, entryHeight, text);
        end

        accumulatedHeight = accumulatedHeight + newEntry:GetHeight();

        table.insert(dropdown.entries, newEntry);
    end

    -- Update the content height to be precise
    dropdown.list.content:SetHeight(accumulatedHeight);

    -- Setup backgrounds
    dropdown.selected.selectedBackground = dropdown.selected:CreateTexture();
    dropdown.selected.selectedBackground:SetPoint("CENTER")
    dropdown.selected.selectedBackground:SetSize(width, entryHeight);
    dropdown.selected.selectedBackground:SetColorTexture(0, 0, 0, 0.7);
    
    dropdown.list.background = dropdown.list:CreateTexture();
    dropdown.list.background:SetPoint("TOP", dropdown.list.content)
    dropdown.list.background:SetSize(width, dropdown.list.content:GetHeight());
    dropdown.list.background:SetColorTexture(0, 0, 0, 0.95);

    SetupScrollbar(dropdown);

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
        local default = Filter:GetDefault(filter)

        HandleClick(self, default);
    end

    dropdown.ShowDropdown = function(self)
        self.list:SetVerticalScroll(0)
        self.list:Show();
    end

    return dropdown;
end