local _, ArenaAnalytics = ...;
ArenaAnalytics.AAimport = {};

local AAimport = ArenaAnalytics.AAimport;

function AAimport:parseRawData(data)
    if(not AAimport:isDataValid(data)) then
        ArenaAnalytics:Print("Import data is corrupted, not valid, or empty. Make sure to copy the whole ArenaStats export text.")
        AAimport:reset();
    else
        ArenaAnalytics:Print("Importing! Please wait...")
        -- Remove heading
        local arenasRaw = string.sub(data, 712)
        -- Split into arenas
        local _, numberOfArenas = arenasRaw:gsub(",","")
        numberOfArenas = numberOfArenas/48
        if (numberOfArenas ~= math.floor(numberOfArenas)) then
            ArenaAnalytics:Print("Data is corrupted! No arenas were coppied.")
            AAimport:reset();
        else
            ArenaAnalytics:Print(numberOfArenas .. " arenas found! Importing!")
            
            local everyValue = {}
            sep = ","
            arenasRaw:gsub("([^"..sep.."]*)"..sep, function(c)
            table.insert(everyValue, c)
            end)
            local arenas = {}
            local arena = {}
            for i = 1, #everyValue do
                if(i%48 ~= 0) then
                    table.insert(arena, everyValue[i])
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
                    table.insert(arenas, arenaTable)
                    arena = {}
                end
            end

            for i = 1, #arenas do
                local arena = arenas[i]
                local size = 0
                for i = 1, 5 do
                    if (arena["teamPlayerName" .. i] ~= "") then
                        size = i
                    else
                        break
                    end
                end
                size = size == 1 and 2 or size;
                size = size == 4 and 5 or size;
                local arenaDB = {
                    ["dateInt"] = tonumber(arena["startTime"]),
                    ["map"] =  ArenaAnalytics.AAmatch:getMapNameById(tonumber(arena["zoneId"])), 
                    ["duration"] = AAimport:getDuration(tonumber(arena["duration"])),
                    ["team"] = AAimport:createGroupTable(arena, "team", size),
                    ["rating"] = arena["newTeamRating"] == "" and "SKIRMISH" or tonumber(arena["newTeamRating"]), 
                    ["ratingDelta"] = tonumber(arena["diffRating"]),
                    ["mmr"] = arena["mmr"] == "" and "-" or tonumber(arena["mmr"]), 
                    ["enemyTeam"] = AAimport:createGroupTable(arena, "enemy", size),
                    ["enemyRating"] = arena["enemyNewTeamRating"] == "" and "SKIRMISH" or tonumber(arena["enemyNewTeamRating"]), 
                    ["enemyRatingDelta"] = tonumber(arena["enemyDiffRating"]),
                    ["enemyMmr"] = arena["enemyMmr"] == "" and "-" or tonumber(arena["enemyMmr"]),
                    ["comp"] = {"",""},
                    ["enemyComp"] = {"",""},
                    ["won"] = arena["teamColor"] == arena["winColor"] and true or false,
                    ["isRanked"] = arena["isRanked"] == "YES" and true or false,
                    ["check"] = false
                }
                table.sort(arenaDB["team"], function(a, b)
                    local prioA = a["name"] == UnitName("player")and 1 or 2
                    local prioB = b["name"] == UnitName("player") and 1 or 2
                    local sameClass = a["class"] == b["class"]
                    return prioA < prioB or (prioA == prioB and a["class"] < b["class"]) or (prioA == prioB and sameClass and a["name"] < b["name"])
                end)
                table.insert(ArenaAnalyticsDB[size .. "v" .. size], arenaDB)
            end
            ArenaAnalytics:Print(numberOfArenas .. " arenas added!")
            AAimport:reset()
        end        
    end
end

function AAimport:isDataValid(data)
    if(string.find(data, ",", 711) == 714 or string.find(data, ",", 711) == 715) then
        return true;
    end
   return false;
end

function AAimport:reset()
    ArenaAnalyticsScrollFrame.importData:Enable();
    ArenaAnalyticsScrollFrame.importDataBox:SetText("");
    ArenaAnalytics.AAtable:RefreshLayout(true);
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