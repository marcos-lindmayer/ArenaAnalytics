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
function ArenaTracker:HandleArenaStart(stateData)
	local battlefieldId = stateData.battlefieldId;
	if(not battlefieldId) then
		Debug:LogError("HandleArenaStart called for invalid battlefieldId!");
		return;
	end

	if(ArenaTracker:IsTrackingArena()) then
		Debug:Log("HandleArenaStart: Already tracking arena!");
		return;
	end

	local status, bracket, teamSize, matchType = API:GetBattlefieldStatus(battlefieldId);
	local bracketIndex = ArenaAnalytics:GetAddonBracketIndex(bracket);

	-- Bail out if it ended by now
	if (status ~= "active" or not teamSize) then
		Debug:LogError("HandleArenaStart bailing out. Status:", status, "Team Size:", teamSize);
		return;
	end

	if(not ArenaTracker:IsInState("Pending")) then
		return;
	end

	ArenaTracker:SetState("Starting");

	Debug:LogGreen("HandleArenaStart:     ", stateData.bracket, stateData.matchType, stateData.seasonPlayed, stateData.seasonPlayedConfirmed);

	-- DB and transient versions
	currentArena.isTracking = true;
	ArenaTracker.isTracking = true;

	currentArena.battlefieldId = battlefieldId;

	-- Update start time immediately, might be overridden by gates open if it hasn't happened yet.
	currentArena.startTime = tonumber(currentArena.startTime) or time();

	currentArena.playerName = API:GetPlayerName();
	currentArena.mySpec = Helpers:IsSpecID(stateData.mySpec) and stateData.mySpec or API:GetSpecialization();

	currentArena.size = teamSize;

	currentArena.matchType = matchType;
	currentArena.bracket = bracket;
	currentArena.bracketIndex = bracketIndex;

	if(ArenaTracker:IsRated()) then
		currentArena.seasonPlayed = stateData.seasonPlayed; -- Post match season played
	end

	-- Add self
	if (currentArena.playerName and not ArenaTracker:IsTrackingPlayer(currentArena.playerName)) then
		-- Add player
		local GUID = UnitGUID("player");
		local name = currentArena.playerName;
		local race_id = Helpers:GetUnitRace("player");
		local isFemale = Helpers:IsUnitFemale("player");
		local class_id = Helpers:GetUnitClass("player");
		local spec_id = currentArena.mySpec or class_id;
		Debug:Log("Using MySpec:", spec_id, isFemale);

		local player = ArenaTracker:CreatePlayerTable(false, GUID, name, race_id, isFemale, spec_id);
		table.insert(currentArena.players, player);
	end

	if(ArenaAnalytics.DataSync) then
		ArenaAnalytics.DataSync:sendMatchGreetingMessage();
	end

	currentArena.mapId = API:GetCurrentMapID();
	Debug:Log("Match tracking started! Tracking mapId: ", currentArena.mapId);

	ArenaTracker:ForceTeamsUpdate();

	ArenaTracker:SetState("Active");
	Events:RegisterArenaEvents();

	-- End immediately
	if(API:GetWinner() ~= nil) then
		ArenaTracker:HandleArenaEnd(); -- TODO: Consider 1 frame delay?
	end
end
