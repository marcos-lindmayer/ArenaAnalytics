local _, ArenaAnalytics = ...; -- Addon Namespace
local Export = ArenaAnalytics.Export;

-- Local module aliases
local AAtable = ArenaAnalytics.AAtable;
local TablePool = ArenaAnalytics.TablePool;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------

-- ArenaAnalytics export

-- TODO: Improve the export format
--[[
Semi-colon + New line   (\n) for separating matches.
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
            isSelf          (boolean : 1 / nil)
            isEnemy         (boolean : 1 / 0)
            isFirstDeath    (boolean : 1 / nil)
            Race            (English Token)
            Gender          (String : "F", "M", nil)
            Class           (English Token)
            Spec            (English Token)
            role            ("tank", "healer", "dps")
            sub_role        ("melee", "ranged", "caster")
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
            TeamIndices     (Index string, e.g., "035" = enemy index 3 and 5 are on your team.)
            EnemyIndices    (Index string, e.g., "124" = enemy index 1, 2 and 4 are on your team.)
            FirstDeath      (Enemy index of the first death. 0 = self)
            Duration        (Number)
            outcome         ("W", "L", "D", nil)
--]]

-- ArenaAnalytics_Compact export format:
Export.exportPrefix_Compact = "ArenaAnalyticsExport_Compact:Date,Season,SeasonPlayed,Map,Bracket,MatchType,Duration,Outcome,FirstDeath,Dampening,QueueTime,RatedInfo,Players,Rounds,";

Export.fieldCount_Compact = Export:CountFields(Export.exportPrefix_Compact);

-- Reusable output table
local outputTable = {};

local baseKeys = { "date", "season", "seasonPlayed", "map", "bracket", "matchType", "duration", "outcome", "firstDeath", "dampening", "queueTime" };
local baseDummy = Export:MakeDummyString(#baseKeys);
local function GetBaseString(formattedMatch)
    wipe(outputTable);

    for i,key in ipairs(baseKeys) do
        tinsert(outputTable, formattedMatch[key] or "");
    end

    return table.concat(outputTable, ",");
end

local ratedInfoKeys = { "rating", "ratingDelta", "mmr", "enemyRating", "enemyRatingDelta", "enemyMmr" };
local ratedInfoDummy = Export:MakeDummyString(#ratedInfoKeys);
local function GetRatedInfo(ratedInfo)
    if(type(ratedInfo) ~= "table") then
        return "";
    end

    wipe(outputTable);

    for i,key in ipairs(ratedInfoKeys) do
        tinsert(outputTable, (ratedInfo[key] or ""));
    end

    return table.concat(outputTable, "/");
end


local playerKeys  = { "name", "race", "faction", "team", "gender", "class", "spec", "role", "subRole", "kills", "deaths", "damage", "healing", "wins", "rating", "ratingDelta", "mmr", "mmrDelta" };
local playerDummy = Export:MakeDummyString(#playerKeys);
local function GetPlayerString(player)
    if(type(player) ~= "table") then
        return "";
    end

    wipe(outputTable);

    for i,key in ipairs(playerKeys) do
        tinsert(outputTable, (player[key] or ""));
    end

    return table.concat(outputTable, ":");
end


local roundKeys = { "duration", "outcome", "firstDeath" };
local roundDummy = Export:MakeDummyString(#roundKeys + 6);
local function GetRoundString(round)
    if(type(round) ~= "table") then
        return "";
    end

    wipe(outputTable);

    for _,key in ipairs(roundKeys) do
        tinsert(outputTable, (round[key] or ""));
    end

    -- 3 allies
    for _,ally in ipairs(round.allies) do
        tinsert(outputTable, (ally or ""));
    end

    -- 3 enemies
    for _,enemy in ipairs(round.enemies) do
        tinsert(outputTable, (enemy or ""));
    end

    return table.concat(outputTable, ":");
end

local values = {};
local parts = {};
function Export:ProcessMatch_Compact()
    local formattedMatch = Export.formattedMatch;
    if(not formattedMatch or not formattedMatch.isValid) then
        return;
    end

    -- Base match fields
    tinsert(parts, GetBaseString(formattedMatch));

    -- Rated info
    tinsert(parts, (formattedMatch.isRated and GetRatedInfo(formattedMatch.ratedInfo) or ""));

    -- Add players
    if(type(formattedMatch.players) == "table") then
        for i,player in ipairs(formattedMatch.players) do
            tinsert(values, GetPlayerString(player));
        end
    end
    tinsert(parts, table.concat(values, "/"));

    wipe(values);

    -- For each round
    if(formattedMatch.isShuffle) then
        if(type(formattedMatch.rounds) == "table") then
            for i,round in ipairs(formattedMatch.rounds) do
                tinsert(values, GetRoundString(round));
            end
        end
    end
    tinsert(parts, table.concat(values, "/"));

    wipe(values);

    local matchCompact = table.concat(parts, ",") .. ",";
    wipe(parts);

    Debug:Log("Export match:", #matchCompact, Export:CountFields(matchCompact));
    return matchCompact;
end