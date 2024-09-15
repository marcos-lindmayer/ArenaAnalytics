-- API adjusted functions to let calling code stay version agnostic.
local _, ArenaAnalytics = ...; -- Addon Namespace
local API = ArenaAnalytics.API;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;
local Localization = ArenaAnalytics.Localization;
local Internal = ArenaAnalytics.Internal;

-------------------------------------------------------------------------

API.defaultButtonTemplate = "UIServiceButtonTemplate";

API.availableBrackets = {
	{ name = "2v2", key = 1},
	{ name = "3v3", key = 2},
	{ name = "5v5", key = 3},
}

API.availableMaps = {
    { id = 562,  token = "BladesEdgeArena" },
    { id = 559,  token = "NagrandArena" },
    { id = 572,  token = "RuinsOfLordaeron" },
    { id = 617,  token = "DalaranArena" },
};

function API:IsInArena()
    return IsActiveBattlefieldArena();
end

function API:IsRatedArena()
    return API:IsInArena() and not IsWargame() and not IsArenaSkirmish();
end

function API:IsShuffle()
    return nil;
end

function API:GetBattlefieldStatus(battlefieldId)
    local status, _, _, _, _, teamSize, isRated = GetBattlefieldStatus(battlefieldId);
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

function API:GetBattlefieldScore(index)
    local name, kills, _, deaths, _, teamIndex, _, race, _, classToken, damage, healing = GetBattlefieldScore(index);
    name = Helpers:ToFullName(name);

    -- Convert values
    local race_id = Localization:GetRaceID(race);
    local class_id = Internal:GetAddonClassID(classToken);
    
    return name, race_id, class_id, teamIndex, kills, deaths, damage, healing;
end

-- Get local player current spec
function API:GetMySpec()
    local spec_id = nil;
	local currentSpecPoints = 0;

    for i = 1, 3 do
        local id, name, _, _, pointsSpent = GetTalentTabInfo(i);
		if (pointsSpent > currentSpecPoints) then
			currentSpecPoints = pointsSpent;
			spec_id = API:GetMappedAddonSpecID(id);
		end
 	end

	ArenaAnalytics:Log("My Spec ID:", spec_id);
	return addonSpecID;
end

function API:GetInspectSpecialization(unitToken)
    if(not unitToken or not UnitExists(unitToken)) then
        return;
    end

    if(UnitGUID("player") == UnitGUID(unitToken)) then
        return API:GetMySpec();
    end

    local spec_id, currentSpecPoints = nil, 0;
    for i = 1, 3 do
        local id, name, _, _, pointsSpent = GetTalentTabInfo(i, true);
		if (id and pointsSpent > currentSpecPoints) then
			currentSpecPoints = pointsSpent;
			spec_id = API:GetMappedAddonSpecID(id);
		end
 	end

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
    [1] = 748, -- Restoration Druid
    [2] = 750, -- Feral Druid
    [3] = 752, -- Balance Druid

    [11] = 839, -- Holy Paladin
    [12] = 845, -- Protection Paladin
    [13] = nil, -- Preg Paladin
    [14] = 855, -- Retribution Paladin

    [21] = 262, -- Restoration Shaman
    [22] = 261, -- Elemental Shaman
    [23] = 263, -- Enhancement Shaman

    [31] = 400, -- Unholy Death Knight
    [32] = 399, -- Frost Death Knight
    [33] = 398, -- Blood Death Knight

    [41] = 811, -- Beast Mastery Hunter
    [42] = 807, -- Marksmanship Hunter
    [43] = 809, -- Survival Hunter

    [51] = 823, -- Frost Mage
    [52] = 851, -- Fire Mage
    [53] = 799, -- Arcane Mage

    [61] = 183, -- Subtlety Rogue
    [62] = 182, -- Assassination Rogue
    [63] = 181, -- Combat Rogue
    [64] = nil, -- Outlaw Rogue

    [71] = 871, -- Affliction Warlock
    [72] = 865, -- Destruction Warlock
    [73] = 867, -- Demonology Warlock

    [81] = 845, -- Protection Warrior
    [82] = 746, -- Arms Warrior
    [83] = 815, -- Fury Warrior

    [91] = 760, -- Discipline Priest
    [92] = 813, -- Holy Priest
    [93] = 795, -- Shadow Priest
    
    [101] = nil, -- Mistweaver Monk
    [102] = nil, -- Brewmaster Monk
    [103] = nil, -- Windwalker Monk
    
    [111] = nil, -- Vengeance Demon Hunter
    [112] = nil, -- Havoc Demon Hunter
    
    [122] = nil, -- Preservation Evoker
    [123] = nil, -- Augmentation Evoker
    [123] = nil, -- Devastation Evoker
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
end