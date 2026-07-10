local ADDON_NAME, QMT = ...
QMT = QMT or {}

local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do dst[k] = DeepCopy(v) end
    return dst
end

local function MergeDefaults(dst, src)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = MergeDefaults(dst[k], v)
        elseif type(dst[k]) ~= type(v) then
            dst[k] = v
        end
    end
    return dst
end

local function Print(msg)
    print("|cff66ccffQFX Minimap|r: " .. tostring(msg))
end

local function Clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function Round(value, step)
    step = step or 1
    return math.floor(value / step + 0.5) * step
end

local function HexFromRGB(r, g, b)
    r = math.floor(Clamp((r or 1) * 255, 0, 255) + 0.5)
    g = math.floor(Clamp((g or 1) * 255, 0, 255) + 0.5)
    b = math.floor(Clamp((b or 1) * 255, 0, 255) + 0.5)
    return string.format("ff%02x%02x%02x", r, g, b)
end

local function AccentHex()
    local classFile = select(2, UnitClass("player"))
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if c then return HexFromRGB(c.r, c.g, c.b) end
    local a = QMT.db.display.accent
    return HexFromRGB(a[1], a[2], a[3])
end

local function DisplayAccentHex()
    local a = QMT.db and QMT.db.display and QMT.db.display.accent or {0.5019608, 0.5019608, 1.0}
    return HexFromRGB(a[1] or 0.5019608, a[2] or 0.5019608, a[3] or 1.0)
end

local function ColorText(text, hex)
    if not text or text == "" then return "" end
    return "|c" .. (hex or AccentHex()) .. text .. "|r"
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(func, ...)
    if ok then return a, b, c, d end
    return nil
end

local function GetClientDefaultFont()
    if type(STANDARD_TEXT_FONT) == "string" and STANDARD_TEXT_FONT ~= "" then
        return STANDARD_TEXT_FONT
    end
    if GameFontHighlightSmall and GameFontHighlightSmall.GetFont then
        local font = GameFontHighlightSmall:GetFont()
        if type(font) == "string" and font ~= "" then return font end
    end
    return nil
end

local function ResolveFontPath(font)
    if type(font) == "string" and font ~= "" and font ~= "AUTO" then
        return font
    end
    return GetClientDefaultFont()
end

local function ApplyFontStringFont(fontString, preferredFont, fontSize, outline)
    if not fontString then return nil end
    local fonts = {
        preferredFont,
        fontString.GetFont and fontString:GetFont(),
        GetClientDefaultFont(),
        "Fonts\\FRIZQT__.TTF",
    }
    local tried = {}
    for _, font in ipairs(fonts) do
        if type(font) == "string" and font ~= "" and not tried[font] then
            tried[font] = true
            if SafeCall(fontString.SetFont, fontString, font, fontSize, outline) then
                return font
            end
        end
    end
    return nil
end

local function IsDescendant(parent, child)
    if not parent or not child then return false end
    if parent == child then return true end
    local p = child.GetParent and child:GetParent()
    while p do
        if p == parent then return true end
        p = p.GetParent and p:GetParent()
    end
    return false
end

QMT.DeepCopy = DeepCopy
QMT.MergeDefaults = MergeDefaults
QMT.Print = Print
QMT.Clamp = Clamp
QMT.Round = Round
QMT.HexFromRGB = HexFromRGB
QMT.AccentHex = AccentHex
QMT.DisplayAccentHex = DisplayAccentHex
QMT.ColorText = ColorText
QMT.SafeCall = SafeCall
QMT.GetClientDefaultFont = GetClientDefaultFont
QMT.ResolveFontPath = ResolveFontPath
QMT.ApplyFontStringFont = ApplyFontStringFont
QMT.IsDescendant = IsDescendant
