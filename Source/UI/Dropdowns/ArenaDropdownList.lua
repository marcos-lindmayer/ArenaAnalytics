local _, ArenaAnalytics = ...; -- Addon Namespace
local Dropdown = ArenaAnalytics.Dropdown;

-- Setup local subclass
Dropdown.List = {};
local List = Dropdown.List;
List.__index = List;

-------------------------------------------------------------------------

function List:Create(parent, width, entries)
    local self = setmetatable({}, List);

    self.name = (parent.name .. "List");

    self.width = width;
    self.entries = entries;

    self.backdrop = CreateFrame("Frame", self.name, parent:GetFrame(), "TooltipBackdropTemplate");

    -- Setup scroll frame, in case we got too many entries to show
    self.scrollFrame = CreateFrame("scrollFrame", self.name .. "_ScrollFrame", self.backdrop, "UIPanelscrollFrameTemplate");
    self.scrollFrame:SetWidth(width);

    -- Update scrollbar max
    self.scrollFrame:SetScript("OnScrollRangeChanged", function(scrollFrame)
        local viewHeight = scrollFrame:GetHeight()
        local contentHeight = scrollFrame.content:GetHeight();
        local maxScroll = math.max(contentHeight - viewHeight, 0)
        
        scrollFrame:UpdateScrollChildRect();
        scrollFrame.ScrollBar:SetMinMaxValues(0, maxScroll);
    end);

    -- Content frame
    self.scrollFrame.content = CreateFrame("Frame", self.name .. "_Content", self.scrollFrame);
    self.scrollFrame.content:SetPoint("TOP", self.scrollFrame);
    self.scrollFrame.content:SetWidth(width);

    -- Assign the scroll child
    self.scrollFrame:SetScrollChild(self.scrollFrame.content);

    return self
end

function List:GetFrame()
    return self.scrollFrame.content;
end

function List:Toggle()
    if(self.backdrop:IsVisible()) then
        self.backdrop:Hide();
    else
        self.backdrop:Show();
    end
end
