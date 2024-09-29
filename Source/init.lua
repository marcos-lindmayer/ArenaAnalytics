local _, ArenaAnalytics = ...; -- Namespace

-- Declare Module Namespaces
ArenaAnalytics.Constants = {};
ArenaAnalytics.SpecSpells = {};
ArenaAnalytics.Localization = {};
ArenaAnalytics.Internal = {};
ArenaAnalytics.Bitmap = {};

ArenaAnalytics.Helpers = {};
ArenaAnalytics.API = {};
ArenaAnalytics.Inspection = {};

ArenaAnalytics.AAtable = {};
ArenaAnalytics.Selection = {};
ArenaAnalytics.ArenaIcon = {};
ArenaAnalytics.Tooltips = {};
ArenaAnalytics.ShuffleTooltip = {};

ArenaAnalytics.Dropdown = {};
ArenaAnalytics.Dropdown.List = {};
ArenaAnalytics.Dropdown.Button = {};
ArenaAnalytics.Dropdown.EntryFrame = {};
ArenaAnalytics.Dropdown.Display = {};

ArenaAnalytics.Options = {};
ArenaAnalytics.AAmatch = {};
ArenaAnalytics.Events = {};
ArenaAnalytics.ArenaTracker = {}
ArenaAnalytics.ArenaMatch = {};
ArenaAnalytics.GroupSorter = {};

ArenaAnalytics.Search = {};
ArenaAnalytics.Filters = {};
ArenaAnalytics.FilterTables = {};

ArenaAnalytics.Export = {};
ArenaAnalytics.Import = {};
ArenaAnalytics.ImportBox = {};
ArenaAnalytics.VersionManager = {};

-- Local module aliases
local Internal = ArenaAnalytics.Internal;
local Bitmap = ArenaAnalytics.Bitmap;
local Options = ArenaAnalytics.Options;
local Filters = ArenaAnalytics.Filters;
local FilterTables = ArenaAnalytics.FilterTables;
local API = ArenaAnalytics.API;
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local AAtable = ArenaAnalytics.AAtable;
local ArenaTracker = ArenaAnalytics.ArenaTracker;
local Events = ArenaAnalytics.Events;

-------------------------------------------------------------------------

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
		ArenaAnalytics:Print("|cff00cc66/aa|r Togggles ArenaAnalytics main panel.");
		ArenaAnalytics:Print("|cff00cc66/aa played|r Prints total duration of tracked arenas.");
		ArenaAnalytics:Print("|cff00cc66/aa version|r Prints the current ArenaAnalytics version.");
		ArenaAnalytics:Print("|cff00cc66/aa total|r Prints total unfiltered matches.");
		print(" ");
	end,

	["version"] = function()
		ArenaAnalytics:Print("Current version: |cffAAAAAAv" .. (API:GetAddonVersion() or "Invalid Version") .. " (Early Access)|r");
	end,

	["total"] = function()
		ArenaAnalytics:Print("Total arenas stored: ", #ArenaAnalyticsDB);
	end,

	["played"] = function()
		local totalDurationInArenas = 0;
		local currentSeasonTotalPlayed = 0;
		for i=1, #ArenaAnalyticsDB do
			local match = ArenaAnalyticsDB[i];
			local duration = ArenaMatch:GetDuration(match) or 0;
			if(duration > 0) then
				totalDurationInArenas = totalDurationInArenas + duration;

				if(ArenaMatch:GetSeason(match) == GetCurrentArenaSeason()) then
					currentSeasonTotalPlayed = currentSeasonTotalPlayed + duration;
				end
			end
		end
		-- TODO: Update coloring?
		ArenaAnalytics:Print("Total arena time played: ", SecondsToTime(totalDurationInArenas));
		ArenaAnalytics:Print("Time played this season: ", SecondsToTime(currentSeasonTotalPlayed));
		ArenaAnalytics:Print("Average arena duration: ", SecondsToTime(math.floor(totalDurationInArenas / #ArenaAnalyticsDB)));
	end,

	-- Debug command to 
	["debug"] = function()
		if(not Options:Get("debuggingEnabled")) then
			Options:Set("debuggingEnabled", true);
			ArenaAnalytics:Log("Debugging enabled!");
		else
			Options:Set("debuggingEnabled", false);
			ArenaAnalytics:Print("Debugging disabled!");
		end
	end,

	["convert"] = function()
		ArenaAnalytics:Print("Forcing data version conversion..");
		if(not ArenaAnalyticsDB or #ArenaAnalyticsDB == 0) then
			ArenaAnalytics.VersionManager:convertArenaAnalyticsDBToMatchHistoryDB(); -- 0.3.0
			ArenaAnalytics.VersionManager:renameMatchHistoryDBKeys(); -- 0.5.0
			ArenaAnalytics.VersionManager:ConvertMatchHistoryDBToNewArenaAnalyticsDB(); -- 0.7.0
			ArenaAnalytics.VersionManager:FinalizeConversionAttempts();
		end
        ArenaAnalyticsScrollFrame:Hide();
	end,

	["updatesessions"] = function()
		ArenaAnalytics:Print("Updating sessions in ArenaAnalyticsDB.");
		ArenaAnalytics:RecomputeSessionsForMatchHistory();

        ArenaAnalyticsScrollFrame:Hide();
	end,

	["updateseasons"] = function()
		ArenaAnalytics:Print("Updating seasons in ArenaAnalyticsDB.");

		for i=1, #ArenaAnalyticsDB do
			local match = ArenaAnalyticsDB[i];
			local season = ArenaMatch:GetSeason(match);
			local matchDate = ArenaMatch:GetDate(match);

			if(not season or season == 0) then
				season = ArenaAnalytics:computeSeasonFromMatchDate(matchDate);
				if(season) then
					ArenaAnalytics:Log("Updated season at index: ", i, " to season: ", season);
					ArenaMatch:SetSeason(match, season);
				else
					local formattedDate = tonumber(matchDate) and date("%d/%m/%y %H:%M:%S", matchDate);
					ArenaAnalytics:Log("Updating seasons got nil season for date: ", formattedDate, " (", matchDate, ")");
				end
			end
		end

        ArenaAnalyticsScrollFrame:Hide();
	end,

	["updategroupsort"] = function()
		ArenaAnalytics:Print("Updating group sorting in ArenaAnalyticsDB.");

		ArenaAnalytics:ResortGroupsInMatchHistory();
		
        ArenaAnalyticsScrollFrame:Hide();
	end,

	["debugcleardb"] = function()
		if(not Options:Get("debuggingEnabled")) then
			ArenaAnalytics:Print("Clearing ArenaAnalyticsDB requires enabling |cffBBBBBB/aa debug|r. Not intended for users!");
		else -- Debug mode is enabled, allow debug clearing the DB
			if (ArenaAnalytics:HasStoredMatches()) then
				ArenaAnalytics:Log("Clearing ArenaAnalyticsDB.");
				ArenaAnalytics:PurgeArenaAnalyticsDB();
				ArenaAnalytics.AAtable:TryShowimportDialogFrame(ArenaAnalyticsScrollFrame);

				ArenaAnalytics.Filters:Refresh();
				ArenaAnalytics.unsavedArenaCount = 0;
			end
		end
	end,

	-- Debugging: Used for temporary explicit triggering of logic, for testing purposes.
	["dumprealms"] = function()
		print(" ");
		ArenaAnalytics:Print(" ================================================  ");
		ArenaAnalytics:Print("  Known Realms:     (Current realm: " .. (ArenaAnalytics:GetLocalRealmIndex() or "").. ")");

		for i,realm in ipairs(ArenaAnalyticsDB.realms) do
			ArenaAnalytics:Print("     ", i, "   ", realm);
		end
		ArenaAnalytics:Print("  ================================================  ");
		print(" ");
	end,

	-- Debugging: Used for temporary explicit triggering of logic, for testing purposes.
	["test"] = function()
		print(" ");
		ArenaAnalytics:Print(" ================================================  ");
		
		local total, count = 0,0;
		for i,name in ipairs(ArenaAnalyticsDB.names) do
			total = total + #name;
			count = count + 1;
		end
		ArenaAnalytics:Log(total / count)

		print(" ");
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
function ArenaAnalytics:LogSpacer()
	if not ArenaAnalyticsSharedSettingsDB["debuggingEnabled"] then
		return;
	end

	print(" ");
end

function ArenaAnalytics:Log(...)
	if not ArenaAnalyticsSharedSettingsDB["debuggingEnabled"] then
		return;
	end

    local hex = "FF6EC7";
    local prefix = string.format("|cff%s%s|r", hex, "ArenaAnalytics (Debug):");
	print(prefix, ...);
end

function ArenaAnalytics:NoFormatting(text)
	return text and text:gsub("|", "||") or "";
end

-- Assert if debug is enabled. Returns value to allow wrapping within if statements.
function ArenaAnalyticsDebugAssert(value, msg)
	if(Options:Get("debuggingEnabled")) then
		assert(value, "Debug Assertion failed! " .. (msg or ""));
	end
	return value;
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
	local hex = select(4, ArenaAnalytics:GetThemeColor());

	if(asSingleColor) then
		return "|cff".. hex .."ArenaAnalytics|r";
	else
		return "Arena|cff".. hex .."Analytics|r";
	end
end

local function createMinimapButton()
	-- Create minimap button -- Credit to Leatrix
	local minimapButton = CreateFrame("Button", "ArenaAnalyticsMinimapButton", Minimap);
	minimapButton:SetFrameLevel(13);
	minimapButton:SetSize(25,25);
	minimapButton:SetMovable(true);
	minimapButton:SetNormalTexture("Interface\\AddOns\\ArenaAnalytics\\icon\\mmicon");
	minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight");

	local size = 50;
	minimapButton.Border = CreateFrame("Frame", nil, minimapButton)
	minimapButton.Border:SetSize(size,size);
	minimapButton.Border:SetPoint("CENTER", minimapButton, "CENTER");

	minimapButton.Border.texture = minimapButton.Border:CreateTexture();
	minimapButton.Border.texture:SetSize(size,size);
	minimapButton.Border.texture:SetPoint("TOPLEFT", 9.5, -9.5);
	minimapButton.Border.texture:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder");

	minimapButton:SetScript("OnEnter", function ()
		ArenaAnalytics.Tooltips:DrawMinimapTooltip();
	end);

	minimapButton:SetScript("OnLeave", function ()
		GameTooltip:Hide();
	end);

	ArenaAnalyticsMapIconPos = ArenaAnalyticsMapIconPos or 0;

	local function SetMinimapIconPosition(angle)
		minimapButton:ClearAllPoints();
		local radius = (Minimap:GetWidth() / 2) + 5
		local xOffset = radius * cos(angle);
		local yOffset = radius * sin(angle);
		minimapButton:SetPoint("CENTER", Minimap, "CENTER", xOffset, yOffset);
	end

	-- Control movement
	local function UpdateMapBtn()
		local cursorX, cursorY = GetCursorPosition();
		local scale = UIParent:GetEffectiveScale() or 1;
		cursorX = cursorX / scale;
		cursorY = cursorY / scale;
	
		local radius = (Minimap:GetWidth() / 2) + 5

		local centerX, centerY = Minimap:GetCenter();
		local angle = math.atan2(cursorY - centerY, cursorX - centerX);
		ArenaAnalyticsMapIconPos = math.deg(angle);
		
		SetMinimapIconPosition(ArenaAnalyticsMapIconPos);
	end

	-- Set position
	SetMinimapIconPosition(ArenaAnalyticsMapIconPos);

	minimapButton:RegisterForClicks("LeftButtonDown", "RightButtonDown");
	minimapButton:RegisterForDrag("LeftButton")

	minimapButton:SetScript("OnDragStart", function()
		minimapButton:StartMoving()
		minimapButton:SetScript("OnUpdate", UpdateMapBtn)
	end)
	
	minimapButton:SetScript("OnDragStop", function()
		minimapButton:StopMovingOrSizing();
		minimapButton:SetScript("OnUpdate", nil)
		SetMinimapIconPosition(ArenaAnalyticsMapIconPos);
	end)
	
	-- Control clicks
	minimapButton:SetScript("OnClick", function(self, button)
		if(button == "RightButton") then
			-- Open ArenaAnalytics Options
			Options:Open();
		else
			ArenaAnalytics:Toggle();
		end
	end)
end

function ArenaAnalytics:init()
	ArenaAnalytics:Log("Initializing..");

	-- Initialize databases
	ArenaAnalyticsDB = ArenaAnalyticsDB or {};
	ArenaAnalyticsDB.names = ArenaAnalyticsDB.names or {};
	ArenaAnalyticsDB.realms = ArenaAnalyticsDB.realms or {};

	-- allows using left and right buttons to move through chat 'edit' box
	for i = 1, NUM_CHAT_WINDOWS do
		_G["ChatFrame"..i.."EditBox"]:SetAltArrowKeyMode(false);
	end

	local version = API:GetAddonVersion();
	local versionText = version ~= -1 and " (Version: " .. version .. ")" or ""
	ArenaAnalytics:Print("Early Access: Bugs are expected!", "|cffAAAAAA" .. versionText .. "|r");
    ArenaAnalytics:Print("Tracking arena games, gl hf",  UnitName("player") .. "!!");

	if(Options:Get("debuggingEnabled")) then
		ArenaAnalytics:Log("Debugging Enabled! |cffBBBBBB/aa debug to disable.|r ");
	end
	
	successfulRequest = C_ChatInfo.RegisterAddonMessagePrefix("ArenaAnalytics");
	if(not successfulRequest) then
		ArenaAnalytics:Log("Failed to register Addon Message Prefix: 'ArenaAnalytics'!")
	end

	---------------------------------
	-- Register Slash Commands
	---------------------------------
	SLASH_AuraTracker1 = "/AA";
	SLASH_AuraTracker2 = "/ArenaAnalytics";
	SlashCmdList.AuraTracker = HandleSlashCommands;

	---------------------------------
	-- Version Control
	---------------------------------

	ArenaAnalytics.VersionManager:OnInit();

	---------------------------------
	-- Initialize modules
	---------------------------------

	ArenaAnalytics:TryFixLastMatchRating();

	Bitmap:Initialize();
	API:Initialize();
	Internal:Initialize();
	Options:Init();
	FilterTables:Init();
	Filters:Init();

	ArenaAnalytics:UpdateLastSession();

	Events:RegisterGlobalEvents();

	-- Update cached rating as soon as possible, through PVP_RATED_STATS_UPDATE event
	RequestRatedInfo();
	
	AAtable:OnLoad();
	
	if(IsInInstance() or IsInGroup(1)) then
		local channel = IsInInstance() and "INSTANCE_CHAT" or "PARTY";
		local messageSuccess = C_ChatInfo.SendAddonMessage("ArenaAnalytics", UnitGUID("player") .. "_deliver|version#?=" .. version, channel)
	end

	createMinimapButton();

	-- Already in an arena
	if (not API:IsInArena()) then
		ArenaTracker:Clear();
	end
end

-- Delay the init a frame, to allow all files to be loaded
function ArenaAnalytics:delayedInit(event, name, ...)
	if (name ~= "ArenaAnalytics") then 
		return;
	end

	C_Timer.After(1, function() ArenaAnalytics.init() end);
end

local events = CreateFrame("Frame");
events:RegisterEvent("ADDON_LOADED");
events:SetScript("OnEvent", ArenaAnalytics.delayedInit);