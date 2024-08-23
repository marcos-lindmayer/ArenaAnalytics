-- Namespace for managing versions, including backwards compatibility and converting data
local _, ArenaAnalytics = ...; -- Addon Namespace
local VersionManager = ArenaAnalytics.VersionManager;

-- Local module aliases
local Constants = ArenaAnalytics.Constants;
local Filters = ArenaAnalytics.Filters;
local Import = ArenaAnalytics.Import;

-------------------------------------------------------------------------

-- Old databases (Set to nil after conversion attempts)
ArenaAnalyticsDB = ArenaAnalyticsDB or {}
MatchHistoryDB = MatchHistoryDB or {}

-- True if data sync was detected with a later version.
VersionManager.newDetectedVersion = false;

function ArenaAnalytics:getVersion()
    return GetAddOnMetadata("ArenaAnalytics", "Version") or "-";
end

-- Compare two version strings. Returns -1 if version is lower, 0 if equal, 1 if higher.
function VersionManager:compareVersions(version, otherVersion)
    otherVersion = otherVersion or ArenaAnalytics:getVersion();

    if(version == nil or version == "") then
        return otherVersion and 1 or 0;
    end

    if(otherVersion == nil or otherVersion == "") then
        return -1;
    end

    local function versionToTable(inVersion)
        local outTable = {}
        inVersion = inVersion or 0;
        
        arenasRaw:gsub("([^.]*).", function(c)
            table.insert(outTable, c)
        end);

        return outTable;
    end

    if(version ~= otherVersion) then
        local v1table = versionToTable(version);
        local v2table = versionToTable(otherVersion);
        
        local length = max(#v1table, #v2table);
        for i=1, length do
            local v1 = tonumber(v1table[i]) or 0;
            local v2 = tonumber(v2table[i]) or 0;
            
            if(v1 ~= v2) then
                return (v1 < v2 and -1 or 1);
            end
        end
    end

    return 0;
end

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
            ArenaAnalytics:Print("ERROR: Converting duration failed (:", inDuration, ")");
        end
        
        if(minutes and seconds) then
            return 60*minutes + seconds;
        else
            return seconds or 0;
        end
    end

    return 0;
end

local function computeSeasonWhenMissing(season, unixDate)
    if(season == nil or season == 0) then
        return ArenaAnalytics:computeSeasonFromMatchDate(unixDate);
    end

    return season;
end

-- v0.3.0 -> 0.5.0
local function updateGroupDataToNewFormat(group)
    local updatedGroup = {};
    for _, player in ipairs(group) do
        local class = (player["class"] and #player["class"] > 2) and player["class"] or nil;
        local spec = (player["spec"] and #player["spec"] > 2) and player["spec"] or nil;

        local updatedPlayerTable = {
            ["GUID"] = player["GUID"] or "",
            ["name"] = player["name"] or "",
            ["class"] = class,
            ["spec"] = spec,
            ["race"] = player["race"],
            ["faction"] = Constants:GetFactionByRace(player["race"]),
            ["killingBlows"] = tonumber(player["killingBlows"]),
            ["deaths"] = tonumber(player["deaths"]),
            ["damageDone"] = tonumber(player["damageDone"]),
            ["healingDone"] = tonumber(player["healingDone"])
        }
        table.insert(updatedGroup, updatedPlayerTable);
    end
    return updatedGroup;
end

-- Convert long form string comp to addon spec ID comp
local function convertCompToShortFormat(comp, bracket)
    local size = ArenaAnalytics:getTeamSizeFromBracket(bracket);
    
    local newComp = {}
    for i=1, size do
        local specKeyString = comp[i];
        if(specKeyString == nil) then
            return nil;
        end

        local class, spec = specKeyString:match("([^|]+)|(.+)");
        local specID = Constants:getAddonSpecializationID(class, spec, true);
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

local function getFullFirstDeathName(firstDeathName, team, enemyTeam)
    if(firstDeathName == nil or #firstDeathName < 3) then
        return nil;
    end

    for _,player in ipairs(team) do
        local name = player and player["name"] or nil;
        if(name and name:find(firstDeathName)) then
            return name;
        end
    end

    for _,player in ipairs(enemyTeam) do
        local name = player and player["name"] or nil;
        if(name and name:find(firstDeathName)) then
            return name;
        end
    end

    ArenaAnalytics:Log("getFullDeathName failed to find matching player name.", firstDeathName);
    return nil;
end

-- 0.3.0 conversion from ArenaAnalyticsDB per bracket to MatchHistoryDB
function VersionManager:convertArenaAnalyticsDBToMatchHistoryDB()
    MatchHistoryDB = MatchHistoryDB or { }

    if(not ArenaAnalyticsDB or #ArenaAnalyticsDB == 0) then
        ArenaAnalyticsDB = nil;
        return;
    end

    if(MatchHistoryDB and #MatchHistoryDB > 0) then
        ArenaAnalytics:Log("Non-empty MatchHistoryDB.");
        ArenaAnalyticsDB = nil;
        return;
    end
    
    local oldTotal = (ArenaAnalyticsDB["2v2"] and #ArenaAnalyticsDB["2v2"] or 0) + (ArenaAnalyticsDB["3v3"] and #ArenaAnalyticsDB["3v3"] or 0) + (ArenaAnalyticsDB["5v5"] and #ArenaAnalyticsDB["5v5"] or 0);
    if(oldTotal == 0) then
        return;
    end

    local brackets = { "2v2", "3v3", "5v5" }
    for _, bracket in ipairs(brackets) do
        if(ArenaAnalyticsDB[bracket] ~= nil) then
            for _, arena in ipairs(ArenaAnalyticsDB[bracket]) do
                local team = updateGroupDataToNewFormat(arena["team"]);
                local enemyTeam = updateGroupDataToNewFormat(arena["enemyTeam"]);

                local updatedArenaData = {
                    ["isRated"] = arena["isRanked"],
                    ["date"] = arena["dateInt"],
                    ["season"] = computeSeasonWhenMissing(arena["season"], arena["dateInt"]),
                    ["map"] = arena["map"], 
                    ["bracket"] = bracket,
                    ["duration"] = convertFormatedDurationToSeconds(tonumber(arena["duration"]) or 0),
                    ["team"] = team,
                    ["rating"] = tonumber(arena["rating"]),
                    ["ratingDelta"] = tonumber(arena["ratingDelta"]),
                    ["mmr"] = tonumber(arena["mmr"]), 
                    ["enemyTeam"] = enemyTeam,
                    ["enemyRating"] = tonumber(arena["enemyRating"]), 
                    ["enemyRatingDelta"] = tonumber(arena["enemyRatingDelta"]),
                    ["enemyMmr"] = tonumber(arena["enemyMmr"]),
                    ["comp"] = convertCompToShortFormat(arena["comp"], bracket),
                    ["enemyComp"] = convertCompToShortFormat(arena["enemyComp"], bracket),
                    ["won"] = arena["won"],
                    ["firstDeath"] = getFullFirstDeathName(arena["firstDeath"], team, enemyTeam)
                }

                table.insert(MatchHistoryDB, updatedArenaData);
                requiresReload = true;
            end
        end
    end

    ArenaAnalytics:Print("Converted data from old database. Old total: ", oldTotal, " New total: ", #MatchHistoryDB);

    table.sort(MatchHistoryDB, function (k1,k2)
        if (k1["date"] and k2["date"]) then
            return k1["date"] < k2["date"];
        end
    end);

    -- Remove old storage
    ArenaAnalyticsDB = nil;
end

-- 0.5.0 renamed keys
function VersionManager:renameMatchHistoryDBKeys()
    local function renameKey(table, oldKey, newKey)
        if(table[oldKey] and not table[newKey]) then
            table[newKey] = table[oldKey];
            table[oldKey] = nil;
        end
    end

    for i = 1, #MatchHistoryDB do
		local match = MatchHistoryDB[i];
        
        local teams = {"team", "enemyTeam"}

        for _,team in ipairs(teams) do
            for i = 1, #match[team] do
                local player = match[team][i];

                -- Rename keys:
                renameKey(player, "damageDone", "damage");
                renameKey(player, "healingDone", "healing");
                renameKey(player, "killingBlows", "kills");
            end    
        end
	end
end

function VersionManager:ConvertMatchHistoryDBToArenaAnalyticsMatchHistoryDB()
    if(true) then
        return; -- Function is not ready yet!
    end

    ArenaAnalyticsMatchHistoryDB = ArenaAnalyticsMatchHistoryDB or {};

    if(not MatchHistoryDB or #MatchHistoryDB == 0) then
        ArenaAnalytics:Log("Clearing supposedly empty MatchHistoryDB.");
        MatchHistoryDB = nil;
        return;
    end

    if(ArenaAnalyticsMatchHistoryDB and #ArenaAnalyticsMatchHistoryDB > 0) then
        ArenaAnalytics:Log("Version Control: Non-empty ArenaAnalyticsMatchHistoryDB.");
        MatchHistoryDB = nil;
        return;
    end

    local function ConvertNumber(number, allowZero, allowNegative)
        number = tonumber(number);
        if not number or (not allowZero and number == 0) or (not allowNegative and number < 0) then
            return nil;
        end
        return number;
    end

    -- Convert old arenas
    for i=1, #MatchHistoryDB do
        local oldArena = MatchHistoryDB[i];
        if(oldArena) then 
            local convertedArena = { }

            -- Set values
            ArenaMatch:SetDate(convertedArena, oldArena["date"]);
            ArenaMatch:SetDuration(convertedArena, oldArena["duration"]);
            ArenaMatch:SetMap(convertedArena, oldArena["map"]);
            ArenaMatch:SetBracket(convertedArena, oldArena["bracket"]);
            ArenaMatch:SetMatchType(convertedArena, oldArena["isRated"] and "rated" or "skirmish");
            
            ArenaMatch:SetPartyRating(match, oldArena["rating"]);
            ArenaMatch:SetPartyMMR(match, oldArena["mmr"]);
            ArenaMatch:SetPartyRatingDelta(match, oldArena["ratingDelta"]);
            
            ArenaMatch:SetEnemyRating(match, oldArena["enemyRating"]);
            ArenaMatch:SetEnemyMMR(match, oldArena["enemyMmr"]);
            ArenaMatch:SetEnemyRatingDelta(match, oldArena["enemyRatingDelta"]);
            
            ArenaMatch:SetSeason(match, oldArena["season"]);
            ArenaMatch:SetSession(match, oldArena["session"]);

            
            ArenaMatch:SetVictory(match, oldArena["won"]);
            ArenaMatch:SetSelf(match, oldArena["player"]);
            ArenaMatch:SetFirstDeath(match, oldArena["firstDeath"]);

            -- Add team

            -- Add enemy team

            -- Update comp

            -- Update enemy comp

        end
    end
end

function VersionManager:FinalizeConversionAttempts()
	ArenaAnalytics.unsavedArenaCount = #MatchHistoryDB;
    
	ArenaAnalytics:ResortGroupsInMatchHistory();
	ArenaAnalytics:RecomputeSessionsForMatchHistory();
    
    Import:tryHide();
    Filters:Refresh();
    ArenaAnalyticsScrollFrame:Hide();
end