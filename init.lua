local _, ArenaAnalytics = ...; -- Namespace

local ratedUpdateEvent = nil;

local version = "";

--------------------------------------
-- Custom Slash Command
--------------------------------------
ArenaAnalytics.commands = {	
	["help"] = function()
		print(" ");
		ArenaAnalytics:Print("List of slash commands:");
		ArenaAnalytics:Print("|cff00cc66/aa|r");
		ArenaAnalytics:Print("|cff00cc66/aa played|r Prints total duration of tracked arenas.");
		print(" ");
	end,
	
	["version"] = function()
		ArenaAnalytics:Print("Current version: ", version, " (Early Access)");
	end,
	
	["total"] = function()
		ArenaAnalytics:Print("Total arenas stored: ", #MatchHistoryDB);
	end,
	
	["oldtotal"] = function()
		local total = 0;
		if(ArenaAnalyticsDB) then
			if(ArenaAnalyticsDB["2v2"]) then total = total + #ArenaAnalyticsDB["2v2"] end;
			if(ArenaAnalyticsDB["3v3"]) then total = total + #ArenaAnalyticsDB["3v3"] end;
			if(ArenaAnalyticsDB["5v5"]) then total = total + #ArenaAnalyticsDB["5v5"] end;
		end

		ArenaAnalytics:Print("Old total arenas: ", total);
	end,
	
	["played"] = function()
		local totalDurationInArenas = 0;
		for i=1, #MatchHistoryDB do
			local duration = tonumber(MatchHistoryDB[i]["duration"]);
			if(duration and duration > 0) then
				totalDurationInArenas = totalDurationInArenas + duration;
			end
		end
		ArenaAnalytics:Print("You've spent a total of", SecondsToTime(totalDurationInArenas), "inside the arena!");
	end,

	-- Debug command to 
	["debug"] = function()
		if(ArenaAnalytics.skipDebugLog and ArenaAnalytics.skipDebugForceNilError) then
			ArenaAnalytics.skipDebugLog = false;
			ArenaAnalytics.skipDebugForceNilError = false;
			ArenaAnalytics:Log("Debugging enabled!");
		else
			ArenaAnalytics.skipDebugLog = true;
			ArenaAnalytics.skipDebugForceNilError = true;
			ArenaAnalytics:Print("Debugging disabled!");
		end
	end,

	["convert"] = function()
		ArenaAnalytics:Print("Converting ArenaAnalyticsDB to MatchHistoryDB");
		MatchHistoryDB = {} -- Force resetting it for testing
		ArenaAnalytics.VersionManager:convertArenaAnalyticsDBToMatchHistoryDB();
	end,

	["updatesessions"] = function()
		ArenaAnalytics:Print("Updating sessions in MatchHistoryDB");
		ArenaAnalytics:recomputeSessionsForMatchHistoryDB();
	end,

	["updateseasons"] = function()
		ArenaAnalytics:Print("Updating seasons in MatchHistoryDB");
		for i=1, #MatchHistoryDB do
			local match = MatchHistoryDB[i];
			local season = match["season"];
			if(season == nil or season == 0) then
				season = ArenaAnalytics:computeSeasonFromMatchDate(match["date"]);
				if(season) then
					ArenaAnalytics:Log("Updated season at index: ", i, " to season: ", season);
					MatchHistoryDB[i]["season"] = season;
				else
					ArenaAnalytics:Log("Updating seasons got nil season for date: ", date("%d/%m/%y %H:%M:%S", match["date"]), " (", match["date"], ")");
				end
			end
		end
	end,

	["debugcleardb"] = function()
		if(ArenaAnalytics.skipDebugLog and ArenaAnalytics.skipDebugForceNilError) then
			ArenaAnalytics:Print("Clearing MatchHistoryDB requires enabling /aa debug. Not intended for users!");
		else -- Debug mode is enabled, allow debug clearing the DB
			ArenaAnalytics:Log("Clearing MatchHistoryDB.");
			MatchHistoryDB = {}
			ArenaAnalytics.AAtable:tryShowimportFrame();
			ArenaAnalytics.Filter:refreshFilters();
			ArenaAnalytics.unsavedArenaCount = 0;
		end
	end,
};

local function HandleSlashCommands(str)	
	if (#str == 0) then	
		-- User just entered "/aa" with no additional args.
		ArenaAnalytics.AAtable.Toggle();
		return;		
	end	
	
	local args = {};
	for _, arg in ipairs({ string.split(' ', str) }) do
		if (#arg > 0) then
			table.insert(args, arg);
		end
	end
	
	local path = ArenaAnalytics.commands; -- required for updating found table.
	
	for id, arg in ipairs(args) do
		if (#arg > 0) then -- if string length is greater than 0.
			arg = arg:lower();			
			if (path[arg]) then
				if (type(path[arg]) == "function") then				
					-- all remaining args passed to our function!
					path[arg](select(id + 1, unpack(args))); 
					return;					
				elseif (type(path[arg]) == "table") then				
					path = path[arg]; -- another sub-table found!
				end
			else
				-- does not exist!
				ArenaAnalytics.commands.help();
				return;
			end
		end
	end
end

function ArenaAnalytics:Print(...)
    local hex = select(4, ArenaAnalytics:GetThemeColor());
    local prefix = string.format("|cff%s%s|r", hex:upper(), "ArenaAnalytics:");
    -- DEFAULT_CHAT_FRAME:AddMessage(string.join(" ", prefix, ...));
	print(prefix, ...);
end

-- Debug logging version of print
ArenaAnalytics.skipDebugLog = true;
function ArenaAnalytics:Log(...)
	if ArenaAnalytics.skipDebugLog then 
		return;
	end

    local hex = "FF6EC7";
    local prefix = string.format("|cff%s%s|r", hex, "ArenaAnalytics (Debug):");
	print(prefix, ...);
end

-- Returns devault theme color
function ArenaAnalytics:GetThemeColor()
	local defaults = {
		theme = {
			r = 0, 
			g = 0.8,
			b = 1,
			hex = "00ccff"
		}
	}
	local c = defaults.theme;
	return c.r, c.g, c.b, c.hex;
end

local function onRatedStatsReceived()
	if(ratedUpdateEvent ~= nil) then
		ratedUpdateEvent:SetScript("OnEvent", nil);
		ratedUpdateEvent = nil;
	end
	
	ArenaAnalytics.AAmatch:updateCachedBracketRatings();
end

local function createMinimapButton()
	-- Create minimap button -- Credit to Leatrix
	local minibtn = CreateFrame("Button", "ArenaAnalyticsMinimapButton", Minimap)
	minibtn:SetFrameLevel(13)
	minibtn:SetSize(24,24)
	minibtn:SetMovable(true)
	minibtn:SetNormalTexture([[Interface\AddOns\ArenaAnalytics\icon\mmicon]])
	minibtn:SetPushedTexture([[Interface\AddOns\ArenaAnalytics\icon\mmicon]])
	minibtn:SetPushedTexture([[Interface\AddOns\ArenaAnalytics\icon\mmiconP]])
	minibtn:SetHighlightTexture([[Interface\AddOns\ArenaAnalytics\icon\mmiconH]])
	minibtn:SetScript("OnEnter", function ()
		GameTooltip:SetOwner(ArenaAnalyticsMinimapButton, "ANCHOR_BOTTOMLEFT");
		local hex = select(4, ArenaAnalytics:GetThemeColor());
		local tooltip = string.format("|cff%s%s|r", hex:upper(), "ArenaAnalytics") .. " \nClick to open";	
		GameTooltip:SetText(tooltip, nil, nil, nil, nil, (ArenaAnalyticsMinimapButton.tooltipStyle or true));
	end);
	minibtn:SetScript("OnLeave", function ()
		GameTooltip:Hide();
	end);

	local minibtnBorder = CreateFrame("Frame", nil, minibtn)
	minibtnBorder:SetSize(50,50)
	minibtnBorder:SetPoint("TOPLEFT");
	local minibtnBorderT = minibtnBorder:CreateTexture()
	minibtnBorderT:SetSize(50,50)
	minibtnBorderT:SetPoint("TOPLEFT", -2, 2);
	minibtnBorderT:SetTexture([[Interface\Minimap\MiniMap-TrackingBorder]])

	ArenaAnalyticsMapIconPos = ArenaAnalyticsMapIconPos or 0
	
	-- Control movement
	local function UpdateMapBtn()
		local cursorX, cursorY = GetCursorPosition();
		local minX, minY = Minimap:GetLeft(), Minimap:GetBottom();
		cursorX = minX - cursorX / Minimap:GetEffectiveScale() + 70;
		cursorY = cursorY / Minimap:GetEffectiveScale() - minY - 70;
		ArenaAnalyticsMapIconPos = math.deg(math.atan2(cursorY, cursorX));
		minibtn:ClearAllPoints();
		local offset = 57;
		minibtn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", offset - (80 * cos(ArenaAnalyticsMapIconPos)), (80 * sin(ArenaAnalyticsMapIconPos)) - offset);
	end

	-- Set position
	UpdateMapBtn();
	
	minibtn:RegisterForDrag("LeftButton")
	minibtn:SetScript("OnDragStart", function()
		minibtn:StartMoving()
		minibtn:SetScript("OnUpdate", UpdateMapBtn)
	end)
	
	minibtn:SetScript("OnDragStop", function()
		minibtn:StopMovingOrSizing();
		minibtn:SetScript("OnUpdate", nil)
		UpdateMapBtn();
	end)
	
	-- Control clicks
	minibtn:SetScript("OnClick", function()
		ArenaAnalytics.AAtable.Toggle()
	end)
end

function ArenaAnalytics:init(event, name, ...)
	if (name ~= "ArenaAnalytics") then return end 
	
	-- allows using left and right buttons to move through chat 'edit' box
	for i = 1, NUM_CHAT_WINDOWS do
		_G["ChatFrame"..i.."EditBox"]:SetAltArrowKeyMode(false);
	end
	
	version = GetAddOnMetadata("ArenaAnalytics", "Version") or 99999;
	local versionText = version ~= 99999 and " (Version: " .. version .. ")" or ""
	ArenaAnalytics:Print("Early Access: Bugs are expected!", versionText);
    ArenaAnalytics:Print("Tracking arena games, gl hf",  UnitName("player") .. "!!");
	successfulRequest = C_ChatInfo.RegisterAddonMessagePrefix("ArenaAnalytics");

	----------------------------------
	-- Register Slash Commands
	----------------------------------

	SLASH_AuraTracker1 = "/aa";
	SLASH_AuraTracker2 = "/arenaanalytics";
	SlashCmdList.AuraTracker = HandleSlashCommands;

	ArenaAnalytics:updateLastSession();

	ArenaAnalyticsLoadSettings();

	-- Update cached rating as soon as possible
	ratedUpdateEvent = CreateFrame("Frame");
	ratedUpdateEvent:RegisterEvent("PVP_RATED_STATS_UPDATE");
	ratedUpdateEvent:SetScript("OnEvent", function() onRatedStatsReceived() end);
	C_Timer.After(0, function() RequestRatedInfo() end);
	
	-- Try converting old matches to MatchHistoryDB
	ArenaAnalytics.VersionManager:convertArenaAnalyticsDBToMatchHistoryDB();

	ArenaAnalytics.AAmatch:EventRegister();
	ArenaAnalytics.AAtable:OnLoad();
	createMinimapButton();

	if(IsInInstance() or IsInGroup(1)) then
		local channel = IsInInstance() and "INSTANCE_CHAT" or "PARTY";
		local messageSuccess = C_ChatInfo.SendAddonMessage("ArenaAnalytics", UnitGUID("player") .. "_deliver|version#?=" .. version, channel)
	end
end

-- Creates the Export DB frame
local function createExportFrame()
	if(ArenaAnalyticsScrollFrame.exportFrameContainer == nil) then
		ArenaAnalyticsScrollFrame.exportFrameContainer = CreateFrame("Frame", nil, ArenaAnalyticsScrollFrame, "BasicFrameTemplateWithInset")
		ArenaAnalyticsScrollFrame.exportFrameContainer:SetFrameStrata("DIALOG");
		ArenaAnalyticsScrollFrame.exportFrameContainer:SetFrameLevel(10);
		ArenaAnalyticsScrollFrame.exportFrameContainer:SetPoint("CENTER", ArenaAnalyticsScrollFrame, "CENTER", 0, 0);
		ArenaAnalyticsScrollFrame.exportFrameContainer:SetSize(400, 150);

		-- Make frame draggable
		ArenaAnalyticsScrollFrame.exportFrameContainer:SetMovable(true)
		ArenaAnalyticsScrollFrame.exportFrameContainer:EnableMouse(true)
		ArenaAnalyticsScrollFrame.exportFrameContainer:RegisterForDrag("LeftButton")
		ArenaAnalyticsScrollFrame.exportFrameContainer:SetScript("OnDragStart", ArenaAnalyticsScrollFrame.exportFrameContainer.StartMoving)
		ArenaAnalyticsScrollFrame.exportFrameContainer:SetScript("OnDragStop", ArenaAnalyticsScrollFrame.exportFrameContainer.StopMovingOrSizing)

		ArenaAnalyticsScrollFrame.exportFrameContainer.Title = ArenaAnalyticsScrollFrame.exportFrameContainer:CreateFontString(nil, "OVERLAY");
		ArenaAnalyticsScrollFrame.exportFrameContainer.Title:SetPoint("TOP", ArenaAnalyticsScrollFrame.exportFrameContainer, "TOP", -10, -5);
		ArenaAnalyticsScrollFrame.exportFrameContainer.Title:SetFont("Fonts\\FRIZQT__.TTF", 12, "");
		ArenaAnalyticsScrollFrame.exportFrameContainer.Title:SetText("ArenaAnalytics Export");

		ArenaAnalyticsScrollFrame.exportFrame = CreateFrame("EditBox", "exportFrameEditbox", ArenaAnalyticsScrollFrame.exportFrameContainer, "InputBoxTemplate");
		ArenaAnalyticsScrollFrame.exportFrame:SetPoint("CENTER", ArenaAnalyticsScrollFrame.exportFrameContainer, "CENTER");
		ArenaAnalyticsScrollFrame.exportFrame:SetSize(350, 25);
		ArenaAnalyticsScrollFrame.exportFrame:SetAutoFocus(true);
		ArenaAnalyticsScrollFrame.exportFrame:SetFont("Fonts\\FRIZQT__.TTF", 10, "");
		ArenaAnalyticsScrollFrame.exportFrame:SetMultiLine(false);
		ArenaAnalyticsScrollFrame.exportFrameContainer:Hide();
		
		ArenaAnalyticsScrollFrame.exportFrameContainer.WarningText = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.exportFrameContainer,"BOTTOM", ArenaAnalyticsScrollFrame.exportFrame, "TOP", 13, 0, "|cffff0000Warning:|r Pasting long string here will crash WoW!");
		ArenaAnalyticsScrollFrame.exportFrameContainer.totalText = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.exportFrameContainer,"TOPLEFT", ArenaAnalyticsScrollFrame.exportFrame, "BOTTOMLEFT", -3, 0, "Total arenas: " .. #MatchHistoryDB);
		ArenaAnalyticsScrollFrame.exportFrameContainer.lengthText = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.exportFrameContainer,"TOPRIGHT", ArenaAnalyticsScrollFrame.exportFrame, "BOTTOMRIGHT", -3, 0, "Export length: 0");

		ArenaAnalyticsScrollFrame.exportFrameContainer.selectBtn = ArenaAnalytics.AAtable:CreateButton("BOTTOM", ArenaAnalyticsScrollFrame.exportFrameContainer, "BOTTOM", 0, 17, "Select All");
		ArenaAnalyticsScrollFrame.exportFrameContainer.selectBtn:SetScript("OnClick", function() ArenaAnalyticsScrollFrame.exportFrame:HighlightText() end);
		
		-- Escape to close
		ArenaAnalyticsScrollFrame.exportFrame:SetScript("OnEscapePressed", function(self)
			ArenaAnalyticsScrollFrame.exportFrame:ClearFocus();
			ArenaAnalyticsScrollFrame.exportFrameContainer:Hide();
		end);

		ArenaAnalyticsScrollFrame.exportFrame:SetScript("OnEnterPressed", function(self)
			self:ClearFocus();
		end);

		-- Highlight on focus gained
		ArenaAnalyticsScrollFrame.exportFrame:SetScript("OnEditFocusGained", function(self)
			self:HighlightText();
		end);
		
		-- Clear text
		ArenaAnalyticsScrollFrame.exportFrame:SetScript("OnHide", function(self)
			-- Garbage collect
			self:SetText("");
		end);
	end
end

function ArenaAnalyticsSettingsFrame()
	local paddingLeft = 25;
	ArenaAnalyticsScrollFrame.settingsFrame = CreateFrame("Frame", nil, ArenaAnalyticsScrollFrame, "BasicFrameTemplateWithInset")
    ArenaAnalyticsScrollFrame.settingsFrame:SetPoint("CENTER")
    ArenaAnalyticsScrollFrame.settingsFrame:SetSize(600, 395)
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
    ArenaAnalyticsScrollFrame_skirmishToggleText:SetText("Show Skirmish");
    ArenaAnalyticsScrollFrame.skirmishToggle:SetChecked(ArenaAnalyticsSettings["skirmishIsChecked"]);

    ArenaAnalyticsScrollFrame.skirmishToggle:SetScript("OnClick", 
        function()
            ArenaAnalyticsSettings["skirmishIsChecked"] = ArenaAnalyticsScrollFrame.skirmishToggle:GetChecked();
			ArenaAnalytics:Log("Show Skirmish: ", ArenaAnalyticsSettings["sessionOnly"]);
        	ArenaAnalytics.Filter:refreshFilters();
            ArenaAnalytics.AAtable:forceCompFilterRefresh();
        end
    );

    ArenaAnalyticsScrollFrame.seasonToggle = CreateFrame("CheckButton", "ArenaAnalyticsScrollFrame_seasonToggle", ArenaAnalyticsScrollFrame.settingsFrame, "OptionsSmallCheckButtonTemplate");
    ArenaAnalyticsScrollFrame.seasonToggle:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft, -70);
    ArenaAnalyticsScrollFrame_seasonToggleText:SetText("Show Previous Seasons");
    ArenaAnalyticsScrollFrame.seasonToggle:SetChecked(ArenaAnalyticsSettings["seasonIsChecked"]);

    ArenaAnalyticsScrollFrame.seasonToggle:SetScript("OnClick", function()
		ArenaAnalyticsSettings["seasonIsChecked"] = ArenaAnalyticsScrollFrame.seasonToggle:GetChecked();
		ArenaAnalytics:Log("Show Previous Seasons: ", ArenaAnalyticsSettings["sessionOnly"]);
		ArenaAnalytics.Filter:refreshFilters();
		ArenaAnalytics.AAtable:forceCompFilterRefresh();
	end);

	-- Current session only
    ArenaAnalyticsScrollFrame.sessionToggle = CreateFrame("CheckButton", "ArenaAnalyticsScrollFrame_sessionToggle", ArenaAnalyticsScrollFrame.settingsFrame, "OptionsSmallCheckButtonTemplate");
    ArenaAnalyticsScrollFrame.sessionToggle:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft, -90);
    ArenaAnalyticsScrollFrame_sessionToggleText:SetText("Show Latest Session Only");
    ArenaAnalyticsScrollFrame.sessionToggle:SetChecked(ArenaAnalyticsSettings["sessionOnly"]);

    ArenaAnalyticsScrollFrame.sessionToggle:SetScript("OnClick", function()
		ArenaAnalyticsSettings["sessionOnly"] = ArenaAnalyticsScrollFrame.sessionToggle:GetChecked();
		ArenaAnalytics:Log("Session Only: ", ArenaAnalyticsSettings["sessionOnly"]);
		ArenaAnalytics.Filter:refreshFilters();
		ArenaAnalytics.AAtable:forceCompFilterRefresh();
    end);

    ArenaAnalyticsScrollFrame.outliers = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", 65, -120, "Minimum games required to appear on comp filter");
    ArenaAnalyticsScrollFrame.outliersInput = CreateFrame("EditBox", "exportFrameScroll", ArenaAnalyticsScrollFrame.settingsFrame, "InputBoxTemplate")
    ArenaAnalyticsScrollFrame.outliersInput:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft + 5, -115);
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
	ArenaAnalyticsScrollFrame.compsLimit = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", 65, -145, "Maximum comps to appear in comp filter dropdowns (0 = unlimited)");
    ArenaAnalyticsScrollFrame.compsLimitInput = CreateFrame("EditBox", "exportFrameScroll", ArenaAnalyticsScrollFrame.settingsFrame, "InputBoxTemplate")
    ArenaAnalyticsScrollFrame.compsLimitInput:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft + 5, -140);
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

	ArenaAnalyticsScrollFrame.settingsFiltersTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft, -180, "Data settings");

    ArenaAnalyticsScrollFrame.resetBtn = ArenaAnalytics.AAtable:CreateButton("TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft, -200, "Reset ALL DATA");
    ArenaAnalyticsScrollFrame.resetWarning = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.resetBtn, "TOPRIGHT", 5, -5, "Warning! This will reset all match history");
    ArenaAnalyticsScrollFrame.resetBtn:Disable()
    ArenaAnalyticsScrollFrame.resetBtn:SetDisabledFontObject("GameFontDisableSmall")
    ArenaAnalyticsScrollFrame.resetBtn:SetScript("OnClick", function (i) 
        ArenaAnalyticsDB = {
			["2v2"] = nil,
			["3v3"] = nil,
			["5v5"] = nil,
		};
		ArenaAnalyticsDB = nil;
		
		ArenaAnalytics.filteredMatchHistory = { }
		MatchHistoryDB = { }
		ArenaAnalyticsScrollFrame.allowReset:SetChecked(false);
		ArenaAnalyticsScrollFrame.resetBtn:Disable();
        ArenaAnalytics:Print("Match history deleted!");
		ArenaAnalytics.AAtable:handleArenaCountChanged();
		ArenaAnalytics.AAtable:tryShowimportFrame();
    end);
    
    ArenaAnalyticsScrollFrame.allowReset = CreateFrame("CheckButton", "ArenaAnalyticsScrollFrame_allowReset", ArenaAnalyticsScrollFrame.settingsFrame, "OptionsSmallCheckButtonTemplate");
    ArenaAnalyticsScrollFrame.allowReset:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft, -225);
    ArenaAnalyticsScrollFrame_allowResetText:SetText("Check to enable data reset (big scary button ^)");
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
	
	ArenaAnalyticsScrollFrame.moreOptionsTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft, -265, "More options");

	-- Always show First Death Overlay
    ArenaAnalyticsScrollFrame.deathToggle = CreateFrame("CheckButton", "ArenaAnalyticsScrollFrame_deathToggle", ArenaAnalyticsScrollFrame.settingsFrame, "OptionsSmallCheckButtonTemplate");
    ArenaAnalyticsScrollFrame.deathToggle:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft, -280);
    ArenaAnalyticsScrollFrame_deathToggleText:SetText("Always show red death bg on icon (else on mouse over only)");
    ArenaAnalyticsScrollFrame.deathToggle:SetChecked(ArenaAnalyticsSettings["alwaysShowDeathBg"]);

    ArenaAnalyticsScrollFrame.deathToggle:SetScript("OnClick", 
        function()
            ArenaAnalyticsSettings["alwaysShowDeathBg"] = ArenaAnalyticsScrollFrame.deathToggle:GetChecked();
			ArenaAnalytics.AAtable:RefreshLayout(true); 
        end
    );

	-- Show warning when 
    ArenaAnalyticsScrollFrame.unsavedThreshold = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", 85, -310, "Unsaved games threshold before showing /reload warning.");
    ArenaAnalyticsScrollFrame.unsavedThresholdInput = CreateFrame("EditBox", "exportFrameScroll", ArenaAnalyticsScrollFrame.settingsFrame, "InputBoxTemplate")
    ArenaAnalyticsScrollFrame.unsavedThresholdInput:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft + 5, -305);
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

local events = CreateFrame("Frame");
events:RegisterEvent("ADDON_LOADED");
events:SetScript("OnEvent", ArenaAnalytics.init);

--⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣀⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
--⠀⠀⠀⠀⠀⣀⣤⣶⣿⣿⣿⣿⣿⣿⣿⣷⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
--⠀⠀⢀⣴⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡄⠀⠀⠀⢀⣀⡀⠀⠀⠀⠀⠀
--⠀⠀⠉⠉⠉⠉⠙⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⠀⠀⣰⣿⣿⡃⠀⠀⠀⠀⠀
--⠀⠀⠀⠀⠀⠀⠀⠀ ⢸⣿⣿⣿⣿⣿⣿⣿⣿⡿⠋⣠⣾⣿⣿⣿⣿⣷⣦⠀⠀⠀
--⠀⠀⠀⠀⠀⠀⠀⣠⣾⣿⣿⣿⣿⣿⣿⠟⠋⣀⣼⣿⣿⣿⣿⣿⣿⣀⣿⣇⠀⠀
--⠀⠀⠀⠀⢀⣴⣿⣿⣿⣿⣿⣿⣿⠟⢁⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀
--⠀⠀⠀⣰⣿⣿⣿⣿⣿⣿⣿⣿⠃⣠⣿⣿⣿⣿⣿⣿⣿⣿⡟⠁⠉⠉⠙⠉⠀⠀
--⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⠃⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣄⣀⠀⠀⠀⠀⠀
--⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⢰⣿⣿⣿⣿⠟⠋⣉⣭⣭⣉⠛⠻⠿⠟⠃⠀⠀⠀
--⠀⠀⠸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢃⣴⣿⣿⣿⣿⣿⣷⠀⠀⠀⠀⠀⠀⠀
--⠀⠀⠀⠹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣸⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀
--⠀⠀⠀⠀⠈⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠀⠀⠀⠀⠀⠀⠀⠀
--⠀⠀⠀⠀⠀⠀⠈⠛⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣶⣤⡀⠀⠀⠀⠀⠀⠀
--⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠀⠀⠀⠀⠀⠀