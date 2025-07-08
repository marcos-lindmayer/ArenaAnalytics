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

ArenaAnalytics:InitializeTransientDB();
local currentArena = ArenaAnalyticsTransientDB.currentArena;

-- Arena variables
local hasReceivedScore = false;
local isActiveTracking = false;

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
	ArenaAnalytics:InitializeTransientDB();
	currentArena = ArenaAnalyticsTransientDB.currentArena;

	-- Transient values (Reset by reload)
	hasReceivedScore = false;
	isActiveTracking = false;

	-- Current Arena
	currentArena.isTracking = nil;

	currentArena.winner = nil; -- Raw winner team ID (2 = draw)

	currentArena.battlefieldId = nil;
	currentArena.mapId = nil;

	currentArena.playerName = nil;

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

	currentArena.hasHandledEnter = nil;
end

function ArenaTracker:Clear()
	Debug:Log("Clearing current arena.");

	ArenaTracker:Reset();

	hasReceivedScore = false;
	isActiveTracking = false;
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

    local _, seasonPlayed = API:GetPersonalRatedInfo(bracketIndex);
	if(type(seasonPlayed) ~= "number") then
		return nil;
	end

    if(not API:GetWinner() and not currentArena.winner) then
        seasonPlayed = seasonPlayed + 1;
    end

    return seasonPlayed;
end

-------------------------------------------------------------------------
-- Solo Shuffle

-- Get current player wins and all players summed wins
function ArenaTracker:GetCurrentWins()
	if(not ArenaTracker:IsTrackingShuffle()) then
		return;
	end

	local myWins, totalWins = 0,0;
	for i=1, GetNumBattlefieldScores() do
		local score = API:GetPlayerScore(i);
		if(score and score.wins) then
			if(currentArena.playerName and score.name == currentArena.playerName) then
				myWins = score.wins;
			end

			totalWins = totalWins + score.wins;
		end
	end

	return myWins, totalWins;
end

function ArenaTracker:UpdateRoundTeam()
	if(not ArenaTracker:IsTrackingShuffle()) then
		return;
	end

	if(ArenaTracker:IsSameRoundTeam()) then
		Debug:Log("Still same team, round team update delayed.");
		return;
	end

	wipe(currentArena.round.team)
	currentArena.round.team = TablePool:Acquire();
	for i=1, 2 do
		local name = Helpers:GetUnitFullName("party"..i);
		if(name) then
			tinsert(currentArena.round.team, name);
			Debug:Log("Adding team player:", name, #currentArena.round.team);
		end
	end

	Debug:Log("UpdateRoundTeam", #currentArena.round.team);
end

function ArenaTracker:RoundTeamContainsPlayer(playerName)
	if(not ArenaTracker:IsTrackingShuffle()) then
		return;
	end

	if(not playerName) then
		return nil;
	end

	for _,teamMember in ipairs(currentArena.round.team) do
		if(teamMember == playerName) then
			return true;
		end
	end

	return playerName == Helpers:GetPlayerName();
end

function ArenaTracker:IsSameRoundTeam()
	if(not ArenaTracker:IsTrackingShuffle()) then
		return nil;
	end

	for i=1, 2 do
		local unitName = Helpers:GetUnitFullName("party"..i);

		if(unitName and not ArenaTracker:RoundTeamContainsPlayer(unitName)) then
			return false;
		end
	end

	return true;
end

function ArenaTracker:CommitCurrentRound(force)
	if(not ArenaTracker:IsTrackingShuffle()) then
		return;
	end

	if(not currentArena.round.hasStarted) then
		return;
	end

	-- Delay commit until team has changed, unless match ended.
	if(not force and ArenaTracker:IsSameRoundTeam() and not API:GetWinner()) then
		Debug:LogGreen("Delaying round commit. Team has not yet changed.");
		return;
	end

	Debug:LogGreen("CommitCurrentRound triggered!")

	local startTime = currentArena.round.startTime;
	local death, endTime = ArenaTracker:GetFirstDeathFromCurrentArena();
	endTime = endTime or time();

	-- Get death stats, then wipe the deaths to avoid double counting
	ArenaTracker:CommitDeaths();
	wipe(currentArena.deathData);

	local roundData = {
		duration = startTime and (endTime - startTime) or nil,
		firstDeath = death,
		team = {},
		enemy = {},
	};

	-- Get the total wins after current round
	local myWins, totalWins = ArenaTracker:GetCurrentWins();
	if(myWins == currentArena.round.wins and totalWins == currentArena.round.totalWins) then
		Debug:LogGreen("Neither wins changed since last round. Assuming draw.");
		roundData.outcome = 2;
	else
		local isWin = (myWins > currentArena.round.wins);
		roundData.outcome = isWin and 1 or 0;
		Debug:LogGreen("Outcome determined:", roundData.outcome, "New wins:", myWins, totalWins, "Old wins:", currentArena.round.wins, currentArena.round.totalWins, "Rounds played:", #currentArena.committedRounds);
	end

	-- Fill round teams
	for _,player in ipairs(currentArena.players) do
		if(player and player.name) then
			local team = ArenaTracker:RoundTeamContainsPlayer(player.name) and roundData.team or roundData.enemy;
			tinsert(team, player.name);
		end
	end

	Debug:LogGreen("Committed round:!", roundData.duration, roundData.firstDeath, #roundData.team, #roundData.enemy, #currentArena.players);
	tinsert(currentArena.committedRounds, roundData);

	-- Reset currentArena round data
	currentArena.deathData = TablePool:Acquire();

	-- Reset current round
	currentArena.round.team = {};
	currentArena.round.startTime = nil;
	currentArena.round.hasStarted = false;

	currentArena.round.wins = myWins;
	currentArena.round.totalWins = totalWins;

	-- Make sure we update the team, if we're not done playing.
	if(not API:GetWinner()) then
		Debug:LogGreen("Round commit forcing team update!");
		ArenaTracker:UpdateRoundTeam();
	end
end

-------------------------------------------------------------------------

-- Is tracking player, supports GUID, name and unitToken
function ArenaTracker:IsTrackingPlayer(playerID)
	return (ArenaTracker:GetPlayer(playerID) ~= nil);
end

function ArenaTracker:IsTrackingArena()
	return currentArena.mapId ~= nil;
end

function ArenaTracker:IsTrackingShuffle()
	return ArenaTracker:IsTrackingArena() and ArenaTracker:IsShuffle();
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

function ArenaTracker:GetShuffleOutcome()
	if(currentArena.committedRounds) then
		local roundWins = 0;

        -- Iterate through all the rounds
        for _, round in ipairs(currentArena.committedRounds) do
            -- Check if firstDeath exists
            if(round.firstDeath) then
                for _, enemyPlayer in ipairs(round.enemy) do
                    if enemyPlayer == round.firstDeath then
                        roundWins = roundWins + 1;
						break;
                    end
                end
            end
        end

        if(roundWins == 3) then
			-- Draw
			return 2; 
		else
			return roundWins > 3 and 1 or 0;
		end
	end

	return nil;
end

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

function ArenaTracker:HandleArenaMessages(msg)
	if(not msg or not ArenaTracker:IsTrackingArena()) then
		return;
	end

	local isStart, timeTillStart = Constants:CheckTimerMessage(msg);

	if(not timeTillStart) then
		Debug:LogWarning("HandleArenaMessages missing:", msg);
		return;
	else
		Debug:LogGreen("HandleArenaMessages:", msg);
	end

	if(not currentArena.hasRealStartTime) then
		local newTime = (time() + timeTillStart);

		if(currentArena.startTime) then
			Debug:LogGreen("Start Time changed by broadcast message:", currentArena.startTime, newTime, newTime - time());
		end

		currentArena.startTime = newTime;
	end

	-- Trigger Start handling logic
	if(isStart == 0) then
		ArenaTracker:HandleArenaStart(msg);
	end
end

function ArenaTracker:HandleRatedUpdate()
	if(not API:IsInArena() or not ArenaTracker:IsTrackingArena()) then
		return;
	end

	if(currentArena.bracketIndex == nil) then
		return;
	end

	-- Get the season played including current match
	local postMatchSeasonPlayed = ArenaTracker:GetSeasonPlayed(currentArena.bracketIndex);
	if(not postMatchSeasonPlayed) then
		return;
	end

	-- Get the current and last rating relative to post match season played
	local rating, lastRating = ArenaRatedInfo:GetRatedInfo(currentArena.bracketIndex, postMatchSeasonPlayed);
	if(not rating and not lastRating) then
		return;
	end

	currentArena.rating = currentArena.rating or rating; -- Assumed nil during the arena
	currentArena.oldRating = lastRating;
end

function ArenaTracker:HandleScoreUpdate()
	hasReceivedScore = true;
	currentArena.winner = API:GetWinner() or currentArena.winner;
	currentArena.seasonPlayed = ArenaTracker:GetSeasonPlayed();
end

function ArenaTracker:HasReliableOutcome()
	if(currentArena.winner ~= nil) then
		return true;
	end

	local winner = API:GetWinner();
	if(winner ~= nil) then
		return true;
	end

	-- Assume we'll stay up to date after receiving the score since last reload
	if(hasReceivedScore) then
		return true;
	end

	return false;
end

-- Begins capturing data for the current arena
-- Gets arena player, size, map, ranked/skirmish
function ArenaTracker:HandleArenaEnter()
	if(isActiveTracking and ArenaTracker:IsTrackingArena()) then
		Debug:LogGreen("HandleArenaEnter: Already tracking arena!");
		return;
	end

	isActiveTracking = true;

	Debug:LogTemp("HandleArenaEnter");

	-- Retrieve current arena info
	local battlefieldId = currentArena.battlefieldId or API:GetActiveBattlefieldID();
	if(not battlefieldId) then
		return;
	end

	local status, bracket, teamSize, matchType = API:GetBattlefieldStatus(battlefieldId);
	local bracketIndex = ArenaAnalytics:GetAddonBracketIndex(bracket);

	ArenaTracker:HandleScoreUpdate();

	if(not ArenaTracker:IsTrackingCurrentArena(battlefieldId, bracketIndex)) then
		Debug:Log("HandleArenaEnter resetting currentArena");
		ArenaTracker:Reset();
	else
		Debug:LogGreen("Keeping existing tracking!", currentArena.oldRating, currentArena.startTime, currentArena.hasRealStartTime, time());
	end

	currentArena.isTracking = true;
	currentArena.battlefieldId = battlefieldId;

	-- Bail out if it ended by now
	if (status ~= "active" or not teamSize) then
		Debug:Log("HandleArenaEnter bailing out. Status:", status, "Team Size:", teamSize);
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
		currentArena.seasonPlayed = ArenaTracker:GetSeasonPlayed(); -- Season Played during the match
		local rating, lastRating = ArenaRatedInfo:GetRatedInfo(bracketIndex, currentArena.seasonPlayed);

		Debug:LogTemp("Active arena season played:", currentArena.seasonPlayed);

		if(not API:GetWinner()) then
			currentArena.oldRating = lastRating;
			Debug:LogTemp("Setting old rating and seasonPlayed on arena enter:", currentArena.oldRating, currentArena.seasonPlayed);
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
	Debug:Log("Match entered! Tracking mapId: ", currentArena.mapId);

	ArenaTracker:ForceTeamsUpdate();

	currentArena.hasHandledEnter = true;

	Events:RegisterArenaEvents();

	RequestRatedInfo();
	RequestBattlefieldScoreData();
end

-- Gates opened, match has officially started
function ArenaTracker:HandleArenaStart(...)
	currentArena.startTime = time();
	currentArena.hasRealStartTime = true; -- The start time has been set by gates opened

	local myWins, totalWins = ArenaTracker:GetCurrentWins();
	currentArena.round.wins = myWins;
	currentArena.round.totalWins = totalWins;
	Debug:LogGreen("Assigned round wins:", myWins, totalWins);

	ArenaTracker:FillMissingPlayers();
	ArenaTracker:ForceTeamsUpdate();
	ArenaTracker:UpdateRoundTeam();

	currentArena.round.startTime = time();
	currentArena.round.hasStarted = true;

	Debug:LogGreen("Match started!", API:GetCurrentMapID(), GetZoneText(), #currentArena.players);
end

function ArenaTracker:CheckRoundEnded()
	if(not API:IsInArena() or not ArenaTracker:IsTrackingShuffle()) then
		return;
	end

	if(not ArenaTracker:IsTrackingArena() or not currentArena.round.hasStarted) then
		Debug:Log("CheckRoundEnded called while not tracking arena, or without active shuffle round.", currentArena.round.hasStarted);
		return;
	end

	-- Check if this is a new round
	if(#currentArena.round.team ~= 2) then
		Debug:Log("CheckRoundEnded missing players.");
		return;
	end

	-- Team remains same, thus round has not changed.
	if(ArenaTracker:IsSameRoundTeam()) then
		Debug:Log("CheckRoundEnded has same team.");
		return;
	end

	Debug:Log("CheckRoundEnded");
	ArenaTracker:HandleRoundEnd();
end

-- Solo Shuffle specific round end
function ArenaTracker:HandleRoundEnd(force)
	if(not API:IsInArena() or not ArenaTracker:IsTrackingShuffle()) then
		return;
	end

	Debug:Log("HandleRoundEnd!", #currentArena.players);

	ArenaTracker:CommitCurrentRound(force);
end

-- Gets arena information when it ends and the scoreboard is shown
-- Matches obtained info with previously collected player values
function ArenaTracker:HandleArenaEnd()
	if(not ArenaTracker:IsTrackingArena()) then
		Debug:LogWarning("ArenaTracker:HandleArenaEnd skipped: Not tracking arena.");
		return;
	end

	if(not currentArena.hasHandledEnter) then
		-- Not ready to end before start
		--return;
	end

	currentArena.endedProperly = true;
	currentArena.ended = true;
	currentArena.endTime = tonumber(currentArena.endTime) or time();

	Debug:Log("HandleArenaEnd!", #currentArena.players, currentArena.startTime, currentArena.endTime);

	-- Solo Shuffle
	ArenaTracker:HandleRoundEnd(true);

	local winner = API:GetWinner();
	local players = {};

	-- Figure out how to default to nil, without failing to count losses.
	local myTeamIndex = nil;

	local firstDeath = ArenaTracker:GetFirstDeathFromCurrentArena();
	ArenaTracker:CommitDeaths();
	wipe(currentArena.deathData);

	local isShuffle = ArenaTracker:IsShuffle();

	for i=1, GetNumBattlefieldScores() do
		local score = API:GetPlayerScore(i) or {};

		-- Find or add player
		local player = ArenaTracker:GetPlayer(score.name);
		if(not player) then
			-- Use scoreboard info
			Debug:Log("Creating new player by scoreboard:", score.name);
			player = ArenaTracker:CreatePlayerTable(nil, nil, score.name);
		end

		-- Fill missing data
		player.teamIndex = score.team;
		player.spec = Helpers:IsSpecID(player.spec) and player.spec or score.spec;
		player.race = player.race or score.race;
		player.kills = score.kills;
		player.deaths = API.trustScoreboardDeaths and score.deaths or player.deaths or 0;
		player.damage = score.damage;
		player.healing = score.healing;

		if(ArenaTracker:IsRated()) then
			player.rating = score.rating;
			player.ratingDelta = score.ratingDelta;
			player.mmr = score.mmr;
			player.mmrDelta = score.mmrDelta;
		end

		if(isShuffle) then
			player.wins = score.wins or 0;
		end

		if(player.name) then
			-- First Death
			if(not isShuffle and player.name == firstDeath) then
				player.isFirstDeath = true;
			end

			if (currentArena.playerName and player.name == currentArena.playerName) then
				myTeamIndex = player.teamIndex;
				player.isSelf = true;
			elseif(isShuffle) then
				-- Everyone else is an opponent in shuffle (1v5)
				player.isEnemy = true;
			end

			table.insert(players, player);
		else
			Debug:LogWarning("Tracker: Invalid player name, player will not be stored!");
		end

		TablePool:Release(score);
	end

	if(ArenaTracker:IsTrackingShuffle()) then
		-- Determine match outcome
		currentArena.outcome = ArenaTracker:GetShuffleOutcome()
	else
		-- Assign isEnemy value
		for _,player in ipairs(players) do
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
	if (ArenaTracker:IsRated() and myTeamIndex) then
		local otherTeamIndex = (myTeamIndex == 0) and 1 or 0;

		currentArena.partyMMR = API:GetTeamMMR(myTeamIndex);
		currentArena.enemyMMR = API:GetTeamMMR(otherTeamIndex);
	end

	currentArena.players = players;

	Debug:Log("Match ended!", #currentArena.players, "players tracked.");
end

-- Player left an arena (Zone changed to non-arena with valid arena data)
function ArenaTracker:HandleArenaExit()
	assert(currentArena.size);
	assert(currentArena.mapId);

	if(Inspection and Inspection.Clear) then
		Inspection:Clear();
	end

	-- Solo Shuffle
	ArenaTracker:HandleRoundEnd(true);

	currentArena.hasStartTime = Helpers:IsPositiveNumber(currentArena.startTime);
	currentArena.startTime = tonumber(currentArena.startTime) or time();
	currentArena.endTime = tonumber(currentArena.endTime) or time();

	if(not currentArena.endedProperly) then
		currentArena.ended = true;
		currentArena.outcome = 0;

		Debug:Log("Detected early leave. Has valid current arena: ", currentArena.mapId);
	end

	Debug:Log("Exited Arena:", API:GetPersonalRatedInfo(currentArena.bracketIndex));

	if(ArenaTracker:IsRated() and not currentArena.partyRating) then
		local newRating, seasonPlayed = API:GetPersonalRatedInfo(currentArena.bracketIndex);
		if(newRating and currentArena.seasonPlayed) then
			local oldRating = currentArena.oldRating;
			if(not oldRating) then
				local season = API:GetCurrentSeason();
				local lastSeasonPlayed = currentArena.seasonPlayed - 1;

				local rating, lastRating = ArenaRatedInfo:GetRatedInfo(currentArena.bracketIndex, currentArena.seasonPlayed);

				oldRating = lastRating or ArenaAnalytics:GetLatestRating(currentArena.bracketIndex, season, lastSeasonPlayed); -- TODO: Validate this
				Debug:LogWarning("Fixed missing old rating:", oldRating, "bracketIndex:", currentArena.bracketIndex, "season:", season, "seasonPlayed:", currentArena.seasonPlayed);
			end

			currentArena.partyRating = newRating;
			currentArena.partyRatingDelta = oldRating and newRating - oldRating or nil;
			Debug:LogGreen("Setting party rating delta:", currentArena.partyRatingDelta, oldRating, newRating);
		else
			Debug:Log("Warning: Nil current rating retrieved from API upon leaving arena.");
		end

		Debug:LogTemp("ArenaExit season played:", currentArena.seasonPlayed, seasonPlayed);
		if(currentArena.seasonPlayed) then
			if(seasonPlayed and seasonPlayed < currentArena.seasonPlayed) then
				-- Rating has updated, no longer needed to store transient Season Played for fixup.
				currentArena.requireRatingFix = true;
			else
				Debug:Log("Tracker: Invalid or up to date seasonPlayed.", seasonPlayed, currentArena.seasonPlayed);
			end
		else
			Debug:Log("Tracker: No season played stored on currentArena.");
		end
	end

	ArenaAnalytics:InsertArenaToMatchHistory(currentArena);
	ArenaTracker:Clear();
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
	if(playerGUID == nil) then
		return;
	end

	local class, race, name, realm = API:GetPlayerInfoByGUID(playerGUID);
	if(name == nil or name == "") then
		ArenaAnalytics:LogError("Invalid name of dead player. Skipping..");
		return;
	end

	if(not realm or realm == "") then
		name = Helpers:ToFullName(name);
	else
		name = name .. "-" .. realm;
	end

	Debug:Log("Player Kill!", isKillCredit, name);

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