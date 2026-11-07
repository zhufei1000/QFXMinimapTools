local _, ns = ...
local target = _G.QFXMinimapTools
if not target then return end
_G["QFXMinimapToolsManagerAPI"] = target
local function OpenManager(tab)
    local api = rawget(_G, "QFXAddonManagerAPI")
    if not api or type(api.OpenAddonSettings) ~= "function" then return false end
    return api.OpenAddonSettings("QFXMinimapTools", tab)
end
target.TryOpenManager = OpenManager
-- Keep ShowOptions/ToggleOptions/OpenBlizzardSettingsCategory native. The
-- manager launches these native windows; it does not replace them.
