-- API adjusted functions to let calling code stay version agnostic.
local _, ArenaAnalytics = ...; -- Addon Namespace
local API = ArenaAnalytics.API;

-------------------------------------------------------------------------

API.defaultButtonTemplate = "UIServiceButtonTemplate";

API.availableBrackets = {
	{ name = "2v2", key = 1},
	{ name = "3v3", key = 2},
	{ name = "5v5", key = 3},
}

API.availableMaps = {
	{ name = "Blade's Edge Arena", key = "BEA"},
	{ name = "Dalaran Arena", key = "DA"},
	{ name = "Nagrand Arena", key = "NA"},
	{ name = "Ruins of Lordaeron", key = "RoL"},
};

function API:IsInArena()
    return IsActiveBattlefieldArena();
end

function API:IsShuffle()
    return nil;
end

function API:GetBattlefieldStatus(battlefieldId)
    local status, _, _, _, _, teamSize, isRated = GetBattlefieldStatus(currentArena.battlefieldId);
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

-- Get local player current spec
function API:GetMySpec()
    local spec_id = nil;
	local currentSpecPoints = 0;

    for i = 1, 3 do
        local id, name, _, _, pointsSpent = GetTalentTabInfo(i);
		if (pointsSpent > currentSpecPoints) then
			currentSpecPoints = pointsSpent;
			spec_id = API:GetMappedAddonSpecID(id);;
		end
 	end

	ArenaAnalytics:Log("My Spec ID:", spec_id);
	return addonSpecID;
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
	for spec_id,mappedID in pairs(API.specMappingTable) do
		if(specID == mappedID) then
			return addonSpecID;
		end
	end
end