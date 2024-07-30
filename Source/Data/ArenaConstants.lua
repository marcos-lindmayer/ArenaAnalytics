local _, ArenaAnalytics = ...; -- Addon Namespace
local Constants = ArenaAnalytics.Constants;

-------------------------------------------------------------------------

Constants.currentSeasonStartInt = 1687219201;

-- (Assumes timestamp of 00:00:01 GMT and no difference between regions for now)
local seasonStartAndEndTimes = {
    {1623801601, 1630972801}, -- season 1 (June 16, 2021 - Sept. 7, 2021)
    {1631577601, 1641776401}, -- season 2 (Sept. 14, 2021 - Jan. 10, 2022)
    {1642381201, 1651536001}, -- season 3 (Jan. 17, 2022 - May 3, 2022)
    {1652313601, 1661731201}, -- season 4 (May 12, 2022 - Aug. 29, 2022)
    {1664841601, 1673226001}, -- season 5 (Oct. 4, 2022 - Jan. 9, 2023)
    {1673917201, 1685318401}, -- season 6 (Jan. 17, 2023 - May 29, 2023)
    {1687219201, 1696363200}, -- season 7 (June 20, 2023 - Oct 3, 2023)
    {nil, nil}, -- season 8 (Unknown start)
}

-- Attempts to get the Classic season by timestamp. Returns season and boolean for isPostSeason
function ArenaAnalytics:computeSeasonFromMatchDate(unixDate)
    local matchTime = tonumber(unixDate);
    if(matchTime) then
        -- before season 1 (Generally bugged matches)
        if(matchTime < seasonStartAndEndTimes[1][1]) then
            return -1;
        end

        for season = 1, #seasonStartAndEndTimes do
            local startTime = seasonStartAndEndTimes[season][1];
            local endTime = seasonStartAndEndTimes[season][2];

            if(startTime and matchTime > startTime) then
                if(not endTime or matchTime < endTime) then
                    return season, false;
                end
                
                local nextSeasonStart = seasonStartAndEndTimes[season+1][1]
                if (not nextSeasonStart or matchTime < nextSeasonStart) then
                    return season, true;
                end
            end
        end
    end

    return nil;
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
}
function Constants:getAddonSpecializationID(class, spec, forceExactSpec)
    if(class == nil) then 
        return nil;
    end

    if(forceExactSpec and spec == nil) then
        return nil;
    end

    local specKey = spec and (class .. "|" .. spec) or class;
    return tonumber(addonSpecializationIDs[specKey]);
end

-- ID to class and spec
local classAndSpecByID = {
    -- Druid
    [0] = {nil, "Druid", nil},
    [1] = {"Druid|Restoration", "Druid", "Restoration", "Healer"},
    [2] = {"Druid|Feral", "Druid", "Feral", "Dps"},
    [3] = {"Druid|Balance", "Druid", "Balance", "Dps"},
    [4] = {"Druid|Guardian", "Druid", "Guardian", "Tank"},
    
    -- Paladin
    [10] = {nil, "Paladin", nil},
    [11] = {"Paladin|Holy", "Paladin", "Holy", "Healer"},
    [12] = {"Paladin|Protection", "Paladin", "Protection", "Tank"},
    [13] = {"Paladin|Preg", "Paladin", "Preg", "Dps"},
    [14] = {"Paladin|Retribution", "Paladin", "Retribution", "Dps"},
    
    -- Shaman
    [20] = {nil, "Shaman", nil},
    [21] = {"Shaman|Restoration", "Shaman", "Restoration", "Healer"},
    [22] = {"Shaman|Elemental", "Shaman", "Elemental", "Dps"},
    [23] = {"Shaman|Enhancement", "Shaman", "Enhancement", "Dps"},

    -- Death Knight
    [30] = {nil, "Death Knight", nil},
    [31] = {"Death Knight|Unholy", "Death Knight", "Unholy", "Dps"},
    [32] = {"Death Knight|Frost", "Death Knight", "Frost", "Dps"},
    [33] = {"Death Knight|Blood", "Death Knight", "Blood", "Tank"},

    -- Hunter
    [40] = {nil, "Hunter", nil},
    [41] = {"Hunter|Beast Mastery", "Hunter", "Beast Mastery", "Dps"},
    [42] = {"Hunter|Marksmanship", "Hunter", "Marksmanship", "Dps"},
    [43] = {"Hunter|Survival", "Hunter", "Survival", "Dps"},

    -- Mage
    [50] = {nil, "Mage", nil},
    [51] = {"Mage|Frost", "Mage", "Frost", "Dps"},
    [52] = {"Mage|Fire", "Mage", "Fire", "Dps"},
    [53] = {"Mage|Arcane", "Mage", "Arcane", "Dps"},

    -- Rogue
    [60] = {nil, "Rogue", nil},
    [61] = {"Rogue|Subtlety", "Rogue", "Subtlety", "Dps"},
    [62] = {"Rogue|Assassination", "Rogue", "Assassination", "Dps"},
    [63] = {"Rogue|Combat", "Rogue", "Combat", "Dps"},
    [64] = {"Rogue|Outlaw", "Rogue", "Outlaw", "Dps"},

    -- Warlock
    [70] = {nil, "Warlock", nil},
    [71] = {"Warlock|Affliction", "Warlock", "Affliction", "Dps"},
    [72] = {"Warlock|Destruction", "Warlock", "Destruction", "Dps"},
    [73] = {"Warlock|Demonology", "Warlock", "Demonology", "Dps"},

    -- Warrior
    [80] = {nil, "Warrior", nil},
    [81] = {"Warrior|Protection", "Warrior", "Protection", "Tank"},
    [82] = {"Warrior|Arms", "Warrior", "Arms", "Dps"},
    [83] = {"Warrior|Fury", "Warrior", "Fury", "Dps"},
    
    -- Priest
    [90] = {nil, "Priest", nil},
    [91] = {"Priest|Discipline", "Priest", "Discipline", "Healer"},
    [92] = {"Priest|Holy", "Priest", "Holy", "Healer"},
    [93] = {"Priest|Shadow", "Priest", "Shadow", "Dps"},
}

-- TODO: Add real priority values (Possible player customizable option?)
function Constants:getSpecPriorityValue(specID)
    return tonumber(specID) or 0
end

function Constants:GetClassAndSpec(specID)
    local data = classAndSpecByID[tonumber(specID)];
    if (not data) then 
        ArenaAnalytics:Log("Failed to find spec for ID: ", specID)
        return nil, nil;
    end

    -- class, spec
    return data[2], data[3];
end

function Constants:GetSpecRole(specID)
    if(not tonumber(specID)) then
        return nil;
    end
    local data = classAndSpecByID[tonumber(specID)];
    assert(data);

    -- class, spec
    return data[4];
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
}

function Constants:GetFactionByRace(race)
    return race and raceToFaction[race] or nil;
end

local arenaTimer = {
    ["default"] = "The Arena battle has begun!",
    ["esES"] = "¡La batalla en arena ha comenzado!",
    ["ptBR"] = "A batalha na Arena começou!",
    ["deDE"] = "Der Arenakampf hat begonnen!",
    ["frFR"] = "Le combat d'arène commence\194\160!",
    ["ruRU"] = "Бой начался!",
    ["itIT"] = "", -- TODO: Check if we can get a value for this
    ["koKR"] = "투기장 전투가 시작되었습니다!",
    ["zhCN"] = "竞技场的战斗开始了！",
    ["zhTW"] = "競技場戰鬥開始了!",
}
arenaTimer["esMX"] = arenaTimer["esES"]
arenaTimer["ptPT"] = arenaTimer["ptBR"]

function Constants:GetArenaTimer()
    if arenaTimer[GetLocale()] then
        return arenaTimer[GetLocale()]
    else
        return arenaTimer["default"]
    end
end

-- Returns class color hex by className
function ArenaAnalytics:GetClassColor(className)
    if(className == nil) then
        return 'ffffffff';
    end
    
    if(className == "Death Knight") then
        return select(4, GetClassColor("DEATHKNIGHT"));
    end
    
    return select(4, GetClassColor(className:upper()));
end

function ArenaAnalytics:ApplyClassColor(text, class)
    return "|c" .. ArenaAnalytics:GetClassColor(class) .. text or "" .."|r";
end

-- Returns class icon path string
function ArenaAnalyticsGetClassIcon(className)
    if(className == nil or className == "") then
        return "";
    end
    
    if(className == "Death Knight") then
        return "Interface\\Icons\\spell_deathknight_classicon";
    else
        return "Interface\\Icons\\classicon_" .. className:lower();
    end
end

-- Returns spec icon path string
function ArenaAnalyticsGetSpecIcon(class, spec)
    if(spec ~= nil) then
        if (spec == "Subtlety") then
            return [[Interface\Icons\ability_stealth]];
        elseif (spec == "Assassination") then
            return [[Interface\Icons\ability_rogue_eviscerate]];
        elseif (spec == "Combat") then
            return [[Interface\Icons\ability_backstab]];
        elseif (spec == "Blood") then
            return [[Interface\Icons\spell_deathknight_bloodpresence]];
        elseif (spec == "Frost" and class == "Death Knight") then
            return [[Interface\Icons\spell_deathknight_frostpresence]];
        elseif (spec == "Unholy") then
            return [[Interface\Icons\spell_deathknight_unholypresence]];
        elseif (spec == "Balance") then
            return [[Interface\Icons\spell_nature_starfall]];
        elseif (spec == "Feral") then
            return [[Interface\Icons\ability_racial_bearform]];
        elseif (spec == "Restoration" and class == "Druid") then
            return [[Interface\Icons\spell_nature_healingtouch]];
        elseif (spec == "Beast Mastery") then
            return [[Interface\Icons\ability_hunter_beasttaming]];
        elseif (spec == "Marksmanship") then
            return [[Interface\Icons\ability_marksmanship]];
        elseif (spec == "Survival") then
            return [[Interface\Icons\ability_hunter_swiftstrike]];
        elseif (spec == "Arcane") then
            return [[Interface\Icons\spell_holy_magicalsentry]];
        elseif (spec == "Fire") then
            return [[Interface\Icons\spell_fire_firebolt02]];
        elseif (spec == "Frost") then
            return [[Interface\Icons\spell_frost_frostbolt02]];
        elseif (spec == "Holy" and class == "Paladin") then
            return [[Interface\Icons\spell_holy_holybolt]];
        elseif (spec == "Protection" and class == "Paladin") then
            return [[Interface\Icons\spell_holy_devotionaura]];
        elseif (spec == "Retribution") then
            return [[Interface\Icons\spell_holy_auraoflight]];
        elseif (spec == "Preg") then
            return [[Interface\Icons\ability_paladin_hammeroftherighteous]];
        elseif (spec == "Discipline") then
            return [[Interface\Icons\spell_holy_wordfortitude]];
        elseif (spec == "Holy") then
            return [[Interface\Icons\spell_holy_guardianspirit]];
        elseif (spec == "Shadow") then
            return [[Interface\Icons\spell_shadow_shadowwordpain]];
        elseif (spec == "Elemental") then
            return [[Interface\Icons\spell_nature_lightning]];
        elseif (spec == "Enhancement") then
            return [[Interface\Icons\spell_nature_lightningshield]];
        elseif (spec == "Restoration") then
            return [[Interface\Icons\spell_nature_magicimmunity]];
        elseif (spec == "Affliction") then
            return [[Interface\Icons\spell_shadow_deathcoil]];
        elseif (spec == "Demonology") then
            return [[Interface\Icons\spell_shadow_metamorphosis]];
        elseif (spec == "Destruction") then
            return [[Interface\Icons\spell_shadow_rainoffire]];
        elseif (spec == "Arms") then
            return [[Interface\Icons\ability_rogue_eviscerate]];
        elseif (spec == "Fury") then
            return [[Interface\Icons\ability_warrior_innerrage]];
        elseif (spec == "Protection") then
            return [[Interface\Icons\inv_shield_06]];
        end
    end
	return "";
end

local mapsList = {
    [562] = "BEA", -- Blade's Edge Arena
    [572] = "RoL", -- Ruins of Lordaeron
    [559] = "NA", -- Nagrand Arena
    [4406] = "RoV", -- Ring of Valor
    [617] = "DA", -- Dalaran Arena
}

function Constants:GetMapKeyByID(id)
    if(id == nil) then
        return nil;
    end

    if(not mapsList[id]) then
        ArenaAnalytics:Log("Failed to find map for mapId:", id);
    end
    return mapsList[id];
end

function ArenaAnalytics:getBracketFromTeamSize(teamSize)
    if(teamSize == 2) then
        return "2v2";
    elseif(teamSize == 3) then
        return "3v3";
    end
    return "5v5";
end

function ArenaAnalytics:getBracketIdFromTeamSize(teamSize)
    if(teamSize == 2) then
        return 1;
    elseif(teamSize == 3) then
        return 2;
    end
    return 3;
end

function ArenaAnalytics:getTeamSizeFromBracketId(bracketId)
    if(bracketId == 1) then
        return 2;
    elseif(bracketId == 2) then
        return 3;
    end
    return 5
end

function ArenaAnalytics:getTeamSizeFromBracket(bracket)
    if(bracket == "2v2") then
        return 2;
    elseif(bracket == "3v3") then
        return 3;
    end
    return 5;
end