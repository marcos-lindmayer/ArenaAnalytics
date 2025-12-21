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
local exportPrefix = "ArenaAnalyticsExport_CSV:Date,Season,SeasonPlayed,Map,Bracket,MatchType,Duration,Outcome,Dampening,QueueTime,"
                    .. "Rating,RatingDelta,Mmr,EnemyRating,EnemyRatingDelta,EnemyMmr,"
                    .. "Player1Name,Player1Race,Player1Team,Player1isFirstDeath,Player1Gender,Player1Class,Player1Spec,Player1Role,Player1Subrole,Player1Kills,Player1Deaths,Player1Damage,Player1Healing,Player1Wins,Player1Rating,Player1RatingDelta,Player1Mmr,Player1MmrDelta,"
                    .. "Player2Name,Player2Race,Player2Team,Player2isFirstDeath,Player2Gender,Player2Class,Player2Spec,Player2Role,Player2Subrole,Player2Kills,Player2Deaths,Player2Damage,Player2Healing,Player2Wins,Player2Rating,Player2RatingDelta,Player2Mmr,Player2MmrDelta,"
                    .. "Player3Name,Player3Race,Player3Team,Player3isFirstDeath,Player3Gender,Player3Class,Player3Spec,Player3Role,Player3Subrole,Player3Kills,Player3Deaths,Player3Damage,Player3Healing,Player3Wins,Player3Rating,Player3RatingDelta,Player3Mmr,Player3MmrDelta,"
                    .. "Player4Name,Player4Race,Player4Team,Player4isFirstDeath,Player4Gender,Player4Class,Player4Spec,Player4Role,Player4Subrole,Player4Kills,Player4Deaths,Player4Damage,Player4Healing,Player4Wins,Player4Rating,Player4RatingDelta,Player4Mmr,Player4MmrDelta,"
                    .. "Player5Name,Player5Race,Player5Team,Player5isFirstDeath,Player5Gender,Player5Class,Player5Spec,Player5Role,Player5Subrole,Player5Kills,Player5Deaths,Player5Damage,Player5Healing,Player5Wins,Player5Rating,Player5RatingDelta,Player5Mmr,Player5MmrDelta,"
                    .. "Player6Name,Player6Race,Player6Team,Player6isFirstDeath,Player6Gender,Player6Class,Player6Spec,Player6Role,Player6Subrole,Player6Kills,Player6Deaths,Player6Damage,Player6Healing,Player6Wins,Player6Rating,Player6RatingDelta,Player6Mmr,Player6MmrDelta,"
                    .. "Player7Name,Player7Race,Player7Team,Player7isFirstDeath,Player7Gender,Player7Class,Player7Spec,Player7Role,Player7Subrole,Player7Kills,Player7Deaths,Player7Damage,Player7Healing,Player7Wins,Player7Rating,Player7RatingDelta,Player7Mmr,Player7MmrDelta,"
                    .. "Player8Name,Player8Race,Player8Team,Player8isFirstDeath,Player8Gender,Player8Class,Player8Spec,Player8Role,Player8Subrole,Player8Kills,Player8Deaths,Player8Damage,Player8Healing,Player8Wins,Player8Rating,Player8RatingDelta,Player8Mmr,Player8MmrDelta,"
                    .. "Player9Name,Player9Race,Player9Team,Player9isFirstDeath,Player9Gender,Player9Class,Player9Spec,Player9Role,Player9Subrole,Player9Kills,Player9Deaths,Player9Damage,Player9Healing,Player9Wins,Player9Rating,Player9RatingDelta,Player9Mmr,Player9MmrDelta,"
                    .. "Player10Name,Player10Race,Player10Team,Player10isFirstDeath,Player10Gender,Player10Class,Player10Spec,Player10Role,Player10Subrole,Player10Kills,Player10Deaths,Player10Damage,Player10Healing,Player10Wins,Player10Rating,Player10RatingDelta,Player10Mmr,Player10MmrDelta,"
                    .. "Round1Duration,Round1Outcome,Round1FirstDeath,Round1Party1,Round1Party2,Round1Enemy1,Round1Enemy2,Round1Enemy3,"
                    .. "Round2Duration,Round2Outcome,Round2FirstDeath,Round2Party1,Round2Party2,Round2Enemy1,Round2Enemy2,Round2Enemy3,"
                    .. "Round3Duration,Round3Outcome,Round3FirstDeath,Round3Party1,Round3Party2,Round3Enemy1,Round3Enemy2,Round3Enemy3,"
                    .. "Round4Duration,Round4Outcome,Round4FirstDeath,Round4Party1,Round4Party2,Round4Enemy1,Round4Enemy2,Round4Enemy3,"
                    .. "Round5Duration,Round5Outcome,Round5FirstDeath,Round5Party1,Round5Party2,Round5Enemy1,Round5Enemy2,Round5Enemy3,"
                    .. "Round6Duration,Round6Outcome,Round6FirstDeath,Round6Party1,Round6Party2,Round6Enemy1,Round6Enemy2,Round6Enemy3,"

local function GetBaseString(match)
    local outcome = ArenaMatch:GetMatchOutcome(match);
    if(outcome == 0) then
        outcome = "L";
    elseif(outcome == 1) then
        outcome = "W";
    elseif(outcome == 2) then
        outcome = "D";
    else
        outcome = "";
    end

    -- Add match data
    local baseString = (ArenaMatch:GetDate(match) or "") .. ","
    .. (ArenaMatch:GetSeason(match) or "") .. ","
    .. (ArenaMatch:GetBracket(match) or "") .. ","
    .. (ArenaMatch:GetMatchType(match) or "") .. ","
    .. (ArenaMatch:GetMap(match) or "") .. ","
    .. (ArenaMatch:GetDuration(match) or "") .. ","
    .. outcome .. ","
    .. (ArenaMatch:GetPartyRating(match) or "").. ","
    .. (ArenaMatch:GetPartyRatingDelta(match) or "").. ","
    .. (ArenaMatch:GetPartyMMR(match) or "").. ","
    .. (ArenaMatch:GetEnemyRating(match) or "").. ","
    .. (ArenaMatch:GetEnemyRatingDelta(match) or "").. ","
    .. (ArenaMatch:GetEnemyMMR(match) or "").. ","
    .. (ArenaMatch:GetEnemyRating(match) or "").. ","

    return baseString;
end

local function GetRatedInfo(match)
    return "";
end

local genders = { "F", "M" };
local factions = { "A", "H" };

local function GetPlayerString(player, isEnemy, isShuffle)
    local player = ArenaMatch:GetPlayerInfo(player);
    if(not player) then
        return ""; -- TODO: fill dummy player fields
    end

    local team = nil;
    if(ArenaMatch:IsPlayerSelf(player)) then
        team = "self";
    elseif(isEnemy ~= nil and not isShuffle) then
        team = isEnemy and "enemy" or "ally";
    end

    local gender = ArenaMatch:IsPlayerFemale(player);
    gender = gender and genders[gender] or nil;

    local race_id = ArenaMatch:GetPlayerRace(player);

    local faction = Internal:GetRaceFactionIndex(race_id);
    faction = faction and factions[faction] or nil;

    local spec_id = ArenaMatch:GetPlayerSpec(player);
    local class, spec = Internal:GetClassAndSpec(spec_id);

    local role_bitmap = ArenaMatch:GetPlayerRole(player);
    local _,role = Bitmap:GetMainRole(role_bitmap);
    local _,subRole = Bitmap:GetSubRole(role_bitmap);

    local kills, deaths, damage, healing = ArenaMatch:GetPlayerStats(player);

    local wins = nil;
    if(isShuffle) then
        wins = ArenaMatch:GetPlayerVariableStats(player);
    end

    local rating, ratingDelta, mmr, mmrDelta = ArenaMatch:GetPlayerRatedInfo(player);

    local playerCSV = (ArenaMatch:GetPlayerFullName(player) or "") .. ","
        .. (Internal:GetRace(race_id) or "") .. ","
        .. (faction or "") .. ","
        .. (team or "") .. ","
        .. (ArenaMatch:IsPlayerFirstDeath(player) and "Y" or "N") .. ","
        .. (gender or "") .. ","
        .. (class or "") .. ","
        .. (spec or "") .. ","
        .. (role or "") .. ","
        .. (subRole or "") .. ","
        .. (kills or "") .. ","
        .. (deaths or "") .. ","
        .. (damage or "") .. ","
        .. (healing or "") .. ","
        .. (wins or "") .. ","
        .. (rating or "") .. ","
        .. (ratingDelta or "") .. ","
        .. (mmr or "") .. ","
        .. (mmrDelta or "") .. ","

    -- name
    -- race
    -- Team (self, ally, enemy)
    -- isFirstDeath (Combine as base field?)
    -- Gender
    -- Class
    -- Spec
    -- Role
    -- Subroll

    -- Kills
    -- Deaths
    -- Damage
    -- Healing

    -- Wins
    -- Rating
    -- RatingDelta
    -- Mmr
    -- MmrDelta

    return playerCSV;
end

local function GetRoundString(round)
    local team, enemy, death, duration, outcome = ArenaMatch:GetRoundData(round);

    team = team or "";
    enemy = enemy or "";

    local player1, player2, enemy1, enemy2, enemy3 = tonumber(team[1]), tonumber(team[2]), tonumber(enemy[1]), tonumber(enemy[2]), tonumber(enemy[3]);

    player1 = player1 and player1 + 1 or nil;
    player2 = player2 and player2 + 1 or nil;
    enemy1 = enemy1 and enemy1 + 1 or nil;
    enemy2 = enemy2 and enemy2 + 1 or nil;
    enemy3 = enemy3 and enemy3 + 1 or nil;

    local roundString = (duration or "") .. ","
        .. (outcome or "") .. ","
        .. (death or "") .. ","
        .. (player1 or "") .. ","
        .. (player2 or "") .. ","
        .. (enemy1 or "") .. ","
        .. (enemy2 or "") .. ","
        .. (enemy3 or "") .. ","

    return roundString;
end


function Export:ProcessMatch_CSV(index)
    if(not index or index < 0 or index > #ArenaAnalyticsDB) then
        return;
    end

    local match = ArenaAnalyticsDB[index];
    if(not match) then
        return;
    end

    local isShuffle = ArenaMatch:isShuffle(match);

    local matchCSV = exportPrefix .. "\n";

    matchCSV = matchCSV .. GetBaseString(match);

    -- Rated info
    matchCSV = matchCSV .. GetRatedInfo(match);

    -- For each player
    local teams = {"team", "enemyTeam"};
    for _,teamKey in ipairs(teams) do
        local team = match[teamKey];
        local isEnemy = not isShuffle and (teamKey == "enemyTeam") or nil;

        for i=1, 5 do
            local player = team and team[i] or nil;
            matchCSV = matchCSV .. GetPlayerString(player, isEnemy, isShuffle);
        end
    end

    -- For each round
    local rounds = ArenaMatch:GetRounds(match);
    for _,round in ipairs(rounds) do
        local roundString = GetRoundString(round);
        matchCSV = matchCSV .. roundString;
    end


    return matchCSV;
end


-- Returns a CSV-formatted string using ArenaAnalyticsDB info
function Export:combineExportCSV()
    if(not ArenaAnalytics:HasStoredMatches()) then
        Debug:Log("Export: No games to export!");
        return "No games to export!";
    end

    if(ArenaAnalyticsScrollFrame.exportDialogFrame) then
        ArenaAnalyticsScrollFrame.exportDialogFrame:Hide();
    end

    local exportTable = {}
    tinsert(exportTable, exportPrefix);

    Export:addMatchesToExport(exportTable)
end

local playerData = { "name", "race", "class", "spec", "kills", "deaths", "damage", "healing" };

function Export:addMatchesToExport(exportTable, nextIndex)
    Debug:Log("Attempting export.. addMatchesToExport", nextIndex);

    nextIndex = nextIndex or 1;


    local arenasAddedThisFrame = 0;
    for i = nextIndex, #ArenaAnalyticsDB do
        local match = ArenaAnalyticsDB[i];

        local victory = match["won"] ~= nil and (match["won"] and "1" or "0") or "";

        -- Add match data
        local matchCSV = match["date"] .. ","
        .. (match["season"] or "") .. ","
        .. (match["bracket"] or "") .. ","
        .. (match["map"] or "") .. ","
        .. (match["duration"] or "") .. ","
        .. victory .. ","
        .. (match["isRated"] and "1" or "0") .. ","
        .. (match["rating"] or "").. ","
        .. (match["ratingDelta"] or "").. ","
        .. (match["mmr"] or "") .. ","
        .. (match["enemyRating"] or "") .. ","
        .. (match["enemyRatingDelta"] or "").. ","
        .. (match["enemyMmr"] or "") .. ","
        .. (match["firstDeath"] or "") .. ","
        .. (match["player"] or "") .. ","

        -- Add team data 
        local teams = {"team", "enemyTeam"};
        for _,teamKey in ipairs(teams) do
            local team = match[teamKey];

            for _,dataKey in ipairs(playerData) do
                for i=1, 5 do
                    local player = team and team[i] or nil;
                    matchCSV = matchCSV .. (player ~= nil and player[dataKey] or "") .. ",";

                    -- "Player1Name,Player1Race,Player1Team,Player1isFirstDeath,Player1Gender,Player1Class,Player1Spec,Player1Role,Player1Subrole,Player1Kills,Player1Deaths,Player1Damage,Player1Healing,Player1Wins,Player1Rating,Player1RatingDelta,Player1Mmr,Player1MmrDelta,"
                end
            end
        end

        tinsert(exportTable, matchCSV);

        arenasAddedThisFrame = arenasAddedThisFrame + 1;

        if(arenasAddedThisFrame >= 10000 and i < #ArenaAnalyticsDB) then
            C_Timer.After(0, function() Export:addMatchesToExport(exportTable, i + 1) end);
            return;
        end
    end

    Export:FinalizeExportCSV(exportTable);
end

local function formatNumber(num)
    assert(num ~= nil);
    local left,num,right = string.match(num,'^([^%d]*%d)(%d*)(.-)')
    return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

function Export:FinalizeExportCSV(exportTable)
    Debug:Log("Attempting export.. FinalizeExportCSV");

    -- Show export with the new CSV string
    if (ArenaAnalytics:HasStoredMatches()) then
        AAtable:CreateExportDialogFrame();
        ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame:SetText(table.concat(exportTable, "\n"));
	    ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame:HighlightText();

        ArenaAnalyticsScrollFrame.exportDialogFrame.totalText:SetText("Total arenas: " .. formatNumber(#exportTable - 1));
        ArenaAnalyticsScrollFrame.exportDialogFrame.lengthText:SetText("Export length: " .. formatNumber(#ArenaAnalyticsScrollFrame.exportDialogFrame.exportFrame:GetText()));
        ArenaAnalyticsScrollFrame.exportDialogFrame:Show();
    elseif(ArenaAnalyticsScrollFrame.exportDialogFrame) then
        ArenaAnalyticsScrollFrame.exportDialogFrame:Hide();
    end

    exportTable = nil;
    collectgarbage("collect");
    Debug:Log("Garbage Collection forced by Export finalize.");
end