local _, ArenaAnalytics = ...;
ArenaAnalytics.Import = {};
ArenaAnalytics.Export = {};

local Import = ArenaAnalytics.Import;
local Export = ArenaAnalytics.Export;

local isImporting = false;
local cachedValues = {};
local cachedArenas = {};

ArenaImportPasteString = "";

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
    if(data[1]:sub(1, 15) == "ArenaAnalytics:") then
        return true;
    end
   return false;
end

function Import:determineImportSource(data)
    if(data and #data[1] > 0) then
        -- Identify ArenaAnalytics
        if(checkDataSource_ArenaAnalytics(data)) then
            return "ArenaAnalytics";
        end

        -- Identify ArenaStats_Wotlk
        if (checkDataSource_ArenaStats_Wotlk(data)) then
            return "ArenaStats_Wotlk";
        end

        if(checkDataSource_ArenaStats_Cata(data)) then
            return "ArenaStats_Cata";
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

---------------------------------
-- General import pipeline startpoint
---------------------------------

function Import:parseRawData(data)
    if(data == nil or tostring(data[1]) == nil) then
        ArenaAnalytics:Log("Invalid data for import attempt.. Bailing out immediately..");
        return;
    end

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

            arenasParsedThisFrame = arenasParsedThisFrame + 1;
            table.insert(cachedArenas, arenaTable)
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

            arenasParsedThisFrame = arenasParsedThisFrame + 1;
            table.insert(cachedArenas, arenaTable);
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
            ["map"] = ArenaAnalytics.AAmatch:getMapNameById(tonumber(arena["zoneId"])), 
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
            ["comp"] = ArenaAnalytics.AAmatch:getArenaComp(group, bracket),
            ["enemyComp"] = ArenaAnalytics.AAmatch:getArenaComp(enemyGroup, bracket),
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
                ["faction"] = ArenaAnalytics.Constants:GetFactionByRace(race),
                ["race"] = race,
                ["class"] = isDK and "Death Knight" or class and string.lower(class):gsub("^%l", string.upper) or nil,
                ["damage"] = nil,
                ["healing"] = nil,
                ["spec"] = spec
            }
            table.insert(group, player);
        end
    end

    -- TODO: Custom function to do this consistently
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
        if(i%91 ~= 0) then
            table.insert(arena, cachedValues[i])
        else
            local arenaTable = {
                ["date"] = arena[1],
                ["season"] = arena[2],
                ["bracket"] = arena[3],
                ["map"] = arena[4],
                ["duration"] = tonumber(arena[5]) or 0,
                ["won"] = (arena[6] ~= "") and (arena[6] == "1" and "1" or "0") or nil, -- Won, lost or nil
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
            ["comp"] = ArenaAnalytics.AAmatch:getArenaComp(team, cachedArena["bracket"]),
            ["enemyComp"] = ArenaAnalytics.AAmatch:getArenaComp(enemyTeam, cachedArena["bracket"]),
            ["won"] = cachedArena["won"],
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
                ["kills"] = arena[groupType ..  i .. "Kills"],
                ["deaths"] = arena[groupType ..  i .. "Deaths"],
                ["faction"] = ArenaAnalytics.Constants:GetFactionByRace(race),
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

---------------------------------
-- ArenaAnalytics export
---------------------------------

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

        if(arenasAddedThisFrame >= 1000 and i < #MatchHistoryDB) then
            C_Timer.After(0, function() Export:addMatchesToExport(i + 1) end);
            return;
        end
    end

    Export:FinalizeExportCSV();
end

local function formatNumber(num)
    ForceDebugNilError(num);
    local left,num,right = string.match(num,'^([^%d]*%d)(%d*)(.-)')
    return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

function Export:FinalizeExportCSV()
    -- Show export with the new CSV string
    if (ArenaAnalytics:hasStoredMatches()) then
        ArenaAnalyticsScrollFrame.exportFrameContainer:Show();
        ArenaAnalyticsScrollFrame.exportFrame:SetText(table.concat(exportTable, "\n"));
	    ArenaAnalyticsScrollFrame.exportFrame:HighlightText();

        ArenaAnalyticsScrollFrame.exportFrameContainer.totalText:SetText("Total arenas: " .. formatNumber(#exportTable - 1));
        ArenaAnalyticsScrollFrame.exportFrameContainer.lengthText:SetText("Export length: " .. formatNumber(#ArenaAnalyticsScrollFrame.exportFrame:GetText()));
    else
        ArenaAnalyticsScrollFrame.exportFrameContainer:Hide();
    end

    exportTable = {}
end