local _, ArenaAnalytics = ...;
ArenaAnalytics.AAimport = {};

local AAimport = ArenaAnalytics.AAimport;

local isImporting = false;
local cachedValues = {};
local cachedArenas = {};
local cachedBracketDB = {};

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
    cachedArenas = {};
    cachedBracketDB = {};
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
        ArenaAnalytics:Print("Import data length: " .. #data);
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

            local cachedArenas = {}
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
                ["isRanked"] = arena[1],
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
                C_Timer.After(0, function() AAimport:parseCachedValues_ArenaStats(i + 1) end);
                return;
            else
                finishedParsing = true;
            end
        end
    end

    if(finishedParsing) then
        AAimport:addCachedArenasToBracketDB_ArenaStats(1);
    end
end

function AAimport:addCachedArenasToBracketDB_ArenaStats(nextIndex)
    if(nextIndex == nil) then
        nextIndex = 1;
    end

    local arenasImportedThisFrame = 0;

    for i = nextIndex, #cachedArenas do
        local arena = cachedArenas[i]
        local size = 0
        for i = 1, 5 do
            if (arena["teamPlayerName" .. i] ~= "" or arena["enemyPlayerName" .. i] ~= "") then
                size = i
            else
                break
            end
        end
        size = size == 1 and 2 or size;
        size = size == 4 and 5 or size;

        local hasRating = (arena["newTeamRating"] ~= nil and arena["newTeamRating"] ~= "");
        local hasMmr = (arena["mmr"] ~= nil and arena["mmr"] ~= "");
        local hasEnemyRating = (arena["enemyNewTeamRating"] ~= nil and arena["enemyNewTeamRating"] ~= "");
        local hasEnemyMmr = (arena["enemyMmr"] ~= nil and arena["enemyMmr"] ~= "");
        
        local arenaDB = {
            ["dateInt"] = tonumber(arena["startTime"]),
            ["map"] = ArenaAnalytics.AAmatch:getMapNameById(tonumber(arena["zoneId"])), 
            ["duration"] = AAimport:getDuration(tonumber(arena["duration"])),
            ["team"] = AAimport:createGroupTable(arena, "team", size),
            ["rating"] = hasRating and tonumber(arena["newTeamRating"]) or "SKIRMISH", 
            ["ratingDelta"] = tonumber(arena["diffRating"]),
            ["mmr"] = hasMmr and tonumber(arena["mmr"]) or "", 
            ["enemyTeam"] = AAimport:createGroupTable(arena, "enemy", size),
            ["enemyRating"] = hasEnemyRating and tonumber(arena["enemyNewTeamRating"]) or "-", 
            ["enemyRatingDelta"] = hasEnemyRating and tonumber(arena["enemyDiffRating"]) or "",
            ["enemyMmr"] = hasEnemyMmr and tonumber(arena["enemyMmr"]) or "-",
            ["comp"] = {"",""},
            ["enemyComp"] = {"",""},
            ["won"] = arena["teamColor"] == arena["winnerColor"] and true or false,
            ["isRanked"] = arena["isRanked"] == "YES" and true or false,
            ["check"] = false
        }

        table.sort(arenaDB["team"], function(a, b)
            local prioA = a["name"] == UnitName("player") and 1 or 2;
            local prioB = b["name"] == UnitName("player") and 1 or 2;
            local sameClass = a["class"] == b["class"];
            return prioA < prioB or (prioA == prioB and a["class"] < b["class"]) or (prioA == prioB and sameClass and a["name"] < b["name"])
        end)

        table.insert(ArenaAnalyticsDB[size .. "v" .. size], arenaDB);
        arenasImportedThisFrame = arenasImportedThisFrame + 1;

        if(arenasImportedThisFrame >= 500 and i < #cachedArenas) then
            C_Timer.After(0, function() AAimport:addCachedArenasToBracketDB_ArenaStats(i + 1) end);
            return;
        end        
    end

    AAimport:completeImport_ArenaStats();
end

function AAimport:completeImport_ArenaStats()
    AAimport:reset();
    AAimport:tryHide();

    local totalArenas = #ArenaAnalyticsDB["2v2"] + #ArenaAnalyticsDB["3v3"] + #ArenaAnalyticsDB["5v5"];
    ArenaAnalytics:Print("Import complete. " .. totalArenas .. " arenas added!");
end

function AAimport:createGroupTable(arena, groupType, size)
    local group = {}
    for i = 1, size do
        local isDK = arena[groupType .. "PlayerClass" .. i] == "DEATHKNIGHT" and true or false;
        local player = {
            ["GUID"] = "",
            ["name"] = arena[groupType .. "PlayerName" .. i],
            ["killingBlows"] = "",
            ["deaths"] = "",
            ["faction"] = "",
            ["race"] = arena[groupType .. "PlayerRace" .. i],
            ["class"] = isDK and "Death Knight" or string.lower(arena[groupType .. "PlayerClass" .. i]):gsub("^%l", string.upper),
            ["filename"] = "",
            ["damageDone"] = "",
            ["healingDone"] = "",
            ["classIcon"] = isDK and ArenaAnalyticsGetClassIcon("Death Knight") or ArenaAnalyticsGetClassIcon(string.lower(arena[groupType .. "PlayerClass" .. i]):gsub("^%l", string.upper)),
            ["spec"] = ""
        }
        table.insert(group, player)
    end
    return group;
end

function AAimport:getDuration(duration)
    if(duration >= 60) then
        local mins = math.floor(duration/60)
        local secs = duration - (mins * 60)
        return mins .. " Min " .. secs .. " Sec"
    else
        return duration .. " Sec"
    end
end