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
local SCORE_UPDATE_TIMEOUT = 5;

local stateData = {
	-- Current match idenfification
	battlefieldId = nil,
	mapId = nil,
	bracket = nil,
	bracketIndex = nil,
	matchType = nil,
	mySpec = nil,

	-- Season Played state
	seasonPlayed = nil,
	seasonPlayedConfirmed = nil,
	isProvenSeasonPlayed = nil,
	scoreReceived = nil,
	scoreTimedOut = nil,
	hasMatchEnded = nil,

	hasRequestedRated = nil,
	hasRequestedScore = nil,
};

-- TransientDB currentArena alias
local currentArena = {};
function ArenaTracker:InitializeSubmodule_Enter()
    currentArena = ArenaAnalyticsTransientDB.currentArena;
end


local function UpdatePostMatchSeasonPlayed(shouldLock)
	if(stateData.seasonPlayedConfirmed) then
		return;
	end

	local seasonPlayed = API:GetSeasonPlayed(stateData.bracketIndex);

	if(seasonPlayed and not stateData.hasMatchEnded) then
		seasonPlayed = seasonPlayed + 1;
	end

	stateData.seasonPlayed = seasonPlayed;
	stateData.seasonPlayedConfirmed = seasonPlayed and shouldLock and true;
end


local function IsAwaitingSeasonPlayed()
	if(not API:IsInArena()) then
		return false;
	end

	if(stateData.matchType ~= "rated") then
		return false;
	end

	if(stateData.seasonPlayedConfirmed) then
		return false;
	end

	if(not ArenaTracker:IsInState("Initiated", "Pending")) then
		return false;
	end

	return true;
end


function ArenaTracker:HandlePreTrackingRatedEvent()
	if(not IsAwaitingSeasonPlayed()) then
		return;
	end

	stateData.hasReceivedRatedInfo = true;

	if(stateData.scoreReceived or stateData.scoreTimedOut) then
		ArenaTracker:OnSeasonPlayedReceived(not stateData.scoreTimedOut);
	end

	if(not stateData.seasonPlayedConfirmed and not stateData.hasRequestedScore) then
		Debug:LogTemp("HandlePreTrackingRatedEvent: Requesting battlefield score for hasWinner.");

		stateData.hasRequestedScore = true;
		RequestBattlefieldScoreData();
		C_Timer.After(SCORE_UPDATE_TIMEOUT, ArenaTracker.HandleScoreTimeout);
	end

	Debug:LogGreen("HandlePreTrackingRatedEvent", stateData.scoreReceived, stateData.scoreTimedOut, stateData.hasMatchEnded, stateData.seasonPlayed, stateData.seasonPlayedConfirmed);
end


function ArenaTracker:HandlePreTrackingScoreEvent()
	if(not IsAwaitingSeasonPlayed()) then
		return;
	end

	stateData.scoreReceived = true;
	ArenaTracker.hasReceivedScore = true;
	stateData.scoreTimedOut = false;

	stateData.hasMatchEnded = API:GetWinner() ~= nil;

	if(stateData.hasReceivedRatedInfo) then
		if(not stateData.hasMatchEnded) then
			ArenaTracker:OnSeasonPlayedReceived(true);
		end
	end

	if(not stateData.seasonPlayedConfirmed and not stateData.hasRequestedRated) then
		Debug:LogTemp("HandlePreTrackingScoreEvent: Requesting rated info for season played.");

		stateData.hasRequestedRated = true;
		RequestRatedInfo();
	end

	Debug:LogGreen("HandlePreTrackingScoreEvent", stateData.scoreReceived, stateData.hasMatchEnded, stateData.seasonPlayed, stateData.seasonPlayedConfirmed);
end


-- Called when awaiting score times out after loading in
function ArenaTracker:HandleScoreTimeout()
	if(not IsAwaitingSeasonPlayed()) then
		return;
	end

	if(stateData.scoreReceived or stateData.scoreTimedOut) then
		return;
	end

	Debug:Log("ArenaTracker:HandleScoreTimeout");

	-- Assume that the match has not yet ended. (WARNING: This assumption could become problematic, if score event on some versions don't respond within the timeout)
	stateData.scoreTimedOut = true;

	if(stateData.hasReceivedRatedInfo) then
		if(not stateData.hasMatchEnded) then -- Assumed nil here, implying false
			ArenaTracker:OnSeasonPlayedReceived(false);
		end
	end
end


-- Called once score and rated events determine a post-match seasonPlayed
function ArenaTracker:OnSeasonPlayedReceived(isProvenSeasonPlayed)
	-- Pending rated match tracking
	if(not IsAwaitingSeasonPlayed()) then
		return;
	end

	stateData.isProvenSeasonPlayed = isProvenSeasonPlayed;

	UpdatePostMatchSeasonPlayed(true);

	if(ArenaTracker:IsInState("Pending")) then
		Debug:LogGreen("Post-match season played received:", stateData.seasonPlayed, ArenaTracker:GetStateName(),stateData.matchType);
		ArenaTracker:StartNewOrContinueTracking();
	end
end


-------------------------------------------------------------------------


-- Called to enter pending state, allowing collection of battlefield score
function ArenaTracker:HandleArenaInitiate(isLoad)
	if(not API:IsInArena()) then
		Debug:Log("HandleArenaInitiate called while not in arena");
		return;
	end

	if(ArenaTracker:IsTrackingArena()) then
		Debug:Log("HandleArenaInitiate: Already tracking arena!");
		return;
	end

	if(not ArenaTracker:IsInState("None")) then
		Debug:LogWarning("HandleArenaInitiate bailing out due to invalid state:", ArenaTracker:GetStateName());
		return;
	end

	ArenaTracker:SetState("Initiated");

	-- Clear the old stateData
	stateData = {};
	stateData.isLoad = isLoad;

	local battlefieldId = API:GetActiveBattlefieldID();
	if(battlefieldId) then
		ArenaTracker:HandleArenaEnter(battlefieldId);
	end
end


-- Await basic info for match identification, before starting active tracking
-- Initialization calls with isLoad = true, to check existing tracking to continue or reset.
function ArenaTracker:HandleArenaEnter(battlefieldId)
	if(not battlefieldId) then
		Debug:Log("HandleArenaEnter: Missing active battlefield ID");
		return;
	end

	if(not API:IsInArena()) then
		Debug:Log("HandleArenaEnter: called while not in arena")
		return;
	end

	if(ArenaTracker:IsTrackingArena()) then
		Debug:Log("HandleArenaEnter: Already tracking arena!");
		return;
	end

	if(not ArenaTracker:IsInState("Initiated")) then
		Debug:Log("HandleArenaEnter bailing out due to invalid state:", ArenaTracker:GetStateName());
		return;
	end

	Debug:LogGreen("=================================================");
	Debug:LogGreen("ArenaTracker:HandleArenaEnter: isLoad =", stateData.isLoad);

	local status, bracket, _, matchType = API:GetBattlefieldStatus(battlefieldId);
	assert(status == "active");

	-- Basic state for currentArena, to compare to existing currentArena before real tracking starts.
	stateData.battlefieldId = battlefieldId;
	stateData.mapId = API:GetCurrentMapID();
	stateData.bracket = bracket;
	stateData.bracketIndex = ArenaAnalytics:GetAddonBracketIndex(bracket);
	stateData.matchType = matchType;

	stateData.mySpec = API:GetSpecialization();

	ArenaTracker:SetState("Pending");

	-- Rated matches may need to await season played for the bracket
	if(IsAwaitingSeasonPlayed()) then
		RequestRatedInfo();
	else
		ArenaTracker:StartNewOrContinueTracking();
	end
end


local function CheckRequiredField(field)
	local success = currentArena[field] and stateData[field] and currentArena[field] == stateData[field];
	if(not success) then
		Debug:LogWarning("CheckRequiredField failing field:", field, currentArena[field], stateData[field]);
	end
	return success;
end

local function CheckOptionalField(field)
	local success = not currentArena[field] or (stateData[field] and currentArena[field] == stateData[field]);
	if(not success) then
		Debug:LogWarning("CheckOptionalField failing field:", field, currentArena[field], stateData[field]);
	end
	return success;
end

function ArenaTracker:CompareExistingTracking()
	-- Returns true if the stateData matches the currentArena, false if it needs to reset before tracking
	assert(currentArena);

	-- No point keeping, if we never started tracking
	if(not currentArena.isTracking) then
		Debug:Log("CompareExistingTracking forcing reset: No previous tracking.", currentArena.isTracking)
		return false;
	end

	if(stateData.matchType == "rated" and not CheckRequiredField("seasonPlayed")) then
		return false;
	end

	if(not CheckRequiredField("mapId")) then
		return false;
	end

	if(not CheckRequiredField("bracket")) then
		return false;
	end

	if(not CheckRequiredField("bracketIndex")) then
		return false;
	end

	if(not CheckRequiredField("matchType")) then
		return false;
	end

	if(not CheckOptionalField("mySpec")) then
		return false;
	end

	Debug:LogTemp("CompareExistingTracking passed!");
	return true;
end


-- This is called once we know whether to reset or continue tracking.
function ArenaTracker:StartNewOrContinueTracking()
	if(not API:IsInArena()) then
		Debug:LogWarning("StartNewOrContinueTracking called outside arena.");
		return;
	end

	if(not stateData.battlefieldId) then
		Debug:LogWarning("StartNewOrContinueTracking called with missing battlefieldId!");
		return;
	end

	if(not ArenaTracker:IsInState("Pending")) then
		Debug:LogWarning("StartNewOrContinueTracking called with state:", ArenaTracker:GetStateName());
		return;
	end

	if(not ArenaTracker:CompareExistingTracking()) then
		Debug:LogGreen("Resetting currentArena for new tracking..");
		ArenaTracker:Reset();
	end

	ArenaTracker:HandleArenaStart(stateData);
end