-- Core/Expansion.lua
-- Expansion registry and zone facade for RouteSweet
-- Allows multiple expansions to register their zone data, activities,
-- databases, and scan logic. Core modules read from this registry
-- instead of hardcoding expansion-specific data.
--
-- LOAD ORDER: Must load after RouteSweet.lua and before any expansion
-- modules or core consumers (FlightTime, QuestScanner, Routing, etc.)

RS.Expansion = RS.Expansion or {}

local E = RS.Expansion

E._registered = {}   -- keyed by expansion name
E._active     = {}   -- list of active expansion names for current character

-- ============================================================
-- REGISTRATION
-- ============================================================
-- Called at file-load time by each expansion module.
-- `data` must include:
--   levelRange     = { minLevel, maxLevel }
--   hubMapID       = number (default city map ID)
--   zones          = { [mapID] = { name, yardWidth }, ... }
--   connectivity   = { [mapID] = { neighbors = { ... } }, ... }
--   portalZones    = { [mapID] = true, ... }
--   scanZoneIDs    = { mapID, ... }
--   staticActivities = { { id, name, mapID, ... }, ... }
--   portals        = { ... }  (optional)
--   bindZoneMap    = { ["subzone"] = mapID, ... }
--   displayNames   = { [mapID] = "Name", ... }  (optional, falls back to zones[mapID].name)
-- Optional:
--   db             = table (expansion-specific database, aliased to RS.DB when active)
--   BuildDynamicActivities = function(enabledTypes) return { node, ... } end
function E:Register(name, data)
    if not name or not data then
        print("|cffff4444RouteSweet:|r Expansion:Register() requires name and data")
        return
    end
    if not data.levelRange then
        print("|cffff4444RouteSweet:|r Expansion '" .. name .. "' missing levelRange")
        return
    end

    self._registered[name] = data

    -- Populate RS.Zones facade tables for backward compatibility
    self:_mergeZoneData(name, data)
end

-- ============================================================
-- ACTIVATION (runtime, called at PLAYER_ENTERING_WORLD)
-- ============================================================
-- Determines which registered expansions apply to the current character.
-- Returns true if at least one expansion is active.
function E:DetectActive()
    self._active = {}
    local level = UnitLevel("player") or 0

    for name, exp in pairs(self._registered) do
        local minLvl = exp.levelRange[1] or 0
        local maxLvl = exp.levelRange[2] or 999
        if level >= minLvl and level <= maxLvl then
            table.insert(self._active, name)
        end
    end

    -- Sort for deterministic ordering
    table.sort(self._active)

    if #self._active > 0 then
        -- Alias RS.DB to primary expansion's database for backward compat.
        -- Preserve any core methods already on RS.DB (e.g. DetectFlightMode)
        -- by copying them onto the expansion DB before swapping.
        local primary = self._registered[self._active[1]]
        if primary and primary.db then
            local coreDB = RS.DB
            for k, v in pairs(coreDB) do
                if type(v) == "function" and primary.db[k] == nil then
                    primary.db[k] = v
                end
            end
            RS.DB = primary.db
        end
        return true
    end
    return false
end

-- Returns true if any expansion is active for the current character.
function E:HasActive()
    return self._active and #self._active > 0
end

-- Returns the list of active expansion names.
function E:GetActive()
    return self._active or {}
end

-- Returns the registered data table for an expansion by name.
function E:GetExpansion(name)
    return self._registered[name]
end

-- Returns a human-readable string listing all registered expansions and their level ranges.
function E:ListSupported()
    local parts = {}
    for name, exp in pairs(self._registered) do
        table.insert(parts, name .. " (level " .. exp.levelRange[1] .. "-" .. exp.levelRange[2] .. ")")
    end
    table.sort(parts)
    return table.concat(parts, ", ")
end

-- ============================================================
-- ZONE DATA ACCESSORS
-- These aggregate across all registered (not just active) expansions
-- so that zone lookups work even before DetectActive() runs.
-- ============================================================

-- Returns yard width for a mapID, or 3000 as fallback.
function E:GetZoneYardWidth(mapID)
    for _, exp in pairs(self._registered) do
        if exp.zones and exp.zones[mapID] then
            return exp.zones[mapID].yardWidth or 3000
        end
    end
    return 3000
end

-- Returns the connectivity graph entry for a mapID, or nil.
function E:GetConnectivity(mapID)
    for _, exp in pairs(self._registered) do
        if exp.connectivity and exp.connectivity[mapID] then
            return exp.connectivity[mapID]
        end
    end
    return nil
end

-- Returns the full merged connectivity table.
function E:GetFullConnectivity()
    local merged = {}
    for _, exp in pairs(self._registered) do
        if exp.connectivity then
            for mapID, data in pairs(exp.connectivity) do
                merged[mapID] = data
            end
        end
    end
    return merged
end

-- Returns merged portal zones set from all active expansions.
function E:GetPortalZones()
    local zones = {}
    for _, name in ipairs(self._active or {}) do
        local exp = self._registered[name]
        if exp and exp.portalZones then
            for mapID, v in pairs(exp.portalZones) do
                zones[mapID] = v
            end
        end
    end
    return zones
end

-- Returns combined scanZoneIDs from all active expansions.
function E:GetAllScanZoneIDs()
    local ids = {}
    for _, name in ipairs(self._active or {}) do
        local exp = self._registered[name]
        if exp and exp.scanZoneIDs then
            for _, mapID in ipairs(exp.scanZoneIDs) do
                table.insert(ids, mapID)
            end
        end
    end
    return ids
end

-- Returns all static activities from all active expansions.
function E:GetAllStaticActivities()
    local all = {}
    for _, name in ipairs(self._active or {}) do
        local exp = self._registered[name]
        if exp and exp.staticActivities then
            for _, act in ipairs(exp.staticActivities) do
                table.insert(all, act)
            end
        end
    end
    return all
end

-- Calls each active expansion's BuildDynamicActivities and merges results.
-- enabledTypes: set of enabled activity type IDs from the profile.
function E:BuildDynamicActivities(enabledTypes)
    local all = {}
    for _, name in ipairs(self._active or {}) do
        local exp = self._registered[name]
        if exp and exp.BuildDynamicActivities then
            local nodes = exp.BuildDynamicActivities(enabledTypes)
            if nodes then
                for _, node in ipairs(nodes) do
                    table.insert(all, node)
                end
            end
        end
    end
    return all
end

-- Returns a set of quest IDs that should be excluded from the dynamic
-- world quest scanner (handled by static expansion data instead).
function E:GetExcludedQuestIDs()
    local ids = {}
    for _, name in ipairs(self._active or {}) do
        local exp = self._registered[name]
        if exp and exp.GetExcludedQuestIDs then
            local expIDs = exp.GetExcludedQuestIDs()
            if expIDs then
                for qID in pairs(expIDs) do ids[qID] = true end
            end
        end
    end
    return ids
end

-- Returns the hub map ID of the primary active expansion (used as fallback
-- when player position is unknown).
function E:GetHubMapID()
    if self._active and #self._active > 0 then
        local exp = self._registered[self._active[1]]
        if exp and exp.hubMapID then return exp.hubMapID end
    end
    return nil
end

-- Returns the bind zone map for a subzone name, searching all registered expansions.
function E:GetBindZoneMap(subzone)
    for _, exp in pairs(self._registered) do
        if exp.bindZoneMap and exp.bindZoneMap[subzone] then
            return exp.bindZoneMap[subzone]
        end
    end
    return nil
end

-- Returns all bind zone map entries merged.
function E:GetFullBindZoneMap()
    local merged = {}
    for _, exp in pairs(self._registered) do
        if exp.bindZoneMap then
            for subzone, mapID in pairs(exp.bindZoneMap) do
                merged[subzone] = mapID
            end
        end
    end
    return merged
end

-- ============================================================
-- RS.Zones FACADE
-- Populates RS.Zones tables from registered expansion data so
-- existing code (UI, Routing portal notes, etc.) continues to work.
-- ============================================================
RS.Zones = RS.Zones or {}

function E:_mergeZoneData(name, data)
    -- MAP_IDS: build from zone keys
    if not RS.Zones.MAP_IDS then RS.Zones.MAP_IDS = {} end
    -- We don't know short names here, but the expansion module can set MAP_IDS directly

    -- CONNECTIVITY
    if data.connectivity then
        if not RS.Zones.CONNECTIVITY then RS.Zones.CONNECTIVITY = {} end
        for mapID, connData in pairs(data.connectivity) do
            RS.Zones.CONNECTIVITY[mapID] = connData
        end
    end

    -- STATIC_ACTIVITIES
    if data.staticActivities then
        if not RS.Zones.STATIC_ACTIVITIES then RS.Zones.STATIC_ACTIVITIES = {} end
        for _, act in ipairs(data.staticActivities) do
            table.insert(RS.Zones.STATIC_ACTIVITIES, act)
        end
    end

    -- PORTALS
    if data.portals then
        if not RS.Zones.PORTALS then RS.Zones.PORTALS = {} end
        for k, v in pairs(data.portals) do
            RS.Zones.PORTALS[k] = v
        end
    end

    -- Display names
    if data.displayNames then
        if not RS.Zones._displayNames then RS.Zones._displayNames = {} end
        for mapID, dname in pairs(data.displayNames) do
            RS.Zones._displayNames[mapID] = dname
        end
    elseif data.zones then
        if not RS.Zones._displayNames then RS.Zones._displayNames = {} end
        for mapID, zoneData in pairs(data.zones) do
            if zoneData.name then
                RS.Zones._displayNames[mapID] = zoneData.name
            end
        end
    end
end

-- Zone name lookup — reads from merged expansion data
function RS.Zones:GetZoneName(mapID)
    if self._displayNames and self._displayNames[mapID] then
        return self._displayNames[mapID]
    end
    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or ("Zone " .. tostring(mapID))
end

-- Portal check — reads from merged connectivity
function RS.Zones:RequiresPortal(fromMapID, toMapID)
    local conn = RS.Zones.CONNECTIVITY and RS.Zones.CONNECTIVITY[fromMapID]
    if not conn then return true end
    for _, neighbor in ipairs(conn.neighbors) do
        if neighbor.mapID == toMapID then
            return neighbor.portalRequired == true
        end
    end
    return true
end
