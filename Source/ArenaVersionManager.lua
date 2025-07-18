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
local Localization = ArenaAnalytics.Localization;
local Sessions = ArenaAnalytics.Sessions;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------

VersionManager.disabled = true;

-- True if data sync was detected with a later version.
VersionManager.newDetectedVersion = false;
VersionManager.latestFormatVersion = 4;

-- TODO: Fix & Validate this function
-- Compare two version strings. Returns -1 if version is lower, 0 if equal, 1 if higher.
function VersionManager:compareVersions(version, otherVersion)
    otherVersion = otherVersion or API:GetAddonVersion();

    if(version == nil or version == "") then
        return otherVersion and 1 or 0;
    end

    if(otherVersion == nil or otherVersion == "") then
        return -1;
    end

    local function versionToTable(inVersion)
        local outTable = {}
        inVersion = inVersion or 0;

        inVersion:gsub("([^.]*).", function(c)
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

-- Removed from SavedVariables. Avoid affecting global variables of other addons.
local MatchHistoryDB = nil;
local ArenaAnalyticsRealmsDB = nil;

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
    if(VersionManager.disabled) then
        return;
    end

    ArenaAnalyticsDB.formatVersion = ArenaAnalyticsDB.formatVersion or 0;
    if(ArenaAnalyticsDB.formatVersion >= VersionManager.latestFormatVersion) then
        return;
    end

    if(VersionManager:HasOldData() and #ArenaAnalyticsDB == 0) then
        -- Force early init, to ensure the internal tables are valid.
        Internal:Initialize();

        Debug:Log("Converting old data...")

        VersionManager:convertArenaAnalyticsDBToMatchHistoryDB() -- 0.3.0
        VersionManager:renameMatchHistoryDBKeys(); -- 0.5.0

        -- Clear old data
        if(ArenaAnalyticsDB) then
            ArenaAnalyticsDB["2v2"] = nil;
            ArenaAnalyticsDB["3v3"] = nil;
            ArenaAnalyticsDB["5v5"] = nil;
        end

        -- Assign new format
        VersionManager:ConvertMatchHistoryDBToNewArenaAnalyticsDB(); -- 0.7.0

        MatchHistoryDB = nil;
    end

    -- Reverts and reset index based name and realm (To improve order and streamline formatting across version)
    if(ArenaAnalyticsDB.formatVersion == 0) then
        VersionManager:RevertIndexBasedNameAndRealm();
    end

    -- Update round delimiter and compress player to compact string
    if(ArenaAnalyticsDB.formatVersion == 1) then
        VersionManager:ConvertRoundAndPlayerFormat();
    end

    if(ArenaAnalyticsDB.formatVersion == 2) then
        for i,match in ipairs(ArenaAnalyticsDB) do
            ArenaMatch:AddWinsToRoundData(match);
        end

        ArenaAnalyticsDB.formatVersion = 3;
    end

    if(ArenaAnalyticsDB.formatVersion == 3) then
        for i,match in ipairs(ArenaAnalyticsDB) do
            ArenaMatch:UpdateComps(match);
        end

        ArenaAnalyticsDB.formatVersion = 4;
    end

    VersionManager:FinalizeConversionAttempts();

    ArenaAnalyticsDB.formatVersion = VersionManager.latestFormatVersion;
end

local function convertFormatedDurationToSeconds(inDuration)
    if(not inDuration) then
        return 0;
    end

    if(type(inDuration) == "number") then
        return tonumber(inDuration);
    end

    if(inDuration and inDuration ~= "") then
        -- Sanitize the formatted time string
        inDuration = inDuration:lower();
        inDuration = inDuration:gsub("%s+", "");

        local minutes, seconds = 0,0;

        if(inDuration:find("|", 1, true)) then
            -- Get minutes before '|' and seconds between ';' and "sec"
            minutes = tonumber(inDuration:match("(.+)|")) or 0;
            seconds = tonumber(inDuration:match(";(.+)sec")) or 0;
        elseif(inDuration:find("min", 1, true) and inDuration:find("sec", 1, true)) then
            -- Get minutes before "min" and seconds between "min" and "sec
            minutes = tonumber(inDuration:match("(.*)min")) or 0;
            seconds = inDuration:match("min(.*)sec") or 0;
        elseif(inDuration:find("sec", 1, true)) then
            -- Get seconds before "sec
            seconds = tonumber(inDuration:match("(.*)sec")) or 0;
        else
            Debug:LogError("Converting duration failed (:", inDuration, ")");
        end

        return 60*minutes + seconds;
    end

    return 0;
end

local function SanitizeSeason(season, unixDate)
    if(season == nil or season == 0) then
        return nil;
    end

    return season;
end

local raceToFaction = {
    -- Horde Races
    ["Orc"] = "Horde",
    ["Undead"] = "Horde",
    ["Tauren"] = "Horde",
    ["Troll"] = "Horde",
    ["Blood Elf"] = "Horde",
    ["Goblin"] = "Horde",
    ["Nightborne"] = "Horde",
    ["Highmountain Tauren"] = "Horde",
    ["Mag'har Orc"] = "Horde",
    ["Vulpera"] = "Horde",
    ["Zandalari Troll"] = "Horde",

    -- Alliance Races
    ["Human"] = "Alliance",
    ["Dwarf"] = "Alliance",
    ["Night Elf"] = "Alliance",
    ["Gnome"] = "Alliance",
    ["Draenei"] = "Alliance",
    ["Worgen"] = "Alliance",
    ["Void Elf"] = "Alliance",
    ["Lightforged Draenei"] = "Alliance",
    ["Dark Iron Dwarf"] = "Alliance",
    ["Kul Tiran"] = "Alliance",
    ["Mechagnome"] = "Alliance",

    -- Neutral Races
    ["Pandaren"] = "Neutral",
    ["Dracthyr"] = "Neutral"
};

local function getFactionByRace(race)
    return race and raceToFaction[race] or nil;
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
            ["faction"] = getFactionByRace(player["race"]),
            ["killingBlows"] = tonumber(player["killingBlows"]),
            ["deaths"] = tonumber(player["deaths"]),
            ["damageDone"] = tonumber(player["damageDone"]),
            ["healingDone"] = tonumber(player["healingDone"])
        }
        table.insert(updatedGroup, updatedPlayerTable);
    end
    return updatedGroup;
end

 -- Addon specific spec IDs { ID, "class|spec", "class", "spec", priority value } (ID must never change to preserve data validity, priority is a runtime check)
local addonSpecializationIDs = {
    -- Druid
    ["Druid"] = 0,
    ["Druid|Restoration"] = 1,
    ["Druid|Feral"] = 2,
    ["Druid|Balance"] = 3,

    -- Paladin
    ["Paladin"] = 10,
    ["Paladin|Holy"] = 11,
    ["Paladin|Protection"] = 12,
    ["Paladin|Preg"] = 13,
    ["Paladin|Retribution"] = 14,

    -- Shaman
    ["Shaman"] = 20,
    ["Shaman|Restoration"] = 21,
    ["Shaman|Elemental"] = 22,
    ["Shaman|Enhancement"] = 23,

    -- Death Knight
    ["Death Knight"] = 30,
    ["Death Knight|Unholy"] = 31,
    ["Death Knight|Frost"] = 32,
    ["Death Knight|Blood"] = 33,

    -- Hunter
    ["Hunter"] = 40,
    ["Hunter|Beast Mastery"] = 41,
    ["Hunter|Marksmanship"] = 42,
    ["Hunter|Survival"] = 43,

    -- Mage
    ["Mage"] = 50,
    ["Mage|Frost"] = 51,
    ["Mage|Fire"] = 52,
    ["Mage|Arcane"] = 53,

    -- Rogue
    ["Rogue"] = 60,
    ["Rogue|Subtlety"] = 61,
    ["Rogue|Assassination"] = 62,
    ["Rogue|Combat"] = 63,
    ["Rogue|Outlaw"] = 64,

    -- Warlock
    ["Warlock"] = 70,
    ["Warlock|Affliction"] = 71,
    ["Warlock|Destruction"] = 72,
    ["Warlock|Demonology"] = 73,

    -- Warrior
    ["Warrior"] = 80,
    ["Warrior|Protection"] = 81,
    ["Warrior|Arms"] = 82,
    ["Warrior|Fury"] = 83,

    -- Priest
    ["Priest"] = 90,
    ["Priest|Discipline"] = 91,
    ["Priest|Holy"] = 92,
    ["Priest|Shadow"] = 93,
};

local function getAddonSpecializationID(class, spec, forceExactSpec)
    if(class == nil) then 
        return nil;
    end

    if(forceExactSpec and spec == nil) then
        return nil;
    end

    local specKey = spec and (class .. "|" .. spec) or class;
    return tonumber(addonSpecializationIDs[specKey]);
end

-- Convert long form string comp to addon spec ID comp
local function convertCompToShortFormat(comp, bracketKey)
    local size = ArenaAnalytics:getTeamSizeFromBracket(bracketKey);
    if(not size) then
        return nil;
    end

    local newComp = {}
    for i=1, size do
        local specKeyString = comp[i];
        if(specKeyString == nil) then
            return nil;
        end

        local class, spec = specKeyString:match("([^|]+)|(.+)");
        local specID = getAddonSpecializationID(class, spec, true);
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
    if(not firstDeathName or #firstDeathName < 3) then
        return nil;
    end

    for _,player in ipairs(team) do
        local name = player and player["name"] or nil;
        if(name and name:find(firstDeathName, 1, true)) then
            return name;
        end
    end

    for _,player in ipairs(enemyTeam) do
        local name = player and player["name"] or nil;
        if(name and name:find(firstDeathName, 1, true)) then
            return name;
        end
    end

    Debug:Log("getFullDeathName failed to find matching player name.", firstDeathName);
    return nil;
end

-- 0.3.0 conversion from ArenaAnalyticsDB per bracket to MatchHistoryDB
function VersionManager:convertArenaAnalyticsDBToMatchHistoryDB()
    MatchHistoryDB = MatchHistoryDB or {}

    local oldTotal = (ArenaAnalyticsDB["2v2"] and #ArenaAnalyticsDB["2v2"] or 0) + (ArenaAnalyticsDB["3v3"] and #ArenaAnalyticsDB["3v3"] or 0) + (ArenaAnalyticsDB["5v5"] and #ArenaAnalyticsDB["5v5"] or 0);
    if(oldTotal == 0) then
        Debug:Log("No old ArenaAnalyticsDB data found.")
        return;
    end

    if(#MatchHistoryDB > 0) then
        Debug:Log("Non-empty MatchHistoryDB.");
        return;
    end

    local brackets = { "2v2", "3v3", "5v5" }
    for _, bracketKey in ipairs(brackets) do
        if(type(ArenaAnalyticsDB[bracketKey]) == "table") then
            for _, arena in ipairs(ArenaAnalyticsDB[bracketKey]) do
                local team = updateGroupDataToNewFormat(arena["team"]);
                local enemyTeam = updateGroupDataToNewFormat(arena["enemyTeam"]);

                local updatedArenaData = {
                    ["isRated"] = arena["isRanked"],
                    ["date"] = arena["dateInt"],
                    ["season"] = SanitizeSeason(arena["season"], arena["dateInt"]),
                    ["map"] = arena["map"], 
                    ["bracket"] = bracketKey,
                    ["duration"] = convertFormatedDurationToSeconds(arena["duration"]) or 0,
                    ["team"] = team,
                    ["rating"] = tonumber(arena["rating"]),
                    ["ratingDelta"] = tonumber(arena["ratingDelta"]),
                    ["mmr"] = tonumber(arena["mmr"]), 
                    ["enemyTeam"] = enemyTeam,
                    ["enemyRating"] = tonumber(arena["enemyRating"]), 
                    ["enemyRatingDelta"] = tonumber(arena["enemyRatingDelta"]),
                    ["enemyMmr"] = tonumber(arena["enemyMmr"]),
                    ["comp"] = convertCompToShortFormat(arena["comp"], bracketKey),
                    ["enemyComp"] = convertCompToShortFormat(arena["enemyComp"], bracketKey),
                    ["won"] = arena["won"],
                    ["firstDeath"] = getFullFirstDeathName(arena["firstDeath"], team, enemyTeam)
                }

                Debug:Log("Adding arena from ArenaAnalyticsDB (Old format)", #MatchHistoryDB)
                table.insert(MatchHistoryDB, updatedArenaData);
            end
        end
    end

    ArenaAnalytics:PrintSystem("Converted data from old database. Old total: ", oldTotal, " New total: ", #MatchHistoryDB);

    table.sort(MatchHistoryDB, function(k1,k2)
        if (k1["date"] and k2["date"]) then
            return k1["date"] < k2["date"];
        end
        return k1["date"] ~= nil;
    end);
end

-- 0.5.0 renamed keys
function VersionManager:renameMatchHistoryDBKeys()
    MatchHistoryDB = MatchHistoryDB or {};

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

function VersionManager:ConvertMatchHistoryDBToNewArenaAnalyticsDB()
    if(not MatchHistoryDB or #MatchHistoryDB == 0) then
        return;
    end

    if(ArenaAnalyticsDB and #ArenaAnalyticsDB > 0) then
        Debug:Log("Version Control: Non-empty ArenaAnalyticsDB.");
        return;
    end

    ArenaAnalyticsDB = {};
    ArenaAnalytics:InitializeArenaAnalyticsDB();

    local function ConvertValues(race, class, spec)
        local race_id = Localization:GetRaceID(race);
        if(race_id) then
            race = race_id;
        else
            Debug:Log("Failed to find race_id when converting race:", race);
        end

        local class_id = Localization:GetClassID(class);
        if(class_id) then
            class = class_id;
        else
            Debug:Log("Failed to find class_id when converting class:", class);
        end

        local spec_id = Internal:GetSpecFromSpecString(class, spec);
        if(spec_id) then
            spec = spec_id;
        else
            Debug:Log("Failed to find spec_id when converting class:", class, "spec:", spec);
        end

        return race, tonumber(spec) or tonumber(class);
    end

    local selfNames = {}

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
            ArenaMatch:SetMatchType(convertedArena, (not oldArena["isRated"] or oldArena["rating"] == "SKIRMISH") and "skirmish" or "rated");

            ArenaMatch:SetPartyRating(convertedArena, oldArena["rating"]);
            ArenaMatch:SetPartyMMR(convertedArena, oldArena["mmr"]);
            ArenaMatch:SetPartyRatingDelta(convertedArena, oldArena["ratingDelta"]);

            ArenaMatch:SetEnemyRating(convertedArena, oldArena["enemyRating"]);
            ArenaMatch:SetEnemyMMR(convertedArena, oldArena["enemyMmr"]);
            ArenaMatch:SetEnemyRatingDelta(convertedArena, oldArena["enemyRatingDelta"]);

            ArenaMatch:SetSeason(convertedArena, oldArena["season"]);
            ArenaMatch:SetSession(convertedArena, oldArena["session"]);

            ArenaMatch:SetMatchOutcome(convertedArena, oldArena["won"]);

            local function ConvertPlayerValues(player)
                local race_id, spec_id = ConvertValues(player.race, player.class, player.spec);
                local role_id = API:GetRoleBitmap(spec_id);

                -- Update for new format values
                player.spec = spec_id;
                player.race = race_id;
                player.role = role_id;
                player.isEnemy = false;

                if(player.name) then
                    if(player.name == oldArena.player) then
                        player.isSelf = true;
                    end

                    if(player.name == oldArena.isFirstDeath) then
                        player.isFirstDeath = true;
                    end
                end
            end

            -- Add team
            for _,player in ipairs(oldArena["team"]) do
                ConvertPlayerValues(player);
                player.isEnemy = false;
                ArenaMatch:AddPlayer(convertedArena, player);
            end

            -- Add enemy team
            for _,player in ipairs(oldArena["enemyTeam"]) do
                ConvertPlayerValues(player);
                player.isEnemy = true;
                ArenaMatch:AddPlayer(convertedArena, player);
            end

            if(oldArena.player) then
                selfNames[oldArena.player] = true;
            end

            -- Comps
            ArenaMatch:UpdateComps(convertedArena);

            tinsert(ArenaAnalyticsDB, convertedArena);
        end
    end

    local myName = Helpers:GetPlayerName();
    if(myName) then
        selfNames[myName] = true;
    else
        Debug:Log("Failed to get local player name. Versioning called too early.");
    end

    -- Attempt retroactively assigning player names
    for i,match in ipairs(ArenaAnalyticsDB) do
        if(match and not ArenaMatch:HasSelf(match)) then
            for name,_ in pairs(selfNames) do
                local result = ArenaMatch:SetSelf(match, name);
                if(result) then
                    break;
                end
            end
        end
    end
end

-- Used in VersionManager:RevertIndexBasedNameAndRealm() and VersionManager:ConvertRoundAndPlayerFormat()
local oldPlayerKeys = {
    name = 0,
    realm = -1,
    is_self = -2,
    is_first_death = -3,
    race = -4,
    spec_id = -5,
    role = -6,
    deaths = -7,
    kills = -8,
    healing = -9,
    damage = -10,
    wins = -11,
    rating = -12,
    ratingDelta = -13,
    mmr = -14,
    mmrDelta = -15,
};

function VersionManager:RevertIndexBasedNameAndRealm()
    if(ArenaAnalyticsDB.formatVersion ~= 0) then
        return;
    end

    -- Confirm that there are only one realms DB with data at a time!
    if(#ArenaAnalyticsDB.realms > 1) then
        assert(not ArenaAnalyticsRealmsDB or #ArenaAnalyticsRealmsDB == 0);
        assert(not ArenaAnalyticsDB.Realms or #ArenaAnalyticsDB.Realms == 0);
    elseif(ArenaAnalyticsRealmsDB and #ArenaAnalyticsRealmsDB > 0) then
        assert(not ArenaAnalyticsDB.Realms or #ArenaAnalyticsDB.Realms == 0);
        assert(#ArenaAnalyticsDB.realms <= 1);
    elseif(ArenaAnalyticsDB.Realms and #ArenaAnalyticsDB.Realms > 0) then
        assert(not ArenaAnalyticsRealmsDB or #ArenaAnalyticsRealmsDB == 0);
        assert(#ArenaAnalyticsDB.realms <= 1);
    end

    -- Confirm that there are only one names DB with data at a time!
    if(#ArenaAnalyticsDB.names > 1) then
        assert(not ArenaAnalyticsDB.Names or #ArenaAnalyticsDB.Names == 0);
    elseif(ArenaAnalyticsDB.Names and #ArenaAnalyticsDB.Names > 0) then
        assert(#ArenaAnalyticsDB.names <= 1);
    end

    -- Move 0.7.0 realms DB to ArenaAnalyticsDB.realms
    if(ArenaAnalyticsRealmsDB and #ArenaAnalyticsRealmsDB > 0 and #ArenaAnalyticsDB.realms <= 1) then
		ArenaAnalyticsDB.realms = Helpers:DeepCopy(ArenaAnalyticsRealmsDB) or {};
		ArenaAnalyticsRealmsDB = nil;

        -- Logging
		Debug:Log("Converted ArenaAnalyticsRealmsDB:", #ArenaAnalyticsDB.realms);
	end

    -- Convert realms DB to final DB
    if(#ArenaAnalyticsDB.realms == 1 and ArenaAnalyticsDB.Realms and #ArenaAnalyticsDB.Realms > 0) then
        Debug:Log("Deep copying ArenaAnalyticsDB.Realms", #ArenaAnalyticsDB.Realms);
        ArenaAnalyticsDB.realms = Helpers:DeepCopy(ArenaAnalyticsDB.Realms) or {};
        ArenaAnalyticsDB.Realms = nil;
    end

    -- Convert names DB to final DB
    if(#ArenaAnalyticsDB.names == 1 and ArenaAnalyticsDB.Names and #ArenaAnalyticsDB.Names > 0) then
        Debug:Log("Deep copying ArenaAnalyticsDB.Names", #ArenaAnalyticsDB.Names);
        ArenaAnalyticsDB.names = Helpers:DeepCopy(ArenaAnalyticsDB.Names) or {};
        ArenaAnalyticsDB.Names = nil;
    end

    -- Revert 
    local function revertPlayerNameAndRealmIndexing(match)
        if(not match) then
            return;
        end

        for _,isEnemy in ipairs({false, true}) do
            local team = ArenaMatch:GetTeam(match, isEnemy);
            if(type(team) == "table") then
                for _,player in ipairs(team) do
                    local name = player[oldPlayerKeys.name];
                    local realm = player[oldPlayerKeys.realm];

                    -- If either name or realm requires reverting
                    if(type(name) == "number" or type(realm) == "number") then
                        Debug:Log("Reverting player names:", name, realm);

                        if(type(name) == "number") then
                            name = ArenaAnalytics:GetName(name, true);
                        end

                        if(type(realm) == "number") then
                            realm = ArenaAnalytics:GetRealm(realm, true);
                        end

                        Debug:Log("   Reverted player names:", name, realm);
                    end

                    player[oldPlayerKeys.name] = name;
                    player[oldPlayerKeys.realm] = realm;
                end
            end
        end
    end

    -- Revert index based naming, to prioritize self as index 1
    for i=1, #ArenaAnalyticsDB do
        local match = ArenaAnalyticsDB[i];
        if(match) then
            revertPlayerNameAndRealmIndexing(match);
        end
    end

    -- Reset names and realms lists
    ArenaAnalyticsDB.names = nil;
    ArenaAnalyticsDB.realms = nil;
    ArenaAnalytics:InitializeArenaAnalyticsDB();

    -- Set a format version, to prevent repeating formatting
    ArenaAnalyticsDB.formatVersion = 1;
end

function VersionManager:ConvertRoundAndPlayerFormat()
    assert(ArenaAnalyticsDB.names[1] == UnitNameUnmodified("player"), "Invalid or missing self as first name entry!");

    local _,realm = UnitFullName("player");
    assert(realm and ArenaAnalyticsDB.realms[1] == realm, "Invalid or missing local realm as first realm entry!");

    if(ArenaAnalyticsDB.formatVersion ~= 1) then
        return;
    end

    local function convertPlayerValues(match, matchIndex)
        if(not match) then
            return;
        end

        -- Get a compact | separated player data string
        local function ToPlayerData(player, isEnemy)
            if(not player or type(player) == "string") then
                return player;
            end

            local player = {
                name = player[oldPlayerKeys.name],
                realm = player[oldPlayerKeys.realm],
                isSelf = player[oldPlayerKeys.is_self],
                isFirstDeath = player[oldPlayerKeys.is_first_death],
                isEnemy = isEnemy,
                race = player[oldPlayerKeys.race],
                spec = player[oldPlayerKeys.spec_id],
                role = player[oldPlayerKeys.role],
                kills = player[oldPlayerKeys.kills],
                deaths = player[oldPlayerKeys.deaths],
                damage = player[oldPlayerKeys.damage],
                healing = player[oldPlayerKeys.healing],
            };

            return ArenaMatch:MakeCompactPlayerData(player);
        end

        -- For each player
        for _,isEnemy in ipairs({false, true}) do
            local team = ArenaMatch:GetTeam(match, isEnemy);
            local newTeam = {}

            if(type(team) == "table") then
                for i,player in ipairs(team) do
                    local newDataString = ToPlayerData(player, isEnemy);

                    Debug:LogEscaped("ConvertPlayerValues:", i, newDataString);

                    if(newDataString == "") then
                        Debug:Log("ERROR: Converting player values added empty player value string!");
                    end

                    -- Actual conversion NYI!
                    if(newDataString) then
                        tinsert(newTeam, newDataString);
                    end
                end
            end

            Debug:Log("ConvertPlayerValues", #newTeam)
            if(#newTeam > 0) then
                local teamKey = isEnemy and ArenaMatch.matchKeys.enemy_team or ArenaMatch.matchKeys.team;
                for i,player in ipairs(newTeam) do
                    Debug:LogEscaped("     ", i, player);
                end

                match[teamKey] = newTeam;
            end
        end
    end

    for i=1, #ArenaAnalyticsDB do
        local match = ArenaAnalyticsDB[i];
        if(match) then
            ArenaMatch:FixRoundFormat(match);
            convertPlayerValues(match, i);
        end
    end

    ArenaAnalyticsDB.formatVersion = 2;
end

function VersionManager:FinalizeConversionAttempts()
	ArenaAnalytics.unsavedArenaCount = #ArenaAnalyticsDB;

	ArenaAnalytics:ResortGroupsInMatchHistory();
	Sessions:RecomputeSessionsForMatchHistory(true);

    Import:TryHide();
    Filters:Refresh();
    ArenaAnalyticsScrollFrame:Hide();
end