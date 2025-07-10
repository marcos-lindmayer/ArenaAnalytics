local _, ArenaAnalytics = ...; -- Addon Namespace
local Debug = ArenaAnalytics.Debug;

-- Local module aliases
local Colors = ArenaAnalytics.Colors;
local API = ArenaAnalytics.API;

-------------------------------------------------------------------------

function Debug:GetDebugLevel()
    return tonumber(ArenaAnalyticsSharedSettingsDB["debuggingLevel"]) or 0;
end

function Debug:SetDebugLevel(level)
    local currentLevel = ArenaAnalytics.Options:Get("debuggingLevel");

    level = tonumber(level) or (currentLevel == 0 and 3) or 0;
    if(level == currentLevel and level > 0) then
        level = 0;
    end

    ArenaAnalytics.Options:Set("debuggingLevel", level);

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

-- Basic log forced regardless of debug level
function Debug:LogForced(...)
    local prefix = Colors:ColorText("ArenaAnalytics (Debug):", Colors.logColor);
	print(prefix, ...);
end

-------------------------------------------------------------------------
-- Debug level 1 (Error)

function Debug:LogError(...)
    if(ArenaAnalyticsSharedSettingsDB["hideErrorLogs"]) then
        return;
    end

    local prefix = Colors:ColorText("ArenaAnalytics (Error):", Colors.errorColor);
	print(prefix, ...);
end

-- Assert if debug is enabled. Returns value to allow wrapping within if statements.
function Debug:Assert(value, msg)
	if(Debug:GetDebugLevel() > 0) then
        if(not value) then
            Debug:LogError("Assert failed:", msg or "-")
            assert(value, "Debug Assertion failed! " .. (msg or ""));
        end
	end
	return value;
end

-------------------------------------------------------------------------
-- Debug level 2 (Warning)

function Debug:LogWarning(...)
	if(Debug:GetDebugLevel() < 2) then
		return;
	end

    local prefix = Colors:ColorText("ArenaAnalytics (Warning):", Colors.warningColor);
	print(prefix, ...);
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

    local prefix = Colors:ColorText("ArenaAnalytics (Debug):", Colors.logGreenColor);
	print(prefix, ...);
end

function Debug:LogEscaped(...)
	if(Debug:GetDebugLevel() < 3) then
		return;
	end

    -- Process each argument and replace | with || in string values, to escape formatting
	local args = {...}
	for i = 1, #args do
		if(type(args[i]) == "string") then
			args[i] = args[i]:gsub("|", "||");
		end
	end

	-- Use unpack to print the modified arguments
	Debug:Log(unpack(args));
end

function Debug:LogFrameTime(context)
	if(Debug:GetDebugLevel() == 0) then
        return;
    end

    debugprofilestart();

    C_Timer.After(0, function()
        local elapsed = debugprofilestop();
        Debug:LogForced("DebugLogFrameTime:", elapsed, "Context:", context);
    end);
end

-------------------------------------------------------------------------
-- Temporary Debugging tools

function Debug:LogTemp(...)
	if(Debug:GetDebugLevel() < 1) then
		return;
	end

    local prefix = Colors:ColorText("ArenaAnalytics (Temp):", Colors.tempColor);
	print(prefix, ...);
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
        Debug:Log(indentation, table);
        return;
    end

    for key,value in pairs(table) do
        if(type(value) == "table") then
            Debug:Log(indentation, key);
            Debug:LogTable(value, level+1, maxLevel);
        else
            Debug:Log(indentation, key, value);
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

-- TEMP debugging
function Debug:PrintScoreboardStats(numPlayers)
	if(Debug:GetDebugLevel() < 5) then
        return;
	end

    local statIDs = {}
    local statNames = {}

    numPlayers = numPlayers or 1;

    for playerIndex=1, numPlayers do
        Debug:LogSpacer();

        local scoreInfo = C_PvP.GetScoreInfo(playerIndex);
        if(scoreInfo and scoreInfo.stats) then
            for i=1, #scoreInfo.stats do
                local stat = scoreInfo.stats[i];
                Debug:Log("Stat:", stat.pvpStatID, stat.pvpStatValue, stat.name);

                if(stat.pvpStatID) then
                    if(statIDs[stat.pvpStatID] and statIDs[stat.pvpStatID] ~= stat.name) then
                        Debug:Log("New stat name for ID!", stat.pvpStatID, stat.name);
                    end
                    statIDs[stat.pvpStatID] = stat.name;
                end

                if(stat.name) then
                    if(statIDs[stat.name] and statIDs[stat.name] ~= stat.pvpStatID) then
                        Debug:Log("New stat ID for name!", stat.pvpStatID, stat.name);
                    end
                    statNames[stat.name] = stat.pvpStatID;
                end
            end

            Debug:LogTable(scoreInfo and scoreInfo.stats);
        else
            Debug:Log("No current stats found!");
        end
    end
end

-------------------------------------------------------------------------
-- Inspection Debugging

local lastInspectUnitToken = "target";
function Debug:NotifyInspectSpec(unitToken)
    if(ArenaAnalytics.Options:Get("debuggingLevel") < 1) then
        return;
    end

    if(API:IsInArena()) then
        return;
    end

    unitToken = unitToken or "target";
    if(not API:CanInspect(unitToken)) then
        return;
    end

    ClearInspectPlayer();
    lastInspectUnitToken = unitToken;
    Debug:Log("Inspecting:", unitToken);
    NotifyInspect(unitToken);
end

function Debug:HandleDebugInspect(GUID)
    if(ArenaAnalytics.Options:Get("debuggingLevel") < 1) then
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

function Debug:Initialize()
    local debugLevel = Debug:GetDebugLevel();
	if(debugLevel > 0) then
        Debug:LogForced(string.format("Debugging Enabled at level: %d!  %s", debugLevel, Colors:ColorText("/aa debug to disable.", Colors.infoColor)));
	end
end
