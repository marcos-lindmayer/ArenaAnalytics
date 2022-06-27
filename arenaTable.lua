--[[ 
    CODE NOT YET COMMENTED
    (sorry)
 ]]

local _, core = ...;

local currentFilters = {
    ["map"] = "All", 
    ["bracket"] = "All", 
    ["comps"] = "All",
    ["comps2v2"] = "All", 
    ["comps3v3"] = "All", 
    ["comps5v5"] = "All",
    ["skirmishIsChecked"] = true
};

local isCompFilterOn;
local dropdownCounter = 1;
local filterComps2v2_opts, filterComps3v3_opts, filterComps5v5_opts

HybridScrollMixin = {};
core.arenaTable = HybridScrollMixin;

function core.arenaTable:Toggle()
    if not ArenaAnalyticsScrollFrame:IsShown() then   
        ArenaAnalyticsScrollFrame:Show();
    else
        ArenaAnalyticsScrollFrame:Hide();
    end
end

function core.arenaTable:CreateButton(point, relativeFrame, relativePoint, xOffset, yOffset, text)
	local btn = CreateFrame("Button", nil, relativeFrame, "UIServiceButtonTemplate");
	btn:SetPoint(point, relativeFrame, relativePoint, xOffset, yOffset);
	btn:SetSize(120, 25);
	btn:SetText(text);
    btn.money:Hide();
	btn:SetNormalFontObject("GameFontHighlight");
	btn:SetHighlightFontObject("GameFontHighlight");
	return btn;
end

local function createDropdown(opts, dropdownCounter)
    local dropdownTable = {};
    dropdownCounter = dropdownCounter and dropdownCounter or ""
    local dropdown_name = dropdownCounter ~= nil and '$parent_' .. opts['name'] .. '_dropdown' .. dropdownCounter 
    or '$parent_' .. opts['name'] .. '_dropdown';
    local menu_items = opts['items'] or {};
    local hasIcon = opts["hasIcon"];
    local title_text = opts['title'] or '';
    local dropdown_width = 0;
    local default_val = opts['defaultVal'] or '';
    local change_func = opts['changeFunc'] or function (dropdown_val) end;

    local dropdown = CreateFrame("Frame", dropdown_name, opts['parent'], 'UIDropDownMenuTemplate')
    local dd_title = dropdown:CreateFontString(dropdown, 'OVERLAY', 'GameFontNormal')
    dd_title:SetPoint("TOPLEFT", 0, 10)


    for _, item in pairs(menu_items) do -- Sets the dropdown width to the largest item string width.
        dd_title:SetText(item)
        local text_width = dd_title:GetStringWidth() + 20
        if text_width > dropdown_width then
            dropdown_width = text_width
        end
    end
    UIDropDownMenu_SetWidth(dropdown, dropdown_width)
    UIDropDownMenu_SetText(dropdown, default_val)
    dd_title:SetText(title_text)
    
    dropdownTable.dd_title = dd_title;


    -- Custom dropdown settings --TODO create own template
    dropdown.Left:SetTexture(nil);
    dropdown.Middle:SetTexture(nil);
    dropdown.Right:SetTexture(nil);
    dropdown.Left:SetColorTexture(0, 0, 0, 0);
    dropdown.Left:SetSize(dropdown_width, 25)
    dropdown.Left:ClearAllPoints();
    dropdown.Left:SetPoint("TOPLEFT", dropdown, "LEFT", 0, 15)
    dropdown.Button:ClearAllPoints();
    dropdown.Button:SetPoint("TOPLEFT", dropdown, "LEFT", 0, 15);
    dropdown.Button:SetSize(dropdown_width,25);
    dropdown.Button.NormalTexture:SetTexture([[Interface\AddOns\ArenaAnalytics\icon\btnborder]]);
    dropdown.Button.NormalTexture:SetTexCoord(0.00195313, 0.57421875, 0.75390625, 0.84570313);
    dropdown.Button.NormalTexture:SetSize(dropdown_width,25);
    dropdown.Button.NormalTexture:ClearAllPoints();
    dropdown.Button.NormalTexture:SetPoint("TOPLEFT", dropdown, "LEFT", 0, 15);
    dropdown.Button.DisabledTexture:SetTexture([[Interface\AddOns\ArenaAnalytics\icon\btnborder]]);
    dropdown.Button.DisabledTexture:SetTexCoord(0.00195313, 0.57421875, 0.75390625, 0.84570313);
    dropdown.Button.DisabledTexture:SetSize(dropdown_width, 25);
    dropdown.Button.DisabledTexture:ClearAllPoints();
    dropdown.Button.DisabledTexture:SetPoint("TOPLEFT", dropdown, "LEFT", 0, 15);
    dropdown.Button.HighlightTexture:SetTexture([[Interface\ClassTrainerFrame\TrainerTextures]]);
    dropdown.Button.HighlightTexture:SetTexCoord(0.00195313, 0.57421875, 0.75390625, 0.84570313);
    dropdown.Button.HighlightTexture:SetSize(dropdown_width, 25);
    dropdown.Button.HighlightTexture:ClearAllPoints();
    dropdown.Button.HighlightTexture:SetPoint("TOPLEFT", dropdown, "LEFT", 0, 15);
    dropdown.Button.PushedTexture:SetTexture([[Interface\ClassTrainerFrame\TrainerTextures]]);
    dropdown.Button.PushedTexture:SetTexCoord(0.00195313, 0.57421875, 0.84960938, 0.94140625);
    dropdown.Button.PushedTexture:SetSize(dropdown_width, 25);
    dropdown.Button.PushedTexture:ClearAllPoints();
    dropdown.Button.PushedTexture:SetPoint("TOPLEFT", dropdown, "LEFT", 0, 15);
    dropdown.Text:ClearAllPoints();
    dropdown.Text:SetJustifyH("CENTER")
    local textWidth = dropdown.Text:GetWidth()
    dropdown.Text:SetPoint("LEFT", dropdown, "LEFT", ((dropdown_width / 2) - (textWidth / 2)), 2)

    UIDropDownMenu_Initialize(dropdown, function(self, level, _)
        local info = UIDropDownMenu_CreateInfo()
        for key, val in pairs(menu_items) do

            info.text = val
            info.tooltipTitle = "";

            if(hasIcon and info.text ~= "All") then
                local classInlineIcons = ""
                for arenaClass in string.gmatch(info.text, "([^%s]+)") do
                    local arenaIconPath = ArenaAnalyticsGetClassIcon(arenaClass);
                    local singleIcon = IconClass(arenaIconPath, 0, 0, 0, 0, 0, 0, 25, 25);
                    classInlineIcons = classInlineIcons .. singleIcon:GetIconString() .. " ";
                    info.tooltipTitle = info.tooltipTitle .. arenaClass .. " "
                end
                info.tooltipTitle = info.tooltipTitle:sub(1, -2)
                info.text = classInlineIcons;
                info.tooltipOnButton = {nil, 1};
                info.justifyH = "CENTER";
            end

            info.checked = false
            info.menuList= key
            info.hasArrow = false
            info.func = function(b)
                UIDropDownMenu_SetSelectedValue(dropdown, b.value, b.value)
                UIDropDownMenu_SetText(dropdown, b.value)
                b.checked = true
                change_func(dropdown, (hasIcon and b.value ~= "All") and b.tooltipTitle or b.value)
            end

            UIDropDownMenu_AddButton(info)
        end
    end)

    dropdownTable.dropdownFrame = dropdown;

    return dropdownTable
end

local function getCsvFromDB()
    local CSVString = "date,map,duration,won,isRanked,team1Name,team2Name,team3Name,team4Name,team5Name,rating,mmr," .. 
    "enemyTeam1Name,enemyTeam2Name,enemyTeam3Name,enemyTeam4Name,enemyTeam5Name,enemyRating, enemyMMR" .. "\n";
    -- Get all arenas ordered by date
    local allArenas = {}
    for arenaN2v2 = 1, #ArenaAnalyticsDB["2v2"] do
        table.insert(allArenas, ArenaAnalyticsDB["2v2"][arenaN2v2]);
    end
    for arenaN3v3 = 1, #ArenaAnalyticsDB["3v3"] do
        table.insert(allArenas, ArenaAnalyticsDB["3v3"][arenaN3v3]);
    end
    for arenaN5v5 = 1, #ArenaAnalyticsDB["5v5"] do
        table.insert(allArenas, ArenaAnalyticsDB["5v5"][arenaN5v5]);
    end
    table.sort(allArenas, function (k1,k2)
        return k1["date"] > k2["date"];
    end)

    for arenaN = 1, #allArenas do
        CSVString = CSVString 
        .. allArenas[arenaN]["date"] .. ","
        .. allArenas[arenaN]["map"] .. ","
        .. allArenas[arenaN]["duration"] .. ","
        .. (allArenas[arenaN]["won"] and "yes" or "no") .. ","
        .. (allArenas[arenaN]["isRanked"] and "yes" or "no") .. ","
        .. allArenas[arenaN]["team"][1]["name"] .. ","
        .. (allArenas[arenaN]["team"][2] and allArenas[arenaN]["team"][2]["name"] or "") .. ","
        .. (allArenas[arenaN]["team"][3] and allArenas[arenaN]["team"][3]["name"] or "") .. ","
        .. (allArenas[arenaN]["team"][4] and allArenas[arenaN]["team"][4]["name"] or "") .. ","
        .. (allArenas[arenaN]["team"][5] and allArenas[arenaN]["team"][5]["name"] or "") .. ","
        .. allArenas[arenaN]["rating"] .. ","
        .. allArenas[arenaN]["mmr"] .. ","
        .. (allArenas[arenaN]["enemyTeam"][1] and allArenas[arenaN]["enemyTeam"][1]["name"] or "") .. ","
        .. (allArenas[arenaN]["enemyTeam"][2] and allArenas[arenaN]["enemyTeam"][2]["name"] or "") .. ","
        .. (allArenas[arenaN]["enemyTeam"][3] and allArenas[arenaN]["enemyTeam"][3]["name"] or "") .. ","
        .. (allArenas[arenaN]["enemyTeam"][4] and allArenas[arenaN]["enemyTeam"][4]["name"] or "") .. ","
        .. (allArenas[arenaN]["enemyTeam"][5] and allArenas[arenaN]["enemyTeam"][5]["name"] or "") .. ","
        .. allArenas[arenaN]["enemyRating"] .. ","
        .. allArenas[arenaN]["enemyMmr"] .. ","
        CSVString = CSVString .. "\n";
    end
    return CSVString;
end

local function exportDB() 
    if not ArenaAnalyticsScrollFrame.exportFrameContainer:IsShown() then   
        ArenaAnalyticsScrollFrame.exportFrameContainer:Show();
        ArenaAnalyticsScrollFrame.exportFrame:SetText(getCsvFromDB())
        ArenaAnalyticsScrollFrame.exportFrame:HighlightText()
    else
        ArenaAnalyticsScrollFrame.exportFrameContainer:Hide();
    end
end

local function getPlayerPlayedComps(bracket)
    local playedComps = {"All"};
    local arenaSize = tonumber(string.sub(bracket, 1, 1))
    if (bracket == nil) then
        return playedComps;
    else
        for arenaNumber = 1, #ArenaAnalyticsDB[bracket] do   
            if (#ArenaAnalyticsDB[bracket][arenaNumber]["comp"] == arenaSize) then
                table.sort(ArenaAnalyticsDB[bracket][arenaNumber]["comp"], function(a,b)
                    local prioA = a == UnitClass("player") and 1 or 2
                    local prioB = b == UnitClass("player") and 1 or 2
                    return prioA < prioB or (prioA == prioB and a < b)
                end)
                local compString = table.concat(ArenaAnalyticsDB[bracket][arenaNumber]["comp"], " ");
                if (not tContains(playedComps, compString)) then
                    table.insert(playedComps, compString)
                end
            end
        end
    end
    return playedComps;
end

local function createText(anchor, refFrame, relPoint, xOff, yOff, text)
    local fontString = ArenaAnalyticsScrollFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    fontString:SetPoint(anchor, refFrame, relPoint, xOff, yOff);
    fontString:SetText(text);
    return fontString
end

local function createExportFrame()
    ArenaAnalyticsScrollFrame.exportFrameContainer = CreateFrame("Frame", nil, ArenaAnalyticsScrollFrame, "BasicFrameTemplateWithInset")
	ArenaAnalyticsScrollFrame.exportFrameContainer:SetPoint("TOP", ArenaAnalyticsScrollFrame, "TOP", 0, 200);
	ArenaAnalyticsScrollFrame.exportFrameContainer:SetSize(510, 150);
    ArenaAnalyticsScrollFrame.exportFrameScrollBg = ArenaAnalyticsScrollFrame.exportFrameContainer:CreateTexture()
	ArenaAnalyticsScrollFrame.exportFrameScrollBg:SetSize(500, 100);
	ArenaAnalyticsScrollFrame.exportFrameScrollBg:SetPoint("CENTER", ArenaAnalyticsScrollFrame.exportFrameScroll, "CENTER");
    ArenaAnalyticsScrollFrame.exportFrameScroll = CreateFrame("ScrollFrame", "exportFrameScroll", ArenaAnalyticsScrollFrame.exportFrameContainer, "UIPanelScrollFrameTemplate");
	ArenaAnalyticsScrollFrame.exportFrameScroll:SetPoint("CENTER", ArenaAnalyticsScrollFrame.exportFrameContainer, "CENTER");
	ArenaAnalyticsScrollFrame.exportFrameScroll:SetSize(500, 100);
    ArenaAnalyticsScrollFrame.exportFrameScroll.ScrollBar:Hide();
    ArenaAnalyticsScrollFrame.exportFrame = CreateFrame("EditBox", "exportFrameScroll", nil, "BackdropTemplate");
    ArenaAnalyticsScrollFrame.exportFrame:SetFrameStrata("TOOLTIP");
    ArenaAnalyticsScrollFrame.exportFrameScroll:SetScrollChild(ArenaAnalyticsScrollFrame.exportFrame);
    ArenaAnalyticsScrollFrame.exportFrame:SetWidth(InterfaceOptionsFramePanelContainer:GetWidth()-18);
    ArenaAnalyticsScrollFrame.exportFrame:SetMultiLine(true);
    ArenaAnalyticsScrollFrame.exportFrame:SetAutoFocus(false);
    ArenaAnalyticsScrollFrame.exportFrame:SetCursorPosition(0);
    ArenaAnalyticsScrollFrame.exportFrame:SetFont("Fonts\\FRIZQT__.TTF", 10);
    ArenaAnalyticsScrollFrame.exportFrame:SetJustifyH("LEFT");
    ArenaAnalyticsScrollFrame.exportFrame:SetJustifyV("CENTER");
    ArenaAnalyticsScrollFrame.exportFrame:HighlightText();
    ArenaAnalyticsScrollFrame.exportFrameContainer:Hide();
end

function core.arenaTable:OnLoad()

    ArenaAnalyticsScrollFrame.ListScrollFrame.update = function() core.arenaTable:RefreshLayout(); end


    HybridScrollFrame_SetDoNotHideScrollBar(ArenaAnalyticsScrollFrame.ListScrollFrame, true);
    ArenaAnalyticsScrollFrame.Bg:SetTexture(nil)
    ArenaAnalyticsScrollFrame.Bg:SetColorTexture(0, 0, 0, 0.5)

	ArenaAnalyticsScrollFrame.title = ArenaAnalyticsScrollFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	ArenaAnalyticsScrollFrame.title:SetPoint("CENTER", ArenaAnalyticsScrollFrame.TitleBg, "CENTER", 0, 0);
	ArenaAnalyticsScrollFrame.title:SetText("Arena Analytics");
    ArenaAnalyticsScrollFrame.TitleBg:SetColorTexture(0,0,0,0.8)

    ArenaAnalyticsScrollFrame.teamBg = CreateFrame("Frame", nil, ArenaAnalyticsScrollFrame)
	ArenaAnalyticsScrollFrame.teamBg:SetPoint("TOPLEFT", ArenaAnalyticsScrollFrame, "TOPLEFT", 340, -90);
    ArenaAnalyticsScrollFrame.teamBg:SetFrameStrata("LOW");
    ArenaAnalyticsScrollFrame.teamBgT = ArenaAnalyticsScrollFrame.teamBg:CreateTexture()
    ArenaAnalyticsScrollFrame.teamBgT:SetColorTexture(0, 0, 0, 0.3)
	ArenaAnalyticsScrollFrame.teamBgT:SetSize(270, 420);
	ArenaAnalyticsScrollFrame.teamBg:SetSize(270, 420);
	ArenaAnalyticsScrollFrame.teamBgT:SetPoint("CENTER", ArenaAnalyticsScrollFrame.teamBg, "CENTER");


    ArenaAnalyticsScrollFrame.export = core.arenaTable:CreateButton("TOPLEFT", ArenaAnalyticsScrollFrame, "TOPLEFT", 20, -35, "Export");
    ArenaAnalyticsScrollFrame.export:SetScript("OnClick", exportDB);

    -- Set export DB CSV frame layout
    createExportFrame();


    local arenaBracket_opts = {
        ['name']='Arena_Bracket',
        ['parent'] = ArenaAnalyticsScrollFrame,
        ['title']='Bracket',
        ['icon']= false,
        ['items'] = {'All' ,'2v2', '3v3', '5v5' },
        ['defaultVal'] ='All', 
        ['changeFunc'] = function (dropdown_frame, dropdown_val)
            currentFilters["bracket"] = dropdown_val;
            if (dropdown_val == "All") then
                -- TODO tidy this up
                UIDropDownMenu_DisableDropDown(ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame);
                ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame.tooltipFrame:Show()
                ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame.Text:Hide();
                ArenaAnalyticsScrollFrame.filterComps3v3.dropdownFrame.Text:Hide();
                ArenaAnalyticsScrollFrame.filterComps5v5.dropdownFrame.Text:Hide();
                ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame:Show();
                ArenaAnalyticsScrollFrame.filterComps3v3.dropdownFrame:Hide();
                ArenaAnalyticsScrollFrame.filterComps5v5.dropdownFrame:Hide();
            else
                UIDropDownMenu_EnableDropDown(ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame);
                ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame.tooltipFrame:Hide()
            end
            if (dropdown_val == "2v2") then
                ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame.Text:Show();
                ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame:Show();
                ArenaAnalyticsScrollFrame.filterComps3v3.dropdownFrame:Hide();
                ArenaAnalyticsScrollFrame.filterComps5v5.dropdownFrame:Hide();
            elseif(dropdown_val == "3v3") then
                ArenaAnalyticsScrollFrame.filterComps3v3.dropdownFrame.Text:Show();
                ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame:Hide();
                ArenaAnalyticsScrollFrame.filterComps3v3.dropdownFrame:Show();
                ArenaAnalyticsScrollFrame.filterComps5v5.dropdownFrame:Hide();
            elseif(dropdown_val == "5v5") then
                ArenaAnalyticsScrollFrame.filterComps5v5.dropdownFrame.Text:Show();
                ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame:Hide();
                ArenaAnalyticsScrollFrame.filterComps3v3.dropdownFrame:Hide();
                ArenaAnalyticsScrollFrame.filterComps5v5.dropdownFrame:Show();

            end
            core.arenaTable:RefreshLayout();
        end
    }

    ArenaAnalyticsScrollFrame.arenaTypeMenu = createDropdown(arenaBracket_opts, nil)
    ArenaAnalyticsScrollFrame.arenaTypeMenu.dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.export, "RIGHT", 15, -3);

    local filterMap_opts = {
        ['name']='Filter_Map',
        ['parent'] = ArenaAnalyticsScrollFrame,
        ['title']='Map',
        ['icon']= false,
        ['items'] = {'All' ,'Nagrand Arena' ,'Ruins of Lordaeron', 'Blade Edge Arena'},
        ['defaultVal'] ='All', 
        ['changeFunc'] = function (dropdown_frame, dropdown_val)
            currentFilters["map"] = dropdown_val;
            core.arenaTable:RefreshLayout();
        end
    }
    
    ArenaAnalyticsScrollFrame.filterMap = createDropdown(filterMap_opts)
    ArenaAnalyticsScrollFrame.filterMap.dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.arenaTypeMenu.dropdownFrame, "RIGHT", 0, 0);

    

    ArenaAnalyticsScrollFrame.skirmishToggle = CreateFrame("CheckButton", "ArenaAnalyticsScrollFrame_skirmishToggle", ArenaAnalyticsScrollFrame, "OptionsSmallCheckButtonTemplate");
    ArenaAnalyticsScrollFrame.skirmishToggle:SetPoint("TOPRIGHT", ArenaAnalyticsScrollFrame, "TOPRIGHT", -120, -40);
    ArenaAnalyticsScrollFrame_skirmishToggleText:SetText("Show Skirmish");
    ArenaAnalyticsScrollFrame.skirmishToggle:SetChecked(true);

    ArenaAnalyticsScrollFrame.skirmishToggle:SetScript("OnClick", 
        function()
            currentFilters["skirmishIsChecked"] = ArenaAnalyticsScrollFrame.skirmishToggle:GetChecked();
            core.arenaTable:RefreshLayout();
        end
    );


    ArenaAnalyticsScrollFrame.resetBtn = core.arenaTable:CreateButton("TOPLEFT", ArenaAnalyticsScrollFrame, "TOPLEFT", 0, 50, "Reset");
    ArenaAnalyticsScrollFrame.resetBtn:SetScript("OnClick", function (i) 
        ArenaAnalyticsDB = {}; 
        print("DB reset");
        core.arenaTable:RefreshLayout(); 
    end);
    

    -- Table headers
    ArenaAnalyticsScrollFrame.dateTitle = createText("TOPLEFT", ArenaAnalyticsScrollFrame.export, "TOPLEFT", 5, -40, "Date");
    ArenaAnalyticsScrollFrame.mapTitle = createText("TOPLEFT", ArenaAnalyticsScrollFrame.dateTitle, "TOPLEFT", 145, 0, "Map");
    ArenaAnalyticsScrollFrame.durationTitle = createText("TOPLEFT", ArenaAnalyticsScrollFrame.mapTitle, "TOPLEFT", 60, 0, "Duration");
    ArenaAnalyticsScrollFrame.teamTitle = createText("TOPLEFT", ArenaAnalyticsScrollFrame.durationTitle, "TOPLEFT", 120, 0, "Team");
    ArenaAnalyticsScrollFrame.ratingTitle = createText("TOPLEFT", ArenaAnalyticsScrollFrame.teamTitle, "TOPLEFT", 130, 0, "Rating");
    ArenaAnalyticsScrollFrame.mmrTitle = createText("TOPLEFT", ArenaAnalyticsScrollFrame.ratingTitle, "TOPLEFT", 85, 0, "MMR");
    ArenaAnalyticsScrollFrame.enemyTeamTitle = createText("TOPLEFT", ArenaAnalyticsScrollFrame.mmrTitle, "TOPLEFT", 70, 0, "Enemy Team");
    ArenaAnalyticsScrollFrame.enemyRatingTitle = createText("TOPLEFT", ArenaAnalyticsScrollFrame.enemyTeamTitle, "TOPLEFT", 140, 0, "Enemy Rating");
    ArenaAnalyticsScrollFrame.enemyMmrTitle = createText("TOPLEFT", ArenaAnalyticsScrollFrame.enemyRatingTitle, "TOPLEFT", 125, 0, "Enemy MMR");


    -- Recorded arena number and winrate
    ArenaAnalyticsScrollFrame.totalArenaNumber = createText("TOPLEFT", ArenaAnalyticsScrollFrame, "BOTTOMLEFT", 15, 30, "");
    ArenaAnalyticsScrollFrame.winrate = createText("TOPLEFT", ArenaAnalyticsScrollFrame.totalArenaNumber, "TOPRIGHT", 20, 0, "");


    -- Add esc to close frame
    _G["ArenaAnalyticsScrollFrame"] = ArenaAnalyticsScrollFrame 
    tinsert(UISpecialFrames, ArenaAnalyticsScrollFrame:GetName()) 

    -- Make frame draggable
    ArenaAnalyticsScrollFrame:SetMovable(true)
    ArenaAnalyticsScrollFrame:EnableMouse(true)
    ArenaAnalyticsScrollFrame:RegisterForDrag("LeftButton")
    ArenaAnalyticsScrollFrame:SetScript("OnDragStart", ArenaAnalyticsScrollFrame.StartMoving)
    ArenaAnalyticsScrollFrame:SetScript("OnDragStop", ArenaAnalyticsScrollFrame.StopMovingOrSizing)


    core.arenaTable:OnShow();
 
end

function core.arenaTable:OnShow()
    HybridScrollFrame_CreateButtons(ArenaAnalyticsScrollFrame.ListScrollFrame, "ArenaAnalyticsScrollListItem");
    core.arenaTable:RefreshLayout();
    ArenaAnalyticsScrollFrame:Hide();
end

function core.arenaTable:RemoveItem(index)
    table.remove(ArenaAnalyticsScrollFrame.items, index);
    core.arenaTable:RefreshLayout();
end

local function setClassTextureWithTooltip(teamIconsFrames, item, itemKey, button)
    --DevTools_Dump(teamIconsFrames)

    for teamIconIndex = 1, #teamIconsFrames do
        -- Reset textures
        if (teamIconsFrames[teamIconIndex].texture) then
            teamIconsFrames[teamIconIndex].texture:SetTexture(nil)
        else
            local teamTexture = teamIconsFrames[teamIconIndex]:CreateTexture();
            teamIconsFrames[teamIconIndex].texture = teamTexture
        end
        teamIconsFrames[teamIconIndex].texture:SetPoint("LEFT", teamIconsFrames[teamIconIndex] ,"RIGHT", -26, 0);
        teamIconsFrames[teamIconIndex].texture:SetTexture(item[itemKey][teamIconIndex] and item[itemKey][teamIconIndex]["classIcon"] or nil);
        teamIconsFrames[teamIconIndex].texture:SetSize(26,26)

        teamIconsFrames[teamIconIndex].tooltip = ""
        if (item[itemKey][teamIconIndex]) then
            local spec = string.len(item[itemKey][teamIconIndex]["spec"]) > 3 and " | " .. item[itemKey][teamIconIndex]["spec"] or ""
            teamIconsFrames[teamIconIndex].tooltip = item[itemKey][teamIconIndex]["name"] .. spec;
        end

    end
    return teamIconsFrames[#teamIconsFrames];
end

local function checkForFilterUpdate(bracket)
    local filterByBracketTable = {
        ["2v2"] = filterComps2v2_opts,
        ["3v3"] = filterComps3v3_opts,
        ["5v5"] = filterComps5v5_opts,
    }
    local frameByBracketTable = {
        ["2v2"] = ArenaAnalyticsScrollFrame.filterComps2v2,
        ["3v3"] = ArenaAnalyticsScrollFrame.filterComps3v3,
        ["5v5"] = ArenaAnalyticsScrollFrame.filterComps5v5,
    }
    if(#getPlayerPlayedComps(bracket) > #filterByBracketTable[bracket]['items']) then
        -- TODO FIX DYNAMIC COMP FILTER UPDATE
        --[[ dropdownCounter = dropdownCounter + 1;
        frameByBracketTable[bracket].dropdownFrame:Hide();
        frameByBracketTable[bracket] = {}
        frameByBracketTable[bracket] = createDropdown(filterByBracketTable[bracket], dropdownCounter);
        frameByBracketTable[bracket].dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.filterMap.dropdownFrame, "RIGHT", 0, 0);
        print("dropdownCounter: " .. dropdownCounter) ]]
    end
end

local function applyFilters(unfilteredDB)

    local filteredDB = {
        ["2v2"] = {},
        ["3v3"] = {},
        ["5v5"] = {},
    };

    --print("unfiltered")
    --DevTools_Dump(unfilteredDB);
    -- Filter map
    local arenaMaps = {{"Nagrand Arena","NA"}, {"Ruins of Lordaeron", "RoL"}, {"Blade Edge Arena", "BEA"}}
    if (currentFilters["map"] == "All") then
        filteredDB = CopyTable(unfilteredDB);
    else
        for _,arenaMap in ipairs(arenaMaps) do
            if (currentFilters["map"] == arenaMap[1]) then
                local brackets = {"2v2", "3v3", "5v5"};
                for _, bracket in ipairs(brackets) do
                    if (#unfilteredDB[bracket] > 0) then
                        for arenaNumber = 1, #unfilteredDB[bracket] do
                            if (unfilteredDB[bracket][arenaNumber]["map"] == arenaMap[2]) then
                                table.insert(filteredDB[bracket], unfilteredDB[bracket][arenaNumber]);
                            end
                        end
                    end
                end
            end
        end
    end


    -- Filter comp
    if (currentFilters["bracket"] ~= "All" and isCompFilterOn) then
        local currentCompFilter = "comps" .. currentFilters["bracket"]
        local n2v2 = #filteredDB["2v2"];
        local n3v3 = #filteredDB["3v3"];
        local n5v5 = #filteredDB["5v5"];
        if (currentFilters["bracket"] == "2v2") then
            for arena2v2Number = n2v2, 1, - 1 do
                if (filteredDB["2v2"][arena2v2Number]) then
                    local DBCompAsString = table.concat(filteredDB["2v2"][arena2v2Number]["comp"], " ");
                    if (DBCompAsString ~= currentFilters["comps2v2"]) then
                        table.remove(filteredDB["2v2"], arena2v2Number)
                        n2v2 = n2v2 - 1
                    end
                end
            end
        end
        if (currentFilters["bracket"] == "3v3") then
        for arena3v3Number = n3v3, 1, -1 do
                if (filteredDB["3v3"][arena3v3Number]) then
                    local DBCompAsString = table.concat(filteredDB["3v3"][arena3v3Number]["comp"], " ");
                    if (DBCompAsString ~= currentFilters["comps3v3"]) then
                        table.remove(filteredDB["3v3"], arena3v3Number)
                        n3v3 = n3v3 - 1
                    end
                end
            end
        end
        if (currentFilters["bracket"] == "5v5") then
            for arena5v5Number = n5v5, 1, -1 do
                if (filteredDB["5v5"][arena5v5Number]) then
                    local DBCompAsString = table.concat(filteredDB["5v5"][arena5v5Number]["comp"], " ");
                    if (DBCompAsString ~= currentFilters["comps5v5"]) then
                        table.remove(filteredDB["5v5"], arena5v5Number)
                        n5v5 = n5v5 - 1
                    end
                end
            end
        end
    end

    
    -- Filter bracket
    if(currentFilters["bracket"] == "2v2") then
        filteredDB["3v3"] = {}
        filteredDB["5v5"] = {}
    elseif(currentFilters["bracket"] == "3v3") then
        filteredDB["2v2"] = {}
        filteredDB["5v5"] = {}
    elseif(currentFilters["bracket"] == "5v5") then
        filteredDB["3v3"] = {}
        filteredDB["2v2"] = {}
    end

    -- Filter Skirmish
    if (currentFilters["skirmishIsChecked"] == false) then
        local n2v2 = #filteredDB["2v2"];
        local n3v3 = #filteredDB["3v3"];
        local n5v5 = #filteredDB["5v5"];

        for arena2v2Number = n2v2, 1, -1 do
            if (filteredDB["2v2"][arena2v2Number]) then
                if (not filteredDB["2v2"][arena2v2Number]["isRanked"]) then
                    table.remove(filteredDB["2v2"], arena2v2Number)
                    n2v2 = n2v2 - 1
                end
            end
        end
        for arena3v3Number = n3v3, 1, -1 do
            if (filteredDB["3v3"][arena3v3Number]) then
                if (not filteredDB["3v3"][arena3v3Number]["isRanked"]) then
                    table.remove(filteredDB["3v3"], arena3v3Number)
                    n3v3 = n3v3 - 1
                end
            end
        end
        for arena5v5Number = n5v5, 1, -1 do
            if (filteredDB["5v5"][arena5v5Number]) then
                if (not filteredDB["5v5"][arena5v5Number]["isRanked"]) then
                    table.remove(filteredDB["5v5"], arena5v5Number)
                    n5v5 = n5v5 - 1
                end
            end
        end
    end

    -- Get arenas from each bracket and sort by date 
    local sortedDB = {}; 

    for b = 1, #filteredDB["2v2"] do
        table.insert(sortedDB, filteredDB["2v2"][b]);
    end
    for n = 1, #filteredDB["3v3"] do
        table.insert(sortedDB, filteredDB["3v3"][n]);
    end
    for m = 1, #filteredDB["5v5"] do
        table.insert(sortedDB, filteredDB["5v5"][m]);
    end
    
    table.sort(sortedDB, function (k1,k2)
        return k1["date"] > k2["date"];
    end
    )

    return sortedDB;
end

function core.arenaTable:RefreshLayout()
    ArenaAnalyticsDB = ArenaAnalyticsDB["2v2"] ~= nil and ArenaAnalyticsDB or {
        ["2v2"] = {},
        ["3v3"] = {},
        ["5v5"] = {},
    };
    
    local filteredDB = applyFilters(ArenaAnalyticsDB);
    ArenaAnalyticsScrollFrame.items = filteredDB;

    local items = ArenaAnalyticsScrollFrame.items;
    --DevTools_Dump(filteredDB)
    local buttons = HybridScrollFrame_GetButtons(ArenaAnalyticsScrollFrame.ListScrollFrame);
    local offset = HybridScrollFrame_GetOffset(ArenaAnalyticsScrollFrame.ListScrollFrame);
    local wins = 0;

    for buttonIndex = 1, #buttons do
        local button = buttons[buttonIndex];
        local itemIndex = buttonIndex + offset;

        if itemIndex <= #items then
            local item = items[itemIndex];
            --button:SetID(itemIndex);
            button.Date:SetText(item["date"] or "");
            button.Map:SetText(item["map"] or "");
            button.Duration:SetText(item["duration"] or "");

            local teamIconsFrames = {button.Team1, button.Team2, button.Team3, button.Team4, button.Team5}
            local enemyTeamIconsFrames = {button.EnemyTeam1, button.EnemyTeam2, button.EnemyTeam3, button.EnemyTeam4, button.EnemyTeam5}
            
            local ratingPrevFrame = setClassTextureWithTooltip(teamIconsFrames, item, "team", button)
            
            -- Paint winner green, loser red
            if (item["won"]) then
                button.Rating:SetText("|cff00cc66" .. item["rating"] .. "|r");
            else
                button.Rating:SetText("|cffff0000" .. item["rating"] .. "|r");
            end

            button.MMR:SetText(item["mmr"] or "");

            local enemyRatingPrevFrame = setClassTextureWithTooltip(enemyTeamIconsFrames, item, "enemyTeam", button)
            
            button.EnemyRating:SetText(item["enemyRating"] or "");
            button.EnemyMMR:SetText(item["enemyMmr"] or "");
            

            button:SetWidth(ArenaAnalyticsScrollFrame.ListScrollFrame.scrollChild:GetWidth());
            button:Show();
        else
            button:Hide();
        end
    end
    

    if (ArenaAnalyticsScrollFrame.filterComps2v2 == nil) then
        
        filterComps2v2_opts = {
            ['name']='Filter2v2_Comps',
            ['parent'] = ArenaAnalyticsScrollFrame,
            ['title']='Comp',
            ['hasIcon']= true,
            ['items'] = getPlayerPlayedComps("2v2"),
            ['defaultVal'] ='All', 
            ['changeFunc'] = function (dropdown_frame, dropdown_val)
                currentFilters["comps2v2"] = dropdown_val;
                isCompFilterOn = dropdown_val ~= "All" and true or false
                core.arenaTable:RefreshLayout();
            end
        }

        -- TODO: make custom tailored dropdowns for comp filter
        ArenaAnalyticsScrollFrame.filterComps2v2 = createDropdown(filterComps2v2_opts, dropdownCounter, ArenaAnalyticsScrollFrame)
        
        -- Set tooltip when comp is disabled
        UIDropDownMenu_DisableDropDown(ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame);
        ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame.Text:Hide();
        ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame.tooltipFrame = CreateFrame("Button", nil, ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame);
        ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame.tooltipFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame, "LEFT", 0, 0);
        ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame.tooltipFrame:SetSize(120, 20)
        ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame.tooltipFrame.title = ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame.tooltipFrame:CreateFontString(nil, nil, "GameFontHighlight");
        ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame.tooltipFrame.title:SetPoint("CENTER", ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame.Button, "CENTER", 0, 0);
        ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame.tooltipFrame.title:SetText("Select a Bracket first");
        ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame.tooltipFrame.title:SetTextScale(.7)

        ArenaAnalyticsScrollFrame.filterComps2v2.dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.filterMap.dropdownFrame, "RIGHT", 0, 0);
    else
        checkForFilterUpdate("2v2");
    end
    if (ArenaAnalyticsScrollFrame.filterComps3v3 == nil) then
        filterComps3v3_opts = {
            ['name']='Filter3v3_Comps',
            ['parent'] = ArenaAnalyticsScrollFrame,
            ['title']='Comp',
            ['hasIcon']= true,
            ['items'] = getPlayerPlayedComps("3v3"),
            ['defaultVal'] ='All', 
            ['changeFunc'] = function (dropdown_frame, dropdown_val)
                currentFilters["comps3v3"] = dropdown_val;
                isCompFilterOn = dropdown_val ~= "All" and true or false
                core.arenaTable:RefreshLayout();
            end
        }
        ArenaAnalyticsScrollFrame.filterComps3v3 = createDropdown(filterComps3v3_opts, dropdownCounter, ArenaAnalyticsScrollFrame)
        ArenaAnalyticsScrollFrame.filterComps3v3.dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.filterMap.dropdownFrame, "RIGHT", 0, 0);
        ArenaAnalyticsScrollFrame.filterComps3v3.dropdownFrame:Hide();
    else
        checkForFilterUpdate("3v3");
    end
    if (ArenaAnalyticsScrollFrame.filterComps5v5 == nil) then
        filterComps5v5_opts = {
            ['name']='Filter5v5_Comps',
            ['parent'] = ArenaAnalyticsScrollFrame,
            ['title']='Comp',
            ['hasIcon']= true,
            ['items'] = getPlayerPlayedComps("5v5"),
            ['defaultVal'] ='All', 
            ['changeFunc'] = function (dropdown_frame, dropdown_val)
                currentFilters["comps5v5"] = dropdown_val;
                isCompFilterOn = dropdown_val ~= "All" and true or false
                core.arenaTable:RefreshLayout();
            end
        }
        ArenaAnalyticsScrollFrame.filterComps5v5 = createDropdown(filterComps5v5_opts, dropdownCounter, ArenaAnalyticsScrollFrame)
        ArenaAnalyticsScrollFrame.filterComps5v5.dropdownFrame:SetPoint("LEFT", ArenaAnalyticsScrollFrame.filterMap.dropdownFrame, "RIGHT", 0, 0);
        ArenaAnalyticsScrollFrame.filterComps5v5.dropdownFrame:Hide();
    else
        checkForFilterUpdate("5v5");
    end

    -- Adjust Team bg
    if (#items < 15) then
        local newHeight = (#items * 28) - 1;
        ArenaAnalyticsScrollFrame.teamBgT:SetHeight(newHeight);
        ArenaAnalyticsScrollFrame.teamBg:SetHeight(newHeight);
    end
    

    -- Update arena count & winrate

    for n = 1, #items do
        if(items[n]["won"]) then wins = wins + 1; end
    end

    local totalArenas = #ArenaAnalyticsScrollFrame.items;
    local winrate = totalArenas > 0 and math.floor(wins * 100 / totalArenas) or 0;
    local winsColoured =  "|cff00cc66" .. wins .. "|r";
    local totalArenasColoured =  "|cffff0000" .. totalArenas .. "|r";
    ArenaAnalyticsScrollFrame.totalArenaNumber:SetText("Total: " .. totalArenas .. " arenas");
    ArenaAnalyticsScrollFrame.winrate:SetText(winsColoured .. "/" .. totalArenasColoured .. " | " .. winrate .. "% Winrate");


    local buttonHeight = ArenaAnalyticsScrollFrame.ListScrollFrame.buttonHeight;
    local totalHeight = #items * buttonHeight;
    local shownHeight = #buttons * buttonHeight;

    HybridScrollFrame_Update(ArenaAnalyticsScrollFrame.ListScrollFrame, totalHeight, shownHeight);
    
end