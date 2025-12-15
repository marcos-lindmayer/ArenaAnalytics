local _, ArenaAnalytics = ... -- Namespace
local ArenaTracker = ArenaAnalytics.ArenaTracker;

-- Local module aliases
local AAmatch = ArenaAnalytics.AAmatch;
local Constants = ArenaAnalytics.Constants;
local SpecSpells = ArenaAnalytics.SpecSpells;
local API = ArenaAnalytics.API;
local Helpers = ArenaAnalytics.Helpers;
local Inspection = ArenaAnalytics.Inspection;
local Sessions = ArenaAnalytics.Sessions;
local Debug = ArenaAnalytics.Debug;
local ArenaRatedInfo = ArenaAnalytics.ArenaRatedInfo;
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local Filters = ArenaAnalytics.Filters;
local Import = ArenaAnalytics.Import;

-------------------------------------------------------------------------
-- ArenaTracker subsection
-- Responsible for dealing with exiting an arena, including early leave.
-------------------------------------------------------------------------

local currentArena = {};
function ArenaTracker:InitializeSubmodule_Exit()
    currentArena = ArenaAnalyticsTransientDB.currentArena;
end

local function CheckRequiresRatingFix()
	if(type(currentArena.seasonPlayed) ~= "number" or currentArena.seasonPlayed == 0) then
		Debug:Log("CheckRequiresRatingFix: No season played stored on currentArena. Skipping fixup check.");
		return nil;
	end

	-- We'll never be able to fix rating without knowing the bracket
	if(not currentArena.bracketIndex) then
		return false;
	end

	-- Missing current season played value, assume we'll get it later to validate
	local seasonPlayed = API:GetSeasonPlayed(currentArena.bracketIndex);
	if(not seasonPlayed) then
		Debug:Log("CheckRequiresRatingFix: Missing current season played for bracket:", currentArena.bracketIndex);
		return true;
	end

	if(seasonPlayed < currentArena.seasonPlayed) then
		if(seasonPlayed + 1 < currentArena.seasonPlayed) then
			Debug:LogError("Tracked post-match seasonPlayed is more than one higher than current season played.");
			return false;
		end

		-- Rating has updated, no longer needed to store transient SeasonPlayed for fixup.
		return true;
	end

	-- Don't schedule rating fix
	Debug:Log("CheckRequiresRatingFix passed, no fix required.");
	return false;
end


local function TryMarkPlayerFirstDeath()
	if(ArenaTracker:IsShuffle()) then
		return;
	end

	if(type(currentArena.players) ~= "table") then
		return;
	end

	-- Get first death
	local firstDeath = ArenaTracker:GetFirstDeathFromCurrentArena();
	ArenaTracker:CommitDeaths();

	-- Find matching player
	for _,player in ipairs(currentArena.players) do
		if(player.name == firstDeath) then
			player.isFirstDeath = true;
		end
	end
end


local function TryComputeSpecs()
	if(not API.legacySpecs) then
		return;
	end

	if(type(currentArena.players) ~= "table") then
		return;
	end

	for _,player in ipairs(currentArena.players) do
		ArenaTracker:ComputeSpec(player);
	end
end


local function TryAssignRating()
	if(not ArenaTracker:IsRated()) then
		return;
	end

	local newRating, oldRating = ArenaRatedInfo:GetRatedInfo(currentArena.bracketIndex, currentArena.seasonPlayed);

	if(newRating) then
		currentArena.partyRating = newRating;
		currentArena.partyRatingDelta = oldRating and newRating - oldRating or nil;

		Debug:Log("Setting party rating:", currentArena.partyRating, "Delta:", currentArena.partyRatingDelta);
	else
		-- Use old rating, presumably temporary
		currentArena.partyRating = oldRating;
		currentArena.requireRatingFix = true;
	end

	currentArena.requireRatingFix = currentArena.requireRatingFix or CheckRequiresRatingFix() or nil;

	Debug:Log("Requires rating fix:", currentArena.requireRatingFix, "New rating:", newRating, "Old rating:", oldRating, "season played:", currentArena.seasonPlayed);
end

-- Player left an arena (Zone changed to non-arena with valid arena data)
function ArenaTracker:HandleArenaExit()
	if(not ArenaTracker:IsTrackingArena(true)) then
		return;
	end

	if(currentArena.isHandlingExit) then
		return;
	end
	currentArena.isHandlingExit = true;

	assert(currentArena.size);
	assert(currentArena.mapId);

	Debug:LogGreen("HandleArenaExit!     ", API:GetSeasonPlayed(currentArena.bracketIndex), currentArena.seasonPlayed);

	if(Inspection and Inspection.Clear) then
		Inspection:Clear();
	end

	-- Solo Shuffle
	if(ArenaTracker:IsShuffle()) then
		ArenaTracker:HandleRoundEnd(true);
	end

	currentArena.hasStartTime = Helpers:IsPositiveNumber(currentArena.startTime);
	currentArena.startTime = tonumber(currentArena.startTime) or time();
	currentArena.endTime = tonumber(currentArena.endTime) or time();

	if(not currentArena.endedProperly) then
		currentArena.ended = true;
		currentArena.outcome = 0;

		Debug:Log("Detected early leave. Has valid current arena: ", currentArena.mapId);
	end

	if(ArenaTracker:IsRated()) then
		TryAssignRating();
	end

	if(not ArenaTracker:IsShuffle()) then
		TryMarkPlayerFirstDeath();
	end

	TryComputeSpecs();

	ArenaTracker:Save(currentArena);
end