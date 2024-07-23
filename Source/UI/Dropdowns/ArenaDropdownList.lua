local _, ArenaAnalytics = ...; -- Addon Namespace
local Dropdown = ArenaAnalytics.Dropdown;

-- Setup local subclass
Dropdown.List = {};
local List = Dropdown.List;
List.__index = List;

-------------------------------------------------------------------------

List.verticalPadding = 5;
List.horizontalPadding = 3;

function List:Create(parent, level, width, height, entries)
    assert(entries ~= nil);

    local self = setmetatable({}, List);

    Dropdown:HideActiveDropdownsFromLevel(level, true);

    self.name = (parent.name .. "List");
    self.parent = parent;
    self.level = level;

    self.width = width;
    self.maxHeight = height * 10 + List.verticalPadding * 2;
    self.entries = entries;

    self.backdrop = CreateFrame("Frame", self.name, parent:GetOwner(), "TooltipBackdropTemplate");
    self.backdrop:SetSize(width, 1);
    self.backdrop:SetFrameStrata("TOOLTIP")
    self.backdrop:Show();

    self:SetBackdropAlpha(0.85);
    
    -- Setup scroll frame, in case we got too many entries to show
    self.scrollFrame = CreateFrame("scrollFrame", self.name .. "_ScrollFrame", self.backdrop, "UIPanelScrollFrameTemplate");
    self.scrollFrame:SetPoint("TOP", self.backdrop, "TOP", 0, -5);
    self.scrollFrame:SetSize(width - List.horizontalPadding*2, self.backdrop:GetHeight());
    self.scrollFrame:SetClipsChildren(true);
    self.scrollFrame.scrollBarHideable = true;

    -- Content frame
    self.scrollFrame.content = CreateFrame("Frame", self.name .. "_Content", self.scrollFrame);
    self.scrollFrame.content:SetPoint("TOP", self.scrollFrame);
    self.scrollFrame.content:SetSize(width, 1);
    
    -- Assign the scroll child
    self.scrollFrame:SetScrollChild(self.scrollFrame.content);

    -- Update scrollbar max
    self:SetupScrollbar();

    self.scrollFrame:SetScript("OnScrollRangeChanged", function(scrollFrame)
        local viewHeight = scrollFrame:GetHeight()
        local contentHeight = scrollFrame.content:GetHeight();
        local maxScroll = math.max(contentHeight - viewHeight, 0)
        
        scrollFrame:UpdateScrollChildRect();
        scrollFrame.ScrollBar:SetMinMaxValues(0, maxScroll);
    end);
    
    self.entryFrames = {}
    self:Refresh();
    
    Dropdown:AddActiveDropdown(level, self);

    return self;
end

function List:Refresh()
    -- Get most recent entries list, in case of a dynamic function
    local entries = Dropdown._internal:RetrieveValue(self.entries, self);
    
    -- Clear old entries
    self.entryFrames = {}

    -- Add new entries
    self:AddEntries(entries, self.scrollFrame.content:GetWidth() - 10, 20);
end

function List:AddEntries(entries, width, height)
    assert(entries);

    local accumulatedHeight = List.verticalPadding * 2;
    local lastFrame = nil;

    for i, entry in ipairs(entries) do 
        local entryFrame = Dropdown.EntryFrame:Create(self, i, width, height, entry);
        entryFrame:Show()

        if(not lastFrame) then
            entryFrame:SetPoint("TOPLEFT", self.scrollFrame.content, "TOPLEFT", 2, -List.verticalPadding);
        else
            entryFrame:SetPoint("TOP", lastFrame, "BOTTOM");
        end

        accumulatedHeight = ceil(accumulatedHeight + entryFrame:GetHeight());
        
        lastFrame = entryFrame:GetFrame();
        table.insert(self.entryFrames, entryFrame);
    end

    self.scrollFrame.content:SetHeight(accumulatedHeight);

    local listHeight = min(accumulatedHeight, self.maxHeight);
    self.scrollFrame:SetHeight(listHeight - 0);
    self.backdrop:SetHeight(self.scrollFrame:GetHeight() + 10);
    
    self:SetupScrollbar();
    
    self.scrollFrame:UpdateScrollChildRect(); -- Ensure the scroll child rect is updated
end

function List:SetupScrollbar()
    local scrollbar = self.scrollFrame.ScrollBar;
    scrollbar:ClearAllPoints();
    scrollbar:SetPoint("TOPLEFT", self.scrollFrame, "TOPRIGHT", -3, 3);
    scrollbar:SetPoint("BOTTOMLEFT", self.scrollFrame, "BOTTOMRIGHT", -3, -4);

    local viewHeight = self.scrollFrame:GetHeight()
    local contentHeight = self.scrollFrame.content:GetHeight();
    
    -- Workaround for scrollbar not hiding automatically
    if ((viewHeight + 0.01) < contentHeight) then
        scrollbar:SetAlpha(1);
    else
        scrollbar:SetAlpha(0);
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

function List:SetBackdropAlpha(alpha)
    local bgColor = self.backdrop.backdropColor or TOOLTIP_DEFAULT_BACKGROUND_COLOR;
	local bgR, bgG, bgB = bgColor:GetRGB();
	
    alpha = alpha or 1;
	self.backdrop:SetBackdropColor(bgR, bgG, bgB, alpha);
end

function List:GetOwner()
    return self.parent:GetOwner();
end

function List:GetFrame()
    return self.scrollFrame.content;
end

function List:GetName()
    return self.name;
end

function List:GetDropdownType()
    return self.type or parent:GetDropdownType();
end

function List:IsMouseOver()
    return self.backdrop:IsMouseOver(5,-5,-5,5);
end

function List:Toggle()
    if(self:IsVisible()) then
        self:Hide();
    else
        self:Show();
    end
end

function List:IsVisible()
    return self.backdrop:IsVisible();
end

function List:Show()
    self.backdrop:Show();
end

function List:Hide()
    Dropdown:HideActiveDropdownsFromLevel(self.level+1, false);
    self.backdrop:Hide();
    ArenaAnalytics:Log("Dropdown list hidden, level:", self.level, " Highest active level: ", Dropdown:GetHighestActiveDropdownLevel());
end

function List:GetPoint()
    local point, parent, relativePoint, x, y = self.backdrop:GetPoint();
    if(parent ~= nil) then
        parent = parent:GetName();
    end
    return point, parent, relativePoint, x, y;
end

function List:SetPoint(...)
    return self.backdrop:SetPoint(...);
end