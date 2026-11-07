local ADDON_NAME, QMT = ...

local LegacyCreate = QMT.CreateOptionsFrame
local LegacyRefresh = QMT.RefreshOptionsControlState
local previousFrame
local version

local function ResolveFactory()
    local W = rawget(_G, "QFXWidgets")
    if type(W) == "table" and type(W.AddonWindow) == "function"
        and type(W.DualRow) == "function" and type(W.NavList) == "function" then
        return W
    end
end

local function ClearOwners(frame)
    if not frame or not frame.factory then return end
    frame:UnregisterAllEvents()
    for _, page in pairs(frame.pages) do
        frame.factory:ClearRefreshes(page.content)
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
        -- SetUILanguage already rebuilds the native window after committing.
    }, layout)
    W:EndPage()
    if not ok then error(err) end
end

local function SelectPage(frame, key)
    if not frame.pages[key] then key = "overview" end
    frame.selectedPage = key
    for pageKey, page in pairs(frame.pages) do
        page.frame:SetShown(pageKey == key)
    end
    frame.nav:Refresh()
    QMT:RefreshOptionsControlState()
end

local function CreateFactoryFrame(W, selected, offsets)
    local frame = CreateFrame("Frame", "QFXMinimapToolsOptionsFrame", UIParent)
    frame.factory = W
    frame.pages = {}
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
        frame.pages[info.key] = W:ScrollPage(frame.content, { reserveBar = true })
        BuildPage(frame, info.key)
        frame.pages[info.key]:ScrollTo(offsets and offsets[info.key] or 0)
    end
    frame.nav = W:NavList(frame.sidebar, {
        mode = "fixed", x = W.Theme.pad, y = -W.Theme.pad,
        width = 174 - W.Theme.pad * 2, items = items,
        getActive = function() return frame.selectedPage end,
        onSelect = function(key) SelectPage(frame, key) end,
    })
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("SKILL_LINES_CHANGED")
    frame:SetScript("OnEvent", function()
        if frame:IsShown() then QMT:RefreshOptionsControlState() end
    end)
    frame:SetScript("OnShow", function() QMT:RefreshOptionsControlState() end)
    QMT.optionsFrame = frame
    SelectPage(frame, selected)
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
    local old = self.optionsFrame or previousFrame
    if old and old ~= self.optionsFrame then ClearOwners(old) end
    if self.optionsFrame and (not W or self.optionsFrame.factory == W) then return self.optionsFrame end
    local selected = old and old.selectedPage or "overview"
    local offsets = old and SaveOffsets(old)
    if self.optionsFrame then
        ClearOwners(self.optionsFrame)
        self.optionsFrame:Hide()
        self.optionsFrame = nil
    end
    local frame = W and CreateFactoryFrame(W, selected, offsets) or LegacyCreate(self)
    previousFrame = frame
    if UISpecialFrames then
        local found
        for _, name in ipairs(UISpecialFrames) do
            if name == "QFXMinimapToolsOptionsFrame" then found = true; break end
        end
        if not found then UISpecialFrames[#UISpecialFrames + 1] = "QFXMinimapToolsOptionsFrame" end
    end
    return frame
end
