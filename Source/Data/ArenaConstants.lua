local _, ArenaAnalytics = ...; -- Addon Namespace
local Constants = ArenaAnalytics.Constants;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;
local Debug = ArenaAnalytics.Debug;

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

local arenaMessages = {
    -- English / Default
    ["One minute until the Arena battle begins!"] = 60,
    ["Thirty seconds until the Arena battle begins!"] = 30,
    ["Fifteen seconds until the Arena battle begins!"] = 15,
    ["The Arena battle has begun!"] = 0,

    -- German (deDE)
    ["Noch eine Minute bis der Arenakampf beginnt!"] = 60,
    ["Noch dreißig Sekunden bis der Arenakampf beginnt!"] = 30,
    ["Noch fünfzehn Sekunden bis der Arenakampf beginnt!"] = 15,
    ["Der Arenakampf hat begonnen!"] = 0,

    -- Spanish (esES / esMX)
    ["¡Un minuto hasta que dé comienzo la batalla en arena!"] = 60,
    ["¡Treinta segundos hasta que comience la batalla en arena!"] = 30,
    ["¡Quince segundos hasta que comience la batalla en arena!"] = 15,
    ["¡La batalla en arena ha comenzado!"] = 0,

    -- French (frFR)
    ["Le combat d'arène commence dans une minute\194\160!"] = 60,
    ["Le combat d'arène commence dans trente secondes\194\160!"] = 30,
    ["Le combat d'arène commence dans quinze secondes\194\160!"] = 15,
    ["Le combat d'arène commence\194\160!"] = 0,

    -- Italian (itIT)
    ["La battaglia nell'arena inizierà tra 60 secondi."] = 60,
    ["La battaglia nell'arena inizierà tra 30 secondi."] = 30,
    ["La battaglia nell'arena inizierà tra 15 secondi."] = 15,
    ["La battaglia nell'arena è iniziata!"] = 0,

    -- Korean (koKR)
    ["투기장 전투 시작 1분 전입니다!"] = 60,
    ["투기장 전투 시작 30초 전입니다!"] = 30,
    ["투기장 전투 시작 15초 전입니다!"] = 15,
    ["투기장 전투가 시작되었습니다!"] = 0,

    -- Portuguese (ptBR / ptPT)
    ["Um minuto até a batalha na Arena começar!"] = 60,
    ["Trinta segundos até a batalha na Arena começar!"] = 30,
    ["Quinze segundos até a batalha na Arena começar!"] = 15,
    ["A batalha na Arena começou!"] = 0,

    -- Russian (ruRU)
    ["Одна минута до начала боя на арене!"] = 60,
    ["Тридцать секунд до начала боя на арене!"] = 30,
    ["Пятнадцать секунд до начала боя на арене!"] = 15, -- TWW Shuffles
    ["До начала боя на арене осталось 15 секунд."] = 15,
    ["Битва на арене началась!"] = 0, -- TWW Shuffles
    ["Бой начался!"] = 0,

    -- Chinese Simplified (zhCN)
    ["竞技场战斗将在一分钟后开始！"] = 60,
    ["竞技场战斗将在三十秒后开始！"] = 30,
    ["竞技场战斗将在十五秒后开始！"] = 15,
    ["竞技场战斗开始了！"] = 0,
    ["竞技场的战斗开始了！"] = 0, -- Wrath Classic

    -- Chinese Traditional (zhTW)
    ["1分鐘後競技場戰鬥開始!"] = 60,
    ["30秒後競技場戰鬥開始!"] = 30,
    ["15秒後競技場戰鬥開始!"] = 15,
    ["競技場戰鬥開始了!"] = 0,
};

-- Check if a message indicates the match has started (0 seconds)
function Constants:CheckTimerMessage(msg)
    local timeTillStart = msg and tonumber(arenaMessages[msg]);
    local isStart = (timeTillStart == 0);

    Debug:Log("ParseArenaTimerMessages message passed:", msg, timeTillStart, isStart);
    return isStart, timeTillStart;
end

--[[
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
        [61] = "La battaglia nell'arena inizierà tra 60 secondi.",
        [31] = "La battaglia nell'arena inizierà tra 30 secondi.",
        [16] = "La battaglia nell'arena inizierà tra 15 secondi.",
        [0] = "La battaglia nell'arena è iniziata!",
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
--]]

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

    return specIconTable[spec_id] or 134400; -- Red question mark ID (Inv_misc_questionmark)
end

function ArenaAnalytics:getBracketFromTeamSize_DEPRECATED(teamSize)
    if(teamSize == 2) then
        return "2v2";
    elseif(teamSize == 3) then
        return "3v3";
    end
    return "5v5";
end

function ArenaAnalytics:getBracketIdFromTeamSize_DEPRECATED(teamSize)
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