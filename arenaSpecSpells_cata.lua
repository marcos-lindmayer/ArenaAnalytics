




local _, ArenaAnalytics = ...; -- Namespace
local SpecSpells = {}
ArenaAnalytics.SpecSpells = SpecSpells;

local specSpells = {
    --------------------------------------------------------
    -- DRUID
    [ 18562 ] = "Restoration", -- Swiftmend
    [ 17116 ] = "Restoration", -- Nature's Swiftness
    [ 48438 ] = "Restoration", -- Wild Growth
    [ 33891 ] = "Restoration", -- Tree of Life

    [ 33917 ] = "Feral", -- Mangle
    [ 49377 ] = "Feral", -- Feral Charge
    [ 61336 ] = "Feral", -- Survival Instincts
    [ 80313 ] = "Feral", -- Pulverize
    [ 33983 ] = "Feral", -- Berserk
    
    [ 78674 ] = "Balance", -- Starsurge
    [ 24858 ] = "Balance", -- Moonkin Form
    [ 50516 ] = "Balance", -- Typhoon
    [ 78675 ] = "Balance", -- Solar Beam
    [ 33831 ] = "Balance", -- Force of Nature
    [ 48505 ] = "Balance", -- Starfall

    --------------------------------------------------------
    -- HUNTER

    [ 19434 ] = "Marksmanship", -- Aimed Shot
    [ 34490 ] = "Marksmanship", -- Silencing Shot
    [ 23989 ] = "Marksmanship", -- Readiness
    [ 53209 ] = "Marksmanship",  -- Chimera Shot

    [ 53301 ] = "Survival", -- Explosive Shot
    [ 19306 ] = "Survival", -- Counterattack
    [ 19386 ] = "Survival", -- Wyvern Sting
    [ 3674 ] = "Survival", -- Black Arrow

    [ 19577 ] = "Beast Mastery", -- Intimidation
    [ 82726 ] = "Beast Mastery", -- Fervor
    [ 82692 ] = "Beast Mastery", -- Focus Fire
    [ 19574 ] = "Beast Mastery", -- Bestial Wrath

    --------------------------------------------------------
    -- MAGE

    [ 44425 ] = "Arcane", -- Arcane Barrage
    [ 12043 ] = "Arcane", -- Presence of Mind
    [ 31589 ] = "Arcane", -- Slow
    [ 54646 ] = "Arcane", -- Focus Magic
    [ 12042 ] = "Arcane", -- Arcane Power

    [ 31687 ] = "Frost", -- Summon Water Elemental
    [ 12472 ] = "Frost", -- Icy Veins
    [ 11958 ] = "Frost", -- Cold Snap
    [ 11426 ] = "Frost", -- Ice Barrier
    [ 44572 ] = "Frost", -- Deep Freeze
   
    [ 11366 ] = "Fire", -- Pyroblast
    [ 11113 ] = "Fire", -- Blast Wave
    [ 11129 ] = "Fire", -- Combustion
    [ 31661 ] = "Fire", -- Dragon's Breath
    [ 44457 ] = "Fire", -- Living Bomb
    [ 31642 ] = "Fire", -- Blazing Speed

    --------------------------------------------------------
    -- PALADIN

    [ 20473 ] = "Holy", -- Holy Shock
    [ 31842 ] = "Holy", -- Divine Favor
    [ 53563 ] = "Holy", -- Beacon of Light
    [ 31821 ] = "Holy", -- Aura Mastery
    [ 85222 ] = "Holy", -- Light of Dawn

    [ 85256 ] = "Retribution", -- Templar's Verdict
    [ 53385 ] = "Retribution", -- Divine Storm
    [ 85285 ] = "Retribution", -- Sacred Shield (Passive Trigger)
    [ 20066 ] = "Retribution", -- Repentance
    [ 85696 ] = "Retribution", -- Zealoty
    
    [ 31935 ] = "Protection", -- Avenger's Shield
    [ 53595 ] = "Protection", -- Hammer of the Righteous
    [ 31935 ] = "Protection", -- Shield of the Righteous
    [ 20925 ] = "Protection", -- Holy Shield
    [ 20927 ] = "Protection", -- Divine Guardian
    [ 20928 ] = "Protection", -- Ardent Defender

    --------------------------------------------------------
    -- PRIEST

    [ 88625 ] = "Holy", -- Holy Word: Chastice
    [ 88684 ] = "Holy", -- Holy Word: Serenity
    [ 88685 ] = "Holy", -- Holy Word: Sanctuary
    [ 724 ] = "Holy", -- Lightwell
    [ 14751 ] = "Holy", -- Chakra
    [ 34861 ] = "Holy", -- Circle of Healing
    [ 47788 ] = "Holy", -- Guardian Spirit

    [ 15407 ] = "Shadow", -- Mind Flay
    [ 15473 ] = "Shadow", -- Shadowform
    [ 15487 ] = "Shadow", -- Silence
    [ 15286 ] = "Shadow", -- Vampiric Embrace
    [ 34914 ] = "Shadow", -- Vampiric Touch
    [ 64044 ] = "Shadow", -- Psychic Horror
    [ 47585 ] = "Shadow", -- Dispersion

    [ 47540 ] = "Discipline", -- Penance
    [ 10060 ] = "Discipline", -- Power Infusion
    [ 89485 ] = "Discipline", -- Inner Focus
    [ 33206 ] = "Discipline", -- Pain Suppression
    [ 62618 ] = "Discipline", -- Power Word: Barrier

    --------------------------------------------------------
    -- ROGUE

    [ 13877 ] = "Combat", -- Blade Fury
    [ 84617 ] = "Combat", -- Revealing Strike
    [ 13750 ] = "Combat", -- Adrenaline Rush
    [ 51690 ] = "Combat", -- Killing Spree

    [ 36554 ] = "Subtlety", -- Shadowstep
    [ 16511 ] = "Subtlety", -- Hemorrhage
    [ 14183 ] = "Subtlety", -- Premeditation
    [ 14185 ] = "Subtlety", -- Preparation
    [ 51713 ] = "Subtlety", -- Shadow Dance

    [ 1329 ] = "Assassination", -- Mutilate
    [ 14177 ] = "Assassination", -- Cold Blood
    [ 79140 ] = "Assassination", -- Vendetta

    --------------------------------------------------------
    -- SHAMAN
    
    [ 974 ] = "Restoration", -- Earth Shield
    [ 16188 ] = "Restoration", -- Nature's Swiftness
    [ 16190 ] = "Restoration", -- Mana Tide Totem
    [ 61295 ] = "Restoration", -- Riptide

    [ 60103 ] = "Enhancement", -- Lava Lash
    [ 17364 ] = "Enhancement", -- Stormstrike
    [ 30823 ] = "Enhancement", -- Shamanistic Rage
    [ 51533 ] = "Enhancement", -- Feral Spirit

    [ 51490 ] = "Elemental", -- Thunderstorm
    [ 16166 ] = "Elemental", -- Elemental Mastery
    [ 61882 ] = "Elemental", -- Earthquake
    
    --------------------------------------------------------
    -- WARLOCK

    [ 17962 ] = "Destruction", -- Conflagrate
    [ 17877 ] = "Destruction", -- Shadowburn
    [ 30283 ] = "Destruction", -- Shadowfury
    [ 80240 ] = "Destruction", -- Bane of Havoc
    [ 50796 ] = "Destruction", -- Chaos Bolt

    [ 30146 ] = "Demonology", -- Summon Felguard
    [ 47193 ] = "Demonology", -- Demonic Empowerment
    [ 71521 ] = "Demonology", -- Hand of Gul'dan
    [ 59672 ] = "Demonology", -- Metamorphosis
    
    [ 30108 ] = "Affliction", -- Unstable Affliction
    [ 18223 ] = "Affliction", -- Curse of Exhaustion
    [ 86121 ] = "Affliction", -- Soul Swap
    [ 48181 ] = "Affliction", -- Haunt

    --------------------------------------------------------
    -- WARRIOR

    [ 12294 ] = "Arms", -- Mortal Strike
    [ 12328 ] = "Arms", -- Sweeping Strikes
    [ 85730 ] = "Arms", -- Deadly Calm
    [ 85388 ] = "Arms", -- Throwdown
    [ 46924 ] = "Arms", -- Bladestorm

    [ 23881 ] = "Fury", -- Bloodthirst
    [ 12292 ] = "Fury", -- Death Wish
    [ 85288 ] = "Fury", -- Raging Blow
    [ 60970 ] = "Fury", -- Heroic Fury
    
    [ 23922 ] = "Protection", -- Shield Slam
    [ 12975 ] = "Protection", -- Last Stand
    [ 12809 ] = "Protection", -- Concussion Blow
    [ 20243 ] = "Protection", -- Devastate
    [ 50720 ] = "Protection", -- Vigilance
    [ 46968 ] = "Protection", -- Shockwave

    --------------------------------------------------------
    -- DEATHKNIGHT

    [ 55090 ] = "Unholy", -- Scourge Strike
    [ 49016 ] = "Unholy", -- Unholy Frenzy
    [ 51052 ] = "Unholy", -- Anti-magic Zone
    [ 63560 ] = "Unholy", -- Dark Transformation
    [ 49206 ] = "Unholy", -- Summon Gargoyle

    [ 49143 ] = "Frost", -- Frost Strike
    [ 51271 ] = "Frost", -- Pillar of Frost
    [ 49203 ] = "Frost", -- Hungering Cold
    [ 49184 ] = "Frost", -- Howling Blast

    [ 55050 ] = "Blood", -- Heart Strike
    [ 50034 ] = "Blood", -- Blood Rites
    [ 49222 ] = "Blood", -- Bone Shield
    [ 48982 ] = "Blood", -- Rune Tap
    [ 55233 ] = "Blood", -- Vampiric Blood
    [ 49028 ] = "Blood", -- Dancing Rune Weapon
}

function SpecSpells:GetSpec(spellID)
    return specSpells[spellID];   
end