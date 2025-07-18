local _, ArenaAnalytics = ...; -- Addon Namespace
local Export = ArenaAnalytics.Export;

-- Local module aliases
local AAtable = ArenaAnalytics.AAtable;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------


function Export:IsExporting()
    return nil;
end


function Export:Start()
    if(Export:IsExporting()) then
        return;
    end


end


function Export:Stop()
    
end


function Export:Clear()

end


function Export:Reset()

end