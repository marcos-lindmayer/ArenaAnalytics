local _, ArenaAnalytics = ...; -- Addon Namespace
local Constants = ArenaAnalytics.Constants;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;
local Internal = ArenaAnalytics.Internal;

-------------------------------------------------------------------------

-- Text colors
Constants.titleColor = "ffffffff";
Constants.headerColor = "ffd0d0d0";
Constants.prefixColor = "FFAAAAAA";
Constants.statsColor = "ffffffff";
Constants.valueColor = nil; -- f5f5f5 for white?
Constants.infoColor = "ffbbbbbb";

-- Outcome colors
Constants.winColor = "ff00cc66";
Constants.lossColor = "ffff0000";
Constants.drawColor = "ffefef00";
Constants.invalidColor = "ff999999";

-- Faction colors
Constants.allianceColor = "FF009DEC";
Constants.hordeColor = "ffE00A05";

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
};

Constants.playerFlags = {
    isFirstDeath = 1,
    isEnemy = 2,
    isSelf = 3,
    isFemale = 4,
};

-------------------------------------------------------------------------

local matchStartedMessages = {
    ["The Arena battle has begun!"] = true,          -- English / Default
    ["¡La batalla en arena ha comenzado!"] = true,   -- esES / esMX
    ["A batalha na Arena começou!"] = true,          -- ptBR
    ["Der Arenakampf hat begonnen!"] = true,         -- deDE
    ["Le combat d'arène commence\194\160!"] = true,  -- frFR
    ["Бой начался!"] = true,                         -- ruRU
    ["투기장 전투가 시작되었습니다!"] = true,           -- koKR
    ["竞技场战斗开始了！"] = true,                     -- zhCN
    ["竞技场的战斗开始了！"] = true,                   -- zhCN (Wotlk)
    ["競技場戰鬥開始了！"] = true,                     -- zhTW (Unconfirmed, classic?)
};

function Constants:IsMatchStartedMessage(msg)
    return msg and matchStartedMessages[msg] or false;
end

-------------------------------------------------------------------------

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
};

-- Returns spec icon path string
function Constants:GetBaseSpecIcon(spec_id)
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
    return bracketIndex and bracketTeamSizes[bracketIndex] or nil;
end

function ArenaAnalytics:getTeamSizeFromBracket(bracket)
    if(not bracket) then
        if(bracket == "2v2") then
            return 2;
        elseif(bracket == "3v3") then
            return 3;
        elseif(bracket == "5v5") then
            return 5;
        end
    end

    return nil;
end