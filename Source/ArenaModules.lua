local _, ArenaAnalytics = ...; -- Namespace

-------------------------------------------------------------------------
-- Declare Module Namespaces

ArenaAnalytics.Colors = {};
ArenaAnalytics.Prints = {};
ArenaAnalytics.Debug = {};
ArenaAnalytics.Commands = {};

ArenaAnalytics.Constants = {};
ArenaAnalytics.SpecSpells = {};
ArenaAnalytics.LocalizationTables = {};
ArenaAnalytics.Bitmap = {};
ArenaAnalytics.TablePool = {};

ArenaAnalytics.ArenaID = {};
ArenaAnalytics.Localization = {};
ArenaAnalytics.Lookup = {};
ArenaAnalytics.ArenaText = {};

ArenaAnalytics.Helpers = {};
ArenaAnalytics.API = {};
ArenaAnalytics.Inspection = {};

ArenaAnalytics.AAtable = {};
ArenaAnalytics.Selection = {};
ArenaAnalytics.ArenaIcon = {};
ArenaAnalytics.Tooltips = {};
ArenaAnalytics.ShuffleTooltip = {};
ArenaAnalytics.PlayerTooltip = {};
ArenaAnalytics.ImportProgressFrame = {};

ArenaAnalytics.Dropdown = {};
ArenaAnalytics.Dropdown.List = {};
ArenaAnalytics.Dropdown.Button = {};
ArenaAnalytics.Dropdown.EntryFrame = {};
ArenaAnalytics.Dropdown.Display = {};

ArenaAnalytics.Options = {};
ArenaAnalytics.AAmatch = {};
ArenaAnalytics.Events = {};
ArenaAnalytics.ArenaRatedInfo = {};
ArenaAnalytics.Sessions = {};
ArenaAnalytics.ArenaMatch = {};
ArenaAnalytics.GroupSorter = {};

ArenaAnalytics.ArenaTracker = {};

ArenaAnalytics.Search = {};
ArenaAnalytics.Filters = {};
ArenaAnalytics.FilterTables = {};

ArenaAnalytics.Export = {};
ArenaAnalytics.Import = {};
ArenaAnalytics.ImportBox = {};
ArenaAnalytics.VersionManager = {};

ArenaAnalytics.Initialization = {};


-------------------------------------------------------------------------
-- Local module aliases

local Options = ArenaAnalytics.Options;

-------------------------------------------------------------------------

-- This is safe to call early, but Options may not have assigned defaults yet.
function Options:GetSafe(setting)
    if(Options and Options.Get) then
        return Options:Get(setting);
    end

    return setting and ArenaAnalyticsSharedSettingsDB and ArenaAnalyticsSharedSettingsDB[setting];
end
