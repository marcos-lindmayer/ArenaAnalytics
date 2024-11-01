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
	currentBattleground.isRated = nil;
	currentBattleground.isShuffle = nil;

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

	-- Add to found specs and hero specs if not already there.
	if(not currentBattleground.knownSpecs[GUID] and spec_id) then
		currentBattleground.knownSpecs[GUID] = spec_id;
		hasNewSpec = true;
	end

	if(not currentBattleground.knownHeroSpecs[GUID] and hero_spec_id) then
		currentBattleground.knownHeroSpecs[GUID] = hero_spec_id;
		hasNewSpec = true;
	end

	-- Find and update player, if either spec were new.
	if(hasNewSpec) then
		local player = SharedTracker:GetPlayer(GUID);
		if(player) then
			player.spec = spec_id;
			player.heroSpec = hero_spec_id;
		end
	end
end

function BattlegroundTracker:IsTrackingPlayer(playerName)
	return playerName and currentBattleground.players and currentBattleground.players[playerName] ~= nil;
end

function BattlegroundTracker:UpdatePlayers()
	if(not BattlegroundTracker:IsTracking()) then
		return;
	end

	BattlegroundTracker:UpdateMyTeam();

	for i=1, GetNumBattlefieldScores() do
		local score = API:GetPlayerScore(i, true);
		if(score and score.name) then
			if(score.name == currentBattleground.playerName) then
				score.isSelf = true;
			end

			TablePool:Release(currentBattleground[score.name]);
			currentBattleground[score.name] = score;
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

	if(match.bracketIndex ~= bracket) then
		ArenaAnalytics:Log("IsTrackingCurrentBattleground: New bracket.");
		return false;
	end

	if(match.battlefieldId ~= battlefieldId) then
		ArenaAnalytics:Log("IsTrackingCurrentBattleground: New battlefield id.");
		return false;
	end

	if(match.isRated) then
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
		ArenaAnalytics:Log("HandleArenaEnter: Already tracking match");
		return;
	end

	Events:RegisterBattlegroundEvents();

	-- Retrieve current match info
	battlefieldId = API:GetActiveBattlefieldID();
	local status, bracket, teamSize, isRated, isShuffle = API:GetBattlefieldStatus(battlefieldId);

	if(not BattlegroundTracker:IsTrackingCurrentBattleground(battlefieldId, bracket)) then
		ArenaTracker:Reset();
	else
		ArenaAnalytics:Log("Keeping existing tracking!")
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

	currentBattleground.bracketIndex = bracket;
	currentBattleground.isRated = isRated;
	currentBattleground.isShuffle = isShuffle;
	currentBattleground.size = teamSize;

	ArenaAnalytics:Log("TeamSize:", teamSize, currentBattleground.size, "Bracket:", currentBattleground.bracketIndex);

	if(isRated) then
		local oldRating, seasonPlayed = API:GetPersonalRatedInfo(currentBattleground.bracketIndex);
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
		local GUID = UnitGUID("player");
		local name = currentBattleground.playerName;
		local race_id = Helpers:GetUnitRace("player");
		local class_id = Helpers:GetUnitClass("player");
		local spec_id = API:GetSpecialization() or class_id;
		ArenaAnalytics:Log("Using MySpec:", spec_id);

		local player = ArenaTracker:CreatePlayerTable(false, GUID, name, race_id, spec_id);
		table.insert(currentBattleground.players, player);
	end

	if(ArenaAnalytics.DataSync) then
		ArenaAnalytics.DataSync:sendMatchGreetingMessage();
	end

	currentBattleground.mapId = API:GetCurrentMapID();
	ArenaAnalytics:Log("Match entered! Tracking mapId: ", currentBattleground.mapId);

	ArenaTracker:CheckRoundEnded();

	RequestBattlefieldScoreData();
end

function BattlegroundTracker:HandleStart()
	currentBattleground.startTime = time();
	currentBattleground.hasRealStartTime = true; -- The start time has been set by gates opened

	BattlegroundTracker:UpdatePlayers();

	ArenaAnalytics:Log("Match started!", API:GetCurrentMapID(), GetZoneText(), #currentBattleground.players);
	ArenaAnalytics:LogTemp("Arena started - Team MMR:", API:GetTeamMMR(0), API:GetTeamMMR(1));
end

function BattlegroundTracker:HandleEnd()
	BattlegroundTracker:UpdatePlayers();


end

function BattlegroundTracker:HandleExit()

end