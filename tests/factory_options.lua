-- lua tests/factory_options.lua <manager source root> [factory|legacy|late|failed] [locale] [forever]
local root, mode = assert(arg[1], "manager source root required"), arg[2] or "factory"
local locale, forever = arg[3] or "enUS", arg[4] == "forever"
local frames, templates, timers, methods = {}, {}, {}, {}
local noop = function() end
local function object(kind, parent, name)
    local obj = { kind = kind, parent = parent, name = name, children = {}, regions = {},
        scripts = {}, shown = true, enabled = true, width = 650, height = 500, text = "" }
    setmetatable(obj, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if key:match("^Set") or key:match("^Enable") or key:match("^Register")
            or key:match("^Unregister") or key == "ClearAllPoints" or key == "AddMaskTexture"
            or key == "StartMoving" or key == "StopMovingOrSizing" then return noop end
    end })
    if parent then
        local list = (kind == "FontString" or kind == "Texture" or kind == "Line" or kind == "MaskTexture")
            and parent.regions or parent.children
        list[#list + 1] = obj
    end
    frames[#frames + 1] = obj
    return obj
end
function methods:GetName() return self.name end
function methods:GetObjectType() return self.kind end
function methods:GetParent() return self.parent end
function methods:GetChildren() return table.unpack(self.children) end
function methods:GetRegions() return table.unpack(self.regions) end
function methods:CreateTexture() return object("Texture", self) end
function methods:CreateMaskTexture() return object("MaskTexture", self) end
function methods:CreateFontString() return object("FontString", self) end
function methods:CreateLine() return object("Line", self) end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:GetScript(event) return self.scripts[event] end
function methods:HookScript(event, fn)
    local old = self.scripts[event]
    self.scripts[event] = function(...) if old then old(...) end; fn(...) end
end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetWidth(v) self.width = v end
function methods:SetHeight(v) self.height = v end
function methods:SetAllPoints(other) self:SetSize((other or self.parent):GetWidth(), (other or self.parent):GetHeight()) end
function methods:SetPoint(...) self.point = { ... } end
function methods:GetPoint() return table.unpack(self.point or {}) end
function methods:GetFrameLevel() return self.level or 1 end
function methods:SetFrameLevel(v) self.level = v end
function methods:SetFrameStrata(v) self.strata = v end
function methods:GetFrameStrata() return self.strata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM" end
function methods:GetScale() return self.scale or 1 end
function methods:SetScale(v) self.scale = v end
function methods:GetEffectiveScale() return self:GetScale() * (self.parent and self.parent:GetEffectiveScale() or 1) end
function methods:SetAlpha(v) self.alpha = v end
function methods:GetAlpha() return self.alpha or 1 end
function methods:SetTexture(path) self.texture = path end
function methods:GetTexture() return self.texture end
function methods:SetGradient(...) self.gradient = { ... } end
function methods:SetText(v) self.text = tostring(v or "") end
function methods:GetText() return self.text end
function methods:GetFontString() self.fontString = self.fontString or self:CreateFontString(); return self.fontString end
function methods:SetFont(path, size) self.fontPath, self.fontSize = path, size; return true end
function methods:GetFont() return self.fontPath or STANDARD_TEXT_FONT, self.fontSize or 12, "" end
function methods:GetStringWidth()
    local width = 0
    for _, cp in utf8.codes(self.text) do width = width + (cp > 127 and 1 or 0.55) * (self.fontSize or 12) end
    return width
end
function methods:GetStringHeight() return self.fontSize or 12 end
function methods:SetValue(v) self.value = v; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end end
function methods:GetValue() return self.value or 0 end
function methods:SetChecked(v) self.checked = v end
function methods:GetChecked() return self.checked end
function methods:SetEnabled(v) self.enabled = v end
function methods:Enable() self.enabled = true end
function methods:Disable() self.enabled = false end
function methods:IsEnabled() return self.enabled end
function methods:SetVerticalScroll(v) self.offset = v end
function methods:GetVerticalScroll() return self.offset or 0 end
function methods:HasFocus() return false end
function methods:Click() if self.enabled and self.scripts.OnClick then self.scripts.OnClick(self, "LeftButton") end end
function methods:IsMouseOver() return false end
UIParent = object("Frame"); UIParent:SetSize(1920, 1080)
GameTooltip = object("Frame", UIParent)
function CreateFrame(kind, name, parent, template)
    if template then templates[#templates + 1] = template end
    local frame = object(kind, parent or UIParent, name)
    if kind == "CheckButton" then frame.Text = frame:CreateFontString() end
    if name then _G[name] = frame end
    return frame
end
STANDARD_TEXT_FONT = "Fonts/FRIZQT__.TTF"
UISpecialFrames, SlashCmdList = {}, {}
unpack = table.unpack
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local combat = false
InCombatLockdown = function() return combat end
CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
GetLocale = function() return locale end
GetTime = function() return 0 end
GetPhysicalScreenSize = function() return 1920, 1080 end
GetScreenWidth = function() return 1920 end
GetScreenHeight = function() return 1080 end
local toc = assert(io.open("QFXMinimapTools/QFXMinimapTools.toc")):read("*a")
local version = assert(toc:match("## Version:%s*([^\r\n]+)"))
C_AddOns = { GetAddOnMetadata = function() return version end }
local Q = {}
local function loadAddon(file) assert(loadfile("QFXMinimapTools/" .. file))("QFXMinimapTools", Q) end
loadAddon("Locale.lua"); loadAddon("Core/Utils.lua")
Q.IsForever = function() return forever end
Q.InvalidateExcludeCache = noop
loadAddon("Core/Defaults.lua"); Q:LoadDB()
local changes, routes, loads = 0, 0, 0
Q.ApplyAll = function() changes = changes + 1 end
Q.GetBorderPresetLabel = function() return "Dark" end
Q.borderPresetOrder, Q.borderPresets = { "DARK" }, { DARK = { label = "Dark" } }
Q.GetIndicatorAnchorLabel = function() return Q.L.INDICATOR_ANCHOR_Q end
Q.GetIndicatorLayerLabel = function() return Q.L.INDICATOR_LAYER_OUTSIDE end
Q.GetUtilityIconSize = function() return Q.db.minimap.indicatorSize end
Q.GetIndicatorWeight = function() return Q.db.minimap.indicatorWeight end
Q.GetIndicatorSpacing = function() return Q.db.minimap.indicatorSpacing end
local status = "Gathering status"
Q.GetGatheringProfessionStatusText = function() return status end
Q.GetLanguageLabel = function(_, key)
    return key == "enUS" and Q.L.LANGUAGE_EN or key == "zhCN" and Q.L.LANGUAGE_ZH or Q.L.LANGUAGE_AUTO
end
Q.SetUILanguage = function(_, key)
    Q.db.ui.language = key; Q.SelectLocale(key)
    Q.optionsFrame:Hide(); Q.optionsFrame = nil
    Q:ShowOptions()
end
ReloadUI = function() changes = changes + 1 end
loadAddon("UI/Widgets.lua"); loadAddon("UI/Options.lua"); loadAddon("UI/FactoryOptions.lua"); loadAddon("ManagerBridge.lua")
assert(#frames == 2 and not QFXWidgets, "settings must remain lazy at startup")
local function attachManager(fail)
    QFXAddonManager = { EnsureConfigLoaded = function()
        loads = loads + 1
        if fail then return false end
        assert(loadfile(root .. "/QFXAddonManager_Config/Libs/QFXWidgets.lua"))("QFXAddonManager_Config", {})
        assert(loadfile(root .. "/QFXAddonManager/Core/Widgets.lua"))("QFXAddonManager", QFXAddonManager)
        QFXAddonManager.Widgets.ApplyBrand()
        QFXWidgets:SetSkin({ toggleAnim = false })
        return true
    end }
    QFXAddonManagerAPI = { OpenAddonSettings = function() routes = routes + 1; return true end }
end
if mode == "factory" then attachManager() elseif mode == "failed" then attachManager(true) end
Q:ToggleOptions()
assert(Q.optionsFrame:IsShown(), "first toggle must open the settings")
assert(routes == 0, "native settings must not redirect into manager")
if mode == "late" then attachManager(); Q:ShowOptions() end
if mode == "legacy" or mode == "failed" then
    assert(not QFXWidgets and #templates > 0)
    assert(loads == (mode == "failed" and 1 or 0))
    Q:ToggleOptions(); assert(not Q.optionsFrame:IsShown())
    print("PASS: " .. mode .. " " .. locale .. " fallback and first toggle")
    return
end
local W = assert(QFXWidgets)
if mode == "factory" then assert(#templates == 0, "factory settings must not create Blizzard controls") end
assert(loads == 1 and not W._refreshScope)
local function walk(node, predicate)
    if predicate(node) then return node end
    for _, child in ipairs(node.children) do
        local found = walk(child, predicate)
        if found then return found end
    end
end
local function find(page, text)
    local row = walk(page.content, function(f) return f._leftRegion and f._leftRegion._label:GetText() == text end)
    return assert(row, "missing row: " .. text)
end
local function nav(key)
    local f = Q.optionsFrame
    f.nav.buttons[key]._hit:GetScript("OnMouseDown")(f.nav.buttons[key]._hit, "LeftButton")
    assert(not W.lastNavError, W.lastNavError)
    assert(f.selectedPage == key and f.pages[key].frame:IsShown())
    Q:RefreshOptionsControlState(); assert(not W.lastRefreshError, W.lastRefreshError)
end
for _, info in ipairs(Q:GetManagerSettingsPages()) do nav(info.key) end
local f = Q.optionsFrame
local complete, missing = W:ValidateAddonWindow(f)
assert(complete, table.concat(missing, ", "))
assert(f.chrome.footer.version:GetText():find(version, 1, true))
local destinations = { "1049855225", "https://discord.gg/HVJ2y4v7k4", "https://github.com/zhufei1000/QFXMinimapTools" }
for index, value in ipairs(destinations) do
    f.chrome.footer.buttons[index]:Click()
    assert(f.chrome.copyDialog.editBox:GetText() == value)
end
local dialog = f.chrome.copyDialog
Q:ToggleOptions(); assert(not f:IsShown() and not dialog:IsShown())
local frameCount, refreshCount = #frames, #W._refresh
Q:ToggleOptions(); assert(Q.optionsFrame == f and f:IsShown() and loads == 1)
assert(#frames == frameCount and #W._refresh == refreshCount, "reopening must reuse all controls")
nav("bag")
Q.db.bag.enabled = false; Q:RefreshOptionsControlState()
assert(find(f.pages.bag, Q.L.BUTTON_SCALE)._leftRegion._control:GetAlpha() == .35)
assert(find(f.pages.bag, Q.L.EXCLUDE)._leftRegion._control:GetAlpha() == .35)
Q.db.bag.enabled = true; Q:RefreshOptionsControlState()
nav("minimap")
local slider = find(f.pages.minimap, Q.L.MINIMAP_SCALE)._leftRegion._control
local before = changes
slider:GetScript("OnMouseDown")(slider, "LeftButton")
slider:SetValue(1.3); slider:SetValue(1.4)
assert(changes == before, "dragging must apply only on release")
slider:GetScript("OnMouseUp")(slider)
assert(changes == before + 1 and Q.db.minimap.scale == 1.4, "slider must commit to the live DB once")
combat = true; Q:RefreshOptionsControlState()
assert(find(f.pages.minimap, Q.L.MINIMAP_SCALE)._leftRegion._control:GetAlpha() == .35)
slider:SetValue(1.6); Q:RefreshOptionsControlState()
assert(changes == before + 1 and Q.db.minimap.scale == 1.4 and slider:GetValue() == 1.4,
    "combat must reject changes and restore the displayed value")
combat = false; Q:RefreshOptionsControlState()
assert(find(f.pages.minimap, Q.L.MINIMAP_SCALE)._leftRegion._control:GetAlpha() == 1)
if not forever then
    nav("flight")
    status = "Profession changed"; Q:RefreshOptionsControlState()
    assert(walk(f.pages.flight.content, function(node) return node._qfx == "statusRow" and node._value:GetText() == status end))
end
nav("advanced")
local reload = find(f.pages.advanced, Q.L.RELOAD)._leftRegion._control
before = changes; reload:Click(); assert(changes == before + 1, "native advanced page must retain reload")
f.pages.advanced:ScrollTo(35)
Q:SetUILanguage("zhCN")
assert(Q.optionsFrame ~= f and Q.optionsFrame.selectedPage == "advanced")
for _, entry in ipairs(W._refresh) do
    for _, page in pairs(f.pages) do assert(entry.owner ~= page.content, "discarded pages must release callbacks") end
end
assert(not W._refreshScope and not W.lastRefreshError)
local callbackCount = #W._refresh
for _ = 1, 4 do
    Q:SetUILanguage("enUS"); Q:SetUILanguage("zhCN")
    Q:RefreshOptionsControlState()
    assert(#W._refresh == callbackCount and not W.lastRefreshError, "language rebuilds must not leak callbacks")
end
assert(#UISpecialFrames == 1)
print("PASS: " .. mode .. " " .. locale .. (forever and " forever" or " retail") .. ": seven pages, chrome, contacts, native entry, state, combat, locale and cleanup")
