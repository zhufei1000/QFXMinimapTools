-- Run from the repository root: lua tests/cache_paths.lua
local Q = {}
local function loadAddon(file) assert(loadfile("QFXMinimapTools/" .. file))("QFXMinimapTools", Q) end
GetLocale = function() return "enUS" end
loadAddon("Locale.lua")
loadAddon("Core/Utils.lua")
loadAddon("Core/Defaults.lua")
loadAddon("Modules/Minimap.lua")
Q.InvalidateExcludeCache = function() end
Q.ApplyAll = function() end
Q:LoadDB()

-- Nested DB tables must be owned by SavedVariables, not shared with defaults.
assert(type(Q.db.minimap) == "table" and type(Q.db.bag.pinnedButtons) == "table")
assert(Q.db.minimap ~= Q.db.bag.pinnedButtons)
Q.db.minimap.borderColor[1] = 0.123
Q:ResetDefaults()
assert(Q.db.minimap.borderColor[1] ~= 0.123, "reset must restore the default border colour")

-- Native frame lists must be cached, but rebuild when a source reference changes.
local q1, q2 = {}, {}
_G.QueueStatusMinimapButton, _G.QueueStatusButton = q1, nil
MinimapCluster = {QueueStatusMinimapButton = q2}
local first = Q:GetNativeQueueFrames()
assert(first == Q:GetNativeQueueFrames() and #first == 2, "queue list should be cached")
_G.QueueStatusMinimapButton = nil
local second = Q:GetNativeQueueFrames()
assert(second ~= first and #second == 1 and second[1] == q2, "changed source must rebuild the list")

print("PASS: default DB isolation and native frame list cache")
