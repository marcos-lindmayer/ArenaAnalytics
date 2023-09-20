-- Namespace for managing versions, including backwards compatibility and converting data
local _, ArenaAnalytics = ...;
ArenaAnalytics.VersionManager = {};

local VersionManager = ArenaAnalytics.VersionManager;

local function convertFormatedDurationToSeconds(duration)
    ArenaAnalytics:Log("Converting duration: " .. duration);

    return duration;
end

local function computeSeasonWhenMissing(season, date)
    if(season == nil) then

    end

    return season
end

local function updateGroupDataToNewFormat(group, myName, myRealm)
    -- Consider adding comp formatted for filters directly here
    local updatedGroup = {};
    for _, player in ipairs(group) do
        local name = player["name"];

        if(name == myName and name:find("%-") == nil) then
            name = name .. "-" .. myRealm;
        end

        local updatedPlayerTable = {
            ["GUID"] = player["GUID"],
            ["name"] = name,
            ["class"] = player["class"],
            ["spec"] = player["spec"]
            ["race"] = player["race"],
            ["faction"] = ArenaAnalytics.Constants:GetFactionByRace(player["race"]),
            ["killingBlows"] = player["killingBlows"],
            ["deaths"] = player["deaths"],
            ["damageDone"] = player["damageDone"],
            ["healingDone"] = player["healingDone"]
        };
        table.insert(updatedGroup, updatedPlayerTable);
    end
    return group;
end

-- 0.3.0 conversion from ArenaAnalyticsDB per bracket to MatchHistoryDB
function VersionManager:convertArenaAnalyticsDBToMatchHistoryDB()
    local brackets = { "2v2", "3v3", "5v5" }

    if(#MatchHistoryDB > 0) then
        ArenaAnalytics:Log("Non-empty MatchHistoryDB.");
        return;
    end

    local myName, myRealm = UnitFullName("player");
    ForceDebugNilError(realm);

    for _, bracket in ipairs(brackets) do
        ForceDebugNilError(bracket);
        ForceDebugNilError(ArenaAnalyticsDB[bracket]);
        
        for _, arena in ipairs(ArenaAnalyticsDB[bracket]) do
            local updatedArenaData = {
                ["isRanked"] = arena["isRanked"],
                ["unixDate"] = arena["dateInt"],
                ["season"] = computeSeasonWhenMissing(arena["season"], arena["dateInt"]),
                ["map"] = arena["map"], 
                ["bracket"] = bracket,
                ["duration"] = convertFormatedDurationToSeconds(arena["duration"]),
                ["team"] = updateGroupDataToNewFormat(arena["team"], myName, myRealm),
                ["rating"] = arena["rating"], 
                ["ratingDelta"] = arena["ratingDelta"],
                ["mmr"] = arena["mmr"], 
                ["enemyTeam"] = updateGroupDataToNewFormat(arena["enemyTeam"], myName, myRealm),
                ["enemyRating"] = arena["enemyRating"], 
                ["enemyRatingDelta"] = arena["enemyRatingDelta"],
                ["enemyMmr"] = arena["enemyMmr"],
                ["comp"] = arena["comp"],
                ["enemyComp"] = arena["enemyComp"],
                ["won"] = arena["won"],
                ["firstDeath"] = arena["firstDeath"]
            }
            table.insert(MatchHistoryDB, updatedArenaData);
        end
    end

    table.sort(MatchHistoryDB, function (k1,k2)
        if (k1["dateInt"] and k2["dateInt"]) then
            return k1["dateInt"] > k2["dateInt"];
        end
        return k1["dateInt"] ~= nil;
    end)
end