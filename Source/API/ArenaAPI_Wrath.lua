-- API adjusted functions to let calling code stay version agnostic.
local _, ArenaAnalytics = ...; -- Addon Namespace
local API = ArenaAnalytics.API;

-------------------------------------------------------------------------

API.defaultButtonTemplate = "UIServiceButtonTemplate";

API.availableBrackets = {
	{ name = "2v2", key = 1},
	{ name = "3v3", key = 2},
	{ name = "5v5", key = 3},
};

API.availableMaps = {
	{ name = "Blade's Edge Arena", key = "BEA"},
	{ name = "Dalaran Arena", key = "DA"},
	{ name = "Nagrand Arena", key = "NA"},
	{ name = "Ruins of Lordaeron", key = "RoL"},
};

-- NOTE: Not updated to release data format (id and preg missing)
-- Get local player current spec
function API:GetMySpec()
    local spec = nil
	local currentSpecPoints = 0

    for i = 1, 3 do
        local name, _, pointsSpent = GetTalentTabInfo(i);
		if (pointsSpent > currentSpecPoints) then
			currentSpecPoints = pointsSpent;
			spec = name;
		end
 	end

	spec = spec == "Feral Combat" and "Feral" or spec;

    return nil;
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

    [81] = 845, -- Protection Paladin
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

function API:GetSpecInfo(spec_id)
	local expansionSpecID = spec_id and internalSpecIdMap[spec_id];
    if(not expansionSpecID) then
        return nil;
    end
    
    local _,spec,_,icon,_,_,class = GetSpecializationInfoByID(spec_id);
    return class,spec,icon;

end

function API:GetMappedAddonSpecID(spec_id)
	for addonSpecID,specID in pairs(internalSpecIdMap) do
		if(specID == spec_id) then
			return addonSpecID;
		end
	end
end