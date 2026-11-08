local ADDON_NAME, QMT = ...
QMT = QMT or {}
_G.QFXMinimapTools = QMT

local L = setmetatable({}, { __index = function(_, key) return QMT.L and QMT.L[key] end })
local SafeCall = QMT.SafeCall
local IsDescendant = QMT.IsDescendant
local ApplyFontStringFont = QMT.ApplyFontStringFont
local Clamp = QMT.Clamp

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

local function IsOwnButton(name)
    return name and name:find("QFXMinimapTools", 1, true) ~= nil
end

function QMT:RememberButtonName(name, frame)
    if not name or name == "" or builtinIgnore[name] or IsOwnButton(name) then return end
    self.knownButtonNames = self.knownButtonNames or {}
    local object = frame and frame.dataObject
    local label = type(object) == "table" and object.label
    self.knownButtonNames[name] = type(label) == "string" and label ~= "" and label or self.knownButtonNames[name] or true
end

function QMT:GetButtonDisplayName(name)
    local key = name:gsub("^LibDBIcon10_", ""):gsub("^Lib_GPI_Minimap_", "")
    key = key:gsub("[_%-]?[Mm]ini[Mm]ap[Bb]utton$", ""):gsub("[_%-]?[Mm]ini[Mm]ap[Ii]con$", "")
    key = key:gsub("[_%-]?[Mm]ini[Mm]ap$", "")
    if key == "" then key = name end
    local getInfo = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
    local _, title = SafeCall(getInfo, key)
    local label = self.knownButtonNames and self.knownButtonNames[name]
    title = type(title) == "string" and title ~= "" and title or type(label) == "string" and label or key
    return (title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
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

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function CapturePoints(frame)
    local points = {}
    if not frame or not frame.GetNumPoints or not frame.GetPoint then return points end
    local count = frame:GetNumPoints() or 0
    for i = 1, count do
        points[#points + 1] = {frame:GetPoint(i)}
    end
    return points
end

local function RestorePoints(frame, points, fallbackParent)
    if not frame or not frame.ClearAllPoints or not frame.SetPoint then return end
    frame:ClearAllPoints()
    local restored = false
    for _, point in ipairs(points or {}) do
        if point and point[1] then
            SafeCall(frame.SetPoint, frame, unpack(point))
            restored = true
        end
    end
    if not restored and fallbackParent then
        SafeCall(frame.SetPoint, frame, "CENTER", fallbackParent, "CENTER", 0, 0)
    end
end

local function IsMouseEnabled(frame)
    if frame and frame.IsMouseEnabled then
        local enabled = SafeCall(frame.IsMouseEnabled, frame)
        if enabled ~= nil then return enabled and true or false end
    end
    return nil
end

function QMT:LooksLikeMinimapButton(frame)
    if type(frame) ~= "table" or not frame.GetName or not frame.IsObjectType then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    local name = FrameName(frame)
    if not name or name == "" then return false end
    if IsOwnButton(name) then return false end
    local w, h = frame:GetSize()
    if IsSecret(w) or IsSecret(h) then return false end
    if not w or not h or w < 8 or h < 8 or w > 70 or h > 70 then return false end
    if name:match("^HandyNotes") or name:match("^TomTom") or name:match("^HereBeDragons") or name:match("^GatherMate") then return false end
    if name:match("^LibDBIcon") or name:find("Minimap") or name:find("MiniMap") or name:find("MapIcon") or name:find("MinimapButton") or name:find("MinimapIcon") or name:find("_Minimap") or name:find("%-Minimap") then
        self:RememberButtonName(name, frame)
        return not self:GetExcludeTable()[name]
    end
    return false
end

local function SaveButtonHitInfo(button)
    if not button then return nil end
    local w, h
    if button.GetSize then w, h = button:GetSize() end
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
    local w, h
    if button.GetSize then w, h = button:GetSize() end
    if not IsSecret(w) and not IsSecret(h) and w and h and button.SetSize and (w < minSize or h < minSize) then
        SafeCall(button.SetSize, button, math.max(w, minSize), math.max(h, minSize))
    end
    if button.SetHitRectInsets then
        -- The 30x30 cell already provides a comfortable target. Do not expand into
        -- adjacent cells, which can make neighboring buttons steal each other's clicks.
        SafeCall(button.SetHitRectInsets, button, 0, 0, 0, 0)
    end
    if button.EnableMouse then SafeCall(button.EnableMouse, button, true) end
end

local function ForwardCollectedButtonScript(cell, scriptName, ...)
    local target = cell and cell.qfxTarget
    if not target then return end
    local script = target.GetScript and target:GetScript(scriptName)
    if script then SafeCall(script, target, ...) end
end

local BAG_FRAME_STRATA = "HIGH"
local BAG_FRAME_LEVEL = 450
local PIN_GAP = 2
local PIN_BAG_GAP = 4
local Q_HIT_PADDING = 8
local Q_ICON_SIZE = 16
local pinnedTextureHooks = setmetatable({}, { __mode = "k" })

local function ApplyBagButtonHitPadding(button, pinTails)
    -- A pinned column uses the space normally reserved for Q's larger hit area.
    local top = pinTails and pinTails.UP and 0 or -Q_HIT_PADDING
    local bottom = pinTails and pinTails.DOWN and 0 or -Q_HIT_PADDING
    button:SetHitRectInsets(-Q_HIT_PADDING, -Q_HIT_PADDING, top, bottom)
end

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
        cell:SetScript("OnLeave", function(self)
            ForwardCollectedButtonScript(self, "OnLeave")
            -- Leaving the bag through a collected icon must also arm auto-close;
            -- the parent frame's OnLeave is not guaranteed to fire in that path.
            QMT:CheckAutoCloseBag()
        end)
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

function QMT:RequestBagLayout()
    if InCombatLockdown and InCombatLockdown() then
        self.pendingBagLayout = true
        return
    end
    if self.bagLayoutQueued then return end
    self.bagLayoutQueued = true
    local function Flush()
        QMT.bagLayoutQueued = false
        if QMT.db and QMT.db.bag and QMT.db.bag.enabled and QMT.bagFrame
            and (QMT.bagFrame:IsShown() or QMT.bagPinFrame) then
            SafeCall(QMT.LayoutBag, QMT)
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Flush) else Flush() end
end

function QMT:CreateBagFrames()
    if self.bagButton then return end
    local button = CreateFrame("Button", "QFXMinimapToolsButton", Minimap or UIParent)
    button:SetSize(22, 22)
    ApplyBagButtonHitPadding(button)
    button:SetFrameStrata("HIGH")
    button:SetFrameLevel(300)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    -- The Q trigger can be dragged vertically along the left edge. Its saved
    -- offset decides whether the bag opens upward or downward from the button.

    -- No round icon frame: only a clickable Q printed on the left border line.
    button.letter = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.letter:SetPoint("CENTER", 0, 0)
    button.letter:SetText("Q")
    do
        local font, _, flags = button.letter:GetFont()
        ApplyFontStringFont(button.letter, font, Q_ICON_SIZE, flags or "OUTLINE")
    end
    button.letter:SetTextColor(0.35, 0.70, 1.00, 1)

    button:SetScript("OnEnter", function(self)
        if self.qfxDragging then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L.TITLE)
        GameTooltip:AddLine(L.LEFT_TIP, 1, 1, 1)
        GameTooltip:AddLine(L.RIGHT_TIP, 1, 1, 1)
        GameTooltip:AddLine(L.BAG_DRAG_TIP, 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
        QMT:CheckAutoCloseBag()
    end)
    button:SetScript("OnClick", function(self, mouseButton)
        if self.qfxSuppressClick then
            self.qfxSuppressClick = nil
            return
        end
        if mouseButton == "RightButton" then QMT:ToggleOptions() else QMT:ToggleBag() end
    end)
    button:SetScript("OnDragStart", function(self)
        QMT:StartBagButtonDrag(self)
    end)
    button:SetScript("OnDragStop", function(self)
        QMT:StopBagButtonDrag(self)
    end)
    button:SetScript("OnShow", function()
        if QMT.bagPinFrame then
            QMT.bagPinFrame:Show()
            QMT:RequestBagLayout()
        end
    end)
    button:SetScript("OnHide", function()
        if QMT.bagPinFrame then QMT.bagPinFrame:Hide() end
    end)
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


function QMT:GetBagButtonDragBounds()
    local mapH = Minimap and Minimap.GetHeight and Minimap:GetHeight() or 0
    -- During early login the minimap may not be sized yet. Returning nil keeps
    -- the saved offset intact instead of clamping it to a temporary zero.
    if mapH <= 0 then return nil end
    local buttonH = self.bagButton and self.bagButton.GetHeight and self.bagButton:GetHeight() or 22
    local limit = math.max(0, (mapH - buttonH) * 0.5)
    local lower, upper = -limit, limit
    if self.bagPinExtent then
        local _, centerY = Minimap:GetCenter()
        local scale = Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale()
        if centerY and scale > 0 then
            local extent = self.bagPinExtent
            if extent.UP > 0 then upper = math.min(upper, UIParent:GetHeight() / scale - centerY - extent.UP / scale - buttonH * 0.5) end
            if extent.DOWN > 0 then lower = math.max(lower, -centerY + extent.DOWN / scale + buttonH * 0.5) end
            if lower > upper then
                local offset = Clamp((lower + upper) * 0.5, -limit, limit)
                return offset, offset
            end
        end
    end
    return lower, upper
end

function QMT:GetBagButtonOffsetY()
    local bag = self.db and self.db.bag
    local offset = tonumber(bag and bag.mainButtonOffsetY) or 0
    local lower, upper = self:GetBagButtonDragBounds()
    if lower then offset = Clamp(offset, lower, upper) end
    return offset
end

-- Negative offsets sit below the minimap centre, so the bag grows upward;
-- zero or positive offsets keep the original downward growth.
function QMT:IsBagExpandingUpward()
    return self:GetBagButtonOffsetY() < -0.5
end

function QMT:StartBagButtonDrag(button)
    if InCombatLockdown and InCombatLockdown() then return end
    button = button or self.bagButton
    if not button or not Minimap then return end
    if button.qfxDragging then return end
    local _, cursorY = GetCursorPosition()
    button.qfxDragging = true
    button.qfxMoved = false
    button.qfxDragStartCursorY = cursorY
    button.qfxDragStartOffset = self:GetBagButtonOffsetY()
    button.qfxDragLastOffset = button.qfxDragStartOffset
    button.qfxDragUpward = self:IsBagExpandingUpward()
    button:SetScript("OnUpdate", function() self:UpdateBagButtonDrag() end)
    if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
end

function QMT:UpdateBagButtonDrag()
    local button = self.bagButton
    if not button or not button.qfxDragging or not Minimap then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local _, cursorY = GetCursorPosition()
    if not cursorY or not button.qfxDragStartCursorY then return end
    local scale = Minimap.GetEffectiveScale and Minimap:GetEffectiveScale() or 1
    if not scale or scale <= 0 then scale = 1 end
    local offset = (button.qfxDragStartOffset or 0) + (cursorY - button.qfxDragStartCursorY) / scale
    local lower, upper = self:GetBagButtonDragBounds()
    if lower then offset = Clamp(offset, lower, upper) end
    if math.abs((button.qfxDragLastOffset or 0) - offset) < 0.01 then return end
    button.qfxDragLastOffset = offset
    button.qfxMoved = true
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "LEFT", -1, offset)
    if self.db and self.db.bag then self.db.bag.mainButtonOffsetY = offset end
    local upward = offset < -0.5
    if upward ~= button.qfxDragUpward then
        button.qfxDragUpward = upward
        if self.bagFrame and self.bagFrame:IsShown() then SafeCall(self.LayoutBag, self) end
    end
end

function QMT:StopBagButtonDrag(button)
    button = button or self.bagButton
    if not button then return end
    button:SetScript("OnUpdate", nil)
    button.qfxDragging = false
    local moved = button.qfxMoved
    local draggedOffset = button.qfxDragLastOffset
    button.qfxMoved = false
    button.qfxDragStartCursorY = nil
    button.qfxDragStartOffset = nil
    button.qfxDragLastOffset = nil
    if not moved then return end
    if self.db and self.db.bag then self.db.bag.mainButtonOffsetY = draggedOffset end
    if not (InCombatLockdown and InCombatLockdown()) then
        self:PlaceBagButton()
        if self.bagFrame and self.bagFrame:IsShown() then SafeCall(self.LayoutBag, self) end
    end
    -- Swallow the click that follows a real drag; clear it on the next frame
    -- in case the client does not deliver OnClick after OnDragStop.
    button.qfxSuppressClick = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if QMT.bagButton then QMT.bagButton.qfxSuppressClick = nil end
        end)
    end
end

function QMT:PlaceBagButton()
    if not self.bagButton or not Minimap then return end
    local db = self.db.bag
    local flightActive = self.IsOutdoorFlightCenterActive and self:IsOutdoorFlightCenterActive()
    -- The Q trigger stays on the left edge; only its vertical offset is
    -- free so the bag can open upward or downward from the button.
    db.mainButtonEdge = "LEFT"
    db.mainButtonOffset = 0
    local offsetY = self:GetBagButtonOffsetY()
    self.bagButton:ClearAllPoints()
    self.bagButton:SetPoint("CENTER", Minimap, "LEFT", -1, offsetY)
    self.bagButton:SetShown(db.enabled and not flightActive)
    if flightActive and self.bagFrame then self:CloseBag() end
    SafeCall(self.LayoutIndicatorColumn, self)
end


function QMT:IsButtonCurrentlyOnMinimap(button)
    if not button or not Minimap then return false end
    if button.IsForbidden and button:IsForbidden() then return false end
    local shown = not button.IsShown or button:IsShown()
    if IsSecret(shown) or not shown then return false end
    local parent = button.GetParent and button:GetParent()
    if parent == Minimap or parent == MinimapCluster or IsDescendant(Minimap, button) then return true end
    if not button.GetCenter then return false end
    local bx, by = button:GetCenter()
    local mx, my = Minimap:GetCenter()
    if IsSecret(bx) or IsSecret(by) or IsSecret(mx) or IsSecret(my) then return false end
    if bx and by and mx and my then
        local buttonScale, mapScale = button:GetEffectiveScale(), Minimap:GetEffectiveScale()
        if IsSecret(buttonScale) or IsSecret(mapScale) or mapScale <= 0 then return false end
        local ratio = buttonScale / mapScale
        bx, by = bx * ratio, by * ratio
        local dx, dy = bx - mx, by - my
        -- Only collect buttons that are actually displayed around the minimap.
        return (dx * dx + dy * dy) <= (220 * 220)
    end
    return false
end

function QMT:CollectButton(button)
    if not button or self.collectedMap[button] or button == self.bagButton or button == self.bagFrame then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    if button.IsForbidden and button:IsForbidden() then return false end
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
        points = CapturePoints(button),
        scale = button.GetScale and button:GetScale() or 1,
        shown = button.IsShown and button:IsShown(),
        width = hitInfo and hitInfo.width,
        height = hitInfo and hitInfo.height,
        hitInsets = hitInfo and hitInfo.hitInsets,
        frameStrata = button.GetFrameStrata and button:GetFrameStrata() or nil,
        frameLevel = button.GetFrameLevel and button:GetFrameLevel() or nil,
        ignoreParentScale = button.IsIgnoringParentScale and SafeCall(button.IsIgnoringParentScale, button) or nil,
        mouseEnabled = IsMouseEnabled(button),
    }
    button:SetParent(self.bagFrame)
    button:SetFrameStrata(BAG_FRAME_STRATA)
    if button.SetFrameLevel then button:SetFrameLevel((self.bagFrame:GetFrameLevel() or BAG_FRAME_LEVEL) + 1) end
    if button.SetIgnoreParentScale then SafeCall(button.SetIgnoreParentScale, button, false) end
    button:SetScale(self.db.bag.buttonScale)
    self:MakeCollectedButtonEasyToMouse(button)
    button:ClearAllPoints()
    self.collectedMap[button] = true
    table.insert(self.collectedButtons, button)

    if button.HookScript and not button.QFXMinimapToolsVisibilityHooked then
        button:HookScript("OnShow", function(btn)
            if QMT.collectedMap and QMT.collectedMap[btn] then QMT:RequestBagLayout() end
        end)
        button:HookScript("OnHide", function(btn)
            if QMT.collectedMap and QMT.collectedMap[btn] then QMT:RequestBagLayout() end
        end)
        button.QFXMinimapToolsVisibilityHooked = true
    end
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
    if InCombatLockdown and InCombatLockdown() then
        self.pendingBagRescan = true
        return
    end
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

function QMT:RestorePinnedButtonStyle(button, original)
    local pin = original and original.pinIcon
    if not pin then return end
    self:RestoreIconBackgroundAndBorder(button, true)
    RestorePoints(pin.texture, pin.points, button)
    pin.texture:SetSize(pin.width, pin.height)
    RestoreButtonHitInfo(button, original)
    original.pinIcon = nil
end

function QMT:ApplyPinnedButtonStyle(button, q)
    local original = self.originalButtons[button]
    if not original then return false end
    local icon = button.icon or button.Icon
    if original.pinIcon and original.pinIcon.texture ~= icon then
        self:RestorePinnedButtonStyle(button, original)
    end
    if type(icon) ~= "table" or not icon.IsObjectType or not icon:IsObjectType("Texture") then return false end
    local pin = original.pinIcon
    if not pin then
        local width, height = icon:GetSize()
        if width <= 0 or height <= 0 then return false end
        pin = {texture = icon, points = CapturePoints(icon), width = width, height = height}
        original.pinIcon = pin
    end
    if hooksecurefunc and button.CreateTexture and not pinnedTextureHooks[button] then
        -- Skin addons can add a border after the first layout. Wait until the
        -- new texture has been configured before checking its decoration.
        hooksecurefunc(button, "CreateTexture", function(source)
            local saved = QMT.originalButtons and QMT.originalButtons[source]
            if saved and saved.pinIcon then QMT:RequestBagLayout() end
        end)
        pinnedTextureHooks[button] = true
    end
    self:StripIconBackgroundAndBorder(button, icon)
    button:SetSize(q:GetSize())
    local size = Q_ICON_SIZE / math.max(pin.width, pin.height)
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetSize(pin.width * size, pin.height * size)
    return true
end

function QMT:PlaceCollectedButton(button, parent, scale)
    local cell = self:GetButtonCell(button)
    cell:SetParent(parent)
    cell:SetFrameLevel(parent:GetFrameLevel() + 1)
    cell:ClearAllPoints()

    button:SetParent(cell)
    button:SetFrameStrata(BAG_FRAME_STRATA)
    if button.SetFrameLevel then button:SetFrameLevel(cell:GetFrameLevel() + 1) end
    button:SetScale(scale)
    self:MakeCollectedButtonEasyToMouse(button)
    button:ClearAllPoints()
    button:SetPoint("CENTER", cell, "CENTER", 0, 0)
    return cell
end

function QMT:LayoutBag()
    if self.IsOutdoorFlightCenterActive and self:IsOutdoorFlightCenterActive() then
        self:CloseBag()
    end
    if InCombatLockdown and InCombatLockdown() then
        self.pendingBagLayout = true
        return
    end
    if not self.bagFrame or not self.bagButton or not self.db.bag.enabled then return end
    local db = self.db.bag
    local buttons = {}
    local pinned = {}
    local exclude = self:GetExcludeTable()
    for _, button in ipairs(self.collectedButtons or {}) do
        local name = FrameName(button)
        if name and not exclude[name] then
            local isPinned = self:IsButtonPinned(name)
            local parent = self.bagFrame
            if isPinned then
                if not self.bagPinFrame then
                    local frame = CreateFrame("Frame", nil, UIParent)
                    frame:SetFrameStrata(BAG_FRAME_STRATA)
                    frame:SetFrameLevel(BAG_FRAME_LEVEL)
                    frame:SetShown(self.bagButton:IsVisible())
                    self.bagPinFrame = frame
                end
                parent = self.bagPinFrame
            else
                self:RestorePinnedButtonStyle(button, self.originalButtons[button])
            end
            if button:IsShown() then
                table.insert(isPinned and pinned or buttons, button)
            elseif button:GetParent() ~= parent then
                -- Keep a hidden icon under its container so its owner's next
                -- Show() can fire OnShow even after its old cell is hidden.
                button:SetParent(parent)
                button:ClearAllPoints()
            end
        end
    end

    local scale = db.buttonScale or 1
    local cell = math.floor(30 * scale + 0.5)
    local activeCells = {}
    local bagGap = 6
    local hadPins = self.bagPinExtent ~= nil
    self.bagPinTails, self.bagPinExtent = nil, nil
    if #pinned > 0 then
        local q = self.bagButton
        local qScale = q:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local maxWidth = cell
        local direction = db.pinnedDirection
        local upward = direction == "UP"
        local near, far = upward and "BOTTOM" or "TOP", upward and "TOP" or "BOTTOM"
        local sign = upward and 1 or -1
        local previous = q
        local extent = 0
        for _, button in ipairs(pinned) do
            local cellFrame = self:PlaceCollectedButton(button, self.bagPinFrame, scale)
            local width, height
            if self:ApplyPinnedButtonStyle(button, q) then
                button:SetScale(qScale)
                width, height = q:GetWidth() * qScale, q:GetHeight() * qScale
            else
                width, height = math.max(cell, button:GetWidth() * scale), math.max(cell, button:GetHeight() * scale)
            end
            cellFrame:SetSize(width, height)
            maxWidth = math.max(maxWidth, width)
            extent = extent + height + PIN_GAP
            cellFrame:SetPoint(near, previous, far, 0, sign * PIN_GAP)
            cellFrame:Show()
            activeCells[button] = true
            previous = cellFrame
        end
        self.bagPinTails = { [direction] = previous }
        self.bagPinExtent = { UP = upward and extent or 0, DOWN = upward and 0 or extent }
        bagGap = math.max(bagGap, (maxWidth - q:GetWidth() * qScale) * 0.5 + PIN_BAG_GAP)
    end
    if hadPins or self.bagPinExtent then
        ApplyBagButtonHitPadding(self.bagButton, self.bagPinTails)
        self:PlaceBagButton()
    end

    local total = #buttons
    local cols = math.max(1, math.min(math.floor(db.buttonsPerRow or 8), math.max(total, 1)))
    local rows = math.max(1, math.ceil(math.max(total, 1) / cols))
    local width = total == 0 and 160 or cols * cell
    local height = total == 0 and 24 or rows * cell

    self.bagFrame:SetSize(width, height)
    self.bagFrame:ClearAllPoints()
    -- EUI-style expansion: when the Q trigger sits in the lower half of the
    -- minimap, the grid grows upward; otherwise it keeps growing downward.
    -- Either way the icons stay outside the map on the left.
    local upward = self:IsBagExpandingUpward()
    if upward then
        self.bagFrame:SetPoint("BOTTOMRIGHT", self.bagButton, "BOTTOMLEFT", -bagGap, -9)
    else
        self.bagFrame:SetPoint("TOPRIGHT", self.bagButton, "TOPLEFT", -bagGap, 9)
    end

    if self.bagFrame.emptyText then
        self.bagFrame.emptyText:SetShown(total == 0)
        self.bagFrame.emptyText:ClearAllPoints()
        self.bagFrame.emptyText:SetPoint("CENTER")
    end

    for index, button in ipairs(buttons) do
        local col = (index - 1) % cols
        local row = math.floor((index - 1) / cols)
        local cellFrame = self:PlaceCollectedButton(button, self.bagFrame, scale)
        cellFrame:SetSize(cell, cell)
        activeCells[button] = true
        if upward then
            -- Start at the bottom edge so the first button stays nearest the Q.
            cellFrame:SetPoint("BOTTOMRIGHT", self.bagFrame, "BOTTOMRIGHT", -col * cell, row * cell)
        else
            cellFrame:SetPoint("TOPRIGHT", self.bagFrame, "TOPRIGHT", -col * cell, -row * cell)
        end
        cellFrame:Show()
    end
    self:HideUnusedButtonCells(activeCells)
end

function QMT:ToggleBag()
    if self.IsOutdoorFlightCenterActive and self:IsOutdoorFlightCenterActive() then return end
    if not self.db.bag.enabled then return end
    if self.bagFrame:IsShown() then
        self:CloseBag()
    else
        self:RescanButtons(true)
        self.bagFrame:Show()
        self:LayoutBag()
        if self.db.bag.autoClose then self:StartBagAutoCloseWatcher() end
    end
end

function QMT:IsMouseOverBag()
    if not self.bagFrame then return false end
    if GetMouseFoci then
        for _, frame in ipairs(GetMouseFoci() or {}) do
            if IsDescendant(self.bagFrame, frame) then return true end
            if self.bagButton and IsDescendant(self.bagButton, frame) then return true end
            if self.bagPinFrame and IsDescendant(self.bagPinFrame, frame) then return true end
        end
        return false
    end
    local frame = GetMouseFocus and GetMouseFocus()
    if frame and self.bagPinFrame and IsDescendant(self.bagPinFrame, frame) then return true end
    if MouseIsOver then
        if MouseIsOver(self.bagFrame) then return true end
        if self.bagButton and MouseIsOver(self.bagButton) then return true end
        return false
    end
    if not frame then return false end
    return IsDescendant(self.bagFrame, frame)
        or (self.bagButton and IsDescendant(self.bagButton, frame))
        or false
end

function QMT:CloseBag()
    if self.bagFrame then self.bagFrame:Hide() end
    self:StopBagAutoCloseWatcher()
end

function QMT:StartBagAutoCloseWatcher()
    if not self.bagFrame then return end
    self.bagAutoCloseElapsed = 0
    self.bagFrame:SetScript("OnUpdate", function(_, elapsed)
        QMT:UpdateBagAutoClose(elapsed)
    end)
end

function QMT:StopBagAutoCloseWatcher()
    if self.bagFrame then self.bagFrame:SetScript("OnUpdate", nil) end
    self.bagAutoCloseElapsed = 0
end

function QMT:UpdateBagAutoClose(elapsed)
    if not self.db or not self.db.bag.autoClose or not self.bagFrame or not self.bagFrame:IsShown() then
        self:StopBagAutoCloseWatcher()
        return
    end
    self.bagAutoCloseElapsed = (self.bagAutoCloseElapsed or 0) + (elapsed or 0)
    if self.bagAutoCloseElapsed < 0.20 then return end
    self.bagAutoCloseElapsed = 0
    if self:IsMouseOverBag() then return end
    self:CloseBag()
end

function QMT:CheckAutoCloseBag()
    if not self.db.bag.autoClose or not self.bagFrame or not self.bagFrame:IsShown() then return end
    C_Timer.After(0.15, function()
        if not QMT.bagFrame or not QMT.bagFrame:IsShown() then return end
        if QMT:IsMouseOverBag() then return end
        QMT:CloseBag()
    end)
end


function QMT:RestoreCollectedButtons()
    if InCombatLockdown and InCombatLockdown() then
        self.pendingBagRestore = true
        return
    end
    if not self.collectedButtons then return end
    for _, button in ipairs(self.collectedButtons) do
        local info = self.originalButtons and self.originalButtons[button]
        if button and info then
            self:RestorePinnedButtonStyle(button, info)
            RestoreButtonHitInfo(button, info)
            SafeCall(button.SetParent, button, info.parent or Minimap)
            if button.SetScale then SafeCall(button.SetScale, button, info.scale or 1) end
            if button.SetFrameStrata and info.frameStrata then SafeCall(button.SetFrameStrata, button, info.frameStrata) end
            if button.SetFrameLevel and info.frameLevel then SafeCall(button.SetFrameLevel, button, info.frameLevel) end
            if button.SetIgnoreParentScale and info.ignoreParentScale ~= nil then SafeCall(button.SetIgnoreParentScale, button, info.ignoreParentScale) end
            if button.EnableMouse and info.mouseEnabled ~= nil then SafeCall(button.EnableMouse, button, info.mouseEnabled) end
            RestorePoints(button, info.points, Minimap)
            -- Visibility belongs to the button's addon. Only restore a button that
            -- QFX itself had to reveal in older versions; never force a current hidden
            -- button to show and override its owner's state machine.
            if info.shown == false and button.Hide then SafeCall(button.Hide, button) end
        end
    end
    self:HideUnusedButtonCells(nil)
    if self.bagPinExtent then
        self.bagPinTails, self.bagPinExtent = nil, nil
        ApplyBagButtonHitPadding(self.bagButton)
        self:PlaceBagButton()
    end
    self.collectedButtons = {}
    self.collectedMap = {}
    self.originalButtons = {}
    self.hasScannedButtons = false
    self.pendingBagRestore = false
    self.knownButtonNames = self.knownButtonNames or {}
end

function QMT:ProcessPendingBagOperations()
    if InCombatLockdown and InCombatLockdown() then return end
    local restore = self.pendingBagRestore
    local rescan = self.pendingBagRescan
    local layout = self.pendingBagLayout
    self.pendingBagRestore = false
    self.pendingBagRescan = false
    self.pendingBagLayout = false

    if restore then self:RestoreCollectedButtons() end
    if self.db and self.db.bag and self.db.bag.enabled then
        if rescan then
            self:RescanButtons(true)
        elseif layout then
            self:LayoutBag()
        end
    end
end

function QMT:ApplyBagSettings()
    self:CreateBagFrames()
    self:PlaceBagButton()
    if not self.db.bag.enabled then
        self:CloseBag()
        self:RestoreCollectedButtons()
        return
    end
    if self.bagFrame and self.bagFrame:IsShown() then
        if self.db.bag.autoClose then self:StartBagAutoCloseWatcher() else self:StopBagAutoCloseWatcher() end
    end
    if self.hasScannedButtons then
        self:LayoutBag()
    else
        self:RescanButtons(true)
    end
end

-- ############################################################
-- Pinned button settings
-- ############################################################
function QMT:IsButtonPinned(name)
    return not IsOwnButton(name) and self.db.bag.pinnedButtons[name] == true
end

function QMT:SetButtonPinned(name, pinned)
    pinned = pinned == true
    if not name or name == "" or self:IsButtonPinned(name) == pinned then return end
    if pinned and (IsOwnButton(name) or self:GetExcludeTable()[name]) then return end
    self.db.bag.pinnedButtons[name] = pinned or nil
    self:LayoutBag()
end

function QMT:SetPinnedButtonDirection(direction)
    if direction ~= "UP" and direction ~= "DOWN" then return end
    if self.db.bag.pinnedDirection == direction then return end
    self.db.bag.pinnedDirection = direction
    self:LayoutBag()
end

function QMT:GetPinnedButtonCount()
    local count = 0
    local exclude = self:GetExcludeTable()
    for name in pairs(self.db.bag.pinnedButtons) do
        if not exclude[name] and self:IsButtonPinned(name) then count = count + 1 end
    end
    return count
end

function QMT:UpdatePinnableButtonItems(items)
    local pins, exclude = self.db.bag.pinnedButtons, self:GetExcludeTable()
    local seen, counts = {}, {}
    for i = #items, 1, -1 do items[i] = nil end
    local function Add(name)
        if not name or IsOwnButton(name) or exclude[name] or seen[name] then return end
        seen[name] = true
        local label = self:GetButtonDisplayName(name)
        counts[label] = (counts[label] or 0) + 1
        items[#items + 1] = { key = name, label = label }
    end
    for name in pairs(pins) do Add(name) end
    for _, button in ipairs(self.collectedButtons or {}) do
        if button:IsShown() then Add(FrameName(button)) end
    end
    table.sort(items, function(a, b)
        if pins[a.key] ~= pins[b.key] then return pins[a.key] == true end
        local left, right = a.label:lower(), b.label:lower()
        if left == right then return a.key < b.key end
        return left < right
    end)
    for _, item in ipairs(items) do
        if counts[item.label] > 1 then item.tooltip = item.key end
    end
    if #items == 0 then items[1] = { key = "", label = L.PINNED_BUTTONS_EMPTY, disabled = true } end
end

-- ############################################################
