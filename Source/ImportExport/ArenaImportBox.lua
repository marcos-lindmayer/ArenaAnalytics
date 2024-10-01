local _, ArenaAnalytics = ...; -- Addon Namespace
local ImportBox = ArenaAnalytics.ImportBox;
ImportBox.__index = ImportBox;

-- Local module aliases
local Import = ArenaAnalytics.Import;

-------------------------------------------------------------------------
-- Import Box

local pasteBuffer, index = {}, 0;
local function onCharAdded(frame, c)
    if(ArenaAnalyticsScrollFrame.importDialogFrame == nil) then
        return;
    end

    if(frame:IsEnabled()) then
        frame:Disable();
        pasteBuffer, index = {}, 0;

        frame.owner:SetText("");

        C_Timer.After(0, function()
            Import:SetPastedInput(pasteBuffer);

            if(#Import.raw[1] > 0) then
                frame:Enable();
            end

            pasteBuffer, index = {}, 0;

            -- Update text:
            frame.owner:SetText(Import:GetSourceName() .. " import detected...");
    
        end);
    end

    index = index + 1;
    pasteBuffer[index] = c;
end

function ImportBox:Create(parent, frameName, width, height)
    assert(parent, "Invalid parent when creating ImportBox.");
    local self = setmetatable({}, ImportBox);

    self.frame = CreateFrame("EditBox", frameName, parent, "InputBoxTemplate")
    self.frame:SetFrameStrata("DIALOG");
    self.frame:SetFrameLevel(501)
    self.frame:SetSize(width, height);
    self.frame:SetAutoFocus(false);
    self.frame:SetMaxBytes(50);

    self.frame:SetScript("OnChar", onCharAdded);

    self.frame:SetScript("OnEnterPressed", function(frame)
        frame:ClearFocus();
    end);

    self.frame:SetScript("OnEscapePressed", function(frame)
        frame:ClearFocus();
    end);

    self.frame:SetScript("OnEditFocusGained", function(frame)
        frame:HighlightText();
    end);

    -- Clear text
    self.frame:SetScript("OnHide", function(frame)
        -- Cleanup
        self:SetText("");

        -- Reset import, unless it's currently importing.
        Import:Reset();
    end);

    self.frame.owner = self;
    return self;
end

function ImportBox:SetText(text)
    assert(self, "SetText called on non-instanced ImportBox.");
    self.frame:SetScript("OnChar", nil);
    self.frame:SetText(text or "");
    self.frame:SetScript("OnChar", onCharAdded);
end

function ImportBox:Clear()
    assert(self, "Clear called on non-instanced ImportBox.");
    self:SetText("");
end

function ImportBox:SetPoint(...)
    assert(self, "SetPoint called on non-instanced ImportBox.");
    self.frame:SetPoint(...);
end