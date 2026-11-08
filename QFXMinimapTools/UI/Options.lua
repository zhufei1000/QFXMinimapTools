local ADDON_NAME, QMT = ...
QMT = QMT or {}
_G.QFXMinimapTools = QMT

local L = setmetatable({}, { __index = function(_, key) return QMT.L and QMT.L[key] end })
local UI = QMT.UI or {}
local BACKDROP_TEMPLATE = UI.BACKDROP_TEMPLATE or (BackdropTemplateMixin and "BackdropTemplate" or nil)
local NormalizeLanguageChoice = QMT.NormalizeLanguageChoice

local function ReloadUICompat()
    if _G.ReloadUI then
        local ok = pcall(_G.ReloadUI)
        if ok then return end
    end
    if C_UI and C_UI.Reload then
        local ok = pcall(C_UI.Reload)
        if ok then return end
    end
    if QMT.Print then QMT.Print("/reload") else print("/reload") end
end

local function RefreshStatsFromOptions()
    if QMT.RefreshStatUpdaterState then QMT:RefreshStatUpdaterState() end
    if QMT.RefreshPhaseEventRegistration then QMT:RefreshPhaseEventRegistration() end
    if QMT.PlaceAllStatFrames then QMT:PlaceAllStatFrames() end
    if QMT.UpdateAllStats then QMT:UpdateAllStats() end
    if QMT.UpdateUtilityRow then QMT:UpdateUtilityRow() end
    if QMT.ApplyDifficultyFramePosition then QMT:ApplyDifficultyFramePosition() end
    if QMT.ApplyTrackingButtonPosition then QMT:ApplyTrackingButtonPosition() end
end

function QMT:CommitOptions(applyFunc)
    if applyFunc then
        applyFunc()
    else
        self:ApplyAll()
    end
    if self.RefreshOptionsControlState then self:RefreshOptionsControlState() end
end

local function CreatePage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    page:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    page:Hide()
    return page
end

local function AddControl(frame, groupName, control)
    if not control then return control end
    frame[groupName] = frame[groupName] or {}
    table.insert(frame[groupName], control)
    return control
end

local function MakeControl(frame, groupName, creator, ...)
    local control = creator(...)
    AddControl(frame, groupName, control)
    return control
end

local function MakeBorderOptions()
    local options = {}
    for _, key in ipairs(QMT.borderPresetOrder or {}) do
        local preset = QMT.borderPresets and QMT.borderPresets[key]
        if preset then table.insert(options, { key = key, label = preset.label or key }) end
    end
    return options
end

local function GetBorderLabel()
    local key = QMT.db and QMT.db.minimap and QMT.db.minimap.borderPreset or "DARK"
    return QMT:GetBorderPresetLabel(key)
end

local function SetBorderPreset(key)
    QMT:SetBorderPreset(key)
end

local function CommitFlightOptions()
    QMT:CommitOptions(function()
        if QMT.RefreshGatheringProfessionCache then QMT:RefreshGatheringProfessionCache() end
        QMT:ApplyAll()
        if QMT.RefreshFlightEventRegistration then QMT:RefreshFlightEventRegistration() end
        if QMT.RefreshOutdoorFlightWatcher then QMT:RefreshOutdoorFlightWatcher() end
        if QMT.UpdateOutdoorFlightCenterState then QMT:UpdateOutdoorFlightCenterState(true) end
        if QMT.RefreshGatheringProfessionStatus then QMT:RefreshGatheringProfessionStatus() end
    end)
end

local function AddOverviewPage(f, page)
    local intro = UI.CreateSection(page, L.OVERVIEW or L.TITLE, 12, -12, 552, 120, L.OVERVIEW_DESC or L.PANEL_DESC)
    UI.CreateButton(intro, L.RESET_MINIMAP_POSITION, 14, -78, 178, 26, function() QMT:ResetMinimapPosition() end, L.RESET_POSITION_TIP)
    UI.CreateButton(intro, L.RESCAN, 204, -78, 124, 26, function() QMT:RescanButtons(true) end)

    local quick = UI.CreateSection(page, L.QUICK_SWITCHES or "Quick switches", 12, -146, 552, 176, L.QUICK_SWITCHES_DESC or "")
    local y = quick.contentTop or -58
    UI.CreateCheck(quick, L.ENABLE_ENHANCE, 18, y, function() return QMT.db.minimap.enabled end, function(v) QMT.db.minimap.enabled = v end, 230); y = y - 30
    UI.CreateCheck(quick, L.SQUARE, 18, y, function() return QMT.db.minimap.square end, function(v) QMT.db.minimap.square = v end, 230); y = y - 30
    UI.CreateCheck(quick, L.COLLECT_BUTTONS, 18, y, function() return QMT.db.bag.enabled end, function(v) QMT.db.bag.enabled = v end, 230)
    y = quick.contentTop or -58
    UI.CreateCheck(quick, L.SHOW_LOCATION, 286, y, function() return QMT.db.display.location end, function(v) QMT.db.display.location = v end, 220, RefreshStatsFromOptions); y = y - 30
    UI.CreateCheck(quick, L.SHOW_COORDS, 286, y, function() return QMT.db.display.coordinates end, function(v) QMT.db.display.coordinates = v end, 220, RefreshStatsFromOptions); y = y - 30
    UI.CreateCheck(quick, L.SHOW_SYSTEM, 286, y, function() return QMT.db.display.system end, function(v) QMT.db.display.system = v end, 220, RefreshStatsFromOptions)

    local hint = UI.CreateSection(page, L.SIMPLE_USAGE or "Usage", 12, -338, 552, 128, L.SIMPLE_USAGE_DESC or "")
    UI.CreateFont(hint, "GameFontHighlightSmall", L.COMMAND_HINT, "TOPLEFT", 16, -64, 510)
end

local function AddMinimapPage(f, page)
    local s = UI.CreateSection(page, L.MINIMAP, 12, -12, 552, 470, L.MINIMAP_DESC or "")
    local y = s.contentTop or -58
    f.enableEnhanceCheck = UI.CreateCheck(s, L.ENABLE_ENHANCE, 18, y, function() return QMT.db.minimap.enabled end, function(v) QMT.db.minimap.enabled = v end, 320); y = y - 30
    f.squareCheck = MakeControl(f, "minimapDependentControls", UI.CreateCheck, s, L.SQUARE, 18, y, function() return QMT.db.minimap.square end, function(v) QMT.db.minimap.square = v end, 320, nil, L.SQUARE_TIP); y = y - 30
    f.hideCompartmentCheck = MakeControl(f, "minimapDependentControls", UI.CreateCheck, s, L.HIDE_COMPARTMENT, 18, y, function() return QMT.db.minimap.hideCompartment end, function(v) QMT.db.minimap.hideCompartment = v end, 320); y = y - 30
    f.lockMinimapCheck = MakeControl(f, "minimapDependentControls", UI.CreateCheck, s, L.LOCK_MINIMAP, 18, y, function() return QMT.db.minimap.locked end, function(v) QMT.db.minimap.locked = v end, 230, nil, L.UNLOCK_MOVE_TIP)
    f.showBorderCheck = MakeControl(f, "minimapDependentControls", UI.CreateCheck, s, L.SHOW_BORDER, 286, y, function() return QMT.db.minimap.borderEnabled ~= false end, function(v) QMT.db.minimap.borderEnabled = v end, 220, nil, L.BORDER_SIZE_TIP); y = y - 44

    f.borderPresetDropdown = MakeControl(f, "minimapDependentControls", UI.CreateDropdown, s, L.BORDER_STYLE, 18, y, 136, 190, MakeBorderOptions(), GetBorderLabel, SetBorderPreset); y = y - 52
    f.borderSizeSlider = MakeControl(f, "borderDependentControls", UI.CreateSlider, s, L.BORDER_SIZE, 18, y, 136, 220, 1, 12, 1, function() return tonumber(QMT.db.minimap.borderSize) or 3 end, function(v) QMT.db.minimap.borderSize = v end, function(v) return tostring(math.floor(v + 0.5)) end, nil); y = y - 54
    f.minimapScaleSlider = MakeControl(f, "minimapDependentControls", UI.CreateSlider, s, L.MINIMAP_SCALE, 18, y, 136, 220, 0.7, 2.0, 0.05, function() return QMT.db.minimap.scale end, function(v) QMT.db.minimap.scale = v end, function(v) return string.format("%.2f", v) end); y = y - 54

    UI.CreateButton(s, L.RESET_MINIMAP_POSITION, UI.ControlX(18, 136), y + 4, 190, 26, function() QMT:ResetMinimapPosition() end, L.RESET_POSITION_TIP)
    UI.CreateFont(s, "GameFontDisableSmall", L.UNLOCK_MOVE_TIP, "TOPLEFT", 18, y - 38, 506)
end

local function AddStatsPage(f, page)
    local s = UI.CreateSection(page, L.STATS, 12, -12, 552, 474, L.STATS_DESC or "")
    local y = s.contentTop or -58
    UI.CreateCheck(s, L.SHOW_LOCATION, 18, y, function() return QMT.db.display.location end, function(v) QMT.db.display.location = v end, 230, RefreshStatsFromOptions); y = y - 30
    UI.CreateCheck(s, L.SHOW_COORDS, 18, y, function() return QMT.db.display.coordinates end, function(v) QMT.db.display.coordinates = v end, 230, RefreshStatsFromOptions); y = y - 30
    UI.CreateCheck(s, L.SHOW_TIME, 18, y, function() return QMT.db.display.time end, function(v) QMT.db.display.time = v end, 230, RefreshStatsFromOptions); y = y - 30
    UI.CreateCheck(s, L.SHOW_SYSTEM, 18, y, function() return QMT.db.display.system end, function(v) QMT.db.display.system = v end, 230, RefreshStatsFromOptions); y = y - 30
    UI.CreateCheck(s, L.SHOW_DIFFICULTY, 18, y, function() return QMT.db.display.difficulty end, function(v) QMT.db.display.difficulty = v end, 230, RefreshStatsFromOptions)

    y = s.contentTop or -58
    if not (QMT.IsForever and QMT:IsForever()) then
        UI.CreateCheck(s, L.SHOW_PHASE_ID, 286, y, function() return QMT.db.display.phaseID end, function(v) QMT.db.display.phaseID = v end, 220, RefreshStatsFromOptions); y = y - 54
    end

    f.fontSizeSlider = UI.CreateSlider(s, L.FONT_SIZE, 18, -246, 130, 220, 8, 22, 1, function() return QMT.db.display.fontSize end, function(v) QMT.db.display.fontSize = v end, function(v) return tostring(v) end, RefreshStatsFromOptions)
    UI.CreateSlider(s, L.COORDS_DECIMALS or "Coords decimals", 18, -306, 130, 220, 0, 2, 1, function() return QMT.db.display.coordsDecimals or 1 end, function(v) QMT.db.display.coordsDecimals = v end, function(v) return tostring(v) end, RefreshStatsFromOptions)
end

local function GetPinnedButtonsSummary()
    local count = QMT:GetPinnedButtonCount()
    if count == 0 then return L.BUTTON_NONE_SELECTED end
    return string.format(L.BUTTON_COUNT_SELECTED, count)
end

local function AddBagPage(f, page)
    local s = UI.CreateSection(page, L.BUTTONS, 12, -12, 552, 474, L.BUTTONS_DESC or "")
    local y = s.contentTop or -58
    f.collectButtonsCheck = UI.CreateCheck(s, L.COLLECT_BUTTONS, 18, y, function() return QMT.db.bag.enabled end, function(v) QMT.db.bag.enabled = v end, 360); y = y - 30
    f.autoCloseCheck = MakeControl(f, "bagDependentControls", UI.CreateCheck, s, L.AUTO_CLOSE, 18, y, function() return QMT.db.bag.autoClose end, function(v) QMT.db.bag.autoClose = v end, 360); y = y - 42

    local items = {}
    local function RefreshItems()
        QMT:RescanButtons(true)
        QMT:UpdatePinnableButtonItems(items)
    end
    local function AlreadyApplied() end
    f.pinnedButtonsDropdown = MakeControl(f, "bagDependentControls", UI.CreateDropdown, s,
        L.PINNED_BUTTONS, 18, y, 184, 220, items, GetPinnedButtonsSummary,
        function(name, checked) QMT:SetButtonPinned(name, checked) end, AlreadyApplied, L.PINNED_BUTTONS_TIP,
        function(name) return QMT:IsButtonPinned(name) end, RefreshItems)
    y = y - 36
    local positions = {{key = "DOWN", label = L.BUTTON_BELOW_Q}, {key = "UP", label = L.BUTTON_ABOVE_Q}}
    f.pinnedPositionDropdown = MakeControl(f, "bagDependentControls", UI.CreateDropdown, s,
        L.PINNED_BUTTON_POSITION, 18, y, 184, 220, positions,
        function() return QMT.db.bag.pinnedDirection == "UP" and L.BUTTON_ABOVE_Q or L.BUTTON_BELOW_Q end,
        function(direction) QMT:SetPinnedButtonDirection(direction) end, AlreadyApplied)
    y = y - 42
    f.buttonScaleSlider = MakeControl(f, "bagDependentControls", UI.CreateSlider, s, L.BUTTON_SCALE, 18, y, 132, 220, 0.7, 1.4, 0.05, function() return QMT.db.bag.buttonScale end, function(v) QMT.db.bag.buttonScale = v end, function(v) return string.format("%.2f", v) end); y = y - 56
    f.buttonsPerRowSlider = MakeControl(f, "bagDependentControls", UI.CreateSlider, s, L.BUTTONS_PER_ROW, 18, y, 132, 220, 1, 10, 1, function() return QMT.db.bag.buttonsPerRow end, function(v) QMT.db.bag.buttonsPerRow = v end, function(v) return tostring(v) end); y = y - 60

    UI.CreateButton(s, L.RESCAN, 18, y, 128, 26, function() QMT:RescanButtons(true) end)
    y = y - 48
    f.excludeEditBox = MakeControl(f, "bagDependentControls", UI.CreateEditBox, s, L.EXCLUDE, 18, y, 132, 340, function() return QMT.db.bag.exclude or "" end, function(v) QMT.db.bag.exclude = v; QMT:InvalidateExcludeCache() end, function() QMT:RestoreCollectedButtons(); QMT:ApplyAll() end)
    y = y - 44
    UI.CreateFont(s, "GameFontDisableSmall", L.BAG_POSITION_TIP, "TOPLEFT", 18, y, 506)
end

local function AddIndicatorPage(f, page)
    local s = UI.CreateSection(page, L.MAP_COMPONENTS, 12, -12, 552, 470, L.MAP_COMPONENTS_DESC)
    local y = s.contentTop or -58
    local anchorOptions = {
        {key = "Q", label = L.INDICATOR_ANCHOR_Q},
        {key = "TOPLEFT", label = L.INDICATOR_ANCHOR_TOPLEFT},
        {key = "TOP", label = L.INDICATOR_ANCHOR_TOP},
        {key = "TOPRIGHT", label = L.INDICATOR_ANCHOR_TOPRIGHT},
        {key = "LEFT", label = L.INDICATOR_ANCHOR_LEFT},
        {key = "RIGHT", label = L.INDICATOR_ANCHOR_RIGHT},
        {key = "BOTTOMLEFT", label = L.INDICATOR_ANCHOR_BOTTOMLEFT},
        {key = "BOTTOM", label = L.INDICATOR_ANCHOR_BOTTOM},
        {key = "BOTTOMRIGHT", label = L.INDICATOR_ANCHOR_BOTTOMRIGHT},
    }
    local layerOptions = {
        {key = "ON", label = L.INDICATOR_LAYER_ON},
        {key = "OUTSIDE", label = L.INDICATOR_LAYER_OUTSIDE},
        {key = "INSIDE", label = L.INDICATOR_LAYER_INSIDE},
    }
    f.indicatorAnchorDropdown = MakeControl(f, "minimapDependentControls", UI.CreateDropdown, s, L.INDICATOR_ANCHOR, 18, y, 60, 130, anchorOptions,
        function() return QMT:GetIndicatorAnchorLabel() end,
        function(key) QMT.db.minimap.indicatorAnchor = key end,
        function() QMT:LayoutIndicatorColumn(); QMT:RefreshOptionsControlState(); QMT:RequestSmartTopRightSnap() end,
        L.INDICATOR_ANCHOR_TIP)
    f.indicatorLayerDropdown = MakeControl(f, "indicatorLayerControls", UI.CreateDropdown, s, L.INDICATOR_LAYER, 286, y, 60, 130, layerOptions,
        function() return QMT:GetIndicatorLayerLabel() end,
        function(key) QMT.db.minimap.indicatorLayer = key end,
        function() QMT:LayoutIndicatorColumn(); QMT:RequestSmartTopRightSnap() end,
        L.INDICATOR_LAYER_TIP)
    y = y - 52
    f.indicatorDirectionDropdown = MakeControl(f, "minimapDependentControls", UI.CreateDropdown, s, L.INDICATOR_DIRECTION, 18, y, 132, 170, {
        {key = "UP", label = L.INDICATOR_UP},
        {key = "DOWN", label = L.INDICATOR_DOWN},
        {key = "LEFT", label = L.INDICATOR_LEFT},
        {key = "RIGHT", label = L.INDICATOR_RIGHT},
    }, function()
        local key = QMT.db.minimap.indicatorDirection
        if key == "UP" then return L.INDICATOR_UP end
        if key == "LEFT" then return L.INDICATOR_LEFT end
        if key == "RIGHT" then return L.INDICATOR_RIGHT end
        return L.INDICATOR_DOWN
    end,
    function(key) QMT.db.minimap.indicatorDirection = key end,
    function() QMT:LayoutIndicatorColumn(); QMT:RequestSmartTopRightSnap() end, L.INDICATOR_DIRECTION_TIP)
    y = y - 52
    f.indicatorSizeSlider = MakeControl(f, "minimapDependentControls", UI.CreateSlider, s, L.INDICATOR_SIZE, 18, y, 132, 220, 12, 40, 1,
        function() return QMT:GetUtilityIconSize() end, function(value) QMT:SetIndicatorSize(value) end,
        function(value) return tostring(value) .. " px" end, function() end, L.INDICATOR_SIZE_TIP)
    y = y - 64
    f.indicatorWeightDropdown = MakeControl(f, "minimapDependentControls", UI.CreateDropdown, s, L.INDICATOR_WEIGHT, 18, y, 132, 170, {
        {key = 0, label = L.INDICATOR_WEIGHT_THIN},
        {key = 1, label = L.INDICATOR_WEIGHT_REGULAR},
        {key = 2, label = L.INDICATOR_WEIGHT_MEDIUM},
        {key = 3, label = L.INDICATOR_WEIGHT_BOLD},
    }, function() return QMT:GetIndicatorWeightLabel() end,
    function(value) QMT:SetIndicatorWeight(value) end, function() end, L.INDICATOR_WEIGHT_TIP)
    y = y - 64
    f.indicatorSpacingSlider = MakeControl(f, "minimapDependentControls", UI.CreateSlider, s, L.INDICATOR_SPACING, 18, y, 132, 220, 0, 24, 1,
        function() return QMT:GetIndicatorSpacing() end, function(value) QMT:SetIndicatorSpacing(value) end,
        function(value) return tostring(value) .. " px" end, function() end, L.INDICATOR_SPACING_TIP)
    y = y - 64
    f.indicatorColorModeDropdown = MakeControl(f, "minimapDependentControls", UI.CreateDropdown, s, L.INDICATOR_COLOR, 18, y, 132, 170, {
        {key = "CLASS", label = L.INDICATOR_COLOR_CLASS},
        {key = "CUSTOM", label = L.INDICATOR_COLOR_CUSTOM},
    }, function() return QMT.db.minimap.indicatorColorMode == "CLASS" and L.INDICATOR_COLOR_CLASS or L.INDICATOR_COLOR_CUSTOM end,
    function(key) QMT:SetIndicatorColorMode(key) end, function() QMT:RefreshOptionsControlState() end, L.INDICATOR_COLOR_TIP)
    y = y - 52
    f.indicatorColorButton = MakeControl(f, "indicatorCustomControls", UI.CreateButton, s, L.INDICATOR_COLOR_PICK, 18, y, 170, 26, function()
        local picker = ColorPickerFrame
        if not picker then return end
        local r, g, b = QMT:GetCustomIndicatorColor()
        local function Apply()
            local nr, ng, nb = picker:GetColorRGB()
            QMT:SetIndicatorColor(nr, ng, nb)
        end
        local function Cancel() QMT:SetIndicatorColor(r, g, b) end
        picker:Hide()
        if picker.SetupColorPickerAndShow then
            picker:SetupColorPickerAndShow({r = r, g = g, b = b, hasOpacity = false, swatchFunc = Apply, cancelFunc = Cancel})
        else
            picker.func, picker.cancelFunc = Apply, Cancel
            picker.hasOpacity = false
            picker:SetColorRGB(r, g, b)
            picker:Show()
        end
    end, L.INDICATOR_COLOR_TIP)
    f.indicatorColorReset = MakeControl(f, "indicatorCustomControls", UI.CreateButton, s, L.INDICATOR_COLOR_RESET, 200, y, 142, 26, function()
        if ColorPickerFrame then ColorPickerFrame:Hide() end
        QMT:SetIndicatorColor(1, 1, 1)
    end)
end

local function AddFlightPage(f, page)
    if QMT.IsForever and QMT:IsForever() then
        UI.CreateSection(page, L.FLIGHT_SECTION, 12, -12, 552, 120,
            L.FOREVER_FLIGHT_UNSUPPORTED or L.FLIGHT_DESC or "")
        return
    end
    local s = UI.CreateSection(page, L.FLIGHT_SECTION, 12, -12, 552, 402, L.FLIGHT_DESC or "")
    local y = s.contentTop or -58
    f.flightCenterCheck = MakeControl(f, "minimapDependentControls", UI.CreateCheck, s, L.FLIGHT_CENTER, 18, y, function() return QMT.db.minimap.flightCenter end, function(v) QMT.db.minimap.flightCenter = v end, 410, CommitFlightOptions); y = y - 30
    f.flightGatheringCheck = MakeControl(f, "flightDependentControls", UI.CreateCheck, s, L.FLIGHT_GATHERING_ONLY, 38, y, function() return QMT.db.minimap.flightCenterOnlyGathering end, function(v) QMT.db.minimap.flightCenterOnlyGathering = v end, 420, CommitFlightOptions, L.FLIGHT_GATHERING_ONLY_TIP); y = y - 26
    f.gatheringStatusText = UI.CreateFont(s, "GameFontDisableSmall", "", "TOPLEFT", 64, y, 448)
    f.gatheringStatusText:SetWordWrap(true)
    f.gatheringStatusText:SetText(QMT:GetGatheringProfessionStatusText())
    y = y - 48
    f.flightScaleSlider = MakeControl(f, "flightDependentControls", UI.CreateSlider, s, L.FLIGHT_SCALE, 18, y, 132, 220, 1.00, 3.00, 0.05, function() return QMT.db.minimap.flightScale end, function(v) QMT.db.minimap.flightScale = v end, function(v) return string.format("%.2f", v) end, CommitFlightOptions); y = y - 56
    f.flightAlphaSlider = MakeControl(f, "flightDependentControls", UI.CreateSlider, s, L.FLIGHT_ALPHA, 18, y, 132, 220, 0.10, 1.00, 0.05, function() return QMT.db.minimap.flightAlpha end, function(v) QMT.db.minimap.flightAlpha = v end, function(v) return string.format("%.2f", v) end, CommitFlightOptions); y = y - 56
    f.flightPosYSlider = MakeControl(f, "flightDependentControls", UI.CreateSlider, s, L.FLIGHT_POS_Y, 18, y, 132, 220, -240, 40, 1, function() return QMT.db.minimap.flightPosY end, function(v) QMT.db.minimap.flightPosY = v end, function(v) return tostring(math.floor(v + 0.5)) end, CommitFlightOptions)
end

local function AddAdvancedPage(f, page)
    local s = UI.CreateSection(page, L.ADVANCED or "Advanced", 12, -12, 552, 348, L.ADVANCED_DESC or "")
    local y = s.contentTop or -58
    UI.CreateDropdown(s, L.UI_LANGUAGE, 18, y, 132, 170, {
        {key = "AUTO", label = L.LANGUAGE_AUTO},
        {key = "zhCN", label = L.LANGUAGE_ZH},
        {key = "zhTW", label = L.LANGUAGE_ZH_TW},
        {key = "enUS", label = L.LANGUAGE_EN},
    }, function() return QMT:GetLanguageLabel(QMT.db and QMT.db.ui and QMT.db.ui.language or "AUTO") end, function(key) QMT:SetUILanguage(key) end, function() end); y = y - 52

    UI.CreateCheck(s, L.SHOW_CPU_USAGE, 18, y, function() return QMT.IsCPUProfilerDisabled and QMT:IsCPUProfilerDisabled() or false end, function(v) if QMT.ApplyCPUProfilerSetting then QMT:ApplyCPUProfilerSetting(v, "user") end end, 420, function() end); y = y - 48
    UI.CreateButton(s, L.RESET, 18, y, 128, 26, function() QMT:ResetDefaults() end)
    UI.CreateButton(s, L.RELOAD, 158, y, 128, 26, function() ReloadUICompat() end)
end

function QMT:GetManagerSettingsPages()
    return {
        {key = "overview", title = L.OVERVIEW or "Overview"},
        {key = "minimap", title = L.MINIMAP},
        {key = "stats", title = L.STATS},
        {key = "indicators", title = L.MAP_COMPONENTS},
        {key = "bag", title = L.BUTTONS},
        {key = "flight", title = L.FLIGHT_SECTION},
        {key = "advanced", title = L.ADVANCED or "Advanced"},
    }
end

function QMT:SelectLegacyOptionsPage(f, id)
    f.selectedPage = id
    for pageID, page in pairs(f.pages or {}) do
        if pageID == id then page:Show() else page:Hide() end
    end
    for pageID, button in pairs(f.tabs or {}) do
        if pageID == id then
            if button.LockHighlight then button:LockHighlight() end
            if button.Text then button.Text:SetTextColor(1, 0.82, 0) end
        else
            if button.UnlockHighlight then button:UnlockHighlight() end
            if button.Text then button.Text:SetTextColor(1, 1, 1) end
        end
    end
end

local function CreateTab(f, id, text, index)
    local b = CreateFrame("Button", nil, f.sidebar, "UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT", f.sidebar, "TOPLEFT", 12, -14 - (index - 1) * 36)
    b:SetSize(126, 30)
    b:SetText(text)
    b:SetScript("OnClick", function() QMT:SelectLegacyOptionsPage(f, id) end)
    f.tabs[id] = b
    return b
end

function QMT:RefreshOptionsControlState()
    local f = self.optionsFrame
    local db = self.db
    if not f or not db then return end
    for _, refresh in ipairs(f.optionRefreshers or {}) do refresh() end
    local minimapEnabled = db.minimap and db.minimap.enabled == true
    local flightEnabled = minimapEnabled and db.minimap and db.minimap.flightCenter == true
    local borderEnabled = minimapEnabled and db.minimap and db.minimap.borderEnabled ~= false
    local indicatorLayerEnabled = minimapEnabled and db.minimap and (db.minimap.indicatorAnchor or "Q") ~= "Q"
    local bagEnabled = db.bag and db.bag.enabled == true
    UI.SetControlsEnabled(f.minimapDependentControls, minimapEnabled)
    UI.SetControlsEnabled(f.flightDependentControls, flightEnabled)
    UI.SetControlsEnabled(f.borderDependentControls, borderEnabled)
    UI.SetControlsEnabled(f.indicatorLayerControls, indicatorLayerEnabled)
    UI.SetControlsEnabled(f.bagDependentControls, bagEnabled)
    if f.pinnedButtonsDropdown then f.pinnedButtonsDropdown:SetText(GetPinnedButtonsSummary()) end
    UI.SetControlsEnabled(f.indicatorCustomControls, minimapEnabled and db.minimap.indicatorColorMode ~= "CLASS")
    if f.borderPresetDropdown and self.RefreshBorderPresetControls then self:RefreshBorderPresetControls() end
    if self.RefreshGatheringProfessionStatus then self:RefreshGatheringProfessionStatus() end
end

function QMT:RefreshGatheringProfessionStatus()
    local f = self.optionsFrame
    if f and f.gatheringStatusText then f.gatheringStatusText:SetText(self:GetGatheringProfessionStatusText()) end
end

function QMT:CreateOptionsFrame()
    if self.optionsFrame then return self.optionsFrame end
    local f = CreateFrame("Frame", nil, UIParent, BACKDROP_TEMPLATE)
    f.optionRefreshers = {}
    f:SetSize(UI.LAYOUT.panelW, UI.LAYOUT.panelH)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI.ApplyBackdrop(f, "panel")

    f.title = UI.CreateFont(f, "GameFontNormalLarge", L.TITLE, "TOPLEFT", 26, -18, 330)
    f.title:SetTextColor(1, 0.82, 0)
    f.desc = UI.CreateFont(f, "GameFontDisableSmall", L.PANEL_DESC, "TOPLEFT", 26, -42, 530)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    f.sidebar = CreateFrame("Frame", nil, f, BACKDROP_TEMPLATE)
    f.sidebar:SetPoint("TOPLEFT", 18, -72)
    f.sidebar:SetSize(UI.LAYOUT.sidebarW, 492)
    UI.ApplyBackdrop(f.sidebar, "card")

    f.content = CreateFrame("Frame", nil, f, BACKDROP_TEMPLATE)
    f.content:SetPoint("TOPLEFT", f.sidebar, "TOPRIGHT", 12, 0)
    f.content:SetSize(576, 492)

    f.pages = {}
    f.tabs = {}
    f.minimapDependentControls = {}
    f.flightDependentControls = {}
    f.borderDependentControls = {}
    f.indicatorLayerControls = {}
    f.bagDependentControls = {}

    local tabInfo = self:GetManagerSettingsPages()
    for i, info in ipairs(tabInfo) do CreateTab(f, info.key, info.title, i) end

    for _, info in ipairs(tabInfo) do f.pages[info.key] = CreatePage(f.content) end
    AddOverviewPage(f, f.pages.overview)
    AddMinimapPage(f, f.pages.minimap)
    AddStatsPage(f, f.pages.stats)
    AddIndicatorPage(f, f.pages.indicators)
    AddBagPage(f, f.pages.bag)
    AddFlightPage(f, f.pages.flight)
    AddAdvancedPage(f, f.pages.advanced)

    f.bottomHint = UI.CreateFont(f, "GameFontDisableSmall", L.COMMAND_HINT, "BOTTOMLEFT", 26, 18, 470)
    local reloadBtn = UI.CreateButton(f, L.RELOAD, 0, 0, 90, 24, function() ReloadUICompat() end)
    reloadBtn:ClearAllPoints()
    reloadBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 18)
    local resetBtn = UI.CreateButton(f, L.RESET, 0, 0, 90, 24, function() QMT:ResetDefaults() end)
    resetBtn:ClearAllPoints()
    resetBtn:SetPoint("RIGHT", reloadBtn, "LEFT", -10, 0)

    self.optionsFrame = f
    f:Hide()
    self:SelectLegacyOptionsPage(f, "overview")
    f:SetScript("OnShow", function() QMT:RefreshOptionsControlState() end)
    return f
end

function QMT:ShowOptions()
    local frame = self:CreateOptionsFrame()
    if frame:IsShown() then self:RefreshOptionsControlState() else frame:Show() end
end

function QMT:ToggleOptions()
    local f = self:CreateOptionsFrame()
    if f:IsShown() then f:Hide() else f:Show() end
end

function QMT:CreateSettingsPanel()
    if self.settingsPanel then return self.settingsPanel end

    local panel = CreateFrame("Frame", "QFXMinimapToolsSettingsPanel", UIParent)
    panel.name = L.TITLE
    panel.parent = nil

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L.TITLE)
    panel.qfxTitle = title

    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    desc:SetWidth(560)
    desc:SetJustifyH("LEFT")
    desc:SetText(L.PANEL_DESC)
    panel.qfxDesc = desc

    local openBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -18)
    openBtn:SetSize(220, 28)
    openBtn:SetText(L.OPEN_OPTIONS)
    panel.qfxOpenButton = openBtn
    openBtn:SetScript("OnClick", function() QMT:ShowOptions() end)

    local resetPosBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetPosBtn:SetPoint("LEFT", openBtn, "RIGHT", 10, 0)
    resetPosBtn:SetSize(210, 28)
    resetPosBtn:SetText(L.RESET_MINIMAP_POSITION)
    panel.qfxResetPosButton = resetPosBtn
    resetPosBtn:SetScript("OnClick", function() QMT:ResetMinimapPosition() end)
    resetPosBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L.RESET_POSITION_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    resetPosBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local cmd = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    cmd:SetPoint("TOPLEFT", openBtn, "BOTTOMLEFT", 0, -16)
    cmd:SetWidth(560)
    cmd:SetJustifyH("LEFT")
    cmd:SetText(L.COMMAND_HINT)
    panel.qfxCommandHint = cmd

    self.settingsPanel = panel
    return panel
end

function QMT:RegisterSettingsCategory()
    if self.settingsRegistered then return true end

    -- WoW Forever deliberately stays out of the Blizzard Settings frame; the
    -- addon is configured through the Q right-click, /qfmt, or QFX Addon Manager.
    if self.IsForever and self:IsForever() then
        self.settingsRegistered = true
        return false
    end

    local panel = self:CreateSettingsPanel()
    local registered = false

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, L.TITLE)
        Settings.RegisterAddOnCategory(category)
        self.settingsCategory = category
        self.settingsCategoryID = category and category.ID
        registered = true
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        registered = true
    end

    if registered then
        self.settingsRegistered = true
        self.settingsRegisterRetryCount = 0
        return true
    end

    self.settingsRegisterRetryCount = (self.settingsRegisterRetryCount or 0) + 1
    if C_Timer and not self.settingsRegisterRetryQueued and self.settingsRegisterRetryCount <= 10 then
        self.settingsRegisterRetryQueued = true
        C_Timer.After(1, function()
            QMT.settingsRegisterRetryQueued = nil
            QMT:RegisterSettingsCategory()
        end)
    end
    return false
end

function QMT:OpenBlizzardSettingsCategory()
    self:RegisterSettingsCategory()
    if Settings and Settings.OpenToCategory and self.settingsCategoryID then
        Settings.OpenToCategory(self.settingsCategoryID)
    elseif InterfaceOptionsFrame_OpenToCategory and self.settingsPanel then
        InterfaceOptionsFrame_OpenToCategory(self.settingsPanel)
        InterfaceOptionsFrame_OpenToCategory(self.settingsPanel)
    else
        self:ShowOptions()
    end
end

function QMT:BuildManagerPage(key, page, context, layout)
    local saved={}
    for _, name in ipairs({"CreateSection","CreateCheck","CreateSlider","CreateDropdown","CreateButton","CreateEditBox","CreateFont"}) do saved[name]=UI[name] end
    local controls={}
    local function Row(cfg)
        local frame=layout:Row(cfg)
        return frame._leftRegion and frame._leftRegion._control or frame
    end
    UI.CreateSection=function(_,title,_,_,_,_,note) layout:Section(title,note); return {contentTop=0} end
    local function Commit(set, apply)
        return function(v) set(v); QMT:CommitOptions(apply) end
    end
    local function Disabled(control)
        for _, entry in ipairs({{"minimapDependentControls",not QMT.db.minimap.enabled},
            {"flightDependentControls",not QMT.db.minimap.enabled or not QMT.db.minimap.flightCenter},
            {"borderDependentControls",not QMT.db.minimap.enabled or QMT.db.minimap.borderEnabled == false},
            {"indicatorLayerControls",not QMT.db.minimap.enabled or (QMT.db.minimap.indicatorAnchor or "Q") == "Q"},
            {"bagDependentControls",not QMT.db.bag.enabled},
            {"indicatorCustomControls",not QMT.db.minimap.enabled or QMT.db.minimap.indicatorColorMode == "CLASS"}}) do
            if entry[2] then for _, item in ipairs(controls[entry[1]] or {}) do if item==control then return true end end end
        end
        return false
    end
    UI.CreateCheck=function(_,label,_,_,get,set,_,apply,tip)
        local control
        control=Row({type="toggle",text=label,getValue=get,setValue=Commit(set,apply),tooltip=tip,disabled=function() return Disabled(control) end})
        return control
    end
    UI.CreateSlider=function(_,label,_,_,_,_,min,max,step,get,set,_,apply,tip)
        local control
        local suffix=(label==L.INDICATOR_SIZE or label==L.INDICATOR_SPACING) and " px" or nil
        control=Row({type="slider",text=label,min=min,max=max,step=step,valueSuffix=suffix,getValue=get,setValue=Commit(set,apply),tooltip=tip,disabled=function() return Disabled(control) end})
        return control
    end
    UI.CreateDropdown=function(_,label,_,_,_,width,options,getLabel,set,apply,tip,isChecked,beforeOpen)
        if isChecked then
            local control
            local cfg = {type = "checkboxDropdown", text = label, width = width, items = options,
                getFn = isChecked, summaryFn = getLabel, tooltip = tip,
                disabled = function() return Disabled(control) end}
            cfg.setFn = function(name, checked)
                if context.Widgets:IsDisabled(cfg) then return end
                set(name, checked)
                QMT:CommitOptions(apply)
            end
            control = Row(cfg)
            local open = control._openMenu
            if open then
                control._openMenu = function()
                    if context.Widgets:IsDisabled(cfg) then return end
                    beforeOpen()
                    control._invalidateMenu()
                    open()
                end
            end
            return control
        end
        local isLanguage=label==L.UI_LANGUAGE
        local values,order={},{}
        for _, item in ipairs(options or {}) do values[item.key]=item.label; order[#order+1]=item.key end
        local control
        control=Row({type="dropdown",text=label,values=values,order=order,tooltip=tip,disabled=function() return Disabled(control) end,getValue=function()
            local labelText=getLabel()
            for _, item in ipairs(options or {}) do if item.label==labelText then return item.key end end
            return order[1]
        end,setValue=function(v)
            Commit(set,apply)(v)
            if isLanguage and context.Rebuild then context.Rebuild() end
        end})
        return control
    end
    UI.CreateButton=function(_,label,_,_,_,_,click,tip)
        if label==L.RELOAD and not context.IncludeReload then return {} end
        local isReset=label==L.RESET
        local control
        control=Row({type="button",text=label,tooltip=tip,disabled=function() return Disabled(control) end,onClick=function()
            if isReset then context.Widgets:Confirm({title=label,text=label,danger=true,onAccept=click}) else click() end
        end})
        return control
    end
    UI.CreateEditBox=function(_,label,_,_,_,_,get,set,apply)
        local control
        control=Row({type="input",text=label,getValue=get,setValue=Commit(set,apply),disabled=function() return Disabled(control) end})
        return control
    end
    UI.CreateFont=function(_,_,text)
        if text=="" and layout.Status then
            return layout:Status(function() return QMT:GetGatheringProfessionStatusText() end)
        end
        local frame=layout:Row({type="label",text=text})
        return frame._leftRegion._label
    end
    local builds={overview=AddOverviewPage,minimap=AddMinimapPage,stats=AddStatsPage,indicators=AddIndicatorPage,bag=AddBagPage,flight=AddFlightPage,advanced=AddAdvancedPage}
    local ok,err=pcall(function() assert(builds[key])(controls,page.content) end)
    for name,fn in pairs(saved) do UI[name]=fn end
    if not ok then error(err) end
    layout:Finish()
end
