local _, ArenaAnalytics = ...;
ArenaAnalytics.Import = {};
ArenaAnalytics.Export = {};

local Import = ArenaAnalytics.Import;
local Export = ArenaAnalytics.Export;

local isImporting = false;
local cachedValues = {};
local cachedArenas = {};

ArenaImportPasteString = "";

local function checkDataSource_ArenaStats(data)
    local dataFormat = data[1]:sub(1, 711);
    local ArenaStatsFormat = "isRanked,startTime,endTime,zoneId,duration,teamName,teamColor,"..
    "winnerColor,teamPlayerName1,teamPlayerName2,teamPlayerName3,teamPlayerName4,teamPlayerName5,"..
    "teamPlayerClass1,teamPlayerClass2,teamPlayerClass3,teamPlayerClass4,teamPlayerClass5,"..
    "teamPlayerRace1,teamPlayerRace2,teamPlayerRace3,teamPlayerRace4,teamPlayerRace5,oldTeamRating,"..
    "newTeamRating,diffRating,mmr,enemyOldTeamRating,enemyNewTeamRating,enemyDiffRating,enemyMmr,"..
    "enemyTeamName,enemyPlayerName1,enemyPlayerName2,enemyPlayerName3,enemyPlayerName4,"..
    "enemyPlayerName5,enemyPlayerClass1,enemyPlayerClass2,enemyPlayerClass3,enemyPlayerClass4,"..
    "enemyPlayerClass5,enemyPlayerRace1,enemyPlayerRace2,enemyPlayerRace3,enemyPlayerRace4,"..
    "enemyPlayerRace5,enemyFaction";
    if(dataFormat == ArenaStatsFormat) then
        return true;
    end

    if(string.find(data[1], ",", 711) == 714 or string.find(data[1], ",", 711) == 715) then
        return true;
    end
   return false;
end

local function checkDataSource_ArenaAnalytics(data)
    if(data[1]:sub(1, 15) == "ArenaAnalytics:") then
        return true;
    end
   return false;
end

function Import:determineImportSource(data)
    if(data and #data[1] > 0) then
        ArenaAnalytics:Log(type(data[1]), #data[1]);

        -- Identify ArenaAnalytics
        if(checkDataSource_ArenaAnalytics(data)) then
            return "ArenaAnalytics";
        end

        -- Identify ArenaStats
        if (checkDataSource_ArenaStats(data)) then
            return "ArenaStats";
        end
    end

    -- Fallback to invalid
    return "Invalid";
end

function Import:reset()
    ArenaAnalyticsScrollFrame.importDataBtn:Enable();
    ArenaAnalyticsScrollFrame.importDataBox:SetText("");
    ArenaAnalytics.AAtable:RefreshLayout(true);

    cachedValues = {};
    cachedArenas = {};
    isImporting = false;
end

function Import:tryHide()
    if(ArenaAnalyticsScrollFrame.importFrame ~= nil and ArenaAnalytics:hasStoredMatches()) then
        ArenaAnalyticsScrollFrame.importDataBtn:Disable();
        ArenaAnalyticsScrollFrame.importDataBox:SetText("");
        ArenaAnalyticsScrollFrame.importFrame:Hide();
        ArenaAnalyticsScrollFrame.importFrame = nil;
    end
end

function Import:parseRawData(data)
    local dataSource = Import:determineImportSource(data);
    
    if(isImporting) then
        ArenaAnalytics:Print("Another import already in progress!");
    elseif(ArenaAnalytics:hasStoredMatches()) then
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
        if(dataSource == "ArenaStats") then
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
                
                -- Gather all ArenaStats values
                cachedValues = {}
                separator = ","
                arenasRaw:gsub("([^"..separator.."]*)"..separator, function(c)
                    table.insert(cachedValues, c)
                end);

                Import:parseCachedValues_ArenaStats(cachedArenas, 1);
            end
        elseif(dataSource == "ArenaAnalytics") then
            -- Remove heading
            local arenasRaw = string.sub(data[1], 1061)
            -- Split into arenas
            local _, numberOfArenas = arenasRaw:gsub(",","");
            numberOfArenas = numberOfArenas/91;
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

function Import:parseCachedValues_ArenaStats(nextIndex)
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
            local arenaTable = {
                ["isRated"] = arena[1],
                ["startTime"] = arena[2],
                ["endTime"] = arena[3],
                ["zoneId"] = arena[4],
                ["duration"] = arena[5],
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

            arenasParsedThisFrame = arenasParsedThisFrame + 1;
            table.insert(cachedArenas, arenaTable)
            arena = {}

            if(arenasParsedThisFrame >= 500 and i < #cachedValues) then
                -- Call function to continue next frame
                C_Timer.After(0, function() Import:parseCachedValues_ArenaStats(cachedArena, i + 1) end);
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

        local unixDate = tonumber(arena["startTime"])    

        local arena = {
            ["isRated"] = (arena["isRated"] == "YES"),
            ["date"] = unixDate,
            ["season"] = ArenaAnalytics:computeSeasonFromMatchDate(unixDate),
            ["map"] = ArenaAnalytics.AAmatch:getMapNameById(tonumber(arena["zoneId"])), 
            ["bracket"] = ArenaAnalytics:getBracketFromTeamSize(size),
            ["duration"] = tonumber(arena["duration"]) or 0,
            ["team"] = Import:createGroupTable_ArenaStats(arena, "team", size),
            ["rating"] = tonumber(arena["newTeamRating"]), 
            ["ratingDelta"] = tonumber(arena["diffRating"]),
            ["mmr"] = tonumber(arena["mmr"]), 
            ["enemyTeam"] = Import:createGroupTable_ArenaStats(arena, "enemy", size),
            ["enemyRating"] = tonumber(arena["enemyNewTeamRating"]), 
            ["enemyRatingDelta"] = tonumber(arena["enemyDiffRating"]),
            ["enemyMmr"] = tonumber(arena["enemyMmr"]),
            ["comp"] = nil,
            ["enemyComp"] = nil,
            ["won"] = arena["teamColor"] == arena["winnerColor"] and true or false,
            ["firstDeath"] = nil
        }

        table.sort(arena["team"], function(a, b)
            local name = UnitName("player");
            local prioA = a["name"] == name and 1 or 2;
            local prioB = b["name"] == name and 1 or 2;
            local sameClass = a["class"] == b["class"];
            return prioA < prioB or (prioA == prioB and a["class"] < b["class"]) or (prioA == prioB and sameClass and a["name"] < b["name"])
        end)

        table.insert(MatchHistoryDB, arena);
        arenasImportedThisFrame = arenasImportedThisFrame + 1;

        if(arenasImportedThisFrame >= 500 and i < #cachedArenas) then
            C_Timer.After(0, function() Import:addCachedArenasToMatchHistory_ArenaStats(i + 1) end);
            return;
        end        
    end

    Import:completeImport();
end

-- ArenaAnalytics import
function Import:parseCachedValues_ArenaAnalytics(nextIndex)
    if(nextIndex == nil) then
        nextIndex = 1;
    end

    local arenasParsedThisFrame = 0;
    local arena = {}
    
    local finishedParsing = false;

    for i = nextIndex, #cachedValues do
        if(i%91 ~= 0) then
            table.insert(arena, cachedValues[i])
        else
            local arenaTable = {
                ["date"] = arena[1],
                ["season"] = arena[2],
                ["bracket"] = arena[3],
                ["map"] = arena[4],
                ["duration"] = arena[5],
                ["won"] = arena[6] == "1",
                ["isRated"] = arena[7] == "1",
                ["rating"] = arena[8],
                ["mmr"] = arena[9],
                ["enemyRating"] = arena[10],
                ["enemyMmr"] = arena[11],
                ["party1Name"] = arena[12], -- Party names
                ["party2Name"] = arena[13],
                ["party3Name"] = arena[14],
                ["party4Name"] = arena[15],
                ["party5Name"] = arena[16],
                ["party1Race"] = arena[17], -- Party races
                ["party2Race"] = arena[18],
                ["party3Race"] = arena[19],
                ["party4Race"] = arena[20],
                ["party5Race"] = arena[21],
                ["party1Class"] = arena[22], -- Party classes
                ["party2Class"] = arena[23],
                ["party3Class"] = arena[24],
                ["party4Class"] = arena[25],
                ["party5Class"] = arena[26],
                ["party1Spec"] = arena[27], -- Party Specs
                ["party2Spec"] = arena[28],
                ["party3Spec"] = arena[29],
                ["party4Spec"] = arena[30],
                ["party5Spec"] = arena[31],
                ["party1Kills"] = arena[32], -- Party Kills stats
                ["party2Kills"] = arena[33],
                ["party3Kills"] = arena[34],
                ["party4Kills"] = arena[35],
                ["party5Kills"] = arena[36],
                ["party1Deaths"] = arena[37], -- Party Death stats
                ["party2Deaths"] = arena[38],
                ["party3Deaths"] = arena[39],
                ["party4Deaths"] = arena[40],
                ["party5Deaths"] = arena[41],
                ["party1Damage"] = arena[42], -- Party Damage stats
                ["party2Damage"] = arena[43],
                ["party3Damage"] = arena[44],
                ["party4Damage"] = arena[45],
                ["party5Damage"] = arena[46],
                ["party1Healing"] = arena[47], -- Party Healing stats
                ["party2Healing"] = arena[48],
                ["party3Healing"] = arena[49],
                ["party4Healing"] = arena[50],
                ["party5Healing"] = arena[51],
                ["enemy1Name"] = arena[52], -- Enemy names
                ["enemy2Name"] = arena[53],
                ["enemy3Name"] = arena[54],
                ["enemy4Name"] = arena[55],
                ["enemy5Name"] = arena[56],
                ["enemy1Race"] = arena[57], -- Enemy races
                ["enemy2Race"] = arena[58],
                ["enemy3Race"] = arena[59],
                ["enemy4Race"] = arena[60],
                ["enemy5Race"] = arena[61],
                ["enemy1Class"] = arena[62], -- Enemy classes
                ["enemy2Class"] = arena[63],
                ["enemy3Class"] = arena[64],
                ["enemy4Class"] = arena[65],
                ["enemy5Class"] = arena[66],
                ["enemy1Spec"] = arena[67], -- Enemy Specs
                ["enemy2Spec"] = arena[68],
                ["enemy3Spec"] = arena[69],
                ["enemy4Spec"] = arena[70],
                ["enemy5Spec"] = arena[71],
                ["enemy1Kills"] = arena[72], -- Enemy Kills stats
                ["enemy2Kills"] = arena[73],
                ["enemy3Kills"] = arena[74],
                ["enemy4Kills"] = arena[75],
                ["enemy5Kills"] = arena[76],
                ["enemy1Deaths"] = arena[77], -- Enemy Death stats
                ["enemy2Deaths"] = arena[78],
                ["enemy3Deaths"] = arena[79],
                ["enemy4Deaths"] = arena[80],
                ["enemy5Deaths"] = arena[81],
                ["enemy1Damage"] = arena[82], -- Enemy Damage stats
                ["enemy2Damage"] = arena[83],
                ["enemy3Damage"] = arena[84],
                ["enemy4Damage"] = arena[85],
                ["enemy5Damage"] = arena[86],
                ["enemy1Healing"] = arena[87], -- Enemy Healing stats
                ["enemy2Healing"] = arena[88],
                ["enemy3Healing"] = arena[89],
                ["enemy4Healing"] = arena[90],
                ["enemy5Healing"] = arena[91],
            }

            arenasParsedThisFrame = arenasParsedThisFrame + 1;
            table.insert(cachedArenas, arenaTable)
            arena = {}

            if(arenasParsedThisFrame >= 500 and i < #cachedValues) then
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
            ["comp"] = ArenaAnalytics.AAmatch:getArenaComp(team, cachedArena["bracket"]),
            ["enemyComp"] = ArenaAnalytics.AAmatch:getArenaComp(enemyTeam, cachedArena["bracket"]),
            ["won"] = cachedArena["won"] or false,
            ["firstDeath"] = cachedArena["firstDeath"] or nil
        }

        table.sort(arena["team"], function(a, b)
            local name = UnitName("player");
            local prioA = a["name"] == name and 1 or 2;
            local prioB = b["name"] == name and 1 or 2;
            local sameClass = a["class"] == b["class"];
            return prioA < prioB or (prioA == prioB and a["class"] < b["class"]) or (prioA == prioB and sameClass and a["name"] < b["name"])
        end)

        table.insert(MatchHistoryDB, arena);
        arenasImportedThisFrame = arenasImportedThisFrame + 1;

        if(arenasImportedThisFrame >= 500 and i < #cachedArenas) then
            C_Timer.After(0, function() Import:addCachedArenasToMatchHistory_ArenaAnalytics(i + 1) end);
            return;
        end        
    end

    Import:completeImport();
end

function Import:completeImport()
    Import:reset();
    Import:tryHide();

    table.sort(MatchHistoryDB, function (k1,k2)
        if (k1["date"] and k2["date"]) then
            return k1["date"] < k2["date"];
        end
    end);

    ArenaAnalytics:recomputeSessionsForMatchHistoryDB();
    ArenaAnalytics:updateLastSession();    
	ArenaAnalytics.unsavedArenaCount = #MatchHistoryDB;
    ArenaAnalytics.Filter:refreshFilters();

    ArenaAnalytics:Print("Import complete. " .. #MatchHistoryDB .. " arenas added!");
end

function Import:createGroupTable_ArenaStats(arena, groupType, size)
    local group = {}
    for i = 1, size do
        local name = arena[groupType .. "PlayerName" .. i];
        local race = arena[groupType .. "PlayerRace" .. i];
        local class = arena[groupType .. "PlayerClass" .. i];
        local isDK = class == "DEATHKNIGHT" and true or false;

        if(name ~= "" and race ~= "" and class ~= "") then 
            local player = {
                ["GUID"] = nil,
                ["name"] = name or "",
                ["killingBlows"] = nil,
                ["deaths"] = nil,
                ["faction"] = ArenaAnalytics.Constants:GetFactionByRace(race),
                ["race"] = race,
                ["class"] = isDK and "Death Knight" or string.lower(class):gsub("^%l", string.upper),
                ["damageDone"] = nil,
                ["healingDone"] = nil,
                ["spec"] = nil
            }
            table.insert(group, player);
        end
    end

    -- Place player first in the arena party group, sort rest 
	table.sort(group, function(a, b)
        local name = UnitName("player");
		local prioA = string.find(a["name"], name) and 1 or 2;
		local prioB = string.find(b["name"], name) and 1 or 2;
		local sameClass = a["class"] == b["class"]

        if (prioA < prioB) then
            return true;
        end

        if (prioA == prioB and a["class"] < b["class"]) then
            return true;
        end

		if (prioA == prioB and sameClass and a["name"] < b["name"]) then
            return true;
        end

        return false;
	end);

    return group;
end

-- TODO: Update for ArenaAnalytics!
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
                ["killingBlows"] = arena[groupType ..  i .. "Kills"],
                ["deaths"] = arena[groupType ..  i .. "Deaths"],
                ["faction"] = ArenaAnalytics.Constants:GetFactionByRace(race),
                ["race"] = race,
                ["class"] = class,
                ["damageDone"] = arena[groupType ..  i .. "Damage"],
                ["healingDone"] = arena[groupType ..  i .. "Healing"],
                ["spec"] = arena[groupType ..  i .. "Spec"]
            }
            table.insert(group, player);
        end
    end

    -- Place player first in the arena party group, sort rest 
	table.sort(group, function(a, b)
        local name = UnitName("player");
		local prioA = string.find(a["name"], name) and 1 or 2;
		local prioB = string.find(b["name"], name) and 1 or 2;
		local sameClass = a["class"] == b["class"]

        if (prioA < prioB) then
            return true;
        end

        if (prioA == prioB and a["class"] < b["class"]) then
            return true;
        end

		if (prioA == prioB and sameClass and a["name"] < b["name"]) then
            return true;
        end

        return false;
	end);

    return group;
end

-- TODO: Update to include all desired export data
local exportTable = {}
-- Returns a CSV-formatted string using MatchHistoryDB info
function Export:combineExportCSV()
    if(not ArenaAnalytics:hasStoredMatches()) then
        return "No games to export!";
    end

    exportTable = {}
    local exportHeader = "ArenaAnalytics:".. 

    -- Match data
    "date,season,bracket,map,duration,won,isRated,rating,mmr,enemyRating,enemyMMR,"..

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

    Export:addMatchesToExport()
end

function Export:addMatchesToExport(nextIndex)
    nextIndex = nextIndex or 1;
    
    arenasAddedThisFrame = 0;

    local teams = {"team", "enemyTeam"};
    local playerData = {"name", "race", "class", "spec", "kills", "deaths", "damage", "healing"};

    for i = nextIndex, #MatchHistoryDB do
        local match = MatchHistoryDB[i];

        ArenaAnalytics:Log(match["rating"], match["mmr"], match["enemyRating"], match["enemyMmr"])
        
        -- Add match data
        local matchCSV = match["date"] .. ","
        .. (match["season"] or "") .. ","
        .. (match["bracket"] or "") .. ","
        .. (match["map"] or "") .. ","
        .. (match["duration"] or "") .. ","
        .. (match["won"] and "1" or "0") .. ","
        .. (match["isRated"] and "1" or "0") .. ","
        .. (match["rating"] or "").. ","
        .. (match["mmr"] or "") .. ","
        .. (match["enemyRating"] or "") .. ","
        .. (match["enemyMmr"] or "") .. ","

        -- Add team data 
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

        if(arenasAddedThisFrame >= 500 and i < #MatchHistoryDB) then
            ArenaAnalytics:Log(i);
            C_Timer.After(0, function() Export:addMatchesToExport(i + 1) end);
            return;
        end
    end

    Export:FinalizeExportCSV();
end

function Export:FinalizeExportCSV()
    -- Show export with the new CSV string
    if (ArenaAnalytics:hasStoredMatches()) then
        ArenaAnalyticsScrollFrame.exportFrameContainer:Show();
        ArenaAnalyticsScrollFrame.exportFrame:SetText(table.concat(exportTable, "\n"));
    else
        ArenaAnalyticsScrollFrame.exportFrameContainer:Hide();
    end

    exportTable = {}
end