local ADDON_NAME, QMT = ...
QMT = QMT or {}
_G.QFXMinimapTools = QMT

local L = setmetatable({}, { __index = function(_, key) return QMT.L and QMT.L[key] end })
local SafeCall = QMT.SafeCall
local Print = QMT.Print

local function FormatLatency(ms)
    ms = tonumber(ms) or 0
    return string.format("%d ms", ms)
end

local function FormatMemoryKB(kb)
    kb = tonumber(kb) or 0
    if kb >= 1024 then return string.format("%.2f MB", kb / 1024) end
    return string.format("%.0f KB", kb)
end

local function GetCVarCompat(name)
    if C_CVar and C_CVar.GetCVar then
        local value = SafeCall(C_CVar.GetCVar, name)
        if value ~= nil then return value end
    end
    if GetCVar then return SafeCall(GetCVar, name) end
    return nil
end

local function GetCVarBoolCompat(name)
    if C_CVar and C_CVar.GetCVarBool then
        local value = SafeCall(C_CVar.GetCVarBool, name)
        if value ~= nil then return value and true or false end
    end
    if GetCVarBool then
        local value = SafeCall(GetCVarBool, name)
        if value ~= nil then return value and true or false end
    end
    local value = GetCVarCompat(name)
    value = value ~= nil and tostring(value):lower() or "0"
    return value == "1" or value == "true" or value == "enabled"
end

local function SetCVarCompat(name, value)
    local ok
    if C_CVar and C_CVar.SetCVar then ok = SafeCall(C_CVar.SetCVar, name, tostring(value)) end
    if SetCVar then ok = SafeCall(SetCVar, name, tostring(value)) or ok end
    return ok
end

local function RegisterCVarCompat(name, defaultValue)
    if C_CVar and C_CVar.RegisterCVar then
        SafeCall(C_CVar.RegisterCVar, name, tostring(defaultValue or "0"))
    end
end

function QMT:IsBlizzardAddonProfilerEnabled()
    if C_AddOnProfiler and C_AddOnProfiler.IsEnabled then
        local enabled = SafeCall(C_AddOnProfiler.IsEnabled)
        if type(enabled) == "boolean" then return enabled end
    end
    local value = GetCVarCompat("addonProfilerEnabled")
    if value == nil then return nil end
    value = tostring(value):lower()
    return value == "1" or value == "true" or value == "enabled"
end


function QMT:ApplyCPUProfilerSetting(reason)
    local perf = self.db and self.db.performance or {}
    local disable = perf.disableCPUProfiling ~= false
    local oldScript = GetCVarBoolCompat("scriptProfile")
    local oldBlizz = self:IsBlizzardAddonProfilerEnabled()

    RegisterCVarCompat("addonProfilerEnabled", "1")
    if disable then
        SetCVarCompat("addonProfilerEnabled", "0")
        SetCVarCompat("scriptProfile", "0")
    else
        -- This path is for diagnostics only. scriptProfile requires /reload before
        -- legacy GetAddOnCPUUsage/UpdateAddOnCPUUsage values become useful.
        SetCVarCompat("addonProfilerEnabled", "1")
        SetCVarCompat("scriptProfile", "1")
    end

    local newScript = GetCVarBoolCompat("scriptProfile")
    local newBlizz = self:IsBlizzardAddonProfilerEnabled()
    if reason == "user" then
        Print(disable and L.CPU_PROFILE_DISABLE_DONE or L.CPU_PROFILE_ENABLE_DONE)
        if oldScript ~= newScript then Print(L.CPU_PROFILE_RELOAD) end
    end

    return newScript, newBlizz
end

local function GetAddonCountCompat()
    if C_AddOns and C_AddOns.GetNumAddOns then return SafeCall(C_AddOns.GetNumAddOns) or 0 end
    if GetNumAddOns then return SafeCall(GetNumAddOns) or 0 end
    return 0
end

local function GetAddonInfoCompat(index)
    local name, title, notes, loadable, reason, security, newVersion
    if C_AddOns and C_AddOns.GetAddOnInfo then
        name, title, notes, loadable, reason, security, newVersion = SafeCall(C_AddOns.GetAddOnInfo, index)
    elseif GetAddOnInfo then
        name, title, notes, loadable, reason, security, newVersion = SafeCall(GetAddOnInfo, index)
    end
    if type(name) == "table" then
        local info = name
        name = info.name or info.addonName or info[1]
        title = info.title or info.Title or info[2] or name
        loadable = info.loadable
        reason = info.reason
        security = info.security
        newVersion = info.newVersion
    end
    return name, title, loadable, reason, security, newVersion
end

local function IsAddonLoadedCompat(nameOrIndex)
    if C_AddOns and C_AddOns.IsAddOnLoaded then return SafeCall(C_AddOns.IsAddOnLoaded, nameOrIndex) and true or false end
    if IsAddOnLoaded then return SafeCall(IsAddOnLoaded, nameOrIndex) and true or false end
    return true
end

local function GetAddonMemoryUsageCompat(nameOrIndex)
    if C_AddOns and C_AddOns.GetAddOnMemoryUsage then return SafeCall(C_AddOns.GetAddOnMemoryUsage, nameOrIndex) or 0 end
    if GetAddOnMemoryUsage then return SafeCall(GetAddOnMemoryUsage, nameOrIndex) or 0 end
    return 0
end

local function GetAddonCPUUsageCompat(nameOrIndex)
    if C_AddOns and C_AddOns.GetAddOnCPUUsage then return SafeCall(C_AddOns.GetAddOnCPUUsage, nameOrIndex) or 0 end
    if GetAddOnCPUUsage then return SafeCall(GetAddOnCPUUsage, nameOrIndex) or 0 end
    return 0
end

function QMT:GetAddonUsageList(limit, includeCPU)
    limit = tonumber(limit) or 8
    if UpdateAddOnMemoryUsage then SafeCall(UpdateAddOnMemoryUsage) end
    if includeCPU and UpdateAddOnCPUUsage then SafeCall(UpdateAddOnCPUUsage) end

    local list = {}
    local count = GetAddonCountCompat()
    for i = 1, count do
        local name, title = GetAddonInfoCompat(i)
        if name and IsAddonLoadedCompat(name) then
            local memory = GetAddonMemoryUsageCompat(name)
            if not memory or memory == 0 then memory = GetAddonMemoryUsageCompat(i) end
            local cpu = includeCPU and GetAddonCPUUsageCompat(name) or nil
            if includeCPU and (not cpu or cpu == 0) then cpu = GetAddonCPUUsageCompat(i) end
            table.insert(list, {
                name = name,
                title = title and title ~= "" and title or name,
                memory = tonumber(memory) or 0,
                cpu = cpu and tonumber(cpu) or nil,
            })
        end
    end
    table.sort(list, function(a, b) return (a.memory or 0) > (b.memory or 0) end)

    local ownName = ADDON_NAME or "QFXMinimapTools"
    local foundOwn = false
    local shown = {}
    for i = 1, math.min(limit, #list) do
        shown[#shown + 1] = list[i]
        if list[i].name == ownName then foundOwn = true end
    end
    if not foundOwn then
        for _, item in ipairs(list) do
            if item.name == ownName then
                shown[#shown + 1] = item
                break
            end
        end
    end
    return shown
end

function QMT:ShowSystemTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
    GameTooltip:AddLine(L.PERFORMANCE_TITLE)

    local fps = math.floor((GetFramerate and GetFramerate() or 0) + 0.5)
    local down, up, home, world = 0, 0, 0, 0
    if GetNetStats then down, up, home, world = GetNetStats() end
    GameTooltip:AddDoubleLine(L.FPS_LABEL, tostring(fps), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.HOME_LATENCY, FormatLatency(home), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.WORLD_LATENCY, FormatLatency(world), 1, 1, 1, 1, 1, 1)

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.ADDON_MEMORY_TITLE)
    local perf = self.db and self.db.performance or {}
    local usage = self:GetAddonUsageList(perf.addonCount or 8, false)
    for _, item in ipairs(usage) do
        GameTooltip:AddDoubleLine(tostring(item.title or item.name), FormatMemoryKB(item.memory), 1, 1, 1, 1, 1, 1)
    end

    GameTooltip:Show()
end

