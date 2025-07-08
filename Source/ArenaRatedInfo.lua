local _, ArenaAnalytics = ... -- Namespace
local ArenaRatedInfo = ArenaAnalytics.ArenaRatedInfo;

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

-------------------------------------------------------------------------

-- Fix to deal deal with missed arenas (Clear & start over if seasonPlayed is nil or outdated)
local function UpdateBracketCachedRatings(bracketIndex, seasonPlayed, rating)
	bracketIndex = tonumber(bracketIndex);
	seasonPlayed = tonumber(seasonPlayed);
	rating = tonumber(rating);

	if(not bracketIndex or not seasonPlayed or not rating) then
		return;
	end

	ArenaAnalyticsTransientDB.ratedInfo[bracketIndex] = ArenaAnalyticsTransientDB.ratedInfo[bracketIndex] or {};
	local ratedInfo = ArenaAnalyticsTransientDB.ratedInfo[bracketIndex];

	if(not ratedInfo.seasonPlayed or (seasonPlayed - 1 > ratedInfo.seasonPlayed)) then
		ratedInfo.seasonPlayed = seasonPlayed;
		ratedInfo.rating = rating;
		ratedInfo.lastRating = nil;
	elseif(seasonPlayed == ratedInfo.seasonPlayed) then
		if(ratedInfo.rating ~= rating) then
			Debug:LogWarning("ArenaRatedInfo: New rating for same season played.");

			ratedInfo.rating = rating;
			ratedInfo.seasonPlayed = seasonPlayed;
		end
	elseif((seasonPlayed - 1) == ratedInfo.seasonPlayed) then
		ratedInfo.seasonPlayed = seasonPlayed;
		ratedInfo.rating = rating;
		ratedInfo.lastRating = ratedInfo.rating;
	end

	Debug:Log("UpdateBracketCachedRatings:", bracketIndex, ratedInfo.seasonPlayed, ratedInfo.rating, ratedInfo.lastRating);
end

function ArenaRatedInfo:UpdateRatedInfo()
	ArenaAnalytics:InitializeTransientDB();

	for bracketIndex=1, 4 do
		local rating, seasonPlayed = API:GetPersonalRatedInfo(bracketIndex);
		UpdateBracketCachedRatings(bracketIndex, seasonPlayed, rating)
	end
end

function ArenaRatedInfo:GetRatedInfo(bracketIndex, seasonPlayed)
	bracketIndex = tonumber(bracketIndex);
	seasonPlayed = tonumber(seasonPlayed);
	if(not bracketIndex or not seasonPlayed) then
		return nil;
	end

	local ratedInfo = ArenaAnalyticsTransientDB.ratedInfo[bracketIndex];
	if(not ratedInfo) then
		Debug:LogWarning("ArenaRatedInfo:GetRatedInfo called for bracket:", bracketIndex, "with no cached values.");
		return nil;
	end

	if(seasonPlayed == ratedInfo.seasonPlayed) then
		return ratedInfo.rating, ratedInfo.lastRating;
	elseif((seasonPlayed - 1) == ratedInfo.seasonPlayed) then
		return nil, ratedInfo.rating;
	end

	return nil;
end