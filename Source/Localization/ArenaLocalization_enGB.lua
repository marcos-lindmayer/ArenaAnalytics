local _, ArenaAnalytics = ... -- Namespace
local Localization = ArenaAnalytics.Localization;

-- Local module aliases
local Helpers = ArenaAnalytics.Helpers;

-------------------------------------------------------------------------

local language = {
    key = "enGB",
    englishName = "English",
    localizedName = "English",
};

local L = {};

-------------------------------------------------------------------------
-- Options



-------------------------------------------------------------------------
-- Maps

L["MAP_BLADES_EDGE_ARENA"] = {
    default = "Blade's Edge Arena",
    short = "BEA",
    search_aliases = { "Blade's Edge", "Blades Edge", "BEA" },
};

L["MAP_RUINS_OF_LORDAERON"] = {
    default = "Ruins of Lordaeron",
    short = "RoL",
    search_aliases = { "Lordaeron", "Ruins", "RoL" },
};

L["MAP_NAGRAND_ARENA"] = {
    default = "Nagrand Arena", 
    short = "NA",
    search_aliases = { "Nagrand", "NA" },
};

L["MAP_RING_OF_VALOR"] = {
    default = "Ring of Valor",
    short = "RoV",
    search_aliases = { "Valor", "Ring", "RoV" },
};

L["MAP_DALARAN_ARENA"] = {
    default = "Dalaran Arena",
    short = "DA",
    search_aliases = { "Dalaran", "DA" },
};

L["MAP_TIGERS_PEAK"] = {
    default = "The Tiger's Peak",
    short = "TP",
    search_aliases = { "Tiger's Peak", "Tigers Peak", "TP" },
};

L["MAP_TOLVIRON_ARENA"] = {
    default = "Tol'Viron Arena",
    short = "TVA",
    search_aliases = { "Tol'Viron", "TVA" },
};

L["MAP_ASHAMANES_FALL"] = {
    default = "Ashamane's Fall",
    short = "AF",
    search_aliases = { "Ashamane", "Ashamane's Fall", "AF" },
};

L["MAP_BLACK_ROOK_HOLD_ARENA"] = {
    default = "Black Rook Hold Arena",
    short = "BRH",
    search_aliases = { "Black Rook", "BRH" },
};

L["MAP_HOOK_POINT"] = {
    default = "Hook Point",
    short = "HP",
    search_aliases = { "Hook", "Hook Point", "HP" },
};

L["MAP_KUL_TIRAS_ARENA"] = {
    default = "Kul Tiras Arena",
    short = "KTA",
    search_aliases = { "Kul Tiras", "KTA" },
};

L["MAP_MUGAMBALA"] = {
    default = "Mugambala",
    short = "M",
    search_aliases = { "Mugambala", "M" },
};

L["MAP_ROBODROME"] = {
    default = "The Robodrome",
    short = "TR",
    search_aliases = { "Robodrome", "TR" },
};

L["MAP_EMPYREAN_DOMAIN"] = {
    default = "Empyrean Domain",
    short = "ED",
    search_aliases = { "Empyrean", "ED" },
};

L["MAP_ENIGMA_CRUCIBLE"] = {
    default = "Enigma Crucible",
    short = "EC",
    search_aliases = { "Enigma", "Crucible", "EC" },
};

L["MAP_MALDRAXXUS_COLISEUM"] = {
    default = "Maldraxxus Coliseum",
    short = "MC",
    search_aliases = { "Maldraxxus", "Coliseum", "MC" },
};

L["MAP_NOKHUDON_PROVING_GROUNDS"] = {
    default = "Nokhudon Proving Grounds",
    short = "NPG",
    search_aliases = { "Nokhudon", "Proving Grounds", "NPG" },
};

L["MAP_CAGE_OF_CARNAGE"] = {
    default = "Cage of Carnage",
    short = "CoC",
    search_aliases = { "Carnage", "Cage", "CoC" },
};


-------------------------------------------------------------------------
-- Race

L["RACE_HUMAN"] = {
    default = "Human",
    search_aliases = { "human" },
};

L["RACE_ORC"] = { 
    default = "Orc", 
    search_aliases = { "orc" },
};

L["RACE_DWARF"] = { 
    default = "Dwarf",
    search_aliases = { "dwarf" },
};

L["RACE_UNDEAD"] = {
    default = "Undead",
    search_aliases = { "undead" },
};

L["RACE_NIGHT_ELF"] = {
    default = "Night Elf",
    short = "Nelf",
    search_aliases = { "night elf", "nightelf", "nelf" },
};

L["RACE_TAUREN"] = {
    default = "Tauren",
    search_aliases = { "tauren" },
};

L["RACE_GNOME"] = {
    default = "Gnome",
    search_aliases = { "gnome" },
};

L["RACE_TROLL"] = {
    default = "Troll",
    search_aliases = { "troll" },
};

L["RACE_DRAENEI"] = {
    default = "Draenei",
    search_aliases = { "draenei" },
};

L["RACE_BLOOD_ELF"] = {
    default = "Blood Elf",
    short = "Belf",
    search_aliases = { "blood elf", "bloodelf", "belf" },
};

L["RACE_WORGEN"] = {
    default = "Worgen",
    search_aliases = { "worgen" },
};

L["RACE_GOBLIN"] = {
    default = "Goblin",
    search_aliases = { "goblin" },
};

L["RACE_PANDAREN"] = {
    default = "Pandaren",
    search_aliases = { "pandaren" },
};

L["RACE_DRACTHYR"] = {
    default = "Dracthyr",
    search_aliases = { "dracthyr" },
};

L["RACE_VOID_ELF"] = {
    default = "Void Elf",
    short = "Velf",
    search_aliases = { "void elf", "voidelf", "velf" },
};

L["RACE_NIGHTBORNE"] = {
    default = "Nightborne",
    search_aliases = { "nightborne" },
};

L["RACE_LIGHTFORGED_DRAENEI"] = {
    default = "Lightforged Draenei",
    short = "L. Draenei",
    search_aliases = { "lightforged draenei", "lightforgeddraenei", "ldraenei" },
};

L["RACE_HIGHMOUNTAIN_TAUREN"] = {
    default = "Highmountain Tauren",
    short = "H. Tauren",
    search_aliases = { "highmountain tauren", "highmountaintauren", "htauren" },
};

L["RACE_DARK_IRON_DWARF"] = {
    default = "Dark Iron Dwarf",
    short = "D. Dwarf",
    search_aliases = { "dark iron dwarf", "darkirondwarf", "didwarf", "ddwarf" },
};

L["RACE_MAGHAR_ORC"] = {
    default = "Mag'har Orc",
    short = "M. Orc",
    search_aliases = { "mag'har orc", "magharorc", "morc" },
};

L["RACE_EARTHEN"] = {
    default = "Earthen",
    search_aliases = { "earthen" },
};

L["RACE_KUL_TIRAN"] = {
    default = "Kul Tiran",
    search_aliases = { "kul tiran", "kultiran" },
};

L["RACE_ZANDALARI_TROLL"] = {
    default = "Zandalari Troll",
    short = "Z. Troll",
    search_aliases = { "zandalari troll", "zandalaritroll", "ztroll" },
};

L["RACE_MECHAGNOME"] = {
    default = "Mechagnome",
    short = "M. Gnome",
    search_aliases = { "mechagnome", "mgnome" },
};

L["RACE_VULPERA"] = {
    default = "Vulpera",
    search_aliases = { "vulpera" },
};

-------------------------------------------------------------------------
-- Classes

L["CLASS_DEATH_KNIGHT"] = {
  default = "Death Knight",
  short = "DK",
  search_aliases = { "Death Knight", "DK", "Deathknight" },
};

L["CLASS_DEMON_HUNTER"] = {
  default = "Demon Hunter",
  short = "DH",
  search_aliases = { "Demon Hunter", "DH", "Demonhunter" },
};

L["CLASS_DRUID"] = {
  default = "Druid",
  search_aliases = { "Druid" },
};

L["CLASS_EVOKER"] = {
  default = "Evoker",
  search_aliases = { "Evoker" },
};

L["CLASS_HUNTER"] = {
  default = "Hunter",
  search_aliases = { "Hunter" },
};

L["CLASS_MAGE"] = {
  default = "Mage",
  search_aliases = { "Mage" },
};

L["CLASS_MONK"] = {
  default = "Monk",
  search_aliases = { "Monk" },
};

L["CLASS_PALADIN"] = {
  default = "Paladin",
  short = "Pala",
  search_aliases = { "Paladin", "Pala", "Pal" },
};

L["CLASS_PRIEST"] = {
  default = "Priest",
  search_aliases = { "Priest" },
};

L["CLASS_ROGUE"] = {
  default = "Rogue",
  search_aliases = { "Rogue" },
};

L["CLASS_SHAMAN"] = {
  default = "Shaman",
  search_aliases = { "Shaman" },
};

L["CLASS_WARLOCK"] = {
  default = "Warlock",
  short = "Lock",
  search_aliases = { "Warlock", "Lock" },
};

L["CLASS_WARRIOR"] = {
  default = "Warrior",
  short = "Warr",
  search_aliases = { "Warrior", "Warr" },
};



-------------------------------------------------------------------------
-- Specs

-- Priest
L["SPEC_DISC_PRIEST"] = {
    default = "Discipline Priest",
    short = "Disc",
    search_aliases = { "discipline", "disc", "dpriest", "dp" },
};

L["SPEC_HOLY_PRIEST"] = {
    default = "Holy Priest",
    short = "Hpriest",
    search_aliases = { "holy priest", "hpriest" },
};

L["SPEC_SHADOW_PRIEST"] = {
    default = "Shadow Priest",
    short = "Spriest",
    search_aliases = { "shadow", "spriest", "sp" },
};


-- Paladin
L["SPEC_HOLY_PALA"] = {
    default = "Holy Paladin",
    short = "Hpal",
    search_aliases = { "holy paladin", "holy pala", "hpal", "hpala", "holypaladin", "holypala" },
};

L["SPEC_PROT_PALA"] = {
    default = "Protection Paladin",
    short = "Prot Pala",
    search_aliases = { "protection paladin", "prot paladin", "protection pala", "prot pala" },
};

L["SPEC_RET_PALA"] = {
    default = "Retribution Paladin",
    short = "Ret",
    search_aliases = { "retribution", "ret", "rpala" },
};

L["SPEC_PREG_PALA"] = {
    default = "Preg Paladin",
    short = "Preg",
    search_aliases = { "preg" },
};


-- Druid
L["SPEC_RESTO_DRUID"] = {
    default = "Restoration Druid",
    short = "Rdruid",
    search_aliases = { "restoration druid", "resto druid", "rdruid", "rd" },
};

L["SPEC_BALANCE_DRUID"] = {
    default = "Balance Druid",
    short = "Boomy",
    search_aliases = { "balance", "bdruid", "moonkin", "boomkin", "boomy" },
};

L["SPEC_FERAL_DRUID"] = {
    default = "Feral Druid",
    short = "Feral",
    search_aliases = { "feral", "fdruid" },
};

L["SPEC_GUARDIAN_DRUID"] = {
    default = "Guardian Druid",
    search_aliases = { "guardian" },
};


-- Shaman
L["SPEC_RESTO_SHAMAN"] = {
    default = "Restoration Shaman",
    short = "Rsham",
    search_aliases = { "restoration shaman", "resto shaman", "rshaman", "rsham" },
};

L["SPEC_ELEMENTAL_SHAMAN"] = {
    default = "Elemental Shaman",
    short = "Ele",
    search_aliases = { "elemental", "ele" },
};

L["SPEC_ENHANCEMENT_SHAMAN"] = {
    default = "Enhancement Shaman",
    short = "Enh",
    search_aliases = { "enhancement", "enh" },
};


-- Warrior
L["SPEC_ARMS_WARRIOR"] = {
    default = "Arms Warrior",
    short = "Arms",
    search_aliases = { "arms", "awarrior", "awarr" },
};

L["SPEC_FURY_WARRIOR"] = {
    default = "Fury Warrior",
    short = "Fury",
    search_aliases = { "fury", "fwarrior", "fwarr", "fwar" },
};

L["SPEC_PROT_WARRIOR"] = {
    default = "Protection Warrior",
    short = "Prot War",
    search_aliases = { "protection warrior", "prot warrior", "pwarrior", "pwarr", "prot war", "protection war" },
};


-- Death Knight
L["SPEC_BLOOD_DK"] = {
    default = "Blood DK",
    short = "BDK",
    search_aliases = { "blood", "bdk" },
};

L["SPEC_FROST_DK"] = {
    default = "Frost DK",
    short = "FDK",
    search_aliases = { "frost death knight", "frost dk", "fdk", "frost deathknight" },
};

L["SPEC_UNHOLY_DK"] = {
    default = "Unholy DK",
    short = "UHDK",
    search_aliases = { "unholy", "uhdk", "udk", "uh" },
};


-- Rogue
L["SPEC_SUBTLETY_ROGUE"] = {
    default = "Subtlety Rogue",
    short = "Sub",
    search_aliases = { "subtlety", "sub", "srogue", "srog" },
};

L["SPEC_ASSASSINATION_ROGUE"] = {
    default = "Assassination Rogue",
    short = "Assa",
    search_aliases = { "assassination", "assa", "arogue" },
};

L["SPEC_OUTLAW_ROGUE"] = {
    default = "Outlaw Rogue",
    search_aliases = { "outlaw", "orogue" },
};

L["SPEC_COMBAT_ROGUE"] = {
    default = "Combat Rogue",
    search_aliases = { "combat", "crogue" },
};


-- Warlock
L["SPEC_AFFLICTION_LOCK"] = {
    default = "Affliction Warlock",
    short = "Affli",
    search_aliases = { "affliction", "affli", "awarlock", "alock" },
};

L["SPEC_DEMONOLOGY_LOCK"] = {
    default = "Demonology Warlock",
    short = "Demo",
    search_aliases = { "demonology", "demo" },
};

L["SPEC_DESTRUCTION_LOCK"] = {
    default = "Destruction Warlock",
    short = "Destro",
    search_aliases = { "destruction", "destro" },
};


-- Hunter
L["SPEC_BEAST_MASTERY_HUNTER"] = {
    default = "Beast Mastery Hunter",
    short = "BM",
    search_aliases = { "beast mastery", "beastmastery", "bm", "bmhunter", "bmhunt" },
};

L["SPEC_MARKSMANSHIP_HUNTER"] = {
    default = "Marksmanship Hunter",
    short = "MM",
    search_aliases = { "marksmanship", "marksman", "mm", "mmhunter", "mmhunt" },
};

L["SPEC_SURVIVAL_HUNTER"] = {
    default = "Survival Hunter",
    short = "Surv",
    search_aliases = { "survival", "surv", "shunter", "shunt", "sh" },
};


-- Mage
L["SPEC_ARCANE_MAGE"] = {
    default = "Arcane Mage",
    short = "Arcane",
    search_aliases = { "arcane", "amage" },
};

L["SPEC_FIRE_MAGE"] = {
    default = "Fire Mage",
    search_aliases = { "fire" },
};

L["SPEC_FROST_MAGE"] = {
    default = "Frost Mage",
    search_aliases = { "frost mage" },
};


-- Monk
L["SPEC_MISTWEAVER_MONK"] = {
    default = "Mistweaver Monk",
    short = "MW",
    search_aliases = { "mistweaver", "mwmonk", "mw" },
};

L["SPEC_BREWMASTER_MONK"] = {
    default = "Brewmaster Monk",
    search_aliases = { "brewmaster", "bmmonk" },
};

L["SPEC_WINDWALKER_MONK"] = {
    default = "Windwalker Monk",
    short = "WW",
    search_aliases = { "windwalker", "wwmonk", "ww" },
};


-- Demon Hunter
L["SPEC_HAVOC_DH"] = {
    default = "Havoc DH",
    short = "HDH",
    search_aliases = { "havoc", "hdh" },
};

L["SPEC_VENGEANCE_DH"] = {
    default = "Vengeance DH",
    short = "VDH",
    search_aliases = { "vengeance", "vdh" },
};


-- Evoker
L["SPEC_PRESERVATION_EVOKER"] = {
    default = "Preservation Evoker",
    short = "Pres",
    search_aliases = { "preservation", "prevoker", "pres" },
};

L["SPEC_AUGMENTATION_EVOKER"] = {
    default = "Augmentation Evoker",
    short = "Aug",
    search_aliases = { "augmentation", "augvoker", "aug" },
};

L["SPEC_DEVASTATION_EVOKER"] = {
    default = "Devastation Evoker",
    short = "Dev",
    search_aliases = { "devastation", "devoker", "dev" },
};


-------------------------------------------------------------------------
-- Register enGB

Localization:Register(language, L);
