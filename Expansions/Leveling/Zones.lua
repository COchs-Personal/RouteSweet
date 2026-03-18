-- Expansions/Leveling/Zones.lua
-- Zone definitions for Midnight leveling (80-90).
-- Uses the same Quel'Thalas zones as the max-level Midnight module but
-- with leveling-appropriate connectivity and portal waypoints.
--
-- LOAD ORDER: After Core/Expansion.lua, before Core modules.

local MAP_IDS = {
    SILVERMOON      = 2393,
    EVERSONG        = 2395,
    ZUL_AMAN        = 2437,
    HARANDAR        = 2413,
    VOIDSTORM       = 2405,
    ISLE_QUELDONAS  = 2536,
}

-- ============================================================
-- PORTAL WAYPOINTS — actual coordinates for zone transition pins
-- These fire as intermediate waypoints when the route crosses zones.
-- ============================================================
local PORTAL_WAYPOINTS = {
    -- Silvermoon → Harandar (west side portal hub)
    SM_TO_HARANDAR = {
        mapID = 2393, x = 0.30, y = 0.50,
        label = "Portal to Harandar (west Silvermoon)",
    },
    -- Silvermoon → Voidstorm (west side portal hub)
    SM_TO_VOIDSTORM = {
        mapID = 2393, x = 0.32, y = 0.50,
        label = "Portal to Voidstorm (west Silvermoon)",
    },
    -- Harandar → Silvermoon return
    HARANDAR_TO_SM = {
        mapID = 2413, x = 0.30, y = 0.75,
        label = "Return Portal to Silvermoon (The Den)",
    },
    -- Harandar ↔ Voidstorm direct
    HARANDAR_TO_VOIDSTORM = {
        mapID = 2413, x = 0.31, y = 0.74,
        label = "Portal to Voidstorm (The Den)",
    },
    -- Voidstorm → Silvermoon return
    VOIDSTORM_TO_SM = {
        mapID = 2405, x = 0.25, y = 0.50,
        label = "Return Portal to Silvermoon (Citadel)",
    },
    -- Voidstorm ↔ Harandar direct
    VOIDSTORM_TO_HARANDAR = {
        mapID = 2405, x = 0.26, y = 0.51,
        label = "Portal to Harandar (Citadel)",
    },
}

-- ============================================================
-- CONNECTIVITY (same graph as Midnight — zones don't change)
-- ============================================================
local CONNECTIVITY = {
    [2393] = {
        neighbors = {
            { mapID = 2395, portalRequired = false, baseTravelMin = 0.5 },
            { mapID = 2413, portalRequired = true,  baseTravelMin = 1.5 },
            { mapID = 2405, portalRequired = true,  baseTravelMin = 1.5 },
        }
    },
    [2395] = {
        neighbors = {
            { mapID = 2393, portalRequired = false, baseTravelMin = 0.5 },
            { mapID = 2437, portalRequired = false, baseTravelMin = 1.0 },
            { mapID = 2536, portalRequired = false, baseTravelMin = 1.5 },
        }
    },
    [2437] = {
        neighbors = {
            { mapID = 2395, portalRequired = false, baseTravelMin = 1.0 },
            { mapID = 2393, portalRequired = false, baseTravelMin = 2.0 },
        }
    },
    [2413] = {
        neighbors = {
            { mapID = 2393, portalRequired = true,  baseTravelMin = 1.5 },
            { mapID = 2405, portalRequired = true,  baseTravelMin = 1.0 },
        }
    },
    [2405] = {
        neighbors = {
            { mapID = 2393, portalRequired = true,  baseTravelMin = 1.5 },
            { mapID = 2413, portalRequired = true,  baseTravelMin = 1.0 },
        }
    },
    [2536] = {
        neighbors = {
            { mapID = 2395, portalRequired = false, baseTravelMin = 1.5 },
            { mapID = 2393, portalRequired = false, baseTravelMin = 2.5 },
        }
    },
}

-- ============================================================
-- BIND ZONE MAP (same as Midnight)
-- ============================================================
local BIND_ZONE_MAP = {
    ["Wayfarer's Rest"]          = 2393,
    ["Silvermoon City"]          = 2393,
    ["Fairbreeze Village"]       = 2393,
    ["Tranquillien"]             = 2393,
    ["Ghostlands"]               = 2437,
    ["Zul'Aman"]                 = 2437,
    ["Amani'shi Outpost"]        = 2437,
    ["Harandar"]                 = 2413,
    ["Thornwall Bastion"]        = 2413,
    ["Harandar's Watch"]         = 2413,
    ["Voidstorm"]                = 2405,
    ["The Obsidian Citadel"]     = 2405,
    ["Stormrift Post"]           = 2405,
    ["Sun's Reach Harbor"]       = 2536,
    ["Isle of Quel'Danas"]       = 2536,
}

-- ============================================================
-- REGISTER
-- ============================================================
RS.Expansion:Register("Leveling", {
    levelRange     = { 80, 89 },
    hubMapID       = 2393,  -- Silvermoon City

    zones = {
        [2393] = { name = "Silvermoon",         yardWidth = 1800 },
        [2395] = { name = "Eversong Woods",     yardWidth = 3800 },
        [2437] = { name = "Zul'Aman",           yardWidth = 3200 },
        [2413] = { name = "Harandar",           yardWidth = 2800 },
        [2405] = { name = "Voidstorm",          yardWidth = 3000 },
        [2536] = { name = "Isle of Quel'Danas", yardWidth = 1400 },
    },

    displayNames = {
        [2393] = "Silvermoon",
        [2395] = "Eversong Woods",
        [2413] = "Harandar",
        [2437] = "Zul'Aman",
        [2405] = "Voidstorm",
        [2536] = "Isle of Quel'Danas",
    },

    connectivity     = CONNECTIVITY,
    portalZones      = { [2413] = true, [2405] = true },
    scanZoneIDs      = { 2393, 2395, 2437, 2413, 2405, 2536 },
    staticActivities = {},  -- leveling has no static weeklies
    portals          = PORTAL_WAYPOINTS,
    bindZoneMap      = BIND_ZONE_MAP,
})
