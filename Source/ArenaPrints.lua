local _, ArenaAnalytics = ...; -- Addon Namespace
local Prints = ArenaAnalytics.Prints;

-- Local module aliases
local Options = ArenaAnalytics.Options;
local Colors = ArenaAnalytics.Colors;
local API = ArenaAnalytics.API;

-------------------------------------------------------------------------

-- Evaluate this, consider use cases for refactoring or clearing it
function Prints:PrintRaw(prefix, ...)
	prefix = tostring(prefix);

	if(not Options:GetSafe("printAsSystem")) then
		if(prefix and #prefix > 0) then
			print(prefix, ...);
		else
			print(...);
		end
	else
		local params = {...};
		for key in pairs(params) do
			if(params[key] == nil) then
				params[key] = "nil";
			end
		end

		SendSystemMessage((prefix or "") .. Colors:ColorText(table.concat(params, " "), Colors.white))
	end
end

function ArenaAnalytics:Print(...)
    local prefix = Colors:ColorText("ArenaAnalytics: ", Colors.themeColor);
	print(prefix, ...);
end

function ArenaAnalytics:PrintSystem(...)
	if(not Options:GetSafe("printAsSystem")) then
		ArenaAnalytics:Print(...);
		return;
	end

    -- Fix nil values
	local params = {...};
	for key in pairs(params) do
		if(params[key] == nil) then
			params[key] = "nil";
		end
	end

    local prefix = Colors:ColorText("ArenaAnalytics: ", Colors.themeColor);
	SendSystemMessage(prefix .. Colors:ColorText(table.concat(params, " "), Colors.white));
end

function ArenaAnalytics:PrintSystemSpacer()
	if(not Options:GetSafe("printAsSystem")) then
		print(" ");
		return;
	end

	SendSystemMessage(" ");
end

-------------------------------------------------------------------------

function Prints:PrintWelcomeMessage()
	local welcomeMessageSeed = random(1, 10000);

	local name = API:GetPlayerName(true) or "";

	local text;
	if(welcomeMessageSeed < 13) then
		text = format("You're being tracked, %s.", name);
	elseif(welcomeMessageSeed == 213) then
		text = format("I'm watching you, %s!", name);
	elseif(welcomeMessageSeed < 100) then
		text = format("Have a wonderful day, %s!", name);
	else
		text = format("Tracking arena games, glhf %s!!", name);
	end

    ArenaAnalytics:PrintSystem(text);
end
