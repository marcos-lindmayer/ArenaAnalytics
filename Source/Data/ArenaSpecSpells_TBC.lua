local _, ArenaAnalytics = ...; -- Addon Namespace
local SpecSpells = ArenaAnalytics.SpecSpells;

-- Local module aliases
local SpecSpells = ArenaAnalytics.SpecSpells;
local API = ArenaAnalytics.API;
local Helpers = ArenaAnalytics.Helpers;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------

--[[
    ## TBC Hybrid Spec Support

    List all talents, marking spec ID and minimum point cost?
    Add functionality to track most points proven per spec, finalize computed spec by the end?

    Format:

    [ 18562 ] = data(1, 15); -- Swiftmend (Example)
    [  ] = data(1, 0); -- 
--]]

local function data(spec, points)
    return { id = spec, points = points };
end

local specSpells = {
    --------------------------------------------------------
    -- DRUID

    -- 1 Restoration
    [ 17116 ] = data(1, 21); -- Nature's Swiftness
    [ 18562 ] = data(1, 31); -- Swiftmend
    [ 45281 ] = data(1, 31); -- Natural Perfection [Rank 1]
    [ 45282 ] = data(1, 31); -- Natural Perfection [Rank 2]
    [ 45283 ] = data(1, 31); -- Natural Perfection [Rank 3]
    [ 33891 ] = data(1, 41); -- Tree of Life

    -- 2 Feral Combat
    [ 26993 ] = data(2, 21); -- Faerie Fire  ... Multiple forms?
    [ 24932 ] = data(2, 31); -- Leader of the Pack
    [ 33983 ] = data(2, 41); -- Mangle (Cat)
    [ 33987 ] = data(2, 41); -- Mangle Bear

    -- 3 Balance
    [ 16886 ] = data(3, 21); -- Nature's Grace
    [ 24858 ] = data(3, 31); -- Moonkin Form
    [ 24907 ] = data(3, 31); -- Moonkin Aura
    [ 33831 ] = data(3, 41); -- Force of Nature


    --------------------------------------------------------
    -- PALADIN

    -- 11 Holy
    [ 20216 ] = data(11, 21); -- Divine Favor
    [ 31834 ] = data(11, 31); -- Light's Grace
    [ 33072 ] = data(11, 31); -- Holy Shock
    [ 31842 ] = data(11, 41); -- Divine Illumination

    -- 12 Protection
    [ 27168 ] = data(12, 21); -- Blessing of Sanctuary
    [ 27169 ] = data(12, 21); -- Greater Blessing of Sanctuary
    [ 20925 ] = data(12, 31); -- Holy Shield
    [ 32700 ] = data(12, 41); -- Avenger's Shield

    -- 14 Retribution
    [ 20218 ] = data(14, 21); -- Sanctity Aura
    [ 20055 ] = data(14, 26); -- Vengeance
    [ 20066 ] = data(14, 31); -- Repentance
    [ 35395 ] = data(14, 41); -- Crusader Strike


    --------------------------------------------------------
    -- SHAMAN

    -- 21 Restoration
    [ 29203 ] = data(21, 21); -- Healing Way
    [ 16188 ] = data(21, 21); -- Nature's Swiftmend
    [ 16190 ] = data(21, 31); -- Mana Tide Totem
    [ 32594 ] = data(21, 41); -- Earth Shield

    -- 22 Elemental
    [ 16166 ] = data(22, 31); -- Elemental Mastery
    [ 30706 ] = data(22, 41); -- Totem of Wrath

    -- 23 Enhancement
    [ 17364 ] = data(23, 31); -- Stormstrike
    [ 30807 ] = data(23, 36); -- Unleashed Rage
    [ 30823 ] = data(23, 41); -- Shamanistic Rage


    --------------------------------------------------------
    -- HUNTER

    -- Beast Mastery    @TODO: Add pet spells: Ferocious Inspiration, Frenzy, 
    [ 24529 ] = data(41, 41); -- Spirit Bond
    [ 19577 ] = data(41, 21); -- Intimidation
    [ 19574 ] = data(41, 31); -- Bestial Wrath
    [ 34471 ] = data(41, 41); -- The Beast Within

    -- Marksmanship
    [ 19503 ] = data(42, 21); -- Scatter Shot
    [ 19506 ] = data(42, 31); -- Trueshot Aura
    [ 34490 ] = data(42, 41); -- Silencing Shot

    -- Survival
    [ 19306 ] = data(43, 21); -- Counterattack
    [ 19386 ] = data(43, 31); -- Wyvern Sting
    [ 34501 ] = data(43, 31); -- Expose Weakness
    [ 34837 ] = data(43, 36); -- Master Tactician
    [ 23989 ] = data(43, 41); -- Readiness


    --------------------------------------------------------
    -- MAGE

    -- Frost
    [ 11958 ] = data(51, 21); -- Cold Snap
    [ 12579 ] = data(51, 31); -- Winter's Chill
    [ 11426 ] = data(51, 31); -- Ice Barrier
    [ 33405 ] = data(51, 31); -- Ice Barrier
    [ 31687 ] = data(51, 41); -- Summon Water Elemental

    -- Fire
    [ 11113 ] = data(52, 21); -- Blast Wave
    [ 31643 ] = data(52, 26); -- Blazing Speed
    [ 28682 ] = data(52, 31); -- Combustion
    [ 33043 ] = data(52, 41); -- Dragon's Breath

    -- Arcane
    [ 46989 ] = data(53, 21); -- Improved Blink
    [ 12043 ] = data(53, 21); -- Presence of Mind
    [ 12042 ] = data(53, 31); -- Arcane Power
    [ 31589 ] = data(53, 41); -- Slow


    --------------------------------------------------------
    -- ROGUE

    -- Subtlety
    [ 14185 ] = data(61, 21); -- Preparation
    [ 16511 ] = data(61, 21); -- Hemorrhage
    [ 14183 ] = data(61, 31); -- Premeditation
    [ 45182 ] = data(61, 31); -- Cheating Death
    [ 36563 ] = data(61, 41); -- Shadowstep

    -- Assassination
    [ 14177 ] = data(62, 21); -- Cold Blood
    [ 31238 ] = data(62, 36); -- Find Weakness
    [ 1329 ] = data(62, 41); -- Mutilate
    [ 27576 ] = data(62, 41); -- Mutilate
    [ 34413 ] = data(62, 41); -- Mutilate

    -- Combat
    [ 13877 ] = data(63, 21); -- Blade Flurry
    [ 13750 ] = data(63, 31); -- Adrenaline Rush


    --------------------------------------------------------
    -- WARLOCK

    -- Affliction
    [ 32386 ] = data(71, 21); -- Shadow Embrace
    [ 30911 ] = data(71, 26); -- Siphon Life
    [ 18223 ] = data(71, 26); -- Curse of Exhaustion
    [ 18220 ] = data(71, 31); -- Dark Pact
    [ 30108 ] = data(71, 41); -- Unstable Affliction

    -- Destruction
    [ 18093 ] = data(72, 21); -- Pyroclasm (Aura)?
    [ 30300 ] = data(72, 26); -- Nether Protection (Aura)?
    [ 34936 ] = data(72, 31); -- Backlash (Aura)?
    [ 30912 ] = data(72, 31); -- Conflagrate
    [ 30414 ] = data(72, 41); -- Shadowfury

    -- Demonology
    [ 18788 ] = data(73, 21); -- Demonic Sacrifice
    [ 19028 ] = data(73, 31); -- Soul Link
    [ 30146 ] = data(73, 41); -- Summon Felguard


    --------------------------------------------------------
    -- WARRIOR

    -- Protection
    [ 12809 ] = data(81, 21); -- Concussion Blow
    [ 18498 ] = data(81, 21); -- Shield Bash - Silenced
    [ 23922 ] = data(81, 31); -- Shield Slam
    [ 30022 ] = data(81, 41); -- Devastate

    -- Arms
    [ 12292 ] = data(82, 21); -- Death Wish
    [ 23694 ] = data(82, 26); -- Improved Hamstring
    [ 30330 ] = data(82, 31); -- Mortal Strike
    [ 29842 ] = data(82, 31); -- Second Wind

    -- Fury
    [ 12328 ] = data(83, 21); -- Sweeping Strikes
    [ 16280 ] = data(83, 26); -- Flurry
    [ 30335 ] = data(83, 31); -- Bloodthirst
    [ 29801 ] = data(83, 41); -- Rampage (Rank 1)
    [ 30029 ] = data(83, 41); -- Rampage Buff (Rank 1)
    [ 30030 ] = data(83, 41); -- Rampage (Rank 2)
    [ 30031 ] = data(83, 41); -- Rampage Buff (Rank 2)
    [ 30033 ] = data(83, 41); -- Rampage (Rank 3)
    [ 30032 ] = data(83, 41); -- Rampage Buff (Rank 3)


    --------------------------------------------------------
    -- PRIEST

    -- Discipline
    [ 25312 ] = data(91, 21); -- Divine Spirit
    [ 45242 ] = data(91, 31); -- Focused Will
    [ 10060 ] = data(91, 31); -- Power Infusion
    [ 33619 ] = data(91, 31); -- Reflective Shield?
    [ 29601 ] = data(91, 36); -- Enlightenment
    [ 33206 ] = data(91, 41); -- Pain Supression

    -- Holy
    [ 27827 ] = data(92, 21); -- Spirit of Redemption
    [ 33151 ] = data(92, 26); -- Surge of Light
    [ 724 ] = data(92, 31); -- Lightwell
    [ 33143 ] = data(92, 31); -- Blessed Resilience (Aura)
    [ 34865 ] = data(92, 41); -- Circle of Healing

    -- Shadow
    [ 15487 ] = data(93, 21); -- Silence
    [ 15286 ] = data(93, 21); -- Vampiric Embrace
    [ 15473 ] = data(93, 31); -- Shadowform
    [ 33200 ] = data(93, 36); -- Misery
    [ 34917 ] = data(93, 41); -- Vampiric Touch
};

function SpecSpells:GetSpec(spellID, spellName)
    local data = specSpells[spellID];
    if(not data) then
        return nil, nil;
    end

    Debug:LogGreen("SpecSpells:", data.id, data.points, "for spell:", spellName);
    return data.id, data.points;
end