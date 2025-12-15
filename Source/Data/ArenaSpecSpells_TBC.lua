local _, ArenaAnalytics = ...; -- Addon Namespace
local SpecSpells = ArenaAnalytics.SpecSpells;

-- Local module aliases
local SpecSpells = ArenaAnalytics.SpecSpells;
local API = ArenaAnalytics.API;
local Helpers = ArenaAnalytics.Helpers;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------

--[[
    ## Missing combat log events:
        - Resource Recovery
        - Extra Attack
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
    [ 34123 ] = data(1, 41); -- Tree of Life (Healing Buff)

    -- 2 Feral Combat
    [ 770 ] = data(2, 21); -- Faerie Fire [Rank 1]
    [ 778 ] = data(2, 21); -- Faerie Fire [Rank 2]
    [ 9749 ] = data(2, 21); -- Faerie Fire [Rank 3]
    [ 9907 ] = data(2, 21); -- Faerie Fire [Rank 4]
    [ 26993 ] = data(2, 21); -- Faerie Fire [Rank 5]
    [ 16857 ] = data(2, 21); -- Faerie Fire (Feral) [Rank 1]
    [ 17390 ] = data(2, 21); -- Faerie Fire (Feral) [Rank 2]
    [ 17391 ] = data(2, 21); -- Faerie Fire (Feral) [Rank 3]
    [ 17392 ] = data(2, 21); -- Faerie Fire (Feral) [Rank 4]
    [ 27011 ] = data(2, 21); -- Faerie Fire (Feral) [Rank 5]
    [ 24932 ] = data(2, 31); -- Leader of the Pack
    [ 33876 ] = data(2, 41); -- Mangle (Cat) [Rank 1]
    [ 33982 ] = data(2, 41); -- Mangle (Cat) [Rank 2]
    [ 33983 ] = data(2, 41); -- Mangle (Cat) [Rank 3]
    [ 33878 ] = data(2, 41); -- Mangle (Bear) [Rank 1]
    [ 33986 ] = data(2, 41); -- Mangle (Bear) [Rank 2]
    [ 33987 ] = data(2, 41); -- Mangle (Bear) [Rank 3]

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
    [ 20473 ] = data(11, 31); -- Holy Shock [Rank 1]
    [ 20929 ] = data(11, 31); -- Holy Shock [Rank 2]
    [ 20930 ] = data(11, 31); -- Holy Shock [Rank 3]
    [ 27174 ] = data(11, 31); -- Holy Shock [Rank 4]
    [ 33072 ] = data(11, 31); -- Holy Shock [Rank 5]
    [ 31842 ] = data(11, 41); -- Divine Illumination

    -- 12 Protection
    [ 20911 ] = data(12, 21); -- Blessing of Sanctuary [Rank 1]
    [ 20912 ] = data(12, 21); -- Blessing of Sanctuary [Rank 2]
    [ 20913 ] = data(12, 21); -- Blessing of Sanctuary [Rank 3]
    [ 20914 ] = data(12, 21); -- Blessing of Sanctuary [Rank 4]
    [ 27168 ] = data(12, 21); -- Blessing of Sanctuary [Rank 5]
    [ 25899 ] = data(12, 21); -- Greater Blessing of Sanctuary [Rank 1]
    [ 27169 ] = data(12, 21); -- Greater Blessing of Sanctuary [Rank 2]
    [ 20178 ] = data(12, 21); -- Reckoning
    [ 20925 ] = data(12, 31); -- Holy Shield [Rank 1]
    [ 20927 ] = data(12, 31); -- Holy Shield [Rank 2]
    [ 20928 ] = data(12, 31); -- Holy Shield [Rank 3]
    [ 27179 ] = data(12, 31); -- Holy Shield [Rank 4]
    [ 31935 ] = data(12, 41); -- Avenger's Shield [Rank 1]
    [ 32699 ] = data(12, 41); -- Avenger's Shield [Rank 2]
    [ 32700 ] = data(12, 41); -- Avenger's Shield [Rank 3]

    -- 14 Retribution
    [ 20218 ] = data(14, 21); -- Sanctity Aura
    [ 20049 ] = data(14, 26); -- Vengeance [Rank 1]
    [ 20056 ] = data(14, 26); -- Vengeance [Rank 2]
    [ 20057 ] = data(14, 26); -- Vengeance [Rank 3]
    [ 20058 ] = data(14, 26); -- Vengeance [Rank 4]
    [ 20059 ] = data(14, 26); -- Vengeance [Rank 5]
    [ 20055 ] = data(14, 26); -- Vengeance (Buff)
    [ 20066 ] = data(14, 31); -- Repentance
    [ 35395 ] = data(14, 41); -- Crusader Strike


    --------------------------------------------------------
    -- SHAMAN

    -- 21 Restoration
    [ 29203 ] = data(21, 21); -- Healing Way (Buff)
    [ 16188 ] = data(21, 21); -- Nature's Swiftmend
    [ 16190 ] = data(21, 31); -- Mana Tide Totem
    [ 974 ] = data(21, 41); -- Earth Shield [Rank 1]
    [ 32593 ] = data(21, 41); -- Earth Shield [Rank 2]
    [ 32594 ] = data(21, 41); -- Earth Shield [Rank 3]

    -- 22 Elemental
--[[    @TODO: Include sub-21 point talents?
    [ 30160 ] = data(22, 16); -- Elemental Devastation [Rank 1]
    [ 29179 ] = data(22, 16); -- Elemental Devastation [Rank 2]
    [ 29180 ] = data(22, 16); -- Elemental Devastation [Rank 3]
    [ 30165 ] = data(22, 16); -- Elemental Devastation (Effect) [Rank 1]
    [ 29177 ] = data(22, 16); -- Elemental Devastation (Effect) [Rank 2]
    [ 29178 ] = data(22, 16); -- Elemental Devastation (Effect) [Rank 3]
--]]
    [ 16166 ] = data(22, 31); -- Elemental Mastery
    [ 30706 ] = data(22, 41); -- Totem of Wrath
    [ 30708 ] = data(22, 41); -- Totem of Wrath (Aura)

    -- 23 Enhancement
    [ 17364 ] = data(23, 31); -- Stormstrike
    [ 32175 ] = data(23, 31); -- Stormstrike (Effect 1)
    [ 32176 ] = data(23, 31); -- Stormstrike (Effect 2)
    [ 30802 ] = data(23, 36); -- Unleashed Rage [Rank 1]
    [ 30808 ] = data(23, 36); -- Unleashed Rage [Rank 2]
    [ 30809 ] = data(23, 36); -- Unleashed Rage [Rank 3]
    [ 30810 ] = data(23, 36); -- Unleashed Rage [Rank 4]
    [ 30811 ] = data(23, 36); -- Unleashed Rage [Rank 5]
    [ 30803 ] = data(23, 36); -- Unleashed Rage (Effect) [Rank 1]
    [ 30804 ] = data(23, 36); -- Unleashed Rage (Effect) [Rank 2]
    [ 30805 ] = data(23, 36); -- Unleashed Rage (Effect) [Rank 3]
    [ 30806 ] = data(23, 36); -- Unleashed Rage (Effect) [Rank 4]
    [ 30807 ] = data(23, 36); -- Unleashed Rage (Effect) [Rank 5]
    [ 30823 ] = data(23, 41); -- Shamanistic Rage
    [ 30824 ] = data(23, 41); -- Shamanistic Rage (Effect)


    --------------------------------------------------------
    -- HUNTER

    -- Beast Mastery
    [ 24529 ] = data(41, 21); -- Spirit Bond [Rank 1]
    [ 20895 ] = data(41, 21); -- Spirit Bond [Rank 2]
    [ 19577 ] = data(41, 21); -- Intimidation
    [ 24394 ] = data(41, 21); -- Intimidation (Stun)
    [ 19615 ] = data(41, 26); -- Frenzy Effect
    [ 34456 ] = data(41, 31); -- Ferocious Inspiration
    [ 19574 ] = data(41, 31); -- Bestial Wrath
    [ 34471 ] = data(41, 41); -- The Beast Within

    -- Marksmanship
    [ 35101 ] = data(42, 21); -- Concussive Barrage
    [ 19503 ] = data(42, 21); -- Scatter Shot
    [ 19506 ] = data(42, 31); -- Trueshot Aura [Rank 1]
    [ 20905 ] = data(42, 31); -- Trueshot Aura [Rank 2]
    [ 20906 ] = data(42, 31); -- Trueshot Aura [Rank 3]
    [ 27066 ] = data(42, 31); -- Trueshot Aura [Rank 4]
    [ 34490 ] = data(42, 41); -- Silencing Shot

    -- Survival
    [ 19306 ] = data(43, 21); -- Counterattack [Rank 1]
    [ 20909 ] = data(43, 21); -- Counterattack [Rank 2]
    [ 20910 ] = data(43, 21); -- Counterattack [Rank 3]
    [ 27067 ] = data(43, 21); -- Counterattack [Rank 4]
    [ 19386 ] = data(43, 31); -- Wyvern Sting [Rank 1]
    [ 24132 ] = data(43, 31); -- Wyvern Sting [Rank 2]
    [ 24133 ] = data(43, 31); -- Wyvern Sting [Rank 3]
    [ 27068 ] = data(43, 31); -- Wyvern Sting [Rank 4]
    [ 34501 ] = data(43, 31); -- Expose Weakness (Aura)
    [ 34833 ] = data(43, 36); -- Master Tactician (Aura) [Rank 1]
    [ 34834 ] = data(43, 36); -- Master Tactician (Aura) [Rank 2]
    [ 34835 ] = data(43, 36); -- Master Tactician (Aura) [Rank 3]
    [ 34836 ] = data(43, 36); -- Master Tactician (Aura) [Rank 4]
    [ 34837 ] = data(43, 36); -- Master Tactician (Aura) [Rank 5]
    [ 23989 ] = data(43, 41); -- Readiness


    --------------------------------------------------------
    -- MAGE

    -- Frost
    [ 11958 ] = data(51, 21); -- Cold Snap
    [ 12579 ] = data(51, 26); -- Winter's Chill
    [ 11426 ] = data(51, 31); -- Ice Barrier [Rank 1]
    [ 13031 ] = data(51, 31); -- Ice Barrier [Rank 2]
    [ 13032 ] = data(51, 31); -- Ice Barrier [Rank 3]
    [ 13033 ] = data(51, 31); -- Ice Barrier [Rank 4]
    [ 27134 ] = data(51, 31); -- Ice Barrier [Rank 5]
    [ 33405 ] = data(51, 31); -- Ice Barrier [Rank 6]
    [ 31687 ] = data(51, 41); -- Summon Water Elemental

    -- Fire
    [ 11113 ] = data(52, 21); -- Blast Wave [Rank 1]
    [ 13018 ] = data(52, 21); -- Blast Wave [Rank 2]
    [ 13019 ] = data(52, 21); -- Blast Wave [Rank 3]
    [ 13020 ] = data(52, 21); -- Blast Wave [Rank 4]
    [ 13021 ] = data(52, 21); -- Blast Wave [Rank 5]
    [ 27133 ] = data(52, 21); -- Blast Wave [Rank 6]
    [ 33933 ] = data(52, 21); -- Blast Wave [Rank 7]
    [ 31643 ] = data(52, 26); -- Blazing Speed
    [ 28682 ] = data(52, 31); -- Combustion
    [ 31661 ] = data(52, 41); -- Dragon's Breath [Rank 1]
    [ 33041 ] = data(52, 41); -- Dragon's Breath [Rank 2]
    [ 33042 ] = data(52, 41); -- Dragon's Breath [Rank 3]
    [ 33043 ] = data(52, 41); -- Dragon's Breath [Rank 4]

    -- Arcane
    [ 47000 ] = data(53, 21); -- Improved Blink [Rank 1]
    [ 46989 ] = data(53, 21); -- Improved Blink [Rank 2]
    [ 12043 ] = data(53, 21); -- Presence of Mind
    [ 12042 ] = data(53, 31); -- Arcane Power
    [ 31589 ] = data(53, 41); -- Slow


    --------------------------------------------------------
    -- ROGUE

    -- Subtlety
    [ 14185 ] = data(61, 21); -- Preparation
    [ 16511 ] = data(61, 21); -- Hemorrhage [Rank 1]
    [ 17347 ] = data(61, 21); -- Hemorrhage [Rank 2]
    [ 17348 ] = data(61, 21); -- Hemorrhage [Rank 3]
    [ 26864 ] = data(61, 21); -- Hemorrhage [Rank 4]
    [ 14183 ] = data(61, 31); -- Premeditation
    [ 45182 ] = data(61, 31); -- Cheating Death
    [ 36554 ] = data(61, 41); -- Shadowstep
    [ 36563 ] = data(61, 41); -- Shadowstep (Effect 1)
    [ 44373 ] = data(61, 41); -- Shadowstep (Effect 2)

    -- Assassination
    [ 14177 ] = data(62, 21); -- Cold Blood
    [ 31244 ] = data(62, 21); -- Quick Recovery [Rank 1]
    [ 31245 ] = data(62, 21); -- Quick Recovery [Rank 2]
    [ 31234 ] = data(62, 36); -- Find Weakness [Rank 1]
    [ 31235 ] = data(62, 36); -- Find Weakness [Rank 2]
    [ 31236 ] = data(62, 36); -- Find Weakness [Rank 3]
    [ 31237 ] = data(62, 36); -- Find Weakness [Rank 4]
    [ 31238 ] = data(62, 36); -- Find Weakness [Rank 5]
    [ 1329 ] = data(62, 41); -- Mutilate [Rank 1]
    [ 34411 ] = data(62, 41); -- Mutilate [Rank 2]
    [ 34412 ] = data(62, 41); -- Mutilate [Rank 3]
    [ 34413 ] = data(62, 41); -- Mutilate [Rank 4]

    -- Combat
    [ 13877 ] = data(63, 21); -- Blade Flurry
    [ 31125 ] = data(63, 26); -- Blade Twisting (Daze)
    [ 13750 ] = data(63, 31); -- Adrenaline Rush
    [ 35542 ] = data(63, 36); -- Combat Potency [Rank 1]
    [ 35545 ] = data(63, 36); -- Combat Potency [Rank 2]
    [ 35546 ] = data(63, 36); -- Combat Potency [Rank 3]
    [ 35547 ] = data(63, 36); -- Combat Potency [Rank 4]
    [ 35548 ] = data(63, 36); -- Combat Potency [Rank 5]


    --------------------------------------------------------
    -- WARLOCK

    -- Affliction
    [ 32386 ] = data(71, 21); -- Shadow Embrace [Rank 1]
    [ 32388 ] = data(71, 21); -- Shadow Embrace [Rank 2]
    [ 32389 ] = data(71, 21); -- Shadow Embrace [Rank 3]
    [ 32390 ] = data(71, 21); -- Shadow Embrace [Rank 4]
    [ 32391 ] = data(71, 21); -- Shadow Embrace [Rank 5]
    [ 18265 ] = data(71, 21); -- Siphon Life [Rank 1]
    [ 18879 ] = data(71, 21); -- Siphon Life [Rank 2]
    [ 18880 ] = data(71, 21); -- Siphon Life [Rank 3]
    [ 18881 ] = data(71, 21); -- Siphon Life [Rank 4]
    [ 27264 ] = data(71, 21); -- Siphon Life [Rank 5]
    [ 30911 ] = data(71, 21); -- Siphon Life [Rank 6]
    [ 18223 ] = data(71, 21); -- Curse of Exhaustion
    [ 18220 ] = data(71, 31); -- Dark Pact [Rank 1]
    [ 18937 ] = data(71, 31); -- Dark Pact [Rank 2]
    [ 18938 ] = data(71, 31); -- Dark Pact [Rank 3]
    [ 27265 ] = data(71, 31); -- Dark Pact [Rank 4]
    [ 30108 ] = data(71, 41); -- Unstable Affliction [Rank 1]
    [ 30404 ] = data(71, 41); -- Unstable Affliction [Rank 2]
    [ 30405 ] = data(71, 41); -- Unstable Affliction [Rank 3]

    -- Destruction
    [ 18093 ] = data(72, 21); -- Pyroclasm (Aura)
    [ 30300 ] = data(72, 26); -- Nether Protection (Aura)
    [ 34936 ] = data(72, 31); -- Backlash (Aura)
    [ 17962 ] = data(72, 31); -- Conflagrate [Rank 1]
    [ 18930 ] = data(72, 31); -- Conflagrate [Rank 2]
    [ 18931 ] = data(72, 31); -- Conflagrate [Rank 3]
    [ 18932 ] = data(72, 31); -- Conflagrate [Rank 4]
    [ 27266 ] = data(72, 31); -- Conflagrate [Rank 5]
    [ 30293 ] = data(72, 31); -- Conflagrate [Rank 6]
    [ 30912 ] = data(72, 31); -- Soul Leech [Rank 1]
    [ 30295 ] = data(72, 31); -- Soul Leech [Rank 2]
    [ 30296 ] = data(72, 31); -- Soul Leech [Rank 3]
    [ 30283 ] = data(72, 41); -- Shadowfury [Rank 1]
    [ 30413 ] = data(72, 41); -- Shadowfury [Rank 2]
    [ 30414 ] = data(72, 41); -- Shadowfury [Rank 3]

    -- Demonology
    [ 18788 ] = data(73, 21); -- Demonic Sacrifice
    [ 19028 ] = data(73, 31); -- Soul Link
    [ 25228 ] = data(73, 31); -- Soul Link Effect
    [ 35696 ] = data(73, 31); -- Demonic Knowledge
    [ 30146 ] = data(73, 41); -- Summon Felguard


    --------------------------------------------------------
    -- WARRIOR

    -- Protection
    [ 12809 ] = data(81, 21); -- Concussion Blow
    [ 18498 ] = data(81, 21); -- Shield Bash - Silenced
    [ 23922 ] = data(81, 31); -- Shield Slam [Rank 1]
    [ 23923 ] = data(81, 31); -- Shield Slam [Rank 2]
    [ 23924 ] = data(81, 31); -- Shield Slam [Rank 3]
    [ 23925 ] = data(81, 31); -- Shield Slam [Rank 4]
    [ 25258 ] = data(81, 31); -- Shield Slam [Rank 5]
    [ 30356 ] = data(81, 31); -- Shield Slam [Rank 6]
    [ 20243 ] = data(81, 41); -- Devastate [Rank 1]
    [ 30016 ] = data(81, 41); -- Devastate [Rank 2]
    [ 30022 ] = data(81, 41); -- Devastate [Rank 3]

    -- Arms
    [ 12292 ] = data(82, 21); -- Death Wish
    [ 23694 ] = data(82, 26); -- Improved Hamstring
    [ 30069 ] = data(82, 31); -- Blood Frenzy [Rank 1]
    [ 30070 ] = data(82, 31); -- Blood Frenzy [Rank 2]
    [ 12294 ] = data(82, 31); -- Mortal Strike [Rank 1]
    [ 21551 ] = data(82, 31); -- Mortal Strike [Rank 2]
    [ 21552 ] = data(82, 31); -- Mortal Strike [Rank 3]
    [ 21553 ] = data(82, 31); -- Mortal Strike [Rank 4]
    [ 25248 ] = data(82, 31); -- Mortal Strike [Rank 5]
    [ 30330 ] = data(82, 31); -- Mortal Strike [Rank 6]
    [ 29841 ] = data(82, 31); -- Second Wind [Rank 1]
    [ 29838 ] = data(82, 31); -- Second Wind [Rank 2]

    -- Fury
    [ 12328 ] = data(83, 21); -- Sweeping Strikes
    [ 12966 ] = data(83, 26); -- Flurry [Rank 1]
    [ 12967 ] = data(83, 26); -- Flurry [Rank 2]
    [ 12968 ] = data(83, 26); -- Flurry [Rank 3]
    [ 12969 ] = data(83, 26); -- Flurry [Rank 4]
    [ 12970 ] = data(83, 26); -- Flurry [Rank 5]
    [ 23881 ] = data(83, 31); -- Bloodthirst [Rank 1]
    [ 23892 ] = data(83, 31); -- Bloodthirst [Rank 2]
    [ 23893 ] = data(83, 31); -- Bloodthirst [Rank 3]
    [ 23894 ] = data(83, 31); -- Bloodthirst [Rank 4]
    [ 25251 ] = data(83, 31); -- Bloodthirst [Rank 5]
    [ 30335 ] = data(83, 31); -- Bloodthirst [Rank 6]
    [ 29801 ] = data(83, 41); -- Rampage [Rank 1]
    [ 30030 ] = data(83, 41); -- Rampage [Rank 2]
    [ 30033 ] = data(83, 41); -- Rampage [Rank 3]
    [ 30029 ] = data(83, 41); -- Rampage Buff [Rank 1]
    [ 30031 ] = data(83, 41); -- Rampage Buff [Rank 2]
    [ 30032 ] = data(83, 41); -- Rampage Buff [Rank 3]


    --------------------------------------------------------
    -- PRIEST

    -- Discipline
    [ 14752 ] = data(91, 21); -- Divine Spirit [Rank 1]
    [ 14818 ] = data(91, 21); -- Divine Spirit [Rank 2]
    [ 14819 ] = data(91, 21); -- Divine Spirit [Rank 3]
    [ 27841 ] = data(91, 21); -- Divine Spirit [Rank 4]
    [ 25312 ] = data(91, 21); -- Divine Spirit [Rank 5]
    [ 27681 ] = data(91, 21); -- Prayer of Spirit [Rank 1]
    [ 32999 ] = data(91, 21); -- Prayer of Spirit [Rank 2]
    [ 45237 ] = data(91, 31); -- Focused Will [Rank 1]
    [ 45241 ] = data(91, 31); -- Focused Will [Rank 2]
    [ 45242 ] = data(91, 31); -- Focused Will [Rank 3]
    [ 10060 ] = data(91, 31); -- Power Infusion
    [ 33619 ] = data(91, 31); -- Reflective Shield      @TODO: Find a way to detect this
    [ 33206 ] = data(91, 41); -- Pain Supression

    -- Holy
    [ 27827 ] = data(92, 21); -- Spirit of Redemption
    [ 33151 ] = data(92, 26); -- Surge of Light
    [ 34754 ] = data(92, 31); -- Clearcasting
    [ 724 ] = data(92, 31); -- Lightwell [Rank 1]
    [ 27870 ] = data(92, 31); -- Lightwell [Rank 2]
    [ 27871 ] = data(92, 31); -- Lightwell [Rank 3]
    [ 28275 ] = data(92, 31); -- Lightwell [Rank 4]
    [ 33143 ] = data(92, 31); -- Blessed Resilience (Aura)
    [ 34861 ] = data(92, 41); -- Circle of Healing [Rank 1]
    [ 34863 ] = data(92, 41); -- Circle of Healing [Rank 2]
    [ 34864 ] = data(92, 41); -- Circle of Healing [Rank 3]
    [ 34865 ] = data(92, 41); -- Circle of Healing [Rank 4]
    [ 34866 ] = data(92, 41); -- Circle of Healing [Rank 5]

    -- Shadow
    [ 15487 ] = data(93, 21); -- Silence
    [ 15286 ] = data(93, 21); -- Vampiric Embrace
    [ 15473 ] = data(93, 31); -- Shadowform
    [ 33196 ] = data(93, 36); -- Misery [Rank 1]
    [ 33197 ] = data(93, 36); -- Misery [Rank 2]
    [ 33198 ] = data(93, 36); -- Misery [Rank 3]
    [ 33199 ] = data(93, 36); -- Misery [Rank 4]
    [ 33200 ] = data(93, 36); -- Misery [Rank 5]
    [ 34914 ] = data(93, 41); -- Vampiric Touch [Rank 1]
    [ 34916 ] = data(93, 41); -- Vampiric Touch [Rank 2]
    [ 34917 ] = data(93, 41); -- Vampiric Touch [Rank 3]
};

function SpecSpells:GetSpec(spellID, spellName)
    local data = specSpells[spellID];
    if(not data) then
        return nil, nil;
    end

    Debug:LogGreen("SpecSpells:", data.id, data.points, "for spell:", spellName);
    return data.id, data.points;
end