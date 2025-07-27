local _, ArenaAnalytics = ...; -- Addon Namespace
local ArenaIcon = ArenaAnalytics.ArenaIcon;

-- Local module aliases
local ArenaID = ArenaAnalytics.ArenaID;
local Helpers = ArenaAnalytics.Helpers;
local API = ArenaAnalytics.API;
local Options = ArenaAnalytics.Options;

-------------------------------------------------------------------------

-- Create the mixin
local ArenaIconMixin = {};

function ArenaIconMixin:Initialize(size, skipDeath)
    self:SetPoint("CENTER");
    self:SetSize(size, size);

    local baseFrameLevel = self:GetFrameLevel();

    -- Create class texture
    self.classTexture = self:CreateTexture();
    self.classTexture:SetPoint("CENTER");
    self.classTexture:SetAllPoints(self);
    self.classTexture:SetTexture(134400);

    -- Create death overlay if needed
    if not skipDeath then
        self.deathOverlay = CreateFrame("Frame", nil, self);
        self.deathOverlay:SetAllPoints(self.classTexture);
        self.deathOverlay:SetFrameLevel(baseFrameLevel + 1);

        self.deathOverlay.texture = self.deathOverlay:CreateTexture();
        self.deathOverlay.texture:SetAllPoints(self.deathOverlay);
        self.deathOverlay.texture:SetColorTexture(1, 0, 0, 0.31);
    end

    -- Create spec overlay
    local halfSize = floor(size/2);
    self.specOverlay = CreateFrame("Frame", nil, self);
    self.specOverlay:SetPoint("BOTTOMRIGHT", self.classTexture, -1.6, 1.6);
    self.specOverlay:SetSize(halfSize, halfSize);
    self.specOverlay:SetFrameLevel(baseFrameLevel + 2);

    self.specOverlay.texture = self.specOverlay:CreateTexture();
    self.specOverlay.texture:SetAllPoints(self.specOverlay);
end

function ArenaIconMixin:SetSpecVisibility(visible)
    if self.specOverlay and self.specOverlay.texture then
        if visible then
            self.specOverlay:Show();
        else
            self.specOverlay:Hide();
        end
    end
end

function ArenaIconMixin:SetDeathVisibility(visible)
    if self.deathOverlay and self.deathOverlay.texture then
        if visible and self.isFirstDeath then
            self.deathOverlay:Show();
        else
            self.deathOverlay:Hide();
        end
    end
end

function ArenaIconMixin:SetSpec(spec_id, hideInvalid)
    local isSpec = Helpers:IsSpecID(spec_id);

    local classIcon, specIcon;
    if Options:Get("fullSizeSpecIcons") then
        classIcon = isSpec and API:GetSpecIcon(spec_id) or ArenaID:GetClassIcon(spec_id);
        specIcon = ""; -- Hide spec icon
    else
        classIcon = ArenaID:GetClassIcon(spec_id);
        specIcon = API:GetSpecIcon(spec_id);
    end

    -- Class icon (Fallback to red question mark)
    local hasClassIcon = (classIcon ~= nil);
    if not classIcon then
        classIcon = not hideInvalid and 134400 or "";
    end

    -- Set class icon
    self.classTexture:SetTexture(classIcon or 134400);

    -- Force question mark for invalid but known classes
    if hasClassIcon and self.classTexture:GetTexture() == nil then
        self.classTexture:SetTexture(134400);
    end

    -- Set spec icon
    local specOverlayIcon = isSpec and specIcon or "";
    self.specOverlay.texture:SetTexture(specOverlayIcon);
end

function ArenaIconMixin:SetIsFirstDeath(value, alwaysShown)
    if not self.deathOverlay then
        return;
    end

    self.isFirstDeath = value and true or nil;

    if not self.isFirstDeath or not alwaysShown then
        self.deathOverlay:Hide();
    else
        self.deathOverlay:Show();
    end
end

-------------------------------------------------------------------------

function ArenaIcon:Create(parent, size, skipDeath)
    -- Create frame and apply mixin
    local frame = CreateFrame("Frame", "ArenaIconFrame", parent);
    Mixin(frame, ArenaIconMixin);

    -- Initialize the mixin
    frame:Initialize(size, skipDeath);

    return frame;
end