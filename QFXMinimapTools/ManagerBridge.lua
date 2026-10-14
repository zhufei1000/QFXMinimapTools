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
if target.ShowOptions then
    local original = target.ShowOptions
    target.ShowOptions = function(...)
        if OpenManager() then return true end
        return original(...)
    end
end
if target.ToggleOptions then
    local original = target.ToggleOptions
    target.ToggleOptions = function(...)
        if OpenManager() then return true end
        return original(...)
    end
end
if target.OpenBlizzardSettingsCategory then
    local original = target.OpenBlizzardSettingsCategory
    target.OpenBlizzardSettingsCategory = function(...)
        if OpenManager() then return true end
        return original(...)
    end
end
