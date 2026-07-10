local ADDON_NAME, QMT = ...
QMT = QMT or {}
_G.QFXMinimapTools = QMT

QMT.API = QMT.API or {}
QMT.API.GetBorderStyle = function() return QMT:GetBorderStyle() end
QMT.API.SetBorderPreset = function(key, noSave) return QMT:SetBorderPreset(key, noSave) end
QMT.API.SetBorderColor = function(r, g, b, a, noSave, edgeFile, edgeSize) return QMT:SetBorderColor(r, g, b, a, noSave, edgeFile, edgeSize) end
QMT.API.SetBorderStyle = function(style, noSave) return QMT:SetBorderStyle(style, noSave) end
QMT.API.RegisterBorderPreset = function(key, label, r, g, b, a, edgeFile, edgeSize) return QMT:RegisterBorderPreset(key, label, r, g, b, a, edgeFile, edgeSize) end
