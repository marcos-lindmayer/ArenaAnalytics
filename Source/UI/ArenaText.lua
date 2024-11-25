local _, ArenaAnalytics = ...; -- Addon Namespace
local ArenaText = ArenaAnalytics.ArenaText;

-- Local module aliases
local UI = ArenaAnalytics.UI;

-------------------------------------------------------------------------

local CustomTextMixin = {};
local L = {};

function UI:UpdateLocalization()
    L = {}; -- TODO: Get current localization
end

local DummyFontString = UIParent:CreateFontString();
local DefaultFont = DummyFontString:GetFont();

local function GetFontForText(text)
    if(not text) then
        return DefaultFont;
    end

    DummyFontString:SetText(text);
    local font = DummyFontString:GetFont();
    return font;
end

function CustomTextMixin:AssignText(text)
    -- Map localization key to a string
    local localizedText = L[key] or key -- Fallback to the key itself if not found
    if ... then
        localizedText = localizedText:format(...) -- Format with additional arguments
    end

    -- Update font (if needed)
    self:UpdateFont(text);

    -- Set the text on the font string
    self:SetText(text or "");
end

function CustomTextMixin:SetLocalizedText(key)
    local text = "";
    if(L and key) then
        text = L[key];
        ArenaAnalytics:LogWarning("Missing localized string for key:", key); -- Add current AA locale to this.
    end

    CustomTextMixin:AssignText(text);
end

function CustomTextMixin:UpdateFont(text)
    -- Example: Adjust the font based on the text length (customize as needed)
    local _, fontSize, fontFlags = self:GetFont();
    local font = GetFontForText(text);

    -- Update font size? (Store desired size to avoid repeat change issues)

    self:SetFont(font, fontSize, fontFlags);
end

function CustomTextMixin:SetFontSize(size)
    local fontPath, fontSize, fontFlags = self:GetFont();
    self:SetFont(fontPath, size or fontSize or 12, fontFlags);
end

function CustomTextMixin:SetBaseColor(r, g, b, a)
    self.baseColor = {r, g, b, a}
    self:SetTextColor(r, g, b, a) -- Apply the base color initially
end

function CustomTextMixin:ApplyColorFormatting(r, g, b, a)
    -- Use the base color as a fallback
    local baseColor = self.baseColor or {1, 1, 1, 1}
    self:SetTextColor(r or baseColor[1], g or baseColor[2], b or baseColor[3], a or baseColor[4])
end

function CustomTextMixin:SetStyle(style)
    -- Adjust color based on text type
end

-------------------------------------------------------------------------

function ArenaText:Create(parent, name, drawLayer, templateName)
    assert(parent, "Attempted to create text without a valid parent.");

    drawLayer = drawLayer or "OVERLAY";
    templateName = templateName or "GameFontNormal";

    local fontString  = parent:CreateFontString(name, drawLayer, templateName);
    Mixin(fontString, CustomTextMixin);
    return fontString;
end