local _, ArenaAnalytics = ... -- Addon Namespace
local Search = ArenaAnalytics.Search;

-- Local module aliases
local Options = ArenaAnalytics.Options;
local Constants = ArenaAnalytics.Constants;

-------------------------------------------------------------------------
-- Search Colors

function Search:ColorizeInvalid(text)
    return text and "|cffFF0000" .. text .. "|r" or "";
end

function Search:ColorizeSymbol(text)
    return text and "|cff00ccff" .. text .. "|r" or "";
end

-- TODO: Add token specific colors
function Search:ColorizeToken(token)
    if(token == nil) then
        return "";
    end

    local type = token.explicitType;
    local text = token:GetRaw();
    
    return text and "|cffFFFFFF" .. text .. "|r" or "";
end