local ADDON_NAME, QMT = ...
QMT = QMT or {}
_G.QFXMinimapTools = QMT

local L = setmetatable({}, { __index = function(_, key) return QMT.L and QMT.L[key] end })
local SafeCall = QMT.SafeCall
local AccentHex = QMT.AccentHex
local DisplayAccentHex = QMT.DisplayAccentHex
local ColorText = QMT.ColorText
local ResolveFontPath = QMT.ResolveFontPath
local ApplyFontStringFont = QMT.ApplyFontStringFont

local statDefaults = {
    -- Current compact layout: location stays at the top, time stays centered at
    -- the bottom, and FPS/MS, coordinates, and phase live in the outer utility row.
    location = {point = "TOP", rel = "TOP", x = 0, y = -3},
    difficulty = {point = "TOPLEFT", rel = "TOPLEFT", x = 3, y = -3},
    time = {point = "BOTTOM", rel = "BOTTOM", x = 0, y = 3},
    system = {point = "BOTTOMLEFT", rel = "BOTTOMLEFT", x = 3, y = 3},
    coordinates = {point = "BOTTOMRIGHT", rel = "BOTTOMRIGHT", x = -3, y = 3},
}

local statUpdateOrder = {"location", "time"}

local function JustifyFromPoint(point)
    if point and point:find("LEFT") then return "LEFT" end
    if point and point:find("RIGHT") then return "RIGHT" end
    return "CENTER"
end

function QMT:CreateStatFrame(key)
    if self.statFrames and self.statFrames[key] then return self.statFrames[key] end
    self.statFrames = self.statFrames or {}
    local info = statDefaults[key]
    local frame = CreateFrame("Frame", "QFXMinimapTools_" .. key, Minimap or UIParent)
    frame:SetFrameStrata("HIGH")
    if Minimap and Minimap.GetFrameLevel and frame.SetFrameLevel then
        frame:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 25)
    end
    frame:SetSize(40, 14)
    frame:Hide()
    frame.Text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.Text:SetPoint(info.point, frame, info.point, 0, 0)
    frame.Text:SetJustifyH(JustifyFromPoint(info.point))
    frame.Text:SetWordWrap(false)
    if key == "time" then
        frame.CalendarBang = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        -- FontString must have a font before SetText(), otherwise BugSack reports
        -- "FontString:SetText(): Font not set" and the taint points at this addon.
        frame.CalendarBang:SetText("!")
        frame.CalendarBang:SetTextColor(1, 0.82, 0.1, 1)
        frame.CalendarBang:SetPoint("LEFT", frame.Text, "RIGHT", 3, 0)
        frame.CalendarBang:Hide()
    end
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        if key == "system" then
            QMT:ShowSystemTooltip(self)
        elseif key == "coordinates" or key == "time" then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            if key == "coordinates" then
                GameTooltip:AddLine(L.COPY_COORDS)
            elseif key == "time" then
                GameTooltip:AddLine(QMT.ZH and "时间" or "Time")
                GameTooltip:AddLine(QMT.ZH and "右键打开日历" or "Right-click to open calendar", 1, 1, 1, true)
                if QMT:HasCalendarNotification() then GameTooltip:AddLine(L.CALENDAR_PENDING, 1, 0.82, 0.1, true) end
            end
            GameTooltip:Show()
        end
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame:SetScript("OnMouseDown", function(_, button)
        if key == "time" then
            if button == "RightButton" and ToggleCalendar then
                ToggleCalendar()
            end
        elseif key == "coordinates" and button == "LeftButton" then
            QMT:ShowCopyCoordinatesPopup()
        end
    end)
    self.statFrames[key] = frame
    return frame
end

function QMT:ApplyTextStyle(frame, point)
    local d = self.db.display
    local font = ResolveFontPath(d.font)
    local fontSize = tonumber(d.fontSize) or 12
    local outline = d.outline or "OUTLINE"
    font = ApplyFontStringFont(frame.Text, font, fontSize, outline)
    frame.Text:SetTextColor(1, 1, 1, 1)
    if d.shadow then
        frame.Text:SetShadowColor(0, 0, 0, 1)
        frame.Text:SetShadowOffset(1, -1)
    else
        frame.Text:SetShadowOffset(0, 0)
    end
    frame.Text:ClearAllPoints()
    frame.Text:SetPoint(point, frame, point, 0, 0)
    frame.Text:SetJustifyH(JustifyFromPoint(point))
    if frame.CalendarBang then
        ApplyFontStringFont(frame.CalendarBang, font, fontSize, outline)
        frame.CalendarBang:SetTextColor(1, 0.82, 0.1, 1)
        if d.shadow then
            frame.CalendarBang:SetShadowColor(0, 0, 0, 1)
            frame.CalendarBang:SetShadowOffset(1, -1)
        else
            frame.CalendarBang:SetShadowOffset(0, 0)
        end
    end
end

function QMT:PlaceStatFrame(key)
    local frame = self:CreateStatFrame(key)
    local info = statDefaults[key]
    local x, y = info.x, info.y
    frame:ClearAllPoints()
    frame:SetPoint(info.point, Minimap, info.rel, x, y)
    if key == "difficulty" then
        self:ApplyTextStyle(frame, "CENTER")
        frame.Text:ClearAllPoints()
        frame.Text:SetPoint("CENTER", frame, "CENTER", 0, 0)
        frame.Text:SetJustifyH("CENTER")
    else
        self:ApplyTextStyle(frame, info.point)
    end
end

local function ZoneColourHex()
    local pvpType = C_PvP and C_PvP.GetZonePVPInfo and C_PvP.GetZonePVPInfo()
    if pvpType == "friendly" then return "ff33dd44" end
    if pvpType == "sanctuary" then return "ff3aaee8" end
    if pvpType == "hostile" or pvpType == "arena" or pvpType == "combat" then return "ffff3333" end
    if pvpType == "contested" then return "ffffdd33" end
    return AccentHex()
end

function QMT:GetLocationText()
    local zone = ""
    if self.db.display.showSubZone and GetSubZoneText and GetSubZoneText() ~= "" then
        zone = GetSubZoneText()
    elseif GetZoneText then
        zone = GetZoneText() or ""
    end
    return ColorText(zone, ZoneColourHex())
end

function QMT:GetCoordinatesText()
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then return "" end
    local _, instanceType = IsInInstance()
    if instanceType and instanceType ~= "none" then return "" end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return "" end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos or not pos.GetXY then return "" end
    local x, y = pos:GetXY()
    if not x or not y then return "" end
    local decimals = tonumber(self.db.display.coordsDecimals) or 1
    local fmt = decimals == 0 and "%.0f, %.0f" or (decimals == 2 and "%.2f, %.2f" or "%.1f, %.1f")
    return ColorText(string.format(fmt, x * 100, y * 100), AccentHex())
end

function QMT:GetTimeCoordinatesText()
    local parts = {}
    if self.db.display.time then parts[#parts + 1] = self:GetTimeText() end

    -- When the utility glass row is active, coordinates have their own centered
    -- glass frame below the minimap. Keep the in-map bottom text as time-only to
    -- avoid duplicated coordinate text. If the utility row is not active, keep the
    -- old combined time + coordinates fallback.
    local utilityCoords = self.ShouldUseUtilityRow and self:ShouldUseUtilityRow()
    if (not utilityCoords) and self.db.display.coordinates then
        local coords = self:GetCoordinatesText()
        if coords and coords ~= "" then parts[#parts + 1] = coords end
    end

    return table.concat(parts, ColorText(" | ", DisplayAccentHex()))
end


local calendarInviteTextureKeys = {
    "CalendarInvitesTexture",
    "CalendarInvitesGlow",
    "CalendarInviteTexture",
    "CalendarInviteGlow",
    "InvitesTexture",
    "InvitesGlow",
    "InviteTexture",
    "InviteGlow",
    "flashInviteTexture",
    "FlashInviteTexture",
    "calendarInviteTexture",
    "calendarInviteGlow",
}

local function AddCalendarSignalCandidate(list, obj)
    if obj and obj.IsShown then list[#list + 1] = obj end
end

function QMT:GetNativeCalendarInviteSignal()
    local shown, alpha = false, 1
    local candidates = {}
    AddCalendarSignalCandidate(candidates, _G.GameTimeCalendarInvitesTexture)
    AddCalendarSignalCandidate(candidates, _G.GameTimeCalendarInvitesGlow)
    AddCalendarSignalCandidate(candidates, _G.GameTimeFrameCalendarInvitesTexture)
    AddCalendarSignalCandidate(candidates, _G.GameTimeFrameCalendarInvitesGlow)

    local frame = _G.GameTimeFrame
    if frame then
        for _, key in ipairs(calendarInviteTextureKeys) do
            AddCalendarSignalCandidate(candidates, frame[key])
        end
    end

    for _, obj in ipairs(candidates) do
        if SafeCall(obj.IsShown, obj) then
            local a = 1
            if obj.GetAlpha then
                local gotAlpha = SafeCall(obj.GetAlpha, obj)
                if type(gotAlpha) == "number" then a = gotAlpha end
            end
            if a > 0.02 then return true, a end
        end
    end
    return shown, alpha
end

function QMT:HasCalendarNotification()
    local frame = self.statFrames and self.statFrames.time
    local bang = frame and frame.CalendarBang
    return bang and bang.IsShown and bang:IsShown() or false
end

function QMT:UpdateCalendarNotificationIndicator()
    local frame = self.statFrames and self.statFrames.time
    local bang = frame and frame.CalendarBang
    if not bang then return false end

    local ok, shown, alpha = pcall(function() return self:GetNativeCalendarInviteSignal() end)
    if not ok then shown, alpha = false, 1 end

    if shown then
        bang:SetText("!")
        bang:SetAlpha(alpha or 1)
        bang:Show()
        return true
    end

    bang:Hide()
    return false
end

function QMT:RefreshCalendarNotificationIndicatorOnly()
    local frame = self.statFrames and self.statFrames.time
    local bang = frame and frame.CalendarBang
    if not bang then return end
    local wasShown = bang:IsShown()
    local wasAlpha = bang:GetAlpha() or 1
    local isShown = self:UpdateCalendarNotificationIndicator()
    local isAlpha = bang:GetAlpha() or 1
    if wasShown ~= isShown or math.abs(wasAlpha - isAlpha) > 0.05 then
        SafeCall(self.UpdateOneStat, self, "time")
    end
end

function QMT:GetTimeText()
    local h, m
    if self.db.display.useRealmTime and GetGameTime then
        h, m = GetGameTime()
    elseif date then
        h, m = tonumber(date("%H")), tonumber(date("%M"))
    else
        h, m = 0, 0
    end
    h, m = h or 0, m or 0
    if self.db.display.use12Hour then
        local suffix = h >= 12 and "PM" or "AM"
        local hh = h % 12
        if hh == 0 then hh = 12 end
        return string.format("%02d:%02d %s", hh, m, ColorText(suffix, AccentHex()))
    end
    return string.format("%02d:%02d", h, m)
end

function QMT:GetSystemText()
    local fps = math.floor((GetFramerate and GetFramerate() or 0) + 0.5)
    local down, up, home, world = 0, 0, 0, 0
    if GetNetStats then down, up, home, world = GetNetStats() end
    local accent = DisplayAccentHex()
    local text = self.db.display.systemString or "%fps | %home"
    local replacements = {
        ["%%fps"] = tostring(fps) .. ColorText(" FPS", accent),
        ["%%home"] = tostring(math.floor(home or 0)) .. ColorText(" MS", accent),
        ["%%world"] = tostring(math.floor(world or 0)) .. ColorText(" MS", accent),
        ["%%down"] = tostring(math.floor(down or 0)),
        ["%%up"] = tostring(math.floor(up or 0)),
    }
    for token, value in pairs(replacements) do text = text:gsub(token, value) end
    return text
end

local function QFXExtractPhaseIDFromGUID(guid)
    local ok, phaseID = pcall(function()
        if not guid or type(guid) ~= "string" or guid == "" then return nil end

        -- Retail creature-style GUID fields:
        -- Creature-0-server-instance-zoneUID-npcID-spawnUID
        local guidType, _, _, _, zoneUID = strsplit("-", guid)
        if guidType == "Creature" or guidType == "Vehicle" or guidType == "GameObject" then
            local id = tonumber(zoneUID)
            if id and id > 0 and id < 100000000 then
                return math.floor(id)
            end
        end
        return nil
    end)
    if ok then return phaseID end
    return nil
end

function QMT:ClearPhaseCache()
    self.lastPhaseID = nil
end

function QMT:TryCachePhaseIDFromUnit(unit)
    if not unit or not UnitExists or not UnitExists(unit) then return nil end
    local guid = SafeCall(UnitGUID, unit)
    local phaseID = QFXExtractPhaseIDFromGUID(guid)
    if phaseID then
        self.lastPhaseID = phaseID
        return phaseID
    end
    return nil
end

function QMT:DetectPhaseID(preferredUnit)
    if preferredUnit then
        local preferredPhaseID = self:TryCachePhaseIDFromUnit(preferredUnit)
        if preferredPhaseID then return preferredPhaseID end
    end

    local units = {"mouseover", "target"}
    for i = 1, #units do
        local phaseID = self:TryCachePhaseIDFromUnit(units[i])
        if phaseID then return phaseID end
    end

    return self.lastPhaseID
end

function QMT:GetPhaseIDText()
    local phaseID = self:DetectPhaseID()
    local prefix = QMT.ZH and "位面 " or "Phase "
    if not phaseID then
        return prefix .. ColorText("--", AccentHex())
    end
    return prefix .. ColorText(tostring(phaseID), AccentHex())
end

function QMT:GetDifficultyText()
    local _, _, diffID, _, maxPlayers, _, _, instanceID, currentPlayers = GetInstanceInfo()
    if not diffID or diffID == 0 then return "" end
    local accent = AccentHex()
    local count = currentPlayers or maxPlayers or ""
    if diffID == 1 or diffID == 3 or diffID == 4 or diffID == 9 or diffID == 14 then
        return tostring(count) .. ColorText("N", accent)
    elseif diffID == 2 or diffID == 5 or diffID == 6 or diffID == 15 then
        return tostring(count) .. ColorText("H", accent)
    elseif diffID == 16 or diffID == 23 then
        return tostring(maxPlayers or "") .. ColorText("M", accent)
    elseif diffID == 8 then
        local level = ""
        if C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
            level = select(1, C_ChallengeMode.GetActiveKeystoneInfo()) or ""
        end
        return ColorText("M+", accent) .. tostring(level)
    elseif diffID == 7 or diffID == 17 then
        return tostring(maxPlayers or "") .. ColorText("LFR", accent)
    elseif diffID == 24 or diffID == 33 then
        return tostring(maxPlayers or "") .. ColorText("TW", accent)
    elseif diffID == 205 then
        return tostring(maxPlayers or "") .. ColorText("F", accent)
    elseif diffID == 208 then
        return ColorText("T", accent)
    end
    return ColorText(tostring(diffID), accent)
end

function QMT:ShowCopyCoordinatesPopup()
    local coords = self:GetCoordinatesText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if coords == "" then return end
    StaticPopupDialogs["QFX_MINIMAP_COORDS"] = {
        text = QMT.ZH and "当前坐标：" or "Current coordinates:",
        button1 = OKAY or "OK",
        hasEditBox = true,
        editBoxWidth = 220,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnShow = function(self)
            self.EditBox:SetText(coords)
            self.EditBox:SetFocus()
            self.EditBox:HighlightText()
        end,
    }
    StaticPopup_Show("QFX_MINIMAP_COORDS")
end

function QMT:UpdateOneStat(key)
    if not self.statFrames then return end
    local frame = self.statFrames[key]
    if not frame then return end
    local d = self.db.display
    local enabled = d[key] == true
    if key == "time" then
        if self.ShouldUseUtilityRow and self:ShouldUseUtilityRow() then
            enabled = d.time == true
        else
            enabled = d.time == true or d.coordinates == true
        end
    end
    if key == "system" and self.ShouldUseUtilityRow and self:ShouldUseUtilityRow() then
        enabled = false
    elseif key == "coordinates" and (d.time or (self.ShouldUseUtilityRow and self:ShouldUseUtilityRow())) then
        enabled = false
    elseif key == "difficulty" and self.ShouldUseNativeDifficultyFrame and self:ShouldUseNativeDifficultyFrame() then
        enabled = false
    end
    if self:IsOutdoorFlightCenterActive() and key ~= "location" then
        enabled = false
    end
    local text = ""
    if key == "location" and d.location then text = self:GetLocationText()
    elseif key == "coordinates" and d.coordinates then text = self:GetCoordinatesText()
    elseif key == "time" and (d.time or d.coordinates) then text = self:GetTimeCoordinatesText()
    elseif key == "system" and d.system then text = self:GetSystemText()
    elseif key == "difficulty" and d.difficulty then text = self:GetDifficultyText() end
    frame.Text:SetText(text)
    if key == "difficulty" then
        local w = math.max(24, (frame.Text:GetStringWidth() or 0) + 8)
        frame:SetSize(w, 24)
        frame.Text:ClearAllPoints()
        frame.Text:SetPoint("CENTER", frame, "CENTER", 0, 0)
        frame.Text:SetJustifyH("CENTER")
    elseif key == "time" then
        local bangVisible = self:UpdateCalendarNotificationIndicator()
        local textW = frame.Text:GetStringWidth() or 0
        local textH = frame.Text:GetStringHeight() or 0
        local bangW = (bangVisible and frame.CalendarBang and (frame.CalendarBang:GetStringWidth() or 0)) or 0
        local gap = bangVisible and 3 or 0
        frame:SetSize(math.max(10, textW + bangW + gap), math.max(10, textH))
        frame.Text:ClearAllPoints()
        frame.Text:SetPoint("CENTER", frame, "CENTER", -((bangW + gap) * 0.5), 0)
        frame.Text:SetJustifyH("CENTER")
        if bangVisible and frame.CalendarBang then
            frame.CalendarBang:ClearAllPoints()
            frame.CalendarBang:SetPoint("LEFT", frame.Text, "RIGHT", gap, 0)
        end
    else
        frame:SetSize(math.max(10, frame.Text:GetStringWidth()), math.max(10, frame.Text:GetStringHeight()))
    end
    frame:SetShown(enabled and text ~= "")
end

function QMT:UpdateAllStats()
    for _, key in ipairs(statUpdateOrder) do
        local ok = pcall(self.UpdateOneStat, self, key)
        if not ok and self.statFrames and self.statFrames[key] then
            self.statFrames[key]:Hide()
        end
    end
end

function QMT:PlaceAllStatFrames()
    for _, key in ipairs(statUpdateOrder) do
        SafeCall(self.PlaceStatFrame, self, key)
    end
end

local function QFXCancelTicker(owner, key)
    local ticker = owner and owner[key]
    if ticker and ticker.Cancel then SafeCall(ticker.Cancel, ticker) end
    if owner then
        owner[key] = nil
        owner[key .. "Interval"] = nil
    end
end

function QMT:EnsureStatTicker(key, interval, callback)
    if not C_Timer or not C_Timer.NewTicker then return false end
    interval = math.max(0.1, tonumber(interval) or 1)
    local tickerKey = key .. "Ticker"
    local intervalKey = tickerKey .. "Interval"
    if self[tickerKey] and self[intervalKey] == interval then return true end
    QFXCancelTicker(self, tickerKey)
    self[tickerKey] = C_Timer.NewTicker(interval, callback)
    self[intervalKey] = interval
    return true
end

function QMT:CancelStatTickers()
    QFXCancelTicker(self, "coordsTicker")
    QFXCancelTicker(self, "systemTicker")
    QFXCancelTicker(self, "timeTicker")
end

function QMT:RefreshStatUpdaterState()
    local d = self.db and self.db.display
    if not d then return end

    -- 1.0.59 independent refresh model:
    -- * FPS / latency uses a lightweight 5s ticker. It only updates that text.
    -- * Coordinates do not use a standing ticker in the bottom utility row. They
    --   update once at layout time, then while the minimap/coordinates text is hovered.
    -- * Time has its own slow minute ticker.
    -- * Phase ID is target/mouseover-event driven only.
    if self.statUpdater then
        self.statUpdater:SetScript("OnUpdate", nil)
        self.statUpdaterRunning = false
    end

    QFXCancelTicker(self, "coordsTicker")

    if not (C_Timer and C_Timer.NewTicker) then
        self:CancelStatTickers()
        return
    end

    if d.system then
        self:EnsureStatTicker("system", math.max(5, tonumber(d.systemInterval or 5) or 5), function()
            local cfg = QMT.db and QMT.db.display
            if not cfg or not cfg.system then return end
            if QMT.ShouldUseUtilityRow and QMT:ShouldUseUtilityRow() then
                SafeCall(QMT.UpdateUtilitySystemText, QMT)
            else
                SafeCall(QMT.UpdateOneStat, QMT, "system")
            end
        end)
    else
        QFXCancelTicker(self, "systemTicker")
    end

    if d.time then
        self:EnsureStatTicker("time", math.max(60, tonumber(d.timeInterval or 60) or 60), function()
            local cfg = QMT.db and QMT.db.display
            if not cfg or not cfg.time then return end
            SafeCall(QMT.UpdateOneStat, QMT, "time")
            if QMT.ShouldUseUtilityRow and QMT:ShouldUseUtilityRow() then
                SafeCall(QMT.UpdateTimeStatusIcons, QMT)
            end
        end)
    else
        QFXCancelTicker(self, "timeTicker")
    end
end

function QMT:RefreshPhaseEventRegistration()
    local eventFrame = self.eventFrame
    if not eventFrame or not eventFrame.UnregisterEvent then return end
    -- 1.0.59: no nameplate phase cache. Target/mouseover events are registered
    -- directly by Core.lua and are the only live phase refresh sources.
    if self.phaseNameplateEventRegistered then
        eventFrame:UnregisterEvent("NAME_PLATE_UNIT_ADDED")
        self.phaseNameplateEventRegistered = false
    end
end

function QMT:CreateStats()
    self:PlaceAllStatFrames()
    -- No standing OnUpdate frame. All live text refreshes are independent tickers
    -- or events: system=5s ticker, time=minute ticker, coordinates=hover only,
    -- phase=target/mouseover events.
    self:RefreshStatUpdaterState()
    self:RefreshPhaseEventRegistration()
    self:UpdateAllStats()
    if self.UpdateUtilityRow then SafeCall(self.UpdateUtilityRow, self) end
end

-- ############################################################
