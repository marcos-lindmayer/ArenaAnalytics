local _, ArenaAnalytics = ...; -- Namespace

local version = "";

function ArenaAnalyticsToggle()
	ArenaAnalytics:Toggle();
end

function ArenaAnalyticsOpenOptions()
	ArenaAnalytics.Options.Open();
end

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
		ArenaAnalytics:Print("Current version: |cffAAAAAAv" .. (ArenaAnalytics:getVersion() or "Nil") .. " (Early Access)|r");
	end,
	
	["total"] = function()
		ArenaAnalytics:Print("Total arenas stored: ", #MatchHistoryDB);
	end,
	
	["played"] = function()
		local totalDurationInArenas = 0;
		local currentSeasonTotalPlayed = 0;
		for i=1, #MatchHistoryDB do
			local match = MatchHistoryDB[i];
			local duration = tonumber(match["duration"]) or 0;
			if(duration > 0) then
				totalDurationInArenas = totalDurationInArenas + duration;

				if(match["season"] == GetCurrentArenaSeason()) then
					currentSeasonTotalPlayed = currentSeasonTotalPlayed + duration;
				end
			end
		end
		-- TODO: Update coloring?
		ArenaAnalytics:Print("Total arena time played: ", SecondsToTime(totalDurationInArenas));
		ArenaAnalytics:Print("Time played this season: ", SecondsToTime(currentSeasonTotalPlayed));
		ArenaAnalytics:Print("Average arena duration: ", SecondsToTime(math.floor(totalDurationInArenas / #MatchHistoryDB)));
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
		ArenaAnalytics:Print("Forcing data version conversion..");
		if(not MatchHistoryDB or #MatchHistoryDB == 0) then
			ArenaAnalytics.VersionManager:convertArenaAnalyticsDBToMatchHistoryDB(); -- 0.3.0
		end
		ArenaAnalytics.VersionManager:renameMatchHistoryDBKeys(); -- 0.5.0
	end,

	["updatesessions"] = function()
		ArenaAnalytics:Print("Updating sessions in MatchHistoryDB.");
		ArenaAnalytics:recomputeSessionsForMatchHistoryDB();

        ArenaAnalyticsScrollFrame:Hide();
	end,

	["updateseasons"] = function()
		ArenaAnalytics:Print("Updating seasons in MatchHistoryDB.");

		for i=1, #MatchHistoryDB do
			local match = MatchHistoryDB[i];
			local season = match and match["season"] or nil;
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

        ArenaAnalyticsScrollFrame:Hide();
	end,

	["updategroupsort"] = function()
		ArenaAnalytics:Print("Updating group sorting in MatchHistoryDB.");

		for i=1, #MatchHistoryDB do
			local match = MatchHistoryDB[i];
			if(match) then
				ArenaAnalytics:SortGroup(match["team"], true);
				ArenaAnalytics:SortGroup(match["enemyTeam"], false);
			end
		end
		
        ArenaAnalyticsScrollFrame:Hide();
	end,

	["debugcleardb"] = function()
		if(ArenaAnalytics.skipDebugLog and ArenaAnalytics.skipDebugForceNilError) then
			ArenaAnalytics:Print("Clearing MatchHistoryDB requires enabling /aa debug. Not intended for users!");
		else -- Debug mode is enabled, allow debug clearing the DB
			if (ArenaAnalytics:hasStoredMatches()) then
				ArenaAnalytics:Log("Clearing MatchHistoryDB.");
				MatchHistoryDB = {}
				ArenaAnalytics.AAtable:tryShowimportDialogFrame(ArenaAnalyticsScrollFrame);
				ArenaAnalytics.Filter:refreshFilters();
				ArenaAnalytics.unsavedArenaCount = 0;
			end
		end
	end,

	["test"] = function()
		local specKeyString = "Mage|Frost";
        local class, spec = specKeyString:match("([^|]+)|(.+)");
        local specID = ArenaAnalytics.Constants:getAddonSpecializationID(class, spec);
		ArenaAnalytics:Log(specID, class, spec)
	end,	
};

local function HandleSlashCommands(str)	
	if (#str == 0) then	
		-- User just entered "/aa" with no additional args.
		ArenaAnalytics:Toggle();
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
ArenaAnalytics.skipDebugLog = false;
function ArenaAnalytics:Log(...)
	if ArenaAnalytics.skipDebugLog then 
		return;
	end

    local hex = "FF6EC7";
    local prefix = string.format("|cff%s%s|r", hex, "ArenaAnalytics (Debug):");
	print(prefix, ...);
end

function ArenaAnalytics:NoFormatting(text)
	return text and text:gsub("|", "||") or "";
end

-- Debug function to force a nil error if input is nil
ArenaAnalytics.skipDebugForceNilError = true;
function ForceDebugNilError(value, forceError)
	if(value == nil) then		
		if(not ArenaAnalytics.skipDebugForceNilError or forceError) then
			local nilOperation = value + 666;
		end
	end
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

function ArenaAnalytics:GetTitleColored(asSingleColor)
	if(asSingleColor) then
		return "|cff"..select(4, ArenaAnalytics:GetThemeColor()).."ArenaAnalytics|r";
	else
		return "Arena|cff"..select(4, ArenaAnalytics:GetThemeColor()).."Analytics|r";
	end
end

local function createMinimapButton()
	-- Create minimap button -- Credit to Leatrix
	local minibtn = CreateFrame("Button", "ArenaAnalyticsMinimapButton", Minimap)
	minibtn:SetFrameLevel(13)
	minibtn:SetSize(24,24)
	minibtn:SetMovable(true)
	minibtn:SetNormalTexture([[Interface\AddOns\ArenaAnalytics\icon\mmicon]])
	--minibtn:SetPushedTexture([[Interface\AddOns\ArenaAnalytics\icon\mmiconP]]) -- FIX: Bugged icon when not mouseover!
	minibtn:SetHighlightTexture([[Interface\AddOns\ArenaAnalytics\icon\mmiconH]])
	minibtn:SetScript("OnEnter", function ()
		ArenaAnalytics.Tooltips:DrawMinimapTooltip();
	end);
	minibtn:SetScript("OnLeave", function ()
		GameTooltip:Hide();
	end);

	local size = 50;
	local minibtnBorder = CreateFrame("Frame", nil, minibtn)
	minibtnBorder:SetSize(size,size)
	minibtnBorder:SetPoint("TOPLEFT");
	local minibtnBorderT = minibtnBorder:CreateTexture()
	minibtnBorderT:SetSize(size,size)
	minibtnBorderT:SetPoint("TOPLEFT", -2, 2);
	minibtnBorderT:SetTexture([[Interface\Minimap\MiniMap-TrackingBorder]])

	ArenaAnalyticsMapIconPos = ArenaAnalyticsMapIconPos or 0
	
	local function SetMinimapIconPosition(angle)
		minibtn:ClearAllPoints();
		local radius = 75;
		minibtn:SetPoint("CENTER", Minimap, "CENTER", -(radius * cos(ArenaAnalyticsMapIconPos)), (radius * sin(ArenaAnalyticsMapIconPos)));
	end

	-- Control movement
	local function UpdateMapBtn()
		local cursorX, cursorY = GetCursorPosition();
		local minX, minY = Minimap:GetLeft(), Minimap:GetBottom();
		cursorX = minX - cursorX / Minimap:GetEffectiveScale() + 70;
		cursorY = cursorY / Minimap:GetEffectiveScale() - minY - 70;
		ArenaAnalyticsMapIconPos = math.deg(math.atan2(cursorY, cursorX));
		
		SetMinimapIconPosition(ArenaAnalyticsMapIconPos);
	end

	-- Set position
	SetMinimapIconPosition(ArenaAnalyticsMapIconPos);

	minibtn:RegisterForClicks("LeftButtonDown", "RightButtonDown");
	minibtn:RegisterForDrag("LeftButton")

	minibtn:SetScript("OnDragStart", function()
		minibtn:StartMoving()
		minibtn:SetScript("OnUpdate", UpdateMapBtn)
	end)
	
	minibtn:SetScript("OnDragStop", function()
		minibtn:StopMovingOrSizing();
		minibtn:SetScript("OnUpdate", nil)
		SetMinimapIconPosition(ArenaAnalyticsMapIconPos);
	end)
	
	-- Control clicks
	minibtn:SetScript("OnClick", function(self, button)
		if(button == "RightButton") then
			-- Open ArenaAnalytics Options
			ArenaAnalytics.Options:Open();
		else
			ArenaAnalytics:Toggle();
		end
	end)
end

function ArenaAnalytics:init()
	-- allows using left and right buttons to move through chat 'edit' box
	for i = 1, NUM_CHAT_WINDOWS do
		_G["ChatFrame"..i.."EditBox"]:SetAltArrowKeyMode(false);
	end

	local version = ArenaAnalytics:getVersion();
	local versionText = version ~= -1 and " (Version: " .. version .. ")" or ""
	ArenaAnalytics:Print("Early Access: Bugs are expected!", "|cffAAAAAA" .. versionText .. "|r");
    ArenaAnalytics:Print("Tracking arena games, gl hf",  UnitName("player") .. "!!");

	if(not ArenaAnalytics.skipDebugLog) then
		ArenaAnalytics:Log("Default Debugging Enabled!");
	end
	
	successfulRequest = C_ChatInfo.RegisterAddonMessagePrefix("ArenaAnalytics");
	if(not successfulRequest) then
		ArenaAnalytics:Log("Failed to register Addon Message Prefix: 'ArenaAnalytics'!")
	end

	----------------------------------
	-- Register Slash Commands
	----------------------------------
	SLASH_AuraTracker1 = "/AA";
	SLASH_AuraTracker2 = "/ArenaAnalytics";
	SlashCmdList.AuraTracker = HandleSlashCommands;

	ArenaAnalytics:updateLastSession();

	ArenaAnalytics.Options:LoadSettings();

	-- Update cached rating as soon as possible
	ArenaAnalytics.Events:CreateEventListenerForRequest("PVP_RATED_STATS_UPDATE", function() 
		ArenaAnalytics.AAmatch:updateCachedBracketRatings();
	end);
	RequestRatedInfo();
	
	-- Try converting old matches to MatchHistoryDB
	ArenaAnalytics.VersionManager:convertArenaAnalyticsDBToMatchHistoryDB();
	ArenaAnalytics.VersionManager:renameMatchHistoryDBKeys();

	ArenaAnalytics.Events:RegisterGlobalEvents();
	ArenaAnalytics.AAtable:OnLoad();
	
	if(IsInInstance() or IsInGroup(1)) then
		local channel = IsInInstance() and "INSTANCE_CHAT" or "PARTY";
		local messageSuccess = C_ChatInfo.SendAddonMessage("ArenaAnalytics", UnitGUID("player") .. "_deliver|version#?=" .. version, channel)
	end

	-- Initialize options menu
	ArenaAnalytics.Options.Initialzie();

	ArenaAnalytics.Filter:resetFilters(false);

	createMinimapButton();

	-- Already in an arena
	if (IsActiveBattlefieldArena()) then
		ArenaAnalytics.Events:RegisterArenaEvents();
		ArenaAnalytics.ArenaTracker:HandleArenaEnter();
	end

	local title = "Bracket";
    local filter = "Filter_Bracket";
    local default = "All"
    local entries = { "All", "2v2", "3v3", "5v5" };
end

-- Delay the init a frame, to allow all files to be loaded
function ArenaAnalytics:delayedInit(event, name, ...)
	if (name ~= "ArenaAnalytics") then return end

	C_Timer.After(0, function() ArenaAnalytics.init() end);
end

local events = CreateFrame("Frame");
events:RegisterEvent("ADDON_LOADED");
events:SetScript("OnEvent", ArenaAnalytics.delayedInit);