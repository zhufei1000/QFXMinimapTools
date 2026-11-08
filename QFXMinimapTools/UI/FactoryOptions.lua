local ADDON_NAME, QMT = ...

local LegacyCreate = QMT.CreateOptionsFrame
local LegacyRefresh = QMT.RefreshOptionsControlState
local factoryFrames, legacyFrames = {}, {}
local version

local function ResolveFactory()
    local W = rawget(_G, "QFXWidgets")
    if type(W) == "table" and type(W.AddonWindow) == "function"
        and type(W.DualRow) == "function" and type(W.NavList) == "function" then
        return W
    end
end

local function SaveOffsets(frame)
    local offsets = {}
    for key, page in pairs(frame.pages or {}) do
        if page.GetOffset then offsets[key] = page:GetOffset() end
    end
    return offsets
end

local function BuildPage(frame, key)
    local W, page = frame.factory, frame.pages[key]
    local layout = { y = -W.Theme.pad }
    function layout:Section(title, note)
        local _, height = W:SectionHeader(page.content, title, self.y, { note = note })
        self.y = self.y - height
    end
    function layout:Row(config)
        if config.type ~= "label" then config.blockInCombat = true end
        local setter, click = config.setValue, config.onClick
        if setter then config.setValue = function(...)
            if W:IsDisabled(config) then return end
            setter(...)
        end end
        if click then config.onClick = function(...)
            if W:IsDisabled(config) then return end
            click(...)
            QMT:RefreshOptionsControlState()
        end end
        local row, height = W:DualRow(page.content, self.y, config)
        self.y = self.y - height
        return row
    end
    function layout:Status(getText)
        local row, height = W:StatusRow(page.content, self.y, { getText = getText, wrap = true, height = 36 })
        self.y = self.y - height
        -- The legacy page builder sets this text once; the factory owns updates.
        return { SetText = function() row:Update() end, SetWordWrap = function() end }
    end
    function layout:Finish()
        page:SetContentHeight(-self.y + W.Theme.pad)
    end
    W:BeginPage(page.content)
    W:ResetRows(page.content)
    local ok, err = pcall(QMT.BuildManagerPage, QMT, key, page, {
        Widgets = W,
        IncludeReload = true,
    }, layout)
    W:EndPage()
    if not ok then error(err) end
end

local function SelectPage(frame, key)
    if not frame.pageKeys[key] then key = "overview" end
    if not frame.pages[key] then
        local page = frame.factory:ScrollPage(frame.content, { reserveBar = true })
        frame.pages[key] = page
        BuildPage(frame, key)
        page:ScrollTo(frame.offsets[key] or 0)
    end
    frame.selectedPage = key
    for pageKey, page in pairs(frame.pages) do
        page.frame:SetShown(pageKey == key)
    end
    frame.nav:Refresh()
    if frame:IsShown() then QMT:RefreshOptionsControlState() end
end

local function CreateFactoryFrame(W, offsets)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame.factory = W
    frame.pages = {}
    frame.pageKeys = {}
    frame.offsets = offsets or {}
    frame:SetSize(880, 640)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    if not version then
        version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or ""
    end
    frame.chrome = W:AddonWindow(frame, {
        title = QMT.L.TITLE, version = version, locale = QMT.LOCALE,
        repository = "https://github.com/zhufei1000/QFXMinimapTools",
    })
    local root = frame.chrome.content
    frame.sidebar = CreateFrame("Frame", nil, root)
    frame.sidebar:SetPoint("TOPLEFT")
    frame.sidebar:SetPoint("BOTTOMLEFT")
    frame.sidebar:SetWidth(174)
    W:SkinFrame(frame.sidebar)
    W:Perimeter(frame.sidebar, { opacity = 0.72 })
    frame.content = CreateFrame("Frame", nil, root)
    frame.content:SetPoint("TOPLEFT", frame.sidebar, "TOPRIGHT", W.Theme.pad, 0)
    frame.content:SetPoint("BOTTOMRIGHT")
    local items = {}
    for _, info in ipairs(QMT:GetManagerSettingsPages()) do
        items[#items + 1] = { key = info.key, label = info.title }
        frame.pageKeys[info.key] = true
    end
    frame.nav = W:NavList(frame.sidebar, {
        mode = "fixed", x = W.Theme.pad, y = -W.Theme.pad,
        width = 174 - W.Theme.pad * 2, items = items,
        getActive = function() return frame.selectedPage end,
        onSelect = function(key) SelectPage(frame, key) end,
    })
    frame:SetScript("OnEvent", function()
        if frame:IsShown() then QMT:RefreshOptionsControlState() end
    end)
    frame:SetScript("OnShow", function(self)
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("SKILL_LINES_CHANGED")
        QMT:RefreshOptionsControlState()
    end)
    frame:HookScript("OnHide", frame.UnregisterAllEvents)
    return frame
end

function QMT:RefreshOptionsControlState()
    local frame = self.optionsFrame
    if not frame or not frame.factory then return LegacyRefresh(self) end
    local page = frame.pages[frame.selectedPage]
    if page then frame.factory:Refresh(page.content) end
end

function QMT:CreateOptionsFrame()
    local W = ResolveFactory()
    if not W then
        local manager = rawget(_G, "QFXAddonManager")
        if manager and type(manager.EnsureConfigLoaded) == "function" then
            manager.EnsureConfigLoaded()
            W = ResolveFactory()
        end
    end
    local locale = self.LOCALE
    local cache = W and factoryFrames or legacyFrames
    local old, frame = self.optionsFrame, cache[locale]
    if old and old == frame then return frame end
    local selected = old and old.selectedPage or "overview"
    if old then old:Hide() end
    if not frame then
        self.optionsFrame = nil
        frame = W and CreateFactoryFrame(W, old and SaveOffsets(old)) or LegacyCreate(self)
        cache[locale] = frame
    end
    self.optionsFrame = frame
    -- Escape resolves the currently selected locale through UISpecialFrames.
    _G.QFXMinimapToolsOptionsFrame = frame
    if W then SelectPage(frame, selected) else self:SelectLegacyOptionsPage(frame, selected) end
    if UISpecialFrames then
        local found
        for _, name in ipairs(UISpecialFrames) do
            if name == "QFXMinimapToolsOptionsFrame" then found = true; break end
        end
        if not found then UISpecialFrames[#UISpecialFrames + 1] = "QFXMinimapToolsOptionsFrame" end
    end
    return frame
end
