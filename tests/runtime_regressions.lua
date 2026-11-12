-- Run from the repository root: lua tests/runtime_regressions.lua
local Q = {}
local function noop() end
for _, file in ipairs({
    "Locale.lua", "Core/Utils.lua", "Core/Defaults.lua", "Modules/Minimap.lua",
    "Modules/FlightMode.lua", "Modules/Stats.lua", "Modules/ButtonBag.lua",
}) do
    assert(loadfile("QFXMinimapTools/" .. file))("QFXMinimapTools", Q)
end
Q:LoadDB()

UIParent = {}
Minimap = {
    GetCenter = function() return 100, 100 end,
    GetEffectiveScale = function() return 2 end,
}
local nearby = {
    GetParent = function() return UIParent end,
    GetCenter = function() return 620, 210 end,
    GetEffectiveScale = function() return 1 end,
}
assert(Q:IsButtonCurrentlyOnMinimap(nearby), "nearby buttons can have a different parent and scale")
nearby.GetCenter = function() return 800, 210 end
assert(not Q:IsButtonCurrentlyOnMinimap(nearby))
local secret = {}
issecretvalue = function(value) return value == secret end
nearby.GetCenter = function() return secret, secret end
assert(not Q:IsButtonCurrentlyOnMinimap(nearby))
local small = {
    GetSize = function() return 18, 20 end,
    SetSize = function(self, width, height) self.width, self.height = width, height end,
}
Q:MakeCollectedButtonEasyToMouse(small)
assert(small.width == 30 and small.height == 30)
Q.bagFrame, Q.bagPinFrame = {}, {}
local pinned = { GetParent = function() return Q.bagPinFrame end }
GetMouseFoci = function() return { pinned } end
assert(Q:IsMouseOverBag(), "pinned buttons count as part of the bag for auto-close")
GetMouseFoci = function() return {} end
assert(not Q:IsMouseOverBag())

GetProfessions = function() return nil, 2 end
GetProfessionInfo = function(index)
    assert(index == 2)
    return "Herbalism", nil, nil, nil, nil, nil, 182
end
assert(Q:RefreshGatheringProfessionCache(), "check the second primary slot even when the first is empty")

local function mockIndicator(shown)
    local frame = { shown = shown, alpha = 1, mouse = true, hooks = {} }
    function frame:IsShown() return self.shown end
    function frame:GetAlpha() return self.alpha end
    function frame:SetAlpha(alpha) self.alpha = alpha end
    function frame:IsMouseEnabled() return self.mouse end
    function frame:EnableMouse(enabled) self.mouse = enabled end
    function frame:HookScript(event, callback) self.hooks[event] = callback end
    function frame:SetShown(visible)
        if self.shown == visible then return end
        self.shown = visible
        local callback = self.hooks[visible and "OnShow" or "OnHide"]
        if callback then callback(self) end
    end
    function frame:Show() self:SetShown(true) end
    function frame:Hide() self:SetShown(false) end
    return frame
end

local nativeMail, nativeCrafting = mockIndicator(true), mockIndicator(true)
MinimapCluster = { IndicatorFrame = { MailFrame = nativeMail, CraftingOrderFrame = nativeCrafting } }
Minimap.GetRegions = noop
GameTimeFrame = mockIndicator(true)
ProfessionsCustomerOrdersFrame = mockIndicator(true)
local icons = { calendar = mockIndicator(false), mail = mockIndicator(false), crafting = mockIndicator(false) }
Q.CreateIndicatorButton = function(_, key) return icons[key] end
Q.ShowIndicatorIcon, Q.UpdateCalendarDate, Q.LayoutIndicatorColumn = noop, noop, noop
Q.RequestSmartTopRightSnap = noop
Q.db.display.time = false
Q.db.minimap.square = false
local pendingMail = true
HasNewMail = function() return pendingMail end
Q:ApplyMailFramePosition()
Q:SetNativeMinimapControlsHidden(false)
assert(icons.mail:IsShown() and nativeMail.alpha == 0 and not nativeMail.mouse,
    "replace native mail even with the clock hidden")
assert(icons.crafting:IsShown() and nativeCrafting.alpha == 0 and not nativeCrafting.mouse,
    "replace native crafting orders even with the clock hidden")
assert(icons.calendar:IsShown() and not GameTimeFrame:IsShown(), "replace native calendar in round mode")
GameTimeFrame:Show()
assert(not GameTimeFrame:IsShown(), "native calendar stays hidden when Blizzard shows it again")
assert(ProfessionsCustomerOrdersFrame.alpha == 1 and ProfessionsCustomerOrdersFrame.mouse,
    "the crafting order window is not a minimap indicator")

ProfessionsCustomerOrders_MinimapButton = mockIndicator(false)
Q:UpdateTimeStatusIcons()
assert(ProfessionsCustomerOrders_MinimapButton.alpha == 0,
    "new native indicator must be managed even when icon visibility is unchanged")
nativeCrafting:Hide()
assert(not icons.crafting:IsShown(), "an open order window must not show a crafting notification")
pendingMail = false
Q:ApplyMailFramePosition()
assert(not icons.mail:IsShown(), "a mail event must clear the replacement icon")

Q.db.minimap.enabled = false
Q:ApplyMailFramePosition()
Q:SetNativeMinimapControlsHidden(false)
assert(nativeMail.alpha == 1 and nativeMail.mouse and nativeCrafting.alpha == 1 and nativeCrafting.mouse,
    "disabling the enhancement must restore the native indicators")
assert(GameTimeFrame:IsShown() and not icons.calendar:IsShown(), "restore the native calendar on disable")
GameTimeFrame, ProfessionsCustomerOrdersFrame, ProfessionsCustomerOrders_MinimapButton, HasNewMail = nil, nil, nil, nil
Q.db.minimap.enabled, Q.db.minimap.square = true, true

local firstTick, everyMinute, iconUpdates = nil, nil, 0
local timer = { Cancel = noop }
C_Timer = {
    NewTimer = function(_, callback) firstTick = callback; return timer end,
    NewTicker = function(_, callback) everyMinute = callback; return timer end,
}
Q.db.display.time, Q.db.display.system = false, false
Q.UpdateTimeStatusIcons = function() iconUpdates = iconUpdates + 1 end
Q:RefreshStatUpdaterState()
firstTick()
assert(everyMinute, "calendar needs a repeating ticker even with the clock hidden")
everyMinute()
assert(iconUpdates == 2)

local combat, airborne = false, false
InCombatLockdown = function() return combat end
local function move(self, point)
    assert(not combat, "attempted to move a protected minimap in combat")
    self.anchor = point
end
Minimap.ClearAllPoints = noop
Minimap.SetPoint = move
Minimap.SetAlpha = noop
Minimap.SetScale = noop
Minimap.SetClampedToScreen = noop
Minimap.SetMaskTexture = function(self, mask) self.mask = mask end
MinimapCluster = { SetScale = noop, SetClampedToScreen = noop }
Q.squareBorder = {
    SetShown = function(self, shown) self.shown = shown end,
    Hide = function(self) self.shown = false end,
}
for _, method in ipairs({
    "CaptureOriginalMinimapState", "RestoreOriginalMinimapState", "SetRoundMinimapArtHidden",
    "SetNativeMinimapControlsHidden", "ApplyMinimapMoveMode", "ApplyQueueStatusButtonPosition",
    "ApplyMailFramePosition", "ApplyTrackingButtonPosition", "ApplyDifficultyFramePosition",
    "ApplyExpansionLandingPageButtonPosition", "UpdateUtilityRow", "ApplyNativeControlSkin",
    "RefreshOutdoorFlightWatcher", "RefreshMinimapAttachedElements", "HideOutdoorFlightMinimapControls",
}) do Q[method] = noop end
Q.ApplySmartTopRightSnap = function(_, leavingFlight)
    if leavingFlight then move(Minimap, "TOPRIGHT") end
end
Q.ShouldUseOutdoorFlightCenter = function() return airborne end
Q.db.minimap.borderEnabled = false
GetMinimapShape = nil
Q:ApplyMinimapSettings()
assert(GetMinimapShape() == "SQUARE")
Q.db.minimap.square = false
Q:ApplyMinimapSettings()
assert(GetMinimapShape() == "ROUND")
Q.db.minimap.enabled = false
Q:ApplyMinimapSettings()
assert(GetMinimapShape == nil, "restore the original absence of a shape provider")

Q.db.minimap.enabled, Q.db.minimap.square = true, true
combat, airborne = true, true
Q:UpdateOutdoorFlightCenterState(true)
assert(not Q:IsOutdoorFlightCenterActive() and Q.pendingFlightApply)
combat = false
Minimap.SetPoint = function() error("simulated anchoring failure") end
assert(not pcall(Q.UpdateOutdoorFlightCenterState, Q, false))
assert(not Q:IsOutdoorFlightCenterActive(), "failed move cannot commit the flight state")
Minimap.SetPoint = move
Q:UpdateOutdoorFlightCenterState(false)
assert(Q:IsOutdoorFlightCenterActive() and Minimap.anchor == "TOP")
combat, airborne = true, false
Q:UpdateOutdoorFlightCenterState(false)
assert(Q:IsOutdoorFlightCenterActive() and Minimap.anchor == "TOP")
combat = false
Q:UpdateOutdoorFlightCenterState(false)
assert(not Q:IsOutdoorFlightCenterActive() and Minimap.anchor == "TOPRIGHT" and not Q.squareBorder.shown)

Q.db.bag.exclude = "PreviouslyExcludedMinimapButton"
Q.hasScannedButtons = true
Q.CreateBagFrames, Q.PlaceBagButton, Q.LayoutBag = noop, noop, noop
Q.bagFrame.IsShown = function() return false end
Q.ApplyAll = Q.ApplyBagSettings
local rescanned
Q.RescanButtons = function() rescanned = true end
Q:ResetDefaults()
assert(rescanned and not Q:GetExcludeTable().PreviouslyExcludedMinimapButton)
print("PASS: button collection, pinned hover, profession slots, native indicators, calendar, shape, flight recovery and reset")
