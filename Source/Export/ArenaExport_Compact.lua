local _, ArenaAnalytics = ...; -- Addon Namespace
local Export = ArenaAnalytics.Export;

-- Local module aliases
local API = ArenaAnalytics.API;
local Debug = ArenaAnalytics.Debug;
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local Helpers = ArenaAnalytics.Helpers;
local Bitmap = ArenaAnalytics.Bitmap;

-------------------------------------------------------------------------
-- ArenaAnalytics export

-- Includes trailing comma, and expects ";\n" added at the end of the prefix and every match line.
local exportPrefix = "ArenaAnalyticsExport_Compact:Date,Season,SeasonPlayed,Map,Bracket,MatchType,Duration,Outcome,RatedInfo,Players,Rounds,";

local outcomes = {
    [0]="L",
    [1]="W",
    [2]="D",
};

-------------------------------------------------------------------------
-- Helper functions

-- Generic helper function to join values with separator, handling nils
local function JoinValues(values, separator, includeTrailingNils)
    if not values or #values == 0 then
        return "";
    end

    local result = {};
    local lastNonNilIndex = 0;

    -- Find the last non-nil index if we're not including trailing nils
    if not includeTrailingNils then
        for i = #values, 1, -1 do
            if values[i] ~= nil then
                lastNonNilIndex = i;
                break;
            end
        end
    else
        lastNonNilIndex = #values;
    end

    -- Build the result array
    for i = 1, lastNonNilIndex do
        local value = values[i];
        if value == nil then
            result[i] = "";
        else
            result[i] = tostring(value);
        end
    end

    return table.concat(result, separator);
end


local function GetOutcomeString(match)
    -- Get match outcome as string
    local outcome = ArenaMatch:GetMatchOutcome(match); -- 0=L, 1=W, 2=D
    return outcome and outcomes[outcome] or "";
end


local function ToNumericBool(value, skipFalse)
    if(value == nil or skipFalse and value == false) then
        return nil;
    end

    return value and 1 or 0;
end

-------------------------------------------------------------------------

-- Rating/RatingDelta/Mmr/EnemyRating/EnemyRatingDelta/EnemyMMR
local function MakeFormattedRatedInfo(match)
    if not ArenaMatch:IsRated(match) then
        return "";
    end

    local values = {
        ArenaMatch:GetPartyRating(match),
        ArenaMatch:GetPartyRatingDelta(match),
        ArenaMatch:GetPartyMMR(match),
        ArenaMatch:GetEnemyRating(match),
        ArenaMatch:GetEnemyRatingDelta(match),
        ArenaMatch:GetEnemyMMR(match)
    };

    return JoinValues(values, "/", false);
end

-- FullName:Race:isFemale:Class:Spec:role:sub_role:isEnemy:isSelf:isFirstDeath:Kills:Deaths:Damage:Healing:Wins:Rating:RatingDelta:Mmr:MmrDelta
-- local example = "Zeetrax-Firemaw:NightElf:1:Priest:Disc:Healer:Caster:0:1:0:3:0:13522:90213:3:1610:-10:1850:-23"
local function MakeFormattedPlayer(player)
    if(not player) then
        return "";
    end

    -- Get player info
    local fullName = ArenaMatch:GetPlayerFullName(player);
    local isSelf = ArenaMatch:IsPlayerSelf(player) or fullName == API:GetplayerName();

    local race = ArenaMatch:GetPlayerRace(player);
    local isFemale = ArenaMatch:IsPlayerFemale(player);
    local spec = ArenaMatch:GetPlayerSpec(player);
    local role = ArenaMatch:GetPlayerRole(player);
    local isFirstDeath = ArenaMatch:IsPlayerFirstDeath(player);

    -- Convert race and spec IDs to English tokens
    local raceToken = ArenaAnalytics:GetRaceToken(race); -- TODO: Fix for actual API
    local classToken = ArenaAnalytics:GetClassToken(spec); -- TODO: Fix for actual API
    local specToken = ArenaAnalytics:GetSpecToken(spec); -- TODO: Fix for actual API

    -- Get role information
    local roleMain = Bitmap:GetMainRoleToken(role);
    local roleSub = Bitmap:GetSubRoleToken(role);

    -- Determine if enemy (assuming non-self team members are not enemies)
    local isEnemy = not isSelf and ArenaMatch:IsPlayerEnemy(player) or 0;

    -- Get stats
    local kills, deaths, damage, healing = ArenaMatch:GetPlayerStats(player);
    local wins = ArenaMatch:GetPlayerVariableStats(player);

    -- Get rated info
    local rating, ratingDelta, mmr, mmrDelta = ArenaMatch:GetPlayerRatedInfo(player);

    -- Convert booleans to numbers
    local isFemaleNum = ToNumericBool(isFemale);
    local isSelfNum = isSelf and 1 or nil;
    local isEnemyNum = isEnemy and 1 or 0;
    local isFirstDeathNum = isFirstDeath and 1 or nil;

    local values = {
        fullName,
        raceToken,
        isFemaleNum,
        classToken,
        specToken,
        roleMain,
        roleSub,
        isEnemyNum,
        isSelfNum,
        isFirstDeathNum,
        kills,
        deaths,
        damage,
        healing,
        wins,
        rating,
        ratingDelta,
        mmr,
        mmrDelta,
    };

    return JoinValues(values, ":", false);
end

-- Player1/Player2/Player3/Player4/Player5/Player6/Player7/Player8/Player9/Player10
local function MakeFormattedPlayers(match)
    if not match then
        return "";
    end

    local players = {};

    -- Add team players
    local team = ArenaMatch:GetTeam(match, false);
    if team then
        for _, player in ipairs(team) do
            table.insert(players, MakeFormattedPlayer(player));
        end
    end

    -- Add enemy players
    local enemyTeam = ArenaMatch:GetTeam(match, true);
    if enemyTeam then
        for _, player in ipairs(enemyTeam) do
            table.insert(players, MakeFormattedPlayer(player));
        end
    end

    return JoinValues(players, "/", false);
end

-- Indices based on exported player order of the match. ? replaces number for 
-- TeamIndices:EnemyIndices:FirstDeathIndex:Duration:isWin
-- local example = "035:124:4:97:1"
local function MakeFormattedRound(round)
    if not round then
        return "";
    end

    local team, enemy, firstDeath, duration, outcome = ArenaMatch:GetRoundData(round);

    local values = {
        team or "",
        enemy or "",
        firstDeath,
        duration,
        outcome,
    };

    return JoinValues(values, ":", false);
end

-- Round1/Round2/Round3/Round4/Round5/Round6
local function MakeFormattedRounds(match)
    if not match or not ArenaMatch:IsShuffle(match) then
        return "";
    end

    local rounds = ArenaMatch:GetRounds(match);
    if not rounds then
        return "";
    end

    local formattedRounds = {};
    for _, round in ipairs(rounds) do
        table.insert(formattedRounds, MakeFormattedRound(round));
    end

    return JoinValues(formattedRounds, "/", false);
end

-------------------------------------------------------------------------

function Export:AddMatchToExport(match)
    if(not API:IsExporting() or not match) then
        return "";
    end

    -- Build the complete match export string
    local matchValues = {
        ArenaMatch:GetDate(match) or "",
        ArenaMatch:GetSeason(match) or "",
        ArenaMatch:GetSeasonPlayed(match) or "",
        ArenaMatch:GetMap(match, true) or "",
        ArenaMatch:GetBracket(match) or "",
        ArenaMatch:GetMatchType(match) or "",
        ArenaMatch:GetDuration(match) or "",
        GetOutcomeString(match),
        MakeFormattedRatedInfo(match) or "",
        MakeFormattedPlayers(match) or "",
        MakeFormattedRounds(match) or "",
    };

    return JoinValues(matchValues, ",", true);
end

-------------------------------------------------------------------------

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
    Bracket         ("2s", "3s", "5s", "ss")
    MatchType       ("rated", "skirm", "wg")
    Duration        (Number)
    Outcome         ("W", "L", "D")
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
            isFemale        (boolean : 1 / 0 / nil)
            Class           (English Token)
            Spec            (English Token)
            role            ("tank", "healer", "dps")
            sub_role        ("melee", "ranged", "caster")
            isEnemy         (boolean : 1 / 0)
            isSelf          (boolean : 1 / nil)
            isFirstDeath    (boolean : 1 / nil)
            Kills           (Number/nil)
            Deaths          (Number/nil)
            Damage          (Number/nil)
            Healing         (Number/nil)
            Wins            (Number/nil)
            Rating          (Number/nil)
            RatingDelta     (Number/nil)
            Mmr             (Number/nil)
            MmrDelta        (Number/nil)
    Rounds  List of Slash / separated round structures    [Shuffles only!]
        Round:  (Colon : separated round values)
            TeamIndices     (Index string, e.g., "035" = enemy index 3 and 5 are on your team.)
            EnemyIndices    (Index string, e.g., "124" = enemy index 1, 2 and 4 are on your team.)
            FirstDeath      (Enemy index of the first death. 0 = self)
            Duration        (Number)
            isWin           (boolean : 1 = true, 0=loss, nil=unknown)
--]]