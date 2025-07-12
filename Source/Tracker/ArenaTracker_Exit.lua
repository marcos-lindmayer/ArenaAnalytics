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
	local seasonPlayed = API:GetSeasonPlayed(currentArena.bracketIndex);
	if(currentArena.seasonPlayed) then
		Debug:Log("CheckRequiresRatingFix: No season played stored on currentArena. Skipping fixup check.");
		return false;
	end

	if(not seasonPlayed) then
		Debug:Log("CheckRequiresRatingFix: Missing current season played for bracket:", currentArena.bracketIndex);
		return true;
	end

	if(seasonPlayed < currentArena.seasonPlayed) then
		if(seasonPlayed + 1 < currentArena.seasonPlayed) then
			Debug:LogError("Tracked post-match seasonPlayed is more than one higher than current season played.");
		end

		-- Rating has updated, no longer needed to store transient SeasonPlayed for fixup.
		return true;
	end
end

local function GetLastStoredRating()
	-- TODO: Add an attempt to fetch the last rating for the bracket in current season? Using ArenaAnalytics:GetLatestRating?
	return nil; -- TODO: Implement?
end

-- Player left an arena (Zone changed to non-arena with valid arena data)
function ArenaTracker:HandleArenaExit()
	assert(currentArena.size);
	assert(currentArena.mapId);

	Debug:LogGreen("HandleArenaExit!     ", API:GetSeasonPlayed(currentArena.bracketIndex));

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

	if(ArenaTracker:IsRated()) then
		local newRating, oldRating = ArenaRatedInfo:GetRatedInfo(currentArena.bracketIndex, currentArena.seasonPlayed);

		if(not oldRating) then
			oldRating = GetLastStoredRating(); -- NYI
		end

		if(newRating) then
			currentArena.partyRating = newRating;
			currentArena.partyRatingDelta = oldRating and newRating - oldRating or nil;

			Debug:LogGreen("Setting party rating delta:", currentArena.partyRatingDelta, oldRating, newRating);
		else
			if(CheckRequiresRatingFix()) then
				currentArena.requireRatingFix = true;

				-- Use old rating temporarily
				currentArena.partyRating = oldRating;
			end
		end
	end

	ArenaTracker:InsertArenaToMatchHistory(currentArena);
	ArenaTracker:Clear();
end


-- Calculates arena duration, turns arena data into friendly strings, adds it to ArenaAnalyticsDB
-- and triggers a layout refresh on ArenaAnalytics.AAtable
function ArenaTracker:InsertArenaToMatchHistory(newArena)
	-- Calculate arena duration
	if(newArena.isShuffle) then
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

	ArenaMatch:SetMatchOutcome(arenaData, newArena.outcome);

	-- Add players from both teams sorted, and assign comps.
	ArenaMatch:AddPlayers(arenaData, newArena.players);

	if(newArena.bracket == "shuffle") then
		ArenaMatch:SetRounds(arenaData, newArena.committedRounds);
	end

	-- Assign session
	Sessions:AssignSession(arenaData);

	if(newArena.requireRatingFix) then
		-- Transient data
		ArenaMatch:SetTransientSeasonPlayed(arenaData, newArena.seasonPlayed);
		ArenaMatch:SetRequireRatingFix(arenaData, newArena.requireRatingFix);
	end

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