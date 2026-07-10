local ADDON_NAME, QMT = ...
QMT = QMT or {}

local DeepCopy = QMT.DeepCopy
local MergeDefaults = QMT.MergeDefaults
local NormalizeLanguageChoice = QMT.NormalizeLanguageChoice
local Print = QMT.Print
local L = setmetatable({}, { __index = function(_, key) return QMT.L and QMT.L[key] end })

local defaults = {
    version = 35,
    ui = {
        language = "AUTO",
    },
    minimap = {
        enabled = true,
        square = true,
        scale = 1.20,
        unclamp = true,
        hideCompartment = true,
        borderSize = 3,
        borderPreset = "AUTO_SKIN",
        borderColor = {0.18, 0.18, 0.18, 1},
        borderEdgeFile = nil,
        autoSnap = true,
        locked = true,
        manualPoint = nil,
        flightCenter = false,
        flightScale = 2.10,
        flightPosY = -55,
        flightAlpha = 0.50,
        flightCenterOnlyGathering = true,
        snapX = -9,
        snapY = -9,
    },
    bag = {
        enabled = true,
        autoClose = false,
        buttonScale = 1.00,
        buttonsPerRow = 8,
        mainButtonOffsetY = 0,
        mainButtonEdge = "LEFT",
        mainButtonOffset = 0,
        manualExclude = {},
        exclude = "MiniMapTracking,MiniMapMailFrame,MiniMapWorldMapButton,MinimapZoomIn,MinimapZoomOut,GameTimeFrame,TimeManagerClockButton,QueueStatusButton,QueueStatusMinimapButton,AddonCompartmentFrame,ExpansionLandingPageMinimapButton,GarrisonLandingPageMinimapButton,CraftingOrderFrame,ProfessionsCustomerOrdersFrame,ProfessionsCustomerOrders_MinimapButton",
    },
    performance = {
        disableCPUProfiling = true,
        addonCount = 8,
    },
    display = {
        fontSize = 12,
        font = "Fonts\\FRIZQT__.TTF",
        outline = "OUTLINE",
        shadow = true,
        accent = {0.5019608, 0.5019608, 1.00},
        location = true,
        coordinates = true,
        time = true,
        system = true,
        phaseID = true,
        difficulty = true,
        coordsDecimals = 1,
        coordsInterval = 2.00,
        systemInterval = 5.00,
        systemString = "%fps | %home",
        timeInterval = 60.00,
        useRealmTime = false,
        use12Hour = false,
        showSubZone = true,
    },
}

local function NormalizeCurrentDB(db)
    local oldVersion = tonumber(db.version or 0) or 0
    db.ui = db.ui or {}
    db.ui.language = NormalizeLanguageChoice(db.ui.language)

    db.display = db.display or {}
    if type(db.display.font) ~= "string" or db.display.font == "" then db.display.font = "AUTO" end
    if tonumber(db.display.coordsInterval or 0) < 1.00 then db.display.coordsInterval = 1.00 end

    -- Removed live options. Existing SavedVariables may still contain them;
    -- ignore/delete them instead of carrying old-version migration branches.
    db.display.durability = nil

    db.minimap = db.minimap or {}
    -- 1.0.59 uses an independent lightweight refresh model. Do not preserve old high-frequency
    -- stored intervals; keep existing visual choices where they still make sense.
    if oldVersion < defaults.version then
        db.minimap.flightCenter = false
        db.display.coordsInterval = math.max(2.00, tonumber(db.display.coordsInterval or 2) or 2)
        db.display.systemInterval = math.max(5.00, tonumber(db.display.systemInterval or 5) or 5)
        db.display.timeInterval = math.max(60.00, tonumber(db.display.timeInterval or 60) or 60)
    end

    db.bag = db.bag or {}
    db.bag.manualExclude = type(db.bag.manualExclude) == "table" and db.bag.manualExclude or {}

    db.version = defaults.version
end

function QMT:LoadDB()
    QFXMinimapToolsDB = MergeDefaults(QFXMinimapToolsDB, DeepCopy(defaults))
    self.db = QFXMinimapToolsDB
    NormalizeCurrentDB(self.db)
    self:InvalidateExcludeCache()
    if self.RefreshLocale then self:RefreshLocale() end
end

function QMT:ResetDefaults()
    QFXMinimapToolsDB = DeepCopy(defaults)
    self.db = QFXMinimapToolsDB
    NormalizeCurrentDB(self.db)
    self:InvalidateExcludeCache()
    if self.RefreshLocale then self:RefreshLocale() end
    self:ApplyAll()
    if self.optionsFrame then self.optionsFrame:Hide() self.optionsFrame = nil self:ShowOptions() end
    Print(L.RESET_DONE)
end
