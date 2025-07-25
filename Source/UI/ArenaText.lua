local _, ArenaAnalytics = ...; -- Addon Namespace
local ArenaText = ArenaAnalytics.ArenaText;
ArenaText.__index = ArenaText

-- Local module aliases
local TablePool = ArenaAnalytics.TablePool;
local ArenaID = ArenaAnalytics.ArenaID;
local Localization = ArenaAnalytics.Localization;
local Lookup = ArenaAnalytics.Lookup;
local Helpers = ArenaAnalytics.Helpers;
local Colors = ArenaAnalytics.Colors;
local Debug = ArenaAnalytics.Debug;

-------------------------------------------------------------------------
-- Create New Instance

-- function ArenaAnalyticsCreateText(parent, anchor, relativeFrame, relPoint, xOff, yOff, text, size)

function ArenaText:CreateInline(parent, text, size, color, point, relativeFrame, relPoint, xOffset, yOffset)
    if(not parent) then
        Debug:LogWarning("ArenaText:CreateInline called without parent.");
        return;
    end

    -- Clean up anchor with defaults
    return ArenaText:Create({
        parent = parent,
        anchor = { point, relativeFrame or parent, relPoint, xOffset, yOffset },
        text = text,
        size = size,
        color = color,
    });
end

function ArenaText:Create(params)
    assert(params and params.parent, "ArenaText:Create requires a 'parent' frame.");

    local instance = setmetatable(TablePool:Acquire(), ArenaText);

    -- Initialize tag table
    instance.tags = TablePool:Acquire();

    -- Font string creation
    local fontString = params.parent:CreateFontString(nil, params.layer or "OVERLAY", params.fontTemplate or "GameFontNormal");
    instance.fontString = fontString;

    -- Optional font size
    instance.size = params.size or 12;

    -- Optional anchor point setup
    if(type(params.anchor) == "table") then
        fontString:ClearAllPoints();

        local point = params.anchor[1] or "TOPLEFT";
        local relFrame = params.anchor[2] or params.parent;
        local relPoint = params.anchor[3] or point;
        local xOffset = params.anchor[4] or 0;
        local yOffset = params.anchor[5] or 0;
        fontString:SetPoint(point, relFrame, relPoint, xOffset, yOffset);
    end

    -- Optional width and justification
    if(params.width) then
        fontString:SetWidth(params.width);
    end
    if(params.justifyH) then
        fontString:SetJustifyH(params.justifyH);
    end
    if(params.justifyV) then
        fontString:SetJustifyV(params.justifyV);
    end

    -- Optional initial text
    if(params.text) then
        instance:SetText(params.text);
    end

    -- Optional initial color
    if(params.color) then
        instance:SetColor(params.color);
    end

    ArenaText:MarkDirty(instance); -- Refresh next frame, allowing batched setters with initial setup (Experiment)
    ArenaText:Register(instance);
    return instance;
end

-------------------------------------------------------------------------
-- Statics

local registeredWrappers = {};
local dirtyWrappers = {};

function ArenaText:Register(wrapper)
    assert(wrapper and wrapper.Refresh);

    if(registeredWrappers[wrapper]) then
        Debug:LogWarning("Duplicate wrapper registration rejected.");
        return;
    end

    registeredWrappers[wrapper] = true; -- TODO: Consider if we want more specific registration, like level of refresh to respect?
end

function ArenaText:Unregister(wrapper)
    if(not wrapper) then
        return;
    end

    registeredWrappers[wrapper] = nil;
end


function ArenaText:RefreshAll()
    local pendingUnregister = TablePool:Acquire(); -- Pending unregister

    for wrapper in pairs(registeredWrappers) do
        if(wrapper) then
            if(type(wrapper.Refresh) == "function") then
                wrapper:Refresh();
            else
                tinsert(pendingUnregister, wrapper);
            end
        end
    end

    for i=#pendingUnregister, 1, -1 do
        local wrapper = pendingUnregister[i];
        if(wrapper) then
            registeredWrappers[wrapper] = nil;
        end
    end
end


function ArenaText:MarkDirty(wrapper)
    assert(wrapper);

    if(dirtyWrappers[wrapper] or wrapper.isDirty) then
        return;
    end

    local isFirstDirty = (next(dirtyWrappers) == nil);
    dirtyWrappers[wrapper] = true;
    wrapper.isDirty = true;

    if(isFirstDirty) then
        C_Timer.After(0, ArenaText.RefreshAllDirty);
    end
end

function ArenaText:RefreshAllDirty()
    for wrapper in pairs(dirtyWrappers) do
        if(wrapper and wrapper.Refresh and wrapper.isDirty) then
            wrapper:Refresh();
        end
    end

    wipe(dirtyWrappers);
end

-------------------------------------------------------------------------
-- Set Text

function ArenaText:SetText(value, ...)
    local valueType = type(value);

    if(valueType == "function") then
        self:SetTextFunc(value, ...);
    elseif(valueType == "string") then
        if(Localization:IsValidToken(value, ...)) then
            self:SetTextToken(value, ...);
        else
            self:SetTextRaw(value, ...);
        end
    else
        Debug:LogError("Invalid value provided for ArenaText:SetText:", valueType, value);
    end
end

function ArenaText:SetTextRaw(text, ...)
    self.rawText = text;
    self.textToken = nil;
    self.textFunc = nil;

    self:_UpdateVarArgs(...);

    ArenaText:MarkDirty(self);
end

function ArenaText:SetTextToken(token, ...)
    self.textToken = token;
    self.textFunc = nil;
    self.rawText = nil;

    self:_UpdateVarArgs(...);

    ArenaText:MarkDirty(self);
end

function ArenaText:SetTextFunc(textFunc, ...)
    self.textFunc = textFunc;
    self.textToken = nil;
    self.rawText = nil;

    self:_UpdateVarArgs(...);

    ArenaText:MarkDirty(self);
end

-------------------------------------------------------------------------
-- Color

function ArenaText:SetColor(color)
    if(type(color) == "func") then
        self:SetColorFunc(color);
    elseif(Colors:IsValidKey(color)) then
        self:SetColorKey(color);
    else
        self:SetColorRaw(color);
    end
end

function ArenaText:SetColorRaw(color)
    self.explicitColor = color;
    self.colorKey = nil;
    self.colorFunc = nil;
    ArenaText:MarkDirty(self);
end

function ArenaText:SetColorKey(key)
    self.colorKey = key;
    self.colorFunc = nil;
    self.explicitColor = nil;
    ArenaText:MarkDirty(self);
end

function ArenaText:SetColorFunc(func)
    self.colorFunc = func;
    self.colorKey = nil;
    self.explicitColor = nil;
    ArenaText:MarkDirty(self);
end

-------------------------------------------------------------------------

function ArenaText:Refresh()
    self.isDirty = false;

    -- TODO: Refresh text, localization & color, at least.
    self:_ResolveColor();
    self:_ResolveText();

    self:_ApplyText();
end

function ArenaText:Clear()
    self.textToken = nil;
    self.textFunc = nil;
    self.rawText = "";

    self:_ApplyText();
end


function ArenaText:GetColor()
    return self.resolvedColor;
end

function ArenaText:GetText()
    return Colors:ColorText(self.resolvedText, self:GetColor());
end

-------------------------------------------------------------------------
-- Resolve text & color

function ArenaText:_UpdateVarArgs(...)
    local argCount = select('#', ...);
    if argCount > 0 then
        self.textArgs = {n = argCount, ...};
    else
        self.textArgs = nil;
    end
end

function ArenaText:_ResolveText()
    local baseText = nil;

    -- Resolve text
    if(self.textFunc) then
        baseText = tostring(self.textFunc()) or "";
    elseif(self.textToken) then
        baseText = Localization:GetTokenFallback(self.textToken, self.tags) or "";
    elseif(self.rawText) then
        baseText = self.rawText;
    else
        Debug:LogWarning("ArenaText:_ResolveText has no valid text.");
        baseText = "Missing";
    end

    if(baseText and self.textArgs) then
        baseText = string.format(baseText, unpack(self.textArgs, 1, self.textArgs.n));
    end

    self.resolvedText = baseText;
end

function ArenaText:_ResolveColor()
    -- Resolve color
    if(self.explicitColor) then
        self.resolvedColor = self.explicitColor;
    elseif(self.colorFunc) then
        local color = self.colorFunc();
        self.resolvedColor = Colors:Get(color) or color;
    elseif(self.colorKey) then
        self.resolvedColor = Colors:Get(self.colorKey);
    else
        self.resolvedColor = nil;
    end
end


local function GetFontForText(text)
    if not text or text == "" then
        return "Fonts\\FRIZQT__.TTF";
    end

    -- Check for Cyrillic characters
    if text:match("[\208-\209][\128-\191]") then
        return "Fonts\\FRIZQT___CYR.TTF";
    end

    -- Check for Korean characters (Hangul)
    if text:match("[\234-\237][\128-\191][\128-\191]") then
        return "Fonts\\2002.TTF";
    end

    -- Check for Chinese characters (CJK Unified Ideographs)
    if text:match("[\228-\233][\128-\191][\128-\191]") then
        -- Could be either simplified or traditional, default to simplified
        -- You might need additional logic here to distinguish between zhCN and zhTW
        return "Fonts\\ARKai_T.TTF";
    end

    -- Default to Western font for Latin characters and others
    return "Fonts\\FRIZQT__.TTF";
end

function ArenaText:_ApplyText()
    local size = self.size or 12;
    local text = self:GetText();

    self.fontString:SetText(text);

    -- local _, _, fontFlags = self.fontString:GetFont();
    self.fontString:SetFont(GetFontForText(text), size, "");
    self.fontString:Show();

    Debug:Log("_ApplyText:", self.fontString:GetText(), self.fontString:GetHeight());
end

-------------------------------------------------------------------------







-- TODO: Figure out if there's a more efficient and reliable way to handle this.
-- Create a hidden font string to get desired font for a text (hack)
--[[
    local fakeFontString = ArenaAnalyticsScrollFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
    fakeFontString:Hide();
    
    function ArenaText:GetFontForString(text)
        fakeFontString:SetText(text);
        return fakeFontString:GetFont();
    end
--]]