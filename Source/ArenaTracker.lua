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

-------------------------------------------------------------------------

function ArenaTracker:getCurrentArena()
	return currentArena;
end

-- Arena variables
local currentArena = {}
local currentRound = {}

-- Reset current arena values
function ArenaTracker:Reset()
	ArenaAnalytics:Log("Resetting current arena values..");

	-- Current Arena
	currentArena.battlefieldId = nil;
	currentArena.mapId = nil;

	currentArena.playerName = "";

	currentArena.startTime = nil;
	currentArena.hasRealStartTime = nil;
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
	currentArena.isRated = nil;
	currentArena.isShuffle = nil;

	currentArena.players = {};

	currentArena.ended = false;
	currentArena.endedProperly = false;
	currentArena.won = nil;

	currentArena.rounds = {}

	currentArena.deathData = {};

	-- Current Round
	currentRound.hasStarted = nil;
	currentRound.startTime = nil;
	currentRound.team = {}
end
ArenaTracker:Reset();

-------------------------------------------------------------------------

function ArenaTracker:UpdateRoundTeam()
	if(not currentArena.isShuffle) then
		return;
	end

	if(ArenaTracker:IsSameRoundTeam()) then
		return;
	end

	currentRound.team = {};
	for i=1, 2 do
		local name = Helpers:GetUnitFullName("party"..i);
		tinsert(currentRound.team, name);
		ArenaAnalytics:Log("Adding team player:", name, #currentRound.team);
	end

	ArenaAnalytics:Log("UpdateRoundTeam", #currentRound.team)
end

function ArenaTracker:RoundTeamContainsPlayer(playerName)
	if(not playerName) then
		return nil;
	end

	for _,teamMember in ipairs(currentRound.team) do
		if(teamMember == playerName) then
			return true;
		end
	end

	return playerName == Helpers:GetPlayerName();
end

function ArenaTracker:IsSameRoundTeam()
	if(not currentArena.isShuffle) then
		return nil;
	end

	for i=1, 2 do
		local unitToken = "party"..i;
		local unitName = Helpers:GetUnitFullName(unitToken);

		if(unitName and not ArenaTracker:RoundTeamContainsPlayer(unitName)) then
			return false;
		end
	end

	return true;
end

function ArenaTracker:CommitCurrentRound()
	if(not currentRound.hasStarted) then
		return;
	end

	local roundData = {
		duration = currentRound.startTime and (time() - currentRound.startTime) or nil,
		firstDeath = ArenaTracker:GetFirstDeathFromCurrentArena(),
		team = {},
		enemy = {},
	};

	-- Fill round teams
	for _,player in ipairs(currentArena.players) do
		if(player and player.name) then
			local team = ArenaTracker:RoundTeamContainsPlayer(player.name) and roundData.team or roundData.enemy;
			tinsert(team, player.name);
		end
	end

	ArenaAnalytics:Log("Adding round to currentArena.rounds!", roundData.duration, roundData.firstDeath, #roundData.team, #roundData.enemy, #currentArena.players);
	tinsert(currentArena.rounds, roundData);

	-- Reset currentArena round data
	currentArena.deathData = {};
	
	-- Reset current round
	currentRound.team = {};
	currentRound.startTime = nil;
	currentRound.hasStarted = false;
end

-------------------------------------------------------------------------

-- Is tracking player, supports GUID, name and unitToken
function ArenaTracker:IsTrackingPlayer(playerID)
	return (ArenaTracker:GetPlayer(playerID) ~= nil);
end

function ArenaTracker:IsTrackingArena()
	return currentArena.mapId ~= nil;
end

function ArenaTracker:GetArenaEndedProperly()
	return currentArena.endedProperly;
end

-- TEMP (?)
function ArenaTracker:SetNotEnded()
	currentArena.ended = false;
end

function ArenaTracker:HasMapData()
	return currentArena.mapId ~= nil;
end

function ArenaTracker:GetPlayer(playerID)
	if(not playerID or playerID == "") then
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
				local GUID = UnitGUID(playerID);
				if(GUID and GUID == player.GUID) then
					return player;
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

-- Gates opened, match has officially started
function ArenaTracker:HandleArenaStart(...)
	currentArena.startTime = time();
	currentArena.hasRealStartTime = true; -- The start time has been set by gates opened

	currentRound.startTime = time();
	currentRound.hasStarted = true;

	ArenaTracker:FillMissingPlayers();
	ArenaTracker:HandleOpponentUpdate();
	ArenaTracker:UpdateRoundTeam();

	ArenaAnalytics:Log("Match started!", API:GetCurrentMapID(), GetZoneText(), #currentArena.players);
end

-- Begins capturing data for the current arena
-- Gets arena player, size, map, ranked/skirmish
function ArenaTracker:HandleArenaEnter(...)
	if(ArenaTracker:IsTrackingArena()) then
		return;
	end

	ArenaTracker:Reset();

	-- Update start time immediately, might be overridden by gates open if it hasn't happened yet.
	currentArena.startTime = time();

	local battlefieldId = ...;
	currentArena.battlefieldId = battlefieldId or ArenaAnalytics:GetActiveBattlefieldID();

	if(not currentArena.battlefieldId) then
		ArenaAnalytics:Log("ERROR: Invalid Battlefield ID in HandleArenaEnter");
	end

	local status, teamSize, isRated = API:GetBattlefieldStatus(currentArena.battlefieldId);
	if (status ~= "active") then
		return false
	end
	ArenaAnalytics:Log("Team Size:", teamSize, API:IsSoloShuffle());
	
	currentArena.playerName = Helpers:GetPlayerName();
	currentArena.isRated = isRated;
	
	if(API:IsSoloShuffle()) then
		currentArena.isShuffle = true;
		currentArena.size = 3;
	else
		currentArena.size = teamSize;
	end
	ArenaAnalytics:Log("TeamSize:", teamSize, currentArena.size, currentArena.isShuffle)

	ArenaTracker:UpdateBracket();

	if(isRated) then
		local oldRating, seasonPlayed = API:GetPersonalRatedInfo(currentArena.bracketIndex);
		if(GetBattlefieldWinner()) then
			-- Get last rating, since we already found the winner here.
			local season = GetCurrentArenaSeason();
			currentArena.oldRating = ArenaAnalytics:GetLatestRating(currentArena.bracketIndex, season, (seasonPlayed and seasonPlayed - 1));
			currentArena.seasonPlayed = seasonPlayed;
		else
			currentArena.oldRating = oldRating;
			currentArena.seasonPlayed = seasonPlayed and seasonPlayed + 1 or nil;  -- Season played after winner is determined
		end
	end

	-- Add self
	if (not ArenaTracker:IsTrackingPlayer(currentArena.playerName)) then
		-- Add player
		local GUID = UnitGUID("player");
		local name = currentArena.playerName;
		local race_id = Helpers:GetUnitRace("player");
		local class_id = Helpers:GetUnitClass("player");
		local spec_id = API:GetMySpec() or class_id;
		ArenaAnalytics:Log("Using MySpec:", spec_id);

		local player = ArenaTracker:CreatePlayerTable(false, GUID, name, race_id, spec_id);
		table.insert(currentArena.players, player);
	end

	if(ArenaAnalytics.DataSync) then
		ArenaAnalytics.DataSync:sendMatchGreetingMessage();
	end

	currentArena.mapId = API:GetCurrentMapID();
	ArenaAnalytics:Log("Match entered! Tracking mapId: ", currentArena.mapId);

	RequestBattlefieldScoreData();
end

function ArenaTracker:CheckRoundEnded()
	if(not API:IsInArena() or not currentArena.isShuffle) then
		return;
	end

	if(not ArenaTracker:IsTrackingArena() or not currentRound.hasStarted) then
		ArenaAnalytics:Log("CheckRoundEnded called while not tracking arena, or without active shuffle round.", currentRound.hasStarted);
		return;
	end
	
	-- Check if this is a new round
	if(#currentRound.team ~= 2) then
		ArenaAnalytics:Log("CheckRoundEnded missing players.");
		return;
	end
	
	-- Team remains same, thus round has not changed.
	if(ArenaTracker:IsSameRoundTeam()) then
		ArenaAnalytics:Log("CheckRoundEnded has same team.");
		return;
	end

	ArenaAnalytics:Log("CheckRoundEnded");
	ArenaTracker:HandleRoundEnd();
end

-- Solo Shuffle specific round end
function ArenaTracker:HandleRoundEnd()
	if(not API:IsInArena()) then
		return;
	end

	ArenaAnalytics:Log("HandleRoundEnd!", #currentArena.players);

	ArenaTracker:CommitCurrentRound();
	ArenaTracker:UpdateRoundTeam();
end

-- Gets arena information when it ends and the scoreboard is shown
-- Matches obtained info with previously collected player values
function ArenaTracker:HandleArenaEnd()
	currentArena.endedProperly = true;
	currentArena.ended = true;

	ArenaAnalytics:Log("HandleArenaEnd!", #currentArena.players);

	local winner = GetBattlefieldWinner();
	local players = {};

	-- Figure out how to default to nil, without failing to count losses.
	local myTeamIndex = nil;

	for i=1, GetNumBattlefieldScores() do
		local name, race_id, spec_id, teamIndex, kills, deaths, damage, healing = API:GetBattlefieldScore(i);

		-- Find or add player
		local player = ArenaTracker:GetPlayer(name);
		if(not player) then
			-- Use scoreboard info
			ArenaAnalytics:Log("Creating new player by scoreboard:", name);
			player = ArenaTracker:CreatePlayerTable(nil, nil, name, race_id, spec_id, kills, deaths, damage, healing);
		end

		player.teamIndex = teamIndex;
		player.spec = Helpers:IsSpecID(player.spec) and player.spec or spec_id;
		player.race = player.race or race_id;
		player.kills = kills;
		player.deaths = deaths;
		player.damage = damage;
		player.healing = healing;

		if (name == currentArena.playerName) then
			ArenaAnalytics:Log("My Team:", teamIndex);
			myTeamIndex = teamIndex;
		elseif(currentArena.isShuffle) then
			player.isEnemy = true;
		end

		if(player.name ~= nil) then
			table.insert(players, player);
		end
	end

	-- Assign isEnemy value
	if(not currentArena.isShuffle) then
		for _,player in ipairs(players) do
			if(player and player.teamIndex) then
				player.isEnemy = (player.teamIndex ~= myTeamIndex);
			end
		end
	end

	-- Assign Winner
	ArenaAnalytics:Log("My faction: ", myTeamIndex, "(Winner:", winner,")")
	if(winner == 255) then
		currentArena.won = 2;
	elseif(winner ~= nil) then
		currentArena.won = (myTeamIndex == winner);
	end

	-- Process ranked information
	if (currentArena.isRated and myTeamIndex) then
		local otherTeamIndex = (myTeamIndex == 0) and 1 or 0;

		currentArena.partyMMR = API:GetTeamMMR(myTeamIndex);
		currentArena.enemyMMR = API:GetTeamMMR(otherTeamIndex);
	end

	currentArena.players = players;

	ArenaAnalytics:Log("Match ended!", currentArena.mapId, GetZoneText(), #currentArena.players);
end

-- Player left an arena (Zone changed to non-arena with valid arena data)
function ArenaTracker:HandleArenaExit()
	assert(currentArena.size);
	assert(currentArena.mapId);

	if(Inspection and Inspection.CancelTimer) then
		Inspection:CancelTimer();
	end

	-- Solo Shuffle
	ArenaTracker:HandleRoundEnd();

	if(not currentArena.endedProperly) then
		currentArena.ended = true;
		currentArena.won = false;

		ArenaAnalytics:Log("Detected early leave. Has valid current arena: ", currentArena.mapId);
	end

	ArenaAnalytics:Log("Exited Arena:", API:GetPersonalRatedInfo(currentArena.bracketIndex));

	if(currentArena.isRated and not currentArena.partyRating) then
		local newRating, seasonPlayed = API:GetPersonalRatedInfo(currentArena.bracketIndex);
		if(newRating and seasonPlayed) then
			local oldRating = currentArena.oldRating;
			if(not oldRating) then
				local season = GetCurrentArenaSeason() or 0;
				oldRating = ArenaAnalytics:GetLatestRating(currentArena.bracketIndex, season, (seasonPlayed - 1));
			end

			currentArena.partyRating = newRating;
			currentArena.partyRatingDelta = oldRating and newRating - oldRating or nil;
		else
			ArenaAnalytics:Log("Warning: Nil current rating retrieved from API upon leaving arena.");
		end

		if(currentArena.seasonPlayed) then
			if(seasonPlayed and seasonPlayed < currentArena.seasonPlayed) then
				-- Rating has updated, no longer needed to store transient Season Played for fixup.
				currentArena.requireRatingFix = true;
			else
				ArenaAnalytics:Log("Tracker: Invalid season played or already up to date.", seasonPlayed, currentArena.seasonPlayed);
			end
		else
			ArenaAnalytics:Log("Tracker: No season played stored on currentArena");
		end
	end

	ArenaAnalytics:InsertArenaToMatchHistory(currentArena);
end

-- Search for missing members of group (party or arena), 
-- Adds each non-tracked player to currentArena.players table.
-- If spec and GUID are passed, include them when creating the player table
function ArenaTracker:FillMissingPlayers(unitGUID, unitSpec)
	if(not currentArena.size) then
		ArenaAnalytics:Log("FillMissingPlayers missing size.");
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

					if(not isEnemy) then
						Inspection:RequestSpec(unitToken)
					end
				end
			elseif(player) then
				ArenaAnalytics:Log("FillMissingPlayer rejecting:", player.name, group, class_id, spec_id, #currentArena.players);
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
		["role"] = Internal:GetRoleBitmap(spec_id),
		["kills"] = kills,
		["deaths"] = deaths,
		["damage"] = damage,
		["healing"] = healing,
	};
end

-- Called from unit actions, to remove false deaths
local function tryRemoveFromDeaths(playerGUID, spell)
	local existingData = currentArena.deathData[playerGUID];
	if(existingData ~= nil) then
		local timeSinceDeath = time() - existingData.time;

		local minimumDelay = existingData.isHunter and 2 or 10;
		if(existingData.hasKillCredit) then
			minimumDelay = minimumDelay + 5;
		end

		if(timeSinceDeath > 0) then
			ArenaAnalytics:Log("Removed death by post-death action: ", spell, " for player: ",currentArena.deathData[playerGUID].name, " Time since death: ", timeSinceDeath);
			currentArena.deathData[playerGUID] = nil;
		end
	end
end

-- Fetch the real first death when saving the match
function ArenaTracker:GetFirstDeathFromCurrentArena()
	if(currentArena.deathData == nil) then
		return;
	end

	local bestKey, bestTime;
	for key,data in pairs(currentArena.deathData) do
		if(bestTime == nil or data.time < bestTime) then
			bestKey = key;
			bestTime = data.time;
		end
	end

	if(not bestKey or not currentArena.deathData[bestKey]) then
		ArenaAnalytics:Log("Death data missing from currentArena.");
		return nil;
	end

	return currentArena.deathData[bestKey].name;
end

-- Handle a player's death, through death or kill credit message
local function handlePlayerDeath(playerGUID, isKillCredit)
	if(playerGUID == nil) then
		return;
	end

	currentArena.deathData[playerGUID] = currentArena.deathData[playerGUID] or {}

	local class, race, name, realm = API:GetPlayerInfoByGUID(playerGUID);
	if(not realm or realm == "") then
		name = Helpers:ToFullName(name);
	else
		name = name .. "-" .. realm;
	end

	ArenaAnalytics:Log("Player Kill!", isKillCredit, name);

	-- Store death
	currentArena.deathData[playerGUID] = {
		["time"] = time(), 
		["GUID"] = playerGUID,
		["name"] = name,
		["isHunter"] = (class == "HUNTER") or nil,
		["hasKillCredit"] = isKillCredit or currentArena.deathData[playerGUID].hasKillCredit,
	};

	if(currentArena.isShuffle and (isKillCredit or class ~= "HUNTER")) then
		ArenaTracker:HandleRoundEnd();
	end
end

function ArenaTracker:UpdateBracket()
	if(currentArena.size) then
		local bracket = nil;
		if(currentArena.isShuffle) then
			bracket = "shuffle";
		elseif(currentArena.size == 2) then
			bracket = "2v2";
		elseif(currentArena.size == 3) then
			bracket = "3v3";
		elseif(currentArena.size == 5) then
			bracket = "5v5";
		else
			ArenaAnalytics:Log("Tracker: Failed to determine bracket!", currentArena.size);
		end

		ArenaAnalytics:Log("Setting bracket:", bracket);
		currentArena.bracketIndex = ArenaAnalytics:GetAddonBracketIndex(bracket);
	end
end

function ArenaTracker:HandleOpponentUpdate()
	if (not API:IsInArena()) then
		return;
	end

	ArenaTracker:FillMissingPlayers();

	-- If API exist to get opponent spec, use it
	if(GetArenaOpponentSpec) then
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
	else
		ArenaAnalytics:Log("GetArenaOpponentSpec was nil.");
	end
end

function ArenaTracker:HandlePartyUpdate()
	if (not API:IsInArena()) then
		return;
	end

	ArenaTracker:FillMissingPlayers();

	for i = 1, currentArena.size do
		local unit = "party"..i;
		local player = ArenaTracker:GetPlayer(UnitGUID(unit));
		if(player and not Helpers:IsSpecID(player.spec)) then
			if(Inspection and Inspection.RequestSpec) then
				ArenaAnalytics:Log("Tracker: HandlePartyUpdate requesting spec:", unit);
				Inspection:RequestSpec(unit);
			end
		end
	end

	if(currentArena.isShuffle) then
		ArenaTracker:CheckRoundEnded();
		ArenaTracker:UpdateRoundTeam();
	end
end

function ArenaTracker:HandleInspect(...)
	if(not API.GetInspectSpecialization) then
		return;
	end

	local GUID = ...;
	local player = ArenaTracker:GetPlayer(GUID);
	if(player and not Helpers:IsSpecID(player.spec)) then
		for i=1, 4 do
			local playerGUID = UnitGUID("party"..i);
			if(playerGUID == GUID) then
				local specID = API:GetInspectSpecialization("party"..i);
				player.spec = API:GetMappedAddonSpecID(specID);
				ArenaAnalytics:Log("HandleInspect:", GUID, player.spec);
				break;
			end
		end
	end

	ArenaAnalytics:Log("Clearing inspect player")
	ClearInspectPlayer();
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
	elseif(destGUID and destGUID:find("Player")) then
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

				ArenaAnalytics:Log("New Aura!", aura.spellId, aura.name)
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
	if (not string.find(sourceGUID, "Player-")) then
		return;
	end

	-- Check if spell belongs to spec defining spells
	local spec_id, shouldDebug = SpecSpells:GetSpec(spellID);
	if(shouldDebug ~= nil) then
		ArenaAnalytics:Log("DEBUG ID Detected spec: ", sourceGUID, spellID, spellName);
	end

	if (spec_id ~= nil) then
		if(ArenaTracker:IsTrackingPlayer(playerID)) then
			ArenaTracker:OnSpecDetected(sourceGUID, spec_id);
		end

		-- Check if unit should be added
		ArenaTracker:FillMissingPlayers(sourceGUID, spec_id);
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
		ArenaAnalytics:Log("Assigning spec: ", spec_id, " for player: ", player.name);
		player.spec = spec_id;
	elseif(player.spec) then
		ArenaAnalytics:Log("Tracker: Keeping old spec:", player.spec, " for player: ", player.name);
	end
end