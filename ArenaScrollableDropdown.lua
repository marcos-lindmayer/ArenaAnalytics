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
        ArenaAnalytics:Log("Max Scroll: ", maxScroll)

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

    isEnemyComp, _ = string.find(opts["name"]:lower(), "enemy")

    dropdown.filterName = filterName;

    dropdown.entries = {}
    
    for i, entry in ipairs(entries) do 
        local text = entry["comp"] or entry;
        dropdown.title:SetText(text);
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

    dropdown.title:SetText(titleText)
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

function Dropdown:Create_Simplified(entries)
    
end

