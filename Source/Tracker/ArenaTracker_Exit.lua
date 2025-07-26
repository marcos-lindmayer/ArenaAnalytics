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

	ArenaTracker:InsertArenaToMatchHistory(currentArena);
	ArenaTracker:Clear();
end


-- Calculates arena duration, turns arena data into friendly strings, adds it to ArenaAnalyticsDB
-- and triggers a layout refresh on ArenaAnalytics.AAtable
function ArenaTracker:InsertArenaToMatchHistory(newArena)
	-- Calculate arena duration
	if(newArena.bracket == "shuffle") then
		newArena.duration = 0;

		if(newArena.committedRounds) then
			for _,round in ipairs(newArena.committedRounds) do
				if(round) then
					newArena.duration = newArena.duration + (tonumber(round.duration) or 0);
				end
			end
		end

		Debug:Log("Shuffle combined duration:", newArena.duration);
	elseif(newArena.hasStartTime and Helpers:IsPositiveNumber(newArena.startTime)) then
		newArena.endTime = tonumber(newArena.endTime) or time();
		if(newArena.startTime < newArena.endTime) then
			newArena.duration = newArena.endTime - newArena.startTime;
		end
	end

	Debug:Log("Duration for new arena:", newArena.duration, newArena.hasStartTime, newArena.hasRealStartTime, newArena.startTime, newArena.endTime);

	local season = API:GetCurrentSeason();
	if (not season or season == 0) then
		Debug:Log("Failed to get valid season for new match.");
	end

	-- Setup table data to insert into ArenaAnalyticsDB
	local arenaData = { }
	ArenaMatch:SetDate(arenaData, newArena.startTime or time());
	ArenaMatch:SetDuration(arenaData, newArena.duration);
	ArenaMatch:SetMap(arenaData, newArena.mapId);

	Debug:Log("Bracket:", newArena.bracketIndex, newArena.bracket, "MatchType:", newArena.matchType);
	ArenaMatch:SetBracketIndex(arenaData, newArena.bracketIndex);

	ArenaMatch:SetMatchType(arenaData, newArena.matchType);

	if (newArena.matchType == "rated") then
		ArenaMatch:SetPartyRating(arenaData, newArena.partyRating);
		ArenaMatch:SetPartyRatingDelta(arenaData, newArena.partyRatingDelta);
		ArenaMatch:SetPartyMMR(arenaData, newArena.partyMMR);

		ArenaMatch:SetEnemyRating(arenaData, newArena.enemyRating);
		ArenaMatch:SetEnemyRatingDelta(arenaData, newArena.enemyRatingDelta);
		ArenaMatch:SetEnemyMMR(arenaData, newArena.enemyMMR);
	end

	ArenaMatch:SetSeason(arenaData, season);
	ArenaMatch:SetSeasonPlayed(arenaData, newArena.seasonPlayed)

	ArenaMatch:SetMatchOutcome(arenaData, newArena.outcome);

	-- Add players from both teams sorted, and assign comps.
	ArenaMatch:AddPlayers(arenaData, newArena.players);

	if(newArena.bracket == "shuffle") then
		ArenaMatch:SetRounds(arenaData, newArena.committedRounds);
	end

	-- Assign session
	Sessions:AssignSession(arenaData);

	ArenaMatch:TrySetRequireRatingFix(arenaData, newArena.requireRatingFix);

	-- Clear transient season played from last match
	ArenaAnalytics:ClearLastMatchTransientValues(newArena.bracketIndex);

	-- Insert arena data as a new ArenaAnalyticsDB entry
	table.insert(ArenaAnalyticsDB, arenaData);

	ArenaAnalytics.unsavedArenaCount = ArenaAnalytics.unsavedArenaCount + 1;

	if(Import.TryHide) then
		Import:TryHide();
	end

	ArenaAnalytics:PrintSystem("Arena recorded!");

	Filters:Refresh();

	Sessions:TryStartSessionDurationTimer();
end