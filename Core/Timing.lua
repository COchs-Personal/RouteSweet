-- Core/Timing.lua
-- Personal activity timing — tracks how long each player actually spends
-- on each stop and feeds running averages back into route time estimates.
--
-- KEY DESIGN NOTE — World Quest ID stability:
--   In Retail WoW (including Midnight), every world quest has a single stable
--   numeric questID that identifies THAT quest definition. "Fortify the Runestones:
--   Magisters" is always questID 90XXX — the same number every week it appears.
--   IDs do not change or get reassigned to different quests. The rotation just
--   controls which quests are active on the map at any given time.
--
--   This means personal timing keyed by questID accumulates meaningfully across
--   weeks: by the 5th time you see "Twilight's Bane" you'll have a solid average
--   for that specific quest's objectives, regardless of how many weeks passed.
--   There is NO reason to clear WQ timing on weekly reset.
--
-- Storage layout in RS_CharData:
--   .activityTimes[key] = { n=count, total=totalSecs, last=lastSecs }
--
--   One unified table. Key derivation:
--     • World quests:     numeric questID  (e.g. 90234)
--       → stable per quest definition, accumulates cross-week
--     • Static activities: string activity id (e.g. "soiree_grounds")
--       → stable string set at activity definition time
--
--   Nothing is cleared on weekly reset. Data only grows (or is manually wiped
--   via /rs resettime). The running average self-corrects as samples accumulate.
--
-- Category defaults (seconds) — used until personal data exists.
-- ============================================================

RS.Timing = RS.Timing or {}

local T = RS.Timing

-- ── Category defaults ────────────────────────────────────────
-- Deliberately slightly generous so the total doesn't under-promise.
local CATEGORY_DEFAULT_SECS = {
    WORLD_QUEST    = 5  * 60,   -- 5m: typical outdoor objective quest
    WEEKLY         = 12 * 60,   -- 12m: e.g. Legends collect + turn-in
    WEEKLY_EVENT   = 20 * 60,   -- 20m: e.g. Soiree, Stormarion assault
    DUNGEON        = 25 * 60,   -- 25m: single dungeon run
    DELVE          = 8  * 60,   -- 8m:  solo delve
    ROTATING_EVENT = 6  * 60,   -- 6m:  Abundance cave clear
    HOUSING        = 3  * 60,   -- 3m:  housing chore
    BATTLEGROUND   = 15 * 60,   -- 15m: average BG
}

-- ── Internal helpers ─────────────────────────────────────────

local function ensureTable()
    if not RS_CharData then return false end
    if not RS_CharData.activityTimes then RS_CharData.activityTimes = {} end
    return true
end

-- Derives the stable storage key for an activity.
-- World quests → numeric questID (same ID = same quest, every week).
-- Static activities → string activity.id.
-- Returns nil if neither is available (unmeasurable activity).
local function storageKey(activity)
    if activity.type == "WORLD_QUEST" and activity.questID then
        return activity.questID   -- numeric; same quest reappears with same ID
    end
    if activity.id then
        return activity.id        -- string; static named activity
    end
    return nil
end

local function getRecord(activity)
    if not ensureTable() then return nil end
    local key = storageKey(activity)
    if not key then return nil end
    return RS_CharData.activityTimes[key]
end

local function putRecord(activity, elapsed)
    if not ensureTable() then return end
    local key = storageKey(activity)
    if not key then return end
    local rec = RS_CharData.activityTimes[key]
    if rec then
        rec.n     = rec.n + 1
        rec.total = rec.total + elapsed
        rec.last  = elapsed
    else
        RS_CharData.activityTimes[key] = { n = 1, total = elapsed, last = elapsed }
    end
end

-- ── Public API ───────────────────────────────────────────────

-- Returns estimated duration in seconds.
-- Priority: personal running average → category default → questTime setting.
function T:GetDuration(activity)
    local rec = getRecord(activity)
    if rec and rec.n > 0 then
        return math.ceil(rec.total / rec.n)
    end
    local cat = CATEGORY_DEFAULT_SECS[activity.type]
    if cat then return cat end
    local qt = RS_Settings and RS_Settings.questTime or 7
    return qt * 60
end

-- Returns personal average seconds, or nil if no data yet.
function T:GetPersonalAvg(activity)
    local rec = getRecord(activity)
    if not rec or rec.n == 0 then return nil end
    return math.ceil(rec.total / rec.n)
end

-- Returns { avg, count, last } or nil.
function T:GetStats(activity)
    local rec = getRecord(activity)
    if not rec or rec.n == 0 then return nil end
    return {
        avg   = math.ceil(rec.total / rec.n),
        count = rec.n,
        last  = rec.last,
    }
end

-- Record elapsed time for a completed stop.
-- Called by Waypoint when a stop advances (quest turned in, proximity dwell,
-- or manual right-click mark-done).
-- Outlier clamping: ignore < 15s (accidental click) and > 90m (AFK/DC).
local MIN_ELAPSED = 15
local MAX_ELAPSED = 90 * 60

function T:Record(activity, elapsed)
    if not activity then return end
    if elapsed < MIN_ELAPSED or elapsed > MAX_ELAPSED then return end
    putRecord(activity, elapsed)
end

-- Reset timing data for a single activity (e.g. if an outlier run skewed the avg).
-- Exposed via /rs resettime <activityName or questID>.
function T:ResetOne(key)
    if not ensureTable() then return end
    RS_CharData.activityTimes[key] = nil
end

-- Reset ALL timing data. Destructive — used by /rs resettime all.
function T:ResetAll()
    if RS_CharData then
        RS_CharData.activityTimes = {}
    end
end

-- Returns a human-readable tooltip line.
-- e.g. "Your avg: 6m 30s  (4 runs, last: 7m)"
-- Returns nil if no personal data.
function T:TooltipLine(activity)
    local stats = self:GetStats(activity)
    if not stats then return nil end
    return string.format(
        "Your avg: %s  (%d %s, last: %s)",
        RS.Flight:FormatTime(stats.avg),
        stats.count,
        stats.count == 1 and "run" or "runs",
        RS.Flight:FormatTime(stats.last)
    )
end
