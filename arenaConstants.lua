--[[ 
	Thanks to Gladdy for spec detection db 
]]

local _, core = ...; -- Namespace
local arenaConstants = {}
core.arenaConstants = arenaConstants;

local specSpells = {
    -- DRUID
    [ 33831 ] = "Balance", -- Force of Nature
    [ 33983 ] = "Feral", -- Mangle (Cat)
    [ 33987 ] = "Feral", -- Mangle (Bear)
    [ 18562 ] = "Restoration", -- Swiftmend
    [ 16188 ] = "Restoration", -- Nature's Swiftness
    [ 45283 ] = "Restoration", -- Natural Perfection
    [ 16880 ] = "Restoration", -- Nature's Grace; Dreamstate spec in TBC equals Restoration
    [ 24858 ] = "Restoration", -- Moonkin Form; Dreamstate spec in TBC equals Restoration
    [ 17007 ] = "Feral", -- Leader of the Pack

    -- HUNTER
    [ 19577 ] = "Beast Mastery", -- Intimidation
    [ 34490 ] = "Marksmanship", -- Silencing Shot
    [ 27068 ] = "Survival", -- Wyvern Sting
    [ 19306 ] = "Survival", -- Counterattack
    [ 27066 ] = "Marksmanship", -- Trueshot Aura
    [ 34692 ] = "Beast Mastery", -- The Beast Within
    [ 20895 ] = "Beast Mastery", -- Spirit Bond
    [ 34455 ] = "Beast Mastery", -- Ferocious Inspiration

    -- MAGE
    [ 12042 ] = "Arcane", -- Arcane Power
    [ 33043 ] = "Fire", -- Dragon's Breath
    [ 33933 ] = "Fire", -- Blast Wave
    [ 33405 ] = "Frost", -- Ice Barrier
    [ 31687 ] = "Frost", -- Summon Water Elemental
    [ 12472 ] = "Frost", -- Icy Veins
    [ 11958 ] = "Frost", -- Cold Snap
    [ 11129 ] = "Fire", -- Combustion
    [ 12043 ] = "Arcane", -- Presence of Mind

    -- PALADIN
    [ 33072 ] = "Holy", -- Holy Shock
    [ 20216 ] = "Holy", -- Divine Favor
    [ 31842 ] = "Holy", -- Divine Illumination
    [ 32700 ] = "Protection", -- Avenger's Shield
    [ 27170 ] = "Retribution", -- Seal of Command
    [ 35395 ] = "Retribution", -- Crusader Strike
    [ 20066 ] = "Retribution", -- Repentance
    [ 20218 ] = "Retribution", -- Sanctity Aura
    [ 31836 ] = "Holy", -- Light's Grace
    [ 20375 ] = "Retribution", -- Seal of Command
    [ 20049 ] = "Retribution", -- Vengeance

    -- PRIEST
    [ 10060 ] = "Discipline", -- Power Infusion
    [ 33206 ] = "Discipline", -- Pain Suppression
    [ 14752 ] = "Discipline", -- Divine Spirit
    [ 33143 ] = "Holy", -- Blessed Resilience
    [ 34861 ] = "Holy", -- Circle of Healing
    [ 15473 ] = "Shadow", -- Shadowform
    [ 34917 ] = "Shadow", -- Vampiric Touch
    [ 45234 ] = "Discipline", -- Focused Will
    [ 27811 ] = "Discipline", -- Blessed Recovery
    [ 33142 ] = "Holy", -- Blessed Resilience
    [ 14752 ] = "Discipline", -- Divine Spirit
    [ 27681 ] = "Discipline", -- Prayer of Spirit
    [ 14893 ] = "Discipline", -- Inspiration

    -- ROGUE
    [ 34413 ] = "Assassination", -- Mutilate
    [ 14177 ] = "Assassination", -- Cold Blood
    [ 13750 ] = "Combat", -- Adrenaline Rush
    [ 14185 ] = "Subtlety", -- Preparation
    [ 16511 ] = "Subtlety", -- Hemorrhage
    [ 36554 ] = "Subtlety", -- Shadowstep
    [ 14278 ] = "Subtlety", -- Ghostly Strike
    [ 14183 ] = "Subtlety", -- Premeditation
    [ 44373 ] = "Subtlety", -- Shadowstep Speed
    [ 36563 ] = "Subtlety", -- Shadowstep DMG
    [ 14278 ] = "Subtlety", -- Ghostly Strike
    [ 31233 ] = "Assassination", -- Find Weakness

    -- SHAMAN
    [ 16166 ] = "Elemental", -- Elemental Mastery
    [ 30823 ] = "Enhancement", -- Shamanistic Rage
    [ 17364 ] = "Enhancement", -- Stormstrike
    [ 16190 ] = "Restoration", -- Mana Tide Totem
    [ 32594 ] = "Restoration", -- Earth Shield
    [ 16190 ] = "Restoration", -- Mana Tide Totem
    [ 30823 ] = "Enhancement", -- Shamanistic Rage

    -- WARLOCK
    [ 30405 ] = "Affliction", -- Unstable Affliction
    [ 30414 ] = "Destruction", -- Shadowfury
    [ 19028 ] = "Demonology", -- Soul Link
    [ 23759 ] = "Demonology", -- Master Demonologist
    [ 30302 ] = "Destruction", -- Nether Protection
    [ 34935 ] = "Destruction", -- Backlash

    -- WARRIOR
    [ 30330 ] = "Arms", -- Mortal Strike
    [ 12292 ] = "Arms", -- Death Wish
    [ 30335 ] = "Fury", -- Bloodthirst
    [ 12809 ] = "Protection", -- Concussion Blow
    [ 30022 ] = "Protection", -- Devastation
    [ 29838 ] = "Arms", -- Second Wind
}
function arenaConstants:GetSpecSpells()
    return specSpells
end

local racials = {
    ["Scourge"] = {
        [7744] = true, -- Will of the Forsaken
        duration = 120,
        spellName = select(1, GetSpellInfo(7744)),
        texture = select(3, GetSpellInfo(7744))
    },
    ["BloodElf"] = {
        [28730] = true, -- Arcane Torrent
        duration = 120,
        spellName = select(1, GetSpellInfo(28730)),
        texture = select(3, GetSpellInfo(28730))
    },
    ["Tauren"] = {
        [20549] = true, -- War Stomp
        duration = 120,
        spellName = select(1, GetSpellInfo(20549)),
        texture = select(3, GetSpellInfo(20549))
    },
    ["Orc"] = {
        [20572] = true,
        [33697] = true,
        [33702] = true,
        duration = 120,
        spellName = select(1, GetSpellInfo(20572)),
        texture = select(3, GetSpellInfo(20572))
    },
    ["Troll"] = {
        [20554] = true,
        [26296] = true,
        [26297] = true,
        duration = 180,
        spellName = select(1, GetSpellInfo(20554)),
        texture = select(3, GetSpellInfo(20554))
    },
    ["NightElf"] = {
        [20580] = true,
        duration = 10,
        spellName = select(1, GetSpellInfo(20580)),
        texture = select(3, GetSpellInfo(20580))
    },
    ["Draenei"] = {
        [28880] = true,
        duration = 180,
        spellName = select(1, GetSpellInfo(28880)),
        texture = select(3, GetSpellInfo(28880))
    },
    ["Human"] = {
        [20600] = true, -- Perception
        duration = 180,
        spellName = select(1, GetSpellInfo(20600)),
        texture = select(3, GetSpellInfo(20600))
    },
    ["Gnome"] = {
        [20589] = true, -- Escape Artist
        duration = 105,
        spellName = select(1, GetSpellInfo(20589)),
        texture = select(3, GetSpellInfo(20589))
    },
    ["Dwarf"] = {
        [20594] = true, -- Stoneform
        duration = 180,
        spellName = select(1, GetSpellInfo(20594)),
        texture = select(3, GetSpellInfo(20594))
    },
}
function arenaConstants:Racials()
    return racials
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

function arenaConstants:GetArenaTimer()
    if arenaTimer[GetLocale()] then
        return arenaTimer[GetLocale()]
    else
        return arenaTimer["default"]
    end
end

-- Returns class icon path string
function ArenaAnalyticsGetClassIcon(className)
	local currentClassName = className;
	local classString;
	if (currentClassName == "Mage") then
		classString = [[Interface\Icons\classicon_mage]];
	elseif (currentClassName == "Rogue") then
		classString = [[Interface\Icons\classicon_rogue]];
	elseif (currentClassName == "Priest") then
		classString = [[Interface\Icons\classicon_priest]];
	elseif (currentClassName == "Druid") then
		classString = [[Interface\Icons\classicon_druid]];
	elseif (currentClassName == "Paladin") then
		classString = [[Interface\Icons\classicon_paladin]];
	elseif (currentClassName == "Shaman") then
		classString = [[Interface\Icons\classicon_shaman]];
	elseif (currentClassName == "Hunter") then
		classString = [[Interface\Icons\classicon_hunter]];
	elseif (currentClassName == "Warrior") then
		classString = [[Interface\Icons\classicon_warrior]];
	elseif (currentClassName == "Warlock") then
		classString = [[Interface\Icons\classicon_warlock]];
	elseif (currentClassName == "Deathknight") then
		classString = [[Interface\Icons\spell_deathknight_classicon]];
	end
	return classString;
end

-- Returns spec icon path string
function ArenaAnalyticsGetSpecIcon(spec, class)
	local currentSpecName = spec;
	local specString;
	if (currentSpecName == "Subtlety") then
		specString = [[Interface\Icons\ability_stealth]];
	elseif (currentSpecName == "Assassination") then
		specString = [[Interface\Icons\ability_rogue_eviscerate]];
	elseif (currentSpecName == "Combat") then
		specString = [[Interface\Icons\ability_backstab]];
	elseif (currentSpecName == "Blood") then
		specString = [[Interface\Icons\spell_deathknight_bloodpresence]];
	elseif (currentSpecName == "Frost" and class == "Deathknight") then
		specString = [[Interface\Icons\spell_deathknight_frostpresence]];
	elseif (currentSpecName == "Unholy") then
		specString = [[Interface\Icons\spell_deathknight_unholypresence]];
	elseif (currentSpecName == "Balance") then
		specString = [[Interface\Icons\spell_nature_starfall]];
	elseif (currentSpecName == "Feral") then
		specString = [[Interface\Icons\ability_racial_bearform]];
	elseif (currentSpecName == "Restoration" and class == "Druid") then
		specString = [[Interface\Icons\spell_nature_healingtouch]];
	elseif (currentSpecName == "Beast Mastery") then
		specString = [[Interface\Icons\ability_hunter_beasttaming]];
	elseif (currentSpecName == "Marksmanship") then
		specString = [[Interface\Icons\ability_marksmanship]];
	elseif (currentSpecName == "Survival") then
		specString = [[Interface\Icons\ability_hunter_swiftstrike]];
	elseif (currentSpecName == "Arcane") then
		specString = [[Interface\Icons\spell_holy_magicalsentry]];
	elseif (currentSpecName == "Fire") then
		specString = [[Interface\Icons\spell_fire_firebolt02]];
	elseif (currentSpecName == "Frost") then
		specString = [[Interface\Icons\spell_frost_frostbolt02]];
	elseif (currentSpecName == "Holy" and class == "Paladin") then
		specString = [[Interface\Icons\spell_holy_holybolt]];
	elseif (currentSpecName == "Protection" and class == "Paladin") then
		specString = [[Interface\Icons\spell_holy_devotionaura]];
	elseif (currentSpecName == "Retribution") then
		specString = [[Interface\Icons\spell_holy_auraoflight]];
	elseif (currentSpecName == "Discipline") then
		specString = [[Interface\Icons\spell_holy_wordfortitude]];
	elseif (currentSpecName == "Holy") then
		specString = [[Interface\Icons\spell_holy_guardianspirit]];
	elseif (currentSpecName == "Shadow") then
		specString = [[Interface\Icons\spell_shadow_shadowwordpain]];
	elseif (currentSpecName == "Elemental") then
		specString = [[Interface\Icons\spell_nature_lightning]];
	elseif (currentSpecName == "Enhancement") then
		specString = [[Interface\Icons\spell_nature_lightningshield]];
	elseif (currentSpecName == "Restoration") then
		specString = [[Interface\Icons\spell_nature_magicimmunity]];
	elseif (currentSpecName == "Affliction") then
		specString = [[Interface\Icons\spell_shadow_deathcoil]];
	elseif (currentSpecName == "Demonology") then
		specString = [[Interface\Icons\spell_shadow_metamorphosis]];
	elseif (currentSpecName == "Destruction") then
		specString = [[Interface\Icons\spell_shadow_rainoffire]];
	elseif (currentSpecName == "Arms") then
		specString = [[Interface\Icons\ability_rogue_eviscerate]];
	elseif (currentSpecName == "Fury") then
		specString = [[Interface\Icons\ability_warrior_innerrage]];
	elseif (currentSpecName == "Protection") then
		specString = [[Interface\Icons\inv_shield_06]];
	end
	return specString;
end