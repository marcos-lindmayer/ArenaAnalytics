--[[ 
	Thanks to Gladdy for spec detection db 
]]

local _, ArenaAnalytics = ...; -- Namespace
local Constants = {}
ArenaAnalytics.Constants = Constants;

Constants.currentSeasonStartInt = 1687219201;

-- (Assumes timestamp of 00:00:01 GMT and no difference between regions for now)
local seasonStartAndEndTimes = {
    {1623801601, 1630972801}, -- season 1 (June 16, 2021 - Sept. 7, 2021)
    {1631577601, 1641776401}, -- season 2 (Sept. 14, 2021 - Jan. 10, 2022)
    {1642381201, 1651536001}, -- season 3 (Jan. 17, 2022 - May 3, 2022)
    {1652313601, 1661731201}, -- season 4 (May 12, 2022 - Aug. 29, 2022)
    {1664841601, 1673226001}, -- season 5 (Oct. 4, 2022 - Jan. 9, 2023)
    {1673917201, 1685318401}, -- season 6 (Jan. 17, 2023 - May 29, 2023)
    {1687219201, 1696197601}, -- season 7 (June 20, 2023 - Oct 2, 2023)
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

-- Priority: Healer > Caster > Tank > Melee
-- Addon specific spec IDs { ID, "class|spec", "class", "spec", priority value } (ID must never change to preserve data validity, priority is a runtime check)
local addonSpecializationIDs = {
    -- Druid
    ["Druid|Restoration"] = 1,
    ["Druid|Feral"] = 2,
    ["Druid|Balance"] = 3,
    
    -- Paladin
    ["Paladin|Holy"] = 11,
    ["Paladin|Protection"] = 12,
    ["Paladin|Preg"] = 13,
    ["Paladin|Retribution"] = 14,
    
    -- Shaman
    ["Shaman|Restoration"] = 21,
    ["Shaman|Elemental"] = 22,
    ["Shaman|Enhancement"] = 23,

    -- Death Knight
    ["Death Knight|Unholy"] = 31,
    ["Death Knight|Frost"] = 32,
    ["Death Knight|Blood"] = 33,

    -- Hunter
    ["Hunter|Beast Mastery"] = 41,
    ["Hunter|Marksmanship"] = 42,
    ["Hunter|Survival"] = 43,

    -- Mage
    ["Mage|Frost"] = 51,
    ["Mage|Fire"] = 52,
    ["Mage|Arcane"] = 53,

    -- Rogue
    ["Rogue|Subtlety"] = 61,
    ["Rogue|Assassination"] = 62,
    ["Rogue|Combat"] = 63,
    ["Rogue|Outlaw"] = 64,

    -- Warlock
    ["Warlock|Affliction"] = 71,
    ["Warlock|Destruction"] = 72,
    ["Warlock|Demonology"] = 73,

    -- Warrior
    ["Warrior|Protection"] = 81,
    ["Warrior|Arms"] = 82,
    ["Warrior|Fury"] = 83,
    
    -- Priest
    ["Priest|Discipline"] = 91,
    ["Priest|Holy"] = 92,
    ["Priest|Shadow"] = 93,
}
function Constants:getAddonSpecializationID(spec)
    if spec == nil then return nil end;
    return addonSpecializationIDs[spec] or nil;
end

-- ID to class and spec
local classAndSpecByID = {
    -- Druid
    [1] = {"Druid|Restoration", "Druid", "Restoration"},
    [2] = {"Druid|Feral", "Druid", "Feral"},
    [3] = {"Druid|Balance", "Druid", "Balance"},
    
    -- Paladin
    [11] = {"Paladin|Holy", "Paladin", "Holy"},
    [12] = {"Paladin|Protection", "Paladin", "Protection"},
    [13] = {"Paladin|Preg", "Paladin", "Preg"},
    [14] = {"Paladin|Retribution", "Paladin", "Retribution"},
    
    -- Shaman
    [21] = {"Shaman|Restoration", "Shaman", "Restoration"},
    [22] = {"Shaman|Elemental", "Shaman", "Elemental"},
    [23] = {"Shaman|Enhancement", "Shaman", "Enhancement"},

    -- Death Knight
    [31] = {"Death Knight|Unholy", "Death Knight", "Unholy"},
    [32] = {"Death Knight|Frost", "Death Knight", "Frost"},
    [33] = {"Death Knight|Blood", "Death Knight", "Blood"},

    -- Hunter
    [41] = {"Hunter|Beast Mastery", "Hunter", "Beast Mastery"},
    [42] = {"Hunter|Marksmanship", "Hunter", "Marksmanship"},
    [43] = {"Hunter|Survival", "Hunter", "Survival"},

    -- Mage
    [51] = {"Mage|Frost", "Mage", "Frost"},
    [52] = {"Mage|Fire", "Mage", "Fire"},
    [53] = {"Mage|Arcane", "Mage", "Arcane"},

    -- Rogue
    [61] = {"Rogue|Subtlety", "Rogue", "Subtlety"},
    [62] = {"Rogue|Assassination", "Rogue", "Assassination"},
    [63] = {"Rogue|Combat", "Rogue", "Combat"},
    [64] = {"Rogue|Outlaw", "Rogue", "Outlaw"},

    -- Warlock
    [71] = {"Warlock|Affliction", "Warlock", "Affliction"},
    [72] = {"Warlock|Destruction", "Warlock", "Destruction"},
    [73] = {"Warlock|Demonology", "Warlock", "Demonology"},

    -- Warrior
    [81] = {"Warrior|Protection", "Warrior", "Protection"},
    [82] = {"Warrior|Arms", "Warrior", "Arms"},
    [83] = {"Warrior|Fury", "Warrior", "Fury"},
    
    -- Priest
    [91] = {"Priest|Discipline", "Priest", "Discipline"},
    [92] = {"Priest|Holy", "Priest", "Holy"},
    [93] = {"Priest|Shadow", "Priest", "Shadow"},
}

-- FIX to fetch by ID as intended
-- Add priority values
function Constants:getSpecPriorityValue(specID)
    return specID and tonumber(specID) or 0
end

function Constants:getClassAndSpec(specID)
    local data = classAndSpecByID[tonumber(specID)];
    if (not data) then 
        ArenaAnalytics:Log("Failed to find spec for ID: ", specID)
        return nil, nil;
    end

    -- class, spec
    return data[2], data[3];
end

local specSpells = {
    -- DRUID
    [ 18562 ] = "Restoration", -- Swiftmend
    [ 17116 ] = "Restoration", -- Nature's Swiftness
    [ 45283 ] = "Restoration", -- Natural Perfection
    [ 33891 ] = "Restoration", -- Tree of Life
    [ 33983 ] = "Feral", -- Mangle (Cat)
    [ 33987 ] = "Feral", -- Mangle (Bear)
    [ 24932 ] = "Feral", -- Leader of the Pack
    [ 49376 ] = "Feral", -- Feral Charge: Cat
    [ 16979 ] = "Feral", -- Feral Charge: Bear
    [ 33831 ] = "Balance", -- Force of Nature
    [ 24858 ] = "Balance", -- Moonkin Form
    [ 24907 ] = "Balance", -- Moonkin Aura
    [ 48505 ] = "Balance", -- Starfall (Rank 1)
    [ 53199 ] = "Balance", -- Starfall (Rank 2)
    [ 53200 ] = "Balance", -- Starfall (Rank 3)
    [ 53201 ] = "Balance", -- Starfall (Rank 4)

    -- HUNTER
    [ 34490 ] = "Marksmanship", -- Silencing Shot
    [ 19506 ] = "Marksmanship", -- Trueshot Aura
    [ 53209 ] = "Marksmanship",  -- Chimera Shot
    [ 27068 ] = "Survival", -- Wyvern Sting
    [ 19306 ] = "Survival", -- Counterattack
    [ 60053 ] = "Survival", -- Explosive Shot
    [ 19577 ] = "Beast Mastery", -- Intimidation
    [ 34692 ] = "Beast Mastery", -- The Beast Within
    [ 20895 ] = "Beast Mastery", -- Spirit Bond
    [ 34455 ] = "Beast Mastery", -- Ferocious Inspiration

    -- MAGE
    [ 12042 ] = "Arcane", -- Arcane Power
    [ 12043 ] = "Arcane", -- Presence of Mind
    [ 44425 ] = "Arcane", -- Arcane Barrage
    [ 31589 ] = "Arcane", -- Slow
    [ 33405 ] = "Frost", -- Ice Barrier
    [ 31687 ] = "Frost", -- Summon Water Elemental
    [ 12472 ] = "Frost", -- Icy Veins
    [ 11958 ] = "Frost", -- Cold Snap
    [ 44572 ] = "Frost", -- Deep Freeze
    [ 42950 ] = "Fire", -- Dragon's Breath
    [ 33933 ] = "Fire", -- Blast Wave
    [ 11129 ] = "Fire", -- Combustion
    [ 55360 ] = "Fire", -- Living Bomb
    [ 31642 ] = "Fire", -- Blazing Speed

    -- PALADIN
    [ 20473 ] = "Holy", -- Holy Shock (Rank 1)
    [ 20929 ] = "Holy", -- Holy Shock (Rank 2)
    [ 20930 ] = "Holy", -- Holy Shock (Rank 3)
    [ 27174 ] = "Holy", -- Holy Shock (Rank 4)
    [ 33072 ] = "Holy", -- Holy Shock (Rank 5)
    [ 48824 ] = "Holy", -- Holy Shock (Rank 6)
    [ 48825 ] = "Holy", -- Holy Shock (Rank 7)
    [ 53563 ] = "Holy", -- Beacon of Light
    [ 53652 ] = "Holy", -- Beacon of Light (Holy Shock)
    [ 53653 ] = "Holy", -- Beacon of Light (Flash of Light)
    [ 53654 ] = "Holy", -- Beacon of Light (???)
    [ 20216 ] = "Holy", -- Divine Favor
    [ 31842 ] = "Holy", -- Divine Illumination
    [ 31836 ] = "Holy", -- Light's Grace
    [ 35395 ] = "Retribution", -- Crusader Strike
    [ 20049 ] = "Retribution", -- Vengeance
    [ 53380 ] = "Retribution", -- Righteous Vengeance (Rank 1)
    [ 53381 ] = "Retribution", -- Righteous Vengeance (Rank 2)
    [ 53382 ] = "Retribution", -- Righteous Vengeance (Rank 3)
    [ 53385 ] = "Retribution", -- Divine Storm
    [ 20066 ] = "Preg", -- Repentance (Ret tree)
    [ 54203 ] = "Preg", -- Sheath of Light (Ret tree)
    [ 20178 ] = "Preg", -- Reckoning (Prot tree)
    [ 20911 ] = "Preg", -- Blessing of Sanctuary (Prot tree)
    [ 31935 ] = "Protection", -- Avenger's Shield (Rank 1)
    [ 32699 ] = "Protection", -- Avenger's Shield (Rank 2)
    [ 32700 ] = "Protection", -- Avenger's Shield (Rank 3)
    [ 48826 ] = "Protection", -- Avenger's Shield (Rank 4)
    [ 48827 ] = "Protection", -- Avenger's Shield (Rank 5)
    [ 20925 ] = "Protection", -- Holy Shield (Rank 1)
    [ 20927 ] = "Protection", -- Holy Shield (Rank 2)
    [ 20928 ] = "Protection", -- Holy Shield (Rank 3)
    [ 27179 ] = "Protection", -- Holy Shield (Rank 4)
    [ 48951 ] = "Protection", -- Holy Shield (Rank 5)
    [ 48952 ] = "Protection", -- Holy Shield (Rank 6)
    [ 53595 ] = "Protection", -- Hammer of the Righteous

    -- PRIEST
    [ 33143 ] = "Holy", -- Blessed Resilience
    [ 20711 ] = "Holy", -- Spirit of Redemption
    [ 724 ] = "Holy", -- Lightwell
    [ 34861 ] = "Holy", -- Circle of Healing
    [ 47788 ] = "Holy", -- Guardian Spirit
    [ 33142 ] = "Holy", -- Blessed Resilience
    [ 15473 ] = "Shadow", -- Shadowform
    [ 34914 ] = "Shadow", -- Vampiric Touch (Rank 1)
    [ 34916 ] = "Shadow", -- Vampiric Touch (Rank 2)
    [ 34917 ] = "Shadow", -- Vampiric Touch (Rank 3)
    [ 48159 ] = "Shadow", -- Vampiric Touch (Rank 4)
    [ 48160 ] = "Shadow", -- Vampiric Touch (Rank 5)
    [ 64044 ] = "Shadow", -- Psychic Horror
    [ 47585 ] = "Shadow", -- Dispersion
    [ 10060 ] = "Discipline", -- Power Infusion
    [ 33206 ] = "Discipline", -- Pain Suppression
    [ 14752 ] = "Discipline", -- Divine Spirit
    [ 45234 ] = "Discipline", -- Focused Will
    [ 27811 ] = "Discipline", -- Blessed Recovery
    [ 14752 ] = "Discipline", -- Divine Spirit
    [ 27681 ] = "Discipline", -- Prayer of Spirit
    [ 14893 ] = "Discipline", -- Inspiration
    [ 52800 ] = "Discipline", -- Borrowed Time
    [ 53007 ] = "Discipline", -- Penance

    -- ROGUE
    [ 13750 ] = "Combat", -- Adrenaline Rush
    [ 51690 ] = "Combat", -- Killing Spree
    [ 14185 ] = "Subtlety", -- Preparation
    [ 16511 ] = "Subtlety", -- Hemorrhage
    [ 14278 ] = "Subtlety", -- Ghostly Strike
    [ 14183 ] = "Subtlety", -- Premeditation
    [ 36554 ] = "Subtlety", -- Shadowstep
    [ 44373 ] = "Subtlety", -- Shadowstep Speed
    [ 36563 ] = "Subtlety", -- Shadowstep DMG
    [ 14278 ] = "Subtlety", -- Ghostly Strike
    [ 31665 ] = "Subtlety", -- Master of Subtlety
    [ 51713 ] = "Subtlety", -- Shadow Dance
    [ 14177 ] = "Assassination", -- Cold Blood
    [ 31233 ] = "Assassination", -- Find Weakness
    [ 48666 ] = "Assassination", -- Mutilate
    [ 57993 ] = "Assassination", -- Envenom
    [ 51662 ] = "Assassination", -- Hunger For Blood

    -- SHAMAN
    [ 16190 ] = "Restoration", -- Mana Tide Totem
    [ 49284 ] = "Restoration", -- Earth Shield
    [ 16190 ] = "Restoration", -- Mana Tide Totem
    [ 61300 ] = "Restoration", -- Riptide
    [ 30823 ] = "Enhancement", -- Shamanistic Rage
    [ 17364 ] = "Enhancement", -- Stormstrike
    [ 30823 ] = "Enhancement", -- Shamanistic Rage
    [ 16166 ] = "Elemental", -- Elemental Mastery
    [ 59159 ] = "Elemental", -- Thunderstorm

    -- WARLOCK
    [ 47847 ] = "Destruction", -- Shadowfury
    [ 30302 ] = "Destruction", -- Nether Protection
    [ 34935 ] = "Destruction", -- Backlash
    [ 17962 ] = "Destruction", -- Conflagrate
    [ 59672 ] = "Demonology", -- Metamorphosis
    [ 47843 ] = "Affliction", -- Unstable Affliction
    [ 59164 ] = "Affliction", -- Haunt

    -- WARRIOR
    [ 56638 ] = "Arms", -- Taste for Blood
    [ 64976 ] = "Arms", -- Juggernaut
    [ 47486 ] = "Arms", -- Mortal Strike
    [ 12292 ] = "Arms", -- Death Wish
    [ 29834 ] = "Arms", -- Second Wind (Rank 1)
    [ 29838 ] = "Arms", -- Second Wind (Rank 2)
    [ 46924 ] = "Arms", -- Bladestorm
    [ 23881 ] = "Fury", -- Bloodthirst
    [ 46916 ] = "Fury", -- Bloodsurge
    [ 12809 ] = "Protection", -- Concussion Blow
    [ 47498 ] = "Protection", -- Devastate

    -- DEATHKNIGHT
    [ 50461 ] = "Unholy", -- Anti-magic Zone
    [ 49222 ] = "Unholy", -- Bone Shield
    [ 71488 ] = "Unholy", -- Scourge Strike
    [ 49206 ] = "Unholy", -- Summon Gargoyle
    [ 49796 ] = "Frost", -- Death Chill
    [ 49203 ] = "Frost", -- Hungering Cold
    [ 51271 ] = "Frost", -- Unbreakable Armor
    [ 55268 ] = "Frost", -- Frost Strike
    [ 51411 ] = "Frost", -- Howling Blast
    [ 49005 ] = "Blood", -- Mark of Blood
    [ 49016 ] = "Blood", -- Unholy Frenzy
    [ 55233 ] = "Blood", -- Vampiric Blood
    [ 55262 ] = "Blood", -- Heart Strike
    [ 49028 ] = "Blood", -- Dancing Rune Weapon
}
function Constants:GetSpecBySpellID(spellID)
    return specSpells[spellID];   
end

local raceToFaction = {
    ["Undead"] = "Horde",
    ["Blood Elf"] = "Horde",
    ["Orc"] = "Horde",
    ["Tauren"] = "Horde",
    ["Troll"] = "Horde",
    ["Human"] = "Alliance",
    ["Draenei"] = "Alliance",
    ["Night Elf"] = "Alliance",
    ["Gnome"] = "Alliance",
    ["Dwarf"] = "Alliance"    
}

function Constants:GetFactionByRace(race)
    return raceToFaction[race];
end

local arenaTimer = {
    ["default"] = {
        [61] = "One minute until the Arena battle begins!",
        [31] = "Thirty seconds until the Arena battle begins!",
        [16] = "Fifteen seconds until the Arena battle begins!",
        [0] = "The Arena battle has begun!",
    },
    ["esES"] = {
        [61] = "¡Un minuto hasta que dé comienzo la batalla en arena!",
        [31] = "¡Treinta segundos hasta que comience la batalla en arena!",
        [16] = "¡Quince segundos hasta que comience la batalla en arena!",
        [0] = "¡La batalla en arena ha comenzado!",
    },
    ["ptBR"] = {
        [61] = "Um minuto até a batalha na Arena começar!",
        [31] = "Trinta segundos até a batalha na Arena começar!",
        [16] = "Quinze segundos até a batalha na Arena começar!",
        [0] = "A batalha na Arena começou!",
    },
    ["deDE"] = {
        [61] = "Noch eine Minute bis der Arenakampf beginnt!",
        [31] = "Noch dreißig Sekunden bis der Arenakampf beginnt!",
        [16] = "Noch fünfzehn Sekunden bis der Arenakampf beginnt!",
        [0] = "Der Arenakampf hat begonnen!",
    },
    ["frFR"] = {
        [61] = "Le combat d'arène commence dans une minute\194\160!",
        [31] = "Le combat d'arène commence dans trente secondes\194\160!",
        [16] = "Le combat d'arène commence dans quinze secondes\194\160!",
        [0] = "Le combat d'arène commence\194\160!",
    },
    ["ruRU"] = {
        [61] = "Одна минута до начала боя на арене!",
        [31] = "Тридцать секунд до начала боя на арене!",
        [16] = "До начала боя на арене осталось 15 секунд.",
        [0] = "Бой начался!",
    },
    ["itIT"] = {
    },
    ["koKR"] = {
        [61] = "투기장 전투 시작 1분 전입니다!",
        [31] = "투기장 전투 시작 30초 전입니다!",
        [16] = "투기장 전투 시작 15초 전입니다!",
        [0] = "투기장 전투가 시작되었습니다!",
    },
    ["zhCN"] = {
        [61] = "竞技场战斗将在一分钟后开始！",
        [31] = "竞技场战斗将在三十秒后开始！",
        [16] = "竞技场战斗将在十五秒后开始！",
        [0] = "竞技场的战斗开始了！",
    },
    ["zhTW"] = {
        [61] = "1分鐘後競技場戰鬥開始!",
        [31] = "30秒後競技場戰鬥開始!",
        [16] = "15秒後競技場戰鬥開始!",
        [0] = "競技場戰鬥開始了!",
    },
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
function ArenaAnalyticsGetClassColor(className)
    if(className == nil) then
        return 'ffffffff';
    end
    
    if(className == "Death Knight") then
        return select(4, GetClassColor("DEATHKNIGHT"));
    end
    
    return select(4, GetClassColor(className:upper()));
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
function ArenaAnalyticsGetSpecIcon(spec, class)
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