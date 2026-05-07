local _, ArenaAnalytics = ...; -- Addon Namespace
local ArenaIcon = ArenaAnalytics.ArenaIcon;
ArenaIcon.__index = ArenaIcon

-- Local module aliases
local Constants = ArenaAnalytics.Constants;
local Helpers = ArenaAnalytics.Helpers;
local API = ArenaAnalytics.API;
local Options = ArenaAnalytics.Options;

-------------------------------------------------------------------------

function ArenaIcon:Create(parent, size, skipDeath)
    local newFrame = CreateFrame("Frame", "ArenaIconFrame", parent);
    newFrame:SetPoint("CENTER");
    newFrame:SetSize(size, size);
    newFrame.skipDeath = skipDeath;

    local baseFrameLevel = newFrame:GetFrameLevel();

    newFrame.classTexture = newFrame:CreateTexture();
    newFrame.classTexture:SetPoint("CENTER");
    newFrame.classTexture:SetAllPoints(newFrame);
    newFrame.classTexture:SetTexture(134400);

    if(not skipDeath) then
        newFrame.deathOverlay = CreateFrame("Frame", nil, newFrame);
        newFrame.deathOverlay:SetAllPoints(newFrame.classTexture);
        newFrame.deathOverlay:SetFrameLevel(baseFrameLevel + 1);

        newFrame.deathOverlay.texture = newFrame.deathOverlay:CreateTexture();
        newFrame.deathOverlay.texture:SetAllPoints(newFrame.deathOverlay);

        local isRedDeathOverlay = true;
        if(isRedDeathOverlay) then -- red
            newFrame.deathOverlay.texture:SetColorTexture(1, 0, 0, 0.3);
        else -- Desaturated
            newFrame.deathOverlay.texture:SetColorTexture(0, 0, 0, 0.5);
        end

        newFrame.deathOverlay:Hide();
    end

    local halfSize = floor(size/2);
    newFrame.specOverlay = CreateFrame("Frame", nil, newFrame);
    newFrame.specOverlay:SetPoint("BOTTOMRIGHT", newFrame.classTexture, -1.6, 1.6);
    newFrame.specOverlay:SetSize(halfSize, halfSize);
    newFrame.specOverlay:SetFrameLevel(baseFrameLevel + 2);

    newFrame.specOverlay.texture = newFrame.specOverlay:CreateTexture();
    newFrame.specOverlay.texture:SetAllPoints(newFrame.specOverlay);

    -- Functions
    function newFrame:UpdateSpecVisibility(forcedVisible)
        if(self.specOverlay and self.specOverlay.texture) then
            if(forcedVisible or Options:Get("alwaysShowSpecOverlay")) then
                self.specOverlay:Show();
            else
                self.specOverlay:Hide();
            end
        end
    end

    function newFrame:UpdateDeathVisibility(visible)
        local isDeathVisible = not self.skipDeath and self.isFirstDeath and (visible or Options:Get("alwaysShowDeathOverlay"));

        self.classTexture:SetDesaturated(isDeathVisible);

        if(self.deathOverlay and self.deathOverlay.texture) then
            if(isDeathVisible) then
                self.deathOverlay:Show();
            else
                self.deathOverlay:Hide();
            end
        end
    end

    function newFrame:SetSpec(spec_id, hideInvalid)
        local isSpec = Helpers:IsSpecID(spec_id);

        local classIcon, specIcon;
        if(Options:Get("fullSizeSpecIcons")) then
            classIcon = isSpec and API:GetSpecIcon(spec_id) or Helpers:GetClassIcon(spec_id);
            specIcon = ""; -- Hide spec icon
        else
            classIcon = Helpers:GetClassIcon(spec_id);
            specIcon = API:GetSpecIcon(spec_id);
        end

        -- Class icon (Fallback to red question mark)
        local hasClassIcon = (classIcon ~= nil);
        if(not classIcon) then
            classIcon = not hideInvalid and 134400 or "";
        end

        -- Set class icon
        newFrame.classTexture:SetTexture(classIcon or 134400);

        -- Force question mark for invalid but known classes
        if(hasClassIcon and newFrame.classTexture:GetTexture() == nil) then
            newFrame.classTexture:SetTexture(134400);
        end

        -- Set spec icon
        local specOverlayIcon = isSpec and specIcon or "";
        newFrame.specOverlay.texture:SetTexture(specOverlayIcon);
    end

    function newFrame:SetIsFirstDeath(value)
        if(self.skipDeath) then
            return;
        end

        self.isFirstDeath = value and true or nil;
        self:UpdateDeathVisibility(true);
    end

    return newFrame;
end