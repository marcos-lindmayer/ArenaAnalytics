-- Namespace for managing versions, including backwards compatibility and converting data
local _, ArenaAnalytics = ...;
ArenaAnalytics.VersionManager = {};

local VersionManager = ArenaAnalytics.VersionManager;

local function convertFormatedDurationToSeconds(inDuration)
    if(tonumber(inDuration)) then
        return inDuration;
    end
    
    if(inDuration ~= nil and inDuration ~= "") then
        -- Sanitize the formatted time string
        inDuration = inDuration:lower();
        inDuration = inDuration:gsub("%s+", "");
        
        local minutes, seconds = 0,0
        
        if(string.find(inDuration, "|")) then
            -- Get minutes before '|' and seconds between ';' and "sec"
            minutes = tonumber(inDuration:match("(.+)|")) or 0;
            seconds = tonumber(inDuration:match(";(.+)sec")) or 0;
        elseif(inDuration:find("min") and inDuration:find("sec")) then
            -- Get minutes before "min" and seconds between "min" and "sec
            minutes = tonumber(inDuration:match("(.*)min")) or 0;
            seconds = inDuration:match("min(.*)sec") or 0;
        elseif(inDuration:find("sec")) then
            -- Get seconds before "sec
            seconds = tonumber(inDuration:match("(.*)sec")) or 0;
        else
            ArenaAnalytics:Print("ERROR: Converting duration failed (:", inDuration, ")")
        end
        
        return 60*minutes + seconds;
    end

    return 0;
end

local function computeSeasonWhenMissing(season, unixDate)
    if(season == nil or season == 0) then
        return ArenaAnalytics:computeSeasonFromMatchDate(unixDate);
    end

    return season;
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
            ["killingBlows"] = tonumber(player["killingBlows"]),
            ["deaths"] = tonumber(player["deaths"]),
            ["damageDone"] = tonumber(player["damageDone"]),
            ["healingDone"] = tonumber(player["healingDone"])
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

    if(ArenaAnalyticsDB == nil) then
        return;
    end

    local myName, myRealm = UnitFullName("player");
    ForceDebugNilError(myRealm);

    local requiresReload = false;

    for _, bracket in ipairs(brackets) do
        if(ArenaAnalyticsDB[bracket] ~= nil) then
            for _, arena in ipairs(ArenaAnalyticsDB[bracket]) do
                local updatedArenaData = {
                    ["isRated"] = arena["isRanked"],
                    ["date"] = arena["dateInt"],
                    ["season"] = computeSeasonWhenMissing(arena["season"], arena["dateInt"]),
                    ["map"] = arena["map"], 
                    ["bracket"] = bracket,
                    ["duration"] = convertFormatedDurationToSeconds(arena["duration"]),
                    ["team"] = updateGroupDataToNewFormat(arena["team"], myName, myRealm),
                    ["rating"] = tonumber(arena["rating"]),
                    ["ratingDelta"] = tonumber(arena["ratingDelta"]),
                    ["mmr"] = tonumber(arena["mmr"]), 
                    ["enemyTeam"] = updateGroupDataToNewFormat(arena["enemyTeam"], myName, myRealm),
                    ["enemyRating"] = tonumber(arena["enemyRating"]), 
                    ["enemyRatingDelta"] = tonumber(arena["enemyRatingDelta"]),
                    ["enemyMmr"] = tonumber(arena["enemyMmr"]),
                    ["comp"] = convertCompToShortFormat(arena["comp"], bracket),
                    ["enemyComp"] = convertCompToShortFormat(arena["enemyComp"], bracket),
                    ["won"] = arena["won"],
                    ["firstDeath"] = arena["firstDeath"]
                }

                table.insert(MatchHistoryDB, updatedArenaData);
                requiresReload = true;
            end
        end
    end

    table.sort(MatchHistoryDB, function (k1,k2)
        if (k1["date"] and k2["date"]) then
            return k1["date"] < k2["date"];
        end
    end);
    
	ArenaAnalytics.unsavedArenaCount = #MatchHistoryDB;

    if(requiresReload and #MatchHistoryDB > 0) then
        ReloadUI();
    end
end