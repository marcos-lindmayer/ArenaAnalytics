local _, ArenaAnalytics = ...; -- Addon Namespace
local ArenaIcon = ArenaAnalytics.ArenaIcon;
ArenaIcon.__index = ArenaIcon

-- Local module aliases
local Constants = ArenaAnalytics.Constants;
local Internal = ArenaAnalytics.Internal;
local Helpers = ArenaAnalytics.Helpers;

-------------------------------------------------------------------------

function ArenaIcon:Create(parent, size, skipDeath)
    local name = "ArenaIcon_"..(spec_id or "???");
    local newFrame = CreateFrame("Frame", name, parent);
    newFrame:SetPoint("CENTER");    
    newFrame:SetSize(size, size);

    local baseFrameLevel = newFrame:GetFrameLevel();

    newFrame.classTexture = newFrame:CreateTexture();
    newFrame.classTexture:SetPoint("CENTER");
    newFrame.classTexture:SetAllPoints(newFrame);
    newFrame.classTexture:SetTexture(134400);

    if(not skipDeath) then
        newFrame.deathOverlay = CreateFrame("Frame", nil, newFrame);
        newFrame.deathOverlay:SetAllPoints(newFrame);
        newFrame.deathOverlay:SetFrameLevel(baseFrameLevel + 5);

        newFrame.deathOverlay.texture = newFrame.deathOverlay:CreateTexture();
        newFrame.deathOverlay.texture:SetAllPoints(newFrame.deathOverlay);
        newFrame.deathOverlay.texture:SetColorTexture(1, 0, 0, 0.27);
    end

    local halfSize = floor(size/2);
    newFrame.specOverlay = CreateFrame("Frame", nil, newFrame);
    newFrame.specOverlay:SetPoint("BOTTOMRIGHT", newFrame.classTexture, -1, 2);
    newFrame.specOverlay:SetSize(halfSize, halfSize);
    newFrame.specOverlay:SetFrameLevel(baseFrameLevel + 10);

    newFrame.specOverlay.texture = newFrame.specOverlay:CreateTexture();
    newFrame.specOverlay.texture:SetAllPoints(newFrame.specOverlay);

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

    function newFrame:SetDeathVisibility(visible)
        if(self.deathOverlay and self.deathOverlay.texture) then
            if(visible and self.isFirstDeath) then
                self.deathOverlay:Show();
            else
                self.deathOverlay:Hide();
            end
        end
    end

    function newFrame:SetSpec(spec_id)
        spec_id = tonumber(spec_id);
        if(spec_id) then
            local classIconTexture = Internal:GetClassIcon(spec_id);
            newFrame.classTexture:SetTexture(classIconTexture or 134400);
        else
            newFrame.classTexture:SetTexture("");
        end

        if(Helpers:IsSpecID(spec_id)) then
            local specIconTexture = Constants:GetSpecIcon(spec_id);
            newFrame.specOverlay.texture:SetTexture(specIconTexture or "");
        else
            newFrame.specOverlay.texture:SetTexture("");
        end
    end

    function newFrame:SetIsFirstDeath(value, alwaysShown)
        if(skipDeath) then
            return;
        end

        self.isFirstDeath = value and true or nil;

        if(not self.isFirstDeath or not alwaysShown) then
            self.deathOverlay:Hide();
        else
            self.deathOverlay:Show();
        end
    end

    return newFrame;
end