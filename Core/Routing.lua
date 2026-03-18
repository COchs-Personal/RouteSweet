-- Core/Routing.lua
-- Shortest-path route builder using:
--   1. Nearest-Neighbour greedy construction (fast, good first solution)
--   2. 2-opt improvement passes (removes crossing paths)
--   3. Expiry-aware re-ordering (urgent quests pulled forward)
--   4. Portal zone batching (cluster Harandar/Voidstorm visits)
--
-- TSP is NP-hard but with < 20 nodes greedy+2opt gives near-optimal results

RS.Router = RS.Router or {}

-- ============================================================
-- COST MATRIX
-- Pre-compute travel time (seconds) between every pair of activities
-- ============================================================
function RS.Router:BuildCostMatrix(activities)
    local n = #activities
    local matrix = {}
    for i = 1, n do
        matrix[i] = {}
        for j = 1, n do
            if i == j then
                matrix[i][j] = 0
            else
                matrix[i][j] = RS.Flight:TravelTimeBetween(activities[i], activities[j])
            end
        end
    end
    return matrix
end

-- ============================================================
-- NEAREST-NEIGHBOUR GREEDY TOUR
-- Start at player's current location, always go to closest next node.
-- effective_cost(i→j) = travelTime(i,j) - scoreBias(j)
--
-- scoreBias is ZONE-AWARE:
--   Cross-zone candidates: full bias (SCORE_SECS_PER_POINT = 8)
--     → score 10 = 80s credit, bends cross-zone routing toward high-value stops
--   Same-zone candidates:  reduced bias (SCORE_SECS_PER_POINT_INTRA = 3)
--     → score 10 = 30s credit, barely nudges within-zone ordering
--
-- Why: within a zone, stops are close together (10–60s apart). A full 80s credit
-- would cause the greedy pass to skip a 22s WQ in favour of a 60s weekly even
-- when the WQ is directly on the path. With a 3s/pt intra-zone bias, the weekly
-- only wins if it's within 30s extra travel — tight enough that 2-opt will clean
-- it up anyway. Cross-zone bias stays high so we cluster portal zones correctly.
--
-- isExpiringSoon always uses full bias regardless of zone (loss is imminent).
-- ============================================================
local SCORE_SECS_PER_POINT       = 8   -- cross-zone: full bias
local SCORE_SECS_PER_POINT_INTRA = 3   -- same-zone:  light bias

function RS.Router:NearestNeighbour(activities, costMatrix, startIndex)
    local n = #activities
    if n == 0 then return {} end

    startIndex = startIndex or 1
    local visited = {}
    local tour = {}
    local current = startIndex

    visited[current] = true
    table.insert(tour, current)

    for _ = 1, n - 1 do
        local bestCost = math.huge
        local bestNext = nil
        local currentMapID = activities[current] and activities[current].mapID

        for j = 1, n do
            if not visited[j] then
                local travelCost = costMatrix[current][j]
                local actScore = activities[j].score or 0
                if activities[j].isExpiringSoon then
                    -- Expiring: always use full bias — loss is imminent regardless of zone
                    actScore = actScore + 20
                    local effectiveCost = travelCost - (actScore * SCORE_SECS_PER_POINT)
                    if effectiveCost < bestCost then
                        bestCost = effectiveCost
                        bestNext = j
                    end
                else
                    -- Normal: use zone-aware bias
                    local sameZone = (activities[j].mapID == currentMapID)
                    local pts = sameZone and SCORE_SECS_PER_POINT_INTRA or SCORE_SECS_PER_POINT
                    local effectiveCost = travelCost - (actScore * pts)
                    if effectiveCost < bestCost then
                        bestCost = effectiveCost
                        bestNext = j
                    end
                end
            end
        end

        if bestNext then
            visited[bestNext] = true
            table.insert(tour, bestNext)
            current = bestNext
        end
    end

    return tour
end

-- ============================================================
-- 2-OPT IMPROVEMENT
-- Iteratively reverses sub-segments to remove path crossings
-- Runs until no improvement found (or max iterations hit)
-- ============================================================
function RS.Router:TwoOpt(tour, costMatrix)
    local n = #tour
    if n < 4 then return tour end

    local improved = true
    local iterations = 0
    local maxIter = 50  -- safety cap

    while improved and iterations < maxIter do
        improved = false
        iterations = iterations + 1

        for i = 1, n - 2 do
            for j = i + 2, n do
                -- Cost of current edges: tour[i]->tour[i+1] and tour[j]->tour[j+1 (wrap)]
                local nextI = tour[i + 1]
                local nextJ = (j < n) and tour[j + 1] or tour[1]

                local currentCost = costMatrix[tour[i]][nextI]
                                  + costMatrix[tour[j]][nextJ]

                -- Cost if we reverse the segment between i+1 and j
                local newCost = costMatrix[tour[i]][tour[j]]
                              + costMatrix[nextI][nextJ]

                if newCost < currentCost - 0.01 then
                    -- Reverse segment from i+1 to j
                    local reversed = {}
                    for k = j, i + 1, -1 do
                        table.insert(reversed, tour[k])
                    end
                    local idx = 1
                    for k = i + 1, j do
                        tour[k] = reversed[idx]
                        idx = idx + 1
                    end
                    improved = true
                end
            end
        end
    end

    return tour
end

-- ============================================================
-- PORTAL ZONE BATCHING
-- Harandar and Voidstorm require portal transit through Silvermoon.
-- After 2-opt, we check if we can avoid repeated portal crossings
-- by grouping same-zone clusters together.
-- ============================================================
function RS.Router:BatchPortalZones(tour, activities)
    local portalZones = RS.Expansion:GetPortalZones()

    -- Count portal-zone stops
    local portalCount = 0
    for _, idx in ipairs(tour) do
        if portalZones[activities[idx].mapID] then
            portalCount = portalCount + 1
        end
    end
    if portalCount <= 1 then return tour end

    -- Group by portal zone dynamically
    local groups = {}      -- mapID -> list of tour positions
    local normalTour = {}

    for _, tourPos in ipairs(tour) do
        local act = activities[tourPos]
        if portalZones[act.mapID] then
            if not groups[act.mapID] then groups[act.mapID] = {} end
            table.insert(groups[act.mapID], tourPos)
        else
            table.insert(normalTour, tourPos)
        end
    end

    -- Rebuild: normal first, then each portal zone batch (sorted by mapID for determinism)
    local batched = {}
    for _, v in ipairs(normalTour) do table.insert(batched, v) end

    local sortedMapIDs = {}
    for mapID in pairs(groups) do table.insert(sortedMapIDs, mapID) end
    table.sort(sortedMapIDs)

    for _, mapID in ipairs(sortedMapIDs) do
        for _, v in ipairs(groups[mapID]) do table.insert(batched, v) end
    end

    return batched
end

-- ============================================================
-- MAIN ROUTE BUILDER
-- Orchestrates the full pipeline and returns a RouteResult table
-- ============================================================
function RS.Router:BuildRoute(activities, playerMapID, playerX, playerY)
    if not activities or #activities == 0 then
        return { stops = {}, totalTravelSecs = 0, totalActivitySecs = 0, totalSecs = 0 }
    end

    -- 1. Find starting index: activity closest to player's current position
    local startIndex = 1
    local bestStartDist = math.huge
    for i, act in ipairs(activities) do
        local dist
        if act.mapID == playerMapID then
            dist = RS.Flight:GetDistanceYards(playerMapID, playerX, playerY, act.x, act.y)
        else
            -- Cross-zone: rough estimate
            dist = RS.Flight:InterZoneSeconds(
                playerMapID, playerX, playerY,
                act.mapID, act.x, act.y
            )
        end
        if dist < bestStartDist then
            bestStartDist = dist
            startIndex = i
        end
    end

    -- 2. Build cost matrix
    local costMatrix = self:BuildCostMatrix(activities)

    -- 3. Nearest-neighbour greedy tour
    local tour = self:NearestNeighbour(activities, costMatrix, startIndex)

    -- 4. 2-opt improvement
    tour = self:TwoOpt(tour, costMatrix)

    -- 5. Portal zone batching
    tour = self:BatchPortalZones(tour, activities)

    -- 6. Build annotated stop list with cumulative time estimates
    local stops = {}
    local cumulativeSecs = 0
    local totalTravelSecs = 0
    local totalActivitySecs = 0

    for i, tourIdx in ipairs(tour) do
        local act = activities[tourIdx]
        local travelSecs = 0

        if i == 1 then
            -- Travel from player position to first stop
            if act.mapID == playerMapID then
                travelSecs = RS.Flight:IntraZoneSeconds(playerMapID, playerX, playerY, act.x, act.y)
            else
                travelSecs = RS.Flight:InterZoneSeconds(playerMapID, playerX, playerY, act.mapID, act.x, act.y)
            end
        else
            local prevAct = activities[tour[i - 1]]
            travelSecs = RS.Flight:TravelTimeBetween(prevAct, act)
        end

        -- Check for portal zone transitions — insert portal waypoint stop + note
        local portalNote = nil
        local portalWaypoint = nil  -- intermediate stop at the portal location
        if i > 1 then
            local prevAct = activities[tour[i - 1]]
            if prevAct.mapID ~= act.mapID then
                local fromID = prevAct.mapID
                local toID   = act.mapID

                -- Check for direct portal between these two zones
                local directPortal = false
                local conn = RS.Zones.CONNECTIVITY and RS.Zones.CONNECTIVITY[fromID]
                if conn then
                    for _, nb in ipairs(conn.neighbors) do
                        if nb.mapID == toID and nb.portalRequired then
                            directPortal = true
                            break
                        end
                    end
                end

                -- Look up the portal waypoint coordinates from the expansion data
                local portals = RS.Zones.PORTALS or {}
                -- Check if this zone transition requires ANY portal at all.
                -- Fly-through transitions (portalRequired = false) need no note.
                local requiresAnyPortal = directPortal
                if not requiresAnyPortal then
                    -- Check if the zones have no direct non-portal connection
                    -- (meaning we need to route via the hub)
                    local hasDirectFly = false
                    if conn then
                        for _, nb in ipairs(conn.neighbors) do
                            if nb.mapID == toID and not nb.portalRequired then
                                hasDirectFly = true
                                break
                            end
                        end
                    end
                    if not hasDirectFly and conn then
                        -- No direct fly path — needs portal routing via hub
                        requiresAnyPortal = true
                    end
                end

                if directPortal then
                    portalNote = "\226\134\146 Portal to " .. RS.Zones:GetZoneName(toID)

                    -- Find the matching portal waypoint for this transition
                    for _, pw in pairs(portals) do
                        if pw.mapID == fromID then
                            local label = pw.label or ""
                            local destName = RS.Zones:GetZoneName(toID)
                            if label:find(destName) or label:find(tostring(toID)) then
                                portalWaypoint = {
                                    id    = "portal_" .. fromID .. "_" .. toID,
                                    name  = pw.label or ("Portal to " .. destName),
                                    mapID = pw.mapID,
                                    x     = pw.x,
                                    y     = pw.y,
                                    type  = "PORTAL",
                                    duration = 0,
                                    isPortalWaypoint = true,
                                }
                                break
                            end
                        end
                    end
                elseif requiresAnyPortal then
                    -- Two-hop via hub — note any travel tools being used
                    local s = RS_Settings
                    local portalZones = RS.Expansion:GetPortalZones()
                    local useArcantina = s and s.hasArcantinaKey and not s.arcantinaOnCooldown
                        and portalZones[fromID]
                    local useHearth = s and s.hearthLocation == "silvermoon"
                        and not s.hearthOnCooldown
                        and portalZones[toID]

                    local destName = RS.Zones:GetZoneName(toID)
                    if useArcantina and useHearth then
                        portalNote = "\226\134\146 Arcantina Key + Hearth \226\134\146 " .. destName
                    elseif useArcantina then
                        portalNote = "\226\134\146 Arcantina Key \226\134\146 Silvermoon \226\134\146 " .. destName
                    elseif useHearth then
                        portalNote = "\226\134\146 Hearth \226\134\146 Silvermoon \226\134\146 " .. destName
                    else
                        portalNote = "\226\134\146 Portal via " .. RS.Zones:GetZoneName(RS.Expansion:GetHubMapID() or 2393)
                    end

                    -- Portal waypoint at the hub's portal to the destination
                    for _, pw in pairs(portals) do
                        if pw.mapID == (RS.Expansion:GetHubMapID() or 2393) then
                            local label = pw.label or ""
                            if label:find(destName) or label:find(tostring(toID)) then
                                portalWaypoint = {
                                    id    = "portal_hub_" .. toID,
                                    name  = pw.label or ("Portal to " .. destName),
                                    mapID = pw.mapID,
                                    x     = pw.x,
                                    y     = pw.y,
                                    type  = "PORTAL",
                                    duration = 0,
                                    isPortalWaypoint = true,
                                }
                                break
                            end
                        end
                    end
                end
            end
        end

        -- Insert portal waypoint as an intermediate stop before the destination
        if portalWaypoint then
            table.insert(stops, {
                index           = #stops + 1,
                activity        = portalWaypoint,
                travelSecs      = 0,  -- travel time is accounted for in the main stop
                activitySecs    = 0,
                arrivalSecs     = cumulativeSecs,
                departureSecs   = cumulativeSecs,
                portalNote      = portalNote,
                isPortalWaypoint = true,
            })
        end

        cumulativeSecs = cumulativeSecs + travelSecs
        totalTravelSecs = totalTravelSecs + travelSecs

        local activitySecs = RS.Timing and RS.Timing:GetDuration(act)
                          or act.duration
                          or ((RS_Settings and RS_Settings.questTime or 7) * 60)
        totalActivitySecs = totalActivitySecs + activitySecs

        table.insert(stops, {
            index           = i,
            activity        = act,
            travelSecs      = travelSecs,
            activitySecs    = activitySecs,
            arrivalSecs     = cumulativeSecs,
            departureSecs   = cumulativeSecs + activitySecs,
            portalNote      = portalNote,
            isUrgent        = act.isExpiringSoon,
        })

        cumulativeSecs = cumulativeSecs + activitySecs
    end

    return {
        stops             = stops,
        totalTravelSecs   = totalTravelSecs,
        totalActivitySecs = totalActivitySecs,
        totalSecs         = totalTravelSecs + totalActivitySecs,
    }
end

-- Store route result on RS for UI access
function RS:BuildRoute()
    local activities = RS.activeActivities or RS.Scanner:GetActiveActivities()
    if not activities or #activities == 0 then
        RS.currentRoute = nil
        return
    end

    -- Get player position
    local playerMapID = C_Map.GetBestMapForUnit("player") or RS.Expansion:GetHubMapID() or 2393
    local playerPos = C_Map.GetPlayerMapPosition(playerMapID, "player")
    local pX = playerPos and playerPos.x or 0.5
    local pY = playerPos and playerPos.y or 0.5

    RS.currentRoute = RS.Router:BuildRoute(activities, playerMapID, pX, pY)
    return RS.currentRoute
end
