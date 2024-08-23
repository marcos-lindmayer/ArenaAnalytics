local _, ArenaAnalytics = ...; -- Addon Namespace
local Import = ArenaAnalytics.Import;
local Export = ArenaAnalytics.Export;

-- Local module aliases
local Options = ArenaAnalytics.Options;
local Filters = ArenaAnalytics.Filters;
local Constants = ArenaAnalytics.Constants;
local Helpers = ArenaAnalytics.Helpers;
local AAtable = ArenaAnalytics.AAtable;
local AAmatch = ArenaAnalytics.AAmatch;

-------------------------------------------------------------------------

local isImporting = false;
local cachedValues = {};
local cachedArenas = {};

ArenaImportPasteString = "";

local existingArenaCount = 0;
local arenasSkippedByDate = 0;
local earliestStartTime, latestStartTime;

-- Get the start time of the first and last arena currently stored.
local function RecomputeFirstAndLastStoredTimes()
    if(isImporting) then
        return;
    end

    earliestStartTime, latestStartTime = nil, nil;
    arenasSkippedByDate = 0;
    existingArenaCount = #ArenaAnalyticsMatchHistoryDB;

    -- Earliest start times (Loop in case of invalid dates)
    for i = #ArenaAnalyticsMatchHistoryDB, 1, -1 do
        local match = ArenaAnalyticsMatchHistoryDB[i];
        
        if(match["date"] and match["date"] > 0) then
            earliestStartTime = match["date"];
        end
    end
    
    -- Latest start times (Loop in case of invalid dates)
    for i = 1, #ArenaAnalyticsMatchHistoryDB do
        local match = ArenaAnalyticsMatchHistoryDB[i];

        if(match["date"] and match["date"] > 0) then
            latestStartTime = match["date"];
        end
    end
end

local function CanImportMatchByRelativeTime(startTime)
    local doesMatchPass = false;

    if(existingArenaCount == 0) then
        doesMatchPass = true;
    elseif(not Options:Get("allowImportDataMerge")) then
        return false; -- Backup catch
    elseif(startTime and earliestStartTime and latestStartTime) then
        if(startTime == 0) then
            doesMatchPass = false;
        else
            doesMatchPass = (startTime + 360) < earliestStartTime or (startTime - 360) > latestStartTime;
        end
    else
        ArenaAnalytics:Log("CanImportMatchByRelativeTime: ", startTime, earliestStartTime, latestStartTime);
    end
    
    if(doesMatchPass == false) then
        ArenaAnalytics:Log("Rejected startTime: ", date("%d/%m/%y %H:%M:%S", startTime));
        arenasSkippedByDate = arenasSkippedByDate + 1;
    end

    return doesMatchPass;
end

local function checkDataSource_ArenaStats_Wotlk(data)
    local ArenaStatsFormat_Wotlk = "isRanked,startTime,endTime,zoneId,duration,teamName,teamColor,"..
    "winnerColor,teamPlayerName1,teamPlayerName2,teamPlayerName3,teamPlayerName4,teamPlayerName5,"..
    "teamPlayerClass1,teamPlayerClass2,teamPlayerClass3,teamPlayerClass4,teamPlayerClass5,"..
    "teamPlayerRace1,teamPlayerRace2,teamPlayerRace3,teamPlayerRace4,teamPlayerRace5,oldTeamRating,"..
    "newTeamRating,diffRating,mmr,enemyOldTeamRating,enemyNewTeamRating,enemyDiffRating,enemyMmr,"..
    "enemyTeamName,enemyPlayerName1,enemyPlayerName2,enemyPlayerName3,enemyPlayerName4,"..
    "enemyPlayerName5,enemyPlayerClass1,enemyPlayerClass2,enemyPlayerClass3,enemyPlayerClass4,"..
    "enemyPlayerClass5,enemyPlayerRace1,enemyPlayerRace2,enemyPlayerRace3,enemyPlayerRace4,"..
    "enemyPlayerRace5,enemyFaction";

    local dataFormat = data[1]:sub(1, #ArenaStatsFormat_Wotlk);
    if(dataFormat == ArenaStatsFormat_Wotlk) then
        return true;
    end

   return false;
end

local function checkDataSource_ArenaStats_Cata(data)
    local ArenaStatsFormat_Cata = "isRanked,startTime,endTime,zoneId,duration,teamName,teamColor,"..
    "winnerColor,teamPlayerName1,teamPlayerName2,teamPlayerName3,teamPlayerName4,teamPlayerName5,"..
    "teamPlayerClass1,teamPlayerClass2,teamPlayerClass3,teamPlayerClass4,teamPlayerClass5,"..
    "teamPlayerRace1,teamPlayerRace2,teamPlayerRace3,teamPlayerRace4,teamPlayerRace5,oldTeamRating,"..
    "newTeamRating,diffRating,mmr,enemyOldTeamRating,enemyNewTeamRating,enemyDiffRating,enemyMmr,"..
    "enemyTeamName,enemyPlayerName1,enemyPlayerName2,enemyPlayerName3,enemyPlayerName4,"..
    "enemyPlayerName5,enemyPlayerClass1,enemyPlayerClass2,enemyPlayerClass3,enemyPlayerClass4,"..
    "enemyPlayerClass5,enemyPlayerRace1,enemyPlayerRace2,enemyPlayerRace3,enemyPlayerRace4,"..
    "enemyPlayerRace5,enemyFaction,enemySpec1,enemySpec2,enemySpec3,enemySpec4,enemySpec5,"..
    "teamSpec1,teamSpec2,teamSpec3,teamSpec4,teamSpec5,"
    local dataFormat = data[1]:sub(1, #ArenaStatsFormat_Cata);
    if(dataFormat == ArenaStatsFormat_Cata) then
        return true;
    end

    return false;
end

local function checkDataSource_ArenaAnalytics(data)
    if(data[1]:sub(1, 18) == "ArenaAnalytics_v2:") then
        return true;
    end
   return false;
end

function Import:determineImportSource(data)
    if(data and data[1] and #data[1] > 0) then
        -- Identify ArenaAnalytics
        if(checkDataSource_ArenaAnalytics(data)) then
            return "ArenaAnalytics";
        end

        -- Identify ArenaStats
        if(checkDataSource_ArenaStats_Cata(data)) then
            return "ArenaStats_Cata";
        elseif (checkDataSource_ArenaStats_Wotlk(data)) then
            return "ArenaStats_Wotlk";
        end
    end

    -- Fallback to invalid
    return "Invalid";
end

function Import:reset()
    ArenaAnalyticsScrollFrame.importDialogFrame.button:Enable();
    ArenaAnalyticsScrollFrame.importDialogFrame.editbox:SetText("");
    AAtable:RefreshLayout(true);

    cachedValues = {};
    cachedArenas = {};
    isImporting = false;
end

function Import:tryHide()
    if(ArenaAnalyticsScrollFrame.importDialogFrame ~= nil and ArenaAnalytics:HasStoredMatches()) then
        ArenaAnalyticsScrollFrame.importDialogFrame.button:Disable();
        ArenaAnalyticsScrollFrame.importDialogFrame.editbox:SetText("");
        ArenaAnalyticsScrollFrame.importDialogFrame:Hide();
        ArenaAnalyticsScrollFrame.importDialogFrame = nil;
    end
end

---------------------------------
-- General import pipeline startpoint
---------------------------------

function Import:parseRawData(data)
    if(data == nil or tostring(data[1]) == nil) then
        ArenaAnalytics:Log("Invalid data for import attempt.. Bailing out immediately..");
        return;
    end

    local dataSource = Import:determineImportSource(data);

    if(not isImporting and dataSource ~= "Invalid") then
        RecomputeFirstAndLastStoredTimes();
    end
    
    if(isImporting) then
        ArenaAnalytics:Print("Another import already in progress!");
    elseif(not ArenaAnalyticsSettings["allowImportDataMerge"] and ArenaAnalytics:HasStoredMatches()) then
        ArenaAnalytics:Print("Import failed due to existing stored matches!");
        Import:reset();
    elseif(dataSource == "Invalid") then
        ArenaAnalytics:Print("Import data is corrupted, not valid, or empty. Make sure to copy the whole ArenaStats export text.");
        Import:reset();
    else
        ArenaAnalytics:Print("Importing! Please wait...")
        isImporting = true;

        local dataIsCorrupt = false;

        cachedArenas = {}

        -- ArenaStats
        if(dataSource == "ArenaStats_Wotlk") then
            -- Remove heading
            local arenasRaw = string.sub(data[1], 712)
            -- Split into arenas
            local _, numberOfArenas = arenasRaw:gsub(",","")
            numberOfArenas = numberOfArenas/48
            if (numberOfArenas ~= math.floor(numberOfArenas)) then
                dataIsCorrupt = true;
            elseif(numberOfArenas == 0) then
                Import:completeImport()
            else
                ArenaAnalytics:Print(numberOfArenas .. " arenas found! Importing!")
                
                -- Gather all ArenaStats (wotlk) values
                cachedValues = {}
                separator = ","
                arenasRaw:gsub("([^"..separator.."]*)"..separator, function(c)
                    table.insert(cachedValues, c)
                end);

                Import:parseCachedValues_ArenaStats_Wotlk(1);
            end
        elseif(dataSource == "ArenaStats_Cata") then
            -- Remove heading
            local arenasRaw = string.sub(data[1], 818);
            -- Split into arenas
            local _, numberOfArenas = arenasRaw:gsub(",","");
            numberOfArenas = numberOfArenas/58;
            if (numberOfArenas ~= math.floor(numberOfArenas) and false) then
                dataIsCorrupt = true;
            elseif(numberOfArenas == 0) then
                Import:completeImport();
            else
                ArenaAnalytics:Print(numberOfArenas .. " arenas found! Importing!");
                
                -- Gather all ArenaStats (cata) values
                cachedValues = {}
                separator = ","
                arenasRaw:gsub("([^"..separator.."]*)"..separator, function(c)
                    table.insert(cachedValues, c)
                end);

                Import:parseCachedValues_ArenaStats_Cata(1);
            end
        elseif(dataSource == "ArenaAnalytics") then
            -- Remove heading
            local arenasRaw = string.sub(data[1], 1111)
            -- Split into arenas
            local _, numberOfArenas = arenasRaw:gsub(",","");
            numberOfArenas = numberOfArenas/95;
            ArenaAnalytics:Log(numberOfArenas)
            if (numberOfArenas ~= math.floor(numberOfArenas)) then
                dataIsCorrupt = true;
            elseif(numberOfArenas == 0) then
                Import:completeImport();
            else
                ArenaAnalytics:Print(numberOfArenas .. " arenas found! Importing!")
                
                -- Gather all ArenaStats values
                cachedValues = {}
                separator = ","
                arenasRaw:gsub("([^"..separator.."]*)"..separator, function(c)
                    table.insert(cachedValues, c)
                end);

                Import:parseCachedValues_ArenaAnalytics(1);
            end
        end

        if(dataIsCorrupt) then 
            ArenaAnalytics:Print("Data is corrupted! No arenas were copied.")
            Import:reset();
        end
    end
    
    if(not isImporting) then
        -- Hide the dialog if we have existing matches
        Import:tryHide();
    end
end

-- Returns true, false or nil based on input strings "1", "0" or ""
local function GetBoolFromBinaryImport(value)
    if(value == "1" or value == "0") then
        return value == "1";
    end

    return nil;
end

---------------------------------
-- ArenaStats (Wotlk) import
---------------------------------

function Import:parseCachedValues_ArenaStats_Wotlk(nextIndex)
    if(nextIndex == nil) then
        nextIndex = 1;
    end

    local arenasParsedThisFrame = 0;
    local arena = {}
    
    local finishedParsing = false;

    for i = nextIndex, #cachedValues do
        if(i%48 ~= 0) then
            table.insert(arena, cachedValues[i])
        else
            if(CanImportMatchByRelativeTime(tonumber(arena[2]))) then
                local arenaTable = {
                    ["isRated"] = (arena[1] == "YES"),
                    ["startTime"] = arena[2],
                    ["endTime"] = arena[3],
                    ["zoneId"] = arena[4],
                    ["duration"] = tonumber(arena[5]) or 0,
                    ["teamName"] = arena[6],
                    ["teamColor"] = arena[7],
                    ["winnerColor"] = arena[8],
                    ["teamPlayerName1"] = arena[9],
                    ["teamPlayerName2"] = arena[10],
                    ["teamPlayerName3"] = arena[11],
                    ["teamPlayerName4"] = arena[12],
                    ["teamPlayerName5"] = arena[13],
                    ["teamPlayerClass1"] = arena[14],
                    ["teamPlayerClass2"] = arena[15],
                    ["teamPlayerClass3"] = arena[16],
                    ["teamPlayerClass4"] = arena[17],
                    ["teamPlayerClass5"] = arena[18],
                    ["teamPlayerRace1"] = arena[19],
                    ["teamPlayerRace2"] = arena[20],
                    ["teamPlayerRace3"] = arena[21],
                    ["teamPlayerRace4"] = arena[22],
                    ["teamPlayerRace5"] = arena[23],
                    ["oldTeamRating"] = arena[24],
                    ["newTeamRating"] = arena[25],
                    ["diffRating"] = arena[26],
                    ["mmr"] = arena[27],
                    ["enemyOldTeamRating"] = arena[28],
                    ["enemyNewTeamRating"] = arena[29],
                    ["enemyDiffRating"] = arena[30],
                    ["enemyMmr"] = arena[31],
                    ["enemyTeamName"] = arena[32],
                    ["enemyPlayerName1"] = arena[33],
                    ["enemyPlayerName2"] = arena[34],
                    ["enemyPlayerName3"] = arena[35],
                    ["enemyPlayerName4"] = arena[36],
                    ["enemyPlayerName5"] = arena[37],
                    ["enemyPlayerClass1"] = arena[38],
                    ["enemyPlayerClass2"] = arena[39],
                    ["enemyPlayerClass3"] = arena[40],
                    ["enemyPlayerClass4"] = arena[41],
                    ["enemyPlayerClass5"] = arena[42],
                    ["enemyPlayerRace1"] = arena[43],
                    ["enemyPlayerRace2"] = arena[44],
                    ["enemyPlayerRace3"] = arena[45],
                    ["enemyPlayerRace4"] = arena[46],
                    ["enemyPlayerRace5"] = arena[47],
                    ["enemyFaction"] = arena[48]
                }
                
                table.insert(cachedArenas, arenaTable);
            end

            arenasParsedThisFrame = arenasParsedThisFrame + 1;
            arena = {}

            if(arenasParsedThisFrame >= 1000 and i < #cachedValues) then
                -- Call function to continue next frame
                C_Timer.After(0, function() Import:parseCachedValues_ArenaStats_Wotlk(i + 1) end);
                return;
            else
                finishedParsing = true;
            end
        end
    end

    if(finishedParsing) then
        Import:addCachedArenasToMatchHistory_ArenaStats(1);
    end
end

---------------------------------
-- ArenaStats (Cata) import
---------------------------------

function Import:parseCachedValues_ArenaStats_Cata(nextIndex)
    if(nextIndex == nil) then
        nextIndex = 1;
    end

    local arenasParsedThisFrame = 0;
    local arena = {}
    
    local finishedParsing = false;

    for i = nextIndex, #cachedValues do
        if(i%58 ~= 0) then
            table.insert(arena, cachedValues[i]);
        else
            if(CanImportMatchByRelativeTime(tonumber(arena[2]))) then
                local arenaTable = {
                    ["isRated"] = (arena[1] == "YES"),
                    ["startTime"] = arena[2],
                    ["endTime"] = arena[3],
                    ["zoneId"] = arena[4],
                    ["duration"] = tonumber(arena[5]) or 0,
                    ["teamName"] = arena[6],
                    ["teamColor"] = arena[7],
                    ["winnerColor"] = arena[8],
                    ["teamPlayerName1"] = arena[9],
                    ["teamPlayerName2"] = arena[10],
                    ["teamPlayerName3"] = arena[11],
                    ["teamPlayerName4"] = arena[12],
                    ["teamPlayerName5"] = arena[13],
                    ["teamPlayerClass1"] = arena[14],
                    ["teamPlayerClass2"] = arena[15],
                    ["teamPlayerClass3"] = arena[16],
                    ["teamPlayerClass4"] = arena[17],
                    ["teamPlayerClass5"] = arena[18],
                    ["teamPlayerRace1"] = arena[19],
                    ["teamPlayerRace2"] = arena[20],
                    ["teamPlayerRace3"] = arena[21],
                    ["teamPlayerRace4"] = arena[22],
                    ["teamPlayerRace5"] = arena[23],
                    ["oldTeamRating"] = arena[24],
                    ["newTeamRating"] = arena[25],
                    ["diffRating"] = arena[26],
                    ["mmr"] = arena[27],
                    ["enemyOldTeamRating"] = arena[28],
                    ["enemyNewTeamRating"] = arena[29],
                    ["enemyDiffRating"] = arena[30],
                    ["enemyMmr"] = arena[31],
                    ["enemyTeamName"] = arena[32],
                    ["enemyPlayerName1"] = arena[33],
                    ["enemyPlayerName2"] = arena[34],
                    ["enemyPlayerName3"] = arena[35],
                    ["enemyPlayerName4"] = arena[36],
                    ["enemyPlayerName5"] = arena[37],
                    ["enemyPlayerClass1"] = arena[38],
                    ["enemyPlayerClass2"] = arena[39],
                    ["enemyPlayerClass3"] = arena[40],
                    ["enemyPlayerClass4"] = arena[41],
                    ["enemyPlayerClass5"] = arena[42],
                    ["enemyPlayerRace1"] = arena[43],
                    ["enemyPlayerRace2"] = arena[44],
                    ["enemyPlayerRace3"] = arena[45],
                    ["enemyPlayerRace4"] = arena[46],
                    ["enemyPlayerRace5"] = arena[47],
                    ["enemyFaction"] = arena[48],
                    ["teamSpec1"] = arena[49],
                    ["teamSpec2"] = arena[50],
                    ["teamSpec3"] = arena[51],
                    ["teamSpec4"] = arena[52],
                    ["teamSpec5"] = arena[53],
                    ["enemySpec1"] = arena[54],
                    ["enemySpec2"] = arena[55],
                    ["enemySpec3"] = arena[56],
                    ["enemySpec4"] = arena[57],
                    ["enemySpec5"] = arena[58],
                }

                table.insert(cachedArenas, arenaTable);
            end

            arenasParsedThisFrame = arenasParsedThisFrame + 1;
            arena = {}

            if(arenasParsedThisFrame >= 1000 and i < #cachedValues) then
                -- Call function to continue next frame
                C_Timer.After(0, function() Import:parseCachedValues_ArenaStats_Cata(i + 1) end);
                return;
            else
                finishedParsing = true;
            end
        end
    end

    if(finishedParsing) then
        Import:addCachedArenasToMatchHistory_ArenaStats(1);
    end
end

function Import:addCachedArenasToMatchHistory_ArenaStats(nextIndex)
    if(nextIndex == nil) then
        nextIndex = 1;
    end

    local arenasImportedThisFrame = 0;

    for i = nextIndex, #cachedArenas do
        local arena = cachedArenas[i]
        local size = 0
        for i = 1, 5 do
            if (arena["teamPlayerName" .. i] ~= "" or arena["enemyPlayerName" .. i] ~= "") then
                size = i;
            end
        end
        size = size == 1 and 2 or size;
        size = size == 4 and 5 or size;

        local unixDate = tonumber(arena["startTime"]) or 0;
        
        local bracket = ArenaAnalytics:getBracketFromTeamSize(size);
        local group = Import:createGroupTable_ArenaStats(arena, "team", size);
        local enemyGroup = Import:createGroupTable_ArenaStats(arena, "enemy", size);

        local arena = {
            ["isRated"] = arena["isRated"],
            ["date"] = unixDate,
            ["season"] = ArenaAnalytics:computeSeasonFromMatchDate(unixDate),
            ["map"] = Constants:GetMapKeyByID(tonumber(arena["zoneId"])), 
            ["bracket"] = bracket,
            ["duration"] = tonumber(arena["duration"]) or 0,
            ["team"] = group,
            ["rating"] = tonumber(arena["newTeamRating"]), 
            ["ratingDelta"] = tonumber(arena["diffRating"]),
            ["mmr"] = tonumber(arena["mmr"]), 
            ["enemyTeam"] = enemyGroup,
            ["enemyRating"] = tonumber(arena["enemyNewTeamRating"]), 
            ["enemyRatingDelta"] = tonumber(arena["enemyDiffRating"]),
            ["enemyMmr"] = tonumber(arena["enemyMmr"]),
            ["comp"] = AAmatch:GetArenaComp(group, size),
            ["enemyComp"] = AAmatch:GetArenaComp(enemyGroup, size),
            ["won"] = arena["teamColor"] == arena["winnerColor"] and true or false,
            ["firstDeath"] = nil,
            ["importInfo"] = {"ArenaStats", (existingArenaCount > 0 and true or false)} -- Import Source, isMergeImport
        }

        table.insert(ArenaAnalyticsMatchHistoryDB, arena);
        arenasImportedThisFrame = arenasImportedThisFrame + 1;

        if(arenasImportedThisFrame >= 500 and i < #cachedArenas) then
            C_Timer.After(0, function() Import:addCachedArenasToMatchHistory_ArenaStats(i + 1) end);
            return;
        end        
    end

    Import:completeImport();
end

function Import:createGroupTable_ArenaStats(arena, groupType, size)
    local group = {}
    for i = 1, size do
        local name = arena[groupType .. "PlayerName" .. i] or "";
        local race = arena[groupType .. "PlayerRace" .. i] or "";
        local class = arena[groupType .. "PlayerClass" .. i] or "";
        local spec = arena[groupType .. "Spec" .. i] or "";
        local isDK = class == "DEATHKNIGHT" and true or false;

        if(name ~= "" and race ~= "" and class ~= "") then 
            local player = {
                ["GUID"] = nil,
                ["name"] = name or "",
                ["kills"] = nil,
                ["deaths"] = nil,
                ["faction"] = Constants:GetFactionByRace(race),
                ["race"] = race,
                ["class"] = isDK and "Death Knight" or class and string.lower(class):gsub("^%l", string.upper) or nil,
                ["damage"] = nil,
                ["healing"] = nil,
                ["spec"] = spec
            }
            table.insert(group, player);
        end
    end

    -- Place player first in the arena party group, sort rest
	ArenaAnalytics:SortGroup(group, (groupType == "team"), arena["player"]);

    return group;
end

---------------------------------
-- ArenaAnalytics import
---------------------------------

-- ArenaAnalytics import
function Import:parseCachedValues_ArenaAnalytics(nextIndex)
    if(nextIndex == nil) then
        nextIndex = 1;
    end

    local arenasParsedThisFrame = 0;
    local arena = {}
    
    local finishedParsing = false;

    for i = nextIndex, #cachedValues do
        if(i%95 ~= 0) then
            table.insert(arena, cachedValues[i])
        else
            if(CanImportMatchByRelativeTime(tonumber(arena[1]))) then
                local arenaTable = {
                    ["date"] = tonumber(arena[1]),
                    ["season"] = tonumber(arena[2]),
                    ["bracket"] = arena[3],
                    ["map"] = arena[4],
                    ["duration"] = tonumber(arena[5]) or 0,
                    ["won"] = GetBoolFromBinaryImport(arena[6]), -- Won, lost or nil
                    ["isRated"] = arena[7] == "1",
                    ["rating"] = tonumber(arena[8]),
                    ["ratingDelta"] = tonumber(arena[9]),
                    ["mmr"] = tonumber(arena[10]),
                    ["enemyRating"] = tonumber(arena[11]),
                    ["enemyRatingDelta"] = tonumber(arena[12]),
                    ["enemyMmr"] = tonumber(arena[13]),
                    ["firstDeath"] = arena[14],
                    ["player"] = arena[15],
                    ["party1Name"] = arena[16], -- Party names
                    ["party2Name"] = arena[17],
                    ["party3Name"] = arena[18],
                    ["party4Name"] = arena[19],
                    ["party5Name"] = arena[20],
                    ["party1Race"] = arena[21], -- Party races
                    ["party2Race"] = arena[22],
                    ["party3Race"] = arena[23],
                    ["party4Race"] = arena[24],
                    ["party5Race"] = arena[25],
                    ["party1Class"] = arena[26], -- Party classes
                    ["party2Class"] = arena[27],
                    ["party3Class"] = arena[28],
                    ["party4Class"] = arena[29],
                    ["party5Class"] = arena[30],
                    ["party1Spec"] = arena[31], -- Party Specs
                    ["party2Spec"] = arena[32],
                    ["party3Spec"] = arena[33],
                    ["party4Spec"] = arena[34],
                    ["party5Spec"] = arena[35],
                    ["party1Kills"] = tonumber(arena[36]), -- Party Kills stats
                    ["party2Kills"] = tonumber(arena[37]),
                    ["party3Kills"] = tonumber(arena[38]),
                    ["party4Kills"] = tonumber(arena[39]),
                    ["party5Kills"] = tonumber(arena[40]),
                    ["party1Deaths"] = tonumber(arena[41]), -- Party Death stats
                    ["party2Deaths"] = tonumber(arena[42]),
                    ["party3Deaths"] = tonumber(arena[43]),
                    ["party4Deaths"] = tonumber(arena[44]),
                    ["party5Deaths"] = tonumber(arena[45]),
                    ["party1Damage"] = tonumber(arena[46]), -- Party Damage stats
                    ["party2Damage"] = tonumber(arena[47]),
                    ["party3Damage"] = tonumber(arena[48]),
                    ["party4Damage"] = tonumber(arena[49]),
                    ["party5Damage"] = tonumber(arena[50]),
                    ["party1Healing"] = tonumber(arena[51]), -- Party Healing stats
                    ["party2Healing"] = tonumber(arena[52]),
                    ["party3Healing"] = tonumber(arena[53]),
                    ["party4Healing"] = tonumber(arena[54]),
                    ["party5Healing"] = tonumber(arena[55]),
                    ["enemy1Name"] = arena[56], -- Enemy names
                    ["enemy2Name"] = arena[57],
                    ["enemy3Name"] = arena[58],
                    ["enemy4Name"] = arena[59],
                    ["enemy5Name"] = arena[60],
                    ["enemy1Race"] = arena[61], -- Enemy races
                    ["enemy2Race"] = arena[62],
                    ["enemy3Race"] = arena[63],
                    ["enemy4Race"] = arena[64],
                    ["enemy5Race"] = arena[65],
                    ["enemy1Class"] = arena[66], -- Enemy classes
                    ["enemy2Class"] = arena[67],
                    ["enemy3Class"] = arena[68],
                    ["enemy4Class"] = arena[69],
                    ["enemy5Class"] = arena[70],
                    ["enemy1Spec"] = arena[71], -- Enemy Specs
                    ["enemy2Spec"] = arena[72],
                    ["enemy3Spec"] = arena[73],
                    ["enemy4Spec"] = arena[74],
                    ["enemy5Spec"] = arena[75],
                    ["enemy1Kills"] = tonumber(arena[76]), -- Enemy Kills stats
                    ["enemy2Kills"] = tonumber(arena[77]),
                    ["enemy3Kills"] = tonumber(arena[78]),
                    ["enemy4Kills"] = tonumber(arena[79]),
                    ["enemy5Kills"] = tonumber(arena[80]),
                    ["enemy1Deaths"] = tonumber(arena[81]), -- Enemy Death stats
                    ["enemy2Deaths"] = tonumber(arena[82]),
                    ["enemy3Deaths"] = tonumber(arena[83]),
                    ["enemy4Deaths"] = tonumber(arena[84]),
                    ["enemy5Deaths"] = tonumber(arena[85]),
                    ["enemy1Damage"] = tonumber(arena[86]), -- Enemy Damage stats
                    ["enemy2Damage"] = tonumber(arena[87]),
                    ["enemy3Damage"] = tonumber(arena[88]),
                    ["enemy4Damage"] = tonumber(arena[89]),
                    ["enemy5Damage"] = tonumber(arena[90]),
                    ["enemy1Healing"] = tonumber(arena[91]), -- Enemy Healing stats
                    ["enemy2Healing"] = tonumber(arena[92]),
                    ["enemy3Healing"] = tonumber(arena[93]),
                    ["enemy4Healing"] = tonumber(arena[94]),
                    ["enemy5Healing"] = tonumber(arena[95]),
                }

                table.insert(cachedArenas, arenaTable);
            end

            arenasParsedThisFrame = arenasParsedThisFrame + 1;
            arena = {}

            if(arenasParsedThisFrame >= 1000 and i < #cachedValues) then
                -- Call function to continue next frame
                C_Timer.After(0, function() Import:parseCachedValues_ArenaAnalytics(i + 1) end);
                return;
            else
                finishedParsing = true;
            end

        end
    end

    if(finishedParsing) then
        Import:addCachedArenasToMatchHistory_ArenaAnalytics();
    end
end

function Import:addCachedArenasToMatchHistory_ArenaAnalytics(nextIndex)
    if(nextIndex == nil) then
        nextIndex = 1;
    end

    local arenasImportedThisFrame = 0;

    for i = nextIndex, #cachedArenas do
        local cachedArena = cachedArenas[i]
        local size = 0
        for i = 1, 5 do
            if (cachedArena["teamPlayerName" .. i] ~= "" or cachedArena["enemyPlayerName" .. i] ~= "") then
                size = i;
            end
        end
        size = size == 1 and 2 or size;
        size = size == 4 and 5 or size;

        local unixDate = tonumber(cachedArena["date"]) or 0;

        local team = Import:createGroupTable_ArenaAnalytics(cachedArena, "party", size);
        local enemyTeam = Import:createGroupTable_ArenaAnalytics(cachedArena, "enemy", size);

        local arena = {
            ["isRated"] = cachedArena["isRated"] or false,
            ["date"] = unixDate,
            ["season"] = cachedArena["season"],
            ["map"] = cachedArena["map"], 
            ["bracket"] = cachedArena["bracket"],
            ["duration"] = tonumber(cachedArena["duration"]) or 0,
            ["team"] = team,
            ["rating"] = tonumber(cachedArena["rating"]), 
            ["ratingDelta"] = tonumber(cachedArena["ratingDelta"]),
            ["mmr"] = tonumber(cachedArena["mmr"]), 
            ["enemyTeam"] = enemyTeam,
            ["enemyRating"] = tonumber(cachedArena["enemyRating"]), 
            ["enemyRatingDelta"] = tonumber(cachedArena["enemyRatingDelta"]),
            ["enemyMmr"] = tonumber(cachedArena["enemyMmr"]),
            ["comp"] = AAmatch:GetArenaComp(team, size),
            ["enemyComp"] = AAmatch:GetArenaComp(enemyTeam, size),
            ["won"] = cachedArena["won"],
            ["firstDeath"] = cachedArena["firstDeath"] ~= "" and cachedArena["firstDeath"] or nil,
            ["player"] = cachedArena["player"],
            ["importInfo"] = {"ArenaAnalytics", (existingArenaCount > 0 and true or false)} -- Import Source, isMergeImport
        }

        table.insert(ArenaAnalyticsMatchHistoryDB, arena);
        arenasImportedThisFrame = arenasImportedThisFrame + 1;

        if(arenasImportedThisFrame >= 500 and i < #cachedArenas) then
            C_Timer.After(0, function() Import:addCachedArenasToMatchHistory_ArenaAnalytics(i + 1) end);
            return;
        end        
    end

    ArenaAnalytics:RecomputeSessionsForMatchHistory();

    Import:completeImport();
end

function Import:completeImport()
    Import:reset();
    Import:tryHide();

    
    table.sort(ArenaAnalyticsMatchHistoryDB, function (k1,k2)
        if (k1["date"] and k2["date"]) then
            return k1["date"] < k2["date"];
        end
    end);
    
    ArenaAnalytics:RecomputeSessionsForMatchHistory();
    ArenaAnalytics:UpdateLastSession();
	ArenaAnalytics.unsavedArenaCount = #ArenaAnalyticsMatchHistoryDB;
    
    Filters:Refresh();
    
    ArenaAnalytics:Print("Import complete. " .. (#ArenaAnalyticsMatchHistoryDB - existingArenaCount) .. " arenas added!");
    ArenaAnalytics:Log("Import ignored", arenasSkippedByDate, "arenas due to their date.");
end

function Import:createGroupTable_ArenaAnalytics(arena, groupType, size)
    local group = {}
    for i = 1, size do
        local name = arena[groupType .. i .. "Name"] or "";
        local race = arena[groupType ..  i .. "Race"] or "";
        local class = arena[groupType ..  i .. "Class"] or "";

        if(name ~= "" and race ~= "" and class ~= "") then 
            local player = {
                ["GUID"] = nil,
                ["name"] = name,
                ["kills"] = arena[groupType ..  i .. "Kills"],
                ["deaths"] = arena[groupType ..  i .. "Deaths"],
                ["faction"] = Constants:GetFactionByRace(race),
                ["race"] = race,
                ["class"] = class,
                ["damage"] = arena[groupType ..  i .. "Damage"],
                ["healing"] = arena[groupType ..  i .. "Healing"],
                ["spec"] = arena[groupType ..  i .. "Spec"]
            }
            table.insert(group, player);
        end
    end

    -- Place player first in the arena party group, sort rest
	ArenaAnalytics:SortGroup(group, (groupType == "party"), arena["player"]);

    return group;
end

---------------------------------
-- ArenaAnalytics export
---------------------------------

-- Returns a CSV-formatted string using ArenaAnalyticsMatchHistoryDB info
function Export:combineExportCSV()
    if(not ArenaAnalytics:HasStoredMatches()) then
        ArenaAnalytics:Log("Export: No games to export!");
        return "No games to export!";
    end

    if(ArenaAnalyticsScrollFrame.exportDialogFrame) then
        ArenaAnalyticsScrollFrame.exportDialogFrame:Hide();
    end

    local exportTable = {}
    local exportHeader = "ArenaAnalytics_v2:"..

    -- Match data
    "date,season,bracket,map,duration,won,isRated,rating,ratingDelta,mmr,enemyRating,enemyRatingDelta,enemyMMR,firstDeath,player,"..

    -- Team data
    "party1Name,party2Name,party3Name,party4Name,party5Name,"..
    "party1Race,party2Race,party3Race,party4Race,party5Race,"..
    "party1Class,party2Class,party3Class,party4Class,party5Class,"..
    "party1Spec,party2Spec,party3Spec,party4Spec,party5Spec,"..
    "party1Kills,party2Kills,party3Kills,party4Kills,party5Kills,"..
    "party1Deaths,party2Deaths,party3Deaths,party4Deaths,party5Deaths,"..
    "party1Damage,party2Damage,party3Damage,party4Damage,party5Damage,"..
    "party1Healing,party2Healing,party3Healing,party4Healing,party5Healing,"..

    -- Enemy Team Data
    "enemy1Name,enemy2Name,enemy3Name,enemy4Name,enemy5Name,"..
    "enemy1Race,enemy2Race,enemy3Race,enemy4Race,enemy5Race,"..
    "enemy1Class,enemy2Class,enemy3Class,enemy4Class,enemy5Class,"..
    "enemy1Spec,enemy2Spec,enemy3Spec,enemy4Spec,enemy5Spec,"..
    "enemy1Kills,enemy2Kills,enemy3Kills,enemy4Kills,enemy5Kills,"..
    "enemy1Deaths,enemy2Deaths,enemy3Deaths,enemy4Deaths,enemy5Deaths,"..
    "enemy1Damage,enemy2Damage,enemy3Damage,enemy4Damage,enemy5Damage,"..
    "enemy1Healing,enemy2Healing,enemy3Healing,enemy4Healing,enemy5Healing";

    tinsert(exportTable, exportHeader);

    Export:addMatchesToExport(exportTable)
end

function Export:addMatchesToExport(exportTable, nextIndex)
    ArenaAnalytics:Log("Attempting export.. addMatchesToExport", nextIndex);

    nextIndex = nextIndex or 1;
    
    local playerData = {"name", "race", "class", "spec", "kills", "deaths", "damage", "healing"};
    
    local arenasAddedThisFrame = 0;
    for i = nextIndex, #ArenaAnalyticsMatchHistoryDB do
        local match = ArenaAnalyticsMatchHistoryDB[i];
        
        local victory = match["won"] ~= nil and (match["won"] and "1" or "0") or "";
        
        -- Add match data
        local matchCSV = match["date"] .. ","
        .. (match["season"] or ArenaAnalytics:computeSeasonFromMatchDate(match["date"]) or "") .. ","
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

        if(arenasAddedThisFrame >= 10000 and i < #ArenaAnalyticsMatchHistoryDB) then
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
    ArenaAnalytics:Log("Attempting export.. FinalizeExportCSV");

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
    ArenaAnalytics:Log("Garbage Collection forced by Export finalize.");
end