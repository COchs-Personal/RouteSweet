-- Core/Waypoint.lua
-- Live waypoint chain manager for RouteSweet
--
-- BEHAVIOUR:
--   • Sets a native Blizzard map pin + supertracking arrow for the current stop
--   • Listens for QUEST_TURNED_IN — if the completed quest matches the current
--     stop's questID, immediately advances to the next stop
--   • Proximity ticker (every 2s) checks distance to current pin; if the player
--     is within ARRIVE_YARDS and the stop has no questID (event/housing/etc.),
--     advances automatically after a short dwell to avoid false triggers
--   • If neither fires (e.g. player manually skips), right-click on a row still
--     calls RS.Waypoint:Complete() to advance
--   • Pin persists on the map until the stop is completed or skipped — it does
--     not disappear just because the player walks nearby for a quest stop
--   • Calling :Start() on a new route resets all state cleanly

RS.Waypoint = RS.Waypoint or {}

local WP = RS.Waypoint

-- ── Config ────────────────────────────────────────────────────
local ARRIVE_YARDS      = 40      -- proximity threshold for non-quest stops
local DWELL_SECS        = 4       -- must remain close for this long before auto-advance
local POLL_INTERVAL     = 2       -- proximity check frequency (seconds)
local YARDS_PER_COORD   = 1333    -- approximate yards per 0-1 UiMap coordinate unit
                                  -- (varies by zone size; good enough for proximity)
-- ── State ─────────────────────────────────────────────────────
WP._route       = nil   -- current ordered list of activity stops
WP._index       = 1     -- which stop we're navigating to
WP._ticker      = nil   -- C_Timer ticker for proximity polling
WP._dwellStart  = nil   -- GetTime() when player first entered arrive radius
WP._active      = false

-- ── Internal: clear the native Blizzard waypoint ────────────────
-- Defined BEFORE setNativePin because Lua local functions must exist before use.
local function clearNativePin()
    pcall(function()
        C_Map.ClearUserWaypoint()
        C_SuperTrack.SetSuperTrackedUserWaypoint(false)
    end)
end

-- ── Internal: set the native Blizzard waypoint ────────────────
local function setNativePin(activity)
    if not activity then return end
    if not C_Map.SetUserWaypoint then return end

    local mapID = activity.mapID
    local x     = activity.x
    local y     = activity.y
    if not mapID or not x or not y then return end

    -- MUST clear before setting — SetUserWaypoint does not update if a pin
    -- already exists on the same map. The supertrack arrow stays locked on
    -- the old coordinates without this clear step.
    clearNativePin()

    local ok, err = pcall(function()
        local pt = UiMapPoint.CreateFromCoordinates(mapID, x, y, 0)
        C_Map.SetUserWaypoint(pt)
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end)
    if not ok then
        pcall(function()
            local pt = CreateVector2D(x, y)
            C_Map.SetUserWaypoint({ mapID = mapID, position = pt })
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end)
    end
end

-- ── Internal: distance from player to coords (yards, same map) ─
local function distanceToStop(activity)
    if not activity then return math.huge end
    local mapID = activity.mapID
    if not mapID then return math.huge end

    local playerPos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not playerPos then return math.huge end

    local dx = (playerPos.x - activity.x) * YARDS_PER_COORD
    local dy = (playerPos.y - activity.y) * YARDS_PER_COORD
    return math.sqrt(dx * dx + dy * dy)
end

-- ── Internal: announce current stop in chat ───────────────────
local function announce(index, activity)
    if not activity then return end
    print(string.format(
        "|cffC8A96ERouteSweet|r → Stop %d: |cffFFFFFF%s|r  |cffaaaaaa(%s)|r",
        index,
        activity.name or "?",
        RS.Zones and RS.Zones.GetZoneName and
            RS.Zones:GetZoneName(activity.mapID) or "?"
    ))
end

-- ── Internal: highlight the active row in the UI ─────────────
local function highlightActiveRow(index)
    if not RS.UI or not RS.UI.rowFrames then return end
    RS.UI:HighlightActiveRow(index)
end

-- ── Internal: advance to the next stop ───────────────────────
local function advanceTo(index)
    -- ── Record elapsed time for the stop we just finished ────
    local prevStop = WP._route and WP._route[WP._index]
    if prevStop and WP._stopStartedAt and RS.Timing then
        local elapsed = math.floor(GetTime() - WP._stopStartedAt)
        local prevAct = prevStop.activity or prevStop
        RS.Timing:Record(prevAct, elapsed)
    end

    WP._index      = index
    WP._dwellStart = nil
    WP._stopStartedAt = GetTime()   -- timestamp when this stop begins

    local stop = WP._route and WP._route[index]
    if not stop then
        -- Route complete
        clearNativePin()
        WP._active = false
        if WP._ticker then WP._ticker:Cancel(); WP._ticker = nil end
        print("|cffC8A96ERouteSweet:|r |cff00ff00Route complete! All stops done.|r")
        highlightActiveRow(nil)
        return
    end

    local act = stop.activity or stop
    setNativePin(act)
    announce(index, act)
    highlightActiveRow(index)
end

-- ── Internal: proximity ticker callback ──────────────────────
local function onProximityTick()
    if not WP._active or not WP._route then return end

    local stop = WP._route[WP._index]
    if not stop then return end
    local act = stop.activity or stop

    -- Portal waypoint stops: advance immediately on proximity (no dwell)
    -- or when player has changed zones (detected via ZONE_CHANGED_NEW_AREA)
    if stop.isPortalWaypoint or (act.isPortalWaypoint) then
        local dist = distanceToStop(act)
        if dist <= ARRIVE_YARDS then
            advanceTo(WP._index + 1)
            return
        end
        -- Also check if player is already in the destination zone
        -- (they took the portal and loaded in)
        local nextStop = WP._route[WP._index + 1]
        if nextStop then
            local nextAct = nextStop.activity or nextStop
            local playerMapID = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
            if playerMapID and nextAct.mapID and playerMapID == nextAct.mapID then
                advanceTo(WP._index + 1)
                return
            end
        end
        return
    end

    -- Quest stops: DON'T auto-advance on proximity — wait for QUEST_TURNED_IN
    -- Only auto-advance on proximity for non-quest stops (events, housing, etc.)
    if act.questID then return end

    local dist = distanceToStop(act)
    if dist <= ARRIVE_YARDS then
        if not WP._dwellStart then
            WP._dwellStart = GetTime()
        elseif (GetTime() - WP._dwellStart) >= DWELL_SECS then
            -- Player has been here long enough — treat as visited
            advanceTo(WP._index + 1)
        end
    else
        WP._dwellStart = nil
    end
end

-- ── Internal: event frame ─────────────────────────────────────
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("QUEST_TURNED_IN")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
-- WORLD_MAP_UPDATE fires when the map display refreshes (zone transitions, open/close)
-- Use pcall so an unknown event doesn't abort the file
pcall(function() eventFrame:RegisterEvent("WORLD_MAP_UPDATE") end)

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "WORLD_MAP_UPDATE" then
        -- Map refreshed — re-set pin in case Blizzard cleared it
        if WP._active and WP._route then
            local stop = WP._route[WP._index]
            if stop then
                local act = stop.activity or stop
                C_Timer.After(0.15, function()
                    if WP._active then setNativePin(act) end
                end)
            end
        end
        return
    end

    if not WP._active or not WP._route then return end

    local stop = WP._route[WP._index]
    if not stop then return end
    local act = stop.activity or stop

    -- Zone change: if current stop is a portal waypoint and we've arrived
    -- in the next stop's zone, auto-advance past the portal stop.
    if event == "ZONE_CHANGED_NEW_AREA" then
        if stop.isPortalWaypoint or (act.isPortalWaypoint) then
            local nextStop = WP._route[WP._index + 1]
            if nextStop then
                local nextAct = nextStop.activity or nextStop
                local playerMapID = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
                if playerMapID and nextAct.mapID and playerMapID == nextAct.mapID then
                    advanceTo(WP._index + 1)
                end
            end
        end
        return
    end

    if event == "QUEST_TURNED_IN" then
        local questID = ...
        if act.questID and act.questID == questID then
            advanceTo(WP._index + 1)
            return
        end
        if act.questIDs then
            for _, qid in ipairs(act.questIDs) do
                if qid == questID then
                    advanceTo(WP._index + 1)
                    return
                end
            end
        end

    elseif event == "QUEST_LOG_UPDATE" then
        if act.questID then
            local ok, completed = pcall(C_QuestLog.IsQuestFlaggedCompleted, act.questID)
            if ok and completed then
                local isStillSameStop = WP._route[WP._index] == stop
                if isStillSameStop then
                    advanceTo(WP._index + 1)
                end
            end
        end
    end
end)

-- ============================================================
-- PUBLIC API
-- ============================================================

-- Start a new waypoint chain from a route
-- route: table of stops (each with .activity or direct activity fields)
-- startIndex: which stop to begin at (default 1)
function WP:Start(route, startIndex)
    -- Clean up any existing chain
    self:Stop()

    if not route or #route == 0 then
        print("|cffC8A96ERouteSweet:|r No route to navigate.")
        return
    end

    self._route  = route
    self._index  = startIndex or 1
    self._active = true
    self._stopStartedAt = GetTime()

    -- Start proximity ticker
    self._ticker = C_Timer.NewTicker(POLL_INTERVAL, onProximityTick)

    -- Set first pin
    advanceTo(self._index)
end

-- Manually complete/skip the current stop and advance
function WP:Complete()
    if not self._active then return end
    advanceTo(self._index + 1)
end

-- Skip to a specific stop by index (e.g. player left-clicks a later row)
function WP:JumpTo(index)
    if not self._route then return end
    if index < 1 or index > #self._route then return end
    self._active = true
    if not self._ticker then
        self._ticker = C_Timer.NewTicker(POLL_INTERVAL, onProximityTick)
    end
    advanceTo(index)
end

-- Stop navigation entirely and clear the pin
function WP:Stop()
    self._active      = false
    self._route       = nil
    self._index       = 1
    self._dwellStart  = nil
    self._stopStartedAt = nil
    if self._ticker then
        self._ticker:Cancel()
        self._ticker = nil
    end
    clearNativePin()
    highlightActiveRow(nil)
end

-- Returns the current active stop index and activity
function WP:GetCurrent()
    if not self._active or not self._route then return nil, nil end
    local stop = self._route[self._index]
    if not stop then return self._index, nil end
    return self._index, stop.activity or stop
end

-- Returns true if a waypoint chain is currently running
function WP:IsActive()
    return self._active == true
end

-- Returns the 0-1 progress fraction through the route
function WP:GetProgress()
    if not self._route or #self._route == 0 then return 0 end
    return (self._index - 1) / #self._route
end
