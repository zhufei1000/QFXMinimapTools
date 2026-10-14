local ADDON_NAME, QMT = ...
QMT = QMT or {}
_G.QFXMinimapTools = QMT

local L = setmetatable({}, { __index = function(_, key) return QMT.L and QMT.L[key] end })
local SafeCall = QMT.SafeCall
local Print = QMT.Print

-- Init / events
-- ############################################################
function QMT:ApplyAll()
    if not self.db then return end
    SafeCall(self.ApplyMinimapSettings, self)
    SafeCall(self.CreateStats, self)
    SafeCall(self.ApplyBagSettings, self)
end

function QMT:Initialize()
    if self.initialized then return end
    self.initialized = true
    self:HideUnusedButtonCells(nil)
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_TimeManager")
    elseif LoadAddOn then
        pcall(LoadAddOn, "Blizzard_TimeManager")
    end
    self.collectedButtons = {}
    self.collectedMap = {}
    self.originalButtons = {}
    self:ApplyAll()
    self:RefreshOutdoorFlightWatcher()
    self:UpdateOutdoorFlightCenterState(true)
    -- Never change the client's global CPU profiling state automatically. The
    -- diagnostic control in Advanced only acts after an explicit user click.
    self:RegisterSettingsCategory()

    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventFrame:RegisterEvent("ZONE_CHANGED")
        self.eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
        self.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        self.eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        self.eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
        self.eventFrame:RegisterEvent("UI_SCALE_CHANGED")
        self.eventFrame:RegisterEvent("UPDATE_PENDING_MAIL")
        self.eventFrame:RegisterEvent("MAIL_INBOX_UPDATE")
        self.eventFrame:RegisterEvent("MAIL_CLOSED")
        self.eventFrame:RegisterEvent("CALENDAR_UPDATE_PENDING_INVITES")
        self.eventFrame:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")
        self.eventFrame:RegisterEvent("CVAR_UPDATE")
        self.eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
        -- Button-bag restore/rescan work must always complete after combat, even
        -- when the optional flight-center feature is disabled.
        self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        self.eventFrame:SetScript("OnEvent", function(_, event, ...)
            if not QMT.db then return end

            if event == "SKILL_LINES_CHANGED" then
                SafeCall(QMT.RefreshGatheringProfessionCache, QMT)
                SafeCall(QMT.RefreshGatheringProfessionStatus, QMT)
                SafeCall(QMT.RefreshOutdoorFlightWatcher, QMT)
                SafeCall(QMT.UpdateOutdoorFlightCenterState, QMT, false)
                return
            elseif event == "UNIT_AURA" then
                local unit = ...
                if unit ~= "player" then return end
                if QMT.flightModeActive
                    or (GetTime and GetTime() < (QMT.flightProbeUntil or 0))
                    or (QMT.IsPlayerAirborne and QMT:IsPlayerAirborne()) then
                    SafeCall(QMT.RequestOutdoorFlightProbe, QMT, 8.0)
                    SafeCall(QMT.UpdateOutdoorFlightCenterState, QMT, false)
                end
                return
            elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED"
                or event == "PLAYER_STARTED_MOVING"
                or event == "PLAYER_STOPPED_MOVING"
                or event == "PLAYER_CONTROL_GAINED"
                or event == "PLAYER_CONTROL_LOST"
                or event == "PLAYER_CAN_GLIDE_CHANGED"
                or event == "PLAYER_IS_GLIDING_CHANGED"
                or event == "PLAYER_REGEN_ENABLED" then
                if event == "PLAYER_REGEN_ENABLED" then
                    SafeCall(QMT.ProcessPendingBagOperations, QMT)
                end
                -- Only real transitions extend the short 10 Hz probe window. Movement
                -- events must not, or merely running while mounted would keep polling
                -- at 10 Hz instead of the intended 2 Hz until takeoff.
                local wantsFlightProbe = event == "PLAYER_MOUNT_DISPLAY_CHANGED"
                    or event == "PLAYER_CAN_GLIDE_CHANGED"
                    or event == "PLAYER_IS_GLIDING_CHANGED"
                    or event == "PLAYER_CONTROL_GAINED"
                    or event == "PLAYER_CONTROL_LOST"
                if wantsFlightProbe then
                    SafeCall(QMT.RequestOutdoorFlightProbe, QMT, 8.0)
                end
                SafeCall(QMT.RefreshOutdoorFlightWatcher, QMT)
                SafeCall(QMT.UpdateOutdoorFlightCenterState, QMT, false)
                return
            end

            -- Phase ID is intentionally ultra-light: only target and mouseover
            -- changes update the displayed value. No focus/nameplate/zone polling.
            if event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" then
                if QMT.db.display and QMT.db.display.phaseID then
                    SafeCall(QMT.UpdateUtilityPhaseText, QMT)
                end
                return
            elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
                SafeCall(QMT.ClearPhaseCache, QMT)
            end

            if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
                SafeCall(QMT.RefreshOutdoorFlightWatcher, QMT)
                SafeCall(QMT.UpdateOutdoorFlightCenterState, QMT, false)
                SafeCall(QMT.RequestSmartTopRightSnap, QMT)
                SafeCall(QMT.ApplySquareBorderStyle, QMT)
                SafeCall(QMT.RequestAttachedElementRefresh, QMT, true, true)
                return
            end

            if event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
                SafeCall(QMT.RequestSmartTopRightSnap, QMT)
                SafeCall(QMT.ApplySquareBorderStyle, QMT)
                SafeCall(QMT.RequestAttachedElementRefresh, QMT, true, true)
                return
            end

            if event == "UPDATE_PENDING_MAIL" or event == "MAIL_INBOX_UPDATE" or event == "MAIL_CLOSED" then
                -- ApplyMailFramePosition refreshes the time status icons itself.
                SafeCall(QMT.ApplyMailFramePosition, QMT)
                return
            end

            if event == "CALENDAR_UPDATE_PENDING_INVITES" or event == "CALENDAR_UPDATE_EVENT_LIST" then
                SafeCall(QMT.UpdateOneStat, QMT, "time")
                SafeCall(QMT.UpdateTimeStatusIcons, QMT)
                return
            end

            if event == "CVAR_UPDATE" then
                local cvar = ...
                if cvar == "timeMgrUseMilitaryTime" or cvar == "timeMgrUseLocalTime" then
                    SafeCall(QMT.UpdateOneStat, QMT, "time")
                    SafeCall(QMT.UpdateTimeStatusIcons, QMT)
                end
                return
            end

            if event == "GROUP_ROSTER_UPDATE" then
                SafeCall(QMT.UpdateOneStat, QMT, "difficulty")
                SafeCall(QMT.ApplyDifficultyFramePosition, QMT)
                SafeCall(QMT.ApplyQueueStatusButtonPosition, QMT)
                if QMT.LayoutUtilityRow then SafeCall(QMT.LayoutUtilityRow, QMT) end
                if QMT.ApplyNativeControlSkin then SafeCall(QMT.ApplyNativeControlSkin, QMT) end
            end
        end)
    end
    SafeCall(self.RefreshFlightEventRegistration, self)
    SafeCall(self.RefreshPhaseEventRegistration, self)

    if LibStub then
        local lib = LibStub:GetLibrary("LibDBIcon-1.0", true)
        if lib and lib.RegisterCallback and not self.libDBIconHooked then
            lib.RegisterCallback(self, "LibDBIcon_IconCreated", function(_, button)
                if QMT.db and QMT.db.bag and QMT.db.bag.enabled then
                    SafeCall(QMT.CollectButton, QMT, button)
                    SafeCall(QMT.RescanButtons, QMT)
                end
            end)
            self.libDBIconHooked = true
        end
    end

    if UIParent and UIParent.HookScript and not self.snapSizeHooked then
        UIParent:HookScript("OnSizeChanged", function() QMT:RequestSmartTopRightSnap() end)
        if MinimapCluster and MinimapCluster.HookScript then MinimapCluster:HookScript("OnSizeChanged", function() QMT:RequestSmartTopRightSnap() end) end
        self.snapSizeHooked = true
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            SafeCall(QMT.ApplySmartTopRightSnap, QMT)
            SafeCall(QMT.ApplySquareBorderStyle, QMT)
            SafeCall(QMT.ApplyMailFramePosition, QMT)
            SafeCall(QMT.ApplyTrackingButtonPosition, QMT)
            SafeCall(QMT.ApplyDifficultyFramePosition, QMT)
            SafeCall(QMT.ApplyExpansionLandingPageButtonPosition, QMT)
            SafeCall(QMT.UpdateUtilityRow, QMT)
        end)
        C_Timer.After(1.5, function()
            SafeCall(QMT.ApplySmartTopRightSnap, QMT)
            SafeCall(QMT.RescanButtons, QMT)
            SafeCall(QMT.ApplySquareBorderStyle, QMT)
            SafeCall(QMT.ApplyMailFramePosition, QMT)
            SafeCall(QMT.ApplyTrackingButtonPosition, QMT)
            SafeCall(QMT.ApplyDifficultyFramePosition, QMT)
            SafeCall(QMT.ApplyExpansionLandingPageButtonPosition, QMT)
            SafeCall(QMT.UpdateUtilityRow, QMT)
        end)
    end
end

SLASH_QFXMINIMAPTOOLS1 = "/qfmt"
SLASH_QFXMINIMAPTOOLS2 = "/qmini"
SlashCmdList["QFXMINIMAPTOOLS"] = function(msg)
    msg = (msg or ""):lower()
    if msg == "reset" then QMT:ResetDefaults()
    elseif msg == "resetpos" or msg == "resetposition" then QMT:ResetMinimapPosition()
    elseif msg == "rescan" then QMT:RescanButtons(true)
    else QMT:ToggleOptions() end
end

_G.QFXMinimapTools_ToggleOptions = function()
    QMT:ToggleOptions()
end

_G.QFXMinimapTools_OpenBlizzardSettings = function()
    QMT:OpenBlizzardSettingsCategory()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON_NAME then
        QMT:LoadDB()
        QMT:RegisterSettingsCategory()
    elseif event == "PLAYER_LOGIN" then
        if not QMT.db then QMT:LoadDB() end
        QMT:Initialize()
    end
end)
