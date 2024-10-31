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

function ArenaTracker:getCurrentBattleground()
	return currentBattleground;
end

-- Battleground variables
local currentBattleground = {}

-- Reset current Battleground values
function BattlegroundTracker:Reset()
	ArenaAnalytics:Log("Resetting current Battleground values..");

	-- Current Battleground
	currentBattleground.battlefieldId = nil;
	currentBattleground.mapId = nil;

	currentBattleground.playerName = "";

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

	currentBattleground.players = TablePool:Acquire();

	currentBattleground.ended = false;
	currentBattleground.endedProperly = false;
	currentBattleground.outcome = nil;

	currentBattleground.round = TablePool:Acquire();
	currentBattleground.committedRounds = TablePool:Acquire();

	currentBattleground.deathData = TablePool:Acquire();

	-- Current Round
	currentBattleground.round.hasStarted = nil;
	currentBattleground.round.startTime = nil;
	currentBattleground.round.team = TablePool:Acquire();

	ArenaAnalyticsDB.currentMatch = currentBattleground;
end

function BattlegroundTracker:Clear()
	ArenaAnalytics:Log("Clearing current Battleground.");

	ArenaAnalyticsDB.currentMatch = nil;
	currentBattleground = {};
end
