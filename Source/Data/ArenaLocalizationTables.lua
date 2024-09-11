local _, ArenaAnalytics = ...; -- Addon Namespace
local Localization = ArenaAnalytics.Localization;

-- Local module aliases
local Internal = ArenaAnalytics.Internal;
local Helpers = ArenaAnalytics.Helpers;

-------------------------------------------------------------------------

function Localization:GetClassID(class)
    if(not class) then
        return nil;
    end

    class = Helpers:ToSafeLower(class);

    for classToken,localizedClass in pairs(LOCALIZED_CLASS_NAMES_MALE) do
        if(class == Helpers:ToSafeLower(classToken) or class == Helpers:ToSafeLower(localizedClass)) then
            return Internal:GetAddonClassID(classToken);
        end
    end

    for classToken,localizedClass in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do 
        if(class == Helpers:ToSafeLower(classToken) or class == Helpers:ToSafeLower(localizedClass)) then
            return Internal:GetAddonClassID(classToken);
        end
    end

    ArenaAnalytics:Log("LocalizationTables: Failed to get class ID for class:", class);
    return nil;
end

-------------------------------------------------------------------------

-- NOTE: Korean and Chinese are ChatGPT-4o values. Untested and unreliable.
raceMapping = {
    Human = {
        enGB = { "Human" },
        deDE = { "Mensch" },
        esES = { "Humano", "Humana" },
        frFR = { "Humain", "Humaine" },
        itIT = { "Umano", "Umana" },
        ptBR = { "Humano", "Humana" },
        ruRU = { "Человек" },
        koKR = { "인간" },
        zhTW = { "人类" },
    },
    Dwarf = {
        enGB = { "Dwarf" },
        deDE = { "Zwerg", "Zwergin" },
        esES = { "Enano", "Enana" },
        frFR = { "Nain", "Naine" },
        itIT = { "Nano", "Nana" },
        ptBR = { "Anão", "Anã" },
        ruRU = { "Дворф", "Дворфийка" },
        koKR = { "드워프" },
        zhTW = { "矮人" },
    },
    NightElf = {
        enGB = { "Night Elf" },
        deDE = { "Nachtelf", "Nachtelfe" },
        esES = { "Elfo de la noche", "Elfa de la noche" },
        frFR = { "Elfe de la nuit" },
        itIT = { "Elfo della notte", "Elfa della notte" },
        ptBR = { "Elfo Noturno", "Elfa Noturna" },
        ruRU = { "Ночной эльф", "Ночная эльфийка" },
        koKR = { "나이트 엘프" },
        zhTW = { "暗夜精灵" },
    },
    Gnome = {
        enGB = { "Gnome" },
        deDE = { "Gnom" },
        esES = { "Gnomo", "Gnoma" },
        frFR = { "Gnome" },
        itIT = { "Gnomo", "Gnoma" },
        ptBR = { "Gnomo", "Gnomida" },
        ruRU = { "Гном", "Гномка"},
        koKR = { "노움" },
        zhTW = { "侏儒" },
    },
    Draenei = {
        enGB = { "Draenei" },
        deDE = { "Draenei" },
        esES = { "Draenei", "Draenea" },
        frFR = { "Draeneï" },
        itIT = { "Draenei" },
        ptBR = { "Draenei", "Draenaia" },
        ruRU = { "Дреней", "Дренейка" },
        koKR = { "드레나이" },
        zhTW = { "德莱尼人" },
    },
    Worgen = {
        enGB = { "Worgen" },
        deDE = { "Worgen" },
        esES = { "Huargen" },
        frFR = { "Worgen" },
        itIT = { "Worgen" },
        ptBR = { "Worgen", "Worgenin" },
        ruRU = { "Ворген" },
        koKR = { "늑대인간" },
        zhTW = { "狼人" },
    },
    Pandaren = {
        enGB = { "Pandaren" },
        deDE = { "Pandaren" },
        esES = { "Pandaren" },
        frFR = { "Pandaren", "Pandaène" },
        itIT = { "Pandaren" },
        ptBR = { "Pandaren", "Pandarena" },
        ruRU = { "Пандарен", "Пандаренка" },
        koKR = { "판다렌" },
        zhTW = { "熊猫人" },
    },
    Dracthyr = {
        enGB = { "Dracthyr" },
        deDE = { "Dracthyr" },
        esES = { "Dracthyr" },
        frFR = { "Dracthyr" },
        itIT = { "Dracthyr" },
        ptBR = { "Dracthyr" },
        ruRU = { "Драктир" },
        koKR = {  },
        zhTW = {  },
    },
    VoidElf = {
        enGB = { "Void Elf" },
        deDE = { "Leerenelf", "Leerenelfe" },
        esES = { "Elfo del Vacío", "Elfa del Vacío" },
        frFR = { "Elfe du Vide" },
        itIT = { "Elfo del Vuoto", "Elfa del Vuoto" },
        ptBR = { "Elfo Caótico", "Elfa Caótica" },
        ruRU = { "Эльф Бездны", "Эльфийка Бездны" },
        koKR = { "공허 엘프" },
        zhTW = { "虚空精灵" },
    },
    LightforgedDraenei = {
        enGB = { "Lightforged Draenei" },
        deDE = { "Lichtgeschmiedeter Draenei", "Lichtgeschmiedete Draenei" },
        esES = { "Draenei templeluz", "Dreanei forjado por la Luz", "Dreanei forjada por la Luz" },
        frFR = { "Draeneï sancteforge" },
        itIT = { "Draenei Forgialuce" },
        ptBR = { "Draenei Forjado a Luz", "Draenaia Forjada a Luz" },
        ruRU = { "Озаренный дреней", "Озаренная дренейка" },
        koKR = { "빛벼림 드레나이" },
        zhTW = { "光铸德莱尼" },
    },
    DarkIronDwarf = {
        enGB = { "Dark Iron Dwarf" },
        deDE = { "Dunkeleisenzwerg", "Dunkeleisenzwergin" },
        esES = { "Enano Hierro Negro", "Enana Hierro Negro" },
        frFR = { "Nain sombrefer", "Naine sombrefer" },
        itIT = { "Nano Ferroscuro", "Nana Ferroscuro" },
        ptBR = { "Anão Ferro Negro", "Anã Ferro Negro" },
        ruRU = { "Дворф из клана Черного Железа", "Дворфийка из клана Черного Железа" },
        koKR = { "검은무쇠 드워프" },
        zhTW = { "黑铁矮人" },
    },
    Earthen = {
        enGB = { "Earthen" },
        deDE = { "Irdener", "Irdene" },
        esES = { "Terráneo", "Terránea" },
        frFR = { "Terrestre" },
        itIT = { "Terrigeno", "Terrigena" },
        ptBR = { "Terrano" },
        ruRU = { "Земельник" },
        koKR = {  },
        zhTW = {  },
    },
    KulTiran = {
        enGB = { "Kul Tiran" },
        deDE = { "Kul Tiraner", "Kul Tiranerin", "Ciudadano de Kul Tiras", "Ciudadana de Kul Tiras" },
        esES = { "Kultirano", "Kultirana" },
        frFR = { "Kultirassien", "Kultirassienne" },
        itIT = { "Kul Tirano", "Kul Tirana" },
        ptBR = { "Kultireno", "Kultirena" },
        ruRU = { "Култирасец", "Култираска" },
        koKR = { "쿨 티란" },
        zhTW = { "库尔提拉斯人" },
    },
    Mechagnome = {
        enGB = { "Mechagnome" },
        deDE = { "Mechagnom" },
        esES = { "Mecagnomo", "Mecagnoma" },
        frFR = { "Mécagnome" },
        itIT = { "Meccagnomo", "Meccagnoma" },
        ptBR = { "Gnomecânico", "Gnomecânica" },
        ruRU = { "Механогном", "Механогномка" },
        koKR = { "기계노움" },
        zhTW = { "机械侏儒" },
    },
    Orc = {
        enGB = { "Orc" },
        deDE = { "Orc" },
        esES = { "Orco" },
        frFR = { "Orc", "Orque" },
        itIT = { "Orco", "Orchessa" },
        ptBR = { "Orc", "Orquisa" },
        ruRU = { "Орк", "Орчиха" },
        koKR = { "오크" },
        zhTW = { "兽人" },
    },
    Undead = {
        enGB = { "Undead" },
        deDE = { "Untoter", "Untote" },
        esES = { "No-muerto", "No-muerta" },
        frFR = { "Mort-vivant", "Morte-vivante" },
        itIT = { "Non Morto", "Non Morta" },
        ptBR = { "Morto-vivo", "Morta-viva" },
        ruRU = { "Нежить" },
        koKR = { "언데드" },
        zhTW = { "被遗忘者" },
    },
    Tauren = {
        enGB = { "Tauren" },
        deDE = { "Tauren" },
        esES = { "Tauren" },
        frFR = { "Tauren", "Taurène" },
        itIT = { "Tauren" },
        ptBR = { "Tauren", "Taurena" },
        ruRU = { "Таурен", "Тауренка" },
        koKR = { "타우렌" },
        zhTW = { "牛头人" },
    },
    Troll = {
        enGB = { "Troll" },
        deDE = { "Troll" },
        esES = { "Trol" },
        frFR = { "Troll", "Trollesse" },
        itIT = { "Troll" },
        ptBR = { "Troll", "Trolesa" },
        ruRU = { "Тролль" },
        koKR = { "트롤" },
        zhTW = { "巨魔" },
    },
    BloodElf = {
        enGB = { "Blood Elf" },
        deDE = { "Blutelf", "Blutelfe" },
        esES = { "Elfo de sangre", "Elfa de sangre" },
        frFR = { "Elfe de sang" },
        itIT = { "Elfo del Sangue", "Elfa del Sangue" },
        ptBR = { "Elfo Sangrento", "Elfa Sangrenta" },
        ruRU = { "Эльф крови", "Эльфийка крови" },
        koKR = { "블러드 엘프" },
        zhTW = { "血精灵" },
    },
    Goblin = {
        enGB = { "Goblin" },
        deDE = { "Goblin" },
        esES = { "Goblin" },
        frFR = { "Gobelin", "Gobeline" },
        itIT = { "Goblin" },
        ptBR = { "Goblin", "Goblina" },
        ruRU = { "Гоблин" },
        koKR = { "고블린" },
        zhTW = { "地精" },
    },
    Nightborne = {
        enGB = { "Nightborne" },
        deDE = { "Nachtgeborener", "Nachtgeborene" },
        esES = { "Natonocturno", "Natonocturna", "Nocheterno", "Nocheterna" },
        frFR = { "Sacrenuit" },
        itIT = { "Nobile Oscuro", "Nobile Oscura" },
        ptBR = { "Filho da Noite", "Filha da Noite" },
        ruRU = { "Ночнорожденный", "Ночнорожденная" },
        koKR = { "나이트본" },
        zhTW = { "夜之子" },
    },
    HighmountainTauren = {
        enGB = { "Highmountain Tauren" },
        deDE = { "Hochbergtauren" },
        esES = { "Tauren de Altamontaña", "Tauren Monte Alto" },
        frFR = { "Tauren de Haut-Roc", "Taurène de Haut-Roc" },
        itIT = { "Tauren di Alto Monte" },
        ptBR = { "Tauren Altamontês", "Taurena Altamontêsa" },
        ruRU = { "Таурен Крутогорья", "Тауренка Крутогорья" },
        koKR = { "높은산 타우렌" },
        zhTW = { "至高岭牛头人" },
    },
    MagharOrc = {
        enGB = { "Mag'har Orc" },
        deDE = { "Mag'har" },
        esES = { "Orco Mag'har" },
        frFR = { "Orc mag'har", "Orque mag'har" },
        itIT = { "Orco Mag'har", "Orchessa Mag'har" },
        ptBR = { "Orc Mag'har" },
        ruRU = { "Маґ'хар", "Маґ'харка" },
        koKR = { "마그하르 오크" },
        zhTW = { "玛格汉兽人" },
    },
    ZandalariTroll = {
        enGB = { "Zandalari Troll" },
        deDE = { "Zandalaritroll" },
        esES = { "Trol Zandalari" },
        frFR = { "Troll zandalari", "Trolle zandalari" },
        itIT = { "Troll Zandalari" },
        ptBR = { "Troll Zandalari", "Trolesa Zandalari" },
        ruRU = { "Зандалар", "Зандаларка" },
        koKR = { "잔달라 트롤" },
        zhTW = { "赞达拉巨魔" },
    },
    Vulpera = {
        enGB = { "Vulpera" },
        esES = { "Vulpera" },
        deDE = { "Vulpera" },
        frFR = { "Vulpérin", "Vulpérine" },
        itIT = { "Vulpera" },
        ptBR = { "Vulpera" },
        ruRU = { "Вульпера" },
        koKR = { "불페라" },
        zhTW = { "狐人" },
    },
}

function Localization:GetRaceID(race)
    if(not race) then
        return nil;
    end

    race = Helpers:ToSafeLower(race);

    -- Look for explicit conversion values
    for raceToken,localizations in pairs(raceMapping) do
        assert(raceToken and localizations);

        for _,values in pairs(localizations) do
            assert(values);

            for _,localizedValue in ipairs(values) do
                if(race == Helpers:ToSafeLower(localizedValue)) then
                    -- Convert token to Race ID
                    return Internal:GetAddonRaceIDByToken(raceToken);
                end
            end
        end
    end

    ArenaAnalytics:Log("LocalizationTables: Failed to find race table value:", race);

    -- Fall back to try looking through 
    for raceID = 1, API.maxRaceID do
        local raceInfo = C_CreatureInfo.GetRaceInfo(raceID)        
        if(raceInfo and race == Helpers:ToSafeLower(raceInfo.raceName)) then
            local addonRaceID = Internal:GetAddonRaceIDByToken(raceInfo.clientFileString);
            if addonRaceID then
                return addonRaceID;
            else
                ArenaAnalytics:Log("Error: No Addon Race ID found for:", raceID, raceInfo.raceName, raceInfo.clientFileString);
                return 1000 + raceID;
            end
        end
    end

    ArenaAnalytics:Log("LocalizationTables: Failed to find raceID:", race);
    return nil;
end