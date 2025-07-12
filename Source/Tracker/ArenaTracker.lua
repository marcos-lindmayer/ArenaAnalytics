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

ArenaTracker.States = {
	None = 1,		-- Not in arena and not tracking
	Pending = 2,	-- Tracking is starting up, awaiting data 
	Starting = 3,	-- 
	Active = 4,		-- Arena is actively being tracked
	Ended = 5,		-- HandleArenaEnd has been triggered
};

-- Reverse lookup for numeric → string
ArenaTracker.TrackingStateNames = {}
for name, num in pairs(ArenaTracker.States) do
	ArenaTracker.TrackingStateNames[num] = name;
end

ArenaTracker.state = ArenaTracker.States.None;

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

	return self.States[stateName] or "Invalid";
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
function ArenaTracker:IsInState(stateName)
	Debug:Log("Setting tracking state:", self.lastState, self.state, self:ToState(stateName));
	return self.state == self:ToState(stateName);
end

-------------------------------------------------------------------------

local currentArena = {}; -- Not yet initialized

local function ReinitializeCurrentArena()
	ArenaAnalytics:InitializeTransientDB();
	currentArena = ArenaAnalyticsTransientDB.currentArena;
end

-- Arena variables
ArenaTracker.hasReceivedScore = nil;
ArenaTracker.isTracking = nil;

function ArenaTracker:GetCurrentArena()
	return ArenaAnalyticsTransientDB and ArenaAnalyticsTransientDB.currentArena;
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

function ArenaTracker:GetDeathData()
	assert(currentArena);
	if(type(currentArena.deathData) ~= "table") then
		Debug:LogError("Force reset DeathData from non-table value!");
		currentArena.deathData = TablePool:Acquire();
	end
	return currentArena.deathData;
end

-- Reset current arena values
function ArenaTracker:Reset()
	Debug:Log("Resetting current arena values..");

	-- Setup base tables
	ReinitializeCurrentArena();

	ArenaTracker.isTracking = false;

	-- Current Arena
	currentArena.isTracking = nil;

	currentArena.winner = nil; -- Raw winner team ID (2 = draw)

	currentArena.battlefieldId = nil;
	currentArena.mapId = nil;

	currentArena.playerName = nil;
	currentArena.mySpec = nil;

	currentArena.hasStartTime = nil; -- Start time existed before fixing at the end
	currentArena.hasRealStartTime = nil; -- Start time was set explicitly by gates opening
	currentArena.startTime = nil;
	currentArena.endTime = nil;

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
end

function ArenaTracker:Clear()
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

	return false;
end

-- Returns the season played expected once the active arena ends
function ArenaTracker:GetSeasonPlayed(bracketIndex)
    if(not API:IsInArena()) then
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

	if(seasonPlayed < currentArena.seasonPlayed) then
		Debug:LogError("ArenaTracker:GetSeasonPlayed", seasonPlayed, API:GetWinner(), currentArena.winner, currentArena.seasonPlayed);
	end
    return seasonPlayed;
end

-------------------------------------------------------------------------

-- Is tracking player, supports GUID, name and unitToken
function ArenaTracker:IsTrackingPlayer(playerID)
	return (ArenaTracker:GetPlayer(playerID) ~= nil);
end

function ArenaTracker:IsTrackingArena()
	return currentArena.mapId ~= nil and currentArena.isTracking and ArenaTracker.isTracking;
end

function ArenaTracker:GetArenaEndedProperly()
	return currentArena and currentArena.endedProperly;
end

function ArenaTracker:HasMapData()
	return currentArena and currentArena.mapId ~= nil;
end

function ArenaTracker:GetPlayer(playerID)
	if(not playerID or playerID == "") then
		return nil;
	end

	if(currentArena.players) then
		for i = 1, #currentArena.players do
			local player = currentArena.players[i];
			if (player) then
				if(Helpers:ToSafeLower(player.name) == Helpers:ToSafeLower(playerID)) then
					return player;
				elseif(player.GUID == playerID) then
					return player;
				else -- Unit Token
					local GUID = UnitGUID(playerID);
					if(GUID and GUID == player.GUID) then
						return player;
					end
				end
			end
		end
	end

	return nil;
end

function ArenaTracker:HasSpec(GUID)
	local player = ArenaTracker:GetPlayer(GUID);
	return player and Helpers:IsSpecID(player.spec);
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
function ArenaTracker:FillMissingPlayers(unitGUID, unitSpec)
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

			local name = Helpers:GetUnitFullName(unitToken);
			local player = ArenaTracker:GetPlayer(name);
			if(name and not player) then
				local GUID = UnitGUID(unitToken);
				local isEnemy = (group == "arena");
				local race_id = Helpers:GetUnitRace(unitToken);
				local class_id = Helpers:GetUnitClass(unitToken);
				local spec_id = GUID and GUID == unitGUID and tonumber(unitSpec);

				if(GUID and name) then
					player = ArenaTracker:CreatePlayerTable(isEnemy, GUID, name, race_id, (spec_id or class_id));
					table.insert(currentArena.players, player);

					if(not isEnemy and Inspection and Inspection.RequestSpec) then
						Debug:Log(unitToken, GUID);
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
function ArenaTracker:CreatePlayerTable(isEnemy, GUID, name, race_id, spec_id, kills, deaths, damage, healing)
	return {
		["isEnemy"] = isEnemy,
		["GUID"] = GUID,
		["name"] = name,
		["race"] = race_id,
		["spec"] = spec_id,
		["kills"] = kills,
		["deaths"] = deaths,
		["damage"] = damage,
		["healing"] = healing,
	};
end

local function hasValidDeathData(playerGUID)
	local deathData = ArenaTracker:GetDeathData();

	local existingData = deathData[playerGUID];
	if(type(existingData) == "table" and tonumber(existingData.time) and existingData.name) then
		return true;
	end

	return false;
end

local function removeDeath(playerGUID)
	local deathData = ArenaTracker:GetDeathData();
	deathData[playerGUID] = nil;
end

-- Called from unit actions, to remove false deaths
local function tryRemoveFromDeaths(playerGUID, spell)
	if(not hasValidDeathData(playerGUID)) then
		removeDeath(playerGUID);
		return;
	end

	local deathData = ArenaTracker:GetDeathData();
	local existingData = deathData[playerGUID];

	if(existingData) then
		local timeSinceDeath = time() - existingData.time;

		local minimumDelay = existingData.isHunter and 2 or 10;
		if(existingData.hasKillCredit) then
			minimumDelay = minimumDelay + 5;
		end

		if(timeSinceDeath > minimumDelay) then
			Debug:Log("Removed death by post-death action: ", spell, " for player: ", existingData.name, " Time since death: ", timeSinceDeath);
			removeDeath(playerGUID);
		end
	end
end

-- Handle a player's death, through death or kill credit message
local function handlePlayerDeath(playerGUID, isKillCredit)
	Debug:LogTemp("handlePlayerDeath", playerGUID, isKillCredit);

	if(playerGUID == nil) then
		return;
	end

	local class, race, name, realm = API:GetPlayerInfoByGUID(playerGUID);
	if(name == nil or name == "") then
		Debug:LogError("Invalid name of dead player. Skipping..");
		return;
	end

	if(not realm or realm == "") then
		name = Helpers:ToFullName(name);
	else
		name = name .. "-" .. realm;
	end

	Debug:LogGreen("Player Kill!", isKillCredit, name);

	-- Store death
	local deathData = ArenaTracker:GetDeathData();
	local death = deathData[playerGUID] or TablePool:Acquire();
	death.time = time();
	death.name = name;
	death.isHunter = (class == "HUNTER") or nil;
	death.hasKillCredit = isKillCredit or death.hasKillCredit;

	-- Validate that this is always true
	Debug:Assert(type(death) == "table");

	deathData[playerGUID] = death;

	if(ArenaTracker:IsTrackingShuffle() and (isKillCredit or class ~= "HUNTER")) then
		C_Timer.After(0, ArenaTracker.HandleRoundEnd);
	end
end

-- Commits current deaths to player stats (May be overridden by scoreboard, if value is trusted for the expansion)
function ArenaTracker:CommitDeaths()
	local deathData = ArenaTracker:GetDeathData();
	for GUID,data in pairs(deathData) do
		local player = ArenaTracker:GetPlayer(GUID);
		if(player and data) then
			-- Increment deaths
			player.deaths = (player.deaths or 0) + 1;
		end
	end
end

-- Fetch the real first death when saving the match
function ArenaTracker:GetFirstDeathFromCurrentArena()
	local deathData = ArenaTracker:GetDeathData();
	if(deathData == nil) then
		return;
	end

	local bestKey, bestTime;
	for key,data in pairs(deathData) do
		if(key and type(data) == "table" and data.time) then
			if(bestTime == nil or data.time < bestTime) then
				bestKey = key;
				bestTime = data.time;
			end
		else
			local player = ArenaTracker:GetPlayer(key);
			Debug:LogError("Invalid death data found:", key, player and player.name, type(data));
			Debug:LogTable(deathData);
		end
	end

	if(not bestKey or not deathData[bestKey]) then
		Debug:Log("Death data missing from currentArena.");
		return nil;
	end

	local firstDeathData = deathData[bestKey];
	return firstDeathData.name, firstDeathData.time;
end

function ArenaTracker:HandleOpponentUpdate()
	if (not API:IsInArena()) then
		return;
	end

	ArenaTracker:FillMissingPlayers();

	-- If API exist to get opponent spec, use it
	if(GetArenaOpponentSpec) then
		Debug:LogTemp("HandleOpponentUpdate")

		for i = 1, currentArena.size do
			local unitToken = "arena"..i;
			local player = ArenaTracker:GetPlayer(unitToken);
			if(player) then
				if(not Helpers:IsSpecID(player.spec)) then
					local spec_id = API:GetArenaPlayerSpec(i, true);
					ArenaTracker:OnSpecDetected(unitToken, spec_id);
				end
			end
		end
	end
end

function ArenaTracker:HandlePartyUpdate()
	if (not API:IsInArena()) then
		return;
	end

	ArenaTracker:FillMissingPlayers();

	for i = 1, currentArena.size do
		local unitToken = "party"..i;
		local player = ArenaTracker:GetPlayer(UnitGUID(unitToken));
		if(player and not Helpers:IsSpecID(player.spec)) then
			if(Inspection and Inspection.RequestSpec) then
				Debug:Log("Tracker: HandlePartyUpdate requesting spec:", unitToken, UnitGUID(unitToken));
				Inspection:RequestSpec(unitToken);
			end
		end
	end

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
		tryRemoveFromDeaths(sourceGUID, spellName);
	elseif(logEventType == "SPELL_AURA_APPLIED" or logEventType == "SPELL_AURA_REMOVED") then
		ArenaTracker:DetectSpec(sourceGUID, spellID, spellName);
	elseif(destGUID and destGUID:find("Player-", 1, true)) then
		-- Player Death
		if (logEventType == "UNIT_DIED") then
			handlePlayerDeath(destGUID, false);
		end
		-- Player killed
		if (logEventType == "PARTY_KILL") then
			handlePlayerDeath(destGUID, true);
		end
	end
end

function ArenaTracker:ProcessUnitAuraEvent(...)
	-- Excludes versions without spell detection included
	if(not SpecSpells or not SpecSpells.GetSpec) then
		return;
	end

	if (not API:IsInArena()) then
		return;
	end

	local unitTarget, updateInfo = ...;
	if(not updateInfo or updateInfo.isFullUpdate) then
		return;
	end

	if(updateInfo.addedAuras) then
		for _,aura in ipairs(updateInfo.addedAuras) do
			if(aura and aura.sourceUnit and aura.isFromPlayerOrPlayerPet) then
				local sourceGUID = UnitGUID(aura.sourceUnit);

				ArenaTracker:DetectSpec(sourceGUID, aura.spellId, aura.name);
			end
		end
	end
end

-- Detects spec if a spell is spec defining, attaches it to its
-- caster if they weren't defined yet, or adds a new unit with it
function ArenaTracker:DetectSpec(sourceGUID, spellID, spellName)
	if(not SpecSpells or not SpecSpells.GetSpec) then
		return;
	end

	-- Only players matter for spec detection
	if (not sourceGUID or not sourceGUID:find("Player-", 1, true)) then
		return;
	end

	-- Check if spell belongs to spec defining spells
	local spec_id = SpecSpells:GetSpec(spellID);
	if (spec_id ~= nil) then
		-- Check if unit should be added
		ArenaTracker:FillMissingPlayers(sourceGUID, spec_id);
		ArenaTracker:OnSpecDetected(sourceGUID, spec_id);
	end
end

function ArenaTracker:OnSpecDetected(playerID, spec_id)
	if(not playerID or not spec_id) then
		return;
	end

	local player = ArenaTracker:GetPlayer(playerID);
	if(not player) then
		return;
	end

	if(not Helpers:IsSpecID(player.spec) or player.spec == 13) then -- Preg doesn't count as a known spec
		Debug:Log("Assigning spec: ", spec_id, " for player: ", player.name);
		player.spec = spec_id;
	elseif(player.spec) then
		Debug:Log("Tracker: Keeping old spec:", player.spec, " for player: ", player.name);
	end
end

-------------------------------------------------------------------------

function ArenaTracker:Initialize()
	ReinitializeCurrentArena();

	ArenaTracker:SetState("None");

	-- Initialize submodules
	ArenaTracker:InitializeSubmodule_Enter();
	ArenaTracker:InitializeSubmodule_Start();
	ArenaTracker:InitializeSubmodule_GatesOpened();
	ArenaTracker:InitializeSubmodule_End();
	ArenaTracker:InitializeSubmodule_Exit();
	ArenaTracker:InitializeSubmodule_Shuffle();
end
