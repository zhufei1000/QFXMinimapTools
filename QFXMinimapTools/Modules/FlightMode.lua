local ADDON_NAME, QMT = ...
QMT = QMT or {}
_G.QFXMinimapTools = QMT

local L = setmetatable({}, { __index = function(_, key) return QMT.L and QMT.L[key] end })
local SafeCall = QMT.SafeCall
local Clamp = QMT.Clamp

local function Now()
    return GetTime and GetTime() or 0
end

-- Outdoor flight minimap focus mode
-- ############################################################
function QMT:IsOutdoorFlightCenterActive()
    return self.flightModeActive == true
end

local GATHERING_SKILL_IDS = {
    [182] = true, -- Herbalism
    [186] = true, -- Mining
}

local GATHERING_PROFESSION_NAMES = {
    ["Herbalism"] = true,
    ["Mining"] = true,
    ["草药学"] = true,
    ["採藥"] = true,
    ["草藥學"] = true,
    ["采矿"] = true,
    ["採礦"] = true,
}

local function IsGatheringProfessionName(name)
    if type(name) ~= "string" or name == "" then return false end
    if GATHERING_PROFESSION_NAMES[name] then return true end
    local lower = string.lower(name)
    return lower == "herbalism" or lower == "mining"
end

function QMT:RefreshGatheringProfessionCache()
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
        -- Older clients should keep the old behavior instead of disabling flight center forever.
        self.hasGatheringProfession = true
        return true
    end

    local primary1, primary2, archaeology, fishing, cooking = GetProfessions()
    local professionIndexes = {primary1, primary2, archaeology, fishing, cooking}
    local found = false
    for _, professionIndex in ipairs(professionIndexes) do
        if professionIndex then
            local info = {GetProfessionInfo(professionIndex)}
            local first = info[1]
            if type(first) == "table" then
                local name = first.name or first.professionName or first.skillLineName
                if IsGatheringProfessionName(name) then found = true end
                if not found then
                    for _, value in pairs(first) do
                        if GATHERING_SKILL_IDS[tonumber(value or 0) or 0] then found = true break end
                    end
                end
            else
                if IsGatheringProfessionName(first) then found = true end
                if not found then
                    for _, value in ipairs(info) do
                        if GATHERING_SKILL_IDS[tonumber(value or 0) or 0] then found = true break end
                    end
                end
            end
            if found then break end
        end
    end
    self.hasGatheringProfession = found
    return found
end

function QMT:HasGatheringProfession(forceRefresh)
    if forceRefresh or self.hasGatheringProfession == nil then
        return self:RefreshGatheringProfessionCache()
    end
    return self.hasGatheringProfession and true or false
end

function QMT:GetGatheringProfessionStatusText()
    if not self.db or not self.db.minimap or not self.db.minimap.flightCenterOnlyGathering then
        return L.GATHERING_PROFESSION_OFF or "Gathering profession check is disabled."
    end
    if self:HasGatheringProfession() then
        return L.GATHERING_PROFESSION_FOUND or "Herbalism or Mining learned. Flight center can trigger."
    end
    return L.GATHERING_PROFESSION_NOT_FOUND or "No Herbalism or Mining found. Flight center will not trigger while this option is enabled."
end

function QMT:ShouldUseOutdoorFlightCenter()
    local db = self.db and self.db.minimap
    if not db or not db.enabled or db.flightCenter ~= true then return false end
    -- When the option is unticked, profession detection must be bypassed entirely.
    -- This also avoids a stale profession cache preventing non-gatherers from centering.
    local gatheringRestrictionEnabled = db.flightCenterOnlyGathering == true
    if gatheringRestrictionEnabled and self.HasGatheringProfession and not self:HasGatheringProfession() then return false end
    if UnitInVehicle and UnitInVehicle("player") then return false end
    if UnitOnTaxi and UnitOnTaxi("player") then return false end
    local inInstance, instanceType = false, "none"
    if IsInInstance then inInstance, instanceType = IsInInstance() end
    if inInstance or (instanceType and instanceType ~= "none") then return false end
    if IsResting and IsResting() then return false end
    return IsFlying and IsFlying() or false
end

function QMT:CaptureOutdoorFlightReturnState()
    if self.flightReturnState or not Minimap then return end
    self.flightReturnState = {
        alpha = Minimap.GetAlpha and Minimap:GetAlpha() or 1,
        zoom = Minimap.GetZoom and Minimap:GetZoom() or nil,
        bagShown = self.bagFrame and self.bagFrame.IsShown and self.bagFrame:IsShown() or false,
    }
end

local FLIGHT_PIN_NAME_MARKERS = {
    "HandyNotes",
    "TomTom",
    "HereBeDragons",
    "GatherMate",
    "Routes",
    "FarmHud",
    "MinimapPing",
    "QuestBlob",
    "ArchBlob",
}

local function QFXFrameName(frame)
    return frame and frame.GetName and frame:GetName() or nil
end

local function QFXIsForbidden(frame)
    return frame and frame.IsForbidden and frame:IsForbidden()
end

function QMT:IsMinimapContentPin(frame)
    local name = QFXFrameName(frame)
    if type(name) ~= "string" or name == "" then return false end
    for _, marker in ipairs(FLIGHT_PIN_NAME_MARKERS) do
        if name:find(marker, 1, true) then return true end
    end
    return false
end

function QMT:LooksLikeFlightMinimapButton(frame)
    if type(frame) ~= "table" or not frame.IsObjectType then return false end
    if QFXIsForbidden(frame) then return false end
    if frame == Minimap or frame == MinimapCluster or frame == _G.MinimapBackdrop then return false end
    if frame == self.squareBorder or frame == self.minimapMover or frame == self.utilityRow then return false end
    if frame == self.bagButton or (self.collectedMap and self.collectedMap[frame]) then return true end
    if self.statFrames then
        for _, statFrame in pairs(self.statFrames) do
            if frame == statFrame then return false end
        end
    end
    if self.indicatorButtons then
        for _, button in pairs(self.indicatorButtons) do
            if frame == button then return true end
        end
    end

    local name = QFXFrameName(frame)
    if name and name:find("QFXMinimapTools", 1, true) then return false end
    if self:IsMinimapContentPin(frame) then return false end
    if name and self.knownButtonNames and self.knownButtonNames[name] then return true end

    local w, h = frame.GetSize and frame:GetSize()
    local sizeOk = w and h and w >= 8 and h >= 8 and w <= 70 and h <= 70
    if name then
        if name:find("LibDBIcon", 1, true) or name:find("MinimapButton", 1, true) or name:find("MinimapIcon", 1, true)
            or name:find("_Minimap", 1, true) or name:find("%-Minimap") then
            return true
        end
        if sizeOk and (name:find("Minimap", 1, true) or name:find("MiniMap", 1, true)) and frame:IsObjectType("Button") then
            if name == "Minimap" or name == "MinimapCluster" or name == "MinimapBackdrop" then return false end
            return true
        end
    end

    if sizeOk and frame:IsObjectType("Button") then
        local parent = frame.GetParent and frame:GetParent()
        if parent == Minimap or parent == MinimapCluster then return true end
    end
    return false
end

function QMT:HideOutdoorFlightAddonButtons()
    if not self:IsOutdoorFlightCenterActive() then return end

    local seen = {}
    local function HideButton(frame)
        if not frame or seen[frame] or not self:LooksLikeFlightMinimapButton(frame) then return end
        seen[frame] = true
        SafeCall(self.SetFrameFlightSuppressed, self, frame, true)
    end

    for _, button in ipairs(self.collectedButtons or {}) do HideButton(button) end
    if self.buttonCells then
        for _, cell in pairs(self.buttonCells) do HideButton(cell) end
    end

    if LibStub then
        local lib = LibStub:GetLibrary("LibDBIcon-1.0", true)
        if lib and lib.GetButtonList and lib.GetMinimapButton then
            local ok, list = pcall(lib.GetButtonList, lib)
            if ok and type(list) == "table" then
                for _, name in ipairs(list) do
                    local okButton, button = pcall(lib.GetMinimapButton, lib, name)
                    if okButton then HideButton(button) end
                end
            end
        end
        local mapButtonLib = LibStub:GetLibrary("LibMapButton-1.1", true)
        if mapButtonLib and type(mapButtonLib.buttons) == "table" then
            for _, button in pairs(mapButtonLib.buttons) do HideButton(button) end
        end
    end

    if Minimap and Minimap.GetChildren then
        for _, child in ipairs({Minimap:GetChildren()}) do HideButton(child) end
    end
    if MinimapCluster and MinimapCluster.GetChildren then
        for _, child in ipairs({MinimapCluster:GetChildren()}) do HideButton(child) end
    end
end

local function QFXCaptureMouseState(frame)
    if not frame then return nil end
    return {
        mouseEnabled = frame.IsMouseEnabled and SafeCall(frame.IsMouseEnabled, frame),
        mouseClickEnabled = frame.IsMouseClickEnabled and SafeCall(frame.IsMouseClickEnabled, frame),
        mouseMotionEnabled = frame.IsMouseMotionEnabled and SafeCall(frame.IsMouseMotionEnabled, frame),
        mouseWheelEnabled = frame.IsMouseWheelEnabled and SafeCall(frame.IsMouseWheelEnabled, frame),
    }
end

function QMT:DisableFrameFlightMouse(frame)
    if not frame or QFXIsForbidden(frame) then return end
    if self.flightSuppressedFrameStates and self.flightSuppressedFrameStates[frame] then return end
    self.flightMouseStates = self.flightMouseStates or {}
    if not self.flightMouseStates[frame] then
        self.flightMouseStates[frame] = QFXCaptureMouseState(frame)
    end
    if frame.SetMouseClickEnabled then SafeCall(frame.SetMouseClickEnabled, frame, false) end
    if frame.EnableMouseWheel then SafeCall(frame.EnableMouseWheel, frame, false) end
    if frame.SetMouseMotionEnabled then
        if self:ShouldShowOutdoorFlightTooltips() then
            local motion = self.flightMouseStates[frame] and self.flightMouseStates[frame].mouseMotionEnabled
            if motion ~= false then SafeCall(frame.SetMouseMotionEnabled, frame, true) end
        else
            SafeCall(frame.SetMouseMotionEnabled, frame, false)
        end
    end
end

function QMT:DisableFrameTreeFlightMouse(frame)
    if not frame or QFXIsForbidden(frame) then return end
    self:DisableFrameFlightMouse(frame)
    if not frame.GetChildren then return end
    local children = {frame:GetChildren()}
    for i = 1, #children do
        self:DisableFrameTreeFlightMouse(children[i])
    end
end

function QMT:ShouldDisableOutdoorFlightMouse()
    local db = self.db and self.db.minimap
    return db and db.flightDisableMouse ~= false
end

function QMT:ShouldShowOutdoorFlightTooltips()
    local db = self.db and self.db.minimap
    return not self:ShouldDisableOutdoorFlightMouse() or not (db and db.flightHideTooltips == true)
end

function QMT:ApplyOutdoorFlightMousePassthrough()
    if not self:IsOutdoorFlightCenterActive() then return end
    if not self:ShouldDisableOutdoorFlightMouse() then
        self:RestoreOutdoorFlightMousePassthrough()
        return
    end
    if not self:ShouldShowOutdoorFlightTooltips() and GameTooltip and GameTooltip.Hide then
        GameTooltip:Hide()
    end
    self:DisableFrameTreeFlightMouse(Minimap)
    self:DisableFrameFlightMouse(_G.MinimapBackdrop)
    self:DisableFrameTreeFlightMouse(_G.HybridMinimap)
    if MinimapCluster then
        self:DisableFrameTreeFlightMouse(MinimapCluster.MinimapContainer)
    end
    if self.statFrames then
        for _, frame in pairs(self.statFrames) do self:DisableFrameFlightMouse(frame) end
    end
    if self.squareBorder then self:DisableFrameFlightMouse(self.squareBorder) end
    if self.minimapMover then self:DisableFrameFlightMouse(self.minimapMover) end
end

function QMT:RestoreOutdoorFlightMousePassthrough()
    for frame, state in pairs(self.flightMouseStates or {}) do
        if frame and state and not QFXIsForbidden(frame) then
            if frame.EnableMouse and state.mouseEnabled ~= nil then
                SafeCall(frame.EnableMouse, frame, state.mouseEnabled)
            end
            if frame.SetMouseClickEnabled and state.mouseClickEnabled ~= nil then
                SafeCall(frame.SetMouseClickEnabled, frame, state.mouseClickEnabled)
            end
            if frame.SetMouseMotionEnabled and state.mouseMotionEnabled ~= nil then
                SafeCall(frame.SetMouseMotionEnabled, frame, state.mouseMotionEnabled)
            end
            if frame.EnableMouseWheel and state.mouseWheelEnabled ~= nil then
                SafeCall(frame.EnableMouseWheel, frame, state.mouseWheelEnabled)
            end
        end
    end
    self.flightMouseStates = {}
end

function QMT:HideOutdoorFlightMinimapControls()
    if not self:IsOutdoorFlightCenterActive() then return end

    -- Native/static controls may remain attached to MinimapCluster instead of the
    -- moved Minimap. Suppress them in place so no duplicate controls remain at the
    -- original top-right location while the map itself is centered.
    if self.CaptureNativeMinimapControls then SafeCall(self.CaptureNativeMinimapControls, self) end
    for frame in pairs(self.nativeMinimapControls or {}) do
        SafeCall(self.SetFrameFlightSuppressed, self, frame, true)
    end

    if self.GetNativeQueueFrames then
        for _, queue in ipairs(self:GetNativeQueueFrames()) do
            SafeCall(self.SetFrameFlightSuppressed, self, queue, true)
        end
    else
        local queue = self.GetManagedNativeQueueFrame and self:GetManagedNativeQueueFrame()
        if queue then SafeCall(self.SetFrameFlightSuppressed, self, queue, true) end
    end

    if self.GetNativeMailFrames then
        for _, frame in ipairs(self:GetNativeMailFrames()) do
            SafeCall(self.SetFrameFlightSuppressed, self, frame, true)
        end
    end
    if self.GetNativeCraftingOrderFrames then
        for _, frame in ipairs(self:GetNativeCraftingOrderFrames()) do
            SafeCall(self.SetFrameFlightSuppressed, self, frame, true)
        end
    end

    local tracking = self.GetNativeTrackingFrame and self:GetNativeTrackingFrame()
    if tracking then SafeCall(self.SetFrameFlightSuppressed, self, tracking, true) end
    if self.GetNativeDifficultyFrames then
        for _, frame in ipairs(self:GetNativeDifficultyFrames()) do
            SafeCall(self.SetFrameFlightSuppressed, self, frame, true)
        end
    end
    local landing = _G.ExpansionLandingPageMinimapButton
    if landing then SafeCall(self.SetFrameFlightSuppressed, self, landing, true) end

    if self.squareBorder then self.squareBorder:Hide() end
    if self.mailIndicator then self.mailIndicator:Hide() end
    if self.indicatorButtons then
        for _, frame in pairs(self.indicatorButtons) do if frame and frame.Hide then frame:Hide() end end
    end
    if self.utilityRow then self.utilityRow:Hide() end
    if self.utilityTextFrames then
        for _, frame in pairs(self.utilityTextFrames) do if frame and frame.Hide then frame:Hide() end end
    end
    SafeCall(self.StopUtilitySystemHoverTicker, self)
    SafeCall(self.StopUtilityCoordinatesHoverTicker, self)

    if self.bagButton then self.bagButton:Hide() end
    if self.bagFrame then self.bagFrame:Hide() end

    -- Keep only the optional zone/location label. All other addon text belongs to
    -- the normal minimap layout and is suspended during flight focus mode.
    if self.statFrames then
        for key, frame in pairs(self.statFrames) do
            if key ~= "location" and frame and frame.Hide then frame:Hide() end
        end
    end

    self:HideOutdoorFlightAddonButtons()
    self:ApplyOutdoorFlightMousePassthrough()
end

function QMT:ApplyOutdoorFlightCenterVisual()
    if not Minimap or not UIParent or not self.db or not self.db.minimap then return end
    local db = self.db.minimap
    self:CaptureOutdoorFlightReturnState()
    self.flightModeActive = true
    if self.ApplyMinimapMoveMode then SafeCall(self.ApplyMinimapMoveMode, self) end

    local flightScale = Clamp(db.flightScale, 1.00, 3.00)
    local flightPosY = Clamp(db.flightPosY, -240, 40)
    local flightAlpha = Clamp(db.flightAlpha, 0.10, 1.00)
    db.flightScale, db.flightPosY, db.flightAlpha = flightScale, flightPosY, flightAlpha

    Minimap:ClearAllPoints()
    Minimap:SetPoint("TOP", UIParent, "TOP", 0, flightPosY)
    if Minimap.SetScale then Minimap:SetScale(flightScale) end
    if Minimap.SetAlpha then Minimap:SetAlpha(flightAlpha) end
    if Minimap.SetZoom then SafeCall(Minimap.SetZoom, Minimap, 0) end

    if self.RefreshMinimapAttachedElements then
        SafeCall(self.RefreshMinimapAttachedElements, self, true, false)
    else
        SafeCall(self.ApplyQueueStatusButtonPosition, self)
        SafeCall(self.ApplyMailFramePosition, self)
        SafeCall(self.ApplyTrackingButtonPosition, self)
        SafeCall(self.ApplyDifficultyFramePosition, self)
        SafeCall(self.ApplyExpansionLandingPageButtonPosition, self)
        SafeCall(self.UpdateUtilityRow, self)
        SafeCall(self.PlaceBagButton, self)
        if self.statFrames then
            for key in pairs(self.statFrames) do SafeCall(self.PlaceStatFrame, self, key) end
            SafeCall(self.UpdateAllStats, self)
        end
    end
    self:HideOutdoorFlightMinimapControls()
end

function QMT:RestoreOutdoorFlightCenterVisual()
    if not self.flightModeActive then return end
    local db = self.db and self.db.minimap or {}
    local state = self.flightReturnState or {}
    self.flightModeActive = false

    SafeCall(self.RestoreOutdoorFlightMousePassthrough, self)
    SafeCall(self.RestoreAllFlightSuppressedFrames, self)
    if self.SetNativeMinimapControlsHidden then
        SafeCall(self.SetNativeMinimapControlsHidden, self, db.enabled and db.square)
    end
    if Minimap and Minimap.SetAlpha then Minimap:SetAlpha(state.alpha or 1) end
    if Minimap and Minimap.SetZoom and type(state.zoom) == "number" then SafeCall(Minimap.SetZoom, Minimap, state.zoom) end
    if Minimap and Minimap.SetScale then Minimap:SetScale(Clamp(db.scale, 0.50, 2.00)) end
    if self.squareBorder then self.squareBorder:SetShown(db.enabled and db.square) end

    if db.autoSnap then self:ApplySmartTopRightSnap() else self:ApplyManualMinimapPosition() end
    if self.ApplyMinimapMoveMode then SafeCall(self.ApplyMinimapMoveMode, self) end
    if self.RefreshMinimapAttachedElements then
        SafeCall(self.RefreshMinimapAttachedElements, self, true, false)
    else
        SafeCall(self.ApplyQueueStatusButtonPosition, self)
        SafeCall(self.ApplyMailFramePosition, self)
        SafeCall(self.ApplyTrackingButtonPosition, self)
        SafeCall(self.ApplyDifficultyFramePosition, self)
        SafeCall(self.ApplyExpansionLandingPageButtonPosition, self)
        SafeCall(self.UpdateUtilityRow, self)
        SafeCall(self.PlaceBagButton, self)
        if self.statFrames then
            for key in pairs(self.statFrames) do SafeCall(self.PlaceStatFrame, self, key) end
            SafeCall(self.UpdateAllStats, self)
        end
    end

    if state.bagShown and self.db and self.db.bag and self.db.bag.enabled and self.bagFrame then
        self.bagFrame:Show()
        SafeCall(self.LayoutBag, self)
    end
    self.flightReturnState = nil
end

function QMT:UpdateOutdoorFlightCenterState(force)
    local shouldCenter = self:ShouldUseOutdoorFlightCenter()
    if shouldCenter then
        if force or not self.flightModeActive then
            self:ApplyOutdoorFlightCenterVisual()
        else
            self:HideOutdoorFlightMinimapControls()
        end
    elseif self.flightModeActive then
        self:RestoreOutdoorFlightCenterVisual()
    end
end

function QMT:RequestOutdoorFlightProbe(duration)
    local db = self.db and self.db.minimap
    if not db or not db.enabled or db.flightCenter ~= true then return end
    local now = Now()
    if self.lastFlightProbeRequest and (now - self.lastFlightProbeRequest) < 0.50 then return end
    self.lastFlightProbeRequest = now
    local window = tonumber(duration) or 8.0
    self.flightProbeUntil = math.max(self.flightProbeUntil or 0, now + window)
    -- One watcher owns all flight-state polling. Event bursts only extend its
    -- short probe window; they never start a second OnUpdate loop.
    SafeCall(self.RefreshOutdoorFlightWatcher, self)
end

local QFX_FLIGHT_EVENTS = {
    "PLAYER_MOUNT_DISPLAY_CHANGED",
    "PLAYER_STARTED_MOVING",
    "PLAYER_STOPPED_MOVING",
    "PLAYER_CONTROL_GAINED",
    "PLAYER_CONTROL_LOST",
    "UNIT_AURA",
}

function QMT:RefreshFlightEventRegistration()
    local frame = self.eventFrame
    if not frame or not frame.RegisterEvent or not frame.UnregisterEvent then return end
    local enabled = self.db and self.db.minimap and self.db.minimap.enabled and self.db.minimap.flightCenter == true
    if enabled and not self.flightEventsRegistered then
        for _, event in ipairs(QFX_FLIGHT_EVENTS) do
            if event == "UNIT_AURA" and frame.RegisterUnitEvent then
                frame:RegisterUnitEvent(event, "player")
            else
                frame:RegisterEvent(event)
            end
        end
        self.flightEventsRegistered = true
    elseif (not enabled) and self.flightEventsRegistered then
        for _, event in ipairs(QFX_FLIGHT_EVENTS) do frame:UnregisterEvent(event) end
        self.flightEventsRegistered = false
    end
end

function QMT:RefreshOutdoorFlightWatcher()
    if self.RefreshFlightEventRegistration then self:RefreshFlightEventRegistration() end
    if not self.flightWatcher then
        self.flightWatcher = CreateFrame("Frame")
        self.flightWatcher.elapsed = 0
    end
    local db = self.db and self.db.minimap
    local inProbeWindow = Now() < (self.flightProbeUntil or 0)
    local shouldWatch = db and db.enabled and db.flightCenter == true and (
        self.flightModeActive
        or inProbeWindow
        or (IsMounted and IsMounted())
        or (IsFlying and IsFlying())
    )
    if shouldWatch then
        self.flightWatcher:SetScript("OnUpdate", function(frame, elapsed)
            frame.elapsed = (frame.elapsed or 0) + (elapsed or 0)
            local interval = QMT.flightModeActive and 0.20 or 0.10
            if frame.elapsed < interval then return end
            frame.elapsed = 0
            SafeCall(QMT.UpdateOutdoorFlightCenterState, QMT, false)
            local stillWatch = QMT.flightModeActive
                or Now() < (QMT.flightProbeUntil or 0)
                or (IsMounted and IsMounted())
                or (IsFlying and IsFlying())
            if not stillWatch then QMT:RefreshOutdoorFlightWatcher() end
        end)
    else
        self.flightWatcher:SetScript("OnUpdate", nil)
        self.flightWatcher.elapsed = 0
    end
end

