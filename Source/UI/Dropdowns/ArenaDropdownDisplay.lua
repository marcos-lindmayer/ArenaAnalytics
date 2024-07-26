local _, ArenaAnalytics = ...; -- Addon Namespace
local Dropdown = ArenaAnalytics.Dropdown;

-- Setup local subclass
local Display = Dropdown.Display;
Display.__index = Display

-- Local module aliases
local Options = ArenaAnalytics.Options;
local Constants = ArenaAnalytics.Constants;
local ArenaIcon = ArenaAnalytics.ArenaIcon;

-------------------------------------------------------------------------

function Display:Create(parent, displayFunc)
    assert(parent);
    assert(parent.GetCheckboxWidth, "Dropdown Display parent must include GetCheckboxWidth()!");
    assert(parent.GetArrowWidth, "Dropdown Display parent must include GetArrowWidth()!");
    
    local self = setmetatable({}, Display);

    self.parent = parent;
    self.name = parent:GetName() .. "_Display";
    
    self.displayFunc = displayFunc;
    self.frames = {}

    self.padding = 0;
    
    return self;
end

function Display:Refresh()
    self:Reset();
    
    if(type(self.displayFunc) == "function") then
        self.displayFunc(self.parent, self);
    else
        Display.SetText(self.parent, self)
    end
end

function Display:SetDisplayFunc(displayFunc, skipRefresh)
    self.displayFunc = displayFunc;

    if(not skipRefresh) then
        self:Refresh();
    end
end

function Display:AddFrame(frame, alignment, offsetX)
    if(self.frames == nil) then
        self.frames = {};
    end

    assert(frame);

    offsetX = tonumber(offsetX) or 0;

    if(alignment == "LEFT") then
        offsetX = offsetX + self.parent:GetCheckboxWidth();
    elseif(Alignment == "RIGHT") then
        offsetX = offsetX - self.parent:GetArrowWidth()
    else -- Assign default value, in case it wasn't already set
        alignment = self.parent.alignment or "CENTER";
    end

    frame:SetParent(self.parent:GetFrame());
    frame:SetPoint(alignment, self.parent:GetFrame(), offsetX, 0);
    frame:Show();

    tinsert(self.frames, frame);
end

function Display:Reset()
    if(self.frames) then
        for i=#self.frames, 1, -1 do
            local frame = self.frames[i];
            if(frame) then
                frame:Hide();
                self.frames[i] = nil;
            end
        end
    end
    self.frames = {};
end

function Display:SetPadding(padding)
    self.padding = padding;
end

function Display:GetName()
    return self.name;
end

function Display:GetWidth()
    local width = self.padding;

    for _,frame in ipairs(self.frames) do
        width = width + frame:GetWidth();
    end

    return width;
end

-------------------------------------------------------------------------
-- Simple Text Display

function Display.SetText(dropdownContext, display)
    assert(dropdownContext and display);
    display:Reset();

    local label = Dropdown:RetrieveValue(dropdownContext.label, dropdownContext);

    local fontString = dropdownContext:GetFrame():CreateFontString(nil, "OVERLAY");
    fontString:SetFont("Fonts\\FRIZQT__.TTF", fontSize or 12, "");
    fontString:SetText(label);

    local offsetX = 0;

    if(dropdownContext.alignment) then
        local desiredPadding = 3;

        if(dropdownContext.alignment == "LEFT") then
            offsetX = desiredPadding;
        elseif(dropdownContext.alignment == "RIGHT") then
            offsetX = -desiredPadding;
        end
    end

    display:AddFrame(fontString, dropdownContext.alignment, offsetX);
end


-------------------------------------------------------------------------
-- Comp Display Function

function Display.SetComp(dropdownContext, display)
    assert(dropdownContext and display);
    display:Reset();
    
    local comp = Dropdown:RetrieveValue(dropdownContext.label, dropdownContext);

    local padding = 1;
    
    -- Create container
    local containerFrame = CreateFrame("Frame", display:GetName() .. "CompContainer", dropdownContext:GetFrame());
    containerFrame:SetSize(10, 26);
    
    local totalWidth = 0;
    local offsetX = 0;

    local compData = ArenaAnalytics:GetCurrentCompData(dropdownContext.key, comp) or {}

    -- Construct the container contents
    if(comp == "All") then
        containerFrame.text = ArenaAnalyticsCreateText(containerFrame, "LEFT", containerFrame, "LEFT", 0, 0, comp, 12);
        containerFrame.text:SetPoint("LEFT", containerFrame, "LEFT", 0, 0);
        
        local width = containerFrame.text:GetWidth() 
        totalWidth = totalWidth + width;
    else
        -- Get data
        local played = tonumber(compData.played);
        local winrate = tonumber(compData.winrate);
        
        local lastFrame = nil
        
        -- Add played text
        local playedPrefix = played and (played .. " ") or "|cffff0000" .. "0  " .. "|r";
        containerFrame.played = ArenaAnalyticsCreateText(containerFrame, "LEFT", containerFrame, "LEFT", 0, 0, playedPrefix, 11);
        totalWidth = totalWidth + containerFrame.played:GetWidth() + padding;
        
        lastFrame = containerFrame.played;
        
        -- Add each player spec icon
        for specID in comp:gmatch("([^|]+)") do
            local class, spec = Constants:GetClassAndSpec(specID);
            local iconFrame = ArenaIcon:Create(containerFrame, class, spec, 25);
            iconFrame:SetPoint("LEFT", lastFrame, "RIGHT", padding, 0);
            
            lastFrame = iconFrame;
            totalWidth = totalWidth + iconFrame:GetWidth() + padding;
        end
        
        -- TODO: Add played text
        local winrateSuffix = winrate and (" " .. winrate .. "%") or "|cffff0000" .. "  0%" .. "|r";
        containerFrame.winrate = ArenaAnalyticsCreateText(lastFrame, "LEFT", lastFrame, "RIGHT", 0, 0, winrateSuffix, 11);
        totalWidth = totalWidth + containerFrame.winrate:GetWidth() + padding;
        lastFrame = containerFrame.winrate;
        
        -- Calculate alignment offset
        local prefixWidth = containerFrame.played:GetWidth();
        local suffixWidth = containerFrame.winrate:GetWidth();
        offsetX = offsetX + (suffixWidth - prefixWidth) / 2;
    end

    -- Average MMR
    if(Options:Get("compDisplayAverageMmr")) then        
        local mmr = tonumber(compData.mmr);
        if(mmr) then
            local averageMMR = mmr and "|cffcccccc" .. mmr .. "|r" or ""

            local mmrText = ArenaAnalyticsCreateText(dropdownContext:GetFrame(), "RIGHT", dropdownContext:GetFrame(), "RIGHT", -5, 0, averageMMR, 8.5);
            display:AddFrame(mmrText, "RIGHT", -7);
        end

        -- Move off center to make room for mmr
        totalWidth = totalWidth + 7;
    end

    containerFrame:SetWidth(totalWidth);

    -- TODO: Remove TEMP background
    containerFrame.background = containerFrame:CreateTexture();
    containerFrame.background:SetPoint("CENTER")
    containerFrame.background:SetSize(containerFrame:GetWidth(), containerFrame:GetHeight());
    containerFrame.background:SetColorTexture(1, 0, 0, 0);

    display:AddFrame(containerFrame, "CENTER", offsetX);
end