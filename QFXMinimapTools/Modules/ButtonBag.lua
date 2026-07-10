local ADDON_NAME, QMT = ...
QMT = QMT or {}
_G.QFXMinimapTools = QMT

local L = setmetatable({}, { __index = function(_, key) return QMT.L and QMT.L[key] end })
local SafeCall = QMT.SafeCall
local IsDescendant = QMT.IsDescendant
local ApplyFontStringFont = QMT.ApplyFontStringFont

-- Minimap button bag
-- ############################################################
local builtinIgnore = {
    MiniMapTracking = true,
    MiniMapMailFrame = true,
    MiniMapWorldMapButton = true,
    MinimapZoomIn = true,
    MinimapZoomOut = true,
    GameTimeFrame = true,
    TimeManagerClockButton = true,
    QueueStatusButton = true,
    QueueStatusMinimapButton = true,
    AddonCompartmentFrame = true,
    MiniMapInstanceDifficulty = true,
    GuildInstanceDifficulty = true,
    MiniMapChallengeMode = true,
    ExpansionLandingPageMinimapButton = true,
    GarrisonLandingPageMinimapButton = true,
    CraftingOrderFrame = true,
    ProfessionsCustomerOrdersFrame = true,
    ProfessionsCustomerOrders_MinimapButton = true,
}

function QMT:RememberButtonName(name)
    if not name or name == "" or builtinIgnore[name] or name:find("QFXMinimapTools") then return end
    self.knownButtonNames = self.knownButtonNames or {}
    self.knownButtonNames[name] = true
end

function QMT:GetKnownButtonList()
    self.knownButtonNames = self.knownButtonNames or {}
    for _, button in ipairs(self.collectedButtons or {}) do
        local name = button and button.GetName and button:GetName() or nil
        if name and not builtinIgnore[name] then self:RememberButtonName(name) end
    end
    local list = {}
    for name in pairs(self.knownButtonNames or {}) do table.insert(list, name) end
    table.sort(list, function(a, b) return a:lower() < b:lower() end)
    return list
end

function QMT:GetExcludeTable()
    local bag = self.db and self.db.bag
    if not bag then return builtinIgnore end
    if self.excludeCache and self.excludeCacheText == bag.exclude and self.excludeCacheManual == bag.manualExclude then
        return self.excludeCache
    end
    local t = {}
    for name in string.gmatch(bag.exclude or "", "[^,%s]+") do t[name] = true end
    if type(bag.manualExclude) == "table" then
        for name, excluded in pairs(bag.manualExclude) do if excluded then t[name] = true end end
    end
    for name in pairs(builtinIgnore) do t[name] = true end
    t.QFXMinimapToolsButton = true
    t.QFXMinimapToolsBag = true
    self.excludeCache = t
    self.excludeCacheText = bag.exclude
    self.excludeCacheManual = bag.manualExclude
    return t
end

function QMT:InvalidateExcludeCache()
    self.excludeCache = nil
    self.excludeCacheText = nil
    self.excludeCacheManual = nil
end

local function FrameName(frame)
    return frame and frame.GetName and frame:GetName() or nil
end

function QMT:LooksLikeMinimapButton(frame)
    if type(frame) ~= "table" or not frame.GetName or not frame.IsObjectType then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    local name = FrameName(frame)
    if not name or name == "" then return false end
    if name:find("QFXMinimapTools") then return false end
    self:RememberButtonName(name)
    local exclude = self:GetExcludeTable()
    if exclude[name] then return false end
    local w, h = frame:GetSize()
    if not w or not h or w < 8 or h < 8 or w > 70 or h > 70 then return false end
    if name:match("^HandyNotes") or name:match("^TomTom") or name:match("^HereBeDragons") or name:match("^GatherMate") then return false end
    if name:match("^LibDBIcon") or name:find("Minimap") or name:find("MiniMap") or name:find("MapIcon") or name:find("MinimapButton") or name:find("MinimapIcon") or name:find("_Minimap") or name:find("%-Minimap") then
        return true
    end
    return false
end

local function SaveButtonHitInfo(button)
    if not button then return nil end
    local w, h = button.GetSize and button:GetSize()
    local hit
    if button.GetHitRectInsets then
        local l, r, t, b = button:GetHitRectInsets()
        hit = {l, r, t, b}
    end
    return {width = w, height = h, hitInsets = hit}
end

local function RestoreButtonHitInfo(button, info)
    if not button or not info then return end
    if info.width and info.height and button.SetSize then
        SafeCall(button.SetSize, button, info.width, info.height)
    end
    if info.hitInsets and button.SetHitRectInsets then
        SafeCall(button.SetHitRectInsets, button, unpack(info.hitInsets))
    end
end

function QMT:MakeCollectedButtonEasyToMouse(button)
    if not button then return end
    local minSize = 30
    local w, h = button.GetSize and button:GetSize()
    if w and h and button.SetSize and (w < minSize or h < minSize) then
        SafeCall(button.SetSize, button, math.max(w, minSize), math.max(h, minSize))
    end
    if button.SetHitRectInsets then
        -- Some addon buttons use a small clickable sub-region. Expanding the hit rect
        -- makes hovering/clicking feel like the reference bag: move onto the icon and it works.
        SafeCall(button.SetHitRectInsets, button, -8, -8, -8, -8)
    end
    if button.EnableMouse then button:EnableMouse(true) end
end

local function ForwardCollectedButtonScript(cell, scriptName, ...)
    local target = cell and cell.qfxTarget
    if not target then return end
    local script = target.GetScript and target:GetScript(scriptName)
    if script then SafeCall(script, target, ...) end
end

local BAG_FRAME_STRATA = "HIGH"
local BAG_FRAME_LEVEL = 450

function QMT:GetButtonCell(button)
    if not button or not self.bagFrame then return nil end
    self.buttonCells = self.buttonCells or {}
    local cell = self.buttonCells[button]
    if not cell then
        cell = CreateFrame("Button", nil, self.bagFrame)
        cell:SetFrameStrata(BAG_FRAME_STRATA)
        cell:RegisterForClicks("AnyUp")
        cell:EnableMouse(true)
        cell:SetScript("OnEnter", function(self) ForwardCollectedButtonScript(self, "OnEnter") end)
        cell:SetScript("OnLeave", function(self) ForwardCollectedButtonScript(self, "OnLeave") end)
        cell:SetScript("OnMouseDown", function(self, mouseButton) ForwardCollectedButtonScript(self, "OnMouseDown", mouseButton) end)
        cell:SetScript("OnMouseUp", function(self, mouseButton) ForwardCollectedButtonScript(self, "OnMouseUp", mouseButton) end)
        cell:SetScript("OnClick", function(self, mouseButton, down)
            local target = self.qfxTarget
            if not target then return end
            local script = target.GetScript and target:GetScript("OnClick")
            if script then
                SafeCall(script, target, mouseButton, down)
            elseif target.Click then
                SafeCall(target.Click, target, mouseButton)
            end
        end)
        self.buttonCells[button] = cell
    end
    -- Keep collected minimap buttons in their original style; only the minimap frame
    -- and Blizzard minimap controls are skinned by QFX.
    cell.qfxTarget = button
    return cell
end

function QMT:HideUnusedButtonCells(active)
    if not self.buttonCells then return end
    for button, cell in pairs(self.buttonCells) do
        if not active or not active[button] then
            cell.qfxTarget = nil
            cell:Hide()
        end
    end
end

function QMT:CreateBagFrames()
    if self.bagButton then return end
    local button = CreateFrame("Button", "QFXMinimapToolsButton", Minimap or UIParent)
    button:SetSize(22, 22)
    button:SetHitRectInsets(-8, -8, -8, -8)
    button:SetFrameStrata("HIGH")
    button:SetFrameLevel(300)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- Fixed Q trigger: no drag registration. It always stays at the left-middle edge.

    -- No round icon frame: only a clickable Q printed on the left border line.
    button.letter = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.letter:SetPoint("CENTER", 0, 0)
    button.letter:SetText("Q")
    do
        local font, size, flags = button.letter:GetFont()
        ApplyFontStringFont(button.letter, font, 16, flags or "OUTLINE")
    end
    button.letter:SetTextColor(0.35, 0.70, 1.00, 1)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L.TITLE)
        GameTooltip:AddLine(L.LEFT_TIP, 1, 1, 1)
        GameTooltip:AddLine(L.RIGHT_TIP, 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
        QMT:CheckAutoCloseBag()
    end)
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then QMT:ToggleOptions() else QMT:ToggleBag() end
    end)
    button:SetScript("OnDragStart", nil)
    button:SetScript("OnDragStop", nil)
    self.bagButton = button

    local bag = CreateFrame("Frame", "QFXMinimapToolsBag", UIParent)
    bag:SetFrameStrata(BAG_FRAME_STRATA)
    bag:SetFrameLevel(BAG_FRAME_LEVEL)
    bag:SetClampedToScreen(true)
    -- No backdrop by default: expanded state shows only collected icons, closer to the reference bag style.
    bag.emptyText = bag:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bag.emptyText:SetPoint("CENTER")
    bag.emptyText:SetText(L.BAG_EMPTY)
    bag.emptyText:Hide()
    bag:EnableMouse(true)
    bag:Hide()
    bag:SetScript("OnLeave", function() QMT:CheckAutoCloseBag() end)
    self.bagFrame = bag
end


function QMT:PlaceBagButton()
    if not self.bagButton or not Minimap then return end
    local db = self.db.bag
    -- Fixed Q trigger: always left-middle on the square minimap border.
    -- This avoids saved drag offsets placing the bag trigger in odd locations.
    db.mainButtonEdge = "LEFT"
    db.mainButtonOffset = 0
    db.mainButtonOffsetY = 0
    self.bagButton:ClearAllPoints()
    self.bagButton:SetPoint("CENTER", Minimap, "LEFT", -1, 0)
    self.bagButton:SetShown(db.enabled)
end


function QMT:IsButtonCurrentlyOnMinimap(button)
    if not button or not Minimap then return false end
    if button.IsShown and not button:IsShown() then return false end
    local parent = button.GetParent and button:GetParent()
    if parent == Minimap or parent == MinimapCluster or IsDescendant(Minimap, button) then return true end
    local bx, by = button.GetCenter and button:GetCenter()
    local mx, my = Minimap:GetCenter()
    if bx and by and mx and my then
        local dx, dy = bx - mx, by - my
        -- Only collect buttons that are actually displayed around the minimap.
        return (dx * dx + dy * dy) <= (220 * 220)
    end
    return false
end

function QMT:CollectButton(button)
    if not button or self.collectedMap[button] or button == self.bagButton or button == self.bagFrame then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    if button.IsProtected and button:IsProtected() then return false end
    if not self:IsButtonCurrentlyOnMinimap(button) then return false end
    if not self:LooksLikeMinimapButton(button) then return false end
    local name = FrameName(button)
    local exclude = self:GetExcludeTable()
    if name and exclude[name] then return false end
    self:RememberButtonName(name)
    local hitInfo = SaveButtonHitInfo(button)
    self.originalButtons[button] = {
        parent = button:GetParent(),
        point = {button:GetPoint(1)},
        scale = button:GetScale(),
        shown = button.IsShown and button:IsShown(),
        width = hitInfo and hitInfo.width,
        height = hitInfo and hitInfo.height,
        hitInsets = hitInfo and hitInfo.hitInsets,
    }
    button:SetParent(self.bagFrame)
    button:SetFrameStrata(BAG_FRAME_STRATA)
    if button.SetFrameLevel then button:SetFrameLevel((self.bagFrame:GetFrameLevel() or BAG_FRAME_LEVEL) + 1) end
    button:SetIgnoreParentScale(false)
    button:SetScale(self.db.bag.buttonScale)
    self:MakeCollectedButtonEasyToMouse(button)
    if button.Show then button:Show() end
    button:ClearAllPoints()
    self.collectedMap[button] = true
    table.insert(self.collectedButtons, button)
    return true
end

function QMT:CollectLibDBIconButtons()
    if not LibStub then return end
    local lib = LibStub:GetLibrary("LibDBIcon-1.0", true)
    if not lib or not lib.GetButtonList or not lib.GetMinimapButton then return end
    local ok, list = pcall(lib.GetButtonList, lib)
    if not ok or type(list) ~= "table" then return end
    for _, name in ipairs(list) do
        local okButton, button = pcall(lib.GetMinimapButton, lib, name)
        if okButton and button then self:CollectButton(button) end
    end
end


function QMT:CollectLibMapButtonButtons()
    if not LibStub then return end
    local lib = LibStub:GetLibrary("LibMapButton-1.1", true)
    if not lib or type(lib.buttons) ~= "table" then return end
    for _, button in pairs(lib.buttons) do
        if button then self:CollectButton(button) end
    end
end


function QMT:ScanMinimapChildren()
    if Minimap then
        local children = {Minimap:GetChildren()}
        for _, child in ipairs(children) do self:CollectButton(child) end
    end
    if MinimapCluster then
        local children = {MinimapCluster:GetChildren()}
        for _, child in ipairs(children) do self:CollectButton(child) end
    end
end

function QMT:RescanButtons(force)
    if InCombatLockdown and InCombatLockdown() then return end
    if not self.db.bag.enabled or not self.bagFrame then return end
    if not force and self.rescanQueued then return end
    if not force and C_Timer and C_Timer.After then
        self.rescanQueued = true
        C_Timer.After(0.20, function()
            QMT.rescanQueued = false
            QMT:RescanButtons(true)
        end)
        return
    end
    self.rescanQueued = false
    self:CollectLibDBIconButtons()
    self:CollectLibMapButtonButtons()
    self:ScanMinimapChildren()
    -- 1.0.4: no broad EnumerateFrames scan by default. The bag now only collects buttons
    -- that are visibly attached to / around the minimap, avoiding unrelated UI frames.
    table.sort(self.collectedButtons, function(a, b) return (FrameName(a) or "") < (FrameName(b) or "") end)
    self.hasScannedButtons = true
    self:LayoutBag()
end

function QMT:LayoutBag()
    if InCombatLockdown and InCombatLockdown() then return end
    if not self.bagFrame or not self.bagButton then return end
    local db = self.db.bag
    local buttons = {}
    local exclude = self:GetExcludeTable()
    for _, button in ipairs(self.collectedButtons or {}) do
        local name = FrameName(button)
        if button and name and not exclude[name] then table.insert(buttons, button) end
    end

    local total = #buttons
    local cols = math.max(1, math.min(math.floor(db.buttonsPerRow or 8), math.max(total, 1)))
    local scale = db.buttonScale or 1
    local cell = math.floor(30 * scale + 0.5)
    local rows = math.max(1, math.ceil(math.max(total, 1) / cols))
    local width = total == 0 and 160 or cols * cell
    local height = total == 0 and 24 or rows * cell

    self.bagFrame:SetSize(width, height)
    self.bagFrame:ClearAllPoints()
    local edge = "LEFT"
    local onRight = true
    -- Fixed left-side Q: expand to the OUTSIDE of the minimap, not into the map.
    -- The bag's right edge attaches to the Q button's left edge, and icons grow leftward.
    self.bagFrame:SetPoint("TOPRIGHT", self.bagButton, "TOPLEFT", -6, 9)

    if self.bagFrame.emptyText then
        self.bagFrame.emptyText:SetShown(total == 0)
        self.bagFrame.emptyText:ClearAllPoints()
        self.bagFrame.emptyText:SetPoint("CENTER")
    end

    local activeCells = {}
    for index, button in ipairs(buttons) do
        local col = (index - 1) % cols
        local row = math.floor((index - 1) / cols)
        local cellFrame = self:GetButtonCell(button)
        activeCells[button] = true
        cellFrame:SetParent(self.bagFrame)
        cellFrame:SetFrameStrata(BAG_FRAME_STRATA)
        if cellFrame.SetFrameLevel then cellFrame:SetFrameLevel((self.bagFrame:GetFrameLevel() or BAG_FRAME_LEVEL) + 1) end
        cellFrame:SetSize(cell, cell)
        cellFrame:ClearAllPoints()
        if onRight then
            cellFrame:SetPoint("TOPRIGHT", self.bagFrame, "TOPRIGHT", -col * cell, -row * cell)
        else
            cellFrame:SetPoint("TOPLEFT", self.bagFrame, "TOPLEFT", col * cell, -row * cell)
        end
        cellFrame:Show()

        button:SetParent(cellFrame)
        button:SetFrameStrata(BAG_FRAME_STRATA)
        if button.SetFrameLevel then button:SetFrameLevel((cellFrame:GetFrameLevel() or 501) + 1) end
        button:SetScale(scale)
        self:MakeCollectedButtonEasyToMouse(button)
        if button.Show then button:Show() end
        button:ClearAllPoints()
        button:SetPoint("CENTER", cellFrame, "CENTER", 0, 0)
    end
    self:HideUnusedButtonCells(activeCells)
end

function QMT:ToggleBag()
    if not self.db.bag.enabled then return end
    if self.bagFrame:IsShown() then
        self.bagFrame:Hide()
        self:HideUnusedButtonCells(nil)
    else
        self:RescanButtons(true)
        self.bagFrame:Show()
        self:LayoutBag()
    end
end

function QMT:CheckAutoCloseBag()
    if not self.db.bag.autoClose or not self.bagFrame or not self.bagFrame:IsShown() then return end
    C_Timer.After(0.15, function()
        if not QMT.bagFrame or not QMT.bagFrame:IsShown() then return end
        if GetMouseFoci then
            for _, frame in ipairs(GetMouseFoci() or {}) do
                if IsDescendant(QMT.bagFrame, frame) or IsDescendant(QMT.bagButton, frame) then return end
            end
        elseif GetMouseFocus then
            local frame = GetMouseFocus()
            if IsDescendant(QMT.bagFrame, frame) or IsDescendant(QMT.bagButton, frame) then return end
        end
        QMT.bagFrame:Hide()
        QMT:HideUnusedButtonCells(nil)
    end)
end


function QMT:RestoreCollectedButtons()
    if InCombatLockdown and InCombatLockdown() then return end
    if not self.collectedButtons then return end
    for _, button in ipairs(self.collectedButtons) do
        local info = self.originalButtons and self.originalButtons[button]
        if button and info then
            RestoreButtonHitInfo(button, info)
            button:SetParent(info.parent or Minimap)
            button:SetScale(info.scale or 1)
            button:ClearAllPoints()
            if info.point and info.point[1] then
                button:SetPoint(unpack(info.point))
            else
                button:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
            end
            if info.shown == false and button.Hide then button:Hide() elseif button.Show then button:Show() end
        end
    end
    self:HideUnusedButtonCells(nil)
    self.collectedButtons = {}
    self.collectedMap = {}
    self.originalButtons = {}
    self.hasScannedButtons = false
    self.knownButtonNames = self.knownButtonNames or {}
end

function QMT:ApplyBagSettings()
    self:CreateBagFrames()
    self:PlaceBagButton()
    if not self.db.bag.enabled then
        if self.bagFrame then self.bagFrame:Hide() end
        self:RestoreCollectedButtons()
        return
    end
    if self.hasScannedButtons then
        self:LayoutBag()
    else
        self:RescanButtons(true)
    end
end

-- ############################################################
-- Button selection panel
-- ############################################################
function QMT:IsButtonManuallyExcluded(name)
    return type(self.db.bag.manualExclude) == "table" and self.db.bag.manualExclude[name] == true
end

function QMT:SetButtonManualCollect(name, collect)
    if not name or name == "" then return end
    self.db.bag.manualExclude = self.db.bag.manualExclude or {}
    if collect then
        self.db.bag.manualExclude[name] = nil
    else
        self.db.bag.manualExclude[name] = true
    end
    self:InvalidateExcludeCache()
    self:RestoreCollectedButtons()
    self:RescanButtons(true)
    if self.buttonManager and self.buttonManager:IsShown() then self:RefreshButtonManager() end
end

function QMT:CreateButtonManager()
    if self.buttonManager then return self.buttonManager end
    local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
    local f = CreateFrame("Frame", "QFXMinimapToolsButtonManager", UIParent, backdropTemplate)
    f:SetSize(470, 500)
    f:SetPoint("CENTER", 0, 20)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 24,
        insets = {left = 6, right = 6, top = 6, bottom = 6},
    })

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 26, -16)
    title:SetWidth(360)
    title:SetJustifyH("LEFT")
    title:SetText(L.BUTTON_MANAGER)
    title:SetTextColor(1, 0.82, 0)
    f.qfxTitle = title

    local tip = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tip:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    tip:SetWidth(418)
    tip:SetJustifyH("LEFT")
    tip:SetWordWrap(true)
    tip:SetText(L.BUTTON_MANAGER_TIP)
    f.qfxTip = tip

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    local listFrame = CreateFrame("Frame", nil, f, backdropTemplate)
    listFrame:SetPoint("TOPLEFT", 24, -78)
    listFrame:SetSize(422, 342)
    if listFrame.SetBackdrop then
        listFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = {left = 3, right = 3, top = 3, bottom = 3},
        })
        if listFrame.SetBackdropColor then listFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.55) end
        if listFrame.SetBackdropBorderColor then listFrame:SetBackdropBorderColor(0.55, 0.45, 0.22, 0.85) end
    end
    f.listFrame = listFrame

    f.rows = {}
    local function SmallButton(parent, text, x, y, w, h, onClick)
        local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        b:SetPoint("TOPLEFT", x, y)
        b:SetSize(w, h)
        b:SetText(text)
        b:SetScript("OnClick", onClick)
        return b
    end

    for i = 1, 14 do
        local cb = CreateFrame("CheckButton", nil, listFrame, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 12, -9 - (i - 1) * 23)
        cb:SetSize(24, 24)
        if cb.Text and cb.Text.ClearAllPoints then cb.Text:ClearAllPoints() end
        if cb.Text then
            cb.Text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
            cb.Text:SetWidth(360)
            cb.Text:SetJustifyH("LEFT")
        end
        cb:SetScript("OnClick", function(self)
            if self.buttonName then QMT:SetButtonManualCollect(self.buttonName, self:GetChecked()) end
        end)
        f.rows[i] = cb
    end

    f.prev = SmallButton(f, L.PREV, 82, -438, 86, 24, function()
        QMT.buttonManagerPage = math.max(1, (QMT.buttonManagerPage or 1) - 1)
        QMT:RefreshButtonManager()
    end)
    f.next = SmallButton(f, L.NEXT, 178, -438, 86, 24, function()
        QMT.buttonManagerPage = (QMT.buttonManagerPage or 1) + 1
        QMT:RefreshButtonManager()
    end)
    f.rescan = SmallButton(f, L.RESCAN, 274, -438, 118, 24, function()
        QMT:RestoreCollectedButtons(); QMT:RescanButtons(true); QMT:RefreshButtonManager()
    end)
    f.pageText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.pageText:SetPoint("BOTTOM", 0, 18)
    self.buttonManager = f
    return f
end

function QMT:RefreshButtonManager()
    local f = self.buttonManager
    if not f then return end
    local list = self:GetKnownButtonList()
    local perPage = #f.rows
    local maxPage = math.max(1, math.ceil(math.max(#list, 1) / perPage))
    self.buttonManagerPage = Clamp(self.buttonManagerPage or 1, 1, maxPage)
    local startIndex = (self.buttonManagerPage - 1) * perPage + 1
    for i, row in ipairs(f.rows) do
        local name = list[startIndex + i - 1]
        row.buttonName = name
        if name then
            row:Show()
            row.Text:SetText(name)
            row:SetChecked(not self:IsButtonManuallyExcluded(name))
        else
            row:Hide()
        end
    end
    f.prev:SetEnabled(self.buttonManagerPage > 1)
    f.next:SetEnabled(self.buttonManagerPage < maxPage)
    f.pageText:SetText(string.format("%d / %d", self.buttonManagerPage, maxPage))
end

function QMT:ShowButtonManager()
    self:RescanButtons(true)
    local f = self:CreateButtonManager()
    self.buttonManagerPage = self.buttonManagerPage or 1
    self:RefreshButtonManager()
    f:Show()
end

-- ############################################################
