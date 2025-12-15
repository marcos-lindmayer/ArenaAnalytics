local _, ArenaAnalytics = ...; -- Addon Namespace
local DataCollector = ArenaAnalytics.DataCollector;

-- Local module aliases
local SpecSpells = ArenaAnalytics.SpecSpells;
local API = ArenaAnalytics.API;
local Helpers = ArenaAnalytics.Helpers;
local Inspection = ArenaAnalytics.Inspection;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------

local excludedStrings = {
    "enchant",
    "flask of",
    "bandage",
    "well fed",
    "elixir",
    "potion"
};

-------------------------------------------------------------------------

function DataCollector:Initiate()
    ArenaAnalyticsDevData = ArenaAnalyticsDevData or {};
    ArenaAnalyticsDevData.classes = ArenaAnalyticsDevData.classes or {};
    ArenaAnalyticsDevData.classlessSpells = ArenaAnalyticsDevData.classlessSpells or {};

    DataCollector:RegisterEvents();

    DataCollector.isInitiated = true;
end

-------------------------------------------------------------------------
--- Local Event Handling

local eventFrame = CreateFrame("Frame");

function DataCollector:RegisterEvents()
    eventFrame:RegisterEvent("UNIT_AURA");
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");

	eventFrame:SetScript("OnEvent", DataCollector.HandleLocalEvents);
	eventFrame.hasRegisteredEvents = true;
end

function DataCollector:HandleLocalEvents(event, ...)
    if(event == "COMBAT_LOG_EVENT_UNFILTERED") then
        DataCollector:ProcessCombatLogEvent(...);
    elseif(event == "UNIT_AURA") then
        DataCollector:ProcessUnitAuraEvent(...);
    end
end

-------------------------------------------------------------------------

local function FindOrAdd_Class(class)
    if(not Helpers:IsValidValue(class)) then
        return;
    end

    if(not ArenaAnalyticsDevData.classes[class]) then
        ArenaAnalyticsDevData.classes[class] = {}
        Debug:Log("DataCollector added new class to spells:", class);
    end

    return ArenaAnalyticsDevData.classes[class];
end

local function ClassDataContains(classData, spellID)
    if(not classData or not spellID) then
        return nil;
    end

    if(classData.pets and classData.pets[spellID]) then
        return true;
    end

    if(classData.auras and classData.auras[spellID]) then
        return true;
    end

    if(classData.spells and classData.spells[spellID]) then
        return true;
    end

    return false;
end

local function AnyClassContains(spellID, spellName)
    for class, data in pairs(ArenaAnalyticsDevData.classes) do
        if(ClassDataContains(data, spellID)) then
            return true, class;
        end
    end

    return false;
end

local function RemoveClasslessSpell(spellID)
    for class, data in pairs(ArenaAnalyticsDevData.classes) do
        if(data[spellID]) then
            Debug:Log("Removed spell from class.", data.name, data.id, class);
        end

        data[spellID] = nil;
    end
end

local function FindOrAdd_Spell(class, spellID, spellName, isAura, isPet)
    local classData = FindOrAdd_Class(class);

    if(not classData or not spellID) then
        return;
    end

    if(ArenaAnalyticsDevData.classlessSpells[spellID]) then
        return;
    end

    if(ClassDataContains(classData, spellID) ~= false) then
        return;
    end

    local spellData = {
        id = spellID,
        name = spellName,
        isAura = isAura,
        isPet = isPet,
    };

    local exists, detectedClass = AnyClassContains(spellID, spellName);
    if(exists) then
        if(not ArenaAnalyticsDevData.classlessSpells[spellID]) then
            Debug:Log("Spell ID found in multiple classes. Marked as classless:", spellID, spellName, detectedClass, class);
        end

        ArenaAnalyticsDevData.classlessSpells[spellID] = spellData;
        RemoveClasslessSpell(spellID);

        return;
    end

    if(isPet) then
        classData.pets = classData.pets or {};
        classData.pets[spellID] = spellData;
    elseif(isAura) then
        classData.auras = classData.auras or {};
        classData.auras[spellID] = spellData;
    else
        classData.spells = classData.spells or {};
        classData.spells[spellID] = spellData;
    end

    Debug:Log("Added spell:", spellName, spellID, class);
end


-------------------------------------------------------------------------


function DataCollector:ProcessUnitAuraEvent(...)
	local unitTarget, updateInfo = ...;
	if(not updateInfo or updateInfo.isFullUpdate) then
		return;
	end

	if(updateInfo.addedAuras) then
		for _,aura in ipairs(updateInfo.addedAuras) do
			if(aura and aura.sourceUnit and aura.isFromPlayerOrPlayerPet) then
				local sourceGUID = Helpers:UnitGUID(aura.sourceUnit);
                DataCollector:HandleSpellID(aura.spellId, aura.name, true, sourceGUID);
			end
		end
	end
end

function DataCollector:ProcessCombatLogEvent(...)
	local timestamp,logEventType,_,sourceGUID,_,_,_,destGUID,_,_,_,spellID,spellName = CombatLogGetCurrentEventInfo();

	-- Tracking teams for spec/race and in case arena is quitted
	if (logEventType == "SPELL_CAST_SUCCESS") then
        DataCollector:HandleSpellID(spellID, spellName, false, sourceGUID);

	elseif(logEventType == "SPELL_AURA_APPLIED" or logEventType == "SPELL_AURA_REMOVED") then
		DataCollector:HandleSpellID(spellID, spellName, true, sourceGUID);
	end
end


function DataCollector:HandleSpellID(spellID, spellName, isAura, sourceGUID)
    if(not spellID or not sourceGUID) then
        return;
    end

    for _,excluded in ipairs(excludedStrings) do
        if(spellName and spellName:lower():find(excluded, 1, true)) then
            ArenaAnalyticsDevData.classlessSpells[spellID] = nil;
            RemoveClasslessSpell(spellID);
            return;
        end
    end

    local playerGUID, isPet = DataCollector:ToPlayerOrOwnerGUID(sourceGUID);
    if(not playerGUID) then
        -- Nither player nor confirmed player-owned pet.
        return;
    end

    local class = select(2, GetPlayerInfoByGUID(playerGUID));

    if(not class) then
        return;
    end

    FindOrAdd_Spell(class, spellID, spellName, isAura, isPet);
end

function DataCollector:ToPlayerOrOwnerGUID(GUID)
    if(not GUID) then
        return nil, nil;
    end

    if(GUID:find("Player-", 1, true)) then
        return GUID, false;
    elseif(not GUID:find("Pet-", 1, true)) then
        return nil, nil;
    end

    if(GUID == UnitGUID("pet")) then
        return Helpers:UnitGUID("player"), true;
    end

    for i=1, 4 do
        local unitToken = "party"..i.."pet";
        if(GUID == UnitGUID(unitToken)) then
            return UnitOwnerGUID(unitToken), true;
        end
    end

    return nil, nil;
end