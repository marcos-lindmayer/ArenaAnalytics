local _, ArenaAnalytics = ...; -- Namespace

-- Local module aliases
local Internal = ArenaAnalytics.Internal;
local Localization = ArenaAnalytics.Localization;
local Bitmap = ArenaAnalytics.Bitmap;
local Options = ArenaAnalytics.Options;
local Filters = ArenaAnalytics.Filters;
local FilterTables = ArenaAnalytics.FilterTables;
local API = ArenaAnalytics.API;
local AAtable = ArenaAnalytics.AAtable;
local Events = ArenaAnalytics.Events;
local Search = ArenaAnalytics.Search;
local VersionManager = ArenaAnalytics.VersionManager;
local Selection = ArenaAnalytics.Selection;
local Dropdown = ArenaAnalytics.Dropdown;
local Tooltips = ArenaAnalytics.Tooltips;
local Debug = ArenaAnalytics.Debug;
local MinimapButton = ArenaAnalytics.MinimapButton;
local Commands = ArenaAnalytics.Commands;
local Prints = ArenaAnalytics.Prints;

-------------------------------------------------------------------------

ArenaAnalyticsTransientDB = ArenaAnalyticsTransientDB or {};

-------------------------------------------------------------------------

function ArenaAnalytics.init()
	Debug:Log("Initializing..");

	local startTime = GetTimePreciseSec();

	ArenaAnalytics:InitializeArenaAnalyticsDB();
	Debug:Init();

	-- allows using left and right buttons to move through chat 'edit' box
	for i = 1, NUM_CHAT_WINDOWS do
		_G["ChatFrame"..i.."EditBox"]:SetAltArrowKeyMode(false);
	end

	local successfulRequest = C_ChatInfo.RegisterAddonMessagePrefix("ArenaAnalytics");
	if(not successfulRequest) then
		Debug:Log("Failed to register Addon Message Prefix: 'ArenaAnalytics'!")
	end

	---------------------------------
	-- Initialize modules
	---------------------------------

	Commands:Initialize()
	Bitmap:Initialize();
	Internal:Initialize();
	Localization:Initialize();
	Search:Initialize();
	API:Initialize();
	Options:Init();
	FilterTables:Init();
	Filters:Init();
	Events:Initialize();

	---------------------------------
	-- Version Control
	---------------------------------

	VersionManager:OnInit();

	---------------------------------
	-- Startup
	---------------------------------

	-- Setup surrender commands
	Commands.UpdateSurrenderCommands();
	MinimapButton:Update();

	AAtable:OnLoad();

	-- Version Message (Unused)
	if(IsInInstance() or IsInGroup(1)) then
		--local channel = IsInInstance() and "INSTANCE_CHAT" or "PARTY";
		--local messageSuccess = C_ChatInfo.SendAddonMessage("ArenaAnalytics", UnitGUID("player") .. "_deliver|version#?=" .. version, channel)
	end

	-- Test timing
	local newTime = GetTimePreciseSec();
	local elapsed = 1000 * (newTime - startTime);

	Debug:Log("Initialized in:", elapsed, "ms.", IsLoggedIn());
end

-- Delay the init a frame, to allow all files to be loaded
function ArenaAnalytics:delayedInit(event, name, ...)
	if (name ~= "ArenaAnalytics") then
		return;
	end

	-- Welcome Message
	Prints:PrintWelcomeMessage();

	MinimapButton:Update();

	ArenaAnalyticsScrollFrame:Hide();
	C_Timer.After(0, ArenaAnalytics.init);
end

local initEventFrame = CreateFrame("Frame");
initEventFrame:RegisterEvent("ADDON_LOADED");
initEventFrame:SetScript("OnEvent", ArenaAnalytics.delayedInit);