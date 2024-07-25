local _, ArenaAnalytics = ...; -- Addon Namespace
local Dropdown = ArenaAnalytics.Dropdown;

-- Setup local subclass
Dropdown.List = {};
local List = Dropdown.List;
List.__index = List;

-------------------------------------------------------------------------

List.verticalPadding = 5;
List.horizontalPadding = 3;
List.maxVisibleEntries = 10;

function List:Create(parent, level, width, height, entries)
    assert(entries ~= nil, "Assertion failed: nil entries list");

    local self = setmetatable({}, List);

    self.name = (parent.name .. "List");
    self.parent = parent;
    self.level = level;

    self.width = width;
    self.height = height;
    self.maxHeight = height * List.maxVisibleEntries + List.verticalPadding * 2;

    self.entries = entries;

    self.backdrop = CreateFrame("Frame", self.name, parent:GetOwner(), "TooltipBackdropTemplate");
    self.backdrop:SetSize(1, 1);
    self.backdrop:SetFrameStrata("TOOLTIP")

    self:SetBackdropAlpha(0.85);
    
    -- Setup scroll frame, in case we got too many entries to show
    self.scrollFrame = CreateFrame("scrollFrame", self.name .. "_ScrollFrame", self.backdrop, "UIPanelScrollFrameTemplate");
    self.scrollFrame:SetPoint("TOP", self.backdrop, "TOP", 0, -5);
    self.scrollFrame:SetSize(1, 1);
    self.scrollFrame:SetClipsChildren(true);
    self.scrollFrame.scrollBarHideable = true;

    -- Content frame
    self.scrollFrame.content = CreateFrame("Frame", self.name .. "_Content", self.scrollFrame);
    self.scrollFrame.content:SetPoint("TOP", self.scrollFrame);
    self.scrollFrame.content:SetSize(1, 1);
    
    -- Assign the scroll child
    self.scrollFrame:SetScrollChild(self.scrollFrame.content);

    self.scrollFrame:SetScript("OnScrollRangeChanged", function(scrollFrame)
        self:UpdateScrollbarMinMax();
    end);
    
    self.entryFrames = {}
    self:Refresh("List:Create");

    self:Hide();

    return self;
end

function List:SetEntries(entries)
    

end

function List:Refresh(debugContext)
    --ArenaAnalytics:Log("Refreshing ", self:GetName(), " for context: ", debugContext);

    -- Get most recent entries list, in case of a dynamic function
    local entries = Dropdown:RetrieveValue(self.entries, self);
    assert(entries, "Assert failed: Nil entries for type: " .. type(self.entries) .. " on dropdown list: " .. self:GetName());
    
    -- Clear old entries
    for i=#self.entryFrames, 1, -1 do
        if(self.entryFrames[i]) then
            self.entryFrames[i]:Hide();
            self.entryFrames[i] = nil;
        end
    end
    
    self.entryFrames = {}

    -- Add new entries
    self:AddEntries(entries, self.width);
    
    Dropdown:AddActiveDropdown(self.level, self);
    
    self:SetupScrollbar();
    self.scrollFrame:UpdateScrollChildRect(); -- Ensure the scroll child rect is updated
end

function List:AddEntries(entries, width)
    assert(entries, "Assert failed: Nil entries.");

    local accumulatedHeight = List.verticalPadding * 2;
    local longestEntryWidth = width or 0;
    local lastFrame = nil;

    for i, entry in ipairs(entries) do 
        local entryFrame = Dropdown.EntryFrame:Create(self, i, width - 10, 20, entry);

        if(not lastFrame) then
            entryFrame:SetPoint("TOP", self.scrollFrame.content, "TOP", 2, -List.verticalPadding);
        else
            entryFrame:SetPoint("TOP", lastFrame, "BOTTOM");
        end

        if(longestEntryWidth < entryFrame:GetWidth()) then
            longestEntryWidth = entryFrame:GetWidth();
        end

        accumulatedHeight = Round(accumulatedHeight + entryFrame:GetHeight());
        
        lastFrame = entryFrame:GetFrame();
        table.insert(self.entryFrames, entryFrame);
    end

    local desiredWidth = Round(max(width, longestEntryWidth));
    if(width ~= desiredWidth) then
        for _,entry in ipairs(self.entryFrames) do
            entry:SetWidth(longestEntryWidth);
        end
    end

    self.scrollFrame.content:SetHeight(accumulatedHeight);

    self:SetSize(desiredWidth, accumulatedHeight + 10);
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

    self:UpdateScrollbarMinMax();
end

function List:UpdateScrollbarMinMax()
    local viewHeight = self.scrollFrame:GetHeight();
    local contentHeight = self.scrollFrame.content:GetHeight();
    local maxScroll = math.max(contentHeight - viewHeight, 0);
    
    self.scrollFrame:UpdateScrollChildRect();
    self.scrollFrame.ScrollBar:SetMinMaxValues(0, maxScroll);
end

function List:SetBackdropAlpha(alpha)
    local bgColor = self.backdrop.backdropColor or TOOLTIP_DEFAULT_BACKGROUND_COLOR;
	local bgR, bgG, bgB = bgColor:GetRGB();
	
    alpha = alpha or 1;
	self.backdrop:SetBackdropColor(bgR, bgG, bgB, alpha);
end

---------------------------------
-- Simple getters
---------------------------------

function List:GetOwner()
    return self.parent:GetOwner();
end

function List:GetSelectedFrame()
    return self.parent:GetSelectedFrame();
end

function List:GetFrame()
    return self.scrollFrame.content;
end

function List:GetName()
    return self.name;
end

function List:GetDropdownType()
    return self.parent:GetDropdownType();
end

---------------------------------
-- Points
---------------------------------

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

function List:SetSize(width, height)
    self.backdrop:SetSize(width, min(height, self.maxHeight));
    self.scrollFrame:SetSize(width - List.horizontalPadding*2, self.backdrop:GetHeight()-10);
    self.scrollFrame.content:SetWidth(self.scrollFrame:GetWidth());
end

---------------------------------
-- Visibility
---------------------------------

function List:IsShown()
    return self.backdrop:IsShown();
end

function List:Toggle()
    if(self:IsShown()) then
        self:Hide();
    else
        self:Show();
    end
end

function List:Show()
    Dropdown:HideActiveDropdownsFromLevel(self.level+1, true);
    self.backdrop:Show();
end

function List:Hide()
    Dropdown:HideActiveDropdownsFromLevel(self.level+1, true);
    self.backdrop:Hide();
    self = nil;
end



-- TODO: Test this.
function List:IsMouseOver()
    return self.backdrop:IsMouseOver(5,-5,-5,5);
end
