local _, ArenaAnalytics = ...;
ArenaAnalytics.FiltersDialog = {};

local FiltersDialog = ArenaAnalytics.FiltersDialog;

local function createFilter_Dropdown(filter, title, entries, default, width, height)
    ForceDebugNilError(filter);

    local opts = {
        ["name"] = filter,
        ["title"] = title or "Unknown",
        ["entries"] = entries or {},
        ["defaultVal"] = default or "All"
    }

    local dropdown = ArenaAnalytics.AAtable:createDropdown(opts);
    dropdown:SetSize(width, height);
    return dropdown;
end

function FiltersDialog:createMoreFiltersFrame()
	local paddingLeft = 25;
	ArenaAnalyticsScrollFrame.MoreFiltersFrame = CreateFrame("Frame", nil, ArenaAnalyticsScrollFrame, "BasicFrameTemplateWithInset")
    ArenaAnalyticsScrollFrame.MoreFiltersFrame:SetPoint("CENTER")
    ArenaAnalyticsScrollFrame.MoreFiltersFrame:SetSize(600, 415)
    ArenaAnalyticsScrollFrame.MoreFiltersFrame:SetFrameStrata("DIALOG");
    ArenaAnalyticsScrollFrame.MoreFiltersFrame:Hide();

    -- Make frame draggable
    ArenaAnalyticsScrollFrame.MoreFiltersFrame:SetMovable(true)
    ArenaAnalyticsScrollFrame.MoreFiltersFrame:EnableMouse(true)
    ArenaAnalyticsScrollFrame.MoreFiltersFrame:RegisterForDrag("LeftButton")
    ArenaAnalyticsScrollFrame.MoreFiltersFrame:SetScript("OnDragStart", ArenaAnalyticsScrollFrame.MoreFiltersFrame.StartMoving)
    ArenaAnalyticsScrollFrame.MoreFiltersFrame:SetScript("OnDragStop", ArenaAnalyticsScrollFrame.MoreFiltersFrame.StopMovingOrSizing)

    local entries = {"All" ,'Nagrand Arena' ,'Ruins of Lordaeron', 'Blade Edge Arena', 'Dalaran Arena'},
    createFilter_Dropdown("Filter_Map", "Map", entries, "All");
end