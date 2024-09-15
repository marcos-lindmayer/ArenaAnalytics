-- API adjusted functions to let calling code stay version agnostic.
local _, ArenaAnalytics = ...; -- Addon Namespace
local API = ArenaAnalytics.API;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;
local Localization = ArenaAnalytics.Localization;
local Internal = ArenaAnalytics.Internal;

-------------------------------------------------------------------------

API.defaultButtonTemplate = "UIPanelButtonTemplate";

API.availableBrackets = {
    { name = "Solo", key = 4},
	{ name = "2v2", key = 1},
	{ name = "3v3", key = 2},
	{ name = "5v5", key = 3},
}

-- Order defines the UI order of maps filter dropdown
API.availableMaps = {
    { id = 1505,  token = "NagrandArena" },
    { id = 572,  token = "RuinsOfLordaeron" },
    { id = 2167, token = "TheRobodrome" }, -- Unconfirmed
    { id = 2563, token = "NokhudonProvingGrounds" }, -- Unconfirmed
    { id = 1552,  token = "AshamanesFall" },
    { id = 1672,  token = "BladesEdgeArena" }, -- Unconfirmed
    { id = 1911,  token = "Mugambala" }, -- Unconfirmed
    { id = 1504,  token = "BlackRookHoldArena" },
    { id = 1825,  token = "HookPoint" },
    { id = 2373, token = "EmpyreanDomain" }, -- Unconfirmed
    { id = 617,  token = "DalaranArena" }, -- Unconfirmed
    { id = 1134,  token = "TheTigersPeak" },
    { id = 2547, token = "EnigmaCrucible" }, -- Unconfirmed
    { id = 2509, token = "MaldraxxusColiseum" },
    { id = 980,  token = "TolVironArena" }, -- Unconfirmed
}

function API:IsInArena()
    return IsActiveBattlefieldArena() and not C_PvP.IsInBrawl() and not C_PvP.IsSoloShuffle(); -- TODO: Add solo shuffle support
end

function API:IsRatedArena()
    return API:IsInArena() and C_PvP.IsRatedArena() and not IsWargame() and not IsArenaSkirmish() and not C_PvP.IsInBrawl();
end

function API:IsShuffle()
    return C_PvP.IsSoloShuffle();
end

function API:GetBattlefieldStatus(battlefieldId)
    local status,_, teamSize = GetBattlefieldStatus(battlefieldId);
    local isRated = API:IsRatedArena();

    return status, teamSize, isRated;
end

function API:GetCurrentMapID()
    return select(8,GetInstanceInfo());
end

function API:GetTeamMMR(teamIndex)
    local _,_,_,mmr = GetBattlefieldTeamInfo(teamIndex);
    return tonumber(mmr);
end

function API:GetPersonalRatedInfo(bracketIndex)
    bracketIndex = tonumber(bracketIndex);
    if(not bracketIndex) then
        return nil;
    end

    -- Solo Shuffle
    if(bracketIndex == 4) then
        return nil; -- NYI
    end

    local rating,_,_,seasonPlayed = GetPersonalRatedInfo(bracketIndex);
    return rating, seasonPlayed;
end

-- TODO: Decide if we wanna get rating and MMR values from here
function API:GetBattlefieldScore(index)
    -- NOTE: GetBattlefieldScore appears to be deprecated in Blizzard API. Find the replacement.
    local name, kills, _, deaths, _, teamIndex, race, _, classToken, damage, healing, rating, ratingDelta, preMatchMMR, mmrChange, spec = GetBattlefieldScore(index);
    name = Helpers:ToFullName(name);

    -- Convert localized values
    local race_id = Localization:GetRaceID(race);
    local spec_id = Localization:GetSpecID(spec);

    -- Fall back to class ID
    if(not spec_id) then
        spec_id = Internal:GetAddonClassID(classToken);
    end
    
    return name, race_id, spec_id, teamIndex, kills, deaths, damage, healing;
end

-- Get local player current spec
function API:GetMySpec()
    local currentSpec = GetSpecialization();
    local id = currentSpec and GetSpecializationInfo(currentSpec);

    local spec_id = API:GetMappedAddonSpecID(id);
	ArenaAnalytics:Log("My Spec ID:", spec_id, "from ID:", id);
	return spec_id;
end

function API:GetInspectSpecialization(unitToken)
    if(not unitToken or not UnitExists(unitToken)) then
        return;
    end

    if(UnitGUID("player") == UnitGUID(unitToken)) then
        return API:GetMySpec();
    end

    local specID = GetInspectSpecialization(unitToken);
    return API:GetMappedAddonSpecID(specID);
end

function API:GetPlayerInfoByGUID(GUID)
    local _,class,_,race,_,name,realm = GetPlayerInfoByGUID(GUID);
    return class,race,name,realm;
end

API.maxRaceID = 70;

API.classMappingTable = {
    [1] = 80,
    [2] = 10,
    [3] = 40,
    [4] = 60,
    [5] = 90,
    [6] = 30,
    [7] = 20,
    [8] = 50,
    [9] = 70,
    [10] = 100,
    [11] = 0,
    [12] = 110,
    [13] = 120,
}

-- Internal Addon Spec ID to expansion spec IDs
API.specMappingTable = {
    [1] = 105, -- Restoration Druid
    [2] = 103, -- Feral Druid
    [3] = 102, -- Balance Druid
    [4] = 104, -- Guardian Druid

    [11] = 65, -- Holy Paladin
    [12] = 66, -- Protection Paladin
    [13] = nil, -- Preg Paladin
    [14] = 70, -- Retribution Paladin

    [21] = 264, -- Restoration Shaman
    [22] = 262, -- Elemental Shaman
    [23] = 263, -- Enhancement Shaman

    [31] = 252, -- Unholy Death Knight
    [32] = 251, -- Frost Death Knight
    [33] = 250, -- Blood Death Knight

    [41] = 253, -- Beast Mastery Hunter
    [42] = 254, -- Marksmanship Hunter
    [43] = 255, -- Survival Hunter

    [51] = 64, -- Frost Mage
    [52] = 63, -- Fire Mage
    [53] = 62, -- Arcane Mage

    [61] = 261, -- Subtlety Rogue
    [62] = 259, -- Assassination Rogue
    [63] = nil, -- Combat Rogue
    [64] = 260, -- Outlaw Rogue

    [71] = 265, -- Affliction Warlock
    [72] = 267, -- Destruction Warlock
    [73] = 266, -- Demonology Warlock

    [81] = 73, -- Protection Warrior
    [82] = 71, -- Arms Warrior
    [83] = 72, -- Fury Warrior

    [91] = 256, -- Discipline Priest
    [92] = 257, -- Holy Priest
    [93] = 258, -- Shadow Priest
    
    [101] = 270, -- Mistweaver Monk
    [102] = 268, -- Brewmaster Monk
    [103] = 269, -- Windwalker Monk
    
    [111] = 581, -- Vengeance Demon Hunter
    [112] = 577, -- Havoc Demon Hunter
    
    [122] = 1468, -- Preservation Evoker
    [123] = 1473, -- Augmentation Evoker
    [123] = 1467, -- Devastation Evoker
}

function API:GetMappedAddonSpecID(specID)
    if(not specID) then
        return nil;
    end

    for spec_id, mappedID in pairs(API.specMappingTable) do
		if(specID == mappedID) then
			return spec_id;
		end
	end

    ArenaAnalytics:Log("Failed to find spec_id for:", specID, type(specID));
    return nil;
end