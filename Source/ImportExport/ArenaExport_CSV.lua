local _, ArenaAnalytics = ...; -- Addon Namespace
local Export = ArenaAnalytics.Export;

-- Local module aliases
local AAtable = ArenaAnalytics.AAtable;
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local TablePool = ArenaAnalytics.TablePool;
local Internal = ArenaAnalytics.Internal;
local Bitmap = ArenaAnalytics.Bitmap;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------

-- ArenaAnalytics export

-- TODO: Improve the export format
--[[
Semi-colon + New line   (;\n) for separating matches.
Comma                   (,) for separating value types (Date,Bracket,Teams,etc).
Slash                   (/) for separating player entries (Player1/Player2/... etc).
Colon                   (:) for separating specific player values (Zeetrax-Ravencrest|NightElf|91|... etc).

NOTE: Assume any value may be nil, when unknown or non-applicable!

Format: (Comma separated)
    Date            (Number)
    Season          (Number)
    SeasonPlayed    (Number)
    Map             (English Token?)
    Bracket         ("2s", "3s", "5s", "shuffle")
    MatchType       ("rated", "skirm", "wg")
    Duration        (Number)
    Outcome         ("W", "L", "D")
    FirstDeath      (playerName or index?)
    Dampening       (NOT YET IMPLEMENTED)
    QueueTime       (NOT YET IMPLEMENTED)
    RatedInfo       (RatedInfo structure)
    Players         (Team structure)
    Rounds          (List of Round structures)

Structures:
    RatedInfo:  List of Slash / separated rating values   [Rated only!]
        Rating
        RatingDelta
        Mmr
        EnemyRating
        EnemyRatingDelta
        EnemyMMR
    Teams:  List of Slash / separated players
        Player: (Colon : separated values)
            FullName        (name-realm)
            Race            (English Token)
            Faction         ("A", "H", nil)
            Team            (String : "self", "ally", "enemy")
            isFirstDeath    (boolean : 1 / nil)
            Gender          (String : "F", "M", nil)
            Class           (English Token)
            Spec            (English Token)
            Role            ("tank", "healer", "dps")
            Sub_role        ("melee", "ranged", "caster")
            Kills           (Number)
            Deaths          (Number)
            Damage          (Number)
            Healing         (Number)
            Wins            (Number)
            Rating          (Number)
            RatingDelta     (Number)
            Mmr             (Number)
            MmrDelta        (Number)
    Rounds  List of Slash / separated round structures    [Shuffles only!]
        Round:  (Colon : separated round values)
            Duration        (Number)
            Outcome         (String : "W", "L", "D", nil)
            FirstDeath      (Enemy index of the first death. 0 = self)
            TeamsLocked     (35-124)
            TeamIndices     (Index string, e.g., "35" = enemy index 3 and 5 are on your team.)
            EnemyIndices    (Index string, e.g., "124" = enemy index 1, 2 and 4 are on your team.)
--]]

-- ArenaAnalytics_CSV export format:
Export.exportPrefix_CSV = "ArenaAnalyticsExport_CSV:Date,Season,SeasonPlayed,Map,Bracket,MatchType,Duration,Outcome,firstDeath,Dampening,QueueTime,"
                    .. "Rating,RatingDelta,Mmr,EnemyRating,EnemyRatingDelta,EnemyMmr,"
                    .. "Player1Name,Player1Race,Player1Faction,Player1Team,Player1Gender,Player1Class,Player1Spec,Player1Role,Player1Subrole,Player1Kills,Player1Deaths,Player1Damage,Player1Healing,Player1Wins,Player1Rating,Player1RatingDelta,Player1Mmr,Player1MmrDelta,"
                    .. "Player2Name,Player2Race,Player2Faction,Player2Team,Player2Gender,Player2Class,Player2Spec,Player2Role,Player2Subrole,Player2Kills,Player2Deaths,Player2Damage,Player2Healing,Player2Wins,Player2Rating,Player2RatingDelta,Player2Mmr,Player2MmrDelta,"
                    .. "Player3Name,Player3Race,Player3Faction,Player3Team,Player3Gender,Player3Class,Player3Spec,Player3Role,Player3Subrole,Player3Kills,Player3Deaths,Player3Damage,Player3Healing,Player3Wins,Player3Rating,Player3RatingDelta,Player3Mmr,Player3MmrDelta,"
                    .. "Player4Name,Player4Race,Player4Faction,Player4Team,Player4Gender,Player4Class,Player4Spec,Player4Role,Player4Subrole,Player4Kills,Player4Deaths,Player4Damage,Player4Healing,Player4Wins,Player4Rating,Player4RatingDelta,Player4Mmr,Player4MmrDelta,"
                    .. "Player5Name,Player5Race,Player5Faction,Player5Team,Player5Gender,Player5Class,Player5Spec,Player5Role,Player5Subrole,Player5Kills,Player5Deaths,Player5Damage,Player5Healing,Player5Wins,Player5Rating,Player5RatingDelta,Player5Mmr,Player5MmrDelta,"
                    .. "Player6Name,Player6Race,Player6Faction,Player6Team,Player6Gender,Player6Class,Player6Spec,Player6Role,Player6Subrole,Player6Kills,Player6Deaths,Player6Damage,Player6Healing,Player6Wins,Player6Rating,Player6RatingDelta,Player6Mmr,Player6MmrDelta,"
                    .. "Player7Name,Player7Race,Player7Faction,Player7Team,Player7Gender,Player7Class,Player7Spec,Player7Role,Player7Subrole,Player7Kills,Player7Deaths,Player7Damage,Player7Healing,Player7Wins,Player7Rating,Player7RatingDelta,Player7Mmr,Player7MmrDelta,"
                    .. "Player8Name,Player8Race,Player8Faction,Player8Team,Player8Gender,Player8Class,Player8Spec,Player8Role,Player8Subrole,Player8Kills,Player8Deaths,Player8Damage,Player8Healing,Player8Wins,Player8Rating,Player8RatingDelta,Player8Mmr,Player8MmrDelta,"
                    .. "Player9Name,Player9Race,Player9Faction,Player9Team,Player9Gender,Player9Class,Player9Spec,Player9Role,Player9Subrole,Player9Kills,Player9Deaths,Player9Damage,Player9Healing,Player9Wins,Player9Rating,Player9RatingDelta,Player9Mmr,Player9MmrDelta,"
                    .. "Player10Name,Player10Race,Player10Faction,Player10Team,Player10Gender,Player10Class,Player10Spec,Player10Role,Player10Subrole,Player10Kills,Player10Deaths,Player10Damage,Player10Healing,Player10Wins,Player10Rating,Player10RatingDelta,Player10Mmr,Player10MmrDelta,"
                    .. "Round1Duration,Round1Outcome,Round1FirstDeath,Round1Ally1,Round1Ally2,Round1Ally3,Round1Enemy1,Round1Enemy2,Round1Enemy3,"
                    .. "Round2Duration,Round2Outcome,Round2FirstDeath,Round2Ally1,Round2Ally2,Round1Ally3,Round2Enemy1,Round2Enemy2,Round2Enemy3,"
                    .. "Round3Duration,Round3Outcome,Round3FirstDeath,Round3Ally1,Round3Ally2,Round1Ally3,Round3Enemy1,Round3Enemy2,Round3Enemy3,"
                    .. "Round4Duration,Round4Outcome,Round4FirstDeath,Round4Ally1,Round4Ally2,Round1Ally3,Round4Enemy1,Round4Enemy2,Round4Enemy3,"
                    .. "Round5Duration,Round5Outcome,Round5FirstDeath,Round5Ally1,Round5Ally2,Round1Ally3,Round5Enemy1,Round5Enemy2,Round5Enemy3,"
                    .. "Round6Duration,Round6Outcome,Round6FirstDeath,Round6Ally1,Round6Ally2,Round1Ally3,Round6Enemy1,Round6Enemy2,Round6Enemy3,"

Export.fieldCount_CSV = Export:CountFields(Export.exportPrefix_CSV);

local baseKeys = { "date", "season", "seasonPlayed", "map", "bracket", "matchType", "duration", "outcome", "firstDeath", "dampening", "queueTime" };
local baseDummy = Export:MakeDummyString(#baseKeys);
local function GetBaseString(formattedMatch)
    local output = "";

    for i,key in ipairs(baseKeys) do
        output = output .. (formattedMatch[key] or "") .. ",";
    end

    return output;
end

local ratedInfoKeys = { "rating", "ratingDelta", "mmr", "enemyRating", "enemyRatingDelta", "enemyMmr" };
local ratedInfoDummy = Export:MakeDummyString(#ratedInfoKeys);
local function GetRatedInfo(ratedInfo)
    if(type(ratedInfo) ~= "table") then
        return ratedInfoDummy;
    end

    local output = "";

    for i,key in ipairs(ratedInfoKeys) do
        output = output .. (ratedInfo[key] or "") .. ",";
    end

    return output;
end


local playerKeys  = { "name", "race", "faction", "team", "gender", "class", "spec", "role", "subRole", "kills", "deaths", "damage", "healing", "wins", "rating", "ratingDelta", "mmr", "mmrDelta" };
local playerDummy = Export:MakeDummyString(#playerKeys);
local function GetPlayerString(player)
    if(type(player) ~= "table") then
        return playerDummy;
    end

    local output = "";

    for i,key in ipairs(playerKeys) do
        output = output .. (player[key] or "") .. ",";
    end

    return output;
end


local roundKeys = { "duration", "outcome", "firstDeath" };
local roundDummy = Export:MakeDummyString(#roundKeys + 6);
local function GetRoundString(round)
    if(type(round) ~= "table") then
        return roundDummy;
    end

    local output = "";

    for _,key in ipairs(roundKeys) do
        output = output .. (round[key] or "") .. ",";
    end

    -- 3 allies
    for _,ally in ipairs(round.allies) do
        output = output .. (ally or "") .. ",";
    end

    -- 3 enemies
    for _,enemy in ipairs(round.enemies) do
        output = output .. (enemy or "") .. ",";
    end

    return output;
end


function Export:ProcessMatch_CSV()
    local formattedMatch = Export.formattedMatch;
    if(not formattedMatch or not formattedMatch.isValid) then
        return;
    end

    local matchCSV = "";

    matchCSV = matchCSV .. GetBaseString(formattedMatch);

    -- Rated info
    matchCSV = matchCSV .. GetRatedInfo(formattedMatch.ratedInfo);

    -- For each player
    for i=1, 10 do
        local player = type(formattedMatch.players) == "table" and formattedMatch.players[i] or nil;
        matchCSV = matchCSV .. GetPlayerString(player);
    end

    -- For each round
    for i=1, 6 do
        local round = type(formattedMatch.rounds) == "table" and formattedMatch.rounds[i];
        matchCSV = matchCSV .. GetRoundString(round);
    end

    Debug:Log("Export match:", #matchCSV, Export:CountFields(matchCSV));
    return matchCSV;
end