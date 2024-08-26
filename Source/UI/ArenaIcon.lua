local _, ArenaAnalytics = ...; -- Addon Namespace
local ArenaIcon = ArenaAnalytics.ArenaIcon;
ArenaIcon.__index = ArenaIcon

-- Local module aliases
local Constants = ArenaAnalytics.Constants;

-------------------------------------------------------------------------

function ArenaIcon:Create(parent, classIndex, spec_id, size, hideSpec)
    local name = "ArenaIcon_"..(class or "?").."_"..(spec or "");
    local newFrame = CreateFrame("Frame", name, parent);
    newFrame:SetSize(size, size);
    
    if(class) then 
        newFrame.classTexture = newFrame:CreateTexture();
        newFrame.classTexture:SetPoint("CENTER", newFrame, 0, 0);
        newFrame.classTexture:SetSize(size,size);

        local classIconTexture = Internal:GetClassIcon(classIndex);
        newFrame.classTexture:SetTexture(classIconTexture);

        if(spec) then
            local halfSize = floor(size/2);

            newFrame.specOverlay = CreateFrame("Frame", nil, newFrame);
            newFrame.specOverlay:SetPoint("BOTTOMRIGHT", newFrame.classTexture, -1, 2);
            newFrame.specOverlay:SetSize(halfSize, halfSize);

            newFrame.specOverlay.texture = newFrame.specOverlay:CreateTexture();
            newFrame.specOverlay.texture:SetPoint("CENTER");
            newFrame.specOverlay.texture:SetSize(halfSize, halfSize);
            
            local specIconTexture = ArenaAnalytics:GetSpecIcon(spec);
            newFrame.specOverlay.texture:SetTexture(specIconTexture);

            if(hideSpec) then
                newFrame.specOverlay:Hide()
            end
        end
    end

    -- Functions
    function newFrame:SetSpecVisibility(visible) 
        if(self.specOverlay and self.specOverlay.texture) then
            if(visible) then
                self.specOverlay:Show();
            else
                self.specOverlay:Hide();
            end
        end
    end

    return newFrame;
end