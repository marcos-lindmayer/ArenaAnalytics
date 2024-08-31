-- Namespace for managing versions, including backwards compatibility and converting data
local _, ArenaAnalytics = ...; -- Addon Namespace
local VersionManager = ArenaAnalytics.VersionManager;

-- Local module aliases
local Constants = ArenaAnalytics.Constants;
local Filters = ArenaAnalytics.Filters;
local Import = ArenaAnalytics.Import;
local API = ArenaAnalytics.API;
local Helpers = ArenaAnalytics.Helpers;
local ArenaMatch = ArenaAnalytics.ArenaMatch;
local Internal = ArenaAnalytics.Internal;

-------------------------------------------------------------------------

-- True if data sync was detected with a later version.
VersionManager.newDetectedVersion = false;

-- Compare two version strings. Returns -1 if version is lower, 0 if equal, 1 if higher.
function VersionManager:compareVersions(version, otherVersion)
    otherVersion = otherVersion or ArenaAnalytics:GetVersion();

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


function VersionManager:HasOldData()
    -- Original format of ArenaAnalyticsDB (Outdated as of 0.3.0)
    if(ArenaAnalyticsDB) then
        local oldTotal = (ArenaAnalyticsDB["2v2"] and #ArenaAnalyticsDB["2v2"] or 0) + (ArenaAnalyticsDB["3v3"] and #ArenaAnalyticsDB["3v3"] or 0) + (ArenaAnalyticsDB["5v5"] and #ArenaAnalyticsDB["5v5"] or 0);
        if(oldTotal > 0) then
            return true;
        end
    end

    -- 0.3.0 Match History DB (Outdated as of 0.7.0)
    if(MatchHistoryDB and #MatchHistoryDB > 0) then
        return true;
    end

    return false;
end

-- Returns true if loading should convert data
function VersionManager:OnInit()
    if(not VersionManager:HasOldData()) then
        return;
    end

    -- Force early init, to ensure the internal tables are valid.
    Internal:Initialize();

    ArenaAnalytics:Log("Converting old data...")

    local NewMatchHistory = {};
    NewMatchHistory = VersionManager:convertArenaAnalyticsDBToMatchHistoryDB(ArenaAnalyticsDB, MatchHistoryDB) -- 0.3.0
    ArenaAnalytics:Log("Matches after first conversion: ", #NewMatchHistory);

    NewMatchHistory = VersionManager:renameMatchHistoryDBKeys(NewMatchHistory); -- 0.5.0

    -- Clear old data
    if(ArenaAnalyticsDB) then
        ArenaAnalyticsDB["2v2"] = nil;
        ArenaAnalyticsDB["3v3"] = nil;
        ArenaAnalyticsDB["5v5"] = nil;
        
        for k,v in pairs(ArenaAnalyticsDB) do
            ArenaAnalytics:Log("Version Control: Testing remaining old data after purging ArenaAnalyticsDB: ", k, v and #v);
        end
    end
    MatchHistoryDB = nil;

    NewMatchHistory = VersionManager:ConvertMatchHistoryDBToNewArenaAnalyticsDB(NewMatchHistory); -- 0.7.0

    -- Assign new format
    ArenaAnalyticsDB = NewMatchHistory;

    ArenaAnalytics:ResortGroupsInMatchHistory();
    ArenaAnalytics:RecomputeSessionsForMatchHistory();
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
function VersionManager:convertArenaAnalyticsDBToMatchHistoryDB(OldMatchHistory, NewMatchHistory)
    local NewMatchHistory = NewMatchHistory or {}

    local oldTotal = (OldMatchHistory["2v2"] and #OldMatchHistory["2v2"] or 0) + (OldMatchHistory["3v3"] and #OldMatchHistory["3v3"] or 0) + (OldMatchHistory["5v5"] and #OldMatchHistory["5v5"] or 0);
    if(oldTotal == 0) then
        ArenaAnalytics:Log("No old ArenaAnalyticsDB data found.")
        return NewMatchHistory;
    end

    if(#NewMatchHistory > 0) then
        ArenaAnalytics:Log("Non-empty MatchHistoryDB.");
        return NewMatchHistory;
    end
    

    local brackets = { "2v2", "3v3", "5v5" }
    for _, bracket in ipairs(brackets) do
        if(OldMatchHistory[bracket] ~= nil) then
            for _, arena in ipairs(OldMatchHistory[bracket]) do
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

                ArenaAnalytics:Log("Adding arena from ArenaAnalyticsDB (Old format)", #NewMatchHistory)
                table.insert(NewMatchHistory, updatedArenaData);
                requiresReload = true;
            end
        end
    end

    ArenaAnalytics:Print("Converted data from old database. Old total: ", oldTotal, " New total: ", #NewMatchHistory);

    table.sort(NewMatchHistory, function (k1,k2)
        if (k1["date"] and k2["date"]) then
            return k1["date"] < k2["date"];
        end
    end);

    -- Remove old storage
    return NewMatchHistory;
end

-- 0.5.0 renamed keys
function VersionManager:renameMatchHistoryDBKeys(MatchHistory)
    MatchHistory = MatchHistory or {};

    local function renameKey(table, oldKey, newKey)
        if(table[oldKey] and not table[newKey]) then
            table[newKey] = table[oldKey];
            table[oldKey] = nil;
        end
    end

    for i = 1, #MatchHistory do
		local match = MatchHistory[i];
        
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

    return MatchHistory;
end

function VersionManager:ConvertMatchHistoryDBToNewArenaAnalyticsDB(OldMatchHistory, NewMatchHistory)
    local NewMatchHistory = NewMatchHistory or {};

    if(not OldMatchHistory or #OldMatchHistory == 0) then
        return NewMatchHistory;
    end

    if(NewMatchHistory and #NewMatchHistory > 0) then
        ArenaAnalytics:Log("Version Control: Non-empty ArenaAnalyticsDB.");
        return NewMatchHistory;
    end

    -- Fill race lookup table
    local localizedRaceLookupTable = {}
    for raceID = 1, API.maxRaceID do
        local raceInfo = C_CreatureInfo.GetRaceInfo(raceID)        
        if raceInfo and raceInfo.raceName and raceInfo.clientFileString then
            local addonRaceID = Internal:GetAddonRaceIDByToken(raceInfo.clientFileString) or (1000 + raceID)
            if addonRaceID then
                localizedRaceLookupTable[raceInfo.raceName] = {
                    raceID = raceID,
                    raceToken = raceInfo.clientFileString,
                    addonRaceID = addonRaceID,
                }
            else
                ArenaAnalytics:Log("Error: No Addon Race ID found for:", raceID, raceInfo.raceName, raceInfo.clientFileString);
            end
        end
    end
    
    -- Fill class lookup table
    local localizedClassLookupTable = {}
    for classIndex, addonClassID in pairs(API.classMappingTable) do
        -- Get the localized name and token for the class
        local localizedName, classToken = GetClassInfo(classIndex);
        if(localizedName and classToken) then
            localizedClassLookupTable[localizedName] = {
                classIndex = classIndex,
                classToken = classToken,
                addonSpecID = addonClassID,
            };
        end
    end

    local function ConvertValues(race, class, spec)
        local raceInfo = race and localizedRaceLookupTable[race];
        if(raceInfo and raceInfo.addonRaceID < 1000) then
            race = raceInfo.addonRaceID;
        else
            race = Internal:GetAddonRaceIDByToken(race);
            
            if(not race) then
                ArenaAnalytics:Log("Failed to find raceInfo when converting race:", race, raceInfo and raceInfo.addonRaceID, raceInfo and raceInfo.raceToken);
            end
        end

        local classInfo = class and localizedClassLookupTable[class];
        if(classInfo) then
            class = classInfo.addonSpecID;
        else
            ArenaAnalytics:Log("Failed to find classInfo when converting class:", class);
        end

        local spec_id = Internal:GetSpecFromSpecString(class, spec);
        if(spec_id) then
            spec = spec_id;
        else
            ArenaAnalytics:Log("Failed to find spec_id when converting class:", class, "spec:", spec);
        end

        return race, tonumber(spec) or tonumber(class);
    end

    -- Convert old arenas
    for i=1, #OldMatchHistory do
        local oldArena = OldMatchHistory[i];
        if(oldArena) then 
            local convertedArena = { }

            -- Set values
            ArenaMatch:SetDate(convertedArena, oldArena["date"]);
            ArenaMatch:SetDuration(convertedArena, oldArena["duration"]);
            ArenaMatch:SetMap(convertedArena, oldArena["map"]);
            ArenaMatch:SetBracket(convertedArena, oldArena["bracket"]);
            ArenaMatch:SetMatchType(convertedArena, oldArena["isRated"] and "rated" or "skirmish");

            ArenaMatch:SetPartyRating(convertedArena, oldArena["rating"]);
            ArenaMatch:SetPartyMMR(convertedArena, oldArena["mmr"]);
            ArenaMatch:SetPartyRatingDelta(convertedArena, oldArena["ratingDelta"]);

            ArenaMatch:SetEnemyRating(convertedArena, oldArena["enemyRating"]);
            ArenaMatch:SetEnemyMMR(convertedArena, oldArena["enemyMmr"]);
            ArenaMatch:SetEnemyRatingDelta(convertedArena, oldArena["enemyRatingDelta"]);

            ArenaMatch:SetSeason(convertedArena, oldArena["season"]);
            ArenaMatch:SetSession(convertedArena, oldArena["session"]);

            ArenaMatch:SetVictory(convertedArena, oldArena["won"]);

            -- Add team
            for _,player in ipairs(oldArena["team"]) do
                local kills, deaths, damage, healing = player.kills, player.deaths, player.damage, player.healing;
                local race_id, spec_id = ConvertValues(player.race, player.class, player.spec);
                local role_id = Internal:GetRoleBitmap(spec_id);

                ArenaMatch:AddPlayer(convertedArena, false, player.name, race_id, spec_id, role_id, kills, deaths, damage, healing);
            end

            -- Add enemy team
            for _,player in ipairs(oldArena["enemyTeam"]) do
                local kills, deaths, damage, healing = player.kills, player.deaths, player.damage, player.healing;
                local race_id, spec_id = ConvertValues(player.race, player.class, player.spec);
                local role_id = Internal:GetRoleBitmap(spec_id);

                ArenaMatch:AddPlayer(convertedArena, true, player.name, race_id, spec_id, role_id, kills, deaths, damage, healing);
            end

            ArenaMatch:SetSelf(convertedArena, oldArena["player"]);
            ArenaMatch:SetFirstDeath(convertedArena, oldArena["firstDeath"]);

            -- Comps
            ArenaMatch:UpdateComps(convertedArena);

            tinsert(NewMatchHistory, convertedArena);
        end
    end

    return NewMatchHistory;
end

function VersionManager:FinalizeConversionAttempts()
	ArenaAnalytics.unsavedArenaCount = #ArenaAnalyticsDB;
    
	ArenaAnalytics:ResortGroupsInMatchHistory();
	ArenaAnalytics:RecomputeSessionsForMatchHistory();
    
    Import:tryHide();
    Filters:Refresh();
    ArenaAnalyticsScrollFrame:Hide();
end