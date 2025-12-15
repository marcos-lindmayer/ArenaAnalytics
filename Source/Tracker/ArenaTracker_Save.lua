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
-- Responsible for saving the arena to the match history
-------------------------------------------------------------------------

function ArenaTracker:TrySave()
	if(not ArenaTracker:IsTrackingArena()) then
		return false;
	end

	-- Basic match comparison
	if(ArenaTracker:IsSameArena()) then
		return false;
	end

	return ArenaTracker:Save(ArenaAnalyticsTransientDB.currentArena);
end

-- Calculates arena duration, turns arena data into friendly strings, adds it to ArenaAnalyticsDB
-- and triggers a layout refresh on ArenaAnalytics.AAtable
function ArenaTracker:Save(newArena)
	if(not newArena) then
		return;
	end

	if(ArenaTracker:IsInState("Saving", "Saved")) then
		return;
	end
	ArenaTracker:SetState("Saving");

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
	else
		newArena.duration = nil;
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
	ArenaTracker:SetState("Saved");

	-- Clear the tracking
	ArenaTracker:Clear();

	-- Update UI
	ArenaTracker:HandleArenaSaved()
	return true;
end


function ArenaTracker:HandleArenaSaved()
	ArenaAnalytics.unsavedArenaCount = ArenaAnalytics.unsavedArenaCount + 1;

	if(Import.TryHide) then
		Import:TryHide();
	end

	Filters:Refresh();

	Sessions:TryStartSessionDurationTimer();

	-- Print in chat
	ArenaAnalytics:PrintSystem("Arena recorded!");
end