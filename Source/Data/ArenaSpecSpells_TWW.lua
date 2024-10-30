local _, ArenaAnalytics = ...; -- Addon Namespace
local SpecSpells = ArenaAnalytics.SpecSpells;

-------------------------------------------------------------------------

local heroSpecSpells = {
    -- TODO: Fill this
}

function SpecSpells:GetHeroSpec(spellID)
    return heroSpecSpells[spellID];
end