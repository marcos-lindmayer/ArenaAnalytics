local _, ArenaAnalytics = ... -- Namespace
local ArenaTracker = ArenaAnalytics.ArenaTracker;

-- Local module aliases
local AAmatch = ArenaAnalytics.AAmatch;
local Constants = ArenaAnalytics.Constants;
local SpecSpells = ArenaAnalytics.SpecSpells;
local API = ArenaAnalytics.API;
local Helpers = ArenaAnalytics.Helpers;
local Internal = ArenaAnalytics.Internal;
local Localization = ArenaAnalytics.Localization;
local Inspection = ArenaAnalytics.Inspection;
local Events = ArenaAnalytics.Events;
local TablePool = ArenaAnalytics.TablePool;
local Debug = ArenaAnalytics.Debug;
local ArenaRatedInfo = ArenaAnalytics.ArenaRatedInfo;

-------------------------------------------------------------------------
-- ArenaTracker subsection
-- Responsible for dealing with exiting an arena, including early leave.
-------------------------------------------------------------------------

local currentArena = {};
function ArenaTracker:InitializeSubmodule_Exit()
    currentArena = ArenaAnalyticsTransientDB.currentArena;
end

-- Player left an arena (Zone changed to non-arena with valid arena data)
function ArenaTracker:HandleArenaExit()
	assert(currentArena.size);
	assert(currentArena.mapId);

	Debug:LogGreen("HandleArenaExit:", API:GetPersonalRatedInfo(currentArena.bracketIndex));

	if(Inspection and Inspection.Clear) then
		Inspection:Clear();
	end

	-- Solo Shuffle
	ArenaTracker:HandleRoundEnd(true);

	currentArena.hasStartTime = Helpers:IsPositiveNumber(currentArena.startTime);
	currentArena.startTime = tonumber(currentArena.startTime) or time();
	currentArena.endTime = tonumber(currentArena.endTime) or time();

	if(not currentArena.endedProperly) then
		currentArena.ended = true;
		currentArena.outcome = 0;

		Debug:Log("Detected early leave. Has valid current arena: ", currentArena.mapId);
	end

	-- Rated match
	if(ArenaTracker:IsRated() and not currentArena.partyRating) then
		local newRating, seasonPlayed = API:GetPersonalRatedInfo(currentArena.bracketIndex);
		if(newRating and currentArena.seasonPlayed) then
			local oldRating = currentArena.oldRating;
			if(not oldRating) then
				local season = API:GetCurrentSeason();
				local lastSeasonPlayed = currentArena.seasonPlayed - 1;

				local rating, lastRating = ArenaRatedInfo:GetRatedInfo(currentArena.bracketIndex, currentArena.seasonPlayed);

				oldRating = lastRating or ArenaAnalytics:GetLatestRating(currentArena.bracketIndex, season, lastSeasonPlayed); -- TODO: Validate this
				Debug:LogWarning("Fixed missing old rating:", oldRating, "bracketIndex:", currentArena.bracketIndex, "season:", season, "seasonPlayed:", currentArena.seasonPlayed);
			end

			currentArena.partyRating = newRating;
			currentArena.partyRatingDelta = oldRating and newRating - oldRating or nil;
			Debug:LogGreen("Setting party rating delta:", currentArena.partyRatingDelta, oldRating, newRating);
		else
			Debug:Log("Warning: Nil current rating retrieved from API upon leaving arena.");
		end

		Debug:LogTemp("ArenaExit season played:", currentArena.seasonPlayed, seasonPlayed);
		if(currentArena.seasonPlayed) then
			if(seasonPlayed and seasonPlayed < currentArena.seasonPlayed) then
				-- Rating has updated, no longer needed to store transient Season Played for fixup.
				currentArena.requireRatingFix = true;
			else
				Debug:Log("Tracker: Invalid or up to date seasonPlayed.", seasonPlayed, currentArena.seasonPlayed);
			end
		else
			Debug:Log("Tracker: No season played stored on currentArena.");
		end
	end

	ArenaAnalytics:InsertArenaToMatchHistory(currentArena);
	ArenaTracker:Clear();
end