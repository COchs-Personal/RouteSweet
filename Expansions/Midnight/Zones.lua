-- Expansions/Midnight/Zones.lua
-- Zone definitions, portal locations, and connectivity for Midnight (Quel'Thalas)
-- Registers with RS.Expansion at load time.
--
-- LOAD ORDER: After Core/Expansion.lua, before Core modules.

local MAP_IDS = {
    SILVERMOON      = 2393,
    EVERSONG        = 2395,
    ZUL_AMAN        = 2437,
    HARANDAR        = 2413,
    VOIDSTORM       = 2405,
    ISLE_QUELDONAS  = 2536,
    ARCANTINA       = 2541,
}

-- Populate RS.Zones.MAP_IDS for backward compat
RS.Zones = RS.Zones or {}
RS.Zones.MAP_IDS = RS.Zones.MAP_IDS or {}
for k, v in pairs(MAP_IDS) do
    RS.Zones.MAP_IDS[k] = v
end

-- ============================================================
-- STATIC EVENTS & WEEKLY ACTIVITIES
-- ============================================================
local STATIC_ACTIVITIES = {
    -- EVERSONG WOODS
    {
        id          = "abundance_eversong",
        name        = "Abundance Cave (Eversong)",
        mapID       = 2395,
        x           = 0.48,
        y           = 0.76,
        type        = "ROTATING_EVENT",
        duration    = 5,
        rewards     = { "gold", "mounts", "professions" },
        questID     = 89507,
        priority    = 3,
        rotationHours = 8,
        notes       = "Skinning cave — best gold. 1 Shard of Dundun = empowered run.",
    },

    -- ZUL'AMAN
    {
        id          = "abundance_zulaman_1",
        name        = "Abundance Cave — Herbalism (Zul'Aman, Strait of Hexx'alor)",
        mapID       = 2437,
        x           = 0.532,
        y           = 0.545,
        type        = "ROTATING_EVENT",
        duration    = 5,
        rewards     = { "gold", "mounts", "professions" },
        questID     = 89507,
        priority    = 3,
        rotationHours = 8,
    },
    {
        id          = "abundance_zulaman_2",
        name        = "Abundance Cave — Nalorakk's Prowl (Zul'Aman)",
        mapID       = 2437,
        x           = 0.304,
        y           = 0.847,
        type        = "ROTATING_EVENT",
        duration    = 5,
        rewards     = { "gold", "mounts", "professions" },
        questID     = 89507,
        priority    = 3,
        rotationHours = 8,
    },

    -- HARANDAR
    {
        id          = "legends_haranir",
        name        = "Legends of the Haranir",
        mapID       = 2413,
        x           = 0.542,
        y           = 0.530,
        type        = "WEEKLY_EVENT",
        duration    = 15,
        rewards     = { "rep", "housing", "cosmetics" },
        questID        = 89268,
        questIDTurnin  = 93932,
        questIDMeta    = 93891,
        priority    = 1,
        notes       = "WARBAND-WIDE pick. Requires Renown 8 with Hara'ti. 7 relics, 1/week.",
        isWarbandLocked = true,
    },
    {
        id          = "abundance_harandar",
        name        = "Abundance Cave (Harandar)",
        mapID       = 2413,
        x           = 0.545,
        y           = 0.351,
        type        = "ROTATING_EVENT",
        duration    = 5,
        rewards     = { "gold", "mounts", "professions" },
        questID     = 89507,
        priority    = 3,
        rotationHours = 8,
    },

    -- VOIDSTORM
    {
        id          = "stormarion_assault",
        name        = "Stormarion Assault",
        mapID       = 2405,
        x           = 0.264,
        y           = 0.676,
        type        = "TIMED_EVENT",
        duration    = 30,
        rewards     = { "gear", "rep", "cache" },
        questID        = 90962,
        questIDMeta    = 93892,
        priority    = 1,
        spawnIntervalMin = 30,
        notes       = "Fires every 30 min. 5min prep + 3 waves. Check timer before flying in.",
    },
    {
        id          = "abundance_voidstorm",
        name        = "Abundance Cave (Voidstorm)",
        mapID       = 2405,
        x           = 0.455,
        y           = 0.423,
        type        = "ROTATING_EVENT",
        duration    = 5,
        rewards     = { "gold", "mounts", "professions" },
        questID     = 89507,
        priority    = 3,
        rotationHours = 8,
    },

    -- THE ARCANTINA
    {
        id          = "arcantina_patron_weekly",
        name        = "Arcantina: Patron Quest",
        mapID       = 2541,
        x           = 0.500,
        y           = 0.500,
        type        = "WEEKLY",
        duration    = 15,
        rewards     = { "housing_decor", "voidlight_marl" },
        questID     = 92320,
        questIDs    = { 92320 },
        priority    = 4,
        notes       = "Use Personal Key to Arcantina (15min CD) or Silvermoon Inn portal. " ..
                      "Quest sends to old-world zone. 9 total patron quests rotating weekly.",
        keyRequired = "arcantina",
    },
    {
        id          = "arcantina_meta",
        name        = "Midnight: Arcantina (Meta)",
        mapID       = 2541,
        x           = 0.500,
        y           = 0.500,
        type        = "WEEKLY",
        duration    = 2,
        rewards     = { "spark_of_radiance", "apex_cache" },
        questID     = 93767,
        priority    = 4,
        notes       = "Complete any patron quest to satisfy this meta. Pick up from Arcantina.",
    },
}

-- ============================================================
-- CONNECTIVITY GRAPH
-- ============================================================
local CONNECTIVITY = {
    [2393] = { -- Silvermoon
        neighbors = {
            { mapID = 2395, portalRequired = false, baseTravelMin = 0.5 },
            { mapID = 2413, portalRequired = true,  baseTravelMin = 1.5 },
            { mapID = 2405, portalRequired = true,  baseTravelMin = 1.5 },
        }
    },
    [2395] = { -- Eversong Woods
        neighbors = {
            { mapID = 2393, portalRequired = false, baseTravelMin = 0.5 },
            { mapID = 2437, portalRequired = false, baseTravelMin = 1.0 },
            { mapID = 2536, portalRequired = false, baseTravelMin = 1.5 },
        }
    },
    [2437] = { -- Zul'Aman
        neighbors = {
            { mapID = 2395, portalRequired = false, baseTravelMin = 1.0 },
            { mapID = 2393, portalRequired = false, baseTravelMin = 2.0 },
        }
    },
    [2413] = { -- Harandar
        neighbors = {
            { mapID = 2393, portalRequired = true,  baseTravelMin = 1.5 },
            { mapID = 2405, portalRequired = true,  baseTravelMin = 1.0 },
        }
    },
    [2405] = { -- Voidstorm
        neighbors = {
            { mapID = 2393, portalRequired = true,  baseTravelMin = 1.5 },
            { mapID = 2413, portalRequired = true,  baseTravelMin = 1.0 },
        }
    },
    [2536] = { -- Isle of Quel'Danas
        neighbors = {
            { mapID = 2395, portalRequired = false, baseTravelMin = 1.5 },
            { mapID = 2393, portalRequired = false, baseTravelMin = 2.5 },
        }
    },
    [2541] = { -- The Arcantina
        neighbors = {
            { mapID = 2393, portalRequired = true, baseTravelMin = 0.4 },
        }
    },
}

-- ============================================================
-- PORTALS
-- ============================================================
local PORTALS = {
    toHarandar          = { mapID = 2393, x = 0.30, y = 0.50, label = "Harandar Portal (west Silvermoon)" },
    toVoidstorm         = { mapID = 2393, x = 0.32, y = 0.50, label = "Voidstorm Portal (west Silvermoon)" },
    fromHarandar        = { mapID = 2413, x = 0.30, y = 0.75, label = "Return Portal (lower Den)" },
    harandarToVoidstorm = { mapID = 2413, x = 0.31, y = 0.74, label = "Voidstorm Portal (lower Den)" },
    fromVoidstorm       = { mapID = 2405, x = 0.25, y = 0.50, label = "Return Portal (Citadel)" },
    voidstormToHarandar = { mapID = 2405, x = 0.26, y = 0.51, label = "Harandar Portal (Citadel)" },
}

-- ============================================================
-- BIND ZONE MAP (subzone name → mapID for hearthstone routing)
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
    ["The Arcantina"]            = 2541,
}

-- ============================================================
-- REGISTER WITH EXPANSION SYSTEM
-- ============================================================
RS.Expansion:Register("Midnight", {
    levelRange     = { 90, 90 },
    hubMapID       = 2393,  -- Silvermoon City

    zones = {
        [2393] = { name = "Silvermoon",         yardWidth = 1800 },
        [2395] = { name = "Eversong Woods",     yardWidth = 3800 },
        [2437] = { name = "Zul'Aman",           yardWidth = 3200 },
        [2413] = { name = "Harandar",           yardWidth = 2800 },
        [2405] = { name = "Voidstorm",          yardWidth = 3000 },
        [2536] = { name = "Isle of Quel'Danas", yardWidth = 1400 },
        [2541] = { name = "The Arcantina",      yardWidth = 400  },
    },

    displayNames = {
        [2393] = "Silvermoon",
        [2395] = "Eversong Woods",
        [2413] = "Harandar",
        [2437] = "Zul'Aman",
        [2405] = "Voidstorm",
        [2536] = "Isle of Quel'Danas",
        [2541] = "The Arcantina",
    },

    connectivity     = CONNECTIVITY,
    portalZones      = { [2413] = true, [2405] = true },
    scanZoneIDs      = { 2395, 2437, 2413, 2405, 2536 },
    staticActivities = STATIC_ACTIVITIES,
    portals          = PORTALS,
    bindZoneMap      = BIND_ZONE_MAP,

    -- BuildDynamicActivities is set in Expansions/Midnight/Activities.lua
    -- db is set in Expansions/Midnight/Database.lua
})
