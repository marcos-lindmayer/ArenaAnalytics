local _, core = ...; -- Namespace

--------------------------------------
-- Custom Slash Command
--------------------------------------
core.commands = {	
	["help"] = function()
		print(" ");
		core:Print("List of slash commands:");
		core:Print("|cff00cc66/aa|r");
		core:Print("|cff00cc66/aa more|r");
		print(" ");
	end,
	
	-- TODO remove
	["more"] = function()
		core:Print("Wanna get more data? Web project coming soon...");
	end,

	["chat"] = function(...)
		local prefix = "ArenaAnalytics"
		C_ChatInfo.RegisterAddonMessagePrefix(prefix)
		local addonMessage = strjoin(" ", ...)
		C_ChatInfo.SendAddonMessage(prefix, addonMessage, "WHISPER", UnitName("player"))
	end,
};

local function HandleSlashCommands(str)	
	if (#str == 0) then	
		-- User just entered "/aa" with no additional args.
		core.arenaTable.Toggle();
		return;		
	end	
	
	local args = {};
	for _, arg in ipairs({ string.split(' ', str) }) do
		if (#arg > 0) then
			table.insert(args, arg);
		end
	end
	
	local path = core.commands; -- required for updating found table.
	
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
				core.commands.help();
				return;
			end
		end
	end
end

function core:Print(...)
    local hex = select(4, self.Config:GetThemeColor());
    local prefix = string.format("|cff%s%s|r", hex:upper(), "ArenaAnalytics:");	
    DEFAULT_CHAT_FRAME:AddMessage(string.join(" ", prefix, ...));
end

local function createMinimapButton()
	-- Create minimap button -- Credit to Leatrix
	local minibtn = CreateFrame("Button", "ArenaAnalyticsMinimapButton", Minimap)
	minibtn:SetFrameLevel(8)
	minibtn:SetSize(24,24)
	minibtn:SetMovable(true)
	minibtn:SetNormalTexture([[Interface\AddOns\ArenaAnalytics\icon\mmicon]])
	minibtn:SetPushedTexture([[Interface\AddOns\ArenaAnalytics\icon\mmicon]])
	minibtn:SetPushedTexture([[Interface\AddOns\ArenaAnalytics\icon\mmiconP]])
	minibtn:SetHighlightTexture([[Interface\AddOns\ArenaAnalytics\icon\mmiconH]])
	minibtn:SetScript("OnEnter", function ()
		GameTooltip:SetOwner(ArenaAnalyticsMinimapButton, "ANCHOR_BOTTOMLEFT");
		local hex = select(4, core.Config:GetThemeColor());
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
	minibtnBorderT:SetPoint("TOPLEFT");
	minibtnBorderT:SetTexture([[Interface\Minimap\MiniMap-TrackingBorder]])

	ArenaAnalyticsMapIconPos = ArenaAnalyticsMapIconPos and ArenaAnalyticsMapIconPos or 0
	
	-- Control movement
	local function UpdateMapBtn()
		local Xpoa, Ypoa = GetCursorPosition()
		local Xmin, Ymin = Minimap:GetLeft(), Minimap:GetBottom()
		Xpoa = Xmin - Xpoa / Minimap:GetEffectiveScale() + 70
		Ypoa = Ypoa / Minimap:GetEffectiveScale() - Ymin - 70
		ArenaAnalyticsMapIconPos = math.deg(math.atan2(Ypoa, Xpoa))
		minibtn:ClearAllPoints()
		minibtn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - (80 * cos(ArenaAnalyticsMapIconPos)), (80 * sin(ArenaAnalyticsMapIconPos)) - 52)
	end
	
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
	
	-- Set position
	minibtn:ClearAllPoints();
	minibtn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - (80 * cos(ArenaAnalyticsMapIconPos)),(80 * sin(ArenaAnalyticsMapIconPos)) - 52)
	
	-- Control clicks
	minibtn:SetScript("OnClick", function()
		core.arenaTable.Toggle()
	end)

end

function core:init(event, name, ...)
	if (name ~= "ArenaAnalytics") then return end 
	
	if (event == "CHAT_MSG_ADDON") then
		print(event, name, ...)
		return;
	end

	-- allows using left and right buttons to move through chat 'edit' box
	for i = 1, NUM_CHAT_WINDOWS do
		_G["ChatFrame"..i.."EditBox"]:SetAltArrowKeyMode(false);
	end
	
	----------------------------------
	-- Register Slash Commands
	----------------------------------

	SLASH_AuraTracker1 = "/aa";
	SLASH_AuraTracker2 = "/arenaanalytics";
	SlashCmdList.AuraTracker = HandleSlashCommands;

	core:Print("Testing version");
    core:Print("Tracking arena games, gl hf",  UnitName("player") .. "!!");
	core.Config.EventRegister();
	core.arenaTable.OnLoad();
	createMinimapButton();


end

function ArenaAnalyticsSettingsFrame()

	local paddingLeft = 25;
	ArenaAnalyticsScrollFrame.settingsFrame = CreateFrame("Frame", nil, ArenaAnalyticsScrollFrame, "BasicFrameTemplateWithInset")
    ArenaAnalyticsScrollFrame.settingsFrame:SetPoint("CENTER")
    ArenaAnalyticsScrollFrame.settingsFrame:SetSize(600, 300)
    ArenaAnalyticsScrollFrame.settingsFrame:SetFrameStrata("HIGH");
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
            core.arenaTable:RefreshLayout(true);
            ArenaAnalyticsCheckForFilterUpdate("2v2")
        end
    );

    ArenaAnalyticsScrollFrame.seasonToggle = CreateFrame("CheckButton", "ArenaAnalyticsScrollFrame_seasonToggle", ArenaAnalyticsScrollFrame.settingsFrame, "OptionsSmallCheckButtonTemplate");
    ArenaAnalyticsScrollFrame.seasonToggle:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft, -70);
    ArenaAnalyticsScrollFrame_seasonToggleText:SetText("Show Previous Seasons");
    ArenaAnalyticsScrollFrame.seasonToggle:SetChecked(ArenaAnalyticsSettings["seasonIsChecked"]);

    ArenaAnalyticsScrollFrame.seasonToggle:SetScript("OnClick", 
        function()
            ArenaAnalyticsSettings["seasonIsChecked"] = ArenaAnalyticsScrollFrame.seasonToggle:GetChecked();
            core.arenaTable:RefreshLayout(true);
            ArenaAnalyticsCheckForFilterUpdate("2v2")
        end
    );

    ArenaAnalyticsScrollFrame.outliers = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", 65, -100, "Min games required to appear on comp filter");
    ArenaAnalyticsScrollFrame.outliersInput = CreateFrame("EditBox", "exportFrameScroll", ArenaAnalyticsScrollFrame.settingsFrame, "InputBoxTemplate")
    ArenaAnalyticsScrollFrame.outliersInput:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft + 5, -95);
    ArenaAnalyticsScrollFrame.outliersInput:SetFrameStrata("HIGH");
    ArenaAnalyticsScrollFrame.outliersInput:SetWidth(30);
    ArenaAnalyticsScrollFrame.outliersInput:SetHeight(20);
    ArenaAnalyticsScrollFrame.outliersInput:SetNumeric();
    ArenaAnalyticsScrollFrame.outliersInput:SetAutoFocus(false);
    ArenaAnalyticsScrollFrame.outliersInput:SetMaxLetters(3);
    ArenaAnalyticsScrollFrame.outliersInput:SetText(ArenaAnalyticsSettings["outliers"])
    
    ArenaAnalyticsScrollFrame.outliersInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus();
        core.arenaTable:RefreshLayout(true);
        ArenaAnalyticsCheckForFilterUpdate("2v2")
        ArenaAnalyticsCheckForFilterUpdate("3v3")
        ArenaAnalyticsCheckForFilterUpdate("5v5")
    end);
    ArenaAnalyticsScrollFrame.outliersInput:SetScript("OnEscapePressed", function(self)
        self:ClearFocus();
        core.arenaTable:RefreshLayout(true);
        ArenaAnalyticsCheckForFilterUpdate("2v2")
        ArenaAnalyticsCheckForFilterUpdate("3v3")
        ArenaAnalyticsCheckForFilterUpdate("5v5")
    end);

    ArenaAnalyticsScrollFrame.outliersInput:SetScript("OnTextChanged", function(self)
        ArenaAnalyticsSettings["outliers"] = ArenaAnalyticsScrollFrame.outliersInput:GetText()
    end);

	ArenaAnalyticsScrollFrame.settingsFiltersTitle = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft, -135, "Data settings");


    ArenaAnalyticsScrollFrame.resetBtn = core.arenaTable:CreateButton("TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft, -155, "Reset ALL DATA");
    ArenaAnalyticsScrollFrame.resetWarning = ArenaAnalyticsCreateText(ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", ArenaAnalyticsScrollFrame.resetBtn, "TOPRIGHT", 5, -5, "Warning! This will reset all match history");
    ArenaAnalyticsScrollFrame.resetBtn:Disable()
    ArenaAnalyticsScrollFrame.resetBtn:SetDisabledFontObject("GameFontDisableSmall")
    ArenaAnalyticsScrollFrame.resetBtn:SetScript("OnClick", function (i) 
        ArenaAnalyticsDB = {}; 
        print("ArenaAnalytics match history deleted!");
        core.arenaTable:RefreshLayout(true); 
    end);
    
    ArenaAnalyticsScrollFrame.allowReset = CreateFrame("CheckButton", "ArenaAnalyticsScrollFrame_allowReset", ArenaAnalyticsScrollFrame.settingsFrame, "OptionsSmallCheckButtonTemplate");
    ArenaAnalyticsScrollFrame.allowReset:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame.settingsFrame, "TOPLEFT", paddingLeft, -180);
    ArenaAnalyticsScrollFrame_allowResetText:SetText("Check to enable data reset");
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
end


local events = CreateFrame("Frame");
events:RegisterEvent("ADDON_LOADED");
events:RegisterEvent("CHAT_MSG_ADDON");
events:SetScript("OnEvent", core.init);