--[[ 
	Thanks to Gladdy for spec detection db 
]]

local _, core = ...; -- Namespace
local Constants = {}
core.Constants = Constants;

local specSpells = {
    -- DRUID
    [ 33831 ] = "Balance", -- Force of Nature
    [ 33983 ] = "Feral", -- Mangle (Cat)
    [ 33987 ] = "Feral", -- Mangle (Bear)
    [ 18562 ] = "Restoration", -- Swiftmend
    [ 17116 ] = "Restoration", -- Nature's Swiftness
    [ 45283 ] = "Restoration", -- Natural Perfection
    [ 24858 ] = "Balance", -- Moonkin Form
    [ 24932 ] = "Feral", -- Leader of the Pack
    [ 49376 ] = "Feral", -- Feral Charge: Cat
    [ 16979 ] = "Feral", -- Feral Charge: Bear
    [ 24907 ] = "Balance", -- Moonkin Aura
    [ 48505 ] = "Balance", -- Starfall (Rank 1)
    [ 53199 ] = "Balance", -- Starfall (Rank 2)
    [ 53200 ] = "Balance", -- Starfall (Rank 3)
    [ 53201 ] = "Balance", -- Starfall (Rank 4)
    [ 33891 ] = "Restoration", -- Tree of Life

    -- HUNTER
    [ 19577 ] = "Beast Mastery", -- Intimidation
    [ 34490 ] = "Marksmanship", -- Silencing Shot
    [ 27068 ] = "Survival", -- Wyvern Sting
    [ 19306 ] = "Survival", -- Counterattack
    [ 60053 ] = "Survival", -- Explosive Shot
    [ 19506 ] = "Marksmanship", -- Trueshot Aura
    [ 34692 ] = "Beast Mastery", -- The Beast Within
    [ 20895 ] = "Beast Mastery", -- Spirit Bond
    [ 34455 ] = "Beast Mastery", -- Ferocious Inspiration
    [ 53209 ] = "Marksmanship",  -- Chimera Shot

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
    [ 10060 ] = "Discipline", -- Power Infusion
    [ 33206 ] = "Discipline", -- Pain Suppression
    [ 14752 ] = "Discipline", -- Divine Spirit
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
    [ 45234 ] = "Discipline", -- Focused Will
    [ 27811 ] = "Discipline", -- Blessed Recovery
    [ 14752 ] = "Discipline", -- Divine Spirit
    [ 27681 ] = "Discipline", -- Prayer of Spirit
    [ 14893 ] = "Discipline", -- Inspiration
    [ 52800 ] = "Discipline", -- Borrowed Time
    [ 53007 ] = "Discipline", -- Penance

    -- ROGUE
    [ 14177 ] = "Assassination", -- Cold Blood
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
    [ 31233 ] = "Assassination", -- Find Weakness
    [ 48666 ] = "Assassination", -- Mutilate
    [ 57993 ] = "Assassination", -- Envenom
    [ 51662 ] = "Assassination", -- Hunger For Blood

    -- SHAMAN
    [ 16166 ] = "Elemental", -- Elemental Mastery
    [ 30823 ] = "Enhancement", -- Shamanistic Rage
    [ 17364 ] = "Enhancement", -- Stormstrike
    [ 16190 ] = "Restoration", -- Mana Tide Totem
    [ 49284 ] = "Restoration", -- Earth Shield
    [ 16190 ] = "Restoration", -- Mana Tide Totem
    [ 30823 ] = "Enhancement", -- Shamanistic Rage
    [ 61300 ] = "Restoration", -- Riptide
    [ 59159 ] = "Elemental", -- Thunderstorm

    -- WARLOCK
    [ 47843 ] = "Affliction", -- Unstable Affliction
    [ 47847 ] = "Destruction", -- Shadowfury
    [ 30302 ] = "Destruction", -- Nether Protection
    [ 34935 ] = "Destruction", -- Backlash
    [ 17962 ] = "Destruction", -- Conflagrate
    [ 59672 ] = "Demonology", -- Metamorphosis
    [ 59164 ] = "Affliction", -- Haunt

    -- WARRIOR
    [ 56638 ] = "Arms", -- Taste for Blood
    [ 64976 ] = "Arms", -- Juggernaut
    [ 47486 ] = "Arms", -- Mortal Strike
    [ 12292 ] = "Arms", -- Death Wish
    [ 23881 ] = "Fury", -- Bloodthirst
    [ 46916 ] = "Fury", -- Bloodsurge
    [ 12809 ] = "Protection", -- Concussion Blow
    [ 47498 ] = "Protection", -- Devastate
    [ 29838 ] = "Arms", -- Second Wind
    [ 46924 ] = "Arms", -- Bladestorm

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
function Constants:Racials()
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
	elseif (currentClassName == "Death Knight") then
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
	elseif (currentSpecName == "Frost" and class == "Death Knight") then
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
    elseif (currentSpecName == "Preg") then
        specString = [[Interface\Icons\ability_paladin_hammeroftherighteous]];
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

function Constants:GetBracketFromTeamSize(teamSize)
    return teamSize .. "v" .. teamSize;
end

function Constants:BracketIdFromTeamSize(teamSize)
    if(teamSize == 2) then
        return 1;
    elseif(teamSize == 3) then
        return 2;
    end    
    return 3;
end

function Constants:TeamSizeFromBracketId(bracketId)
    if(bracketId == 1) then
        return 2;
    elseif(teamSize == 2) then
        return 3;
    end    
    return 5;
end