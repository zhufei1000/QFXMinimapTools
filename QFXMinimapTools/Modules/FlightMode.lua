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

function QMT:HasGatheringProfession()
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
        -- Older clients should keep the old behavior instead of disabling flight center forever.
        return true
    end

    local profs = { GetProfessions() }
    for _, professionIndex in ipairs(profs) do
        if professionIndex then
            local info = { GetProfessionInfo(professionIndex) }
            if IsGatheringProfessionName(info[1]) then
                return true
            end
            for _, value in ipairs(info) do
                if GATHERING_SKILL_IDS[tonumber(value or 0) or 0] then
                    return true
                end
            end
        end
    end
    return false
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
    if db.flightCenterOnlyGathering == true and self.HasGatheringProfession and not self:HasGatheringProfession() then return false end
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
    }
end

function QMT:ApplyOutdoorFlightCenterVisual()
    if not Minimap or not UIParent or not self.db or not self.db.minimap then return end
    local db = self.db.minimap
    self:CaptureOutdoorFlightReturnState()
    self.flightModeActive = true

    local flightScale = Clamp(db.flightScale, 1.00, 3.00)
    local flightPosY = Clamp(db.flightPosY, -240, 40)
    local flightAlpha = Clamp(db.flightAlpha, 0.10, 1.00)
    db.flightScale, db.flightPosY, db.flightAlpha = flightScale, flightPosY, flightAlpha

    Minimap:ClearAllPoints()
    Minimap:SetPoint("TOP", UIParent, "TOP", 0, flightPosY)
    if Minimap.SetScale then Minimap:SetScale(flightScale) end
    if Minimap.SetAlpha then Minimap:SetAlpha(flightAlpha) end
    if Minimap.SetZoom then SafeCall(Minimap.SetZoom, Minimap, 0) end

    if self.squareBorder then self.squareBorder:Hide() end
    self:ApplyQueueStatusButtonPosition()
    self:ApplyMailFramePosition()
    self:ApplyTrackingButtonPosition()
    self:PlaceBagButton()
    if self.statFrames then
        for key in pairs(self.statFrames) do self:PlaceStatFrame(key) end
        self:UpdateAllStats()
    end
    if self.bagFrame and self.bagFrame:IsShown() then self:LayoutBag() end
end

function QMT:RestoreOutdoorFlightCenterVisual()
    if not self.flightModeActive then return end
    local db = self.db and self.db.minimap or {}
    local state = self.flightReturnState or {}
    self.flightModeActive = false

    if Minimap and Minimap.SetAlpha then Minimap:SetAlpha(state.alpha or 1) end
    if Minimap and Minimap.SetZoom and type(state.zoom) == "number" then SafeCall(Minimap.SetZoom, Minimap, state.zoom) end
    if Minimap and Minimap.SetScale then Minimap:SetScale(Clamp(db.scale, 0.50, 2.00)) end
    if self.squareBorder then self.squareBorder:SetShown(db.enabled and db.square) end

    if db.autoSnap then self:ApplySmartTopRightSnap() else self:ApplyManualMinimapPosition() end
    self:ApplyQueueStatusButtonPosition()
    self:ApplyMailFramePosition()
    self:ApplyTrackingButtonPosition()
    self:PlaceBagButton()
    if self.statFrames then
        for key in pairs(self.statFrames) do self:PlaceStatFrame(key) end
        self:UpdateAllStats()
    end
    if self.bagFrame and self.bagFrame:IsShown() then self:LayoutBag() end
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
    if self.flightModeActive then return end
    if not self.flightProbe then
        self.flightProbe = CreateFrame("Frame")
    end
    self.flightProbe.elapsed = 0
    self.flightProbe:SetScript("OnUpdate", function(frame, elapsed)
        frame.elapsed = (frame.elapsed or 0) + (elapsed or 0)
        if frame.elapsed < 0.08 then return end
        frame.elapsed = 0
        SafeCall(QMT.UpdateOutdoorFlightCenterState, QMT, false)
        if QMT.flightModeActive or Now() >= (QMT.flightProbeUntil or 0) then
            frame:SetScript("OnUpdate", nil)
            frame.elapsed = 0
            SafeCall(QMT.RefreshOutdoorFlightWatcher, QMT)
        end
    end)
    SafeCall(self.RefreshOutdoorFlightWatcher, self)
end

local QFX_FLIGHT_EVENTS = {
    "PLAYER_MOUNT_DISPLAY_CHANGED",
    "PLAYER_STARTED_MOVING",
    "PLAYER_STOPPED_MOVING",
    "PLAYER_CONTROL_GAINED",
    "PLAYER_CONTROL_LOST",
    "PLAYER_REGEN_ENABLED",
    "SKILL_LINES_CHANGED",
    "UNIT_AURA",
}

function QMT:RefreshFlightEventRegistration()
    local frame = self.eventFrame
    if not frame or not frame.RegisterEvent or not frame.UnregisterEvent then return end
    local enabled = self.db and self.db.minimap and self.db.minimap.enabled and self.db.minimap.flightCenter == true
    if enabled and not self.flightEventsRegistered then
        for _, event in ipairs(QFX_FLIGHT_EVENTS) do frame:RegisterEvent(event) end
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
            if frame.elapsed < 0.20 then return end
            frame.elapsed = 0
            QMT:UpdateOutdoorFlightCenterState(false)
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


