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
-- Responsible for starting tracking, after event or OnLoad says so.
-------------------------------------------------------------------------

local currentArena = {};
function ArenaTracker:InitializeSubmodule_Start()
    currentArena = ArenaAnalyticsTransientDB.currentArena;
end

-- Begins capturing data for the current arena
-- Gets arena player, size, map, ranked/skirmish
function ArenaTracker:HandleArenaStart()
	if(ArenaTracker:IsTrackingArena()) then
		Debug:LogGreen("HandleArenaStart: Already tracking arena!");
		return;
	end

	Debug:LogGreen("HandleArenaStart");

	-- Retrieve current arena info
	local battlefieldId = currentArena.battlefieldId or API:GetActiveBattlefieldID();
	if(not battlefieldId) then
		return;
	end

	local status, bracket, teamSize, matchType = API:GetBattlefieldStatus(battlefieldId);
	local bracketIndex = ArenaAnalytics:GetAddonBracketIndex(bracket);

	ArenaTracker:HandleScoreUpdate();

	if(not ArenaTracker:IsTrackingCurrentArena(battlefieldId, bracketIndex)) then
		Debug:Log("HandleArenaStart resetting currentArena");
		ArenaTracker:Reset();
	else
		Debug:LogGreen("Keeping existing tracking!", currentArena.oldRating, currentArena.startTime, currentArena.hasRealStartTime, time());
	end

	-- DB and transient versions
	currentArena.isTracking = true;
	ArenaTracker.isTracking = true;

	currentArena.battlefieldId = battlefieldId;

	-- Bail out if it ended by now
	if (status ~= "active" or not teamSize) then
		Debug:Log("HandleArenaStart bailing out. Status:", status, "Team Size:", teamSize);
		return false;
	end

	-- Update start time immediately, might be overridden by gates open if it hasn't happened yet.
	currentArena.startTime = tonumber(currentArena.startTime) or time();

	currentArena.playerName = Helpers:GetPlayerName();

	currentArena.size = teamSize;

	currentArena.matchType = matchType;
	currentArena.bracket = bracket;
	currentArena.bracketIndex = bracketIndex;

	Debug:Log("TeamSize:", teamSize, currentArena.size, "Bracket:", bracket);

	if(ArenaTracker:IsRated()) then
		currentArena.seasonPlayed = ArenaTracker:GetSeasonPlayed(currentArena.bracketIndex); -- Season Played during the match
		local rating, lastRating = ArenaRatedInfo:GetRatedInfo(bracketIndex, currentArena.seasonPlayed);

		Debug:LogTemp("Active arena season played:", currentArena.seasonPlayed);

		if(not API:GetWinner()) then
			currentArena.oldRating = lastRating;
			Debug:LogTemp("Setting old rating and seasonPlayed on arena start:", currentArena.oldRating, currentArena.seasonPlayed);
		end
	end

	-- Add self
	if (currentArena.playerName and not ArenaTracker:IsTrackingPlayer(currentArena.playerName)) then
		-- Add player
		local GUID = UnitGUID("player");
		local name = currentArena.playerName;
		local race_id = Helpers:GetUnitRace("player");
		local class_id = Helpers:GetUnitClass("player");
		local spec_id = API:GetSpecialization() or class_id;
		Debug:Log("Using MySpec:", spec_id);

		local player = ArenaTracker:CreatePlayerTable(false, GUID, name, race_id, spec_id);
		table.insert(currentArena.players, player);
	end

	if(ArenaAnalytics.DataSync) then
		ArenaAnalytics.DataSync:sendMatchGreetingMessage();
	end

	currentArena.mapId = API:GetCurrentMapID();
	Debug:Log("Match tracking started! Tracking mapId: ", currentArena.mapId);

	ArenaTracker:ForceTeamsUpdate();

	Events:RegisterArenaEvents();

	-- TODO: Determine if this fits updated init flow
	RequestRatedInfo();
	RequestBattlefieldScoreData();
end
