-- API adjusted functions to let calling code stay version agnostic.
local _, ArenaAnalytics = ...; -- Addon Namespace
local API = ArenaAnalytics.API;

-------------------------------------------------------------------------

API.defaultButtonTemplate = "UIPanelButtonTemplate";

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
    local currentSpec = GetSpecialization();
    local id = currentSpec and GetSpecializationInfo(currentSpec);

    local spec_id = API:GetMappedAddonSpecID(id);
	ArenaAnalytics:Log("My Spec ID:", spec_id);
	return spec_id;
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

-- TODO: Update for TWW IDs
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

function API:GetMappedAddonSpecID(spec_id)
	for addonSpecID,specID in pairs(API.specMappingTable) do
		if(specID == spec_id) then
			return addonSpecID;
		end
	end
end