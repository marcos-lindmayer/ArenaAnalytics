local _, ArenaAnalytics = ...; -- Addon Namespace
local Debug = ArenaAnalytics.Debug;

-- Local module aliases
local Colors = ArenaAnalytics.Colors;
local Options = ArenaAnalytics.Options;
local Helpers = ArenaAnalytics.Helpers;
local API = ArenaAnalytics.API;

-------------------------------------------------------------------------

function Debug:GetDebugLevel()
    return tonumber(ArenaAnalyticsSharedSettingsDB["debuggingLevel"]) or 0;
end

function Debug:SetDebugLevel(level)
    local currentLevel = Debug:GetDebugLevel();

    level = Helpers:ToSafeNumber(level) or (currentLevel == 0 and 1) or 0;
    if(level == currentLevel and level > 0) then
        level = 0;
    end

    Options:Set("debuggingLevel", level);

    if(Debug:GetDebugLevel() == 0) then
        ArenaAnalytics:PrintSystem("Debugging disabled!");
    else
        Debug:LogForced(string.format("Debugging level %d enabled!", level));
    end
end

-------------------------------------------------------------------------
-- Logging

-- Debug logging version of print
function Debug:LogSpacer()
	if(Debug:GetDebugLevel() < 1) then
		return;
	end

	print(" ");
end

function Debug:LogInternal(prefix, color, ...)
    color = color or Colors.logColor;

    prefix = Colors:ColorText(prefix or "ArenaAnalytics:", color);
	print(prefix, ...);
end

-- Basic log forced regardless of debug level
function Debug:LogForced(...)
    Debug:LogInternal("ArenaAnalytics (Debug):", Colors.logColor, ...)
end

-------------------------------------------------------------------------
-- Debug (Errors & Warnings)

function Debug:LogError(...)
    if(ArenaAnalyticsSharedSettingsDB["hideErrorLogs"]) then
        return;
    end

    Debug:LogInternal("ArenaAnalytics (Error):", Colors.errorColor, ...);
end

function Debug:LogWarning(...)
	if(Debug:GetDebugLevel() < 1) then
		return;
	end

    Debug:LogInternal("ArenaAnalytics (Warning):", Colors.warningColor, ...);
end

-------------------------------------------------------------------------
-- Debug level 2 (Warning)

function Debug:LogFrameTime(context)
	if(Debug:GetDebugLevel() < 2) then
        return;
    end

    debugprofilestart();

    C_Timer.After(0, function()
        local elapsed = debugprofilestop();
        Debug:LogForced("DebugLogFrameTime:", elapsed, "Context:", context);
    end);
end

-------------------------------------------------------------------------
-- Debug level 3 (Misc)
function Debug:Log(...)
	if(Debug:GetDebugLevel() < 3) then
		return;
	end

    Debug:LogForced(...);
end

function Debug:LogGreen(...)
	if(Debug:GetDebugLevel() < 3) then
		return;
	end

    Debug:LogInternal("ArenaAnalytics (Debug):", Colors.logGreenColor, ...);
end

function Debug:LogPurple(...)
	if(Debug:GetDebugLevel() < 3) then
		return;
	end

    Debug:LogInternal("ArenaAnalytics (Debug):", Colors.logPurpleColor, ...);
end

function Debug:LogEscaped(...)
	if(Debug:GetDebugLevel() < 3) then
		return;
	end

    -- Process each argument and replace | with || in string values, to escape formatting
	local args = {...}
    local argCount = select('#', ...);

	for i=1, argCount do
        local arg = args[i];

        if(arg == nil) then
            args[i] = "nil";
        elseif(type(arg) == "string") then
			args[i] = arg:gsub("|", "||");
		end
	end

	-- Use unpack to print the modified arguments
	Debug:Log(unpack(args));
end

-- Assert if debug is enabled. Returns value to allow wrapping within if statements.
function Debug:Assert(value, msg)
	if(Debug:GetDebugLevel() >= 3) then
        if(not value) then
            Debug:LogError("Assert failed:", msg or "(No Message Provided)");
            assert(value, "Debug Assertion failed! " .. (msg or ""));
        end
	end
	return value;
end

-------------------------------------------------------------------------
-- Temporary Debugging tools

function Debug:LogTemp(...)
	if(Debug:GetDebugLevel() < 2) then
		return;
	end

    Debug:LogInternal("ArenaAnalytics (Temp):", Colors.tempColor, ...);
end

function Debug:LogTable(table, level, maxLevel)
    if(Debug:GetDebugLevel() < 4) then
        Debug:Log("Debug:LogTable requires log level 4.");
        return;
    end

    if(not table) then
        Debug:Log("DebugLogTable: Nil table");
        return;
    end

    level = level or 0;
    if(level > (maxLevel or 10)) then
        Debug:LogWarning("Debug:LogTable max level exceeded.");
        return;
    end

    local indentation = string.rep(" ", 3*level);

    if(type(table) ~= "table") then
        Debug:LogEscaped(indentation, table);
        return;
    end

    for key,value in pairs(table) do
        if(type(value) == "table") then
            Debug:LogEscaped(indentation, key);
            Debug:LogTable(value, level+1, maxLevel);
        else
            Debug:LogEscaped(indentation, key, value);
        end
    end
end

-------------------------------------------------------------------------
-- UI

-- Used to draw a solid box texture over a frame for testing
function Debug:DrawDebugBackground(frame, r, g, b, a)
	if(Debug:GetDebugLevel() < 5) then
        return;
	end

    -- TEMP testing
    if(not frame.debugBackground) then
        frame.debugBackground = frame:CreateTexture();
    end

    frame.debugBackground:SetAllPoints(frame);
    frame.debugBackground:SetColorTexture(r or 1, g or 0, b or 0, a or 0.4);
end

-------------------------------------------------------------------------
-- Inspection Debugging

local lastInspectUnitToken = "target";
function Debug:NotifyInspectSpec(unitToken)
    if(Debug:GetDebugLevel() < 2) then
        return;
    end

    if(API:IsInArena()) then
        return;
    end

    unitToken = unitToken or "target";
    if(not API:CanInspect(unitToken)) then
        Debug:Log("Rejecting inspect by API:CanInspect for unit:", API:GetUnitFullName(unitToken), unitToken);
        return;
    end

    ClearInspectPlayer();
    lastInspectUnitToken = unitToken;
    Debug:Log("Inspecting:", API:GetUnitFullName(unitToken), unitToken);
    NotifyInspect(unitToken);
end

function Debug:HandleDebugInspect(GUID)
    if(Debug:GetDebugLevel() < 2) then
        return;
    end

    local spec = nil;

    if(C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) then
        spec = C_SpecializationInfo.GetSpecialization(true);
    elseif(GetSpecialization ~= nil) then
        spec = GetSpecialization(true);
    end

    local spec2 = GetInspectSpecialization(lastInspectUnitToken);

    Debug:Log("HandleDebugInspect:", spec, spec2, API:GetSpecialization(lastInspectUnitToken));
end

-------------------------------------------------------------------------

function Debug:TryStoreRawArena(arena)
	if(Debug:GetDebugLevel() < 10) then
        return;
    end

    ArenaAnalyticsTransientDB.rawArena = Helpers:DeepCopy(arena);
end

function Debug:ForceApplyRawArena()
	if(Debug:GetDebugLevel() < 1) then
        return;
    end

    if(API:IsInArena()) then
        Debug:LogTemp("In arena")
        return;
    end

    local ArenaTracker = ArenaAnalytics.ArenaTracker;
    if(ArenaTracker:IsTrackingArena(true)) then
        Debug:LogTemp("Already tracking")
        return;
    end

    if(type(ArenaAnalyticsTransientDB.rawArena) ~= "table") then
        Debug:LogTemp("No raw arena", type(ArenaAnalyticsTransientDB.rawArena))
        return;
    end

    Debug:LogWarning("Force replacing currentArena with cached rawArena!!");
    ArenaAnalyticsTransientDB.currentArena = Helpers:DeepCopy(ArenaAnalyticsTransientDB.rawArena);
    ArenaAnalyticsTransientDB.currentArena.startTime = time();
    ArenaTracker:Initialize();
end

-------------------------------------------------------------------------

function Debug:Initialize()
    local debugLevel = Debug:GetDebugLevel();
	if(debugLevel > 0) then
        Debug:LogForced(string.format("Debugging Enabled at level: %d!  %s", debugLevel, Colors:ColorText("/aa debug to disable.", Colors.infoColor)));
	end
end
