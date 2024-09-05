local _, ArenaAnalytics = ...; -- Addon Namespace
local Import = ArenaAnalytics.Import;

-- Local module aliases

-------------------------------------------------------------------------

local formatPrefix = "isRanked,startTime,endTime,zoneId,duration,teamName,teamColor,"..
    "winnerColor,teamPlayerName1,teamPlayerName2,teamPlayerName3,teamPlayerName4,teamPlayerName5,"..
    "teamPlayerClass1,teamPlayerClass2,teamPlayerClass3,teamPlayerClass4,teamPlayerClass5,"..
    "teamPlayerRace1,teamPlayerRace2,teamPlayerRace3,teamPlayerRace4,teamPlayerRace5,oldTeamRating,"..
    "newTeamRating,diffRating,mmr,enemyOldTeamRating,enemyNewTeamRating,enemyDiffRating,enemyMmr,"..
    "enemyTeamName,enemyPlayerName1,enemyPlayerName2,enemyPlayerName3,enemyPlayerName4,"..
    "enemyPlayerName5,enemyPlayerClass1,enemyPlayerClass2,enemyPlayerClass3,enemyPlayerClass4,"..
    "enemyPlayerClass5,enemyPlayerRace1,enemyPlayerRace2,enemyPlayerRace3,enemyPlayerRace4,"..
    "enemyPlayerRace5,enemyFaction,enemySpec1,enemySpec2,enemySpec3,enemySpec4,enemySpec5,"..
    "teamSpec1,teamSpec2,teamSpec3,teamSpec4,teamSpec5,";

function Import:CheckDataSource_ArenaStatsCata()
    if(not Import.raw or Import.raw == "") then
        return false;
    end

    return formatPrefix == Import.raw:sub(1, #formatPrefix);
end