-- Namespace for managing versions, including backwards compatibility and converting data
local _, ArenaAnalytics = ...;
ArenaAnalytics.Dropdown = {};
local Dropdown = ArenaAnalytics.Dropdown;

-- Returns buttons for filter lists
local function createDropdownButton(info, dropdown, filter, width)
    local button = CreateFrame("Button", filter .. "_" .. info.text, dropdown.list, "UIServiceButtonTemplate");
    button.money:Hide();
    button:SetSize(width, 25);
    button:SetPoint("CENTER", dropdown.list);
    button:SetNormalFontObject("GameFontHighlight");
    button:SetHighlightFontObject("GameFontHighlight");
    button:SetAttribute("dropdown", dropdown);
    

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

-- Returns a dropdown frame
-- Used for match filters
function Dropdown:Create(opts)
    local filterName = opts["name"];
    local dropdown_name ="$parent_" .. opts["name"] .. "_dropdown";
    local entries = opts["entries"] or {};
    local isCompDropdown = opts["hasCompIcons"];
    local title_text = opts["title"] or "";
    local dropdown_width = (filterName == "Filter_Comp" or filterName == "Filter_EnemyComp") and 265 or 0;
    local default_val = opts["defaultVal"] or "";

    local dropdown = CreateFrame("Frame", dropdown_name, ArenaAnalyticsScrollFrame);
    dropdown.list = CreateFrame("Frame", dropdown_name .. "_list", dropdown)
    dropdown:SetSize(500, 25);
    dropdown.list:SetPoint("TOP", dropdown, "BOTTOM")
    dropdown.title = dropdown:CreateFontString(nil, "OVERLAY")
    dropdown.title:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    dropdown.title:SetPoint("TOPLEFT", 0, 15)
    isEnemyComp, _ = string.find(opts["name"]:lower(), "enemy")
    dropdown.filterName = filterName;
    

    dropdown.entries = {}
    
    for _, entry in ipairs(entries) do 
        local text = entry["comp"] or entry;
        dropdown.title:SetText(text);
        local text_width = dropdown.title:GetStringWidth() + 50
        if (text_width > dropdown_width and filterName ~= "Filter_Comp" and filterName ~= "Filter_EnemyComp") then
            dropdown_width = text_width
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

        local newEntry = createDropdownButton(info, dropdown, title_text, dropdown_width);
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

    dropdown.title:SetText(title_text)
    dropdown.list:SetSize(dropdown_width, (#dropdown.entries * 25));
    dropdown:SetWidth(dropdown_width)
    
    local totalHeight = 0;
    for i = 1, #dropdown.entries do
        local entry = dropdown.entries[i];
        totalHeight = totalHeight + entry:GetHeight();
        entry:SetPoint("TOPLEFT", 0, -(i - 1) * entry:GetHeight())
        entry:SetWidth(dropdown_width)
    end
    
    local dropdownBg = dropdown:CreateTexture();
    dropdownBg:SetPoint("CENTER")
    dropdownBg:SetSize(dropdown_width, 25);
    dropdownBg:SetColorTexture(0, 0, 0, 0.7);
    
    dropdown.background = dropdown.list:CreateTexture();
    dropdown.background:SetPoint("TOP")
    dropdown.background:SetSize(dropdown_width, totalHeight);
    dropdown.background:SetColorTexture(0, 0, 0, 0.9);

    dropdown.selected = CreateFrame("Button", dropdown_name .. "_selected", dropdown, "UIServiceButtonTemplate")
    dropdown.selected.money:Hide();
    dropdown.selected:SetPoint("CENTER")
    dropdown.selected:SetSize(dropdown_width, 25)
    dropdown.selected:SetText(default_val);
    dropdown.selected:SetNormalFontObject("GameFontHighlight");
    dropdown.selected:SetHighlightFontObject("GameFontHighlight");
    dropdown.selected:SetDisabledFontObject("GameFontDisableSmall");
    dropdown.selected:SetAttribute("name", dropdown)

    dropdown.selected:SetScript("OnClick", function (args)
        local dropdownList = args:GetAttribute("name").list
        if (dropdownList:IsShown()) then
            dropdownList:Hide();
        else
            ArenaAnalytics.AAtable:closeFilterDropdowns();
            dropdownList:Show();
        end
    end);

    dropdown.reset = function(self)
        ArenaAnalytics.Filter:changeFilter(dropdown, default_val);
    end

    dropdown.list:Hide();

    return dropdown;
end
