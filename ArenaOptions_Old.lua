local _, ArenaAnalytics = ...;
ArenaAnalytics.Options_OLD = {};

local Options_OLD = ArenaAnalytics.Options_OLD;

function Options_OLD:createSettingsFrame()
	local paddingLeft = 25;
	ArenaAnalyticsScrollFrame.settingsFrame = CreateFrame("Frame", nil, ArenaAnalyticsScrollFrame, "BasicFrameTemplateWithInset")
    ArenaAnalyticsScrollFrame.settingsFrame:SetPoint("CENTER")
    ArenaAnalyticsScrollFrame.settingsFrame:SetSize(600, 415)
    ArenaAnalyticsScrollFrame.settingsFrame:SetFrameStrata("DIALOG");
    ArenaAnalyticsScrollFrame.settingsFrame:Hide();

    -- Make frame draggable
    ArenaAnalyticsScrollFrame.settingsFrame:SetMovable(true)
    ArenaAnalyticsScrollFrame.settingsFrame:EnableMouse(true)
    ArenaAnalyticsScrollFrame.settingsFrame:RegisterForDrag("LeftButton")
    ArenaAnalyticsScrollFrame.settingsFrame:SetScript("OnDragStart", ArenaAnalyticsScrollFrame.settingsFrame.StartMoving)
    ArenaAnalyticsScrollFrame.settingsFrame:SetScript("OnDragStop", ArenaAnalyticsScrollFrame.settingsFrame.StopMovingOrSizing)
    
	ArenaAnalyticsScrollFrame.settingsFrametitle = ArenaAnalyticsScrollFrame.settingsFrame:CreateFontString(nil, "OVERLAY");
	ArenaAnalyticsScrollFrame.settingsFrametitle:SetPoint("TOP", ArenaAnalyticsScrollFrame.settingsFrame, "TOP", -10, -5);
    ArenaAnalyticsScrollFrame.settingsFrametitle:SetFont("Fonts\\FRIZQT__.TTF", 12, "");
	ArenaAnalyticsScrollFrame.settingsFrametitle:SetText("Settings");

	ArenaAnalyticsScrollFrame.settingsFiltersTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft, -35, "Filter settings");

    ArenaAnalyticsScrollFrame.skirmishToggle = CreateFrame("CheckButton", "ArenaAnalyticsScrollFrame_skirmishToggle", ArenaAnalyticsScrollFrame.settingsFrame, "OptionsSmallCheckButtonTemplate");
    ArenaAnalyticsScrollFrame.skirmishToggle:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft, -50);
    ArenaAnalyticsScrollFrame.skirmishToggle.text = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.settingsFrame, "LEFT", ArenaAnalyticsScrollFrame.skirmishToggle, "RIGHT", 5, 0, "Show Skirmish");
    ArenaAnalyticsScrollFrame.skirmishToggle:SetChecked(ArenaAnalyticsSettings["showSkirmish"]);

    ArenaAnalyticsScrollFrame.skirmishToggle:SetScript("OnClick", function()
		ArenaAnalyticsSettings["showSkirmish"] = ArenaAnalyticsScrollFrame.skirmishToggle:GetChecked();
		ArenaAnalytics:Log("Show Skirmish: ", ArenaAnalyticsSettings["defaultCurrentSessionFilter"]);
		ArenaAnalytics.Filter:refreshFilters();
		ArenaAnalytics.AAtable:forceCompFilterRefresh();
	end);

    ArenaAnalyticsScrollFrame.seasonToggle = CreateFrame("CheckButton", "ArenaAnalyticsScrollFrame_seasonToggle", ArenaAnalyticsScrollFrame.settingsFrame, "OptionsSmallCheckButtonTemplate");
    ArenaAnalyticsScrollFrame.seasonToggle:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft, -70);
    ArenaAnalyticsScrollFrame.seasonToggle.text = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.settingsFrame, "LEFT", ArenaAnalyticsScrollFrame.seasonToggle, "RIGHT", 5, 0, "Show Previous Seasons");
    ArenaAnalyticsScrollFrame.seasonToggle:SetChecked(ArenaAnalyticsSettings["defaultCurrentSeasonFilter"]);

    ArenaAnalyticsScrollFrame.seasonToggle:SetScript("OnClick", function()
		ArenaAnalyticsSettings["defaultCurrentSeasonFilter"] = ArenaAnalyticsScrollFrame.seasonToggle:GetChecked();
		ArenaAnalytics:Log("Show Previous Seasons: ", ArenaAnalyticsSettings["defaultCurrentSessionFilter"]);
		ArenaAnalytics.Filter:refreshFilters();
		ArenaAnalytics.AAtable:forceCompFilterRefresh();
	end);

	-- Current session only
    ArenaAnalyticsScrollFrame.sessionToggle = CreateFrame("CheckButton", "ArenaAnalyticsScrollFrame_sessionToggle", ArenaAnalyticsScrollFrame.settingsFrame, "OptionsSmallCheckButtonTemplate");
    ArenaAnalyticsScrollFrame.sessionToggle:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft, -90);
    ArenaAnalyticsScrollFrame.sessionToggle.text = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.settingsFrame, "LEFT", ArenaAnalyticsScrollFrame.sessionToggle, "RIGHT", 5, 0, "Show Latest Session Only");
    ArenaAnalyticsScrollFrame.sessionToggle:SetChecked(ArenaAnalyticsSettings["defaultCurrentSessionFilter"]);

    ArenaAnalyticsScrollFrame.sessionToggle:SetScript("OnClick", function()
		ArenaAnalyticsSettings["defaultCurrentSessionFilter"] = ArenaAnalyticsScrollFrame.sessionToggle:GetChecked();
		ArenaAnalytics:Log("Session Only: ", ArenaAnalyticsSettings["defaultCurrentSessionFilter"]);
		ArenaAnalytics.Filter:refreshFilters();
		ArenaAnalytics.AAtable:forceCompFilterRefresh();
    end);

	-- Current session only
    ArenaAnalyticsScrollFrame.compFilterSortByTotalToggle = CreateFrame("CheckButton", "ArenaAnalyticsScrollFrame_sessionToggle", ArenaAnalyticsScrollFrame.settingsFrame, "OptionsSmallCheckButtonTemplate");
    ArenaAnalyticsScrollFrame.compFilterSortByTotalToggle:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft, -110);
    ArenaAnalyticsScrollFrame.compFilterSortByTotalToggle.text = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.settingsFrame, "LEFT", ArenaAnalyticsScrollFrame.compFilterSortByTotalToggle, "RIGHT", 5, 0, "Sort comp filter dropdowns by total played");
    ArenaAnalyticsScrollFrame.compFilterSortByTotalToggle:SetChecked(ArenaAnalyticsSettings["sortCompFilterByTotalPlayed"]);

    ArenaAnalyticsScrollFrame.compFilterSortByTotalToggle:SetScript("OnClick", function()
		ArenaAnalyticsSettings["sortCompFilterByTotalPlayed"] = ArenaAnalyticsScrollFrame.compFilterSortByTotalToggle:GetChecked();
		ArenaAnalytics:Log("Sort comp filter by total: ", ArenaAnalyticsSettings["sortCompFilterByTotalPlayed"]);
		ArenaAnalytics.Filter:refreshFilters();
		ArenaAnalytics.AAtable:forceCompFilterRefresh();
    end);

    ArenaAnalyticsScrollFrame.outliers = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", 65, -145, "Minimum games required to appear on comp filter");
    ArenaAnalyticsScrollFrame.outliersInput = CreateFrame("EditBox", "exportFrameScroll", ArenaAnalyticsScrollFrame.settingsFrame, "InputBoxTemplate")
    ArenaAnalyticsScrollFrame.outliersInput:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft + 5, -140);
    ArenaAnalyticsScrollFrame.outliersInput:SetWidth(30);
    ArenaAnalyticsScrollFrame.outliersInput:SetHeight(20);
    ArenaAnalyticsScrollFrame.outliersInput:SetNumeric();
    ArenaAnalyticsScrollFrame.outliersInput:SetAutoFocus(false);
    ArenaAnalyticsScrollFrame.outliersInput:SetMaxLetters(3);
    ArenaAnalyticsScrollFrame.outliersInput:SetText(ArenaAnalyticsSettings["outliers"])
    
    ArenaAnalyticsScrollFrame.outliersInput:SetScript("OnEditFocusLost", function(self)
        ArenaAnalyticsSettings["outliers"] = tonumber(ArenaAnalyticsScrollFrame.outliersInput:GetText()) or ArenaAnalyticsSettings["outliers"];
		ArenaAnalytics.Filter:refreshFilters();
		ArenaAnalyticsScrollFrame.outliersInput:SetText(ArenaAnalyticsSettings["outliers"]);
    end);

    ArenaAnalyticsScrollFrame.outliersInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus();
    end);
	
    ArenaAnalyticsScrollFrame.outliersInput:SetScript("OnEscapePressed", function(self)
        ArenaAnalyticsScrollFrame.outliersInput:SetText(ArenaAnalyticsSettings["outliers"]);
        self:ClearFocus();
    end);

	-- Limit for total comps to show
	ArenaAnalyticsScrollFrame.compsLimit = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", 65, -170, "Maximum comps to appear in comp filter dropdowns (0 = unlimited)");
    ArenaAnalyticsScrollFrame.compsLimitInput = CreateFrame("EditBox", "exportFrameScroll", ArenaAnalyticsScrollFrame.settingsFrame, "InputBoxTemplate")
    ArenaAnalyticsScrollFrame.compsLimitInput:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft + 5, -165);
    ArenaAnalyticsScrollFrame.compsLimitInput:SetWidth(30);
    ArenaAnalyticsScrollFrame.compsLimitInput:SetHeight(20);
    ArenaAnalyticsScrollFrame.compsLimitInput:SetNumeric();
    ArenaAnalyticsScrollFrame.compsLimitInput:SetAutoFocus(false);
    ArenaAnalyticsScrollFrame.compsLimitInput:SetMaxLetters(3);
    ArenaAnalyticsScrollFrame.compsLimitInput:SetText(tonumber(ArenaAnalyticsSettings["compsLimit"]));
    
    ArenaAnalyticsScrollFrame.compsLimitInput:SetScript("OnEditFocusLost", function(self)
		local oldValue = tonumber(ArenaAnalyticsSettings["compsLimit"]) or 0;
		local newValue = tonumber(ArenaAnalyticsScrollFrame.compsLimitInput:GetText());
        ArenaAnalyticsSettings["compsLimit"] = newValue or oldValue;
		ArenaAnalyticsScrollFrame.compsLimitInput:SetText(ArenaAnalyticsSettings["compsLimit"]);
        ArenaAnalytics.AAtable:RefreshLayout(true);
		ArenaAnalytics.AAtable:forceCompFilterRefresh();
    end);
	
    ArenaAnalyticsScrollFrame.compsLimitInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus();
    end);
	
    ArenaAnalyticsScrollFrame.compsLimitInput:SetScript("OnEscapePressed", function(self)
		ArenaAnalyticsScrollFrame.compsLimitInput:SetText(ArenaAnalyticsSettings["compsLimit"] or 0);
        self:ClearFocus();
    end);

	ArenaAnalyticsScrollFrame.settingsFiltersTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft, -205, "Data settings");

    ArenaAnalyticsScrollFrame.resetBtn = ArenaAnalytics.AAtable:CreateButton("TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft, -225, "Reset ALL DATA");
    ArenaAnalyticsScrollFrame.resetWarning = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.resetBtn, "TOPRIGHT", 5, -5, "Warning! This will reset all match history");
    ArenaAnalyticsScrollFrame.resetBtn:Disable()
    ArenaAnalyticsScrollFrame.resetBtn:SetDisabledFontObject("GameFontDisableSmall")
    ArenaAnalyticsScrollFrame.resetBtn:SetScript("OnClick", function (i) 
		ArenaAnalyticsDB = nil; -- Kept in case of stuck outdated data
		
		ArenaAnalytics.filteredMatchHistory = { }
		MatchHistoryDB = { }
		ArenaAnalyticsScrollFrame.allowReset:SetChecked(false);
		ArenaAnalyticsScrollFrame.resetBtn:Disable();
        ArenaAnalytics:Print("Match history deleted!");
		ArenaAnalytics.AAtable:handleArenaCountChanged();
		ArenaAnalytics.AAtable:tryShowimportDialogFrame();
    end);
    
    ArenaAnalyticsScrollFrame.allowReset = CreateFrame("CheckButton", "ArenaAnalyticsScrollFrame_allowReset", ArenaAnalyticsScrollFrame.settingsFrame, "OptionsSmallCheckButtonTemplate");
    ArenaAnalyticsScrollFrame.allowReset:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft, -250);
    ArenaAnalyticsScrollFrame.allowReset.text = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.settingsFrame, "LEFT", ArenaAnalyticsScrollFrame.allowReset, "RIGHT", 5, 0, "Check to enable data reset (big scary button ^)");
    ArenaAnalyticsScrollFrame.allowReset:SetChecked(false);

    ArenaAnalyticsScrollFrame.allowReset:SetScript("OnClick", 
        function()
            if (ArenaAnalyticsScrollFrame.allowReset:GetChecked() == true) then 
                ArenaAnalyticsScrollFrame.resetBtn:Enable()
            else
                ArenaAnalyticsScrollFrame.resetBtn:Disable()
            end
        end
    );
	
	ArenaAnalyticsScrollFrame.moreOptionsTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft, -290, "More options");

	-- Always show First Death Overlay
    ArenaAnalyticsScrollFrame.deathToggle = CreateFrame("CheckButton", "ArenaAnalyticsScrollFrame_deathToggle", ArenaAnalyticsScrollFrame.settingsFrame, "OptionsSmallCheckButtonTemplate");
    ArenaAnalyticsScrollFrame.deathToggle:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft, -305);
    ArenaAnalyticsScrollFrame.deathToggle.text = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.settingsFrame, "LEFT", ArenaAnalyticsScrollFrame.deathToggle, "RIGHT", 5, 0, "Always show red death bg on icon (else on mouse over only)");
    ArenaAnalyticsScrollFrame.deathToggle:SetChecked(ArenaAnalyticsSettings["alwaysShowDeathOverlay"]);

    ArenaAnalyticsScrollFrame.deathToggle:SetScript("OnClick", 
        function()
            ArenaAnalyticsSettings["alwaysShowDeathOverlay"] = ArenaAnalyticsScrollFrame.deathToggle:GetChecked();
			ArenaAnalytics.AAtable:RefreshLayout(true); 
        end
    );

	-- Show warning when 
    ArenaAnalyticsScrollFrame.unsavedThreshold = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", 85, -335, "Unsaved games threshold before showing /reload warning.");
    ArenaAnalyticsScrollFrame.unsavedThresholdInput = CreateFrame("EditBox", "exportFrameScroll", ArenaAnalyticsScrollFrame.settingsFrame, "InputBoxTemplate")
    ArenaAnalyticsScrollFrame.unsavedThresholdInput:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft + 5, -330);
    ArenaAnalyticsScrollFrame.unsavedThresholdInput:SetWidth(50);
    ArenaAnalyticsScrollFrame.unsavedThresholdInput:SetHeight(20);
    ArenaAnalyticsScrollFrame.unsavedThresholdInput:SetNumeric();
    ArenaAnalyticsScrollFrame.unsavedThresholdInput:SetAutoFocus(false);
    ArenaAnalyticsScrollFrame.unsavedThresholdInput:SetMaxLetters(5);
    ArenaAnalyticsScrollFrame.unsavedThresholdInput:SetText(ArenaAnalyticsSettings["unsavedWarningThreshold"])
    
    ArenaAnalyticsScrollFrame.unsavedThresholdInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus();
    end);
	
    ArenaAnalyticsScrollFrame.unsavedThresholdInput:SetScript("OnEscapePressed", function(self)
		ArenaAnalyticsScrollFrame.unsavedThresholdInput:SetText(ArenaAnalyticsSettings["unsavedWarningThreshold"] or "");
        self:ClearFocus();
    end);

    ArenaAnalyticsScrollFrame.unsavedThresholdInput:SetScript("OnEditFocusLost", function(self)
		local oldValue = tonumber(ArenaAnalyticsSettings["unsavedWarningThreshold"]) or 213;
		local newValue = tonumber(ArenaAnalyticsScrollFrame.unsavedThresholdInput:GetText());
        ArenaAnalyticsSettings["unsavedWarningThreshold"] = newValue or oldValue;
		ArenaAnalyticsScrollFrame.unsavedThresholdInput:SetText(tonumber(ArenaAnalyticsSettings["unsavedWarningThreshold"]));
		
		ArenaAnalytics.AAtable:checkUnsavedWarningThreshold();
    end);

	ArenaAnalyticsScrollFrame.exportBtn = ArenaAnalytics.AAtable:CreateButton("BOTTOM", ArenaAnalyticsScrollFrame.settingsFrame, "BOTTOM", 0, 22, "Export");
    ArenaAnalyticsScrollFrame.exportBtn:SetScript("OnClick", function() ArenaAnalytics.Export:combineExportCSV() end);

    -- Set export DB CSV frame layout
    createExportFrame();
end