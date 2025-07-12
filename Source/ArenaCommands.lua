local _, ArenaAnalytics = ...; -- Addon Namespace
local Commands = ArenaAnalytics.Commands;

-- Local module aliases
local ArenaTracker = ArenaAnalytics.ArenaTracker;
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local API = ArenaAnalytics.API;
local Colors = ArenaAnalytics.Colors;
local Options = ArenaAnalytics.Options;
local Sessions = ArenaAnalytics.Sessions;
local VersionManager = ArenaAnalytics.VersionManager;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------

--------------------------------------
-- Custom Slash Command
--------------------------------------
Commands.list = {
	["help"] = function()
		ArenaAnalytics:PrintSystemSpacer();
		ArenaAnalytics:PrintSystem("List of slash commands:");
		ArenaAnalytics:PrintSystem("|cff00cc66/aa|r Togggles ArenaAnalytics main panel.");
		ArenaAnalytics:PrintSystem("|cff00cc66/aa played|r Prints total duration of tracked arenas.");
		ArenaAnalytics:PrintSystem("|cff00cc66/aa version|r Prints the current ArenaAnalytics version.");
		ArenaAnalytics:PrintSystem("|cff00cc66/aa total|r Prints total unfiltered matches.");
		ArenaAnalytics:PrintSystem("|cff00cc66/aa purge|r Show dialog to permanently delete match history.");
		ArenaAnalytics:PrintSystem("|cff00cc66/aa credits|r Print addon credits.");
		ArenaAnalytics:PrintSystemSpacer();
	end,

	["credits"] = function()
		ArenaAnalytics:PrintSystem("ArenaAnalytics authors: Lingo, Zeetrax.   Developed in association with Hydra. www.twitch.tv/Hydramist");
	end,

	["version"] = function()
		ArenaAnalytics:PrintSystem("Current version: " .. Colors:GetVersionText("Invalid Version"));
	end,

	["total"] = function()
		ArenaAnalytics:PrintSystem("Total arenas stored: ", #ArenaAnalyticsDB);
	end,

	-- TODO: Update this to respect active filters
	["played"] = function()
		local totalDurationInArenas = 0;
		local currentSeasonTotalPlayed = 0;
		local longestDuration = 0;
		for i=1, #ArenaAnalyticsDB do
			local match = ArenaAnalyticsDB[i];
			local duration = ArenaMatch:GetDuration(match) or 0;
			if(duration > 0) then
				totalDurationInArenas = totalDurationInArenas + duration;

				if(duration < 2760) then -- Only count valid duration (plus 60sec buffer)
					longestDuration = max(longestDuration, duration);
				end

				if(ArenaMatch:GetSeason(match) == API:GetCurrentSeason()) then
					currentSeasonTotalPlayed = currentSeasonTotalPlayed + duration;
				end
			end
		end

		-- TODO: Update coloring?
		ArenaAnalytics:PrintSystem("Total arena time played: ", SecondsToTime(totalDurationInArenas));
		ArenaAnalytics:PrintSystem("Time played this season: ", SecondsToTime(currentSeasonTotalPlayed));
		ArenaAnalytics:PrintSystem("Average arena duration: ", SecondsToTime(math.floor(totalDurationInArenas / #ArenaAnalyticsDB)));
		ArenaAnalytics:PrintSystem("Longest arena duration: ", SecondsToTime(math.floor(longestDuration)));
	end,

	-- Debug level
	["debug"] = function(level)
		Debug:SetDebugLevel(level);
	end,

	["convert"] = function()
		ArenaAnalytics:PrintSystem("Forcing data version conversion..");
		if(not ArenaAnalyticsDB or #ArenaAnalyticsDB == 0) then
			VersionManager:OnInit();
		end
        ArenaAnalyticsScrollFrame:Hide();
	end,

	["updatesessions"] = function()
		ArenaAnalytics:PrintSystem("Updating sessions in ArenaAnalyticsDB.");
		Sessions:RecomputeSessionsForMatchHistory();

        ArenaAnalyticsScrollFrame:Hide();
	end,

	["updategroupsort"] = function()
		ArenaAnalytics:PrintSystem("Updating group sorting in ArenaAnalyticsDB.");

		ArenaAnalytics:ResortGroupsInMatchHistory();

        ArenaAnalyticsScrollFrame:Hide();
	end,

	["purge"] = function()
		ArenaAnalytics:ShowPurgeConfirmationDialog();
	end,

	["debugcleardb"] = function()
		if(Debug:GetDebugLevel() == 0) then
			ArenaAnalytics:PrintSystem("Clearing ArenaAnalyticsDB requires debugging enabled.  |cffBBBBBB/aa debug|r. Not intended for users!");
		else -- Debug mode is enabled, allow debug clearing the DB
			if (ArenaAnalytics:HasStoredMatches()) then
				Debug:Log("Purging ArenaAnalyticsDB.");
				ArenaAnalytics:PurgeArenaAnalyticsDB();
			end
		end
	end,

	-- Debugging: Used for temporary explicit triggering of logic, for testing purposes.
	["dumprealms"] = function()
		print(" ");
		ArenaAnalytics:Print(" ================================================  ");
		ArenaAnalytics:Print("  Known Realms:     (Current realm: " .. (ArenaAnalytics:GetLocalRealmIndex() or "").. ")");

		for i,realm in ipairs(ArenaAnalyticsDB.realms) do
			ArenaAnalytics:Print("     ", i, "   ", realm);
		end
		ArenaAnalytics:Print("  ================================================  ");
		print(" ");
	end,

	-- Debugging: Used to gather zone and version info from users helping with version update
	["dump"] = function(...)
		print(" ");
		ArenaAnalytics:Print(" ================================================  ");

		local interfaceVersion = select(4, GetBuildInfo());
		ArenaAnalytics:Print("Interface Version:", interfaceVersion);

		if(API and API.IsInArena()) then
			ArenaAnalytics:Print("Arena Map ID:", API:GetCurrentMapID(), GetZoneText());
			ArenaAnalytics:Print("BattlefieldWinner", API:GetWinner(), ArenaTracker:GetSeasonPlayed());
		end
		print(" ");
	end,

	-- Debugging: Used for temporary explicit triggering of logic, for testing purposes.
	["test"] = function(...)
		print(" ");
		ArenaAnalytics:Print(" ================================================ ");

		if(API:IsInArena()) then
			--Debug:LogTemp("Requesting RequestBattlefieldScoreData")
			--RequestBattlefieldScoreData();
			Debug:Log("BattlefieldID", API:GetActiveBattlefieldID());
		end

		Debug:LogTable(ArenaTracker:GetCurrentArena());

		ArenaAnalytics:Print(" ================================================ ");
	end,

	["inspect"] = function(...)
		Debug:NotifyInspectSpec(...);
	end,
};

local function handleSlashCommands(str)
	if (#str == 0) then
		-- User just entered "/aa" with no additional args.
		ArenaAnalyticsToggle();
		return;
	end

	-- Split args by spaces
	local args = {};
	for _, arg in ipairs({ string.split(' ', str) }) do
		if (#arg > 0) then
			table.insert(args, arg);
		end
	end

	local path = Commands.list; -- required for updating found table.

	for id, arg in ipairs(args) do
		if (#arg > 0) then -- if string length is greater than 0.
			arg = arg:lower();			
			if (path[arg]) then
				if (type(path[arg]) == "function") then				
					-- all remaining args passed to our function!
					path[arg](select(id + 1, unpack(args))); 
					return;					
				elseif (type(path[arg]) == "table") then				
					path = path[arg]; -- another sub-table found!
				end
			else
				-- does not exist!
				Commands.list.help();
				return;
			end
		end
	end
end


-------------------------------------------------------------------------
-- afk / surrender commands

function Commands.HandleChatAfk(message)
	Debug:Log("/afk override triggered.");
	local surrendered = API:TrySurrenderArena("afk");
	if(surrendered == nil) then
		-- Fallback to base /afk
		SendChatMessage(message, "AFK");
	end
end

function Commands.HandleGoodGame()
	Debug:Log("/gg triggered.");
	API:TrySurrenderArena("gg");
end

function Commands.UpdateSurrenderCommands()
	if(not API:HasSurrenderAPI()) then
		return;
	end

	local isAfkOverrideActive = (SlashCmdList.CHAT_AFK == Commands.HandleChatAfk);
	if(Options:Get("enableSurrenderAfkOverride")) then
		if(not isAfkOverrideActive) then
			Commands.previousAfkFunc = SlashCmdList.CHAT_AFK;
			SlashCmdList.CHAT_AFK = Commands.HandleChatAfk;
		end
	elseif(isAfkOverrideActive and Commands.previousAfkFunc) then
		SlashCmdList.CHAT_AFK = Commands.previousAfkFunc;
	end

	local hasGoodGameCommand = (SLASH_ArenaAnalyticsSurrender1 ~= nil and SlashCmdList.ArenaAnalyticsSurrender ~= nil);
	if(Options:Get("enableSurrenderGoodGameCommand")) then
		if(not hasGoodGameCommand) then
			-- /gg to surrender
			SLASH_ArenaAnalyticsSurrender1 = "/gg";
			SlashCmdList.ArenaAnalyticsSurrender = Commands.HandleGoodGame;
		end
	elseif(hasGoodGameCommand) then
		SLASH_ArenaAnalyticsSurrender1 = nil;
		SlashCmdList.ArenaAnalyticsSurrender = nil;
	end
end

-------------------------------------------------------------------------

function Commands:Initialize()
	SLASH_ArenaAnalyticsCommands1 = "/AA";
	SLASH_ArenaAnalyticsCommands2 = "/ArenaAnalytics";
	SlashCmdList.ArenaAnalyticsCommands = handleSlashCommands;

	-- Update /afk and /gg for surrender, if the game version supports it
	Commands.UpdateSurrenderCommands();
end