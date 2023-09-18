# ArenaAnalytics
Arena log and stats addOn.

*Author: Lingo*

Special thanks to: 
Hydra, Itrulia, and Permok.

*Inspired by ArenaStatsTBC.*
Credit to Gladdy for spec spells and translations tables.

Open layout with */aa*

Player Search functionality:
The search field takes in a comma separated list of players.
Starting a player segment with (+/-) prefix enforces searching for specific team. (+ = your team, - = enemy team)
Example: +Hydra, -Zeetrax

Alt Search:
Separating names within a player segment by the '|' character will be treated as alts for the same player.
If any alt is found, the player is considered to be found in the match.
Example: Hydr|hxii-firemaw|romeboy (Search matches if any one of the alts are found)

Exact Search:
Each character name may be surrouned by quotation marks must be exact. This functions both with or without explicit server.
Without quotation marks, the name accepts partial matches for player names.
Example: "Hydr", "hxii-firemaw"

Quick Search:
Clicking class icons for players in a stored arena in the match history will search for the player.
Shift-clicking adds it to the existing search.
If control is held, the player will be added as your team only, otherwise if alt is held it must be an enemy.
Right-clicking overrides the explicit team prefix to match the team of the player in the match you clicked.
