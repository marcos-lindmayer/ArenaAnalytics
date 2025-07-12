local _, ArenaAnalytics = ... -- Namespace
local ArenaRatedInfo = ArenaAnalytics.ArenaRatedInfo;

-- Local module aliases
local API = ArenaAnalytics.API;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------

local RATING_HISTORY_LIMIT = 10;

local function GetBracketRatedInfo(bracketIndex)
	assert(ArenaAnalytics:GetBracket(bracketIndex), "Invalid bracketIndex!");
	ArenaAnalyticsTransientDB.ratedInfo[bracketIndex] = ArenaAnalyticsTransientDB.ratedInfo[bracketIndex] or {};
	return ArenaAnalyticsTransientDB.ratedInfo[bracketIndex];
end

local function ClearOutdatedRatings(bracketIndex, seasonPlayed)
	local bracketRatedInfo = GetBracketRatedInfo(bracketIndex);

	for key,rating in pairs(bracketRatedInfo) do
		if(type(key) == "number") then
			if(key < seasonPlayed - RATING_HISTORY_LIMIT) then
				Debug:Log("ArenaRatedInfo clearing old rating:", ArenaAnalytics:GetBracket(bracketIndex), seasonPlayed, rating);
				bracketRatedInfo[key] = nil;
			end
		end
	end
end

-- Fix to deal deal with missed arenas (Clear & start over if seasonPlayed is nil or outdated)
local function UpdateBracketCachedRatings(bracketIndex, seasonPlayed, rating)
	bracketIndex = tonumber(bracketIndex);
	seasonPlayed = tonumber(seasonPlayed);
	rating = tonumber(rating);

	if(not seasonPlayed or not rating) then
		return;
	end

	local bracketRatedInfo = GetBracketRatedInfo(bracketIndex);
	bracketRatedInfo[seasonPlayed] = rating;

	-- Store the last season played known from outside arenas (May update twice after early leaves)
	if(not API:IsInArena()) then
		bracketRatedInfo.lastWorldSeasonPlayed = seasonPlayed;
	end

	Debug:Log("UpdateBracketCachedRatings:", bracketIndex, seasonPlayed, bracketRatedInfo[seasonPlayed]);
end

function ArenaRatedInfo:UpdateRatedInfo()
	ArenaAnalytics:InitializeTransientDB();

	for bracketIndex=1, 4 do
		assert(ArenaAnalytics:GetBracket(bracketIndex), "Invalid bracketIndex in UpdateRatedInfo!");

		local rating, seasonPlayed = API:GetPersonalRatedInfo(bracketIndex);
		if(rating and seasonPlayed) then
			UpdateBracketCachedRatings(bracketIndex, seasonPlayed, rating);
			ClearOutdatedRatings(bracketIndex, seasonPlayed);
		end
	end
end

function ArenaRatedInfo:GetRatedInfo(bracketIndex, seasonPlayed)
	bracketIndex = tonumber(bracketIndex);
	seasonPlayed = tonumber(seasonPlayed);
	if(not bracketIndex or not seasonPlayed) then
		return nil;
	end

	local bracketRatedInfo = GetBracketRatedInfo(bracketIndex);

	local rating = bracketRatedInfo[seasonPlayed];
	local lastRating = bracketRatedInfo[seasonPlayed - 1];

	return tonumber(rating), tonumber(lastRating);
end

function ArenaRatedInfo:HasRating(bracketIndex, seasonPlayed)
	bracketIndex = tonumber(bracketIndex);
	seasonPlayed = tonumber(seasonPlayed);
	if(not bracketIndex or not seasonPlayed) then
		return nil;
	end

	local bracketRatedInfo = ArenaAnalyticsTransientDB.ratedInfo[bracketIndex];
	return bracketRatedInfo and tonumber(bracketRatedInfo[seasonPlayed]) ~= nil;
end

function ArenaRatedInfo:GetLastSeasonPlayed(bracketIndex)
	bracketIndex = tonumber(bracketIndex);
	if(not bracketIndex) then
		return nil;
	end

	local bracketRatedInfo = ArenaAnalyticsTransientDB.ratedInfo[bracketIndex];
	if(not bracketRatedInfo) then
		return nil;
	end

	local latestSeasonPlayed = 0;
	for seasonPlayed,_ in pairs(bracketRatedInfo) do
		if(type(seasonPlayed) == "number" and latestSeasonPlayed < seasonPlayed) then
			latestSeasonPlayed = seasonPlayed;
		end
	end

	if(latestSeasonPlayed == 0) then
		return nil;
	end

	return latestSeasonPlayed;
end