local ADDON_NAME, QMT = ...
QMT = QMT or {}
_G.QFXMinimapTools = QMT

local L = setmetatable({}, { __index = function(_, key) return QMT.L and QMT.L[key] end })
local UI = QMT.UI or {}
local BACKDROP_TEMPLATE = UI.BACKDROP_TEMPLATE or (BackdropTemplateMixin and "BackdropTemplate" or nil)
local NormalizeLanguageChoice = QMT.NormalizeLanguageChoice

local function RefreshStatsFromOptions()
    if QMT.RefreshStatUpdaterState then QMT:RefreshStatUpdaterState() end
    if QMT.RefreshPhaseEventRegistration then QMT:RefreshPhaseEventRegistration() end
    if QMT.PlaceAllStatFrames then QMT:PlaceAllStatFrames() end
    if QMT.UpdateAllStats then QMT:UpdateAllStats() end
    if QMT.UpdateUtilityRow then QMT:UpdateUtilityRow() end
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
        QMT:ApplyAll()
        if QMT.RefreshFlightEventRegistration then QMT:RefreshFlightEventRegistration() end
        if QMT.RefreshOutdoorFlightWatcher then QMT:RefreshOutdoorFlightWatcher() end
        if QMT.UpdateOutdoorFlightCenterState then QMT:UpdateOutdoorFlightCenterState(true) end
        if QMT.RefreshGatheringProfessionStatus then QMT:RefreshGatheringProfessionStatus() end
    end)
end

local function AddOverviewPage(f, page)
    local intro = UI.CreateSection(page, L.OVERVIEW or L.TITLE, 12, -12, 552, 120, L.OVERVIEW_DESC or L.PANEL_DESC)
    UI.CreateButton(intro, L.RESET_MINIMAP_POSITION, 14, -78, 178, 26, function() QMT:ResetMinimapPosition() end)
    UI.CreateButton(intro, L.RESCAN, 204, -78, 124, 26, function() QMT:RescanButtons(true) end)
    UI.CreateButton(intro, L.BUTTON_MANAGER, 340, -78, 142, 26, function() QMT:ShowButtonManager() end)

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
    local s = UI.CreateSection(page, L.MINIMAP, 12, -12, 552, 430, L.MINIMAP_DESC or "")
    local y = s.contentTop or -58
    f.enableEnhanceCheck = UI.CreateCheck(s, L.ENABLE_ENHANCE, 18, y, function() return QMT.db.minimap.enabled end, function(v) QMT.db.minimap.enabled = v end, 320); y = y - 30
    f.squareCheck = MakeControl(f, "minimapDependentControls", UI.CreateCheck, s, L.SQUARE, 18, y, function() return QMT.db.minimap.square end, function(v) QMT.db.minimap.square = v end, 320, nil, L.SQUARE_TIP); y = y - 30
    f.hideCompartmentCheck = MakeControl(f, "minimapDependentControls", UI.CreateCheck, s, L.HIDE_COMPARTMENT, 18, y, function() return QMT.db.minimap.hideCompartment end, function(v) QMT.db.minimap.hideCompartment = v end, 320); y = y - 30
    f.lockMinimapCheck = MakeControl(f, "minimapDependentControls", UI.CreateCheck, s, L.LOCK_MINIMAP, 18, y, function() return QMT.db.minimap.locked end, function(v) QMT.db.minimap.locked = v end, 320, nil, L.UNLOCK_MOVE_TIP); y = y - 44

    f.borderPresetDropdown = MakeControl(f, "minimapDependentControls", UI.CreateDropdown, s, L.BORDER_STYLE, 18, y, 136, 190, MakeBorderOptions(), GetBorderLabel, SetBorderPreset); y = y - 52
    f.minimapScaleSlider = MakeControl(f, "minimapDependentControls", UI.CreateSlider, s, L.MINIMAP_SCALE, 18, y, 136, 220, 0.7, 2.0, 0.05, function() return QMT.db.minimap.scale end, function(v) QMT.db.minimap.scale = v end, function(v) return string.format("%.2f", v) end); y = y - 54

    UI.CreateButton(s, L.RESET_MINIMAP_POSITION, UI.ControlX(18, 136), y + 4, 190, 26, function() QMT:ResetMinimapPosition() end)
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
    UI.CreateCheck(s, L.SHOW_PHASE_ID, 286, y, function() return QMT.db.display.phaseID end, function(v) QMT.db.display.phaseID = v end, 220, RefreshStatsFromOptions); y = y - 54

    f.fontSizeSlider = UI.CreateSlider(s, L.FONT_SIZE, 18, -246, 130, 220, 8, 22, 1, function() return QMT.db.display.fontSize end, function(v) QMT.db.display.fontSize = v end, function(v) return tostring(v) end, RefreshStatsFromOptions)
    UI.CreateSlider(s, L.COORDS_DECIMALS or "Coords decimals", 18, -306, 130, 220, 0, 2, 1, function() return QMT.db.display.coordsDecimals or 1 end, function(v) QMT.db.display.coordsDecimals = v end, function(v) return tostring(v) end, RefreshStatsFromOptions)
end

local function AddBagPage(f, page)
    local s = UI.CreateSection(page, L.BUTTONS, 12, -12, 552, 474, L.BUTTONS_DESC or "")
    local y = s.contentTop or -58
    f.collectButtonsCheck = UI.CreateCheck(s, L.COLLECT_BUTTONS, 18, y, function() return QMT.db.bag.enabled end, function(v) QMT.db.bag.enabled = v end, 360); y = y - 30
    f.autoCloseCheck = MakeControl(f, "bagDependentControls", UI.CreateCheck, s, L.AUTO_CLOSE, 18, y, function() return QMT.db.bag.autoClose end, function(v) QMT.db.bag.autoClose = v end, 360); y = y - 54
    f.buttonScaleSlider = MakeControl(f, "bagDependentControls", UI.CreateSlider, s, L.BUTTON_SCALE, 18, y, 132, 220, 0.7, 1.4, 0.05, function() return QMT.db.bag.buttonScale end, function(v) QMT.db.bag.buttonScale = v end, function(v) return string.format("%.2f", v) end); y = y - 56
    f.buttonsPerRowSlider = MakeControl(f, "bagDependentControls", UI.CreateSlider, s, L.BUTTONS_PER_ROW, 18, y, 132, 220, 1, 10, 1, function() return QMT.db.bag.buttonsPerRow end, function(v) QMT.db.bag.buttonsPerRow = v end, function(v) return tostring(v) end); y = y - 60

    UI.CreateButton(s, L.RESCAN, 18, y, 128, 26, function() QMT:RescanButtons(true) end)
    UI.CreateButton(s, L.BUTTON_MANAGER, 158, y, 142, 26, function() QMT:ShowButtonManager() end)
    y = y - 48
    f.excludeEditBox = MakeControl(f, "bagDependentControls", UI.CreateEditBox, s, L.EXCLUDE, 18, y, 132, 340, function() return QMT.db.bag.exclude or "" end, function(v) QMT.db.bag.exclude = v; QMT:InvalidateExcludeCache() end, function() QMT:RestoreCollectedButtons(); QMT:ApplyAll() end)
end

local function AddFlightPage(f, page)
    local s = UI.CreateSection(page, L.FLIGHT_SECTION, 12, -12, 552, 402, L.FLIGHT_DESC or "")
    local y = s.contentTop or -58
    f.flightCenterCheck = MakeControl(f, "minimapDependentControls", UI.CreateCheck, s, L.FLIGHT_CENTER, 18, y, function() return QMT.db.minimap.flightCenter end, function(v) QMT.db.minimap.flightCenter = v end, 410, CommitFlightOptions); y = y - 30
    f.flightGatheringCheck = MakeControl(f, "flightDependentControls", UI.CreateCheck, s, L.FLIGHT_GATHERING_ONLY, 38, y, function() return QMT.db.minimap.flightCenterOnlyGathering end, function(v) QMT.db.minimap.flightCenterOnlyGathering = v end, 420, CommitFlightOptions, L.FLIGHT_GATHERING_ONLY_TIP); y = y - 26
    f.gatheringStatusText = UI.CreateFont(s, "GameFontDisableSmall", "", "TOPLEFT", 64, y, 448)
    f.gatheringStatusText:SetWordWrap(true)
    function QMT:RefreshGatheringProfessionStatus()
        if f.gatheringStatusText and self.GetGatheringProfessionStatusText then
            f.gatheringStatusText:SetText(self:GetGatheringProfessionStatusText())
        end
    end
    QMT:RefreshGatheringProfessionStatus()
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
        {key = "enUS", label = L.LANGUAGE_EN},
    }, function() return QMT:GetLanguageLabel(QMT.db and QMT.db.ui and QMT.db.ui.language or "AUTO") end, function(key) QMT:SetUILanguage(key) end, function() end); y = y - 52

    UI.CreateCheck(s, L.SHOW_CPU_USAGE, 18, y, function() return QMT.db.performance and QMT.db.performance.disableCPUProfiling ~= false end, function(v) QMT.db.performance = QMT.db.performance or {}; QMT.db.performance.disableCPUProfiling = v and true or false; QMT:ApplyCPUProfilerSetting("user") end, 420, function() end); y = y - 48
    UI.CreateButton(s, L.RESET, 18, y, 128, 26, function() QMT:ResetDefaults() end)
    UI.CreateButton(s, L.RELOAD, 158, y, 128, 26, function() ReloadUI() end)
end

local function SelectPage(f, id)
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
    b:SetScript("OnClick", function() SelectPage(f, id) end)
    f.tabs[id] = b
    return b
end

function QMT:RefreshOptionsControlState()
    local f = self.optionsFrame
    local db = self.db
    if not f or not db then return end
    local minimapEnabled = db.minimap and db.minimap.enabled == true
    local flightEnabled = minimapEnabled and db.minimap and db.minimap.flightCenter == true
    local bagEnabled = db.bag and db.bag.enabled == true
    UI.SetControlsEnabled(f.minimapDependentControls, minimapEnabled)
    UI.SetControlsEnabled(f.flightDependentControls, flightEnabled)
    UI.SetControlsEnabled(f.bagDependentControls, bagEnabled)
    if f.borderPresetDropdown and self.RefreshBorderPresetControls then self:RefreshBorderPresetControls() end
    if self.RefreshGatheringProfessionStatus then self:RefreshGatheringProfessionStatus() end
end

function QMT:CreateOptionsFrame()
    if self.optionsFrame then return self.optionsFrame end
    local f = CreateFrame("Frame", "QFXMinimapToolsOptionsFrame", UIParent, BACKDROP_TEMPLATE)
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
    f.bagDependentControls = {}

    local tabInfo = {
        {"overview", L.OVERVIEW or "Overview"},
        {"minimap", L.MINIMAP},
        {"stats", L.STATS},
        {"bag", L.BUTTONS},
        {"flight", L.FLIGHT_SECTION},
        {"advanced", L.ADVANCED or "Advanced"},
    }
    for i, info in ipairs(tabInfo) do CreateTab(f, info[1], info[2], i) end

    for _, info in ipairs(tabInfo) do f.pages[info[1]] = CreatePage(f.content) end
    AddOverviewPage(f, f.pages.overview)
    AddMinimapPage(f, f.pages.minimap)
    AddStatsPage(f, f.pages.stats)
    AddBagPage(f, f.pages.bag)
    AddFlightPage(f, f.pages.flight)
    AddAdvancedPage(f, f.pages.advanced)

    f.bottomHint = UI.CreateFont(f, "GameFontDisableSmall", L.COMMAND_HINT, "BOTTOMLEFT", 26, 18, 470)
    local reloadBtn = UI.CreateButton(f, L.RELOAD, 0, 0, 90, 24, function() ReloadUI() end)
    reloadBtn:ClearAllPoints()
    reloadBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 18)
    local resetBtn = UI.CreateButton(f, L.RESET, 0, 0, 90, 24, function() QMT:ResetDefaults() end)
    resetBtn:ClearAllPoints()
    resetBtn:SetPoint("RIGHT", reloadBtn, "LEFT", -10, 0)

    self.optionsFrame = f
    SelectPage(f, "overview")
    self:RefreshOptionsControlState()
    return f
end

function QMT:ShowOptions()
    self:CreateOptionsFrame():Show()
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
        return true
    end

    if C_Timer and not self.settingsRegisterRetryQueued then
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
