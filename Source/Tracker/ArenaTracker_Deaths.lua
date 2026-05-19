local _, ArenaAnalytics = ... -- Namespace
local ArenaTracker = ArenaAnalytics.ArenaTracker;

-- Local module aliases
local API = ArenaAnalytics.API;
local Helpers = ArenaAnalytics.Helpers;
local TablePool = ArenaAnalytics.TablePool;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------

local currentArena = {};
function ArenaTracker:InitializeSubmodule_Deaths()
    currentArena = ArenaAnalyticsTransientDB.currentArena;
end


function ArenaTracker:GetDeathData()
	assert(currentArena);
	if(type(currentArena.deathData) ~= "table") then
		Debug:LogError("Force reset DeathData from non-table value!");
		currentArena.deathData = TablePool:Acquire();
	end
	return currentArena.deathData;
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
function ArenaTracker:TryRemoveFromDeaths(playerGUID, spell)
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


local function IsPartyFeignDeath(playerGUID)
	if(not API:IsValidValue(playerGUID)) then
		return;
	end

	-- local player
	local unitToken = "player";
	if(playerGUID == Helpers:UnitGUID(unitToken)) then
		return API:UnitIsFeignDeath(unitToken);
	end

	for i=1, 2 do
		unitToken = "party"..i;
		if(playerGUID == Helpers:UnitGUID(unitToken)) then
			return API:UnitIsFeignDeath(unitToken);
		end
	end

	-- Unit was not found
	return nil;
end

-- Handle a player's death, through death or kill credit message
function ArenaTracker:HandlePlayerDeath(playerGUID, isKillCredit)
	if(not API:IsValidValue(playerGUID)) then
		return;
	end

	if(not playerGUID:find("Player-", 1, true)) then
		Debug:LogWarning("HandlePlayerDeath with non-player GUID.");
		return;
	end

	local name, realm, class, race, isFemale = API:GetPlayerInfoByGUID(playerGUID);
	if(not API:IsValidValue(name)) then
		Debug:LogError("Invalid name of dead player. Skipping..");
		return;
	end

	local isHunter = (class == "HUNTER") or nil;
	if(isHunter and IsPartyFeignDeath(playerGUID)) then
		Debug:LogPurple("Player death treated as feign death.");
		return;
	end

	if(API:IsValidValue(realm)) then
		name = name .. "-" .. realm;
	else
		name = API:ToFullName(name);
	end

	Debug:LogGreen("Player Kill!", isKillCredit, name);

	-- Store death
	local deathData = ArenaTracker:GetDeathData();
	local death = type(deathData[playerGUID]) == "table" and deathData[playerGUID] or TablePool:Acquire();
	death.time = time();
	death.name = name;
	death.isHunter = isHunter;
	death.hasKillCredit = isKillCredit or death.hasKillCredit;

	deathData[playerGUID] = death;
	Debug:LogGreen("Assigned death:", death.name, playerGUID);
end


-- Commits current deaths to player stats (May be overridden by scoreboard, if value is trusted for the expansion)
function ArenaTracker:CommitDeaths()
	local deathData = ArenaTracker:GetDeathData();
	Helpers:SanitizeSecretTable(deathData);

	for key,data in pairs(deathData) do
		local player = ArenaTracker:GetPlayer(key);
		if(player and data) then
			-- Increment deaths
			player.deaths = (player.deaths or 0) + 1;
		else
			Debug:LogWarning("ArenaTracker:CommitDeaths failed to assign deaths for player:", player and player.name, key);
		end
	end

	wipe(currentArena.deathData);
end

-- Fetch the real first death when saving the match
function ArenaTracker:GetFirstDeathFromCurrentArena(skipHunter)
	local deathData = ArenaTracker:GetDeathData();
	if(deathData == nil) then
		return;
	end

	local bestKey, bestTime, isHunter;
	for key,data in pairs(deathData) do
		if(key and type(data) == "table" and data.time) then
			if(bestTime == nil or data.time < bestTime) then
				local timeSince = time() - data.time;
				if(not skipHunter or not data.isHunter) then -- Trusting hunters are risky, may break shuffles
					bestKey = key;
					bestTime = data.time;
				end
			end
		else
			local player = ArenaTracker:GetPlayer(key);
			Debug:LogError("Invalid death data found:", key, player and player.name, type(data));
		end
	end

	if(not bestKey or not deathData[bestKey]) then
		Debug:Log("Death data missing from currentArena. HasKey:", bestKey ~= nil);
		return nil;
	end

	local bestData = deathData[bestKey];
	return bestData.name, bestData.time, bestData.isHunter;
end
