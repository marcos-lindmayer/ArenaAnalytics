local _, ArenaAnalytics = ...; -- Addon Namespace
local Export = ArenaAnalytics.Export;

-- Local module aliases
local AAtable = ArenaAnalytics.AAtable;
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
            isWin           (boolean : 1 = true, 0=loss, nil=unknown)
--]]

-- Includes trailing comma, and expects ";\n" added at the end of the prefix and every match line.
local exportPrefix = "ArenaAnalyticsExport_Compact:Date,Season,SeasonPlayed,Map,Bracket,MatchType,Duration,Outcome,Dampening,QueueTime,RatedInfo,Players,Rounds,";

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

function Export:addMatchesToExport(exportTable, nextIndex)
    Debug:Log("Attempting export.. addMatchesToExport", nextIndex);

    nextIndex = nextIndex or 1;

    local playerData = {"name", "race", "class", "spec", "kills", "deaths", "damage", "healing"};

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
                    if(player ~= nil) then
                        matchCSV = matchCSV .. (player[dataKey] or "");
                    end

                    matchCSV = matchCSV .. ",";
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