local _, ArenaAnalytics = ... -- Namespace
local Localization = ArenaAnalytics.Localization;

-- Local module aliases
local Options = ArenaAnalytics.Options;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------

Localization.currentLanguage = "enGB";
Localization.languages = {};
Localization.data = {};

function Localization:Register(language, languageTable)
    assert(language.key and language.englishName and language.localizedName and type(languageTable) == "table", "Invalid language registration  "..tostring(language.key).."  "..tostring(language.englishName).."  "..tostring(language.localizedName).."  "..tostring(languageTable));

    if(Localization.data[language.key]) then
        Debug:LogWarning("Language already registered:", language.key, language.englishName, language.localizedName);
        return;
    end

    tinsert(Localization.languages, language);

    Localization.data[language.key] = languageTable;

    Debug:Log("Registered language:", language.key, language.englishName, language.localizedName);
end

-------------------------------------------------------------------------

function Localization:IsValidToken(token)
    return nil; -- TODO: Implement
end

function Localization:Get(token, isFemale, explicitLanguage)

end

function Localization:GetShort(token, isFemale, explicitLanguage)

end

function Localization:GetPlural(token, isFemale, count, explicitLanguage)

end

-------------------------------------------------------------------------

function Localization:Initialize()
    Localization.currentLanguage = Options:GetSafe("language") or "enGB";
end