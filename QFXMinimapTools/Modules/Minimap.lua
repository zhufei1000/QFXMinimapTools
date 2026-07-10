local ADDON_NAME, QMT = ...
QMT = QMT or {}
_G.QFXMinimapTools = QMT

local L = setmetatable({}, { __index = function(_, key) return QMT.L and QMT.L[key] end })
local SafeCall = QMT.SafeCall
local Clamp = QMT.Clamp
local Round = QMT.Round
local AccentHex = QMT.AccentHex
local DisplayAccentHex = QMT.DisplayAccentHex
local ColorText = QMT.ColorText
local IsDescendant = QMT.IsDescendant
local Print = QMT.Print
local NormalizeLanguageChoice = QMT.NormalizeLanguageChoice
local SelectLocale = QMT.SelectLocale

function QMT:ResetMinimapPosition()
    if not self.db or not self.db.minimap then return end
    local db = self.db.minimap
    db.autoSnap = true
    db.locked = true
    db.manualPoint = nil
    local inset = self:GetSnapInset()
    db.snapX = -inset
    db.snapY = -inset
    self:ApplyAll()
    if self.optionsFrame then self.optionsFrame:Hide() self.optionsFrame = nil self:ShowOptions() end
    Print(L.POSITION_RESET_DONE)
end

-- ############################################################
-- Minimap enhancement
-- ############################################################

local roundMinimapArtNames = {
    "MinimapBorder",
    "MinimapBorderTop",
    "MinimapBackdrop",
    "MiniMapMailBorder",
    "MiniMapBattlefieldBorder",
    "MinimapNorthTag",
}

local function LooksLikeRoundMinimapArt(region)
    if not region or not region.GetTexture then return false end
    local tex = region:GetTexture()
    if type(tex) ~= "string" then return false end
    tex = tex:lower()
    if tex:find("qfxminimaptools", 1, true) then return false end
    if tex:find("border", 1, true) or tex:find("arch", 1, true) or tex:find("minimap%-trackingborder") then
        return tex:find("minimap", 1, true) or tex:find("mini%-map", 1, true) or tex:find("trackingborder", 1, true)
    end
    return false
end

function QMT:CaptureRoundMinimapArt()
    if self.roundMinimapArtCaptured then return end
    self.roundMinimapArtCaptured = true
    self.roundMinimapArt = {}

    local function AddArt(obj)
        if not obj or obj == self.squareBorder or self.roundMinimapArt[obj] then return end
        if obj.GetObjectType and obj:GetObjectType() == "Frame" and obj.GetName and tostring(obj:GetName() or ""):find("QFXMinimapTools") then return end
        self.roundMinimapArt[obj] = {
            alpha = obj.GetAlpha and obj:GetAlpha() or 1,
            shown = obj.IsShown and obj:IsShown() or true,
        }
    end

    for _, name in ipairs(roundMinimapArtNames) do AddArt(_G[name]) end
    if MinimapCluster then
        AddArt(MinimapCluster.BorderTop)
        AddArt(MinimapCluster.BorderBottom)
    end
    if Minimap then
        for _, region in ipairs({Minimap:GetRegions()}) do
            if LooksLikeRoundMinimapArt(region) then AddArt(region) end
        end
    end
    if MinimapCluster then
        for _, region in ipairs({MinimapCluster:GetRegions()}) do
            if LooksLikeRoundMinimapArt(region) then AddArt(region) end
        end
    end
end

function QMT:SetRoundMinimapArtHidden(hidden)
    self:CaptureRoundMinimapArt()
    for obj, info in pairs(self.roundMinimapArt or {}) do
        if obj and obj.SetAlpha then
            if hidden then
                obj:SetAlpha(0)
                if obj.Hide then obj:Hide() end
            else
                obj:SetAlpha(info.alpha or 1)
                if info.shown and obj.Show then obj:Show() end
            end
        end
    end
end

local nativeMinimapControlNames = {
    -- Default header / title / time / tracking / zoom / top overlay controls.
    "MinimapZoneTextButton",
    "MinimapZoneText",
    "MinimapToggleButton",
    "MinimapCompassTexture",
    "MiniMapWorldMapButton",
    "MinimapZoomIn",
    "MinimapZoomOut",
    "TimeManagerClockButton",
    "GameTimeFrame",
    "AddonCompartmentFrame",
    "GarrisonLandingPageMinimapButton",
}

function QMT:ShouldCleanSquareMinimap()
    return self.db and self.db.minimap and self.db.minimap.enabled and self.db.minimap.square
end

function QMT:CaptureNativeMinimapControls()
    if self.nativeMinimapControlsCaptured then return end
    self.nativeMinimapControlsCaptured = true
    self.nativeMinimapControls = {}

    local function AddObj(obj)
        if not obj or obj == self.bagButton or obj == self.bagFrame or obj == self.squareBorder then return end
        if self.nativeMinimapControls[obj] then return end
        self.nativeMinimapControls[obj] = {
            alpha = obj.GetAlpha and obj:GetAlpha() or 1,
            shown = obj.IsShown and obj:IsShown() or false,
        }
        if obj.HookScript and not obj.QFXMinimapToolsCleanHook then
            obj:HookScript("OnShow", function(frame)
                if QMT:ShouldCleanSquareMinimap() and frame.Hide then frame:Hide() end
            end)
            obj.QFXMinimapToolsCleanHook = true
        end
    end

    for _, name in ipairs(nativeMinimapControlNames) do AddObj(_G[name]) end

    if MinimapCluster then
        AddObj(MinimapCluster.ZoneTextButton)
        AddObj(MinimapCluster.BorderTop)
        AddObj(MinimapCluster.BorderBottom)
        AddObj(MinimapCluster.AddonCompartmentFrame)
        AddObj(MinimapCluster.MinimapContainer and MinimapCluster.MinimapContainer.Header)
    end

    if Minimap then
        for _, region in ipairs({Minimap:GetRegions()}) do
            if LooksLikeRoundMinimapArt(region) then AddObj(region) end
        end
    end
end

function QMT:SetNativeMinimapControlsHidden(hidden)
    self:CaptureNativeMinimapControls()
    for obj, info in pairs(self.nativeMinimapControls or {}) do
        if obj then
            if hidden then
                if obj.SetAlpha then obj:SetAlpha(0) end
                if obj.Hide then obj:Hide() end
            else
                if obj.SetAlpha then obj:SetAlpha(info.alpha or 1) end
                if info.shown and obj.Show then obj:Show() end
            end
        end
    end
end

function QMT:GetSnapInset()
    local border = self.db and self.db.minimap and tonumber(self.db.minimap.borderSize) or 3
    -- The border frame extends outside the Minimap. Use a larger automatic inset so
    -- the border itself plus a small gap remains visible at any UI scale.
    return math.max(border * 3, 9)
end

function QMT:CreateSnapAnchor()
    if self.snapAnchor then return self.snapAnchor end
    local anchor = CreateFrame("Frame", "QFXMinimapToolsTopRightAnchor", UIParent)
    anchor:SetSize(1, 1)
    local inset = self:GetSnapInset()
    anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -inset, -inset)
    self.snapAnchor = anchor
    return anchor
end

function QMT:UpdateSquareBorderPosition()
    if self.squareBorder and Minimap then
        self.squareBorder:SetFrameStrata("LOW")
        if self.squareBorder.SetFrameLevel and Minimap.GetFrameLevel then
            self.squareBorder:SetFrameLevel(math.max(0, (Minimap:GetFrameLevel() or 1) - 1))
        end
        self.squareBorder:ClearAllPoints()
        self.squareBorder:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -3, 3)
        self.squareBorder:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 3, -3)
    end
end

function QMT:RefreshMinimapAttachedElements(updateStats, layoutBag)
    SafeCall(self.ApplyQueueStatusButtonPosition, self)
    SafeCall(self.ApplyMailFramePosition, self)
    SafeCall(self.ApplyTrackingButtonPosition, self)
    SafeCall(self.ApplyDifficultyFramePosition, self)
    SafeCall(self.ApplyExpansionLandingPageButtonPosition, self)
    SafeCall(self.UpdateUtilityRow, self)
    if self.ApplyNativeControlSkin then SafeCall(self.ApplyNativeControlSkin, self) end
    SafeCall(self.PlaceBagButton, self)
    if self.statFrames then
        if self.PlaceAllStatFrames then
            SafeCall(self.PlaceAllStatFrames, self)
        else
            for key in pairs(self.statFrames) do SafeCall(self.PlaceStatFrame, self, key) end
        end
        if updateStats then SafeCall(self.UpdateAllStats, self) end
    end
    if layoutBag and self.bagFrame and self.bagFrame:IsShown() then SafeCall(self.LayoutBag, self) end
end

function QMT:RequestAttachedElementRefresh(updateStats, layoutBag)
    self.refreshStatsQueued = self.refreshStatsQueued or updateStats
    self.refreshBagLayoutQueued = self.refreshBagLayoutQueued or layoutBag
    if self.attachedRefreshQueued then return end
    self.attachedRefreshQueued = true
    local function Flush()
        QMT.attachedRefreshQueued = false
        local doStats = QMT.refreshStatsQueued
        local doLayout = QMT.refreshBagLayoutQueued
        QMT.refreshStatsQueued = false
        QMT.refreshBagLayoutQueued = false
        SafeCall(QMT.RefreshMinimapAttachedElements, QMT, doStats, doLayout)
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, Flush)
    else
        Flush()
    end
end


function QMT:GetManagedNativeQueueFrame()
    -- Retail clients can expose more than one queue-eye frame name. The minimap-era
    -- QueueStatusMinimapButton is the one that belongs on the minimap; QueueStatusButton
    -- may still exist for other Blizzard UI paths and must not be dragged on top of it.
    return _G.QueueStatusMinimapButton or _G.QueueStatusButton
end


function QMT:CaptureNativeQueueFrame(frame)
    if not frame then return end
    self.queueStatusOriginal = self.queueStatusOriginal or {}
    if self.queueStatusOriginal[frame] then return end
    self.queueStatusOriginal[frame] = {
        parent = frame.GetParent and frame:GetParent(),
        point = {frame:GetPoint(1)},
        scale = frame.GetScale and frame:GetScale() or 1,
        width = frame.GetWidth and frame:GetWidth(),
        height = frame.GetHeight and frame:GetHeight(),
        alpha = frame.GetAlpha and frame:GetAlpha() or 1,
        shown = frame.IsShown and frame:IsShown() or false,
    }
end

local function QFXRestoreNativeQueueFrame(frame, original)
    if not frame or not original then return end
    SafeCall(frame.SetParent, frame, original.parent or MinimapCluster or Minimap)
    SafeCall(frame.ClearAllPoints, frame)
    if original.point and original.point[1] then
        SafeCall(frame.SetPoint, frame, unpack(original.point))
    end
    if original.scale and frame.SetScale then SafeCall(frame.SetScale, frame, original.scale) end
    if original.width and original.height and frame.SetSize then
        SafeCall(frame.SetSize, frame, original.width, original.height)
    end
    if frame.SetAlpha then SafeCall(frame.SetAlpha, frame, original.alpha or 1) end
    if original.shown then
        if frame.Show then SafeCall(frame.Show, frame) end
    else
        if frame.Hide then SafeCall(frame.Hide, frame) end
    end
end


function QMT:ApplyQueueStatusButtonPosition()
    if not Minimap then return end
    local q = self:GetManagedNativeQueueFrame()
    if not q then return end

    if not self:ShouldCleanSquareMinimap() then
        QFXRestoreNativeQueueFrame(q, self.queueStatusOriginal and self.queueStatusOriginal[q])
        return
    end

    self:CaptureNativeQueueFrame(q)

    -- Only relocate Blizzard's minimap queue-eye. Never call Show() here: Blizzard owns
    -- the queue state and display timing. Forcing Show() makes the eye flash even when the
    -- player has not queued for anything.
    SafeCall(q.SetParent, q, Minimap)
    SafeCall(q.ClearAllPoints, q)
    SafeCall(q.SetPoint, q, "BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 2, 2)
    SafeCall(q.SetSize, q, 24, 24)
    SafeCall(q.SetScale, q, 0.5)
    SafeCall(q.SetFrameStrata, q, "HIGH")
    if q.SetFrameLevel and Minimap.GetFrameLevel then
        SafeCall(q.SetFrameLevel, q, (Minimap:GetFrameLevel() or 0) + 35)
    end
    if q.SetAlpha then SafeCall(q.SetAlpha, q, 1) end
    self:StripIconBackgroundAndBorder(q)

    if q.HookScript and not q.QFXMinimapToolsQueueHooked then
        q:HookScript("OnShow", function()
            QMT:ApplyQueueStatusButtonPosition()
        end)
        q.QFXMinimapToolsQueueHooked = true
    end
end

local function QFXHasNewMail(owner)
    local apiHasMail
    if HasNewMail then
        apiHasMail = SafeCall(HasNewMail)
        if apiHasMail then return true end
    end
    if owner and owner.mailNativeWantsShow then return true end
    local mail = _G.MiniMapMailFrame
    if mail and mail.IsShown and mail:IsShown() then return true end
    return apiHasMail and true or false
end

function QMT:ShouldUseCustomMailIndicator()
    return self.db
        and self.db.minimap
        and self.db.minimap.enabled
        and self.db.minimap.square
        and Minimap
end

function QMT:GetMailIndicator()
    if self.mailIndicator then return self.mailIndicator end
    if not Minimap then return nil end

    -- Addon-owned clean mail icon. It intentionally has no circular tracking border:
    -- the icon sits on the square minimap edge like a compact edge marker.
    local frame = CreateFrame("Frame", "QFXMinimapToolsMailIndicator", Minimap)
    frame:SetSize(20, 15)
    frame:EnableMouse(true)
    frame:SetFrameStrata("HIGH")
    if frame.SetFrameLevel and Minimap.GetFrameLevel then
        frame:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 38)
    end

    local icon = frame:CreateTexture(nil, "ARTWORK")
    if icon.SetAtlas then
        icon:SetAtlas("UI-HUD-Minimap-Mail-Up", true)
    else
        icon:SetTexture("Interface\\Minimap\\MiniMap-MailIcon")
        icon:SetSize(20, 15)
    end
    icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.Icon = icon

    frame:SetScript("OnEnter", function(owner)
        if not GameTooltip then return end
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.MAIL_PENDING or "New mail")
        if type(_G.MinimapMailFrameUpdate) == "function" then
            SafeCall(_G.MinimapMailFrameUpdate)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        if GameTooltip_Hide then
            GameTooltip_Hide()
        elseif GameTooltip then
            GameTooltip:Hide()
        end
    end)
    frame:Hide()

    self.mailIndicator = frame
    return frame
end

function QMT:CaptureNativeMailFrame()
    local mail = _G.MiniMapMailFrame
    if not mail or self.mailFrameOriginal then return end
    self.mailFrameOriginal = {
        parent = mail.GetParent and mail:GetParent(),
        point = {mail:GetPoint(1)},
        scale = mail.GetScale and mail:GetScale() or 1,
        width = mail.GetWidth and mail:GetWidth(),
        height = mail.GetHeight and mail:GetHeight(),
        alpha = mail.GetAlpha and mail:GetAlpha() or 1,
    }
end

function QMT:RestoreNativeMailFrame()
    local mail = _G.MiniMapMailFrame
    local original = self.mailFrameOriginal
    if not mail or not original then return end

    SafeCall(mail.SetParent, mail, original.parent or MinimapCluster or Minimap)
    SafeCall(mail.ClearAllPoints, mail)
    if original.point and original.point[1] then
        SafeCall(mail.SetPoint, mail, unpack(original.point))
    end
    if original.scale then SafeCall(mail.SetScale, mail, original.scale) end
    if original.width and original.height and mail.SetSize then
        SafeCall(mail.SetSize, mail, original.width, original.height)
    end
    if mail.SetAlpha then SafeCall(mail.SetAlpha, mail, original.alpha or 1) end
end

function QMT:ApplyMailFramePosition()
    local useCustom = self:ShouldUseCustomMailIndicator()
    local mail = _G.MiniMapMailFrame
    local indicator = self.mailIndicator

    if useCustom then
        self:CaptureNativeMailFrame()
        self.mailNativeWantsShow = self.mailNativeWantsShow or (mail and mail.IsShown and mail:IsShown()) or false

        -- Suppress Blizzard's native mail frame while square mode is active. The
        -- visible mail affordance now lives in the bottom utility row.
        if mail then
            if mail.SetAlpha then SafeCall(mail.SetAlpha, mail, 0) end
            if mail.Hide then
                self.suppressingMailNative = true
                SafeCall(mail.Hide, mail)
                self.suppressingMailNative = false
            end
            if mail.HookScript and not mail.QFXMinimapToolsMailSuppressHooked then
                mail:HookScript("OnShow", function(frame)
                    if not QMT:ShouldUseCustomMailIndicator() then return end
                    QMT.mailNativeWantsShow = true
                    local function HideNativeMailAgain()
                        if QMT:ShouldUseCustomMailIndicator() then
                            if frame.SetAlpha then SafeCall(frame.SetAlpha, frame, 0) end
                            if frame.Hide then
                                QMT.suppressingMailNative = true
                                SafeCall(frame.Hide, frame)
                                QMT.suppressingMailNative = false
                            end
                            SafeCall(QMT.ApplyMailFramePosition, QMT)
                            SafeCall(QMT.UpdateTimeStatusIcons, QMT)
                        end
                    end
                    if C_Timer and C_Timer.After then
                        C_Timer.After(0, HideNativeMailAgain)
                    else
                        HideNativeMailAgain()
                    end
                end)
                mail:HookScript("OnHide", function()
                    if QMT.suppressingMailNative then return end
                    QMT.mailNativeWantsShow = false
                    SafeCall(QMT.UpdateTimeStatusIcons, QMT)
                end)
                mail.QFXMinimapToolsMailSuppressHooked = true
            end
        end

        if indicator then indicator:Hide() end
        SafeCall(self.UpdateTimeStatusIcons, self)
    else
        if indicator then indicator:Hide() end
        SafeCall(self.UpdateTimeStatusIcons, self)
        self:RestoreNativeMailFrame()
    end
end


local function QFXSetTextureOrAtlas(texture, atlas, fallback)
    if not texture then return end
    if atlas and texture.SetAtlas then
        local ok = pcall(texture.SetAtlas, texture, atlas, false)
        if ok then return end
    end
    if fallback and texture.SetTexture then SafeCall(texture.SetTexture, texture, fallback) end
end

local function QFXClickNativeFrame(frame, mouseButton)
    if not frame then return end
    mouseButton = mouseButton or "LeftButton"
    local script = frame.GetScript and frame:GetScript("OnClick")
    if script then
        SafeCall(script, frame, mouseButton, false)
    elseif frame.Click then
        SafeCall(frame.Click, frame, mouseButton)
    end
end

local function QFXShowNativeFrameTooltip(frame, owner)
    if not frame or not owner then return false end
    local script = frame.GetScript and frame:GetScript("OnEnter")
    if not script then return false end
    if GameTooltip then GameTooltip:SetOwner(owner, "ANCHOR_CURSOR") end
    SafeCall(script, frame)
    return GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown()
end

local function QFXDecorRegionKey(region)
    if not region then return "" end
    local name = region.GetName and region:GetName() or ""
    local texture = region.GetTexture and region:GetTexture() or ""
    local atlas = region.GetAtlas and region:GetAtlas() or ""
    return string.lower(tostring(name or "") .. " " .. tostring(texture or "") .. " " .. tostring(atlas or ""))
end

local function QFXLooksLikeDecorativeIconLayer(region)
    local key = QFXDecorRegionKey(region)
    if key == "" then return false end
    if key:find("border", 1, true) then return true end
    if key:find("background", 1, true) then return true end
    if key:find("backdrop", 1, true) then return true end
    if key:find("bg", 1, true) then return true end
    if key:find("ring", 1, true) then return true end
    if key:find("circle", 1, true) then return true end
    if key:find("round", 1, true) then return true end
    if key:find("glow", 1, true) then return true end
    if key:find("shadow", 1, true) then return true end
    if key:find("overlay", 1, true) then return true end
    if key:find("highlight", 1, true) then return true end
    if key:find("pushed", 1, true) then return true end
    return false
end

function QMT:StripIconBackgroundAndBorder(frame)
    if not frame then return end
    local function VisitRegion(region)
        if region and QFXLooksLikeDecorativeIconLayer(region) then
            if not region.QFXMinimapToolsDecorOriginal then
                region.QFXMinimapToolsDecorOriginal = {
                    alpha = region.GetAlpha and region:GetAlpha() or 1,
                    shown = region.IsShown and region:IsShown() or false,
                }
            end
            if region.SetAlpha then SafeCall(region.SetAlpha, region, 0) end
            if region.Hide then SafeCall(region.Hide, region) end
        end
    end

    if frame.SetBackdropColor then SafeCall(frame.SetBackdropColor, frame, 0, 0, 0, 0) end
    if frame.SetBackdropBorderColor then SafeCall(frame.SetBackdropBorderColor, frame, 0, 0, 0, 0) end
    if frame.GetRegions then
        for _, region in ipairs({frame:GetRegions()}) do VisitRegion(region) end
    end
    if frame.GetChildren then
        for _, child in ipairs({frame:GetChildren()}) do
            if child.SetBackdropColor then SafeCall(child.SetBackdropColor, child, 0, 0, 0, 0) end
            if child.SetBackdropBorderColor then SafeCall(child.SetBackdropBorderColor, child, 0, 0, 0, 0) end
            if child.GetRegions then
                for _, region in ipairs({child:GetRegions()}) do VisitRegion(region) end
            end
        end
    end
end


local QFX_UTILITY_ROW_HEIGHT = 22
local QFX_UTILITY_ICON_SIZE = QFX_UTILITY_ROW_HEIGHT

function QMT:ApplyIndicatorTextFont(btn)
    if not btn then return end
    local d = self.db and self.db.display or {}
    local font = d.font
    if self.ResolveFontPath then font = self.ResolveFontPath(font) end
    local size = tonumber(d.fontSize) or 12
    local outline = d.outline or "OUTLINE"
    local function Apply(fs)
        if not fs then return end
        if self.ApplyFontStringFont then
            self.ApplyFontStringFont(fs, font, size, outline)
        elseif fs.SetFont and font then
            fs:SetFont(font, size, outline)
        end
        if d.shadow then
            fs:SetShadowColor(0, 0, 0, 1)
            fs:SetShadowOffset(1, -1)
        else
            fs:SetShadowOffset(0, 0)
        end
    end
    Apply(btn.Label)
    Apply(btn.Badge)
end

function QMT:CreateIndicatorButton(key)
    self.indicatorButtons = self.indicatorButtons or {}
    if self.indicatorButtons[key] then return self.indicatorButtons[key] end

    -- Use UIParent as the real parent. Some client builds clip children that are
    -- anchored outside the Minimap texture area, which made the 1.0.44 bottom
    -- glass panels look like they were not implemented. The buttons are still
    -- positioned relative to Minimap through the utility row.
    local parent = UIParent or Minimap
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local btn = CreateFrame("Button", "QFXMinimapToolsIndicator_" .. key, parent, template)
    btn:SetSize(QFX_UTILITY_ROW_HEIGHT, QFX_UTILITY_ROW_HEIGHT)
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(360)
    btn:SetHitRectInsets(-3, -3, -3, -3)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    if btn.SetBackdrop then
        btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        btn:SetBackdropColor(0, 0, 0, 0)
        btn:SetBackdropBorderColor(0, 0, 0, 0)
    end

    -- No glass highlight texture is created for text widgets. Keeping the
    -- bottom row as plain text lowers texture count and avoids overlaying
    -- other addons with decorative frames.

    btn.Icon = btn:CreateTexture(nil, "ARTWORK")
    btn.Icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.Icon:SetSize(QFX_UTILITY_ICON_SIZE, QFX_UTILITY_ICON_SIZE)

    btn.HighlightIcon = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.HighlightIcon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.HighlightIcon:SetSize(QFX_UTILITY_ICON_SIZE, QFX_UTILITY_ICON_SIZE)
    btn.HighlightIcon:SetBlendMode("ADD")
    btn.HighlightIcon:SetAlpha(0.75)
    btn:SetHighlightTexture(btn.HighlightIcon)

    btn.Label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.Label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.Label:SetTextColor(1, 1, 1, 1)
    btn.Label:SetWordWrap(false)
    btn.Label:Hide()

    btn.Badge = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.Badge:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.Badge:SetTextColor(1, 1, 1, 1)
    btn.Badge:SetShadowColor(0, 0, 0, 1)
    btn.Badge:SetShadowOffset(1, -1)
    btn.Badge:SetWordWrap(false)
    btn.Badge:Hide()

    btn:HookScript("OnMouseDown", function(self)
        if self.PushedAtlas or self.PushedFallback then
            QFXSetTextureOrAtlas(self.Icon, self.PushedAtlas, self.PushedFallback or self.NormalFallback)
        end
    end)
    btn:HookScript("OnMouseUp", function(self)
        if self.NormalAtlas or self.NormalFallback then
            QFXSetTextureOrAtlas(self.Icon, self.NormalAtlas, self.NormalFallback)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if self.NormalAtlas or self.NormalFallback then
            QFXSetTextureOrAtlas(self.Icon, self.NormalAtlas, self.NormalFallback)
        end
        GameTooltip:Hide()
    end)
    btn:Hide()
    self.indicatorButtons[key] = btn
    return btn
end

function QMT:ApplyIndicatorButtonStyle(btn, glass)
    if not btn then return end
    local styleKey = glass and "glass" or "plain"
    if btn.__qfxIndicatorStyle == styleKey then return end
    btn.__qfxIndicatorStyle = styleKey
    if btn.SetBackdrop then
        btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        if glass then
            btn:SetBackdropColor(0.02, 0.04, 0.06, 0.48)
        else
            btn:SetBackdropColor(0, 0, 0, 0)
        end
        btn:SetBackdropBorderColor(0, 0, 0, 0)
    end
    if btn.GlassTop then btn.GlassTop:SetShown(glass and true or false) end
end

function QMT:ClearIndicatorBadge(btn)
    if btn and btn.Badge then btn.Badge:Hide() end
end

function QMT:SetIndicatorBadge(btn, text, r, g, b)
    if not btn or not btn.Badge then return end
    self:ApplyIndicatorTextFont(btn)
    btn.Badge:SetText(text or "")
    btn.Badge:SetTextColor(r or 1, g or 1, b or 1, 1)
    btn.Badge:Show()
end

function QMT:ShowIndicatorIcon(btn, atlas, fallback, r, g, b, highlightAtlas, pushedAtlas, highlightFallback, pushedFallback)
    if not btn then return end
    btn.__qfxGlassHighlightReady = nil
    btn.__qfxGlassLabelReady = nil
    self:ApplyIndicatorButtonStyle(btn, false)
    self:ClearIndicatorBadge(btn)
    if btn.Label then btn.Label:Hide() end
    if btn.Icon then
        btn.Icon:ClearAllPoints()
        btn.Icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn.Icon:SetSize(QFX_UTILITY_ICON_SIZE, QFX_UTILITY_ICON_SIZE)
        QFXSetTextureOrAtlas(btn.Icon, atlas, fallback)
        btn.Icon:SetSize(QFX_UTILITY_ICON_SIZE, QFX_UTILITY_ICON_SIZE)
        btn.Icon:SetVertexColor(r or 1, g or 1, b or 1, 1)
        btn.Icon:Show()
    end
    if btn.HighlightIcon then
        btn.HighlightIcon:ClearAllPoints()
        btn.HighlightIcon:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn.HighlightIcon:SetSize(QFX_UTILITY_ICON_SIZE, QFX_UTILITY_ICON_SIZE)
        QFXSetTextureOrAtlas(btn.HighlightIcon, highlightAtlas or atlas, highlightFallback or fallback)
        btn.HighlightIcon:SetSize(QFX_UTILITY_ICON_SIZE, QFX_UTILITY_ICON_SIZE)
        btn.HighlightIcon:SetVertexColor(1, 1, 1, 1)
    end
    btn.NormalAtlas, btn.NormalFallback = atlas, fallback
    btn.PushedAtlas, btn.PushedFallback = pushedAtlas, pushedFallback
    btn:SetSize(QFX_UTILITY_ROW_HEIGHT, QFX_UTILITY_ROW_HEIGHT)
end

function QMT:ShouldUseUtilityRow()
    -- Bottom utility widgets are anchored to the real Minimap and should exist
    -- whenever the minimap enhancement is enabled. Do not require square mode:
    -- users can keep the same bottom FPS / phase glass panels if they temporarily
    -- switch the map shape.
    return self.db and self.db.minimap and self.db.minimap.enabled and Minimap
end

function QMT:GetUtilityRow()
    if self.utilityRow then return self.utilityRow end
    -- Parent the row to UIParent instead of Minimap so the widgets below the
    -- square map are never clipped by the Minimap frame.
    local row = CreateFrame("Frame", "QFXMinimapToolsUtilityRow", UIParent or Minimap)
    row:SetFrameStrata("LOW")
    row:SetFrameLevel(1)
    row:SetSize(1, QFX_UTILITY_ROW_HEIGHT)
    row:Hide()
    self.utilityRow = row
    return row
end

function QMT:GetNativeCraftingOrderFrame()
    local indicator = MinimapCluster and MinimapCluster.IndicatorFrame
    if indicator and indicator.CraftingOrderFrame then return indicator.CraftingOrderFrame end
    return _G.CraftingOrderFrame or _G.ProfessionsCustomerOrdersFrame or _G.ProfessionsCustomerOrders_MinimapButton
end

function QMT:SuppressNativeCraftingOrderFrame()
    local frame = self:GetNativeCraftingOrderFrame()
    if not frame then return end
    self.craftingOrderNativeWantsShow = self.craftingOrderNativeWantsShow or (frame.IsShown and frame:IsShown())
    if frame.SetAlpha then SafeCall(frame.SetAlpha, frame, 0) end
    if frame.Hide then
        self.suppressingCraftingNative = true
        SafeCall(frame.Hide, frame)
        self.suppressingCraftingNative = false
    end
    if frame.HookScript and not frame.QFXMinimapToolsCraftingHooked then
        frame:HookScript("OnShow", function(f)
            if not QMT:ShouldUseUtilityRow() then return end
            QMT.craftingOrderNativeWantsShow = true
            if f.SetAlpha then SafeCall(f.SetAlpha, f, 0) end
            if f.Hide then
                QMT.suppressingCraftingNative = true
                SafeCall(f.Hide, f)
                QMT.suppressingCraftingNative = false
            end
            SafeCall(QMT.UpdateTimeStatusIcons, QMT)
        end)
        frame:HookScript("OnHide", function()
            if QMT.suppressingCraftingNative then return end
            QMT.craftingOrderNativeWantsShow = false
            SafeCall(QMT.UpdateTimeStatusIcons, QMT)
        end)
        frame.QFXMinimapToolsCraftingHooked = true
    end
end

function QMT:HasCraftingOrderIndicator()
    local frame = self:GetNativeCraftingOrderFrame()
    if frame and frame.IsShown and frame:IsShown() then return true end
    return self.craftingOrderNativeWantsShow and true or false
end

function QMT:GetUtilitySystemText()
    local fps = math.floor((GetFramerate and GetFramerate() or 0) + 0.5)
    local down, up, home, world = 0, 0, 0, 0
    if GetNetStats then down, up, home, world = GetNetStats() end
    local latency = tonumber(world) or tonumber(home) or 0
    if latency <= 0 then latency = tonumber(home) or 0 end
    return tostring(fps) .. " | " .. tostring(math.floor(latency + 0.5))
end

function QMT:GetUtilityPhaseText()
    local phaseID = self.DetectPhaseID and self:DetectPhaseID()
    return phaseID and tostring(phaseID) or "--"
end

function QMT:GetUtilityCoordinatesText()
    if not self.GetCoordinatesText then return "" end
    local text = self:GetCoordinatesText()
    return text or ""
end

function QMT:ApplyUtilityTextFont(frame)
    if not frame or not frame.Text then return end
    local d = self.db and self.db.display or {}
    local font = d.font
    if self.ResolveFontPath then font = self.ResolveFontPath(font) end
    local size = tonumber(d.fontSize) or 12
    local outline = d.outline or "OUTLINE"
    if self.ApplyFontStringFont then
        self.ApplyFontStringFont(frame.Text, font, size, outline)
    elseif frame.Text.SetFont and font then
        frame.Text:SetFont(font, size, outline)
    end
    if d.shadow then
        frame.Text:SetShadowColor(0, 0, 0, 1)
        frame.Text:SetShadowOffset(1, -1)
    else
        frame.Text:SetShadowOffset(0, 0)
    end
    frame.__qfxFontKey = tostring(font or "") .. ":" .. tostring(size) .. ":" .. tostring(outline) .. ":" .. tostring(d.shadow and 1 or 0)
end

function QMT:CreateUtilityTextFrame(key)
    self.utilityTextFrames = self.utilityTextFrames or {}
    if self.utilityTextFrames[key] then return self.utilityTextFrames[key] end

    local parent = self:GetUtilityRow()
    local frame = CreateFrame("Frame", "QFXMinimapToolsUtilityText_" .. key, parent or UIParent or Minimap)
    frame:SetFrameStrata("LOW")
    frame:SetFrameLevel(2)
    frame:SetSize(10, QFX_UTILITY_ROW_HEIGHT)
    frame:EnableMouse(true)
    frame:SetHitRectInsets(-2, -2, -2, -2)
    frame.Text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.Text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.Text:SetJustifyH("CENTER")
    frame.Text:SetWordWrap(false)
    frame.Text:SetTextColor(1, 1, 1, 1)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame:Hide()
    self:ApplyUtilityTextFont(frame)
    self.utilityTextFrames[key] = frame
    return frame
end

function QMT:SetUtilityText(frame, text, minWidth, r, g, b)
    if not frame or not frame.Text then return false end
    text = text or ""
    local changed = false
    local d = self.db and self.db.display or {}
    local font = d.font
    if self.ResolveFontPath then font = self.ResolveFontPath(font) end
    local fontKey = tostring(font or "") .. ":" .. tostring(tonumber(d.fontSize) or 12) .. ":" .. tostring(d.outline or "OUTLINE") .. ":" .. tostring(d.shadow and 1 or 0)
    if frame.__qfxFontKey ~= fontKey then
        self:ApplyUtilityTextFont(frame)
        frame.__qfxLastWidth = nil
        changed = true
    end
    if frame.__qfxText ~= text then
        frame.Text:SetText(text)
        frame.__qfxText = text
        frame.__qfxLastWidth = nil
        changed = true
    end
    local cr, cg, cb = r or 1, g or 1, b or 1
    local colorKey = tostring(cr) .. ":" .. tostring(cg) .. ":" .. tostring(cb)
    if frame.__qfxColorKey ~= colorKey then
        frame.Text:SetTextColor(cr, cg, cb, 1)
        frame.__qfxColorKey = colorKey
    end
    local textW = frame.__qfxLastWidth
    if not textW then
        textW = frame.Text:GetStringWidth() or 0
        frame.__qfxLastWidth = textW
    end
    local w = math.max(tonumber(minWidth) or 10, textW + 4)
    if frame.__qfxWidth ~= w or frame.__qfxHeight ~= QFX_UTILITY_ROW_HEIGHT then
        frame:SetSize(w, QFX_UTILITY_ROW_HEIGHT)
        frame.__qfxWidth = w
        frame.__qfxHeight = QFX_UTILITY_ROW_HEIGHT
        changed = true
    end
    if not frame:IsShown() then
        frame:Show()
        changed = true
    end
    return changed
end

function QMT:HideUtilityText(frame)
    if frame and frame:IsShown() then
        frame:Hide()
        return true
    end
    return false
end

local function QFXCancelUtilityTicker(owner, key)
    local ticker = owner and owner[key]
    if ticker and ticker.Cancel then SafeCall(ticker.Cancel, ticker) end
    if owner then owner[key] = nil end
end

function QMT:StartUtilitySystemHoverTicker()
    if not self.db or not self.db.display or not self.db.display.system then return end
    if self.UpdateUtilitySystemText then SafeCall(self.UpdateUtilitySystemText, self) end
    if not C_Timer or not C_Timer.NewTicker or self.utilitySystemHoverTicker then return end
    self.utilitySystemHoverTicker = C_Timer.NewTicker(0.75, function()
        if not QMT.db or not QMT.db.display or not QMT.db.display.system then
            QFXCancelUtilityTicker(QMT, "utilitySystemHoverTicker")
            return
        end
        SafeCall(QMT.UpdateUtilitySystemText, QMT)
    end)
end

function QMT:StopUtilitySystemHoverTicker()
    QFXCancelUtilityTicker(self, "utilitySystemHoverTicker")
end

function QMT:StartUtilityCoordinatesHoverTicker()
    if not self.db or not self.db.display or not self.db.display.coordinates then return end
    if self.UpdateUtilityCoordinatesText then SafeCall(self.UpdateUtilityCoordinatesText, self) end
    if not C_Timer or not C_Timer.NewTicker or self.utilityCoordsHoverTicker then return end
    self.utilityCoordsHoverTicker = C_Timer.NewTicker(0.50, function()
        if not QMT.db or not QMT.db.display or not QMT.db.display.coordinates then
            QFXCancelUtilityTicker(QMT, "utilityCoordsHoverTicker")
            return
        end
        SafeCall(QMT.UpdateUtilityCoordinatesText, QMT)
    end)
end

function QMT:StopUtilityCoordinatesHoverTicker()
    QFXCancelUtilityTicker(self, "utilityCoordsHoverTicker")
end

function QMT:SetupUtilityHoverRefresh()
    if self.utilityHoverRefreshHooked then return end
    if Minimap and Minimap.HookScript then
        Minimap:HookScript("OnEnter", function()
            if QMT.db and QMT.db.display and QMT.db.display.coordinates then
                SafeCall(QMT.StartUtilityCoordinatesHoverTicker, QMT)
            end
        end)
        Minimap:HookScript("OnLeave", function()
            SafeCall(QMT.StopUtilityCoordinatesHoverTicker, QMT)
        end)
        self.utilityHoverRefreshHooked = true
    end
end

function QMT:UpdateUtilitySystemText(skipLayout)
    local d = self.db and self.db.display or {}
    local frame = self:CreateUtilityTextFrame("system")
    local changed
    if self:ShouldUseUtilityRow() and d.system then
        changed = self:SetUtilityText(frame, self:GetUtilitySystemText(), 44, 1, 1, 1)
        frame:SetScript("OnEnter", function(owner)
            -- FPS/MS has its own 5s lightweight ticker; on hover only refresh once
            -- before showing the detailed tooltip, no extra hover ticker.
            SafeCall(QMT.UpdateUtilitySystemText, QMT, true)
            QMT:ShowSystemTooltip(owner)
        end)
        frame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    else
        SafeCall(self.StopUtilitySystemHoverTicker, self)
        changed = self:HideUtilityText(frame)
    end
    if changed and not skipLayout then self:LayoutUtilityRow() end
    return changed
end

function QMT:UpdateUtilityCoordinatesText(skipLayout)
    local d = self.db and self.db.display or {}
    local frame = self:CreateUtilityTextFrame("coordinates")
    local text = self:GetUtilityCoordinatesText()
    local changed
    if self:ShouldUseUtilityRow() and d.coordinates and text and text ~= "" then
        changed = self:SetUtilityText(frame, text, 58, 1, 1, 1)
        frame:SetScript("OnEnter", function(owner)
            SafeCall(QMT.StartUtilityCoordinatesHoverTicker, QMT)
            GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
            GameTooltip:AddLine(L.COPY_COORDS or (QMT.ZH and "复制坐标" or "Copy coordinates"))
            GameTooltip:AddLine(frame.__qfxText or text, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        frame:SetScript("OnLeave", function()
            SafeCall(QMT.StopUtilityCoordinatesHoverTicker, QMT)
            GameTooltip:Hide()
        end)
        frame:SetScript("OnMouseDown", function(_, button)
            if button == "LeftButton" and QMT.ShowCopyCoordinatesPopup then QMT:ShowCopyCoordinatesPopup() end
        end)
    else
        SafeCall(self.StopUtilityCoordinatesHoverTicker, self)
        changed = self:HideUtilityText(frame)
    end
    if changed and not skipLayout then self:LayoutUtilityRow() end
    return changed
end

function QMT:UpdateUtilityPhaseText(skipLayout)
    local d = self.db and self.db.display or {}
    local frame = self:CreateUtilityTextFrame("phase")
    local changed
    if self:ShouldUseUtilityRow() and d.phaseID then
        changed = self:SetUtilityText(frame, self:GetUtilityPhaseText(), 42, 1, 1, 1)
        frame:SetScript("OnEnter", function(owner)
            GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
            GameTooltip:AddLine(QMT.ZH and "位面 ID" or "Phase ID")
            if QMT.GetPhaseIDText then GameTooltip:AddLine(QMT:GetPhaseIDText(), 1, 1, 1, true) end
            GameTooltip:AddLine(QMT.ZH and "只在鼠标指向或目标变化时更新。" or "Updates only on mouseover or target changes.", 0.75, 0.75, 0.75, true)
            GameTooltip:Show()
        end)
    else
        changed = self:HideUtilityText(frame)
    end
    if changed and not skipLayout then self:LayoutUtilityRow() end
    return changed
end

function QMT:UpdateTimeStatusIcons(skipLayout)
    self:SuppressNativeCraftingOrderFrame()

    local d = self.db and self.db.display or {}
    local canUse = self:ShouldUseUtilityRow() and Minimap and not (self.IsOutdoorFlightCenterActive and self:IsOutdoorFlightCenterActive())
    local timeFrame = self.statFrames and self.statFrames.time
    local canAttachToTime = canUse and d.time and timeFrame and timeFrame.IsShown and timeFrame:IsShown()
    local statusLevel = Minimap and Minimap.GetFrameLevel and ((Minimap:GetFrameLevel() or 0) + 43) or 360

    local calendar = self:CreateIndicatorButton("calendar")
    if canUse then
        local day = tonumber(date and date("%d")) or 1
        self:ShowIndicatorIcon(
            calendar,
            "UI-HUD-Calendar-" .. tostring(day) .. "-Up",
            "Interface\\Calendar\\UI-Calendar-Button",
            1, 1, 1,
            "UI-HUD-Calendar-" .. tostring(day) .. "-Mouseover",
            "UI-HUD-Calendar-" .. tostring(day) .. "-Down",
            "Interface\\Calendar\\UI-Calendar-Button",
            "Interface\\Calendar\\UI-Calendar-Button"
        )
        calendar:SetScript("OnEnter", function(owner)
            GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
            GameTooltip:AddLine(QMT.ZH and "日历" or "Calendar")
            GameTooltip:AddLine(QMT.ZH and "左键打开日历" or "Left-click to open the calendar", 1, 1, 1)
            if QMT:HasCalendarNotification() then GameTooltip:AddLine(L.CALENDAR_PENDING or "Pending invites", 1, 0.82, 0.1, true) end
            GameTooltip:Show()
        end)
        calendar:SetScript("OnClick", function(_, button) if button == "LeftButton" and ToggleCalendar then ToggleCalendar() end end)
        calendar:SetParent(Minimap)
        calendar:SetFrameStrata("HIGH")
        if calendar.SetFrameLevel then calendar:SetFrameLevel(statusLevel) end
        calendar:ClearAllPoints()
        if canAttachToTime then
            calendar:SetPoint("RIGHT", timeFrame, "LEFT", -2, 0)
        else
            calendar:SetPoint("BOTTOM", Minimap, "BOTTOM", 0, 3)
        end
        calendar:Show()
        self:StripIconBackgroundAndBorder(calendar)
    else
        calendar:Hide()
    end

    local mail = self:CreateIndicatorButton("mail")
    local hasMail = canUse and QFXHasNewMail(self)
    if hasMail then
        self:ShowIndicatorIcon(
            mail,
            "UI-HUD-Minimap-Mail-Up",
            "Interface\\Minimap\\MiniMap-MailIcon",
            1, 1, 1,
            "UI-HUD-Minimap-Mail-Mouseover",
            "UI-HUD-Minimap-Mail-Down",
            "Interface\\Minimap\\MiniMap-MailIcon",
            "Interface\\Minimap\\MiniMap-MailIcon"
        )
        mail:SetScript("OnEnter", function(owner)
            if not QFXShowNativeFrameTooltip(_G.MiniMapMailFrame, owner) then
                GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
                GameTooltip:AddLine(L.MAIL_PENDING or (QMT.ZH and "有新邮件" or "New mail"))
                GameTooltip:Show()
            end
        end)
        mail:SetScript("OnClick", function(_, button) QFXClickNativeFrame(_G.MiniMapMailFrame, button) end)
    else
        mail:Hide()
    end

    local crafting = self:CreateIndicatorButton("crafting")
    local hasCrafting = canUse and self:HasCraftingOrderIndicator()
    if hasCrafting then
        self:ShowIndicatorIcon(
            crafting,
            "UI-HUD-Minimap-CraftingOrder-Up-2x",
            "Interface\\Icons\\INV_Inscription_Tradeskill01",
            1, 1, 1,
            "UI-HUD-Minimap-CraftingOrder-Over-2x",
            "UI-HUD-Minimap-CraftingOrder-Down-2x",
            "Interface\\Icons\\INV_Inscription_Tradeskill01",
            "Interface\\Icons\\INV_Inscription_Tradeskill01"
        )
        crafting:SetScript("OnEnter", function(owner)
            local native = QMT:GetNativeCraftingOrderFrame()
            if not QFXShowNativeFrameTooltip(native, owner) then
                GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
                GameTooltip:AddLine(QMT.ZH and "制造订单" or "Crafting Orders")
                local info = C_CraftingOrders and C_CraftingOrders.GetPersonalOrdersInfo and SafeCall(C_CraftingOrders.GetPersonalOrdersInfo)
                if type(info) == "table" then
                    for _, order in pairs(info) do
                        local name = order.professionName or order.name
                        local count = order.numPersonalOrders or order.numOrders
                        if name and count then GameTooltip:AddDoubleLine(tostring(name), tostring(count), 1, 1, 1, 1, 1, 1) end
                    end
                end
                GameTooltip:Show()
            end
        end)
        crafting:SetScript("OnClick", function(_, button) QFXClickNativeFrame(QMT:GetNativeCraftingOrderFrame(), button) end)
    else
        crafting:Hide()
    end

    local statusAnchor = canAttachToTime and timeFrame or (calendar and calendar.IsShown and calendar:IsShown() and calendar or nil)
    local function AttachStatusIcon(icon)
        if not icon or not canUse or not statusAnchor then
            if icon then icon:Hide() end
            return
        end
        icon:SetParent(Minimap)
        icon:SetFrameStrata("HIGH")
        if icon.SetFrameLevel then icon:SetFrameLevel(statusLevel) end
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", statusAnchor, "RIGHT", 2, 0)
        icon:Show()
        QMT:StripIconBackgroundAndBorder(icon)
        statusAnchor = icon
    end
    AttachStatusIcon(hasMail and mail or nil)
    AttachStatusIcon(hasCrafting and crafting or nil)
end

function QMT:LayoutUtilityRow()
    local row = self:GetUtilityRow()
    if not self:ShouldUseUtilityRow() then
        SafeCall(self.StopUtilitySystemHoverTicker, self)
        SafeCall(self.StopUtilityCoordinatesHoverTicker, self)
        if row then row:Hide() end
        if self.utilityTextFrames then
            for _, frame in pairs(self.utilityTextFrames) do if frame and frame.Hide then frame:Hide() end end
        end
        return
    end

    local d = self.db and self.db.display or {}
    local system = self.utilityTextFrames and self.utilityTextFrames.system
    local coords = self.utilityTextFrames and self.utilityTextFrames.coordinates
    local phase = self.utilityTextFrames and self.utilityTextFrames.phase
    local hasSystem = d.system and system and system.IsShown and system:IsShown()
    local hasCoords = d.coordinates and coords and coords.IsShown and coords:IsShown()
    local hasPhase = d.phaseID and phase and phase.IsShown and phase:IsShown()
    local rowHasAny = hasSystem or hasCoords or hasPhase

    if not rowHasAny then
        row:Hide()
        return
    end

    row:SetParent(UIParent or Minimap)
    row:SetFrameStrata("LOW")
    if row.SetFrameLevel then row:SetFrameLevel(1) end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", 0, -4)
    row:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 0, -4)
    row:SetHeight(QFX_UTILITY_ROW_HEIGHT)
    row:Show()

    local rowLevel = (row:GetFrameLevel() or 1) + 1
    if hasSystem then
        system:SetParent(row)
        system:SetFrameStrata("LOW")
        system:SetFrameLevel(rowLevel)
        system:ClearAllPoints()
        system:SetPoint("LEFT", row, "LEFT", 0, 0)
    end
    if hasCoords then
        coords:SetParent(row)
        coords:SetFrameStrata("LOW")
        coords:SetFrameLevel(rowLevel)
        coords:ClearAllPoints()
        coords:SetPoint("CENTER", row, "CENTER", 0, 0)
    end
    if hasPhase then
        phase:SetParent(row)
        phase:SetFrameStrata("LOW")
        phase:SetFrameLevel(rowLevel)
        phase:ClearAllPoints()
        phase:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    end
end

function QMT:UpdateUtilityRow()
    local row = self:GetUtilityRow()
    if not self:ShouldUseUtilityRow() then
        SafeCall(self.StopUtilitySystemHoverTicker, self)
        SafeCall(self.StopUtilityCoordinatesHoverTicker, self)
        if row then row:Hide() end
        if self.utilityTextFrames then for _, frame in pairs(self.utilityTextFrames) do if frame and frame.Hide then frame:Hide() end end end
        if self.indicatorButtons then for _, btn in pairs(self.indicatorButtons) do if btn and btn.Hide then btn:Hide() end end end
        return
    end

    self:UpdateUtilitySystemText(true)
    self:UpdateUtilityCoordinatesText(true)
    self:UpdateUtilityPhaseText(true)
    self:UpdateTimeStatusIcons(true)
    self:LayoutUtilityRow()
    self:SetupUtilityHoverRefresh()

end

function QMT:ShouldUseNativeTrackingCorner()
    return self.db
        and self.db.minimap
        and self.db.minimap.enabled
        and self.db.minimap.square
        and Minimap
end

function QMT:GetNativeTrackingFrame()
    if MinimapCluster and MinimapCluster.Tracking then
        return MinimapCluster.Tracking
    end
    return _G.MiniMapTracking
end

function QMT:CaptureNativeTrackingFrame()
    local tracking = self:GetNativeTrackingFrame()
    if not tracking or self.trackingFrameOriginal then return end
    self.trackingFrameOriginal = {
        parent = tracking.GetParent and tracking:GetParent(),
        point = {tracking:GetPoint(1)},
        scale = tracking.GetScale and tracking:GetScale() or 1,
        width = tracking.GetWidth and tracking:GetWidth(),
        height = tracking.GetHeight and tracking:GetHeight(),
        alpha = tracking.GetAlpha and tracking:GetAlpha() or 1,
    }
end

local function QFXTrackingBorderKey(region)
    if not region then return "" end
    local name = region.GetName and region:GetName() or ""
    local texture = region.GetTexture and region:GetTexture()
    return string.lower(tostring(name or "") .. " " .. tostring(texture or ""))
end

local function QFXLooksLikeTrackingOuterBorder(region)
    local key = QFXTrackingBorderKey(region)
    if key == "" then return false end
    if key:find("trackingborder", 1, true) then return true end
    if key:find("tracking_border", 1, true) then return true end
    if key:find("minimap-trackingborder", 1, true) then return true end
    if key:find("minimap_trackingborder", 1, true) then return true end
    if key:find("tracking", 1, true) and key:find("border", 1, true) then return true end
    return false
end

local function QFXRememberAndHideTrackingOuterBorder(region)
    if not region then return end
    if not region.QFXMinimapToolsTrackingBorderOriginal then
        region.QFXMinimapToolsTrackingBorderOriginal = {
            alpha = region.GetAlpha and region:GetAlpha() or 1,
            shown = region.IsShown and region:IsShown() or false,
        }
    end
    if region.SetAlpha then SafeCall(region.SetAlpha, region, 0) end
    if region.Hide then SafeCall(region.Hide, region) end
end

local function QFXRestoreTrackingOuterBorderRegion(region)
    if not region then return end
    local original = region.QFXMinimapToolsTrackingBorderOriginal
    if not original then return end
    if region.SetAlpha then SafeCall(region.SetAlpha, region, original.alpha or 1) end
    if original.shown then
        if region.Show then SafeCall(region.Show, region) end
    else
        if region.Hide then SafeCall(region.Hide, region) end
    end
end

local function QFXWalkTrackingOuterBorderRegions(frame, callback)
    if not frame or type(callback) ~= "function" then return end
    local seen = {}
    local function Visit(region)
        if not region or seen[region] then return end
        seen[region] = true
        if QFXLooksLikeTrackingOuterBorder(region) then
            callback(region)
        end
    end

    Visit(_G.MiniMapTrackingButtonBorder)
    Visit(_G.MiniMapTrackingBorder)
    Visit(frame.Border)
    Visit(frame.border)

    if frame.GetRegions then
        for _, region in ipairs({frame:GetRegions()}) do Visit(region) end
    end
    if frame.GetChildren then
        for _, child in ipairs({frame:GetChildren()}) do
            if child and child.GetRegions then
                for _, region in ipairs({child:GetRegions()}) do Visit(region) end
            end
        end
    end
end

function QMT:HideNativeTrackingOuterBorder()
    local tracking = self:GetNativeTrackingFrame()
    if not tracking then return end
    QFXWalkTrackingOuterBorderRegions(tracking, QFXRememberAndHideTrackingOuterBorder)
end

function QMT:RestoreNativeTrackingOuterBorder()
    local tracking = self:GetNativeTrackingFrame()
    if not tracking then return end
    QFXWalkTrackingOuterBorderRegions(tracking, QFXRestoreTrackingOuterBorderRegion)
end

function QMT:RestoreNativeTrackingFrame()
    local tracking = self:GetNativeTrackingFrame()
    local original = self.trackingFrameOriginal
    if not tracking or not original then
        self:RestoreNativeTrackingOuterBorder()
        return
    end

    SafeCall(tracking.SetParent, tracking, original.parent or MinimapCluster or Minimap)
    SafeCall(tracking.ClearAllPoints, tracking)
    if original.point and original.point[1] then
        SafeCall(tracking.SetPoint, tracking, unpack(original.point))
    end
    if original.scale then SafeCall(tracking.SetScale, tracking, original.scale) end
    if original.width and original.height and tracking.SetSize then
        SafeCall(tracking.SetSize, tracking, original.width, original.height)
    end
    if tracking.SetAlpha then SafeCall(tracking.SetAlpha, tracking, original.alpha or 1) end
    self:RestoreNativeTrackingOuterBorder()
end

function QMT:GetNativeTrackingButton()
    local tracking = self:GetNativeTrackingFrame()
    if tracking and tracking.Button then return tracking.Button end
    return _G.MiniMapTrackingButton or tracking
end

function QMT:OpenNativeTrackingMenu(owner)
    local blizBtn = self:GetNativeTrackingButton()
    if not blizBtn then return end
    if owner then
        SafeCall(blizBtn.SetParent, blizBtn, Minimap or owner)
        SafeCall(blizBtn.ClearAllPoints, blizBtn)
        SafeCall(blizBtn.SetPoint, blizBtn, "CENTER", owner, "CENTER", 0, 0)
        if blizBtn.SetAlpha then SafeCall(blizBtn.SetAlpha, blizBtn, 0) end
        if blizBtn.EnableMouse then SafeCall(blizBtn.EnableMouse, blizBtn, false) end
    end
    if blizBtn.OpenMenu then
        SafeCall(blizBtn.OpenMenu, blizBtn)
    else
        QFXClickNativeFrame(blizBtn, "LeftButton")
    end
end

function QMT:GetTrackingIndicator()
    local btn = self:CreateIndicatorButton("tracking")
    self:ShowIndicatorIcon(btn, "UI-HUD-Minimap-Tracking-Up", "Interface\\Minimap\\Tracking\\None")
    btn:SetScript("OnEnter", function(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
        GameTooltip:AddLine(QMT.ZH and "追踪" or "Tracking")
        GameTooltip:AddLine(QMT.ZH and "左键打开追踪菜单" or "Left-click to open tracking menu", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnClick", function(owner, button)
        if button == "LeftButton" then QMT:OpenNativeTrackingMenu(owner) end
    end)
    return btn
end

function QMT:ApplyTrackingButtonPosition()
    local tracking = self:GetNativeTrackingFrame()
    local useCorner = self:ShouldUseNativeTrackingCorner()
    local indicator = useCorner and self:GetTrackingIndicator() or self.indicatorButtons and self.indicatorButtons.tracking

    if not useCorner then
        if indicator then indicator:Hide() end
        self:RestoreNativeTrackingFrame()
        return
    end

    if tracking then
        self:CaptureNativeTrackingFrame()
        SafeCall(tracking.SetParent, tracking, Minimap)
        SafeCall(tracking.ClearAllPoints, tracking)
        SafeCall(tracking.SetPoint, tracking, "TOPRIGHT", Minimap, "TOPRIGHT", 4, 4)
        if tracking.SetFrameStrata then SafeCall(tracking.SetFrameStrata, tracking, "HIGH") end
        if tracking.SetFrameLevel and Minimap.GetFrameLevel then
            SafeCall(tracking.SetFrameLevel, tracking, (Minimap:GetFrameLevel() or 0) + 39)
        end
        if tracking.SetAlpha then SafeCall(tracking.SetAlpha, tracking, 0) end
        if tracking.EnableMouse then SafeCall(tracking.EnableMouse, tracking, false) end
        if tracking.Show then SafeCall(tracking.Show, tracking) end
        self:HideNativeTrackingOuterBorder()
        self:StripIconBackgroundAndBorder(tracking)

        if tracking.HookScript and not tracking.QFXMinimapToolsTrackingCornerHooked then
            tracking:HookScript("OnShow", function()
                if QMT:ShouldUseNativeTrackingCorner() then
                    SafeCall(QMT.ApplyTrackingButtonPosition, QMT)
                end
            end)
            tracking.QFXMinimapToolsTrackingCornerHooked = true
        end
    end

    if indicator then
        indicator:SetParent(Minimap)
        indicator:ClearAllPoints()
        indicator:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", 4, 4)
        indicator:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 42)
        indicator:Show()
        self:StripIconBackgroundAndBorder(indicator)
    end
end

function QMT:ShouldUseNativeDifficultyFrame()
    return self.db and self.db.minimap and self.db.minimap.enabled and self.db.minimap.square and Minimap
end

function QMT:GetNativeDifficultyFrames()
    local frames, seen = {}, {}
    local function Add(frame)
        if frame and not seen[frame] then
            seen[frame] = true
            frames[#frames + 1] = frame
        end
    end
    Add(MinimapCluster and MinimapCluster.InstanceDifficulty)
    Add(MinimapCluster and MinimapCluster.GuildInstanceDifficulty)
    Add(_G.MiniMapInstanceDifficulty)
    Add(_G.GuildInstanceDifficulty)
    Add(_G.MiniMapChallengeMode)
    return frames
end

function QMT:CaptureNativeDifficultyFrame(frame)
    if not frame then return end
    self.difficultyFrameOriginal = self.difficultyFrameOriginal or {}
    if self.difficultyFrameOriginal[frame] then return end
    self.difficultyFrameOriginal[frame] = {
        parent = frame.GetParent and frame:GetParent(),
        point = {frame:GetPoint(1)},
        scale = frame.GetScale and frame:GetScale() or 1,
        alpha = frame.GetAlpha and frame:GetAlpha() or 1,
        shown = frame.IsShown and frame:IsShown() or false,
    }
end

local function QFXRestoreNativeDifficultyFrame(frame, original)
    if not frame or not original then return end
    SafeCall(frame.SetParent, frame, original.parent or MinimapCluster or Minimap)
    SafeCall(frame.ClearAllPoints, frame)
    if original.point and original.point[1] then SafeCall(frame.SetPoint, frame, unpack(original.point)) end
    if original.scale and frame.SetScale then SafeCall(frame.SetScale, frame, original.scale) end
    if frame.SetAlpha then SafeCall(frame.SetAlpha, frame, original.alpha or 1) end
    if original.shown then
        if frame.Show then SafeCall(frame.Show, frame) end
    else
        if frame.Hide then SafeCall(frame.Hide, frame) end
    end
end

function QMT:ApplyDifficultyFramePosition()
    local frames = self:GetNativeDifficultyFrames()
    if not frames or #frames == 0 then return end

    if not self:ShouldUseNativeDifficultyFrame() then
        for _, frame in ipairs(frames) do
            QFXRestoreNativeDifficultyFrame(frame, self.difficultyFrameOriginal and self.difficultyFrameOriginal[frame])
        end
        return
    end

    local index = 0
    for _, frame in ipairs(frames) do
        self:CaptureNativeDifficultyFrame(frame)
        index = index + 1
        SafeCall(frame.SetParent, frame, Minimap)
        SafeCall(frame.ClearAllPoints, frame)
        SafeCall(frame.SetPoint, frame, "TOPLEFT", Minimap, "TOPLEFT", 2 + ((index - 1) * 24), -2)
        if frame.SetScale then SafeCall(frame.SetScale, frame, 0.75) end
        if frame.SetAlpha then SafeCall(frame.SetAlpha, frame, 1) end
        if frame.SetFrameStrata then SafeCall(frame.SetFrameStrata, frame, "HIGH") end
        if frame.SetFrameLevel and Minimap.GetFrameLevel then SafeCall(frame.SetFrameLevel, frame, (Minimap:GetFrameLevel() or 0) + 40) end
        self:StripIconBackgroundAndBorder(frame)
        -- Do not force Show(); Blizzard decides when a difficulty badge is relevant.
        if frame.HookScript and not frame.QFXMinimapToolsDifficultyHooked then
            frame:HookScript("OnShow", function() SafeCall(QMT.ApplyDifficultyFramePosition, QMT) end)
            frame.QFXMinimapToolsDifficultyHooked = true
        end
    end
end

function QMT:CaptureExpansionLandingPageButton(btn)
    if not btn or self.expansionLandingButtonOriginal then return end
    self.expansionLandingButtonOriginal = {
        parent = btn.GetParent and btn:GetParent(),
        point = {btn:GetPoint(1)},
        scale = btn.GetScale and btn:GetScale() or 1,
        alpha = btn.GetAlpha and btn:GetAlpha() or 1,
        shown = btn.IsShown and btn:IsShown() or false,
    }
end

function QMT:RestoreExpansionLandingPageButton()
    local btn = _G.ExpansionLandingPageMinimapButton
    local original = self.expansionLandingButtonOriginal
    if not btn or not original then return end
    SafeCall(btn.SetParent, btn, original.parent or MinimapCluster or Minimap)
    SafeCall(btn.ClearAllPoints, btn)
    if original.point and original.point[1] then SafeCall(btn.SetPoint, btn, unpack(original.point)) end
    if btn.SetScale then SafeCall(btn.SetScale, btn, original.scale or 1) end
    if btn.SetAlpha then SafeCall(btn.SetAlpha, btn, original.alpha or 1) end
    if original.shown then
        if btn.Show then SafeCall(btn.Show, btn) end
    else
        if btn.Hide then SafeCall(btn.Hide, btn) end
    end
end

function QMT:ApplyExpansionLandingPageButtonPosition()
    local btn = _G.ExpansionLandingPageMinimapButton
    if not btn or not Minimap then return end
    if not self:ShouldCleanSquareMinimap() then
        self:RestoreExpansionLandingPageButton()
        return
    end

    self:CaptureExpansionLandingPageButton(btn)
    SafeCall(btn.SetParent, btn, Minimap)
    SafeCall(btn.ClearAllPoints, btn)
    SafeCall(btn.SetPoint, btn, "BOTTOMLEFT", Minimap, "BOTTOMLEFT", 2, 2)
    if btn.SetScale then SafeCall(btn.SetScale, btn, 0.75) end
    if btn.SetAlpha then SafeCall(btn.SetAlpha, btn, 1) end
    if btn.SetFrameStrata then SafeCall(btn.SetFrameStrata, btn, "HIGH") end
    if btn.SetFrameLevel and Minimap.GetFrameLevel then SafeCall(btn.SetFrameLevel, btn, (Minimap:GetFrameLevel() or 0) + 41) end
    self:StripIconBackgroundAndBorder(btn)
    -- Do not force Show(); Blizzard controls unlock/visibility for the current expansion feature.
    if btn.HookScript and not btn.QFXMinimapToolsLandingHooked then
        btn:HookScript("OnShow", function() SafeCall(QMT.ApplyExpansionLandingPageButtonPosition, QMT) end)
        btn.QFXMinimapToolsLandingHooked = true
    end
end

function QMT:ApplyManualMinimapPosition()
    if self.flightModeActive then return end
    if not Minimap or not MinimapCluster or not UIParent then return end
    local db = self.db and self.db.minimap
    if not db or db.autoSnap then return end

    MinimapCluster:SetClampedToScreen(false)
    SafeCall(Minimap.SetClampedToScreen, Minimap, false)
    MinimapCluster:ClearAllPoints()
    MinimapCluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)

    local mp = db.manualPoint
    if type(mp) ~= "table" or type(mp.x) ~= "number" or type(mp.y) ~= "number" then
        local cx, cy = Minimap:GetCenter()
        if cx and cy then
            mp = {x = cx, y = cy}
            db.manualPoint = mp
        else
            return
        end
    end

    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER", UIParent, "BOTTOMLEFT", mp.x, mp.y)
    self:UpdateSquareBorderPosition()
    self:ApplyQueueStatusButtonPosition()
    self:ApplyMailFramePosition()
    self:ApplyTrackingButtonPosition()
    self:ApplyDifficultyFramePosition()
    self:ApplyExpansionLandingPageButtonPosition()
    self:UpdateUtilityRow()
    if self.ApplyNativeControlSkin then self:ApplyNativeControlSkin() end
    self:PlaceBagButton()
    if self.statFrames then
        for key in pairs(self.statFrames) do self:PlaceStatFrame(key) end
        self:UpdateAllStats()
    end
    if self.bagFrame and self.bagFrame:IsShown() then self:LayoutBag() end
end

function QMT:SaveManualMinimapPosition()
    if not Minimap or not self.db or not self.db.minimap then return end
    local cx, cy = Minimap:GetCenter()
    if not cx or not cy then return end
    self.db.minimap.manualPoint = {x = cx, y = cy}
    self.db.minimap.autoSnap = false
end

function QMT:StartMoveMinimap()
    if self.flightModeActive then return end
    if not Minimap or not UIParent or not self.db or self.db.minimap.locked then return end
    local scale = UIParent:GetEffectiveScale() or 1
    local cursorX, cursorY = GetCursorPosition()
    cursorX, cursorY = cursorX / scale, cursorY / scale
    local mapX, mapY = Minimap:GetCenter()
    self.minimapDragOffsetX = (mapX or cursorX) - cursorX
    self.minimapDragOffsetY = (mapY or cursorY) - cursorY
    self.db.minimap.autoSnap = false
    self.squareBorder:SetScript("OnUpdate", function()
        local s = UIParent:GetEffectiveScale() or 1
        local x, y = GetCursorPosition()
        x, y = x / s, y / s
        Minimap:ClearAllPoints()
        Minimap:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x + (QMT.minimapDragOffsetX or 0), y + (QMT.minimapDragOffsetY or 0))
        QMT:UpdateSquareBorderPosition()
        QMT:ApplyQueueStatusButtonPosition()
        QMT:ApplyMailFramePosition()
        QMT:ApplyTrackingButtonPosition()
        QMT:ApplyDifficultyFramePosition()
        QMT:ApplyExpansionLandingPageButtonPosition()
        QMT:UpdateUtilityRow()
        QMT:PlaceBagButton()
        if QMT.statFrames then for key in pairs(QMT.statFrames) do QMT:PlaceStatFrame(key) end end
        if QMT.bagFrame and QMT.bagFrame:IsShown() then QMT:LayoutBag() end
    end)
end

function QMT:StopMoveMinimap()
    if self.squareBorder then self.squareBorder:SetScript("OnUpdate", nil) end
    self:SaveManualMinimapPosition()
    self:ApplyManualMinimapPosition()
end

function QMT:ApplyMinimapMoveMode()
    if not self.squareBorder or not self.db or not self.db.minimap then return end
    local unlocked = not self.db.minimap.locked
    self.squareBorder:EnableMouse(unlocked)
    self.squareBorder:SetMovable(unlocked)
    if unlocked then
        self.squareBorder:RegisterForDrag("LeftButton")
        self.squareBorder:SetScript("OnDragStart", function() QMT:StartMoveMinimap() end)
        self.squareBorder:SetScript("OnDragStop", function() QMT:StopMoveMinimap() end)
        self.squareBorder:SetScript("OnMouseUp", function(_, button) if button == "LeftButton" then QMT:StopMoveMinimap() end end)
        self.squareBorder:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:AddLine(L.UNLOCK_MOVE_TIP)
            GameTooltip:Show()
        end)
        self.squareBorder:SetScript("OnLeave", function() GameTooltip:Hide() end)
    else
        self.squareBorder:RegisterForDrag()
        self.squareBorder:SetScript("OnDragStart", nil)
        self.squareBorder:SetScript("OnDragStop", nil)
        self.squareBorder:SetScript("OnMouseUp", nil)
        self.squareBorder:SetScript("OnEnter", nil)
        self.squareBorder:SetScript("OnLeave", nil)
    end
end

function QMT:ApplySmartTopRightSnap()
    if self.flightModeActive then return end
    if not self.db or not self.db.minimap or not self.db.minimap.autoSnap then return end
    if not Minimap or not MinimapCluster or not UIParent then return end
    local anchor = self:CreateSnapAnchor()
    local inset = self:GetSnapInset()
    -- Auto snap is fixed behavior. Always use the safe inset instead of reusing old
    -- saved offsets that may push the border off-screen.
    local x = -inset
    local y = -inset
    self.db.minimap.snapX = x
    self.db.minimap.snapY = y
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, y)

    -- The cluster frame contains large hidden header space in modern clients. Anchor the real
    -- Minimap frame itself to UIParent, but leave a border-width inset so the custom border remains visible.
    MinimapCluster:SetClampedToScreen(false)
    SafeCall(Minimap.SetClampedToScreen, Minimap, false)
    MinimapCluster:ClearAllPoints()
    MinimapCluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)

    self:UpdateSquareBorderPosition()
    self:RequestAttachedElementRefresh(true, true)
end

function QMT:RequestSmartTopRightSnap()
    if self.snapQueued then return end
    self.snapQueued = true
    local function Flush()
        QMT.snapQueued = false
        QMT:ApplySmartTopRightSnap()
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, Flush)
    else
        Flush()
    end
end

local defaultSquareBorderEdge = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"

QMT.borderPresets = QMT.borderPresets or {}
QMT.borderPresetOrder = QMT.borderPresetOrder or {"AUTO_SKIN", "ACTIONBAR", "ELVUI", "NDUI", "DARKMODE", "BLACK", "SILVER", "DARK", "GOLD", "CLASS"}

local function RegisterBuiltInBorderPresets()
    QMT.borderPresets.AUTO_SKIN = {
        label = L.BORDER_AUTO or "Auto skin",
        edgeFile = defaultSquareBorderEdge,
        color = {0.18, 0.18, 0.18, 1},
    }
    QMT.borderPresets.ACTIONBAR = {
        label = L.BORDER_ACTIONBAR or "Action button",
        edgeFile = defaultSquareBorderEdge,
        color = {0.18, 0.18, 0.18, 1},
    }
    QMT.borderPresets.ELVUI = { label = L.BORDER_ELVUI or "ElvUI", edgeFile = defaultSquareBorderEdge, color = {0.10, 0.10, 0.10, 1} }
    QMT.borderPresets.NDUI = { label = L.BORDER_NDUI or "NDui", edgeFile = defaultSquareBorderEdge, color = {0.06, 0.06, 0.06, 1} }
    QMT.borderPresets.DARKMODE = { label = L.BORDER_DARKMODE or "DarkMode", edgeFile = defaultSquareBorderEdge, color = {0.02, 0.02, 0.02, 1} }
    QMT.borderPresets.BLACK = {
        label = L.BORDER_BLACK,
        edgeFile = defaultSquareBorderEdge,
        color = {0, 0, 0, 1},
    }
    QMT.borderPresets.SILVER = {
        label = L.BORDER_SILVER,
        edgeFile = defaultSquareBorderEdge,
        -- Slightly warm silver, close to the default action-button rim.
        color = {0.78, 0.78, 0.72, 1},
    }
    QMT.borderPresets.DARK = {
        label = L.BORDER_DARK,
        edgeFile = defaultSquareBorderEdge,
        color = {0.18, 0.18, 0.18, 1},
    }
    QMT.borderPresets.GOLD = {
        label = L.BORDER_GOLD,
        edgeFile = defaultSquareBorderEdge,
        color = {0.95, 0.72, 0.28, 1},
    }
    QMT.borderPresets.CLASS = {
        label = L.BORDER_CLASS,
        edgeFile = defaultSquareBorderEdge,
        classColor = true,
        color = {0.5019608, 0.5019608, 1.00, 1},
    }
end
RegisterBuiltInBorderPresets()

function QMT:RefreshLocale()
    local choice = self.db and self.db.ui and self.db.ui.language or "AUTO"
    SelectLocale(NormalizeLanguageChoice(choice))
    RegisterBuiltInBorderPresets()
end

function QMT:GetLanguageLabel(key)
    key = NormalizeLanguageChoice(key)
    if key == "zhCN" then return L.LANGUAGE_ZH end
    if key == "enUS" then return L.LANGUAGE_EN end
    return L.LANGUAGE_AUTO
end

function QMT:RefreshSettingsPanelText()
    local panel = self.settingsPanel
    if not panel then return end
    panel.name = L.TITLE
    if panel.qfxTitle then panel.qfxTitle:SetText(L.TITLE) end
    if panel.qfxDesc then panel.qfxDesc:SetText(L.PANEL_DESC) end
    if panel.qfxOpenButton then panel.qfxOpenButton:SetText(L.OPEN_OPTIONS) end
    if panel.qfxResetPosButton then panel.qfxResetPosButton:SetText(L.RESET_MINIMAP_POSITION) end
    if panel.qfxCommandHint then panel.qfxCommandHint:SetText(L.COMMAND_HINT) end
end

function QMT:RefreshButtonManagerText()
    local f = self.buttonManager
    if not f then return end
    if f.qfxTitle then f.qfxTitle:SetText(L.BUTTON_MANAGER) end
    if f.qfxTip then f.qfxTip:SetText(L.BUTTON_MANAGER_TIP) end
    if f.prev then f.prev:SetText(L.PREV) end
    if f.next then f.next:SetText(L.NEXT) end
    if f.rescan then f.rescan:SetText(L.RESCAN) end
end

function QMT:SetUILanguage(key)
    if not self.db then return end
    key = NormalizeLanguageChoice(key)
    self.db.ui = self.db.ui or {}
    self.db.ui.language = key
    self:RefreshLocale()
    self:RefreshSettingsPanelText()
    self:RefreshButtonManagerText()
    if self.buttonManager and self.buttonManager:IsShown() then self:RefreshButtonManager() end
    if self.optionsFrame then
        local wasShown = self.optionsFrame:IsShown()
        self.optionsFrame:Hide()
        self.optionsFrame = nil
        if wasShown then
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function() QMT:ShowOptions() end)
            else
                self:ShowOptions()
            end
        end
    end
    Print(L.LANGUAGE_CHANGED)
end

local function GetClassBorderColor()
    local classFile = select(2, UnitClass("player"))
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if c then return c.r or 1, c.g or 1, c.b or 1, c.a or 1 end
    local a = QMT.db and QMT.db.display and QMT.db.display.accent or {0.5019608, 0.5019608, 1.0}
    return a[1] or 0.5019608, a[2] or 0.5019608, a[3] or 1.0, 1
end
local function IsAddonLoadedSafe(name)
    if not name or name == "" then return false end
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
        return ok and loaded and true or false
    end
    if IsAddOnLoaded then
        local ok, loaded = pcall(IsAddOnLoaded, name)
        return ok and loaded and true or false
    end
    return false
end

local function GetElvUI()
    if not _G.ElvUI then return nil end
    local ok, E = pcall(function() return unpack(_G.ElvUI) end)
    return ok and E or nil
end

local function GetQFXExternalBorderColor(mode)
    mode = mode or "AUTO_SKIN"
    local function elv()
        local E = GetElvUI()
        local c = E and E.media and (E.media.bordercolor or E.media.rgbvaluecolor)
        if type(c) == "table" then return c.r or c[1] or 0.10, c.g or c[2] or 0.10, c.b or c[3] or 0.10, c.a or c[4] or 1 end
    end
    local function ndui()
        local nd = type(_G.NDui) == "table" and _G.NDui or type(_G.NDuiDB) == "table" and _G.NDuiDB or type(_G.NDuiConfig) == "table" and _G.NDuiConfig or nil
        local candidates = { nd and nd.media and nd.media.border_color, nd and nd.Media and nd.Media.border_color, nd and nd.db and nd.db.media and nd.db.media.border_color, _G.C and _G.C.media and _G.C.media.border_color, _G.NDuiDB and _G.NDuiDB.media and _G.NDuiDB.media.border_color }
        for _, c in ipairs(candidates) do
            if type(c) == "table" then return c.r or c[1] or 0.08, c.g or c[2] or 0.08, c.b or c[3] or 0.08, c.a or c[4] or 1 end
        end
    end
    if mode == "ELVUI" or mode == "AUTO_SKIN" then
        if GetElvUI() or IsAddonLoadedSafe("ElvUI") then local r,g,b,a = elv(); return r or 0.10, g or 0.10, b or 0.10, a or 1, "ELVUI" end
    end
    if mode == "NDUI" or mode == "AUTO_SKIN" then
        if type(_G.NDui) == "table" or type(_G.NDuiDB) == "table" or IsAddonLoadedSafe("NDui") then local r,g,b,a = ndui(); return r or 0.06, g or 0.06, b or 0.06, a or 1, "NDUI" end
    end
    if mode == "DARKMODE" or mode == "AUTO_SKIN" then
        if type(_G.DarkMode) == "table" or IsAddonLoadedSafe("DarkMode") then return 0.02, 0.02, 0.02, 1, "DARKMODE" end
    end
    return nil
end

local function RegisterQFXSkinTarget(frame, group)
    if not frame then return end
    frame.qfxSkinTarget = true
    frame.qfxSkinGroup = group or "MinimapTools"
    frame.d4border = true
    _G.QFXMinimapTools_SkinTargets = _G.QFXMinimapTools_SkinTargets or {}
    _G.QFXMinimapTools_SkinTargets[frame:GetName() or tostring(frame)] = frame
end

local ROUND_MINIMAP_BUTTON_BORDER = "Interface\\Minimap\\MiniMap-TrackingBorder"
local ROUND_MINIMAP_BUTTON_HIGHLIGHT = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"



local function TexturePath(texture)
    if not texture or not texture.GetTexture then return nil end
    local ok, tex = pcall(texture.GetTexture, texture)
    if not ok then return nil end
    if type(tex) == "string" then return tex:lower() end
    return nil
end

local function LooksLikeNativeRoundButtonBorder(texture)
    local path = TexturePath(texture)
    if not path then return false end
    if path:find("qfxminimaptools", 1, true) then return false end
    if path:find("quickslot", 1, true) or path:find("buttonhilight%-square") then return false end
    if path:find("trackingborder", 1, true) then return true end
    if path:find("minimap", 1, true) and path:find("border", 1, true) then return true end
    if path:find("queue", 1, true) and path:find("border", 1, true) then return true end
    return false
end

local function FrameHasNativeRoundBorder(frame)
    if not frame then return false end
    local function CheckRegions(obj)
        if not obj or not obj.GetRegions then return false end
        for _, region in ipairs({obj:GetRegions()}) do
            if region and region.IsShown and region:IsShown() and LooksLikeNativeRoundButtonBorder(region) then
                local a = region.GetAlpha and region:GetAlpha() or 1
                if a and a > 0 then return true end
            end
        end
        return false
    end
    if CheckRegions(frame) then return true end
    if frame.GetChildren then
        for _, child in ipairs({frame:GetChildren()}) do
            if CheckRegions(child) then return true end
        end
    end
    return false
end

local function ApplyRoundMinimapButtonBorder(frame, color, show, preferNative)
    if not frame then return end
    if show == false then
        if frame.QFXRoundMinimapBorder then frame.QFXRoundMinimapBorder:Hide() end
        if frame.QFXRoundMinimapHighlight then frame.QFXRoundMinimapHighlight:Hide() end
        return
    end

    -- QueueStatusButton already owns a proper Blizzard round border on clients that
    -- expose it. In that case do not add any QFX border; just leave the native art alone.
    if preferNative and FrameHasNativeRoundBorder(frame) then
        if frame.QFXRoundMinimapBorder then frame.QFXRoundMinimapBorder:Hide() end
        if frame.QFXRoundMinimapHighlight then frame.QFXRoundMinimapHighlight:Hide() end
        return
    end

    local r, g, b, a = 0.18, 0.18, 0.18, 1
    if type(color) == "table" then r, g, b, a = color[1] or color.r or r, color[2] or color.g or g, color[3] or color.b or b, color[4] or color.a or a end

    if not frame.QFXRoundMinimapBorder then
        if InCombatLockdown and InCombatLockdown() and frame.IsProtected and frame:IsProtected() then return end
        frame.QFXRoundMinimapBorder = frame:CreateTexture(nil, "OVERLAY")
        frame.QFXRoundMinimapBorder:SetTexture(ROUND_MINIMAP_BUTTON_BORDER)
    end
    local w = frame.GetWidth and frame:GetWidth() or 24
    local h = frame.GetHeight and frame:GetHeight() or 24
    local size = math.max(42, (math.max(w or 24, h or 24) or 24) + 20)
    frame.QFXRoundMinimapBorder:ClearAllPoints()
    frame.QFXRoundMinimapBorder:SetPoint("CENTER", frame, "CENTER", -1, 0)
    frame.QFXRoundMinimapBorder:SetSize(size, size)
    frame.QFXRoundMinimapBorder:SetVertexColor(r, g, b, a)
    frame.QFXRoundMinimapBorder:Show()

    if not frame.QFXRoundMinimapHighlight then
        if InCombatLockdown and InCombatLockdown() and frame.IsProtected and frame:IsProtected() then return end
        frame.QFXRoundMinimapHighlight = frame:CreateTexture(nil, "HIGHLIGHT")
        frame.QFXRoundMinimapHighlight:SetTexture(ROUND_MINIMAP_BUTTON_HIGHLIGHT)
        frame.QFXRoundMinimapHighlight:SetBlendMode("ADD")
    end
    frame.QFXRoundMinimapHighlight:ClearAllPoints()
    frame.QFXRoundMinimapHighlight:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.QFXRoundMinimapHighlight:SetSize(math.max(28, size - 14), math.max(28, size - 14))
end

function QMT:ApplyNativeControlSkin()
    -- Do not force action-button square borders onto native minimap controls.
    -- Queue eye: prefer Blizzard's own round frame. Difficulty badge: use the same
    -- LibDBIcon-style round minimap frame as a fallback because QFX draws the text itself.
    local db = self.db and self.db.minimap
    local show = db and db.enabled and db.square
    local style = self.GetBorderStyle and self:GetBorderStyle() or {r = 0.18, g = 0.18, b = 0.18, a = 1}
    local color = {style.r or 0.18, style.g or 0.18, style.b or 0.18, style.a or 1}

    local q = self:GetManagedNativeQueueFrame()
    if q then
        -- Queue eye stays as a pure eye glyph in the lower-left corner; do not add
        -- a QFX round button frame around it.
        ApplyRoundMinimapButtonBorder(q, color, false, false)
    end

    local diff = self.statFrames and self.statFrames.difficulty
    if diff then
        ApplyRoundMinimapButtonBorder(diff, color, false, false)
    end
end

local function NormaliseBorderStyle(style)
    if type(style) ~= "table" then return nil end
    local edgeFile = style.edgeFile or defaultSquareBorderEdge
    local edgeSize = tonumber(style.edgeSize or style.borderSize or (QMT.db and QMT.db.minimap and QMT.db.minimap.borderSize) or 3) or 3
    local r, g, b, a
    if type(style.color) == "table" then
        r, g, b, a = style.color[1], style.color[2], style.color[3], style.color[4]
    else
        r, g, b, a = style.r, style.g, style.b, style.a
    end
    r = Clamp(tonumber(r) or 0, 0, 1)
    g = Clamp(tonumber(g) or 0, 0, 1)
    b = Clamp(tonumber(b) or 0, 0, 1)
    a = Clamp(tonumber(a) or 1, 0, 1)
    return { edgeFile = edgeFile, edgeSize = edgeSize, r = r, g = g, b = b, a = a }
end

function QMT:RegisterBorderPreset(key, label, r, g, b, a, edgeFile, edgeSize)
    if type(key) ~= "string" or key == "" then return false end
    key = key:upper()
    self.borderPresets[key] = {
        label = label or key,
        edgeFile = edgeFile or defaultSquareBorderEdge,
        edgeSize = edgeSize,
        color = {Clamp(tonumber(r) or 1, 0, 1), Clamp(tonumber(g) or 1, 0, 1), Clamp(tonumber(b) or 1, 0, 1), Clamp(tonumber(a) or 1, 0, 1)},
    }
    local exists = false
    for _, v in ipairs(self.borderPresetOrder) do if v == key then exists = true break end end
    if not exists then table.insert(self.borderPresetOrder, key) end
    return true
end

function QMT:SetBorderPreset(key, noSave)
    if type(key) ~= "string" then return false end
    key = key:upper()
    if not self.borderPresets[key] then return false end
    if noSave then
        local preset = self.borderPresets[key]
        local r, g, b, a
        if preset.classColor then r, g, b, a = GetClassBorderColor() else r, g, b, a = unpack(preset.color or {0, 0, 0, 1}) end
        self.runtimeBorderStyle = { edgeFile = preset.edgeFile or defaultSquareBorderEdge, edgeSize = preset.edgeSize, r = r, g = g, b = b, a = a }
    elseif self.db and self.db.minimap then
        self.runtimeBorderStyle = nil
        self.db.minimap.borderPreset = key
        self.db.minimap.borderEdgeFile = nil
        if key ~= "CLASS" then
            local preset = self.borderPresets[key]
            self.db.minimap.borderColor = {unpack(preset.color or {0, 0, 0, 1})}
        end
    end
    self:ApplySquareBorderStyle()
    self:RefreshBorderPresetControls()
    return true
end

function QMT:SetBorderColor(r, g, b, a, noSave, edgeFile, edgeSize)
    local style = NormaliseBorderStyle({r = r, g = g, b = b, a = a, edgeFile = edgeFile, edgeSize = edgeSize})
    if not style then return false end
    if noSave then
        self.runtimeBorderStyle = style
    elseif self.db and self.db.minimap then
        self.runtimeBorderStyle = nil
        self.db.minimap.borderPreset = "CUSTOM"
        self.db.minimap.borderColor = {style.r, style.g, style.b, style.a}
        self.db.minimap.borderEdgeFile = style.edgeFile
        if edgeSize then self.db.minimap.borderSize = style.edgeSize end
    end
    self:ApplySquareBorderStyle()
    self:RefreshBorderPresetControls()
    return true
end

function QMT:SetBorderStyle(style, noSave)
    if type(style) == "string" then return self:SetBorderPreset(style, noSave) end
    if type(style) ~= "table" then return false end
    if style.preset then return self:SetBorderPreset(style.preset, noSave) end
    local color = style.color or style
    return self:SetBorderColor(color.r or color[1], color.g or color[2], color.b or color[3], color.a or color[4], noSave, style.edgeFile, style.edgeSize or style.borderSize)
end

function QMT:GetBorderStyle()
    if self.runtimeBorderStyle then
        local s = self.runtimeBorderStyle
        return { preset = "RUNTIME", edgeFile = s.edgeFile, edgeSize = s.edgeSize, r = s.r, g = s.g, b = s.b, a = s.a }
    end

    local db = self.db and self.db.minimap or {}
    local key = db.borderPreset or "DARK"
    local preset = self.borderPresets[key]
    local edgeFile = db.borderEdgeFile or (preset and preset.edgeFile) or defaultSquareBorderEdge
    local edgeSize = tonumber(db.borderSize) or 3
    local r, g, b, a

    local er, eg, eb, ea = nil
    if key == "AUTO_SKIN" or key == "ELVUI" or key == "NDUI" or key == "DARKMODE" then
        er, eg, eb, ea = GetQFXExternalBorderColor(key)
    end
    if er then
        r, g, b, a = er, eg, eb, ea
    elseif preset and preset.classColor then
        r, g, b, a = GetClassBorderColor()
    elseif preset and preset.color then
        r, g, b, a = unpack(preset.color)
    elseif type(db.borderColor) == "table" then
        r, g, b, a = db.borderColor[1], db.borderColor[2], db.borderColor[3], db.borderColor[4]
    else
        r, g, b, a = 0, 0, 0, 1
    end

    r = Clamp(tonumber(r) or 0, 0, 1)
    g = Clamp(tonumber(g) or 0, 0, 1)
    b = Clamp(tonumber(b) or 0, 0, 1)
    a = Clamp(tonumber(a) or 1, 0, 1)
    return { preset = key, edgeFile = edgeFile, edgeSize = edgeSize, r = r, g = g, b = b, a = a }
end

QMT.GetMinimapBorderStyle = QMT.GetBorderStyle
QMT.SetMinimapBorderStyle = QMT.SetBorderStyle

function QMT:EnsureSquareBorderLines()
    if not self.squareBorder then return end
    if self.squareBorderLines then return end
    self.squareBorderLines = {
        top = self.squareBorder:CreateTexture(nil, "BORDER"),
        bottom = self.squareBorder:CreateTexture(nil, "BORDER"),
        left = self.squareBorder:CreateTexture(nil, "BORDER"),
        right = self.squareBorder:CreateTexture(nil, "BORDER"),
    }
end

function QMT:ApplySquareBorderStyle()
    if not self.squareBorder or not self.db or not self.db.minimap then return end
    local style = self:GetBorderStyle()
    local edgeSize = Clamp(tonumber(style.edgeSize or self.db.minimap.borderSize) or 3, 1, 12)
    local signature = table.concat({
        tostring(style.preset or ""),
        tostring(style.edgeFile or ""),
        tostring(edgeSize),
        string.format("%.4f", style.r or 0),
        string.format("%.4f", style.g or 0),
        string.format("%.4f", style.b or 0),
        string.format("%.4f", style.a or 1),
    }, "|")
    if self.squareBorderStyleSignature == signature and self.squareBorderLines then return end
    self.squareBorderStyleSignature = signature

    -- Do not rely on Backdrop edge tinting for the visible border. Some edge
    -- textures are dark/pre-colored, so SetBackdropBorderColor can appear to do
    -- nothing. Solid line textures are always tintable and refresh immediately.
    if self.squareBorder.SetBackdrop then self.squareBorder:SetBackdrop(nil) end
    self:EnsureSquareBorderLines()
    local lines = self.squareBorderLines
    if not lines then return end

    lines.top:ClearAllPoints()
    lines.top:SetPoint("TOPLEFT", self.squareBorder, "TOPLEFT", 0, 0)
    lines.top:SetPoint("TOPRIGHT", self.squareBorder, "TOPRIGHT", 0, 0)
    lines.top:SetHeight(edgeSize)

    lines.bottom:ClearAllPoints()
    lines.bottom:SetPoint("BOTTOMLEFT", self.squareBorder, "BOTTOMLEFT", 0, 0)
    lines.bottom:SetPoint("BOTTOMRIGHT", self.squareBorder, "BOTTOMRIGHT", 0, 0)
    lines.bottom:SetHeight(edgeSize)

    lines.left:ClearAllPoints()
    lines.left:SetPoint("TOPLEFT", self.squareBorder, "TOPLEFT", 0, -edgeSize)
    lines.left:SetPoint("BOTTOMLEFT", self.squareBorder, "BOTTOMLEFT", 0, edgeSize)
    lines.left:SetWidth(edgeSize)

    lines.right:ClearAllPoints()
    lines.right:SetPoint("TOPRIGHT", self.squareBorder, "TOPRIGHT", 0, -edgeSize)
    lines.right:SetPoint("BOTTOMRIGHT", self.squareBorder, "BOTTOMRIGHT", 0, edgeSize)
    lines.right:SetWidth(edgeSize)

    for _, tex in pairs(lines) do
        tex:SetColorTexture(style.r or 0, style.g or 0, style.b or 0, style.a or 1)
        tex:Show()
        if (style.preset == "DARKMODE" or style.preset == "AUTO_SKIN") and _G.DarkMode and type(_G.DarkMode.UpdateColor) == "function" then
            pcall(_G.DarkMode.UpdateColor, _G.DarkMode, tex, "ui")
        end
    end
    RegisterQFXSkinTarget(self.squareBorder, "MinimapBorder")
    if self.ApplyNativeControlSkin then self:ApplyNativeControlSkin() end
end

function QMT:GetBorderPresetLabel(key)
    key = key or (self.db and self.db.minimap and self.db.minimap.borderPreset) or "DARK"
    local preset = self.borderPresets and self.borderPresets[key]
    if preset and preset.label then return preset.label end
    if key == "CUSTOM" or key == "RUNTIME" then return L.BORDER_CUSTOM end
    return tostring(key or "")
end

function QMT:RefreshBorderPresetControls()
    local f = self.optionsFrame
    if not f then return end
    local key = self.db and self.db.minimap and self.db.minimap.borderPreset or "DARK"
    if self.runtimeBorderStyle then key = "RUNTIME" end
    if f.borderPresetDropdown then
        f.borderPresetDropdown:SetText(self:GetBorderPresetLabel(key))
    end
end


-- ############################################################
function QMT:ApplyMinimapSettings()
    local db = self.db.minimap
    if not Minimap or not MinimapCluster then return end

    if not self.originalGetMinimapShape then
        self.originalGetMinimapShape = _G.GetMinimapShape
    end

    -- 自动贴近屏幕边缘：作为默认行为固定开启，不再放到设置界面里。
    db.unclamp = true

    if db.enabled then
        local scale = Clamp(db.scale, 0.50, 2.00)
        db.scale = scale
        -- Direct top-right anchoring works best when the real Minimap frame is scaled.
        -- Scaling only MinimapCluster can appear capped around 1.0 on some UI layouts.
        MinimapCluster:SetScale(1)
        if Minimap.SetScale then Minimap:SetScale(scale) end
        MinimapCluster:SetClampedToScreen(false)
        SafeCall(Minimap.SetClampedToScreen, Minimap, false)

        if db.square then
            _G.GetMinimapShape = function() return "SQUARE" end
            SafeCall(Minimap.SetMaskTexture, Minimap, "Interface\\Buttons\\WHITE8X8")
            self:SetRoundMinimapArtHidden(true)
            self:SetNativeMinimapControlsHidden(true)
        else
            _G.GetMinimapShape = self.originalGetMinimapShape or function() return "ROUND" end
            SafeCall(Minimap.SetMaskTexture, Minimap, "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
            self:SetRoundMinimapArtHidden(false)
            self:SetNativeMinimapControlsHidden(false)
        end
    else
        MinimapCluster:SetScale(1)
        if Minimap.SetScale then Minimap:SetScale(1) end
        MinimapCluster:SetClampedToScreen(false)
        SafeCall(Minimap.SetClampedToScreen, Minimap, false)
        _G.GetMinimapShape = self.originalGetMinimapShape or _G.GetMinimapShape
        SafeCall(Minimap.SetMaskTexture, Minimap, "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        self:SetRoundMinimapArtHidden(false)
        self:SetNativeMinimapControlsHidden(false)
    end

    if not self.squareBorder then
        self.squareBorder = CreateFrame("Frame", "QFXMinimapToolsSquareBorder", Minimap, BackdropTemplateMixin and "BackdropTemplate")
        self.squareBorder:SetFrameStrata("LOW")
        if self.squareBorder.SetFrameLevel and Minimap.GetFrameLevel then
            self.squareBorder:SetFrameLevel(math.max(0, (Minimap:GetFrameLevel() or 1) - 1))
        end
        self.squareBorder:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -3, 3)
        self.squareBorder:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 3, -3)
        self.squareBorder:SetBackdrop({
            edgeFile = defaultSquareBorderEdge,
            edgeSize = db.borderSize or 3,
        })
        self.squareBorder:SetBackdropBorderColor(0, 0, 0, 1)
    end
    self:ApplySquareBorderStyle()
    self.squareBorder:SetShown(db.enabled and db.square)
    self:ApplyMinimapMoveMode()
    self:ApplyQueueStatusButtonPosition()
    self:ApplyMailFramePosition()
    self:ApplyTrackingButtonPosition()
    self:ApplyDifficultyFramePosition()
    self:ApplyExpansionLandingPageButtonPosition()
    self:UpdateUtilityRow()
    if self.ApplyNativeControlSkin then self:ApplyNativeControlSkin() end
    if db.autoSnap then self:ApplySmartTopRightSnap() else self:ApplyManualMinimapPosition() end

    if AddonCompartmentFrame then
        if not self.compartmentHooked then
            AddonCompartmentFrame:HookScript("OnShow", function(frame)
                if QMT.db and QMT.db.minimap and (QMT.db.minimap.hideCompartment or QMT:ShouldCleanSquareMinimap()) then frame:Hide() end
            end)
            self.compartmentHooked = true
        end
        if db.hideCompartment or self:ShouldCleanSquareMinimap() then AddonCompartmentFrame:Hide() else AddonCompartmentFrame:Show() end
    end

    self:RefreshOutdoorFlightWatcher()
    self:UpdateOutdoorFlightCenterState(true)
end

-- ############################################################
-- Text displays
-- ############################################################
