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

-- TODO: Fix, complete and verify localized race mappings.
local raceMapping = {
    Human = {
        ["enUS"] = {"Human"},
        ["frFR"] = {"Humain", "Humaine"},
        ["deDE"] = {"Mensch"},
        ["esES"] = {"Humano"},
        ["esMX"] = {"Humano"},
        ["itIT"] = {"Umano"},
        ["ptBR"] = {"Humano", "Humana"},
        ["ruRU"] = {"Человек"},
        ["koKR"] = {"인간"},
        ["zhCN"] = {"人类"},
        ["zhTW"] = {"人類"},
    },
    Orc = {
        ["enUS"] = {"Orc"},
        ["frFR"] = {"Orc", "Orque"},
        ["deDE"] = {"Ork"},
        ["esES"] = {"Orco"},
        ["esMX"] = {"Orco"},
        ["itIT"] = {"Orco"},
        ["ptBR"] = {"Orc"},
        ["ruRU"] = {"Орк"},
        ["koKR"] = {"오크"},
        ["zhCN"] = {"兽人"},
        ["zhTW"] = {"獸人"},
    },
    Dwarf = {
        ["enUS"] = {"Dwarf"},
        ["frFR"] = {"Nain", "Naine"},
        ["deDE"] = {"Zwerg", "Zwergin"},
        ["esES"] = {"Enano", "Enana"},
        ["esMX"] = {"Enano", "Enana"},
        ["itIT"] = {"Nano", "Nana"},
        ["ptBR"] = {"Anão", "Anã"},
        ["ruRU"] = {"Дворф"},
        ["koKR"] = {"드워프"},
        ["zhCN"] = {"矮人"},
        ["zhTW"] = {"矮人"},
    },
    NightElf = {
        ["enUS"] = {"Night Elf"},
        ["frFR"] = {"Elfe de la nuit", "Elfe de la nuit femelle"},
        ["deDE"] = {"Nachtelf", "Nachtelfe"},
        ["esES"] = {"Elfo de la noche", "Elfa de la noche"},
        ["esMX"] = {"Elfo de la noche", "Elfa de la noche"},
        ["itIT"] = {"Elfo della Notte", "Elfa della Notte"},
        ["ptBR"] = {"Elfo Noturno", "Elfa Noturna"},
        ["ruRU"] = {"Ночной эльф", "Ночная эльфийка"},
        ["koKR"] = {"나이트 엘프"},
        ["zhCN"] = {"暗夜精灵"},
        ["zhTW"] = {"夜精靈"},
    },
    Draenei = {
        ["enUS"] = {"Draenei"},
        ["frFR"] = {"Draeneï", "Draeneï femelle"},
        ["deDE"] = {"Draenei", "Draeneifrau"},
        ["esES"] = {"Draenei"},
        ["esMX"] = {"Draenei"},
        ["itIT"] = {"Draenei"},
        ["ptBR"] = {"Draenei"},
        ["ruRU"] = {"Дреней"},
        ["koKR"] = {"드레나이"},
        ["zhCN"] = {"德莱尼"},
        ["zhTW"] = {"德萊尼"},
    },
    -- Allied Races & Other
    VoidElf = {
        ["enUS"] = {"Void Elf"},
        ["frFR"] = {"Elfe du Vide", "Elfe du Vide femelle"},
        ["deDE"] = {"Leerenelf", "Leerenelfe"},
        ["esES"] = {"Elfo del Vacío", "Elfa del Vacío"},
        ["esMX"] = {"Elfo del Vacío", "Elfa del Vacío"},
        ["itIT"] = {"Elfo del Vuoto", "Elfa del Vuoto"},
        ["ptBR"] = {"Elfo Caótico", "Elfa Caótica"},
        ["ruRU"] = {"Эльф Бездны", "Эльфийка Бездны"},
        ["koKR"] = {"공허의 엘프"},
        ["zhCN"] = {"虚空精灵"},
        ["zhTW"] = {"虛空精靈"},
    },
    LightforgedDraenei = {
        ["enUS"] = {"Lightforged Draenei"},
        ["frFR"] = {"Draeneï sancteforge", "Draeneï sancteforge femelle"},
        ["deDE"] = {"Lichtgeschmiedeter Draenei", "Lichtgeschmiedete Draenei"},
        ["esES"] = {"Draenei forjado por la Luz"},
        ["esMX"] = {"Draenei forjado por la Luz"},
        ["itIT"] = {"Draenei Forgialuce"},
        ["ptBR"] = {"Draenei Forjado a Luz"},
        ["ruRU"] = {"Озаренный дреней"},
        ["koKR"] = {"빛벼림 드레나이"},
        ["zhCN"] = {"光铸德莱尼"},
        ["zhTW"] = {"光鑄德萊尼"},
    },
    Earthen = {
        ["enUS"] = {"Earthen"},
        ["frFR"] = {"Terrestre"},
        ["deDE"] = {"Erdbewohner"},
        ["esES"] = {"Terráneo"},
        ["esMX"] = {"Terráneo"},
        ["itIT"] = {"Terrigeno"},
        ["ptBR"] = {"Terrano"},
        ["ruRU"] = {"Земляной"},
        ["koKR"] = {"대지의 주민"},
        ["zhCN"] = {"土灵"},
        ["zhTW"] = {"土靈"},
    },
}

-- TODO: Verify logic
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
                if(Helpers:ToSafeLower(localizedValue) == race) then
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
        if(raceInfo and race == raceInfo.raceName) then
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