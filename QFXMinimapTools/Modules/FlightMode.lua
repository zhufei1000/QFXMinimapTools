local ADDON_NAME, QMT = ...
QMT = QMT or {}
_G.QFXMinimapTools = QMT

local L = setmetatable({}, { __index = function(_, key) return QMT.L and QMT.L[key] end })
local SafeCall = QMT.SafeCall
local Clamp = QMT.Clamp

local function Now()
    return GetTime and GetTime() or 0
end

function QMT:IsPlayerAirborne()
    if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
        local ok, isGliding = pcall(C_PlayerInfo.GetGlidingInfo)
        if ok and isGliding then return true end
    end
    return IsFlying and IsFlying() or false
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

    local primary1, primary2 = GetProfessions()
    local professionIndexes = {primary1, primary2}
    local found = false
    for _, professionIndex in ipairs(professionIndexes) do
        if professionIndex then
            local info = {GetProfessionInfo(professionIndex)}
            local first = info[1]
            if type(first) == "table" then
                local name = first.name or first.professionName or first.skillLineName
                local skillLine = first.skillLine or first.skillLineID or first.professionID
                found = GATHERING_SKILL_IDS[tonumber(skillLine or 0) or 0] == true
                    or IsGatheringProfessionName(name)
            else
                -- GetProfessionInfo's seventh return value is the skill line.
                -- Do not scan every numeric return: rank/max-rank/offset values
                -- can coincidentally equal 182 or 186 and cause false positives.
                local skillLine = info[7]
                local skillLineName = info[11]
                found = GATHERING_SKILL_IDS[tonumber(skillLine or 0) or 0] == true
                    or IsGatheringProfessionName(first)
                    or IsGatheringProfessionName(skillLineName)
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
    return self:IsPlayerAirborne()
end

function QMT:CaptureOutdoorFlightReturnState()
    if self.flightReturnState or not Minimap then return end
    self.flightReturnState = {
        alpha = Minimap.GetAlpha and Minimap:GetAlpha() or 1,
        zoom = Minimap.GetZoom and Minimap:GetZoom() or nil,
        bagShown = self.bagFrame and self.bagFrame.IsShown and self.bagFrame:IsShown() or false,
    }
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
    if self.indicatorButtons then
        for _, frame in pairs(self.indicatorButtons) do if frame and frame.Hide then frame:Hide() end end
    end
    if self.utilityRow then self.utilityRow:Hide() end
    if self.utilityTextFrames then
        for _, frame in pairs(self.utilityTextFrames) do if frame and frame.Hide then frame:Hide() end end
    end
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
        if force or not self.flightModeActive then self:ApplyOutdoorFlightCenterVisual() end
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
    "PLAYER_CAN_GLIDE_CHANGED",
    "PLAYER_IS_GLIDING_CHANGED",
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
        or self:IsPlayerAirborne()
    )
    if shouldWatch then
        self.flightWatcher:SetScript("OnUpdate", function(frame, elapsed)
            frame.elapsed = (frame.elapsed or 0) + (elapsed or 0)
            local probing = Now() < (QMT.flightProbeUntil or 0)
            local interval = QMT.flightModeActive and 0.20 or (probing and 0.10 or 0.50)
            if frame.elapsed < interval then return end
            frame.elapsed = 0
            SafeCall(QMT.UpdateOutdoorFlightCenterState, QMT, false)
            local stillWatch = QMT.flightModeActive
                or Now() < (QMT.flightProbeUntil or 0)
                or (IsMounted and IsMounted())
                or QMT:IsPlayerAirborne()
            if not stillWatch then QMT:RefreshOutdoorFlightWatcher() end
        end)
    else
        self.flightWatcher:SetScript("OnUpdate", nil)
        self.flightWatcher.elapsed = 0
    end
end
