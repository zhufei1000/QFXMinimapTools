local ADDON_NAME, QMT = ...
QMT = QMT or {}
_G.QFXMinimapTools = QMT

local Clamp = QMT.Clamp or function(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end
local Round = QMT.Round or function(value, step)
    step = step or 1
    return math.floor(value / step + 0.5) * step
end

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local UI = QMT.UI or {}
QMT.UI = UI

UI.BACKDROP_TEMPLATE = BACKDROP_TEMPLATE
UI.LAYOUT = {
    panelW = 760,
    panelH = 620,
    sidebarW = 150,
    margin = 18,
    rowH = 28,
    sliderRowH = 46,
    labelW = 140,
    controlW = 190,
    sliderW = 220,
}

local function ApplyBackdrop(frame, kind)
    if not frame or not frame.SetBackdrop then return frame end
    if kind == "panel" then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 },
        })
    elseif kind == "pane" then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        if frame.SetBackdropColor then frame:SetBackdropColor(0.045, 0.045, 0.05, 0.72) end
        if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(0.48, 0.40, 0.20, 0.85) end
    elseif kind == "card" then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 11,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        if frame.SetBackdropColor then frame:SetBackdropColor(0.02, 0.02, 0.025, 0.56) end
        if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(0.24, 0.24, 0.28, 0.95) end
    elseif kind == "dropdown" then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        if frame.SetBackdropColor then frame:SetBackdropColor(0.035, 0.035, 0.04, 0.95) end
        if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(0.42, 0.42, 0.46, 1) end
    end
    return frame
end
UI.ApplyBackdrop = ApplyBackdrop

local function AddTooltip(frame, title, text)
    if not frame or (not title and not text) then return end
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if title then GameTooltip:AddLine(title, 1, 0.82, 0) end
        if text and text ~= "" then GameTooltip:AddLine(text, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
UI.AddTooltip = AddTooltip

local function CreateFont(parent, template, text, point, x, y, width, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    fs:SetPoint(point or "TOPLEFT", x or 0, y or 0)
    if width then fs:SetWidth(width) end
    fs:SetJustifyH(justify or "LEFT")
    fs:SetText(text or "")
    return fs
end
UI.CreateFont = CreateFont

function UI.CreateCard(parent, x, y, w, h, title, desc)
    local card = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    card:SetSize(w, h)
    ApplyBackdrop(card, "card")
    if title then
        card.Title = CreateFont(card, "GameFontNormal", title, "TOPLEFT", 12, -10, w - 24)
        card.Title:SetTextColor(1, 0.82, 0)
    end
    if desc then
        card.Desc = CreateFont(card, "GameFontDisableSmall", desc, "TOPLEFT", 12, title and -30 or -12, w - 24)
        card.Desc:SetJustifyH("LEFT")
        card.Desc:SetWordWrap(true)
    end
    return card
end

function UI.CreateSection(parent, title, x, y, w, h, desc)
    local section = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
    section:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    section:SetSize(w, h)
    ApplyBackdrop(section, "pane")
    section.Title = CreateFont(section, "GameFontNormalLarge", title or "", "TOPLEFT", 14, -12, w - 28)
    section.Title:SetTextColor(1, 0.82, 0)
    local offset = -36
    if desc and desc ~= "" then
        section.Desc = CreateFont(section, "GameFontDisableSmall", desc, "TOPLEFT", 14, -34, w - 28)
        section.Desc:SetJustifyH("LEFT")
        section.Desc:SetWordWrap(true)
        offset = -58
    end
    section.contentTop = offset
    return section
end

local function SetFontStringEnabled(fontString, enabled, r, g, b)
    if not fontString or not fontString.SetTextColor then return end
    if enabled then
        fontString:SetTextColor(r or 1, g or 1, b or 1)
    else
        fontString:SetTextColor(0.55, 0.55, 0.55)
    end
end

function UI.SetControlEnabled(control, enabled)
    if not control then return end
    enabled = enabled and true or false
    if control.Enable and control.Disable then
        if enabled then control:Enable() else control:Disable() end
    elseif control.EnableMouse then
        control:EnableMouse(enabled)
    end
    if control.SetAlpha then control:SetAlpha(enabled and 1 or 0.55) end
    SetFontStringEnabled(control.qfxLabel, enabled, 1, 0.82, 0)
    SetFontStringEnabled(control.Text, enabled)
    SetFontStringEnabled(control.Value, enabled)
    SetFontStringEnabled(control.Low, enabled, 0.75, 0.75, 0.75)
    SetFontStringEnabled(control.High, enabled, 0.75, 0.75, 0.75)
    if control.SetEnabled then control:SetEnabled(enabled) end
    if control.GetName then
        local name = control:GetName()
        local ddButton = name and _G[name .. "Button"]
        if ddButton and ddButton.Enable and ddButton.Disable then
            if enabled then ddButton:Enable() else ddButton:Disable() end
        end
    end
    if control.SetTextColor and control.GetObjectType and control:GetObjectType() == "EditBox" then
        control:SetTextColor(enabled and 1 or 0.55, enabled and 1 or 0.55, enabled and 1 or 0.55, 1)
    end
end

function UI.SetControlsEnabled(list, enabled)
    if not list then return end
    for _, control in ipairs(list) do UI.SetControlEnabled(control, enabled) end
end

function UI.CreateRowLabel(parent, text, x, y, width)
    local fs = CreateFont(parent, "GameFontNormal", text or "", "TOPLEFT", x, y - 3, width or UI.LAYOUT.labelW)
    fs:SetHeight(UI.LAYOUT.rowH)
    fs:SetJustifyV("MIDDLE")
    fs:SetTextColor(1, 0.82, 0)
    fs:SetWordWrap(true)
    return fs
end

function UI.ControlX(x, labelW)
    return x + (labelW or UI.LAYOUT.labelW) + 8
end

function UI.CreateCheck(parent, text, x, y, getValue, setValue, width, onCommit, tooltip)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetSize(24, 24)
    if cb.Text and cb.Text.ClearAllPoints then cb.Text:ClearAllPoints() end
    if cb.Text then
        cb.Text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        cb.Text:SetWidth(width or 320)
        cb.Text:SetJustifyH("LEFT")
        cb.Text:SetText(text or "")
    end
    cb:SetChecked(getValue and getValue() or false)
    cb:SetScript("OnClick", function(self)
        if setValue then setValue(self:GetChecked() and true or false) end
        if onCommit then onCommit() elseif QMT.CommitOptions then QMT:CommitOptions() else QMT:ApplyAll() end
    end)
    AddTooltip(cb, text, tooltip)
    return cb
end

local sliderIndex = 0
local function FormatLimit(value)
    if type(value) ~= "number" then return tostring(value or "") end
    if value == math.floor(value) then return tostring(value) end
    return string.format("%.2f", value)
end

function UI.CreateSlider(parent, label, x, y, labelW, sliderW, minV, maxV, step, getValue, setValue, formatText, onCommit, tooltip)
    sliderIndex = sliderIndex + 1
    labelW = labelW or UI.LAYOUT.labelW
    sliderW = sliderW or UI.LAYOUT.sliderW
    local rowLabel = UI.CreateRowLabel(parent, label, x, y, labelW)
    local controlX = UI.ControlX(x, labelW)
    local name = "QFXMinimapToolsSlider" .. sliderIndex
    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", controlX, y - 2)
    s:SetWidth(sliderW)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    if _G[name .. "Text"] then _G[name .. "Text"]:SetText("") end
    s.Low = _G[name .. "Low"]
    s.High = _G[name .. "High"]
    if s.Low then
        s.Low:ClearAllPoints()
        s.Low:SetPoint("TOPLEFT", s, "BOTTOMLEFT", -1, -3)
        s.Low:SetText(FormatLimit(minV))
    end
    if s.High then
        s.High:ClearAllPoints()
        s.High:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", 1, -3)
        s.High:SetText(FormatLimit(maxV))
    end
    s.Value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    s.Value:SetPoint("TOP", s, "BOTTOM", 0, -3)
    s.Value:SetWidth(64)
    s.Value:SetJustifyH("CENTER")
    s.qfxLabel = rowLabel
    local function UpdateValue(value)
        s.Value:SetText(formatText and formatText(value) or tostring(value))
    end
    local initial = getValue and getValue() or minV
    s:SetValue(Clamp(initial, minV, maxV))
    UpdateValue(s:GetValue())

    local pendingCommit = false
    local function CommitIfNeeded(force)
        if force or not (IsMouseButtonDown and IsMouseButtonDown("LeftButton")) then
            pendingCommit = false
            if onCommit then onCommit() elseif QMT.CommitOptions then QMT:CommitOptions() else QMT:ApplyAll() end
        else
            pendingCommit = true
        end
    end

    s:SetScript("OnValueChanged", function(_, value)
        value = Round(value, step)
        if setValue then setValue(value) end
        UpdateValue(value)
        CommitIfNeeded(false)
    end)
    s:SetScript("OnMouseUp", function()
        if pendingCommit then CommitIfNeeded(true) end
    end)
    AddTooltip(s, label, tooltip)
    return s
end

function UI.CreateButton(parent, text, x, y, w, h, onClick, tooltip)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT", x, y)
    b:SetSize(w, h)
    b:SetText(text or "")
    b:SetScript("OnClick", onClick)
    AddTooltip(b, text, tooltip)
    return b
end

local dropdownIndex = 0
function UI.CreateDropdown(parent, labelText, x, y, labelW, w, options, getValue, setValue, onCommit, tooltip)
    labelW = labelW or UI.LAYOUT.labelW
    w = w or UI.LAYOUT.controlW
    local label = UI.CreateRowLabel(parent, labelText, x, y, labelW)
    local controlX = UI.ControlX(x, labelW)

    if UIDropDownMenu_Initialize and UIDropDownMenu_SetWidth and UIDropDownMenu_SetText and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton then
        dropdownIndex = dropdownIndex + 1
        local name = "QFXMinimapToolsDropdown" .. dropdownIndex
        local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
        dd:SetPoint("TOPLEFT", parent, "TOPLEFT", controlX - 18, y + 6)
        UIDropDownMenu_SetWidth(dd, w)
        if UIDropDownMenu_SetButtonWidth then UIDropDownMenu_SetButtonWidth(dd, w) end
        if UIDropDownMenu_JustifyText then UIDropDownMenu_JustifyText(dd, "LEFT") end
        dd.qfxLabel = label
        dd.SetText = function(self, text) UIDropDownMenu_SetText(self, text or "") end
        dd.GetText = function(self) if UIDropDownMenu_GetText then return UIDropDownMenu_GetText(self) end return "" end
        UIDropDownMenu_SetText(dd, getValue and getValue() or "")
        UIDropDownMenu_Initialize(dd, function(_, level)
            for _, opt in ipairs(options or {}) do
                if opt and opt.key then
                    local selected = opt.key == (dd.qfxSelectedKey or nil)
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = opt.label or opt.key
                    info.checked = selected or ((getValue and tostring(getValue()) == tostring(opt.label or opt.key)) and true or false)
                    info.func = function()
                        dd.qfxSelectedKey = opt.key
                        if setValue then setValue(opt.key) end
                        UIDropDownMenu_SetText(dd, opt.label or opt.key)
                        if CloseDropDownMenus then CloseDropDownMenus() end
                        if onCommit then onCommit() elseif QMT.CommitOptions then QMT:CommitOptions() else QMT:ApplyAll() end
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end)
        AddTooltip(dd, labelText, tooltip)
        return dd
    end

    local button = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", controlX, y - 1)
    button:SetSize(w, 24)
    button:SetFrameLevel((parent:GetFrameLevel() or 1) + 2)
    ApplyBackdrop(button, "dropdown")
    button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.Text:SetPoint("LEFT", 8, 0)
    button.Text:SetPoint("RIGHT", -24, 0)
    button.Text:SetJustifyH("LEFT")
    button.qfxLabel = label
    button.SetText = function(self, text) self.Text:SetText(text or "") end
    button.GetText = function(self) return self.Text:GetText() end
    button.Arrow = button:CreateTexture(nil, "OVERLAY")
    button.Arrow:SetSize(16, 16)
    button.Arrow:SetPoint("RIGHT", -5, 0)
    button.Arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    button.Highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.Highlight:SetAllPoints(button)
    button.Highlight:SetColorTexture(1, 1, 1, 0.08)

    local menu = CreateFrame("Frame", nil, button, BACKDROP_TEMPLATE)
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel((button:GetFrameLevel() or 1) + 20)
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
    ApplyBackdrop(menu, "panel")
    menu:Hide()
    button.qfxMenu = menu

    local rowH = 22
    local count = 0
    for _, opt in ipairs(options or {}) do
        if opt and opt.key then
            count = count + 1
            local row = CreateFrame("Button", nil, menu)
            row:SetPoint("TOPLEFT", 8, -6 - (count - 1) * rowH)
            row:SetSize(w - 16, rowH)
            row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.Text:SetPoint("LEFT", 6, 0)
            row.Text:SetText(opt.label or opt.key)
            row.Highlight = row:CreateTexture(nil, "HIGHLIGHT")
            row.Highlight:SetAllPoints(row)
            row.Highlight:SetColorTexture(1, 1, 1, 0.12)
            row:SetScript("OnClick", function()
                if setValue then setValue(opt.key) end
                button:SetText(opt.label or opt.key)
                menu:Hide()
                if onCommit then onCommit() elseif QMT.CommitOptions then QMT:CommitOptions() else QMT:ApplyAll() end
            end)
        end
    end
    menu:SetSize(w, math.max(1, count) * rowH + 12)
    button:SetScript("OnClick", function()
        if menu:IsShown() then menu:Hide() else menu:Show() end
    end)
    button:SetScript("OnHide", function() menu:Hide() end)
    button:SetText(getValue and getValue() or "")
    AddTooltip(button, labelText, tooltip)
    return button
end

function UI.CreateEditBox(parent, labelText, x, y, labelW, w, getValue, setValue, onCommit, tooltip)
    local label = UI.CreateRowLabel(parent, labelText, x, y, labelW or UI.LAYOUT.labelW)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetPoint("TOPLEFT", parent, "TOPLEFT", UI.ControlX(x, labelW), y - 1)
    eb:SetSize(w or 280, 22)
    eb:SetAutoFocus(false)
    eb:SetText(getValue and getValue() or "")
    eb:SetCursorPosition(0)
    eb.qfxLabel = label
    local function Commit(self)
        if setValue then setValue(self:GetText() or "") end
        self:ClearFocus()
        if onCommit then onCommit() elseif QMT.CommitOptions then QMT:CommitOptions() else QMT:ApplyAll() end
    end
    eb:SetScript("OnEnterPressed", Commit)
    eb:SetScript("OnEditFocusLost", Commit)
    AddTooltip(eb, labelText, tooltip)
    return eb, label
end
