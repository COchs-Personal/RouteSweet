-- Core/FlightTime.lua
-- Travel time estimation between two map coordinates
-- Handles Skyriding (variable speed, momentum-based) vs static flight mounts
-- Accounts for portal zone penalties

RS.Flight = RS.Flight or {}

-- ============================================================
-- SPEED CONSTANTS
-- All speeds in yards/second. WoW maps use normalised 0-1 coords.
-- Approximate yard scale per zone (varies, these are tuned estimates):
--   Eversong Woods ~ 3800 yards wide
--   Zul'Aman       ~ 3200 yards wide
--   Harandar       ~ 2800 yards wide
--   Voidstorm      ~ 3000 yards wide
-- ============================================================

-- Zone yard widths now come from the expansion registry.
-- RS.Expansion:GetZoneYardWidth(mapID) returns the width or 3000 as fallback.

-- Flight speeds in yards/second
local SPEED = {
    -- Skyriding: starts slow, accelerates. Average across a medium-length flight:
    SKYRIDING_SHORT  = 40,   -- < 500 yards: not enough time to build momentum
    SKYRIDING_MEDIUM = 75,   -- 500-1500 yards: good momentum window
    SKYRIDING_LONG   = 110,  -- > 1500 yards: full speed with dive boosts

    -- Static mount (150% ground speed = 2.67x walk, flight ~280% = ~26 yds/s)
    STATIC_FLIGHT    = 26,
    STATIC_GROUND    = 14,   -- Used near quest objectives (dismount + walk)
}

-- Overhead costs in seconds
local OVERHEAD = {
    MOUNT_UP         = 2,   -- Mounting animation
    DISMOUNT_WALK    = 8,   -- Average walk after landing to interact
    PORTAL_LOAD      = 8,   -- Zone transition loading screen
    PORTAL_WALK      = 30,  -- Walking to portal in Silvermoon + through
    HEARTH_CAST      = 10,  -- Hearthstone cast time
    -- Arcantina Key (item 253629, Warband Toy, 15min CD — hotfixed 2026-03-09):
    --   Use Key (2s) -> Arcantina instance load (8s) -> walk to exit portal (~20s)
    --   -> Silvermoon Inn load (8s) = ~38s total to Silvermoon.
    --   Functionally a Silvermoon hearthstone with 15min CD.
    --   Permanent portal back to Arcantina exists at Silvermoon Inn (Wayfarer's Rest).
    ARCANTINA_CAST   = 2,
    ARCANTINA_TO_SM  = 20,  -- Walk inside Arcantina to exit portal
    -- Total Key -> Silvermoon ≈ 38s
}

-- Hub map ID: read from active expansion, fallback to Silvermoon
local function getHubMapID()
    return RS.Expansion:GetHubMapID() or 2393
end

-- ============================================================
-- TRAVEL TOOL HELPERS
-- Hearthstone and Arcantina Key can eliminate specific portal legs
-- ============================================================

-- Bind zone map now comes from the expansion registry.
-- RS.Expansion:GetBindZoneMap(subzone) returns the mapID or nil.

-- Returns the mapID the player's hearthstone is currently bound to,
-- using the live GetBindLocation() API. Returns nil if unknown/unset.
local function hearthMapID()
    local loc = GetBindLocation and GetBindLocation() or nil
    -- GetBindLocation() returns subzone string; map to our zone IDs
    if not loc or loc == "" then return nil end
    return RS.Expansion:GetBindZoneMap(loc)
end

-- Returns true if hearthstone is available (not on cooldown, bound somewhere useful)
local function hearthAvailable()
    if not hearthMapID() then return false end
    -- Check actual item cooldown: C_Container.GetItemCooldown preferred in retail 12.0+
    -- fallback to global GetItemCooldown for safety
    local startTime, duration, enable
    if C_Container and C_Container.GetItemCooldown then
        startTime, duration, enable = C_Container.GetItemCooldown(6948)
    else
        startTime, duration, enable = GetItemCooldown(6948)
    end
    if not startTime then return true end  -- API unavailable, assume ready
    -- On cooldown if duration > 0 and cooldown hasn't expired yet
    if duration and duration > 0 then
        local remaining = (startTime + duration) - GetTime()
        if remaining > 2 then return false end  -- 2s buffer for GCD
    end
    return true
end

-- ============================================================
-- TRAVEL TOOL COST HELPERS
-- Uses RS.TravelTools registry for cooldown checks (12.0 API).
-- ============================================================

-- Returns true if the player owns the Arcantina Key.
local function arcantinaOwned()
    if C_ToyBox and C_ToyBox.HasToy then
        local ok, has = pcall(C_ToyBox.HasToy, 253629)
        if ok and has then return true end
    end
    if IsQuestFlaggedCompleted then
        local ok, done = pcall(IsQuestFlaggedCompleted, 86903)
        if ok and done then return true end
    end
    return RS_Settings and RS_Settings.hasArcantinaKey or false
end

-- Returns true if the key is owned and not on cooldown.
local function arcantinaAvailable()
    if not arcantinaOwned() then return false end
    if RS.TravelTools then
        return RS.TravelTools:GetSpellCDRemaining(1255801) <= 2
    end
    return true  -- can't check CD, assume ready
end

-- Returns remaining cooldown seconds on the Arcantina Key (0 if ready/unowned).
function RS.Flight:ArcantinaCDRemaining()
    if not arcantinaOwned() then return 0 end
    if RS.TravelTools then
        return math.ceil(RS.TravelTools:GetSpellCDRemaining(1255801))
    end
    return 0
end

-- Cost (seconds) to reach hub via Arcantina Key from any zone.
local function arcantinaCost(fromMapID)
    if not arcantinaAvailable() then return nil end
    if fromMapID == getHubMapID() then return nil end
    return OVERHEAD.ARCANTINA_CAST + OVERHEAD.PORTAL_LOAD + OVERHEAD.ARCANTINA_TO_SM + OVERHEAD.PORTAL_LOAD
end

-- Cost (seconds) to reach toMapID using any available travel tool.
-- Checks class teleports (Mage → Silvermoon), Arcantina Key, hearthstone, etc.
-- Returns the cheapest option, or nil if no tool helps.
local function travelToolCost(fromMapID, toMapID)
    if not RS.TravelTools then return nil end
    local hubID = getHubMapID()

    -- 1. Direct teleport to destination (e.g. Mage Teleport: Silvermoon)
    local directTool, directCost = RS.TravelTools:GetBestToolTo(toMapID)
    if directTool then
        return directTool.castTime + OVERHEAD.PORTAL_LOAD
    end

    -- 2. Direct teleport to hub (then portal to destination)
    local hubTool, hubCost = RS.TravelTools:GetBestToolTo(hubID)
    local portalZones = RS.Expansion:GetPortalZones()
    if hubTool and portalZones[toMapID] then
        return hubTool.castTime + OVERHEAD.PORTAL_LOAD + OVERHEAD.PORTAL_WALK + OVERHEAD.PORTAL_LOAD
    end

    -- 3. Arcantina Key → hub (from portal zones)
    local ac = arcantinaCost(fromMapID)
    if ac and (toMapID == hubID or portalZones[toMapID]) then
        if toMapID == hubID then return ac end
        return ac + OVERHEAD.PORTAL_WALK + OVERHEAD.PORTAL_LOAD
    end

    -- 4. Hearthstone
    if not hearthAvailable() then return nil end
    local dest = hearthMapID()
    if not dest then return nil end
    if fromMapID == dest then return nil end
    if dest == toMapID then
        return OVERHEAD.HEARTH_CAST + OVERHEAD.PORTAL_LOAD
    end
    if dest == hubID and portalZones[toMapID] then
        return OVERHEAD.HEARTH_CAST + OVERHEAD.PORTAL_LOAD + OVERHEAD.PORTAL_WALK + OVERHEAD.PORTAL_LOAD
    end

    -- 5. Shaman Astral Recall (second hearthstone)
    local bestHearth, bestCD = RS.TravelTools:GetBestHearth()
    if bestHearth and bestCD <= 2 and bestHearth.spellID ~= 8690 then
        -- Astral Recall or similar — same destination as hearthstone
        if dest == toMapID then
            return bestHearth.castTime + OVERHEAD.PORTAL_LOAD
        end
        if dest == hubID and portalZones[toMapID] then
            return bestHearth.castTime + OVERHEAD.PORTAL_LOAD + OVERHEAD.PORTAL_WALK + OVERHEAD.PORTAL_LOAD
        end
    end

    return nil
end

-- ============================================================
-- EUCLIDEAN DISTANCE between two normalised (0-1) map coords
-- Returns distance in yards based on zone width estimate
-- ============================================================
function RS.Flight:GetDistanceYards(mapID, x1, y1, x2, y2)
    local width = RS.Expansion:GetZoneYardWidth(mapID)
    -- WoW map coords are roughly square; use width for both axes
    local dx = (x2 - x1) * width
    local dy = (y2 - y1) * width
    return math.sqrt(dx*dx + dy*dy)
end

-- ============================================================
-- INTRA-ZONE TRAVEL TIME (seconds)
-- Both points in the same zone, straight-line aerial path
-- ============================================================
function RS.Flight:IntraZoneSeconds(mapID, x1, y1, x2, y2)
    local dist = self:GetDistanceYards(mapID, x1, y1, x2, y2)
    local speed, overhead

    -- Use detected flight mode if available, fall back to saved setting
    local mode = RS_Settings and RS_Settings.detectedFlightMode or
                 (RS_Settings and RS_Settings.useSkyriding and "skyriding" or "static")
    local isSkyriding = (mode == "skyriding")

    if isSkyriding then
        if dist < 500 then
            speed = SPEED.SKYRIDING_SHORT
        elseif dist < 1500 then
            speed = SPEED.SKYRIDING_MEDIUM
        else
            speed = SPEED.SKYRIDING_LONG
        end
    else
        speed = SPEED.STATIC_FLIGHT
    end

    overhead = OVERHEAD.MOUNT_UP + OVERHEAD.DISMOUNT_WALK
    return math.ceil((dist / speed) + overhead)
end

-- ============================================================
-- INTER-ZONE TRAVEL TIME (seconds)
-- Crosses zone boundaries. Handles the portal zone penalty for
-- Harandar and Voidstorm which require a stop in Silvermoon.
-- ============================================================
-- ============================================================
-- INTER-ZONE TRAVEL TIME (seconds)
-- Crosses zone boundaries. Accounts for:
--   • Direct portals (Harandar↔Voidstorm at The Den / Citadel)
--   • Two-hop via Silvermoon for non-adjacent zones
--   • Hearthstone: if set to Silvermoon, replaces the "reach Silvermoon" leg
--   • Arcantina Key: instant return to Silvermoon from Harandar/Voidstorm
-- ============================================================
function RS.Flight:InterZoneSeconds(fromMapID, fromX, fromY, toMapID, toX, toY)
    if fromMapID == toMapID then
        return self:IntraZoneSeconds(fromMapID, fromX, fromY, toX, toY)
    end

    -- Check travel tools first (Mage teleports, Arcantina Key, hearthstone, etc.)
    -- If a tool can get us there cheaper than flying, use it.
    local toolCost = travelToolCost(fromMapID, toMapID)

    local isSkyriding = RS_Settings and (
        RS_Settings.detectedFlightMode == "skyriding" or
        (not RS_Settings.detectedFlightMode and RS_Settings.useSkyriding)
    )
    local speedMult = isSkyriding and 1.0 or 1.6

    local conn = RS.Zones.CONNECTIVITY and RS.Zones.CONNECTIVITY[fromMapID]
    if not conn then
        -- No connectivity data — return tool cost if available, else fallback
        return toolCost or 600
    end

    -- Find direct connection
    local directLink = nil
    for _, neighbor in ipairs(conn.neighbors) do
        if neighbor.mapID == toMapID then
            directLink = neighbor
            break
        end
    end

    if directLink then
        local baseSecs = directLink.baseTravelMin * 60
        if directLink.portalRequired then
            baseSecs = baseSecs + OVERHEAD.PORTAL_LOAD + OVERHEAD.PORTAL_WALK
        else
            baseSecs = baseSecs * speedMult
        end
        -- Use travel tool if cheaper than the direct route
        if toolCost and toolCost < baseSecs then
            return math.ceil(toolCost)
        end
        return math.ceil(baseSecs)
    end

    -- No direct link — two-hop via hub.
    -- But first: if travelToolCost already found a route, it's likely optimal.
    if toolCost then
        return math.ceil(toolCost)
    end

    local hubID = getHubMapID()
    if fromMapID == hubID or toMapID == hubID then
        return 600
    end

    -- Leg 1: fromZone -> hub (fly or portal)
    local leg1Secs = 600
    local connFrom = RS.Zones.CONNECTIVITY and RS.Zones.CONNECTIVITY[fromMapID]
    if connFrom then
        for _, nb in ipairs(connFrom.neighbors) do
            if nb.mapID == hubID then
                leg1Secs = nb.baseTravelMin * 60
                if nb.portalRequired then
                    leg1Secs = leg1Secs + OVERHEAD.PORTAL_LOAD + OVERHEAD.PORTAL_WALK
                else
                    leg1Secs = leg1Secs * speedMult
                end
                break
            end
        end
    end

    -- Leg 2: hub -> toZone
    local leg2Secs = 600
    local connHub = RS.Zones.CONNECTIVITY and RS.Zones.CONNECTIVITY[hubID]
    if connHub then
        for _, nb in ipairs(connHub.neighbors) do
            if nb.mapID == toMapID then
                leg2Secs = nb.baseTravelMin * 60
                if nb.portalRequired then
                    leg2Secs = leg2Secs + OVERHEAD.PORTAL_LOAD + OVERHEAD.PORTAL_WALK
                else
                    leg2Secs = leg2Secs * speedMult
                end
                break
            end
        end
    end

    return math.ceil(leg1Secs + leg2Secs)
end

-- ============================================================
-- TOTAL TRAVEL TIME between two activities (seconds)
-- Activities can be in the same zone or different zones
-- ============================================================
function RS.Flight:TravelTimeBetween(actA, actB)
    -- Guard against missing coordinate data
    if not actA.mapID or not actA.x or not actA.y then return 600 end
    if not actB.mapID or not actB.x or not actB.y then return 600 end

    if actA.mapID == actB.mapID then
        return self:IntraZoneSeconds(actA.mapID, actA.x, actA.y, actB.x, actB.y)
    else
        return self:InterZoneSeconds(actA.mapID, actA.x, actA.y, actB.mapID, actB.x, actB.y)
    end
end

-- ============================================================
-- HUMAN-READABLE TIME STRING
-- ============================================================
function RS.Flight:FormatTime(seconds)
    if seconds < 60 then
        return seconds .. "s"
    elseif seconds < 3600 then
        local m = math.floor(seconds / 60)
        local s = seconds % 60
        if s == 0 then return m .. "m" end
        return m .. "m " .. s .. "s"
    else
        local h = math.floor(seconds / 3600)
        local m = math.floor((seconds % 3600) / 60)
        return h .. "h " .. m .. "m"
    end
end

-- Compact format for tight UI columns: "1h24m" instead of "1h 24m", "24m" not "24m 0s"
function RS.Flight:FormatTimeCompact(seconds)
    if seconds < 60 then
        return seconds .. "s"
    elseif seconds < 3600 then
        return math.floor(seconds / 60) .. "m"
    else
        local h = math.floor(seconds / 3600)
        local m = math.floor((seconds % 3600) / 60)
        if m == 0 then return h .. "h" end
        return h .. "h" .. m .. "m"
    end
end
