local ADDON_NAME, QMT = ...
QMT = QMT or {}
_G.QFXMinimapTools = QMT

-- Client branch helpers
-- ############################################################
-- WoW Forever (Camelot, interface 16001) still reports WOW_PROJECT_MAINLINE,
-- so the interface number is the only reliable way to tell it apart from
-- Retail 12.x. Keep the range check in one place instead of scattering
-- version branches through the feature modules.
local FOREVER_MIN_INTERFACE = 16000
local FOREVER_MAX_INTERFACE = 20000
local RETAIL_12_MIN_INTERFACE = 120000
local RETAIL_12_MAX_INTERFACE = 130000
local isForeverCache
local isRetail12xCache

function QMT.GetInterfaceNumber()
    local _, _, _, interfaceNumber = GetBuildInfo()
    return tonumber(interfaceNumber)
end

function QMT.IsForever()
    if isForeverCache == nil then
        local interfaceNumber = QMT.GetInterfaceNumber()
        isForeverCache = interfaceNumber ~= nil
            and interfaceNumber >= FOREVER_MIN_INTERFACE
            and interfaceNumber < FOREVER_MAX_INTERFACE
    end
    return isForeverCache
end

function QMT.IsRetail12x()
    if isRetail12xCache == nil then
        local interfaceNumber = QMT.GetInterfaceNumber()
        isRetail12xCache = interfaceNumber ~= nil
            and interfaceNumber >= RETAIL_12_MIN_INTERFACE
            and interfaceNumber < RETAIL_12_MAX_INTERFACE
    end
    return isRetail12xCache
end
