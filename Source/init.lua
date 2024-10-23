local _, ArenaAnalytics = ...; -- Namespace

-- Declare Module Namespaces
ArenaAnalytics.Constants = {};
ArenaAnalytics.SpecSpells = {};
ArenaAnalytics.Localization = {};
ArenaAnalytics.Internal = {};
ArenaAnalytics.Bitmap = {};
ArenaAnalytics.TablePool = {};

ArenaAnalytics.Helpers = {};
ArenaAnalytics.API = {};
ArenaAnalytics.Inspection = {};

ArenaAnalytics.AAtable = {};
ArenaAnalytics.Selection = {};
ArenaAnalytics.ArenaIcon = {};
ArenaAnalytics.Tooltips = {};
ArenaAnalytics.ShuffleTooltip = {};
ArenaAnalytics.PlayerTooltip = {};
ArenaAnalytics.ImportProgressFrame = {};

ArenaAnalytics.Dropdown = {};
ArenaAnalytics.Dropdown.List = {};
ArenaAnalytics.Dropdown.Button = {};
ArenaAnalytics.Dropdown.EntryFrame = {};
ArenaAnalytics.Dropdown.Display = {};

ArenaAnalytics.Options = {};
ArenaAnalytics.AAmatch = {};
ArenaAnalytics.Events = {};
ArenaAnalytics.ArenaTracker = {};
ArenaAnalytics.Sessions = {};
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
local Sessions = ArenaAnalytics.Sessions;
local ArenaTracker = ArenaAnalytics.ArenaTracker;
local AAtable = ArenaAnalytics.AAtable;
local Events = ArenaAnalytics.Events;
local Search = ArenaAnalytics.Search;
local VersionManager = ArenaAnalytics.VersionManager;
local Debug = ArenaAnalytics.Debug;

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
		ArenaAnalytics:Print("|cff00cc66/aa purge|r Show dialog to permanently delete match history.");
		ArenaAnalytics:Print("|cff00cc66/aa credits|r Print addon credits.");
		print(" ");
	end,

	["credits"] = function()
		ArenaAnalytics:Print("ArenaAnalytics authors: Lingo, Zeetrax.   Developed in association with Hydra. www.twitch.tv/Hydramist");
	end,

	["version"] = function()
		ArenaAnalytics:Print("Current version: |cffAAAAAAv" .. (API:GetAddonVersion() or "Invalid Version") .. "|r");
	end,

	["total"] = function()
		ArenaAnalytics:Print("Total arenas stored: ", #ArenaAnalyticsDB);
	end,

	["played"] = function()
		local totalDurationInArenas = 0;
		local currentSeasonTotalPlayed = 0;
		local longestDuration = 0;
		for i=1, #ArenaAnalyticsDB do
			local match = ArenaAnalyticsDB[i];
			local duration = ArenaMatch:GetDuration(match) or 0;
			if(duration > 0) then
				totalDurationInArenas = totalDurationInArenas + duration;

				if(duration < 2760) then -- Only count valid duration (plus 60sec buffer)
					longestDuration = max(longestDuration, duration);
				end

				if(ArenaMatch:GetSeason(match) == GetCurrentArenaSeason()) then
					currentSeasonTotalPlayed = currentSeasonTotalPlayed + duration;
				end
			end
		end

		-- TODO: Update coloring?
		ArenaAnalytics:Print("Total arena time played: ", SecondsToTime(totalDurationInArenas));
		ArenaAnalytics:Print("Time played this season: ", SecondsToTime(currentSeasonTotalPlayed));
		ArenaAnalytics:Print("Average arena duration: ", SecondsToTime(math.floor(totalDurationInArenas / #ArenaAnalyticsDB)));
		ArenaAnalytics:Print("Longest arena duration: ", SecondsToTime(math.floor(longestDuration)));
	end,

	-- Debug command to 
	["debug"] = function(level)
		Debug:SetDebugLevel(level);
	end,

	["convert"] = function()
		ArenaAnalytics:Print("Forcing data version conversion..");
		if(not ArenaAnalyticsDB or #ArenaAnalyticsDB == 0) then
			VersionManager:OnInit();
		end
        ArenaAnalyticsScrollFrame:Hide();
	end,

	["updatesessions"] = function()
		ArenaAnalytics:Print("Updating sessions in ArenaAnalyticsDB.");
		Sessions:RecomputeSessionsForMatchHistory();

        ArenaAnalyticsScrollFrame:Hide();
	end,

	["updategroupsort"] = function()
		ArenaAnalytics:Print("Updating group sorting in ArenaAnalyticsDB.");

		ArenaAnalytics:ResortGroupsInMatchHistory();
		
        ArenaAnalyticsScrollFrame:Hide();
	end,

	["purge"] = function()
		ArenaAnalytics:ShowPurgeConfirmationDialog();
	end,

	["debugcleardb"] = function()
		if(ArenaAnalytics:GetDebugLevel() == 0) then
			ArenaAnalytics:Print("Clearing ArenaAnalyticsDB requires debugging enabled.  |cffBBBBBB/aa debug|r. Not intended for users!");
		else -- Debug mode is enabled, allow debug clearing the DB
			if (ArenaAnalytics:HasStoredMatches()) then
				ArenaAnalytics:Log("Purging ArenaAnalyticsDB.");
				ArenaAnalytics:PurgeArenaAnalyticsDB();
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
	["test"] = function(...)
		print(" ");
		ArenaAnalytics:Print(" ================================================  ");

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

-------------------------------------------------------------------------

function ArenaAnalytics:Print(...)
    local hex = select(4, ArenaAnalytics:GetThemeColor());
    local prefix = string.format("|cff%s%s|r", hex:upper(), "ArenaAnalytics:");
    -- DEFAULT_CHAT_FRAME:AddMessage(string.join(" ", prefix, ...));
	print(prefix, ...);
end

-------------------------------------------------------------------------

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

local function CreateMinimapButton()
	-- Create minimap button -- Credit to Leatrix
	minimapButton = CreateFrame("Button", "ArenaAnalyticsMinimapButton", Minimap);
	minimapButton:SetParent(Minimap);
	minimapButton:SetFrameLevel(13);
	minimapButton:SetSize(25,25);
	minimapButton:SetMovable(true);
	minimapButton:SetNormalTexture("Interface\\AddOns\\ArenaAnalytics\\icon\\mmicon");
	minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight");

	local size = 50;
	minimapButton.Border = CreateFrame("Frame", nil, minimapButton);
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

		local radius = (Minimap:GetWidth() / 2) + 5;

		local centerX, centerY = Minimap:GetCenter();
		local angle = math.atan2(cursorY - centerY, cursorX - centerX);
		ArenaAnalyticsMapIconPos = math.deg(angle);

		SetMinimapIconPosition(ArenaAnalyticsMapIconPos);
	end

	-- Set position
	SetMinimapIconPosition(ArenaAnalyticsMapIconPos);

	minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	minimapButton:RegisterForDrag("LeftButton");

	minimapButton:SetScript("OnDragStart", function()
		minimapButton:StartMoving();
		minimapButton:SetScript("OnUpdate", UpdateMapBtn);
	end);

	minimapButton:SetScript("OnDragStop", function()
		minimapButton:StopMovingOrSizing();
		minimapButton:SetScript("OnUpdate", nil)
		SetMinimapIconPosition(ArenaAnalyticsMapIconPos);
	end);

	-- Control clicks
	minimapButton:SetScript("OnClick", function(self, button)
		if(button == "RightButton") then
			-- Open ArenaAnalytics Options
			Options:Open();
		else
			ArenaAnalytics:Toggle();
		end
	end);
end

function ArenaAnalytics:init()
	ArenaAnalytics:Log("Initializing..");

	-- allows using left and right buttons to move through chat 'edit' box
	for i = 1, NUM_CHAT_WINDOWS do
		_G["ChatFrame"..i.."EditBox"]:SetAltArrowKeyMode(false);
	end

	local version = API:GetAddonVersion();
	local versionText = version ~= -1 and " (Version: " .. version .. ")" or ""
    ArenaAnalytics:Print("Tracking arena games, gl hf",  UnitName("player") .. "!!");
	
	Debug:OnLoad();

	successfulRequest = C_ChatInfo.RegisterAddonMessagePrefix("ArenaAnalytics");
	if(not successfulRequest) then
		ArenaAnalytics:Log("Failed to register Addon Message Prefix: 'ArenaAnalytics'!")
	end

	---------------------------------
	-- Register Slash Commands
	---------------------------------
	SLASH_ArenaAnalyticsCommands1 = "/AA";
	SLASH_ArenaAnalyticsCommands2 = "/ArenaAnalytics";
	SlashCmdList.ArenaAnalyticsCommands = HandleSlashCommands;
	
	if(API:HasSurrenderAPI()) then
		-- Override /afk to surrender in arenas
		SlashCmdList.CHAT_AFK = function(message)
			local surrendered = API:TrySurrenderArena();
			if(surrendered == nil) then
				-- Fallback to base /afk
				SendChatMessage(message, "AFK");
			end
		end

		-- /gg to surrender
		SLASH_ArenaAnalyticsSurrender1 = "/gg";
		SlashCmdList.ArenaAnalyticsSurrender = function(msg)
			ArenaAnalytics:Log("/gg triggered.");
			local surrendered = API:TrySurrenderArena();
		end
	end

	---------------------------------
	-- Initialize modules
	---------------------------------

	Bitmap:Initialize();
	Internal:Initialize();
	ArenaAnalytics:InitializeArenaAnalyticsDB();
	Search:Initialize();
	API:Initialize();
	Options:Init();
	FilterTables:Init();
	Filters:Init();

	---------------------------------
	-- Version Control
	---------------------------------

	VersionManager:OnInit();	

	---------------------------------
	-- Startup
	---------------------------------

	ArenaAnalytics:TryFixLastMatchRating();
	Events:RegisterGlobalEvents();

	-- Update cached rating as soon as possible, through PVP_RATED_STATS_UPDATE event
	RequestRatedInfo();
	
	AAtable:OnLoad();
	
	if(IsInInstance() or IsInGroup(1)) then
		local channel = IsInInstance() and "INSTANCE_CHAT" or "PARTY";
		local messageSuccess = C_ChatInfo.SendAddonMessage("ArenaAnalytics", UnitGUID("player") .. "_deliver|version#?=" .. version, channel)
	end

	-- Already in an arena
	if (not API:IsInArena() and ArenaAnalyticsDB.currentArena) then
		ArenaTracker:Clear();
	end
end

-- Delay the init a frame, to allow all files to be loaded
function ArenaAnalytics:delayedInit(event, name, ...)
	if (name ~= "ArenaAnalytics") then 
		return;
	end
	
	CreateMinimapButton();

	ArenaAnalyticsScrollFrame:Hide();
	C_Timer.After(1, function() ArenaAnalytics.init() end);
end

local events = CreateFrame("Frame");
events:RegisterEvent("ADDON_LOADED");
events:SetScript("OnEvent", ArenaAnalytics.delayedInit);