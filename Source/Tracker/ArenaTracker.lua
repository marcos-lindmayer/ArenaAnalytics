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

-- ArenaEnter and Compare declaration
ArenaTracker.stateData = {};

ArenaTracker.States = {
	None = 1,		-- Not in arena and not tracking
	Initiated = 2,	-- Tracking initiated, awaiting battlefieldId to enter pending state
	Pending = 3,	-- Tracking is starting up, awaiting data
	Starting = 4,	-- HandleArenaStart in progress, not yet fully active
	Active = 5,		-- Arena is actively being tracked
	Ended = 6,		-- HandleArenaEnd has been triggered
	Locked = 7,		-- Tracking complete, save required
	Saving = 8,		-- Attempted insert to match history
	Saved = 9,
};
ArenaTracker.state = ArenaTracker.States.None;

-- Reverse lookup for numeric → string
ArenaTracker.TrackingStateNames = {}
for name, num in pairs(ArenaTracker.States) do
	ArenaTracker.TrackingStateNames[num] = name;
end


-- Converts string → numeric tracking state
function ArenaTracker:ToState(value)
	local state = nil;

	if(type(value) == "number") then
		assert(self.TrackingStateNames[value], "Invalid ");
		return value;
	end

	state = value and self.States[value];

	assert(state, "Invalid state name: " .. (value or "nil"));
	return state;
end


-- Gets numeric state
function ArenaTracker:GetCurrentState()
	return self.state;
end


function ArenaTracker:GetState(stateName)
	if(not stateName) then
		return self.state;
	end

	return self.States[stateName] or -1;
end


-- Converts numeric → string tracking state
function ArenaTracker:GetStateName(stateNum)
	stateNum = stateNum or self.state;
	return self.TrackingStateNames[stateNum] or "Invalid";
end


-- Sets the current tracking state by string name
function ArenaTracker:SetState(stateName)
	local stateNum = self:ToState(stateName);
	self.lastState = self.state;
	self.state = stateNum;

	Debug:Log("Setting tracking state:", self.state, stateName, "lastState:", self.lastState, ArenaTracker:GetStateName(self.lastState));
end


-- Checks if state matches a given name
local function IsInState_Internal(stateName, index)
	return ArenaTracker.state == ArenaTracker:ToState(stateName);
end

function ArenaTracker:IsInState(...)
	local states = {...};
	for index in ipairs(states) do
		if(IsInState_Internal(states[index], index)) then
			return true;
		end
	end

	return false;
end


function ArenaTracker:IsLocked()
	return ArenaTracker:IsInState("Saving", "Locked");
end

-------------------------------------------------------------------------

-- Arena variables
ArenaTracker.hasReceivedScore = nil;
ArenaTracker.isTracking = nil;

local currentArena = {}; -- Not yet initialized

local function ReinitializeCurrentArena()
	ArenaAnalytics:InitializeTransientDB();
	currentArena = ArenaAnalyticsTransientDB.currentArena;
end


function ArenaTracker:IsShuffle()
	return currentArena.bracket == "shuffle";
end

function ArenaTracker:IsRated()
	return currentArena.matchType == "rated";
end

function ArenaTracker:IsWargame()
	return currentArena.matchType == "wargame";
end

function ArenaTracker:IsSkirmish()
	return currentArena.matchType == "skirmish";
end


-- Reset current arena values
function ArenaTracker:Reset()
	Debug:Log("Resetting current arena values..");

	-- Setup base tables
	ReinitializeCurrentArena();

	ArenaTracker.isTracking = false;

	-- Current Arena
	currentArena.isTracking = nil;
	currentArena.isHandlingExit = false;

	currentArena.winner = nil; -- Raw winner team ID (2 = draw)

	currentArena.battlefieldId = nil;
	currentArena.mapId = nil;

	currentArena.playerName = nil;
	currentArena.mySpec = nil;

	currentArena.hasStartTime = nil; -- Start time existed before fixing at the end
	currentArena.hasRealStartTime = nil; -- Start time was set explicitly by gates opening
	currentArena.startTime = nil;
	currentArena.endTime = nil;
	currentArena.duration = nil;

	currentArena.oldRating = nil;
	currentArena.seasonPlayed = nil;
	currentArena.requireRatingFix = nil;

	currentArena.partyRating = nil;
	currentArena.partyRatingDelta = nil;
	currentArena.partyMMR = nil;

	currentArena.enemyRating = nil;
	currentArena.enemyRatingDelta = nil;
	currentArena.enemyMMR = nil;

	currentArena.size = nil;
	currentArena.matchType = nil; -- rated, wargame, skirmish
	currentArena.bracket = nil; -- 2v2, 3v3, 5v5, shuffle
	currentArena.bracketIndex = nil;

	currentArena.ended = false;
	currentArena.endedProperly = false;
	currentArena.outcome = nil; -- Relative outcome by the end

	currentArena.players = TablePool:Acquire();
	currentArena.deathData = TablePool:Acquire();
	currentArena.committedRounds = TablePool:Acquire();

	-- Current Round
	currentArena.round = TablePool:Acquire();
	currentArena.round.team = TablePool:Acquire();
	currentArena.round.hasStarted = nil;
	currentArena.round.startTime = nil;

	currentArena.locked = false;
end


function ArenaTracker:Clear(respectLock)
	if(respectLock and ArenaTracker:IsLocked()) then
		return;
	end

	Debug:Log("Clearing current arena.");

	ArenaTracker.hasReceivedScore = nil;
	ArenaTracker.isTracking = nil;
	ArenaTracker:SetState("None");

	ArenaTracker:Reset();
end


function ArenaTracker:HasReliableOutcome()
	if(currentArena.winner ~= nil) then
		return true;
	end

	if(API:GetWinner() ~= nil) then
		return true;
	end

	if(ArenaTracker.hasReceivedScore) then
		return true;
	end

	return false;
end


-- Returns the season played expected once the active arena ends
function ArenaTracker:GetSeasonPlayed(bracketIndex)
    if(not API:IsInArena() or not ArenaTracker:IsRated()) then
        return nil;
    end

	bracketIndex = tonumber(bracketIndex or currentArena.bracketIndex);
	if(not bracketIndex) then
		return nil;
	end

	-- We can't determine season played, without a reliable state
	if(not ArenaTracker:HasReliableOutcome()) then
		return nil;
	end

	local seasonPlayed = API:GetSeasonPlayed(bracketIndex);
	if(not seasonPlayed) then
		return nil;
	end

    if(not API:GetWinner() and not currentArena.winner) then
        seasonPlayed = seasonPlayed + 1;
    end

	if(currentArena.seasonPlayed and seasonPlayed < currentArena.seasonPlayed) then
		Debug:LogWarning("ArenaTracker:GetSeasonPlayed trying to reduce post match season played.", seasonPlayed, API:GetWinner(), currentArena.winner, currentArena.seasonPlayed);
	end
    return seasonPlayed;
end


-------------------------------------------------------------------------


-- Is tracking player, supports GUID, name and unitToken
function ArenaTracker:IsTrackingPlayer(playerID)
	return (ArenaTracker:GetPlayer(playerID) ~= nil);
end

function ArenaTracker:IsTrackingArena(skipTransient)
	return currentArena.mapId ~= nil and currentArena.isTracking and (skipTransient or ArenaTracker.isTracking);
end

function ArenaTracker:GetArenaEndedProperly()
	return currentArena and currentArena.endedProperly;
end

function ArenaTracker:HasMapData()
	return currentArena and currentArena.mapId ~= nil;
end


function ArenaTracker:GetPlayer(playerID)
	if(not Helpers:IsValidValue(playerID)) then
		return nil;
	end

	if(not currentArena.players) then
		return nil;
	end

	for i = 1, #currentArena.players do
		local player = currentArena.players[i];
		if (player) then
			if(Helpers:ToSafeLower(player.name) == Helpers:ToSafeLower(playerID)) then
				return player;
			elseif(player.GUID == playerID) then
				return player;
			else -- Unit Token
				local GUID = Helpers:UnitGUID(playerID);
				if(GUID and not API:IsSecretValue(GUID) and GUID == player.GUID) then
					return player;
				end
			end
		end
	end

	return nil;
end


function ArenaTracker:HandleScoreUpdate()
	if(not API:IsInArena()) then
		return;
	end

	ArenaTracker:HandlePreTrackingScoreEvent();

	if(not ArenaTracker:IsTrackingArena()) then
		return;
	end

	ArenaTracker.hasReceivedScore = true;
	currentArena.winner = API:GetWinner() or currentArena.winner;
end


function ArenaTracker:HandleRatedUpdate()
	if(not API:IsInArena()) then
		return;
	end

	ArenaTracker:HandlePreTrackingRatedEvent();

	if(not ArenaTracker:IsTrackingArena()) then
		return;
	end

	-- We can't trust seasonPlayed from ratedInfo before we know of a winner
	if(currentArena.winner ~= nil) then
		currentArena.seasonPlayed = ArenaTracker:GetSeasonPlayed(currentArena.bracketIndex) or currentArena.seasonPlayed;
	end
end


-- Search for missing members of group (party or arena), 
-- Adds each non-tracked player to currentArena.players table.
-- If spec and GUID are passed, include them when creating the player table
function ArenaTracker:FillMissingPlayers()
	if(not currentArena.size) then
		Debug:Log("FillMissingPlayers missing size.");
		return;
	end

	if(#currentArena.players >= 2*currentArena.size) then
		return;
	end

	for _,group in ipairs({"party", "arena"}) do
		for i = 1, currentArena.size do
			local unitToken = group..i;
			if(UnitExists(unitToken)) then
				local name = API:GetUnitFullName(unitToken);
				local player = ArenaTracker:GetPlayer(name);
				if(name and not player) then
					local isEnemy = (group == "arena");

					player = ArenaTracker:CreatePlayerTable(isEnemy, name, unitToken);
					table.insert(currentArena.players, player);

					Debug:Log("Creating player table.", name, "IsFemale:", player.isFemale);

					if(not isEnemy and Inspection and Inspection.RequestSpec) then
						Inspection:RequestSpec(unitToken);
					end
				end
			end
		end
	end

	if(#currentArena.players == 2*currentArena.size) then
		ArenaTracker:UpdateRoundTeam();
	end
end


-- Returns a table with unit information to be placed inside arena.players
function ArenaTracker:CreatePlayerTable(isEnemy, name, unitToken, spec_id)
	unitToken = tostring(unitToken);

	local data = {
		isEnemy = isEnemy,
		name = name,
		GUID = Helpers:UnitGUID(unitToken),
		race = Helpers:GetUnitRace(unitToken),
		isFemale = Helpers:IsUnitFemale(unitToken),
		spec = spec_id or Helpers:GetUnitClass(unitToken),

		isSelf = currentArena.playerName and name == currentArena.playerName or nil,

		unitToken = unitToken,
		petToken = unitToken and unitToken.."pet",
	};

	return data;
end

function ArenaTracker:TryFindPetOwnerGUID(petGUID)
	if(not API:IsInArena()) then
		return;
	end

	if(type(currentArena.players) ~= "table") then
		return nil;
	end

	if(not petGUID or not petGUID:find("Pet-", 1, true)) then
		return nil;
	end

	for _,player in ipairs(currentArena.players) do
		local petToken = player and player.petToken;
		if(petToken and petGUID == UnitGUID(petToken)) then
			return player.GUID;
		end
	end

	return nil;
end


function ArenaTracker:HandlePartyUpdate()
	Debug:Log("ArenaTracker:HandlePartyUpdate()")

	if (not API:IsInArena()) then
		return;
	end

	ArenaTracker:FillMissingPlayers();

	ArenaTracker:RequestPartySpecs();

	-- Internal IsTrackingShuffle() check
	ArenaTracker:CheckRoundEnded();
	ArenaTracker:UpdateRoundTeam();
end


function ArenaTracker:ForceTeamsUpdate()
	ArenaTracker:HandleOpponentUpdate();
	ArenaTracker:HandlePartyUpdate();
end


-- Attempts to get initial data on arena players:
-- GUID, name, race, class, spec
function ArenaTracker:ProcessCombatLogEvent(...)
	if (not API:IsInArena()) then
		return;
	end

	-- Tracking teams for spec/race and in case arena is quitted
	local timestamp,logEventType,_,sourceGUID,_,_,_,destGUID,_,_,_,spellID,spellName = CombatLogGetCurrentEventInfo();
	if (logEventType == "SPELL_CAST_SUCCESS") then
		ArenaTracker:DetectSpec(sourceGUID, spellID, spellName);
		ArenaTracker:TryRemoveFromDeaths(sourceGUID, spellName);
	elseif(logEventType == "SPELL_AURA_APPLIED" or logEventType == "SPELL_AURA_REMOVED") then
		ArenaTracker:DetectSpec(sourceGUID, spellID, spellName);
	elseif(destGUID and destGUID:find("Player-", 1, true)) then
		-- Player Death
		if (logEventType == "UNIT_DIED") then
			ArenaTracker:HandlePlayerDeath(destGUID, false);
		end
		-- Player killed
		if (logEventType == "PARTY_KILL") then
			ArenaTracker:HandlePlayerDeath(destGUID, true);
		end
	end
end


-------------------------------------------------------------------------


function ArenaTracker:Initialize()
	ReinitializeCurrentArena();

	ArenaTracker:SetState("None");

	-- Initialize submodules
	ArenaTracker:InitializeSubmodule_Compare();
	ArenaTracker:InitializeSubmodule_Enter();
	ArenaTracker:InitializeSubmodule_Start();
	ArenaTracker:InitializeSubmodule_GatesOpened();
	ArenaTracker:InitializeSubmodule_End();
	ArenaTracker:InitializeSubmodule_Exit();

	ArenaTracker:InitializeSubmodule_Shuffle();
	ArenaTracker:InitializeSubmodule_Deaths();
	ArenaTracker:InitializeSubmodule_Specs();
end
