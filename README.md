# ArenaAnalytics
Arena log and stats addOn.

*Author: Lingo*

Special thanks to: 
Hydra, Itrulia, and Permok.

*Inspired by ArenaStatsTBC.*
Credit to Gladdy for translations tables.

Open layout with */aa* or */arenaanalytics*
Optional keybind to toggle set in Addons category of the game keybindings menu.


Player Search functionality:
 Player search is designed to function in addition to other filters.
 Most keywords has several shortened aliases. E.g., MM for marksmanship hunters.

 The search field takes in a comma separated list of players.
 A player segment consists of search tokens.
 Tokens are either names, a series of alts or a keyword such as Death Knight.
 
 Explicit Type:
   Some cases may provide ambiguity, where the search will prefer a matched keyword over names by default.
   To resolve this, you can prefix tokens by type:token, where type can be the following:
     class: or c:
     spec: or s:
     race: or r:
     role:
     faction: or f:
     alts: or a:   (Alts is automatically assumed if you include '/' in the token without spaces)
     team: or t:
   
   Example: class:death knight, name:death, spec:frost mage

 Inversed Segment:
   Adding the keyword: 'not' to a player segment will force it to fail if it finds a match.
   
   The following example will fail if there's a player that's both undead and priest:
   Example: not undead priest

 Explicit Team:
   Starting a player segment with (+/-) prefix enforces searching for specific team. (+ = your team, - = enemy team)
   Alternatively adding the words "team" or "enemy" to a player segment. (Last takes priority)

   Following will find matches against an enemy priest named Hydra , where no mage was on your team:
   Example: enemy priest hydra, not team mage

 Alt Search:
   Separating names within a player segment by the '/' character will be treated as alts for the same player.
   If any alt is found, the player is considered to be found in the match.
   
   Example: Hydr|hxii-firemaw|romeboy (Search matches if any one of the alts are found)

 Exact Search:
   Each character name may be surrounded by quotation marks must be exact. This functions both with or without explicit server.
   Without quotation marks, the name accepts partial matches for player names.
   
   Example: "Hydr", "hxii-firemaw", "Hydr/hxii-firemaw/Romeboy"

 Negated Tokens:
   Prefixing a token with '!' will fail for a player if that token is found.

   The following will find matches with enemy priests that are not undead.
   Example: enemy priest !undead

 Quick Search:
   Click a player in the match history to add values to the search.
     LMB to add value to the search
     RMB to add and negate the player segment

     Nomod: Add player name and realm (Options to exclude realm)
     Shift: Add spec (or class when spec is missing)
     Ctrl: Add race
     Alt: Add to existing search in a new player segment (no alt replaces the existing search)