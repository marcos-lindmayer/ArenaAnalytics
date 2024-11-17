local _, ArenaAnalytics = ... -- Namespace
local ArenaTracker = ArenaAnalytics.ArenaTracker;

-- Local module aliases
local SharedTracker = ArenaAnalytics.SharedTracker;
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
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local Sessions = ArenaAnalytics.Sessions;
local Import = ArenaAnalytics.Import;
local Filters = ArenaAnalytics.Filters;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------

-- Arena variables
local currentArena = {}

function ArenaTracker:GetCurrentArena()
	return currentArena;
end

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
	currentArena.matchType = nil;
	currentArena.isShuffle = nil;

	currentArena.players = TablePool:Acquire();

	currentArena.ended = false;
	currentArena.endedProperly = false;
	currentArena.outcome = nil;

	currentArena.round = TablePool:Acquire();
	currentArena.committedRounds = TablePool:Acquire();

	currentArena.deathData = TablePool:Acquire();

	-- Current Round
	currentArena.round.hasStarted = nil;
	currentArena.round.startTime = nil;
	currentArena.round.team = TablePool:Acquire();

	ArenaAnalyticsDB.currentMatch = currentArena;
end

function ArenaTracker:Clear()
	ArenaAnalytics:Log("Clearing current arena.");

	ArenaAnalyticsDB.currentMatch = nil;
	currentArena = {};
end

-------------------------------------------------------------------------

function ArenaTracker:IsTracking()
	return currentArena.mapId ~= nil;
end

function ArenaTracker:IsTrackingCurrentArena(battlefieldId, bracket)
	if(not API:IsInArena()) then
		ArenaAnalytics:Log("IsTrackingCurrentArena: Not in arena.")
		return false;
	end
	
	local arena = ArenaAnalyticsDB.currentMatch;
	if(not arena) then
		ArenaAnalytics:Log("IsTrackingCurrentArena: No existing arena.", arena, ArenaAnalyticsDB.currentMatch);
		return false;
	end

	if(arena.bracketIndex ~= bracket) then
		ArenaAnalytics:Log("IsTrackingCurrentArena: New bracket.");
		return false;
	end

	if(arena.battlefieldId ~= battlefieldId) then
		ArenaAnalytics:Log("IsTrackingCurrentArena: New battlefield id.");
		return false;
	end

	if(arena.matchType == "rated") then
		if(not arena.seasonPlayed) then
			ArenaAnalytics:Log("IsTrackingCurrentArena: Existing rated arena has no season played.", arena.seasonPlayed)
			return false;
		end

		local _, seasonPlayed = API:GetPersonalRatedInfo(bracket);
		local trackedSeasonPlayed = arena.seasonPlayed - (arena.endedProperly and 1 or 0);
		if(not seasonPlayed or seasonPlayed ~= trackedSeasonPlayed) then
			ArenaAnalytics:Log("IsTrackingCurrentArena: Invalid season played, or mismatch to tracked value.", seasonPlayed, arena.seasonPlayed)
			return false;
		end
	end

	ArenaAnalytics:Log("IsTrackingCurrentArena: Arena alrady tracked")
	return true;
end

-- Begins capturing data for the current arena
-- Gets arena player, size, map, ranked/skirmish
function ArenaTracker:HandleArenaEnter(battlefieldId)
	if(ArenaTracker:IsTracking()) then
		ArenaAnalytics:Log("HandleArenaEnter: Already tracking arena");
		return;
	end

	-- Retrieve current arena info
	battlefieldId = battlefieldId or API:GetActiveBattlefieldID();
	if(not battlefieldId) then
		return;
	end

	Events:RegisterArenaEvents();

	local status, bracket, matchType, teamSize, isShuffle = API:GetBattlefieldStatus(battlefieldId);

	if(not ArenaTracker:IsTrackingCurrentArena(battlefieldId, bracket)) then
		ArenaTracker:Reset();
	else
		ArenaAnalytics:Log("Keeping existing tracking!");
		currentArena = ArenaAnalyticsDB.currentMatch;
	end

	currentArena.battlefieldId = battlefieldId;

	-- Bail out if it ended by now
	if (status ~= "active" or not teamSize) then
		ArenaAnalytics:Log("HandleArenaEnter bailing out. Status:", status, "Team Size:", teamSize);
		return false;
	end

	-- Update start time immediately, might be overridden by gates open if it hasn't happened yet.
	if(not currentArena.hasRealStartTime) then
		currentArena.startTime = time();
	end

	if(not currentArena.battlefieldId) then
		ArenaAnalytics:Log("ERROR: Invalid Battlefield ID in HandleArenaEnter");
	end

	currentArena.playerName = Helpers:GetPlayerName();

	currentArena.bracketIndex = bracket;
	currentArena.matchType = matchType;
	currentArena.isShuffle = isShuffle;
	currentArena.size = teamSize;

	ArenaAnalytics:Log("TeamSize:", teamSize, currentArena.size, "Bracket:", currentArena.bracketIndex);

	if(matchType == "rated") then
		local oldRating, seasonPlayed = API:GetPersonalRatedInfo(currentArena.bracketIndex);
		if(GetBattlefieldWinner()) then
			currentArena.seasonPlayed = seasonPlayed and seasonPlayed - 1; -- Season Played during the match
		else
			currentArena.oldRating = oldRating;
			currentArena.seasonPlayed = seasonPlayed;
		end
	end

	-- Add self
	if (not SharedTracker:IsTrackingPlayer(currentArena.playerName)) then
		-- Add player
		local GUID = UnitGUID("player");
		local name = currentArena.playerName;
		local race_id = Helpers:GetUnitRace("player");
		local class_id = Helpers:GetUnitClass("player");
		local spec_id = API:GetSpecialization() or class_id;
		ArenaAnalytics:Log("Using MySpec:", spec_id);

		local player = ArenaTracker:CreatePlayerTable(false, GUID, name, race_id, spec_id);
		table.insert(currentArena.players, player);
	end

	if(ArenaAnalytics.DataSync) then
		ArenaAnalytics.DataSync:sendMatchGreetingMessage();
	end

	currentArena.mapId = API:GetCurrentMapID();
	ArenaAnalytics:Log("Match entered! Tracking mapId: ", currentArena.mapId);

	ArenaTracker:CheckRoundEnded();

	RequestBattlefieldScoreData();
end

-- Gates opened, match has officially started
function ArenaTracker:HandleArenaStart(...)
	currentArena.startTime = time();
	currentArena.hasRealStartTime = true; -- The start time has been set by gates opened

	local myWins, totalWins = ArenaTracker:GetCurrentWins();
	currentArena.round.wins = myWins;
	currentArena.round.totalWins = totalWins;
	ArenaAnalytics:LogGreen("Assigned round wins:", myWins, totalWins);

	ArenaTracker:FillMissingPlayers();
	ArenaTracker:HandleOpponentUpdate();
	ArenaTracker:UpdateRoundTeam();

	currentArena.round.startTime = time();
	currentArena.round.hasStarted = true;

	ArenaAnalytics:Log("Match started!", API:GetCurrentMapID(), GetZoneText(), #currentArena.players);
	ArenaAnalytics:LogTemp("Arena started - Team MMR:", API:GetTeamMMR(0), API:GetTeamMMR(1));
end

function ArenaTracker:ProcessDeaths()
	local firstDeath = ArenaTracker:GetFirstDeathFromCurrentArena();
	ArenaTracker:CommitDeaths();
	wipe(currentArena.deathData);
	return firstDeath;
end

-- Gets arena information when it ends and the scoreboard is shown
-- Matches obtained info with previously collected player values
function ArenaTracker:HandleArenaEnd()
	if(not ArenaTracker:IsTracking()) then
		return;
	end

	if(currentArena.endedProperly) then
		return;
	end

	currentArena.endedProperly = true;
	currentArena.ended = true;
	currentArena.endTime = time();

	ArenaAnalytics:Log("HandleArenaEnd!", #currentArena.players);
	ArenaAnalytics:LogTemp("Arena ended - Team MMR:", API:GetTeamMMR(0), API:GetTeamMMR(1), API:IsInArena());

	-- Solo Shuffle
	ArenaTracker:HandleRoundEnd(true);
	local firstDeath = ArenaTracker:ProcessDeaths();

	local winner = GetBattlefieldWinner();
	--local players = {};

	-- Figure out how to default to nil, without failing to count losses.
	local myTeamIndex = nil;

	for i=1, GetNumBattlefieldScores() do
		local score = API:GetPlayerScore(i, currentArena.isShuffle);

		-- Find or add player
		local player = SharedTracker:GetPlayer(score.name);
		if(not player) then
			-- Use scoreboard info
			ArenaAnalytics:Log("Creating new player by scoreboard:", score.name);
			player = ArenaTracker:CreatePlayerTable(nil, nil, score.name);
			tinsert(currentArena.players, player);
		end

		-- Fill missing data
		player.teamIndex = score.team;
		player.spec = Helpers:IsSpecID(player.spec) and player.spec or score.spec;
		player.race = player.race or score.race;
		player.kills = score.kills;
		player.deaths = API.trustScoreboardDeaths and score.deaths or player.deaths or 0;
		player.damage = score.damage;
		player.healing = score.healing;

		if(currentArena.matchType == "rated") then
			player.rating = score.rating;
			player.ratingDelta = score.ratingDelta;
			player.mmr = score.mmr;
			player.mmrDelta = score.mmrDelta;
		end

		if(currentArena.isShuffle) then
			player.wins = score.wins or 0;
		end

		if(player.name) then
			-- First Death
			if(not currentArena.isShuffle and player.name == firstDeath) then
				player.isFirstDeath = true;
			end

			if (player.name == currentArena.playerName) then
				myTeamIndex = player.teamIndex;
				player.isSelf = true;
			elseif(currentArena.isShuffle) then
				player.isEnemy = true;
			end

			-- Insert player
			--tinsert(players, player);
		else
			ArenaAnalytics:Log("Tracker: Invalid player name at index:", i);
		end

		TablePool:Release(score);
	end

	--currentArena.players = players;

	if(currentArena.isShuffle) then
		-- Determine match outcome
		currentArena.outcome = ArenaTracker:GetShuffleOutcome();
	else
		-- Assign isEnemy value
		for _,player in ipairs(currentArena.players) do
			if(player and player.teamIndex) then
				player.isEnemy = (player.teamIndex ~= myTeamIndex);
			end
		end

		-- Assign Winner
		if(winner == 255) then
			currentArena.outcome = 2;
		elseif(winner ~= nil) then
			currentArena.outcome = (myTeamIndex == winner) and 1 or 0;
		end
	end

	-- Process ranked information
	if (currentArena.matchType == "rated") then
		if(myTeamIndex) then
			local otherTeamIndex = (myTeamIndex == 0) and 1 or 0;

			currentArena.partyMMR = API:GetTeamMMR(myTeamIndex);
			currentArena.enemyMMR = API:GetTeamMMR(otherTeamIndex);
		else
			ArenaAnalytics:LogWarning("Failed to retrieve MMR.");
		end
	end

	ArenaAnalytics:Log("Match ended!", #currentArena.players, "players tracked.");
end

-- Player left an arena (Zone changed to non-arena with valid arena data)
function ArenaTracker:HandleArenaExit()
	if(not currentArena.size or not currentArena.mapId) then
		return;
	end

	if(Inspection and Inspection.CancelTimer) then
		Inspection:CancelTimer();
	end

	-- Solo Shuffle
	ArenaTracker:HandleRoundEnd(true);
	local firstDeath = ArenaTracker:ProcessDeaths();
	if(firstDeath and not currentArena.isShuffle) then
		-- Assign first death
		for _,player  in iparis(currentArena.players) do
			if(player and player.name == firstDeath) then
				player.isFirstDeath = true;
			end
		end
	end

	currentArena.endTime = currentArena.endTime or time();

	if(not currentArena.endedProperly) then
		currentArena.ended = true;
		currentArena.outcome = false;
		
		ArenaAnalytics:Log("Detected early leave. Has valid current arena: ", currentArena.mapId);
	end

	ArenaAnalytics:Log("Exited Arena:", API:GetPersonalRatedInfo(currentArena.bracketIndex));
	ArenaAnalytics:LogTemp("Arena exited - Team MMR:", API:GetTeamMMR(0), API:GetTeamMMR(1));

	if(currentArena.matchType == "rated" and not currentArena.partyRating) then
		local newRating, seasonPlayed = API:GetPersonalRatedInfo(currentArena.bracketIndex);
		if(newRating and seasonPlayed) then
			local oldRating = currentArena.oldRating;
			if(not oldRating) then
				local season = GetCurrentArenaSeason();
				oldRating = ArenaAnalytics:GetLatestRating(currentArena.bracketIndex, season, (seasonPlayed - 1));
			end

			currentArena.partyRating = newRating;
			currentArena.partyRatingDelta = oldRating and newRating - oldRating or nil;
		else
			ArenaAnalytics:Log("Warning: Nil current rating retrieved from API upon leaving arena.");
		end

		if(currentArena.seasonPlayed) then
			if(seasonPlayed and seasonPlayed < (currentArena.seasonPlayed + 1)) then
				-- Rating has updated, no longer needed to store transient Season Played for fixup.
				currentArena.requireRatingFix = true;
			else
				ArenaAnalytics:Log("Tracker: Invalid or up to date seasonPlayed.", seasonPlayed, currentArena.seasonPlayed);
			end
		else
			ArenaAnalytics:Log("Tracker: No season played stored on currentArena");
		end
	end

	ArenaTracker:SaveArena(currentArena);
	ArenaTracker:Clear();
end

-- Search for missing members of group (party or arena), 
-- Adds each non-tracked player to currentArena.players table.
-- If spec and GUID are passed, include them when creating the player table
function ArenaTracker:FillMissingPlayers(unitGUID, knownSpec, knownHeroSpec)
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
			local player = SharedTracker:GetPlayer(name);
			if(name and not player) then
				local GUID = UnitGUID(unitToken);
				local isEnemy = (group == "arena");
				local race_id = Helpers:GetUnitRace(unitToken);
				local class_id = Helpers:GetUnitClass(unitToken);

				if(GUID and name) then
					player = ArenaTracker:CreatePlayerTable(isEnemy, GUID, name, race_id, class_id);
					table.insert(currentArena.players, player);

					if(GUID == UnitGUID) then
						player.spec = tonumber(knownSpec) or player.spec;
						player.heroSpec = tonumber(knownHeroSpec) or player.heroSpec;
					end

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

function ArenaTracker:AssignSpec(playerID, spec_id, hero_spec_id)
	local player = SharedTracker:GetPlayer(playerID);
	if(not player or Helpers:IsSpecID(player.spec)) then
		return;
	end

	-- Specialization
	if(not Helpers:IsSpecID(player.spec) or player.spec == 13) then -- Preg doesn't count as a known spec
		ArenaAnalytics:Log("Assigning spec: ", spec_id, " for player: ", player.name);
		player.spec = spec_id;
	elseif(player.spec) then
		ArenaAnalytics:Log("Tracker: Keeping old spec:", player.spec, " for player: ", player.name);
	end

	-- Hero Spec
	if(hero_spec_id and hero_spec_id ~= player.heroSpec) then
		if(not player.heroSpec or SharedTracker:IsSameRoundTeam()) then
			ArenaAnalytics:Log("Assigning hero spec:", hero_spec_id, " for player:", player.name, "Old hero spec:", player.heroSpec);
			player.heroSpec = hero_spec_id;
		end
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

-- Called from unit actions, to remove false deaths
function ArenaTracker:TryRemoveFromDeaths(playerGUID, spell)
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

-- Handle a player's death, through death or kill credit message
function ArenaTracker:HandlePlayerDeath(playerGUID, isKillCredit)
	if(playerGUID == nil) then
		return;
	end

	currentArena.deathData[playerGUID] = currentArena.deathData[playerGUID] or TablePool:Acquire();

	local class, race, name, realm = API:GetPlayerInfoByGUID(playerGUID);
	if(not realm or realm == "") then
		name = Helpers:ToFullName(name);
	else
		name = name .. "-" .. realm;
	end

	ArenaAnalytics:Log("Player Kill!", isKillCredit, name);

	-- Store death
	currentArena.deathData[playerGUID] = {
		time = time(), 
		name = name,
		isHunter = (class == "HUNTER") or nil,
		hasKillCredit = isKillCredit or currentArena.deathData[playerGUID].hasKillCredit,
	};

	if(currentArena.isShuffle and (isKillCredit or class ~= "HUNTER")) then
		C_Timer.After(0, ArenaTracker.HandleRoundEnd);
	end
end

-- Commits current deaths to player stats (May be overridden by scoreboard, if value is trusted for the expansion)
function ArenaTracker:CommitDeaths()
	for GUID,data in pairs(currentArena.deathData) do
		local player = SharedTracker:GetPlayer(GUID);
		if(player and data) then
			-- Increment deaths
			player.deaths = (player.deaths or 0) + 1;
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

	local firstDeathData = currentArena.deathData[bestKey];
	return firstDeathData.name, firstDeathData.time;
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
			local player = SharedTracker:GetPlayer(unitToken);
			if(player) then
				if(not Helpers:IsSpecID(player.spec)) then
					local spec_id = API:GetArenaPlayerSpec(i, true);
					SharedTracker:OnSpecDetected(unitToken, spec_id);
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
		local unit = "party"..i;
		local player = SharedTracker:GetPlayer(UnitGUID(unit));
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

-------------------------------------------------------------------------

-- Finalize and store the new arena, triggering updates as needed.
function ArenaTracker:SaveArena(newArena)
	local hasStartTime = tonumber(newArena.startTime) and newArena.startTime > 0;
	if(not hasStartTime) then
		-- At least get an estimate for the time of the match this way.
		newArena.startTime = time();
		ArenaAnalytics:Log("Warning: Start time overridden upon inserting arena.");
	end

	-- Calculate arena duration
	if(newArena.isShuffle) then
		newArena.duration = 0;

		if(newArena.committedRounds) then
			for _,round in ipairs(newArena.committedRounds) do
				if(round) then
					newArena.duration = newArena.duration + (tonumber(round.duration) or 0);
				end
			end
		end

		ArenaAnalytics:Log("Shuffle combined duration:", newArena.duration);
	else
		if (hasStartTime) then
			newArena.endTime = newArena.endTime or time();
			local duration = (newArena.endTime - newArena.startTime);
			duration = duration < 0 and 0 or duration;
			newArena.duration = duration;
		else
			ArenaAnalytics:Log("Force fixed start time at match end.");
			newArena.duration = 0;
		end
	end

	local season = GetCurrentArenaSeason();
	if (season == 0) then
		ArenaAnalytics:Log("Failed to get valid season for new match.");
	end

	-- Setup table data to insert into ArenaAnalyticsDB
	local arenaData = { }
	ArenaMatch:SetDate(arenaData, newArena.startTime);
	ArenaMatch:SetDuration(arenaData, newArena.duration);
	ArenaMatch:SetMap(arenaData, newArena.mapId);

	ArenaAnalytics:Log("Bracket:", newArena.bracketIndex);
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

	ArenaMatch:SetMatchOutcome(arenaData, newArena.outcome);

	-- Add players from both teams sorted, and assign comps.
	ArenaMatch:AddPlayers(arenaData, newArena.players);

	if(newArena.isShuffle) then
		ArenaMatch:SetRounds(arenaData, newArena.committedRounds);
	end

	-- Assign session
	Sessions:AssignSession(arenaData);
	ArenaAnalytics:Log("session:", session);

	if(newArena.requireRatingFix) then
		-- Transient data
		ArenaMatch:SetTransientSeasonPlayed(arenaData, newArena.seasonPlayed);
		ArenaMatch:SetRequireRatingFix(arenaData, newArena.requireRatingFix);
	end

	-- Clear transient season played from last match
	ArenaAnalytics:ClearLastMatchTransientValues(newArena.bracketIndex);

	-- Insert arena data as a new ArenaAnalyticsDB entry
	table.insert(ArenaAnalyticsDB, arenaData);

	ArenaAnalytics.unsavedArenaCount = ArenaAnalytics.unsavedArenaCount + 1;

	if(Import.TryHide) then
		Import:TryHide();
	end

	ArenaAnalytics:PrintSystem("Arena recorded!");

	Filters:Refresh();

	Sessions:TryStartSessionDurationTimer();
end