local _, ArenaAnalytics = ...; -- Addon Namespace
local Localization = ArenaAnalytics.Localization;

-- Local module aliases
local Internal = ArenaAnalytics.Internal;
local Helpers = ArenaAnalytics.Helpers;
local API = ArenaAnalytics.API;

-------------------------------------------------------------------------

local classLookupTable = nil;
function Localization:GetClassID(class)
    if(not classLookupTable) then
        ArenaAnalytics:LogError("classLookupTable failed to initialize for Localization conversions.");
        return nil;
    end

    if(not class or class == "") then
        return nil;
    end

    class = Helpers:ToSafeLower(class);
    local class_id = class and classLookupTable[class];

    if(class_id) then
        ArenaAnalytics:LogGreen("Localization:GetSpecID found ID:", class_id, "for", class);
    else
        ArenaAnalytics:LogWarning("Localization:GetSpecID failed to find ID for:", class);
    end

    return class_id;
end

-- TODO: Implement
local function InitializeLookupTable_Class()
    classLookupTable = {};

    local function PopulateTable(classToken, className)
        local classID = Internal:GetAddonClassID(classToken);

        if(classID) then
            classToken = Helpers:ToSafeLower(classToken);
            className = Helpers:ToSafeLower(className);

            if(classToken and not classLookupTable[classToken]) then
                classLookupTable[classToken] = classID;
            end

            if(className and not classLookupTable[className]) then
                classLookupTable[className] = classID;
            end
        end
    end

    if(LOCALIZED_CLASS_NAMES_MALE) then
        for classToken,localizedClass in pairs(LOCALIZED_CLASS_NAMES_MALE) do
            PopulateTable(classToken, localizedClass);
        end
    end

    if(LOCALIZED_CLASS_NAMES_FEMALE) then
        for classToken,localizedClass in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
            PopulateTable(classToken, localizedClass);
        end
    end
end

-------------------------------------------------------------------------

local specLookupTable = nil;
function Localization:GetSpecID(classToken, spec)
    if(not specLookupTable) then
        ArenaAnalytics:LogError("specLookupTable failed to initialize for Localization conversions.");
        return nil;
    end

    if(not classToken or not spec or spec == "") then
        return nil;
    end

    classToken = Helpers:ToSafeLower(classToken);
    spec = Helpers:ToSafeLower(spec);

    local classTable = specLookupTable[classToken];
    local spec_id = classTable and tonumber(classTable[spec]);

    -- Logging
    if(spec_id) then
        ArenaAnalytics:LogGreen("Localization:GetSpecID found ID:", spec_id, "for", classToken, spec);
    else
        ArenaAnalytics:LogWarning("Localization:GetSpecID failed to find ID for:", classToken, spec);
    end

    return spec_id;
end

local function InitializeLookupTable_Spec()
    specLookupTable = {};

    if(GetSpecializationInfoForClassID and GetSpecializationInfoForSpecID and not API.disableSpecInfoAPI) then
        -- Populate English first, independent of game client and localization
        for classIndex=1, API:GetNumClasses() do
            Internal:PopulateEnglishSpecs(specLookupTable, classIndex);
        end

        -- Second loop to deal with different class index orders
        for classIndex=1, API:GetNumClasses() do
            local _,classToken = GetClassInfo(classIndex);
            if(classToken) then
                classToken = Helpers:ToSafeLower(classToken);
                specLookupTable[classToken] = specLookupTable[classToken] or {};

                local classTable = specLookupTable[classToken];

                for specIndex=0, 4 do
                    local specID = GetSpecializationInfoForClassID(classIndex, specIndex);
                    if(specID) then
                        for genderIndex = 1, 3 do
                            local id, specName = GetSpecializationInfoForSpecID(specID, genderIndex);
                            specName = Helpers:SanitizeValue(specName);

                            if(id and specName and tonumber(classTable[specName]) == nil) then -- Prioritize known English IDs
                                ArenaAnalytics:LogTemp("InitializeLookupTable_Spec", classToken, specName, id, classTable[specName]);
                                classTable[specName] = API:GetMappedAddonSpecID(id);
                            end
                        end
                    end
                end
            end
        end
    end
end

function Localization:TempLogSpecMapping()
    ArenaAnalytics.Debug:LogTable(specLookupTable);
end

-------------------------------------------------------------------------

local raceMapping = {
    Human = {
        enGB = { "Human" },
        deDE = { "Mensch" },
        esES = { "Humano", "Humana" },
        frFR = { "Humain", "Humaine" },
        itIT = { "Umano", "Umana" },
        ptBR = { "Humano", "Humana" },
        ruRU = { "Человек" },
        koKR = { "인간" },
        zhTW = {  },
        zhCN = { "人类" },
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
        zhTW = {  },
        zhCN = { "矮人" },
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
        zhTW = {  },
        zhCN = { "暗夜精灵" },
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
        zhTW = {  },
        zhCN = { "侏儒" },
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
        zhTW = {  },
        zhCN = { "德莱尼" },
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
        zhTW = {  },
        zhCN = { "狼人" },
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
        zhTW = {  },
        zhCN = { "熊猫人" },
    },
    Dracthyr = {
        enGB = { "Dracthyr" },
        deDE = { "Dracthyr" },
        esES = { "Dracthyr" },
        frFR = { "Dracthyr" },
        itIT = { "Dracthyr" },
        ptBR = { "Dracthyr" },
        ruRU = { "Драктир" },
        koKR = { "드랙티르" },
        zhTW = {  },
        zhCN = { "龙希尔" },
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
        zhTW = {  },
        zhCN = { "虚空精灵" },
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
        zhTW = {  },
        zhCN = { "光铸德莱尼" },
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
        zhTW = {  },
        zhCN = { "黑铁矮人" },
    },
    Earthen = {
        enGB = { "Earthen" },
        deDE = { "Irdener", "Irdene" },
        esES = { "Terráneo", "Terránea" },
        frFR = { "Terrestre" },
        itIT = { "Terrigeno", "Terrigena" },
        ptBR = { "Terrano" },
        ruRU = { "Земельник" },
        koKR = { "토석인" },
        zhTW = {  },
        zhCN = { "土灵" },
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
        zhTW = {  },
        zhCN = { "库尔提拉斯人" },
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
        zhTW = {  },
        zhCN = { "机械侏儒" },
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
        zhTW = {  },
        zhCN = { "兽人" },
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
        zhTW = {  },
        zhCN = { "亡灵" },
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
        zhTW = {  },
        zhCN = { "牛头人" },
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
        zhTW = {  },
        zhCN = { "巨魔" },
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
        zhTW = {  },
        zhCN = { "血精灵" },
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
        zhTW = {  },
        zhCN = { "地精" },
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
        zhTW = {  },
        zhCN = { "夜之子" },
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
        zhTW = {  },
        zhCN = { "至高岭牛头人" },
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
        zhTW = {  },
        zhCN = { "玛格汉兽人" },
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
        zhTW = {  },
        zhCN = { "赞达拉巨魔" },
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
        zhTW = {  },
        zhCN = { "狐人" },
    },
};

local raceLookupTable = nil;
function Localization:GetRaceID(race, factionIndex)
    if(not raceLookupTable) then
        ArenaAnalytics:LogError("raceLookupTable failed to initialize for Localization conversions.");
        return nil;
    end

    if(not race) then
        return nil;
    end

    race = Helpers:SanitizeValue(race);

    local value = race and raceLookupTable[race];
    if(not value) then
        return nil;
    end

    local race_id = nil;
    if(type(value) == "table") then
        local index = tonumber(factionIndex) and (1 + tonumber(factionIndex) % 2);
        race_id = tonumber(index and value[index] or value[1]);
    else
        race_id = tonumber(value);
    end

    -- Logging
    if(race_id) then
        ArenaAnalytics:LogGreen("Localization:GetRaceID found ID:", race_id, "for", race, factionIndex);
    else
        ArenaAnalytics:LogWarning("Localization:GetRaceID failed to find ID for:", race, factionIndex);
    end

    return race_id;
end

local function InitializeLookupTable_Race()
    raceLookupTable = {};

    local function PopulateRace(raceToken, key)
        if(raceToken and key and key ~= "" and not raceLookupTable[key]) then
            local hordeID = Internal:GetAddonRaceIDByToken(raceToken, 0);
            local allianceID = Internal:GetAddonRaceIDByToken(raceToken, 1);

            -- Insert neutral as table, or explicit faction as number
            if(hordeID and allianceID and hordeID ~= allianceID) then
                raceLookupTable[key] = { hordeID, allianceID }
            elseif(hordeID or allianceID) then
                raceLookupTable[key] = hordeID or allianceID;
            end
        end
    end

    for raceToken,localizations in pairs(raceMapping) do
        assert(raceToken and localizations);

        raceToken = Helpers:SanitizeValue(raceToken);
        PopulateRace(raceToken, raceToken);

        for _,values in pairs(localizations) do
            assert(values);

            for _,localizedValue in ipairs(values) do
                local localizedToken = Helpers:SanitizeValue(localizedValue);
                PopulateRace(raceToken, localizedToken);
            end
        end
    end

    -- Special cases
    PopulateRace("undead", "scourge");
end

function Localization:GetFactionIndex(faction)
    if(not faction) then
        return nil;
    end

    if(type(faction) == "string") then
        -- TODO: Add localized checks?
        faction = Helpers:ToSafeLower(faction);
        if(faction == "horde") then
            faction = 0;
        elseif(faction == "alliance") then
            faction = 1;
        end
    end

    faction = tonumber(faction);
    return faction and faction % 2;
end

function Localization:Initialize()
    InitializeLookupTable_Class();
    InitializeLookupTable_Spec();
    InitializeLookupTable_Race();
end