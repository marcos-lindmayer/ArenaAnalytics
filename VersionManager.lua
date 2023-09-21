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
    local updatedGroup = {};
    for _, player in ipairs(group) do
        local name = player["name"];

        if(name == myName and name:find("%-") == nil) then
            name = name .. "-" .. myRealm;
        end

        local updatedPlayerTable = {
            ["GUID"] = player["GUID"] or "",
            ["name"] = name or "",
            ["class"] = player["class"] or "",
            ["spec"] = player["spec"] or "",
            ["race"] = player["race"] or "",
            ["faction"] = ArenaAnalytics.Constants:GetFactionByRace(player["race"]),
            ["killingBlows"] = player["killingBlows"] or "",
            ["deaths"] = player["deaths"] or "",
            ["damageDone"] = player["damageDone"] or "",
            ["healingDone"] = player["healingDone"] or ""
        }
        table.insert(updatedGroup, updatedPlayerTable);
    end
    return group;
end

-- Convert long form string comp to addon spec ID comp
local function convertCompToShortFormat(comp, bracket)
    local size = ArenaAnalytics:getTeamSizeFromBracket(bracket);
    
    local newComp = {}
    for i=1, size do
        local specID = ArenaAnalytics.Constants:getAddonSpecializationID(comp[i]);
        if(specID == nil) then
            return nil;
        end

        table.insert(newComp, specID);
    end

    table.sort(newComp, function(a, b)
        return a < b;
    end);

    return table.concat(newComp, '|');
end

-- 0.3.0 conversion from ArenaAnalyticsDB per bracket to MatchHistoryDB
function VersionManager:convertArenaAnalyticsDBToMatchHistoryDB()
    local brackets = { "2v2", "3v3", "5v5" }

    if(#MatchHistoryDB > 0) then
        ArenaAnalytics:Log("Non-empty MatchHistoryDB.");
        return;
    end

    local myName, myRealm = UnitFullName("player");
    ForceDebugNilError(myRealm);

    for _, bracket in ipairs(brackets) do
        ForceDebugNilError(bracket);
        ForceDebugNilError(ArenaAnalyticsDB[bracket]);
        
        for _, arena in ipairs(ArenaAnalyticsDB[bracket]) do
            local updatedArenaData = {
                ["isRated"] = arena["isRanked"],
                ["date"] = arena["dateInt"],
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
                ["comp"] = convertCompToShortFormat(arena["comp"], bracket),
                ["enemyComp"] = convertCompToShortFormat(arena["enemyComp"], bracket),
                ["won"] = arena["won"],
                ["firstDeath"] = arena["firstDeath"]
            }
            table.insert(MatchHistoryDB, updatedArenaData);
        end
    end

    table.sort(MatchHistoryDB, function (k1,k2)
        if (k1["date"] and k2["date"]) then
            return k1["date"] > k2["date"];
        end
    end);
end