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

local MAX_TIMESTAMP_DIFFERENCE = 1200; -- The limit in time before forcing new tracking

local stateData = {
	-- Current match idenfification
	mapID = nil,
	bracket = nil,
	bracketIndex = nil,
	matchType = nil,
	mySpec = nil,

	-- Season Played state
	seasonPlayed = nil,
	seasonPlayedLocked = nil,
	scoreReceived = nil,
	hasMatchEnded = nil,
};

-- TransientDB currentArena alias
local currentArena = {};
function ArenaTracker:InitializeSubmodule_Enter()
    currentArena = ArenaAnalyticsTransientDB.currentArena;
end

function ArenaTracker:HandleRatedUpdate()
	if(stateData.seasonPlayedLocked) then
		return;
	end

	local _,seasonPlayed = API:GetPersonalRatedInfo()
	stateData.seasonPlayed = seasonPlayed;
end

function ArenaTracker:HandleScoreUpdate()
	if(stateData.seasonPlayedLocked) then
		return;
	end

	local _,seasonPlayed = API:GetPersonalRatedInfo()
	stateData.seasonPlayed = seasonPlayed;
end

-------------------------------------------------------------------------

-- Await basic info for match identification, before starting active tracking
-- Initialization calls with isLoad = true, to check existing tracking to continue or reset.
function ArenaTracker:HandleArenaEnter(isLoad)
	if(not API:IsInArena()) then
		Debug:Log("HandleArenaEnter called while not in arena")
		return;
	end

	if(ArenaTracker:IsTrackingArena()) then
		Debug:LogGreen("HandleArenaEnter: Already tracking arena!");
		return;
	end

	Debug:LogGreen("ArenaTracker:HandleArenaEnter: isLoad =", isLoad);

	-- Basic state for currentArena, to compare to existing currentArena before real tracking starts.
	stateData = {};
	stateData.mapID = API:GetCurrentMapID();

	local battlefieldID = API:GetActiveBattlefieldID()
	if(not battlefieldID) then
		Debug:LogError("Missing active battlefield ID");
		return;
	end

	local status, bracket, _, matchType = API:GetBattlefieldStatus(battlefieldID);
	if(status ~= "active") then
		Debug:Log("HandleArenaEnter bailing out: No active battlefield found.");
		return;
	end

	stateData.bracket = bracket;
	stateData.bracketIndex = ArenaAnalytics:GetAddonBracketIndex(bracket);
	stateData.matchType = matchType;

	stateData.mySpec = API:GetSpecialization();

	Debug:LogTable(stateData);

	-- Battlefield Score event = reliable GetBattlefieldWinner(), combined with seasonPlayed for reliable determination of pre or post match value.

	-- No async checks implemented yet*
	ArenaTracker:HandleArenaStart();
end

function ArenaTracker:CompareExistingTracking()

end












-- TODO: Refactor into CompareExistingTracking  and remove this.
-- TODO: Compare teams and enemies for known players, and perhaps startTime being within an hour?
function ArenaTracker:IsTrackingCurrentArena(battlefieldId, bracketIndex, isScoreEvent)
	if(not API:IsInArena()) then
		Debug:Log("IsTrackingCurrentArena: Not in arena.");
		return false;
	end

	local arena = ArenaAnalyticsTransientDB.currentArena;
	if(not arena) then
		Debug:Log("IsTrackingCurrentArena: No existing arena.", arena, ArenaAnalyticsTransientDB.currentArena);
		return false;
	end

	if(not arena.mapId or arena.mapId ~= API:GetCurrentMapID()) then
		Debug:Log("IsTrackingCurrentArena: Not tracking arena.");
		return false;
	end

	battlefieldId = battlefieldId or API:GetActiveBattlefieldID();
	if(not battlefieldId or arena.battlefieldId ~= battlefieldId) then
		Debug:Log("IsTrackingCurrentArena: New or missing battlefield id.");
		return false;
	end

	local _, bracket = API:GetBattlefieldStatus(battlefieldId); -- RELOAD ISSUE
	if(not bracket or arena.bracket ~= bracket) then
		Debug:Log("IsTrackingCurrentArena: New or missing bracket.", bracket, arena.bracket);
		return false;
	end

	if(arena.startTime) then
		local trackingAge = (time() - arena.startTime);
		if(trackingAge > 3600) then
			Debug:Log("IsTrackingCurrentArena: Old tracking expired. Tracked age:", trackingAge);
			return false;
		end
	end

	-- TODO: Compare known players (team and enemies) between current and existing tracking

	-- Skipped if arena.seasonPlayed or seasonPlayed are missing
	if(arena.matchType == "rated" and arena.seasonPlayed) then
		local seasonPlayed = ArenaTracker:GetSeasonPlayed(bracketIndex);
		if(seasonPlayed and seasonPlayed ~= arena.seasonPlayed) then
			Debug:Log("IsTrackingCurrentArena: Invalid season played, or mismatch to tracked value.", seasonPlayed, arena.seasonPlayed);
			return false;
		end
	end

	Debug:Log("IsTrackingCurrentArena: Arena alrady tracked")
	return true;
end
