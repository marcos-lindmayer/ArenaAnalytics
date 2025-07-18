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
local Filters = ArenaAnalytics.Filters;
local Helpers = ArenaAnalytics.Helpers;

-------------------------------------------------------------------------
-- Helper functions

local function ColorSlashCommand(text)
	return Colors:ColorText(text, Colors.slashCommandColor);
end

-------------------------------------------------------------------------
-- Command Handlers

function Commands.HandleCommand_Help()
	ArenaAnalytics:PrintSystemSpacer();
	ArenaAnalytics:PrintSystem("List of slash commands:");
	ArenaAnalytics:PrintSystem(ColorSlashCommand("/aa"), "Togggles ArenaAnalytics main panel.");
	ArenaAnalytics:PrintSystem(ColorSlashCommand("/aa played"), "Prints total duration of tracked arenas.");
	ArenaAnalytics:PrintSystem(ColorSlashCommand("/aa version"), "Prints the current ArenaAnalytics version.");
	ArenaAnalytics:PrintSystem(ColorSlashCommand("/aa total"), "Prints total unfiltered matches.");
	ArenaAnalytics:PrintSystem(ColorSlashCommand("/aa purge"), "Show dialog to permanently delete match history.");
	ArenaAnalytics:PrintSystem(ColorSlashCommand("/aa credits"), "Print addon credits.");
	ArenaAnalytics:PrintSystemSpacer();
end

function Commands.HandleCommand_Credits()
	ArenaAnalytics:PrintSystem("ArenaAnalytics authors: Lingo, Zeetrax.   Developed in association with Hydra. www.twitch.tv/Hydramist");
end

function Commands.HandleCommand_Version()
	ArenaAnalytics:PrintSystem("Current version: " .. Colors:GetVersionText("Invalid Version"));
end

function Commands.HandleCommand_Total()
	ArenaAnalytics:PrintSystem("Total arenas stored: ", #ArenaAnalyticsDB);
end

function Commands.HandleCommand_Played()
	local totalDurationInArenas = 0;
	local currentSeasonTotalPlayed = 0;
	local longestDuration = 0;
	for i=1, ArenaAnalytics.filteredMatchCount do
		local match = ArenaAnalytics:GetFilteredMatch(i);
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

	local function PrintColored(text, duration)
		if(duration == "") then
			duration = "None";
		end

		local coloredText = Colors:ColorText(text, Colors.white);
		local coloredDuration = Colors:ColorText(duration, Colors.statsColor);
		ArenaAnalytics:PrintSystem(coloredText, coloredDuration);
	end

	-- TODO: Update coloring?
	ArenaAnalytics:PrintSystem(Colors:ColorText("==== Arena Played Time ==========", Colors.infoColor));
	PrintColored(" Total played: ", SecondsToTime(totalDurationInArenas));
	PrintColored(" Current season: ", SecondsToTime(currentSeasonTotalPlayed) or "NaN");
	PrintColored(" Average duration: ", SecondsToTime(math.floor(totalDurationInArenas / ArenaAnalytics.filteredMatchCount)));
	PrintColored(" Longest duration: ", SecondsToTime(math.floor(longestDuration)));
	ArenaAnalytics:PrintSystem(Colors:ColorText("=============================", Colors.infoColor));
end

function Commands.HandleCommand_Debug(level)
	Debug:SetDebugLevel(level);
end

function Commands.HandleCommand_Convert()
	ArenaAnalytics:PrintSystem("Forcing data version conversion..");
	if(not ArenaAnalyticsDB or #ArenaAnalyticsDB == 0) then
		VersionManager:OnInit();
	end
	ArenaAnalyticsScrollFrame:Hide();
end

function Commands.HandleCommand_Update(arg)
	if(arg == "sessions") then
		ArenaAnalytics:PrintSystem("Updating sessions in ArenaAnalyticsDB.");
		Sessions:RecomputeSessionsForMatchHistory(true);
		Filters:Refresh();
	elseif(arg == "groups") then
		ArenaAnalytics:PrintSystem("Updating group sorting in ArenaAnalyticsDB.");
		ArenaAnalytics:ResortGroupsInMatchHistory(true);
		Filters:Refresh();
	elseif(arg == "matches") then
		ArenaAnalytics:PrintSystem("Resorting matches in ArenaAnalyticsDB.");
		ArenaAnalytics:ResortMatchHistory(true);
		Filters:Refresh();
	else
		-- Show /aa update help
		ArenaAnalytics:PrintSystem(ColorSlashCommand("/aa update"), "help:");
		ArenaAnalytics:PrintSystem(ColorSlashCommand("/aa update sessions"), "Recomputes sessions.");
		ArenaAnalytics:PrintSystem(ColorSlashCommand("/aa update groups"), "Sort players in all stored groups.");
		ArenaAnalytics:PrintSystem(ColorSlashCommand("/aa update matches"), "Resorts the match history. Invalid dates last.");
	end
end

function Commands.HandleCommand_Purge()
	ArenaAnalytics:ShowPurgeConfirmationDialog();
end

function Commands.HandleCommand_DumpRealms()
	print(" ");
	ArenaAnalytics:Print(" ================================================  ");
	ArenaAnalytics:Print("  Known Realms:     (Current realm: " .. (ArenaAnalytics:GetLocalRealmIndex() or "").. ")");

	for i,realm in ipairs(ArenaAnalyticsDB.realms) do
		ArenaAnalytics:Print("     ", i, "   ", realm);
	end
	ArenaAnalytics:Print("  ================================================  ");
	print(" ");
end

function Commands.HandleCommand_Dump()
	print(" ");
	ArenaAnalytics:Print("================================================  ");

	local interfaceVersion = select(4, GetBuildInfo());
	ArenaAnalytics:Print("Interface Version:", interfaceVersion);

	if(API and API.IsInArena()) then
		ArenaAnalytics:Print("Arena Map ID:", API:GetCurrentMapID(), GetZoneText());

		if(API.hasDampening) then
			ArenaAnalytics:Print("Dampening Buff:", API:GetCurrentDampening());
		end

		ArenaAnalytics:Print("IsArenaPreparation:", API:IsArenaPreparation());
	end

	ArenaAnalytics:Print("================================================  ");
	print(" ");
end

function Commands.HandleCommand_Test()
	print(" ");
	ArenaAnalytics:Print("================================================ ");

	--Debug:Log("Target isFemale:", Helpers:IsUnitFemale("target"), UnitNameUnmodified("target"));

	local teamMMR, enemyMMR = API:GetTeamMMR(false), API:GetTeamMMR(true);
	Debug:LogTemp("Score Event MMR Test:", teamMMR, enemyMMR, #ArenaAnalyticsDB);
	Debug:LogTemp("Score0:", GetBattlefieldTeamInfo(0))
	Debug:LogTemp("Score0:", GetBattlefieldTeamInfo(1))

	ArenaAnalytics:Print("================================================ ");
end

function Commands.HandleCommand_Inspect(...)
	Debug:NotifyInspectSpec(...);
end

--------------------------------------
-- Custom Slash Command
--------------------------------------

Commands.list = {
	["help"] = Commands.HandleCommand_Help,
	["credits"] = Commands.HandleCommand_Credits,
	["version"] = Commands.HandleCommand_Version,
	["total"] = Commands.HandleCommand_Total,
	["played"] = Commands.HandleCommand_Played,
	["convert"] = Commands.HandleCommand_Convert,
	["update"] = Commands.HandleCommand_Update,
	["purge"] = Commands.HandleCommand_Purge,
	["inspect"] = Commands.HandleCommand_Inspect,

	-- Debug commands
	["debug"] = Commands.HandleCommand_Debug,				-- Debug level
	["dumprealms"] = Commands.HandleCommand_DumpRealms,		-- Debugging: Used for temporary explicit triggering of logic, for testing purposes.
	["test"] = Commands.HandleCommand_Test,					-- Debugging: Used for temporary explicit triggering of logic, for testing purposes.
	["dump"] = Commands.HandleCommand_Dump,					-- Debugging: Used to gather zone and version info from users helping with version update.
};

local function handleSlashCommands(str)
	if (#str == 0) then
		-- User just entered "/aa" with no additional args.
		ArenaAnalyticsToggle();
		return;
	end

	str = Helpers:ToSafeLower(str);

	-- Split args by spaces
	local args = {};
	for _, arg in ipairs({ string.split(' ', str) }) do
		if (#arg > 0) then
			table.insert(args, arg);
		end
	end

	local path = Commands.list; -- required for updating found table.

	for i, arg in ipairs(args) do
		if (#arg > 0) then -- if string length is greater than 0.
			if (path[arg]) then
				if (type(path[arg]) == "function") then
					-- all remaining args passed to our function!
					path[arg](select(i + 1, unpack(args)));
					return;
				elseif (type(path[arg]) == "table") then
					path = path[arg]; -- another sub-table found!
				else
					Debug:LogWarning("Invalid /aa command:", i, path[arg]);
					break;
				end
			else
				-- Does not exist!
				break;
			end
		end
	end

	Commands.list.help();
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