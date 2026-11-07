local ADDON_NAME, QMT = ...
QMT = QMT or {}

local DeepCopy = QMT.DeepCopy
local MergeDefaults = QMT.MergeDefaults
local NormalizeLanguageChoice = QMT.NormalizeLanguageChoice
local Print = QMT.Print
local L = setmetatable({}, { __index = function(_, key) return QMT.L and QMT.L[key] end })

local defaults = {
    version = 38,
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
        borderEnabled = true,
        borderPreset = "AUTO_SKIN",
        borderColor = {0.18, 0.18, 0.18, 1},
        borderEdgeFile = nil,
        autoSnap = true,
        locked = true,
        manualPoint = nil,
        flightCenter = true,
        flightScale = 2.10,
        flightPosY = -55,
        flightAlpha = 0.50,
        flightCenterOnlyGathering = true,
        snapX = -9,
        snapY = -9,
        indicatorDirection = "DOWN",
        indicatorAnchor = "Q",
        indicatorLayer = "OUTSIDE",
        indicatorSize = 18,
        indicatorSpacing = 4,
        indicatorWeight = 2,
        indicatorColorMode = "CUSTOM",
        indicatorColor = {1, 1, 1},
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
        addonCount = 8,
    },
    display = {
        fontSize = 12,
        font = "AUTO",
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

-- WoW Forever is a Classic-era ruleset on the modern client. Outdoor flight
-- center and Retail shard/phase IDs have no meaning there, so start with both
-- features off instead of showing permanently empty widgets.
if QMT.IsForever and QMT.IsForever() then
    defaults.minimap.flightCenter = false
    defaults.minimap.flightCenterOnlyGathering = false
    defaults.display.phaseID = false
end

local function NormalizeCurrentDB(db)
    db.ui = db.ui or {}
    db.ui.language = NormalizeLanguageChoice(db.ui.language)

    db.display = db.display or {}
    if type(db.display.font) ~= "string" or db.display.font == "" then db.display.font = "AUTO" end
    -- FRIZQT does not contain every locale's glyphs (notably Chinese zone names).
    -- Migrate the old built-in default while preserving genuinely custom fonts.
    if db.display.font == "Fonts\\FRIZQT__.TTF" then db.display.font = "AUTO" end
    if tonumber(db.display.coordsInterval or 0) < 1.00 then db.display.coordsInterval = 1.00 end

    -- Removed live options. Existing SavedVariables may still contain them;
    -- ignore/delete them instead of carrying old-version migration branches.
    db.display.durability = nil

    db.minimap = db.minimap or {}
    if db.minimap.indicatorDirection ~= "UP" and db.minimap.indicatorDirection ~= "DOWN"
        and db.minimap.indicatorDirection ~= "LEFT" and db.minimap.indicatorDirection ~= "RIGHT" then
        db.minimap.indicatorDirection = "DOWN"
    end
    local anchor = db.minimap.indicatorAnchor
    if anchor ~= "Q" and anchor ~= "TOPLEFT" and anchor ~= "TOP" and anchor ~= "TOPRIGHT"
        and anchor ~= "LEFT" and anchor ~= "RIGHT" and anchor ~= "BOTTOMLEFT"
        and anchor ~= "BOTTOM" and anchor ~= "BOTTOMRIGHT" then
        db.minimap.indicatorAnchor = "Q"
    end
    if db.minimap.indicatorLayer ~= "ON" and db.minimap.indicatorLayer ~= "OUTSIDE"
        and db.minimap.indicatorLayer ~= "INSIDE" then
        db.minimap.indicatorLayer = "OUTSIDE"
    end
    db.minimap.indicatorSize = math.max(12, math.min(40, math.floor((tonumber(db.minimap.indicatorSize) or 18) + 0.5)))
    db.minimap.indicatorSpacing = math.max(0, math.min(24, math.floor((tonumber(db.minimap.indicatorSpacing) or 4) + 0.5)))
    db.minimap.indicatorWeight = math.max(0, math.min(3, math.floor((tonumber(db.minimap.indicatorWeight) or 2) + 0.5)))
    if db.minimap.indicatorColorMode ~= "CLASS" and db.minimap.indicatorColorMode ~= "CUSTOM" then
        db.minimap.indicatorColorMode = "CUSTOM"
    end
    local iconColor = type(db.minimap.indicatorColor) == "table" and db.minimap.indicatorColor or {}
    db.minimap.indicatorColor = {}
    for i = 1, 3 do
        db.minimap.indicatorColor[i] = math.max(0, math.min(1, tonumber(iconColor[i]) or 1))
    end
    if type(db.minimap.borderEnabled) ~= "boolean" then db.minimap.borderEnabled = true end
    db.minimap.borderSize = math.max(1, math.min(12, tonumber(db.minimap.borderSize) or 3))
    -- Keep the user's feature choices across addon updates. Older builds reset
    -- flightCenter whenever the internal DB version changed, which could make the
    -- gathering restriction appear broken after updating the addon.
    db.display.coordsInterval = math.max(2.00, tonumber(db.display.coordsInterval or 2) or 2)
    db.display.systemInterval = math.max(5.00, tonumber(db.display.systemInterval or 5) or 5)
    db.display.timeInterval = math.max(60.00, tonumber(db.display.timeInterval or 60) or 60)
    if type(db.minimap.flightCenterOnlyGathering) ~= "boolean" then
        db.minimap.flightCenterOnlyGathering = true
    end

    db.bag = db.bag or {}
    db.bag.manualExclude = type(db.bag.manualExclude) == "table" and db.bag.manualExclude or {}

    db.performance = db.performance or {}
    -- 1.0.60 no longer changes the client's global CPU profiler during login.
    -- Remove the old stored enforcement flag; the advanced-page control now reflects
    -- and changes the live profiler state only when the user explicitly clicks it.
    db.performance.disableCPUProfiling = nil

    -- Keep Forever on the supported feature set even when an old SavedVariables
    -- file or a copied WTF folder still has these switches enabled.
    if QMT.IsForever and QMT.IsForever() then
        db.minimap.flightCenter = false
        db.minimap.flightCenterOnlyGathering = false
        db.display.phaseID = false
    end

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
