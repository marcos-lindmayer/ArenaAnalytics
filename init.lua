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


local events = CreateFrame("Frame");
events:RegisterEvent("ADDON_LOADED");
events:RegisterEvent("CHAT_MSG_ADDON");
events:SetScript("OnEvent", core.init);