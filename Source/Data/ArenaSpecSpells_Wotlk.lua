local _, ArenaAnalytics = ...; -- Addon Namespace
local SpecSpells = ArenaAnalytics.SpecSpells;

-------------------------------------------------------------------------

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
function SpecSpells:GetSpec(spellID)
    return specSpells[spellID];
end