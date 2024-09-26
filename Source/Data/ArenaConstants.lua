local _, ArenaAnalytics = ...; -- Addon Namespace
local Constants = ArenaAnalytics.Constants;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;
local Internal = ArenaAnalytics.Internal;

-------------------------------------------------------------------------

Constants.headerColor = "ffd0d0d0";
Constants.prefixColor = "FF909090";
Constants.valueColor = "fff9f9f9";
Constants.infoColor = "ffbbbbbb";

-- Outcome colors
Constants.winColor = "ff00cc66";
Constants.lossColor = "ffff0000";
Constants.drawColor = "ffffcc00";

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

-------------------------------------------------------------------------

-- NOTE: Indices here affect save data
Constants.roleIndexes = { 
    -- Main roles
    { token = "tank", isMain = true, name = "Tank" },
    { token = "damager", isMain = true, name = "Dps" },
    { token = "healer", isMain = true, name = "Healer" },

    -- Sub roles
    { token = "caster", name = "Caster" },
    { token = "ranged", name = "Ranged" },
    { token = "melee", name = "Melee" },
}

-------------------------------------------------------------------------

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

local specIconTable = {
        -- Druid
        [1] = [[Interface\Icons\spell_nature_healingtouch]],
        [2] = [[Interface\Icons\ability_druid_catform]],
        [3] = [[Interface\Icons\spell_nature_starfall]],
        [4] = [[Interface\Icons\ability_racial_bearform]],
    
        -- Paladin
        [11] = [[Interface\Icons\spell_holy_holybolt]],
        [12] = [[Interface\Icons\spell_holy_devotionaura]],
        [13] = [[Interface\Icons\ability_paladin_hammeroftherighteous]],
        [14] = [[Interface\Icons\spell_holy_auraoflight]],
    
        -- Shaman
        [21] = [[Interface\Icons\spell_nature_magicimmunity]],
        [22] = [[Interface\Icons\spell_nature_lightning]],
        [23] = [[Interface\Icons\spell_nature_lightningshield]],
    
        -- Death Knight
        [31] = [[Interface\Icons\spell_deathknight_unholypresence]],
        [32] = [[Interface\Icons\spell_deathknight_frostpresence]],
        [33] = [[Interface\Icons\spell_deathknight_bloodpresence]],
    
        -- Hunter
        [41] = [[Interface\Icons\ability_hunter_beasttaming]],
        [42] = [[Interface\Icons\ability_marksmanship]],
        [43] = [[Interface\Icons\ability_hunter_swiftstrike]],
    
        -- Mage
        [51] = [[Interface\Icons\spell_frost_frostbolt02]],
        [52] = [[Interface\Icons\spell_fire_firebolt02]],
        [53] = [[Interface\Icons\spell_holy_magicalsentry]],
    
        -- Rogue
        [61] = [[Interface\Icons\ability_stealth]],
        [62] = [[Interface\Icons\ability_rogue_eviscerate]],
        [63] = [[Interface\Icons\ability_backstab]],
        [64] = [[Interface\Icons\ability_rogue_waylay]], -- Outlaw
    
        -- Warlock
        [71] = [[Interface\Icons\spell_shadow_deathcoil]], -- Affliction
        [72] = [[Interface\Icons\spell_shadow_rainoffire]], -- Destruction
        [73] = [[Interface\Icons\spell_shadow_metamorphosis]], -- Demonology
    
        -- Warrior
        [81] = [[Interface\Icons\inv_shield_06]], -- Protection
        [82] = [[Interface\Icons\ability_rogue_eviscerate]], -- Arms
        [83] = [[Interface\Icons\ability_warrior_innerrage]], -- Fury
    
        -- Priest
        [91] = [[Interface\Icons\spell_holy_wordfortitude]], -- Disc
        [92] = [[Interface\Icons\spell_holy_guardianspirit]], -- Holy
        [93] = [[Interface\Icons\spell_shadow_shadowwordpain]], -- Shadow
    
        -- Monk
        [101] = [[Interface\Icons\Spell_monk_mistweaver_spec]], -- Mistweaver
        [102] = [[Interface\Icons\spell_monk_brewmaster_spec]], -- Brewmaster
        [103] = [[Interface\Icons\spell_monk_windwalker_spec]], -- Windwalker
    
        -- Demon Hunter
        [111] = [[Interface\Icons\ability_demonhunter_spectank]], -- Vengeance
        [112] = [[Interface\Icons\ability_demonhunter_specdps]], -- Havoc
    
        -- Evoker
        [121] = [[Interface\Icons\classicon_evoker_preservation]], -- Preservation
        [122] = [[Interface\Icons\classicon_evoker_augmentation]], -- Augmentation
        [123] = [[Interface\Icons\classicon_evoker_devastation]], -- Devastation
}

-- Returns spec icon path string
function Constants:GetSpecIcon(spec_id)
    if(not spec_id or Helpers:IsClassID(spec_id)) then
        return "";
    end

    return specIconTable[spec_id] or 134400;
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

local bracketTeamSizes = { 2, 3, 5, 3 };
function ArenaAnalytics:getTeamSizeFromBracketIndex(bracketIndex)
    bracketIndex = tonumber(bracketIndex);
    return bracketIndex and bracketTeamSizes[bracketIndex];
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