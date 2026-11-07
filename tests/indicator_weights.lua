-- Run from repository root: lua tests/indicator_weights.lua
local Q, textureCount = {}, 0
local noop = function() end
local methods = {}
local function object()
    return setmetatable({ scripts = {}, width = 0, height = 0 }, { __index = function(_, key)
        return methods[key] or (key:match("^Set") or key:match("^Register")) and noop
    end })
end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetPoint(...) self.point = { ... } end
function methods:ClearAllPoints() self.point = nil end
function methods:SetTexCoord(...) self.coords = { ... } end
function methods:SetTexture(path) self.path = path end
function methods:SetVertexColor(...) self.color = { ... } end
function methods:SetTextColor(...) self.color = { ... } end
function methods:SetText(text) self.text = text end
function methods:SetAlpha(alpha) self.alpha = alpha end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:HookScript(event, fn) self.scripts[event] = fn end
function methods:CreateTexture() textureCount = textureCount + 1; return object() end
function methods:CreateFontString() return object() end
function CreateFrame() return object() end
UIParent = object()
GetLocale = function() return "enUS" end
local function loadAddon(file) assert(loadfile("QFXMinimapTools/" .. file))("QFXMinimapTools", Q) end
loadAddon("Locale.lua"); loadAddon("Core/Utils.lua")
Q.InvalidateExcludeCache = noop
loadAddon("Core/Defaults.lua"); Q:LoadDB()
loadAddon("Modules/Minimap.lua")
Q.LayoutIndicatorColumn = noop
Q.ApplyFontStringFont = noop
local names = { calendar = "Calendar", mail = "Mail", crafting = "Hammer", tracking = "Magnifier" }
local function near(a, b) return math.abs(a - b) < 0.00001 end
for key, name in pairs(names) do
    local btn = Q:CreateIndicatorButton(key)
    assert(not btn.OutlineTextures, "weight must not allocate offset silhouettes")
    local atlas, path = Q:GetIndicatorArt(key)
    Q:ShowIndicatorIcon(btn, atlas, path)
    assert(btn.Icon.path:find(name .. "_Weights.blp", 1, true))
    for _, size in ipairs({ 12, 18, 24, 40 }) do
        Q:SetIndicatorSize(size)
        for weight = 0, 3 do
            Q:SetIndicatorWeight(weight)
            assert(Q.db.minimap.indicatorWeight == weight and btn.AppliedWeight == weight)
            local uv = btn.Icon.coords
            assert(uv[1] > weight / 4 and uv[2] < (weight + 1) / 4 and near(uv[2] - uv[1], 0.21875))
            assert(uv[3] == 0.0625 and uv[4] == 0.9375)
            for index = 1, 4 do assert(uv[index] == btn.HighlightIcon.coords[index]) end
            assert(btn.width == size and btn.Icon.width == size, "weight must not change layout or icon scale")
            Q:SetIndicatorHovered(btn, true)
            assert(near(btn.Icon.width, size * 1.12) and btn.AppliedWeight == weight)
            assert(btn.Icon.coords == uv, "hover must reuse the selected weight")
            Q:SetIndicatorHovered(btn, false)
            assert(btn.Icon.width == size)
        end
    end
    Q:SetIndicatorColor(0.2, 0.4, 0.6)
    assert(btn.Icon.color[1] == 0.2 and btn.HighlightIcon.color[3] == 0.6)
    if btn.CalendarDate then
        Q:UpdateCalendarDate(btn, 28)
        local text, width, x, y = btn.CalendarDate.text, btn.CalendarDate.width, btn.CalendarDate.point[4], btn.CalendarDate.point[5]
        Q:SetIndicatorWeight(0); Q:SetIndicatorWeight(3)
        assert(btn.CalendarDate.text == text and btn.CalendarDate.width == width
            and btn.CalendarDate.point[4] == x and btn.CalendarDate.point[5] == y, "weight must leave the date geometry intact")
    end
    Q:ShowIndicatorIcon(btn, nil, "Interface\\Icons\\INV_Misc_QuestionMark")
    assert(not btn.UsesWeightStrip and btn.Icon.coords[1] == 0 and btn.Icon.coords[2] == 1)
    Q:ShowIndicatorIcon(btn, atlas, path)
    assert(btn.UsesWeightStrip and btn.AppliedWeight == 3, "restoring bundled art must restore the selected weight")
end
assert(textureCount == 8, "four icons must use only main and highlight textures")
Q:SetIndicatorWeight(-20); assert(Q:GetIndicatorWeight() == 0)
Q:SetIndicatorWeight(20); assert(Q:GetIndicatorWeight() == 3)
for _, locale in ipairs({ "enUS", "zhCN", "zhTW" }) do
    Q.SelectLocale(locale)
    for weight = 0, 3 do
        Q:SetIndicatorWeight(weight)
        assert(type(Q:GetIndicatorWeightLabel()) == "string" and #Q:GetIndicatorWeightLabel() > 0)
    end
end
print("PASS: four weights, four sizes, four icons, UV/highlight/hover/color/date, persisted values, labels and eight textures")
