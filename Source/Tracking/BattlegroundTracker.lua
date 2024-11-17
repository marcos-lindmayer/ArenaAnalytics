local _, ArenaAnalytics = ... -- Namespace
local BattlegroundTracker = ArenaAnalytics.BattlegroundTracker;

-- Local module aliases
local Constants = ArenaAnalytics.Constants;
local SpecSpells = ArenaAnalytics.SpecSpells;
local API = ArenaAnalytics.API;
local Helpers = ArenaAnalytics.Helpers;
local Internal = ArenaAnalytics.Internal;
local Localization = ArenaAnalytics.Localization;
local Inspection = ArenaAnalytics.Inspection;
local Events = ArenaAnalytics.Events;
local TablePool = ArenaAnalytics.TablePool;
local BattlegroundMatch = ArenaAnalytics.BattlegroundMatch;
local Sessions = ArenaAnalytics.Sessions;
local Import = ArenaAnalytics.Import;
local Filters = ArenaAnalytics.Filters;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------
-- Battleground variables
local currentBattleground = {}

function BattlegroundTracker:GetCurrentBattleground()
	return currentBattleground;
end

-- Reset current Battleground values
function BattlegroundTracker:Reset()
	ArenaAnalytics:Log("Resetting current Battleground values..");

	-- Current Battleground
	currentBattleground.battlefieldId = nil;
	currentBattleground.mapId = nil;

	currentBattleground.playerName = "";
	currentBattleground.myTeam = nil;

	currentBattleground.startTime = nil;
	currentBattleground.hasRealStartTime = nil;
	currentBattleground.endTime = nil;

	currentBattleground.oldRating = nil;
	currentBattleground.seasonPlayed = nil;
	currentBattleground.requireRatingFix = nil;

	currentBattleground.partyRating = nil;
	currentBattleground.partyRatingDelta = nil;
	currentBattleground.partyMMR = nil;

	currentBattleground.enemyRating = nil;
	currentBattleground.enemyRatingDelta = nil;
	currentBattleground.enemyMMR = nil;

	currentBattleground.size = nil;
	currentBattleground.isShuffle = nil;
	currentBattleground.matchType = nil;
	currentBattleground.bracket = nil;

	TablePool:ReleaseNested(currentBattleground.players);
	TablePool:Release(currentBattleground.knownSpecs);
	TablePool:Release(currentBattleground.knownHeroSpecs);

	currentBattleground.players = TablePool:Acquire();
	currentBattleground.knownSpecs = TablePool:Acquire();
	currentBattleground.knownHeroSpecs = TablePool:Acquire();

	currentBattleground.ended = false;
	currentBattleground.endedProperly = false;
	currentBattleground.outcome = nil;

	ArenaAnalyticsDB.currentMatch = currentBattleground;
end

function BattlegroundTracker:Clear()
	ArenaAnalytics:Log("Clearing current Battleground.");

	ArenaAnalyticsDB.currentMatch = nil;
	currentBattleground = {};
end

-------------------------------------------------------------------------

function BattlegroundTracker:IsTracking()
	return currentBattleground.mapId ~= nil;
end

-------------------------------------------------------------------------

function BattlegroundTracker:HandleSpecDetected(GUID, spec_id, hero_spec_id)
	local hasNewSpec = nil;

	local playerName = Helpers:GetFullNameByGUID(GUID);
	if(not playerName) then
		return;
	end

	-- Add to found specs and hero specs if not already there.
	if(not currentBattleground.knownSpecs[playerName] and spec_id) then
		currentBattleground.knownSpecs[playerName] = spec_id;
		hasNewSpec = true;
	end

	if(not currentBattleground.knownHeroSpecs[playerName] and hero_spec_id) then
		currentBattleground.knownHeroSpecs[playerName] = hero_spec_id;
		hasNewSpec = true;
	end

	-- Find and update player, if either spec were new.
	if(hasNewSpec) then
		local player = BattlegroundTracker:FindOrAddPlayer(playerName);
		if(player) then
			player.spec = spec_id;
			player.heroSpec = hero_spec_id;
		end
	end
end

function BattlegroundTracker:IsTrackingPlayer(playerName)
	return playerName and currentBattleground.players and currentBattleground.players[playerName] ~= nil;
end

function BattlegroundTracker:FindOrAddPlayer(playerName)
	if(not playerName) then
		return nil;
	end

	if(not BattlegroundTracker:IsTrackingPlayer(playerName)) then
		local player = TablePool:Acquire();
		player.name = playerName;
		currentBattleground.players[playerName] = player;
	end

	return currentBattleground.players[playerName];
end

function BattlegroundTracker:UpdatePlayers()
	if(not BattlegroundTracker:IsTracking()) then
		return;
	end

	for i=1, GetNumBattlefieldScores() do
		local score = API:GetPlayerScore(i, true);
		if(score and score.name) then
			if(score.name == currentBattleground.playerName) then
				score.isSelf = true;
			end

			local player = BattlegroundTracker:FindOrAddPlayer(score.name);
			if(player) then
				TablePool:Release(player.score);
				player.score = score;
			else
				ArenaAnalytics:LogWarning("Failed to add player:", score.name);
			end
		end
	end
end

function BattlegroundTracker:IsTrackingCurrentBattleground(battlefieldId, bracket)
	if(not API:IsInArena()) then
		ArenaAnalytics:Log("IsTrackingCurrentBattleground: Not in match.")
		return false;
	end

	local match = ArenaAnalyticsDB.currentMatch;
	if(not match) then
		ArenaAnalytics:Log("IsTrackingCurrentBattleground: No existing match.", match, ArenaAnalyticsDB.currentMatch);
		return false;
	end

	if(match.bracket ~= bracket) then
		ArenaAnalytics:Log("IsTrackingCurrentBattleground: New bracket.");
		return false;
	end

	if(match.battlefieldId ~= battlefieldId) then
		ArenaAnalytics:Log("IsTrackingCurrentBattleground: New battlefield id.");
		return false;
	end

	if(match.matchType == "rated") then
		if(not match.seasonPlayed) then
			ArenaAnalytics:Log("IsTrackingCurrentBattleground: Existing rated match has no season played.", match.seasonPlayed)
			return false;
		end

		local _, seasonPlayed = API:GetPersonalRatedInfo(bracket);
		local trackedSeasonPlayed = match.seasonPlayed - (match.endedProperly and 1 or 0);
		if(not seasonPlayed or seasonPlayed ~= trackedSeasonPlayed) then
			ArenaAnalytics:Log("IsTrackingCurrentBattleground: Invalid season played, or mismatch to tracked value.", seasonPlayed, match.seasonPlayed)
			return false;
		end
	end

	ArenaAnalytics:Log("IsTrackingCurrentBattleground: Match alrady tracked")
	return true;
end

function BattlegroundTracker:HandleEnter()
	if(BattlegroundTracker:IsTracking()) then
		return;
	end

	-- Retrieve current match info
	local battlefieldId = API:GetActiveBattlefieldID();
	if(not battlefieldId) then
		return;
	end

	Events:RegisterBattlegroundEvents();

	local status, bracket, matchType, teamSize, isShuffle = API:GetBattlefieldStatus(battlefieldId);

	if(not BattlegroundTracker:IsTrackingCurrentBattleground(battlefieldId, bracket)) then
		BattlegroundTracker:Reset();
	else
		ArenaAnalytics:Log("Keeping existing battleground tracking!")
		currentBattleground = ArenaAnalyticsDB.currentMatch;
	end

	currentBattleground.battlefieldId = battlefieldId;

	-- Bail out if it ended by now
	if (status ~= "active" or not teamSize) then
		ArenaAnalytics:Log("HandleArenaEnter bailing out. Status:", status, "Team Size:", teamSize);
		return false;
	end

	-- Update start time immediately, might be overridden by gates open if it hasn't happened yet.
	if(not currentBattleground.hasRealStartTime) then
		currentBattleground.startTime = time();
	end

	if(not currentBattleground.battlefieldId) then
		ArenaAnalytics:Log("ERROR: Invalid Battlefield ID in HandleArenaEnter");
	end

	currentBattleground.playerName = Helpers:GetPlayerName();

	currentBattleground.bracket = bracket;
	currentBattleground.matchType = matchType;
	currentBattleground.size = teamSize;

	ArenaAnalytics:Log("TeamSize:", teamSize, currentBattleground.size, "Bracket:", currentBattleground.bracket);

	if(currentBattleground.matchType == "rated") then
		local oldRating, seasonPlayed = API:GetPersonalRatedInfo(currentBattleground.bracket);
		if(GetBattlefieldWinner()) then
			currentBattleground.seasonPlayed = seasonPlayed and seasonPlayed - 1; -- Season Played during the match
		else
			currentBattleground.oldRating = oldRating;
			currentBattleground.seasonPlayed = seasonPlayed;
		end
	end

	-- Add self
	if (not BattlegroundTracker:IsTrackingPlayer(currentBattleground.playerName)) then
		-- Add player
		local player = TablePool:Acquire();
		player.GUID = UnitGUID("player");
		player.name = currentBattleground.playerName;
		player.race = Helpers:GetUnitRace("player");
		local class_id = Helpers:GetUnitClass("player");
		local spec_id = API:GetSpecialization() or class_id;
		player.spec = spec_id or class_id;
		ArenaAnalytics:Log("Using MySpec:", spec_id);

		currentBattleground.players[player.name] = player;
	end

	if(ArenaAnalytics.DataSync) then
		ArenaAnalytics.DataSync:sendMatchGreetingMessage();
	end

	currentBattleground.mapId = API:GetCurrentMapID();
	ArenaAnalytics:Log("Match entered! Tracking map_id: ", currentBattleground.mapId);

	RequestBattlefieldScoreData();
end

function BattlegroundTracker:HandleStart()
	currentBattleground.startTime = time();
	currentBattleground.hasRealStartTime = true; -- The start time has been set by gates opened

	BattlegroundTracker:UpdatePlayers();

	ArenaAnalytics:Log("Match started!", currentBattleground.mapId, GetZoneText(), #currentBattleground.players);
	ArenaAnalytics:LogTemp("Battleground started - Team MMR:", API:GetTeamMMR(0), API:GetTeamMMR(1));
end

function BattlegroundTracker:HandleEnd()
	if(not BattlegroundTracker:IsTracking()) then
		return;
	end

	BattlegroundTracker:UpdatePlayers();

	if(currentBattleground.endedProperly) then
		return;
	end

	currentBattleground.endedProperly = true;
	currentBattleground.ended = true;
	currentBattleground.endTime = time();

	ArenaAnalytics:Log("HandleArenaEnd!", #currentBattleground.players);
	ArenaAnalytics:LogTemp("Battleground ended - Team MMR:", API:GetTeamMMR(0), API:GetTeamMMR(1), API:IsInArena());

	local winner = GetBattlefieldWinner();

	-- Figure out how to default to nil, without failing to count losses.
	local myTeamIndex = nil;
end

local function getMyTeamID()
	if(not currentBattleground.players or #currentBattleground.players == 0) then
		return nil;
	end

	for _,player in pairs(currentBattleground.players) do
		if(player and player.name == playerName) then
			local score = player.score;
			return score and score.team;
		end
	end

	return nil;
end

local function GetSpecFromPlayer(player, specKey)
	if(not player) then
		return nil;
	end

	specKey = specKey or "spec";

	if(specKey == "spec" and Helpers:IsSpecID(player[specKey]) or player[specKey]) then
		return player[specKey];
	end

	local score = player.score;
	if(not score or not score[specKey]) then
		return nil;
	end

	return score[specKey] or player[specKey] or nil;
end

function BattlegroundTracker:TestLastRaw()
	currentBattleground = Helpers:DeepCopy(ArenaAnalyticsBattlegroundsDB.lastSavedRaw) or {};
	BattlegroundTracker:HandleExit(true);
end

function BattlegroundTracker:HandleExit(isDebug)
	if(not BattlegroundTracker:IsTracking()) then
		return;
	end

	ArenaAnalytics:LogGreen("Battleground Exited!");

	if(not isDebug) then
		ArenaAnalyticsBattlegroundsDB.lastSavedRaw = currentBattleground;
	end

	currentBattleground.endTime = currentBattleground.endTime or time();

	if(currentBattleground.players) then
		currentBattleground.myTeam = getMyTeamID();

		local playerName = Helpers:GetPlayerName();
		local map_id = Internal:GetAddonMapID(currentBattleground.mapId);

		local players = TablePool:Acquire();
		for name,player in pairs(currentBattleground.players) do
			local newPlayer = Helpers:DeepCopy(player.score) or TablePool:Acquire();
			newPlayer.spec = GetSpecFromPlayer(player, "spec");
			newPlayer.heroSpec = GetSpecFromPlayer(player, "heroSpec");

			if(newPlayer.team) then
				newPlayer.isEnemy = (newPlayer.team ~= currentBattleground.myTeam);
			end

			tinsert(players, newPlayer);
		end

		currentBattleground.players = (#players > 0) and players;
	end

	BattlegroundTracker:SaveBattleground(currentBattleground);
	BattlegroundTracker:Clear();
end

function BattlegroundTracker:SaveBattleground(newBattleground)
	if(not newBattleground) then
		return;
	end

	local hasStartTime = tonumber(newBattleground.startTime) and newBattleground.startTime > 0;
	if(not hasStartTime) then
		-- At least get an estimate for the time of the match this way.
		newBattleground.startTime = time();
		ArenaAnalytics:Log("Warning: Start time overridden upon inserting arena.");
	end

	-- Calculate arena duration
	if(newBattleground.isShuffle) then
		newBattleground.duration = 0;

		if(newBattleground.committedRounds) then
			for _,round in ipairs(newBattleground.committedRounds) do
				if(round) then
					newBattleground.duration = newBattleground.duration + (tonumber(round.duration) or 0);
				end
			end
		end

		ArenaAnalytics:Log("Shuffle combined duration:", newBattleground.duration);
	else
		if (hasStartTime) then
			newBattleground.endTime = newBattleground.endTime or time();
			local duration = (newBattleground.endTime - newBattleground.startTime);
			duration = duration < 0 and 0 or duration;
			newBattleground.duration = duration;
		else
			ArenaAnalytics:Log("Force fixed start time at match end.");
			newBattleground.duration = 0;
		end
	end

	local season = GetCurrentArenaSeason();
	if (season == 0) then
		ArenaAnalytics:Log("Failed to get valid season for new match.");
	end

	Debug:LogTable(newBattleground);

	-- Setup table data to insert into ArenaAnalyticsDB
	local battlegroundData = {}
	BattlegroundMatch:SetDate(battlegroundData, newBattleground.startTime);
	BattlegroundMatch:SetDuration(battlegroundData, newBattleground.duration);
	BattlegroundMatch:SetMap(battlegroundData, newBattleground.mapId);

	ArenaAnalytics:Log("Bracket:", newBattleground.bracket);
	BattlegroundMatch:SetBracketIndex(battlegroundData, newBattleground.bracket);
	BattlegroundMatch:SetMatchType(battlegroundData, newBattleground.matchType);

	if (newBattleground.matchType == "rated") then
		BattlegroundMatch:SetPartyRating(battlegroundData, newBattleground.partyRating);
		BattlegroundMatch:SetPartyRatingDelta(battlegroundData, newBattleground.partyRatingDelta);
		BattlegroundMatch:SetPartyMMR(battlegroundData, newBattleground.partyMMR);

		BattlegroundMatch:SetEnemyRating(battlegroundData, newBattleground.enemyRating);
		BattlegroundMatch:SetEnemyRatingDelta(battlegroundData, newBattleground.enemyRatingDelta);
		BattlegroundMatch:SetEnemyMMR(battlegroundData, newBattleground.enemyMMR);
	end

	BattlegroundMatch:SetSeason(battlegroundData, season);

	BattlegroundMatch:SetMatchOutcome(battlegroundData, newBattleground.outcome);

	-- Add players from both teams sorted
	BattlegroundMatch:AddPlayers(battlegroundData, newBattleground.players);

	if(newBattleground.isShuffle) then
		BattlegroundMatch:SetRounds(battlegroundData, newBattleground.committedRounds);
	end

	-- Assign session
	Sessions:AssignSession(battlegroundData);
	ArenaAnalytics:Log("session:", session);

	if(newBattleground.requireRatingFix) then
		-- Transient data
		BattlegroundMatch:SetTransientSeasonPlayed(battlegroundData, newBattleground.seasonPlayed);
		BattlegroundMatch:SetRequireRatingFix(battlegroundData, newBattleground.requireRatingFix);
	end

	-- Clear transient season played from last match
	--ArenaAnalytics:ClearLastMatchTransientValues(newBattleground.bracket);

	-- Insert arena data as a new ArenaAnalyticsDB entry
	table.insert(ArenaAnalyticsBattlegroundsDB, battlegroundData);

	ArenaAnalytics.unsavedArenaCount = ArenaAnalytics.unsavedArenaCount + 1;

	if(Import.TryHide) then
		Import:TryHide();
	end

	ArenaAnalytics:PrintSystem("Battleground recorded!");

	Filters:Refresh();

	Sessions:TryStartSessionDurationTimer();
end