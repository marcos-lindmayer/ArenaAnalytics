local _, ArenaAnalytics = ...; -- Namespace
local Initialization = ArenaAnalytics.Initialization;

-- Local module aliases
local ArenaID = ArenaAnalytics.ArenaID;
local LocalizationTables = ArenaAnalytics.LocalizationTables;
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
local ArenaTracker = ArenaAnalytics.ArenaTracker;
local Debug = ArenaAnalytics.Debug;
local MinimapButton = ArenaAnalytics.MinimapButton;
local Commands = ArenaAnalytics.Commands;
local Prints = ArenaAnalytics.Prints;

-------------------------------------------------------------------------
-- This file always must be loaded last,
-- ensuring all modules functions has been declared
-------------------------------------------------------------------------

-- Await VARIABLES_LOADED and other early events
ArenaAnalyticsScrollFrame:Hide();
Events:Initialize();

-- Initialization state
Initialization.locked = false;
Initialization.lastStep = 0;

Initialization.receivedEvents = {}

local initializationStages = {
	{ step = 1, func = "Step1_AddonLoaded", event = "ADDON_LOADED" },
	{ step = 2, func = "Step2_VariablesLoaded", event = "VARIABLES_LOADED" },
	{ step = 3, func = "Step3_PlayerLogin", event = "PLAYER_LOGIN" },
	{ step = 4, func = "Step4_EnteringWorld", event = "PLAYER_ENTERING_WORLD" },
	{ step = 5, func = "Step5_InitiateTracking", event = "UPDATE_BATTLEFIELD_STATUS" },

	-- This must always come last, and none above may be blocking forever
	{ func = "Step6_LoadComplete" },
};

local stages = {};

function Initialization:HandleLoadEvents(event, ...)
	assert(event);

	if(Initialization.hasLoaded) then
		return;
	end

	if(Initialization.receivedEvents[event]) then
		Debug:LogError("Initialization event received twice:", event, "!", ...);
		return;
	end
	Initialization.receivedEvents[event] = true;

	--Debug:LogGreen("Initialization:HandleLoadEvent:", event, ...); -- TODO: Check critical APIs at different events?

	-- Try the next step if state is currently unlocked
	Initialization:TryAdvanceInitialization();
end


function Initialization:InitiateStep(currentStep)
	assert(tonumber(currentStep) and Initialization.lastStep < currentStep, ("Initialization:InitiateStep called twice for step: " .. currentStep .. " after step: " .. Initialization.lastStep));

	--Debug:LogGreen("Initializing step:", currentStep);

	Initialization.locked = true;
	Initialization.lastStep = currentStep;
end

function stages.Step1_AddonLoaded()
	Initialization:InitiateStep(1);
	Debug:Log("Step1_AddonLoaded");

	local successfulRequest = C_ChatInfo.RegisterAddonMessagePrefix("ArenaAnalytics");
	if(not successfulRequest) then
		Debug:Log("Failed to register Addon Message Prefix: 'ArenaAnalytics'!")
	end

	-- Welcome Message
	Prints:PrintWelcomeMessage();
end


function stages.Step2_VariablesLoaded()
	Initialization:InitiateStep(2);
	Debug:Log("Step2_VariablesLoaded:", IsLoggedIn());

	-- Initialize DBs
	ArenaAnalytics:InitializeArenaAnalyticsDB();

	MinimapButton:Initialize();
	Debug:Initialize();

	---------------------------------
	-- Initialize modules
	---------------------------------

	Options:Initialize();
	Commands:Initialize();
	Bitmap:Initialize();
	ArenaID:Initialize();
	LocalizationTables:Initialize();
	Search:Initialize();
	API:Initialize();
	FilterTables:Initialize();
	Filters:Initialize();
end


function stages.Step3_PlayerLogin()
	Initialization:InitiateStep(3);
	Debug:Log("Step3_PlayerLogin:", IsLoggedIn());

	VersionManager:OnInit();
	AAtable:OnLoad();
end


function stages.Step4_EnteringWorld()
	Initialization:InitiateStep(4);
	Debug:Log("Step4_EnteringWorld");

	-- TODO: Implement to inform users of latest versions (Avoid false positives from development versions!)
	-- Version Message (Unused)
	if(IsInInstance() or IsInGroup(1)) then
		--local channel = IsInInstance() and "INSTANCE_CHAT" or "PARTY";
		--local messageSuccess = C_ChatInfo.SendAddonMessage("ArenaAnalytics", UnitGUID("player") .. "_deliver|version#?=" .. version, channel)
	end

	-- Don't wait for battlefield event outside of arena, let step 5 happen immediately
	if(not API:IsInArena()) then
		Initialization.receivedEvents["UPDATE_BATTLEFIELD_STATUS"] = true;
	end
end


-- Initiate tracking if in arena, otherwise skip
function stages.Step5_InitiateTracking()
	Initialization:InitiateStep(5);
	Debug:Log("Step5_InitiateTracking()", API:IsInArena());

	ArenaTracker:Initialize();

	-- Force a status update and set initial wasInArena
	Events:CheckZoneChanged(true);

	if(API:IsInArena()) then
		ArenaAnalytics.loadedIntoArena = true; -- Limit Events module from entering the arena
	else
		Debug:Log("Step5_InitiateTracking() triggering ArenaTracker:Clear()");
		ArenaTracker:Clear();
	end
end


function stages.Step6_LoadComplete()
	Initialization:InitiateStep(6);
	Debug:LogGreen("Step6_LoadComplete()");

	-- Mark initialization as done.
	Initialization.hasLoaded = true;
	Initialization.hasPending = nil;

	Events:UnregisterLoadEvents();
	Events:OnLoad();
end


local function shouldInitiateStep(stepNumber, stepData)
	if(not Debug:Assert(stepData and type(stepData.func) == "string")) then
		return false;
	end

	if(stepNumber - 1 ~= Initialization.lastStep) then
		return false;
	end

	if(stepData.event and not Initialization.receivedEvents[stepData.event]) then
		return false;
	end

	if(stepData.conditionFunc and not stepData.conditionFunc()) then
		return false;
	end

	return true;
end

local function TryAdvanceInitialization_Internal()
	for stepNumber=Initialization.lastStep+1, #initializationStages do
		local stepData = initializationStages[stepNumber];

		if(not shouldInitiateStep(stepNumber, stepData)) then
			return;
		end

		local stageFunc = stages[stepData.func];
		stageFunc(stepNumber);
	end
end

function Initialization:TryAdvanceInitialization(forced)
	if(Initialization.locked and not forced) then
		Debug:Log("Initialization locked. Skipping attempt.");
		Initialization.hasPending = true;
		return;
	end

	Initialization.locked = true;
	TryAdvanceInitialization_Internal();

	if(Initialization.hasPending and not Initialization.hasLoaded) then
		-- Force repeat next frame, instead of unlocking
		C_Timer.After(0, function() Initialization:TryAdvanceInitialization(true) end);
		return;
	end

	Initialization.locked = false;
end