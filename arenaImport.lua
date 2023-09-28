local _, ArenaAnalytics = ...;
ArenaAnalytics.AAimport = {};

local AAimport = ArenaAnalytics.AAimport;

local isImporting = false;
local cachedValues = {};
local cachedArenas_ArenaStats = {};

ArenaImportPasteString = "";

function AAimport:determineImportSource(data)
    -- Identify ArenaStats
    if (AAimport:isDataValid(data)) then
        return "ArenaStats";
    end

    -- Identify ArenaAnalytics

    -- Fallback to invalid
    return "Invalid";
end

function AAimport:isDataValid(data)
    if(string.find(data, ",", 711) == 714 or string.find(data, ",", 711) == 715) then
        return true;
    end
   return false;
end

function AAimport:reset()
    ArenaAnalyticsScrollFrame.importDataBtn:Enable();
    ArenaAnalyticsScrollFrame.importDataBox:SetText("");
    ArenaAnalytics.AAtable:RefreshLayout(true);

    cachedValues = {};
    cachedArenas_ArenaStats = {};
    isImporting = false;
end

function AAimport:tryHide()
    if(ArenaAnalyticsScrollFrame.importFrame ~= nil and ArenaAnalytics:hasStoredMatches()) then
        ArenaAnalyticsScrollFrame.importDataBtn:Disable();
        ArenaAnalyticsScrollFrame.importDataBox:SetText("");
        ArenaAnalyticsScrollFrame.importFrame:Hide();
        ArenaAnalyticsScrollFrame.importFrame = nil;
    end
end

function AAimport:parseRawData(data)
    local dataSource = AAimport:determineImportSource(data);
    
    if (data ~= nil) then 
        ArenaAnalytics:Log("Import data length: " .. #data);
    end

    if(isImporting) then
        ArenaAnalytics:Print("Another import already in progress!");
    elseif(ArenaAnalytics:hasStoredMatches()) then
        ArenaAnalytics:Print("Import failed due to existing stored matches!");
        AAimport:reset();
    elseif(dataSource == "Invalid" or not AAimport:isDataValid(data)) then
        ArenaAnalytics:Print("Import data is corrupted, not valid, or empty. Make sure to copy the whole ArenaStats export text.");
        AAimport:reset();
    else
        ArenaAnalytics:Print("Importing! Please wait...")
        isImporting = true;

        -- Remove heading
        local arenasRaw = string.sub(data, 712)
        -- Split into arenas
        local _, numberOfArenas = arenasRaw:gsub(",","")
        numberOfArenas = numberOfArenas/48
        if (numberOfArenas ~= math.floor(numberOfArenas)) then
            ArenaAnalytics:Print("Data is corrupted! No arenas were copied.")
            AAimport:reset();
        else
            ArenaAnalytics:Print(numberOfArenas .. " arenas found! Importing!")
            
            -- Gather all ArenaStats values
            cachedValues = {}
            separator = ","
            arenasRaw:gsub("([^"..separator.."]*)"..separator, function(c)
                table.insert(cachedValues, c)
            end);

            local cachedArenas_ArenaStats = {}
            AAimport:parseCachedValues_ArenaStats(1);
        end        
    end
    
    if(not isImporting) then
        -- Hide the dialog if we have existing matches
        AAimport:tryHide();
    end
end

function AAimport:parseCachedValues_ArenaStats(nextIndex)
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
            table.insert(cachedArenas_ArenaStats, arenaTable)
            arena = {}

            if(arenasParsedThisFrame >= 500 and i < #cachedValues) then
                -- Call function to continue next frame
                C_Timer.After(0, function() AAimport:parseCachedValues_ArenaStats(i + 1) end);
                return;
            else
                finishedParsing = true;
            end
        end
    end

    if(finishedParsing) then
        AAimport:addCachedArenasToMatchHistory_ArenaStats(1);
    end
end

function AAimport:addCachedArenasToMatchHistory_ArenaStats(nextIndex)
    if(nextIndex == nil) then
        nextIndex = 1;
    end

    local arenasImportedThisFrame = 0;

    for i = nextIndex, #cachedArenas_ArenaStats do
        local arena = cachedArenas_ArenaStats[i]
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
            ["isRated"] = arena["isRanked"] == "YES" and true or false,
            ["date"] = unixDate,
            ["season"] = ArenaAnalytics:computeSeasonFromMatchDate(unixDate),
            ["map"] = ArenaAnalytics.AAmatch:getMapNameById(tonumber(arena["zoneId"])), 
            ["bracket"] = ArenaAnalytics:getBracketFromTeamSize(size),
            ["duration"] = tonumber(arena["duration"]) or 0,
            ["team"] = AAimport:createGroupTable(arena, "team", size),
            ["rating"] = tonumber(arena["newTeamRating"]), 
            ["ratingDelta"] = tonumber(arena["diffRating"]),
            ["mmr"] = tonumber(arena["mmr"]), 
            ["enemyTeam"] = AAimport:createGroupTable(arena, "enemy", size),
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

        if(arenasImportedThisFrame >= 500 and i < #cachedArenas_ArenaStats) then
            C_Timer.After(0, function() AAimport:addCachedArenasToMatchHistory_ArenaStats(i + 1) end);
            return;
        end        
    end

    AAimport:completeImport_ArenaStats();
end

function AAimport:completeImport_ArenaStats()
    AAimport:reset();
    AAimport:tryHide();

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

function AAimport:createGroupTable(arena, groupType, size)
    local group = {}
    for i = 1, size do
        local name = arena[groupType .. "PlayerName" .. i];
        local race = arena[groupType .. "PlayerRace" .. i];
        local class = arena[groupType .. "PlayerClass" .. i];
        local isDK = class == "DEATHKNIGHT" and true or false;

        if(name ~= "" and race ~= "" and class ~= "") then 
            local player = {
                ["GUID"] = "",
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