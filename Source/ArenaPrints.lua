local _, ArenaAnalytics = ...; -- Addon Namespace
local Prints = ArenaAnalytics.Prints;

-- Local module aliases
local Options = ArenaAnalytics.Options;
local Colors = ArenaAnalytics.Colors;

-------------------------------------------------------------------------

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
	local text;

	local name = UnitNameUnmodified("player");

	if(welcomeMessageSeed < 10) then
		text = format("You're being tracked, %s.", name);
	elseif(welcomeMessageSeed < 100) then
		text = format("Have a wonderful day, %s!", name);
	elseif(welcomeMessageSeed == 213) then
		text = format("I'm watching you, %s!", name);
	else
		text = format("Tracking arena games, glhf %s!!", name);
	end

    ArenaAnalytics:PrintSystem(text);
end
