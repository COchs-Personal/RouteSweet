-- Core/QuestScanner.lua
-- Reads live world quest data, weekly completion state, and timed event status
-- Uses only out-of-combat APIs safe in Midnight 12.0.1:
--   C_TaskQuest, C_QuestLog, C_Reputation, C_WeeklyRewards, GetTime()
--
-- NOTE: Quest reward values may return "secret values" in 12.0 when in combat.
-- All scanning is done out-of-combat, but we wrap reward reads in pcall to be safe.

RS.Scanner = RS.Scanner or {}

-- Reward weight score by list position (pos 1 = 10, pos 2 = 8, etc., min 1)
local function rewardWeightForPosition(pos)
    return math.max(1, 12 - (pos * 2))
end

-- Build a reward->score map from the active profile's rewardOrder
local function buildRewardWeights()
    local profile = RS:GetActiveProfile()
    local weights = {}
    for i, entry in ipairs(profile.rewardOrder) do
        if entry.enabled then
            weights[entry.id] = rewardWeightForPosition(i)
        else
            weights[entry.id] = 0
        end
    end
    -- Fallback weights for any reward type not explicitly in the profile
    local fallbacks = {
        gear=10, rep=8, cache=9, gold=5, mounts=7,
        cosmetics=4, housing=4, professions=3,
    }
    return setmetatable(weights, { __index = fallbacks })
end

-- Build a set of enabled activity type IDs from the active profile
local function buildEnabledActivityTypes()
    local profile = RS:GetActiveProfile()
    local enabled = {}
    for _, entry in ipairs(profile.activityOrder) do
        if entry.enabled then
            enabled[entry.id] = true
        end
    end
    return enabled
end

-- Score bonus by activity type list position (pos 1 = +10, pos 2 = +8, etc.)
local function activityPositionBonus(activityType)
    local profile = RS:GetActiveProfile()
    for i, entry in ipairs(profile.activityOrder) do
        if entry.id == activityType and entry.enabled then
            return math.max(0, 12 - (i * 2))
        end
    end
    return 0
end

-- Time thresholds
local EXPIRY_URGENT_SECS  = 4 * 3600   -- < 4 hours: boost priority
local EXPIRY_SKIP_SECS    = 20 * 60    -- < 20 min: probably not worth it
local ABUNDANCE_CYCLE     = 8 * 3600   -- 8-hour rotation

-- Weekly reset urgency tiers (seconds until reset):
-- These control how aggressively weeklies override nearby WQs.
-- SCORE_SECS_PER_POINT = 8, so a bonus of +20 = 160s detour tolerance.
local RESET_URGENT_SECS   = 4  * 3600  -- < 4h:  critical, clear weeklies ASAP
local RESET_WARNING_SECS  = 24 * 3600  -- < 24h: day-before, start prioritising
local RESET_NORMAL_SECS   = 48 * 3600  -- < 48h: mild nudge

-- Returns seconds until next weekly reset, or nil if API unavailable.
local function secsUntilReset()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        return C_DateAndTime.GetSecondsUntilWeeklyReset()
    end
    return nil
end

-- ============================================================
-- WORLD QUEST SCANNING
-- Returns a list of activity nodes ready for the router
-- ============================================================
function RS.Scanner:GetActiveActivities()
    local activities = {}
    local enabled = buildEnabledActivityTypes()

    -- 1. WORLD QUESTS via C_TaskQuest
    if enabled["WORLD_QUEST"] then
        local wqActivities = self:ScanWorldQuests()
        for _, a in ipairs(wqActivities) do table.insert(activities, a) end
    end

    -- 2. STATIC ACTIVITIES from all active expansions (weeklies, rotating events, etc.)
    local staticActivities = self:ScanStaticActivities()
    for _, a in ipairs(staticActivities) do
        if enabled[a.type] then
            table.insert(activities, a)
        end
    end

    -- 3. DYNAMIC ACTIVITIES from all active expansions (Soiree, Dungeons, Housing,
    --    and Leveling quests). Leveling nodes use types not in the profile's
    --    activityOrder (CAMPAIGN, QUESTLINE, etc.) — include them unconditionally.
    local dynamicNodes = RS.Expansion:BuildDynamicActivities(enabled)
    for _, node in ipairs(dynamicNodes) do
        -- Include if: type is in the enabled profile types, OR it's a leveling
        -- type that doesn't exist in the profile system (campaign/questline/etc.)
        if enabled[node.type] or not RS.Scanner:IsProfileType(node.type) then
            table.insert(activities, node)
        end
    end

    -- 4. ROTATING EVENTS (Abundance caves — generic, reads from expansion static activities)
    if enabled["ROTATING_EVENT"] then
        local abundanceActivity = self:GetActiveAbundanceCave()
        if abundanceActivity then table.insert(activities, abundanceActivity) end
    end

    -- Score and sort
    -- Leveling activities arrive with pre-computed .score from XP-based scoring.
    -- Max-level activities get scored here via ScoreActivity().
    for _, a in ipairs(activities) do
        if not a.score then
            a.score = self:ScoreActivity(a)
        end
    end
    table.sort(activities, function(a, b) return (a.score or 0) > (b.score or 0) end)

    RS.activeActivities = activities
    return activities
end

-- ============================================================
-- WORLD QUEST SCANNER
-- ============================================================
function RS.Scanner:ScanWorldQuests()
    local results = {}
    local now = GetServerTime()

    -- Scan all zones from active expansions
    local zoneMapIDs = RS.Expansion:GetAllScanZoneIDs()

    local seen = {}  -- deduplicate quests that appear on multiple zone maps

    -- Exclude quest IDs handled by static expansion data (e.g. delve boss quests)
    -- so the dynamic scanner doesn't add duplicates or ungated entries.
    local excluded = {}
    if RS.Expansion and RS.Expansion.GetExcludedQuestIDs then
        excluded = RS.Expansion:GetExcludedQuestIDs()
    end

    -- Two quest sources, scanned per zone + child zones:
    -- 1. C_TaskQuest — world quests, bonus objectives, task quests
    --    Returns empty until player has viewed the zone in Map UI.
    --    Data fills in via MapCanvas.MapSet / QUEST_LOG_UPDATE events.
    -- 2. C_QuestLog.GetQuestsOnMap — regular quests, dailies, prey hunts
    --    Works immediately without map interaction.

    local getTaskQuests = C_TaskQuest and (C_TaskQuest.GetQuestsOnMap
                       or C_TaskQuest.GetQuestsForPlayerByMapID)
    local getQuestLog   = C_QuestLog and C_QuestLog.GetQuestsOnMap

    -- Build full zone list including child/sub-zones
    local allZones = {}
    for _, mapID in ipairs(zoneMapIDs) do
        allZones[mapID] = true
        -- Add child zones (sub-zones, micro-dungeons, etc.)
        if C_Map and C_Map.GetMapChildrenInfo then
            local ok, children = pcall(C_Map.GetMapChildrenInfo, mapID, nil, true)
            if ok and children then
                for _, child in ipairs(children) do
                    if child.mapID then
                        allZones[child.mapID] = true
                    end
                end
            end
        end
    end

    for mapID in pairs(allZones) do
        -- Source 1: C_TaskQuest (world quests, bonus objectives)
        local quests = {}
        if getTaskQuests then
            local ok, tq = pcall(getTaskQuests, mapID)
            if ok and tq then
                for _, qi in ipairs(tq) do table.insert(quests, qi) end
            end
        end

        -- Source 2: C_QuestLog.GetQuestsOnMap (regular quests, dailies, prey hunts)
        if getQuestLog then
            local ok, lq = pcall(getQuestLog, mapID)
            if ok and lq then
                for _, qi in ipairs(lq) do table.insert(quests, qi) end
            end
        end
        for _, questInfo in ipairs(quests) do
            -- 11.0.5+ uses questID (uppercase D); pre-11.0.5 used questId (lowercase d)
            local qID = questInfo.questID or questInfo.questId
            if qID and not seen[qID] and not excluded[qID] then

                local completed = false
                pcall(function() completed = C_QuestLog.IsQuestFlaggedCompleted(qID) end)
                if not completed then
                    seen[qID] = true

                    -- Time left (task quests / world quests only)
                    local timeLeft = nil
                    if C_TaskQuest and C_TaskQuest.GetQuestTimeLeftSeconds then
                        pcall(function() timeLeft = C_TaskQuest.GetQuestTimeLeftSeconds(qID) end)
                    end

                    -- Skip if nearly expired
                    if not timeLeft or timeLeft >= EXPIRY_SKIP_SECS then
                        -- Try task quest title first, then quest log title
                        local title = ""
                        if C_TaskQuest and C_TaskQuest.GetQuestInfoByQuestID then
                            pcall(function() title = C_TaskQuest.GetQuestInfoByQuestID(qID) or "" end)
                        end
                        if title == "" then
                            pcall(function() title = C_QuestLog.GetTitleForQuestID(qID) or "" end)
                        end
                        if title == "" then title = "Quest #" .. qID end

                        -- Use the quest's actual mapID if available (cross-zone spillover),
                        -- otherwise fall back to the map we scanned.
                        local questMapID = questInfo.mapID or mapID
                        local x, y = questInfo.x, questInfo.y

                        -- If quest came from a different zone, get its proper coordinates
                        -- via C_TaskQuest.GetQuestLocation if available.
                        if questMapID ~= mapID and C_TaskQuest.GetQuestLocation then
                            local ok, lx, ly = pcall(C_TaskQuest.GetQuestLocation, qID, questMapID)
                            if ok and lx and ly then
                                x, y = lx, ly
                            end
                        end

                        -- Determine quest type: world quest vs daily vs other task quest
                        local isWQ = C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(qID)
                        local questType = "WORLD_QUEST"
                        if not isWQ then
                            -- Dailies, bonus objectives, zone unlock quests etc.
                            -- Use isDaily from the API if available, else default to WORLD_QUEST
                            if questInfo.isDaily then
                                questType = "WORLD_QUEST"  -- dailies route the same as WQs
                            end
                        end

                        -- Reward type detection using WQT-style APIs.
                        -- Gate: HaveQuestRewardData must be true for reliable reads.
                        local rewardTypes = {}
                        local haveData = not HaveQuestRewardData or HaveQuestRewardData(qID)
                        if haveData then
                            -- Items (gear, consumables) — each in its own pcall for safety
                            pcall(function()
                                local numItems = GetNumQuestLogRewards and GetNumQuestLogRewards(qID) or 0
                                for ri = 1, numItems do
                                    pcall(function()
                                        local _, _, _, _, _, rewardId = GetQuestLogRewardInfo(ri, qID)
                                        if rewardId then
                                            local ok, price, typeID = pcall(function() return select(11, C_Item.GetItemInfo(rewardId)) end)
                                            if ok and typeID and (typeID == Enum.ItemClass.Armor or typeID == Enum.ItemClass.Weapon) then
                                                table.insert(rewardTypes, "gear")
                                            else
                                                table.insert(rewardTypes, "item")
                                            end
                                        end
                                    end)
                                end
                            end)
                            -- Currencies — separate pcall
                            pcall(function()
                                local currencies = C_QuestLog.GetQuestRewardCurrencies(qID)
                                for _, cur in ipairs(currencies or {}) do
                                    local isRep = false
                                    pcall(function()
                                        isRep = C_CurrencyInfo.GetFactionGrantedByCurrency(cur.currencyID) ~= nil
                                    end)
                                    table.insert(rewardTypes, isRep and "rep" or "currency")
                                end
                            end)
                            -- Gold
                            pcall(function()
                                local gold = GetQuestLogRewardMoney(qID) or 0
                                if gold > 0 then table.insert(rewardTypes, "gold") end
                            end)
                            -- XP
                            pcall(function()
                                local xp = GetQuestLogRewardXP(qID) or 0
                                if xp > 0 then table.insert(rewardTypes, "xp") end
                            end)
                        end

                        if #rewardTypes == 0 then
                            rewardTypes = { "misc" }
                        end

                        -- Request reward data preload so tooltip has data on hover.
                        -- HaveQuestRewardData returns false until Blizzard loads it;
                        -- RequestPreloadRewardData triggers async loading.
                        if C_TaskQuest and C_TaskQuest.RequestPreloadRewardData then
                            pcall(C_TaskQuest.RequestPreloadRewardData, qID)
                        end

                        -- duration intentionally nil here so RS.Timing:GetDuration
                        -- is used at route-build time (picks personal avg or category default)
                        table.insert(results, {
                            id       = "wq_" .. qID,
                            questID  = qID,
                            name     = title,
                            mapID    = questMapID,
                            x        = x or 0.5,
                            y        = y or 0.5,
                            type     = questType,
                            duration = nil,
                            rewards  = rewardTypes,
                            timeLeft = timeLeft,
                            isExpiringSoon = timeLeft and timeLeft < EXPIRY_URGENT_SECS,
                            priority = 2,
                        })
                    end
                end
            end  -- end qID guard
        end
    end

    return results
end
-- Checks weekly/event completion via C_QuestLog
-- ============================================================
function RS.Scanner:ScanStaticActivities()
    local results = {}

    for _, activity in ipairs(RS.Expansion:GetAllStaticActivities()) do
        local isDone = false

        -- Check via questID if we have one
        -- Prefer questIDTurnin for completion (turn-in = fully done), fall back to questID
        if activity.questIDTurnin then
            isDone = C_QuestLog.IsQuestFlaggedCompleted(activity.questIDTurnin)
        elseif activity.questID then
            isDone = C_QuestLog.IsQuestFlaggedCompleted(activity.questID)
        end

        -- Check local weekly completion cache as fallback
        if not isDone and RS_CharData.completedWeeklies[activity.id] then
            isDone = true
        end

        -- Skip Abundance static entries — handled dynamically
        if activity.type == "ROTATING_EVENT" then
            -- Handled by GetActiveAbundanceCave()
        elseif not isDone then
            table.insert(results, {
                id          = activity.id,
                name        = activity.name,
                mapID       = activity.mapID,
                x           = activity.x,
                y           = activity.y,
                type        = activity.type,
                duration    = (activity.duration or RS_Settings.questTime) * 60,
                rewards     = activity.rewards or {},
                timeLeft    = nil,
                priority    = activity.priority or 2,
                notes       = activity.notes,
                isWarbandLocked = activity.isWarbandLocked,
            })
        end
    end

    return results
end

-- ============================================================
-- ABUNDANCE CAVE — detect which cave is active via confirmed Area POI IDs
-- From HandyNotes_Midnight:
--   Normal:   8415=Zul'Aman, 8416=Eversong, 8417=Voidstorm, 8418=Harandar
--   Harvest:  8525=Zul'Aman, 8528=Eversong, 8526=Voidstorm, 8527=Harandar
-- ============================================================
local ABUNDANCE_POIS = {
    { mapID = 2437, normalPOI = 8415, harvestPOI = 8525, label = "Zul'Aman" },
    { mapID = 2395, normalPOI = 8416, harvestPOI = 8528, label = "Eversong" },
    { mapID = 2405, normalPOI = 8417, harvestPOI = 8526, label = "Voidstorm" },
    { mapID = 2413, normalPOI = 8418, harvestPOI = 8527, label = "Harandar" },
}

function RS.Scanner:GetActiveAbundanceCave()
    if not C_AreaPoiInfo or not C_AreaPoiInfo.GetAreaPOIInfo then return nil end

    -- Check each zone for its known Abundance POI IDs
    for _, entry in ipairs(ABUNDANCE_POIS) do
        for _, poiID in ipairs({ entry.harvestPOI, entry.normalPOI }) do
            local ok, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, entry.mapID, poiID)
            if ok and info then
                local isHarvest = (poiID == entry.harvestPOI)
                local name = info.name or ("Abundance Cave (" .. entry.label .. ")")
                local x = info.position and info.position.x or 0.5
                local y = info.position and info.position.y or 0.5

                -- Time remaining: try POI first, fall back to 8hr rotation math
                local timeLeft = nil
                if info.secondsLeft and info.secondsLeft > 0 then
                    timeLeft = info.secondsLeft
                else
                    -- Abundance caves rotate every 8 hours at 7:00, 15:00, 23:00 UTC.
                    local ROTATION_SECS = 8 * 3600  -- 8 hours
                    local EPOCH_OFFSET  = 25200     -- 7h offset from UTC epoch
                    local now = GetServerTime()
                    local elapsed = (now - EPOCH_OFFSET) % ROTATION_SECS
                    timeLeft = ROTATION_SECS - elapsed
                end

                local suffix = isHarvest and " |cffff8800[HARVEST]|r" or " |cff00ff00[ACTIVE]|r"
                local timeNote = ""
                if timeLeft and RS.Flight then
                    timeNote = " — rotates in " .. RS.Flight:FormatTime(timeLeft)
                end

                -- Find matching static cave entry for coords fallback
                local caveX, caveY = x, y
                for _, a in ipairs(RS.Expansion:GetAllStaticActivities()) do
                    if a.type == "ROTATING_EVENT" and a.mapID == entry.mapID then
                        if caveX == 0.5 then caveX = a.x end
                        if caveY == 0.5 then caveY = a.y end
                        break
                    end
                end

                return {
                    id             = "abundance_" .. entry.mapID .. "_active",
                    name           = name .. suffix,
                    mapID          = entry.mapID,
                    x              = caveX,
                    y              = caveY,
                    type           = "ROTATING_EVENT",
                    duration       = 5 * 60,
                    rewards        = { "gold", "mounts", "professions" },
                    timeLeft       = timeLeft,
                    isExpiringSoon = timeLeft and timeLeft < (60 * 60),
                    priority       = isHarvest and 3 or 2,
                    notes          = (isHarvest and "Abundant Harvest" or "Abundance Cave")
                                     .. " (" .. entry.label .. ")" .. timeNote,
                    questID        = 89507,  -- shared weekly quest
                }
            end
        end
    end

    return nil  -- no active abundance cave found (all POIs inactive)
end

-- ============================================================
-- ACTIVITY SCORING
-- Higher = do this sooner. Uses active profile's reward weights and activity ordering.
-- For WEEKLY/WEEKLY_EVENT types, score scales with proximity to weekly reset:
--   Normal play (>48h)  : no bonus beyond reward/type score → low detour tolerance
--   <48h to reset       : +5 bonus  → mild nudge toward weeklies
--   <24h to reset       : +12 bonus → day-before, weeklies start winning detours
--   < 4h to reset       : +30 bonus → critical, weeklies override nearly everything
-- SCORE_SECS_PER_POINT=8, so +30 = 240s extra detour tolerance for critical weeklies.
-- ============================================================
function RS.Scanner:ScoreActivity(activity)
    local score = 0
    local rewardWeights = buildRewardWeights()

    -- Reward score from profile-ordered weights
    for _, reward in ipairs(activity.rewards or {}) do
        score = score + (rewardWeights[reward] or 1)
    end

    -- WQ expiry urgency bonus (always applies regardless of profile)
    if activity.isExpiringSoon then
        score = score + 15
    end

    -- Activity type position bonus from profile order
    score = score + activityPositionBonus(activity.type)

    -- Zone preference modifier (prefer/avoid zones for variety)
    -- Values are deliberately large: they multiply by SCORE_SECS_PER_POINT (8s)
    -- in the TSP solver, so +40 = 320s travel credit, -40 = 320s penalty.
    -- This is enough to overcome Silvermoon→Eversong proximity advantage.
    if activity.mapID then
        local profile = RS:GetActiveProfile()
        if profile and profile.zonePreferences then
            local pref = profile.zonePreferences[activity.mapID]
            if pref == "prefer" then
                score = score + 40
            elseif pref == "avoid" then
                score = score - 40
            end
        end
    end

    -- Great Vault awareness: boost activities that count toward the next vault slot.
    -- Dungeons, delves, and world activities all contribute to vault progress.
    local hasGearReward = false
    for _, r in ipairs(activity.rewards or {}) do
        if r == "gear" or r == "cache" then hasGearReward = true; break end
    end
    if hasGearReward then
        score = score + 5
        -- Extra boost if vault slots are incomplete
        if RS.DB and RS.DB.GetVaultWorldRemaining then
            local remaining = RS.DB:GetVaultWorldRemaining()
            if remaining and remaining > 0 then
                -- Activities that count toward vault get a bonus proportional to urgency
                if activity.type == "WORLD_QUEST" or activity.type == "DELVE"
                    or activity.type == "DUNGEON" then
                    score = score + math.min(10, remaining * 3)
                end
            end
        end
    end

    -- Deprioritize rep rewards for maxed factions
    if RS.DB and RS.DB.IsFactionMaxed then
        for _, r in ipairs(activity.rewards or {}) do
            if r == "rep" and activity.factionID then
                if RS.DB:IsFactionMaxed(activity.factionID) then
                    score = score - 5
                end
            end
        end
    end

    -- Prey zone priority: if the player has an active prey quest in a zone,
    -- all activities in that zone get a bonus so the crystal fills passively
    -- while completing other content there.
    if activity.mapID and RS.DB and RS.DB.GetActivePreyZone then
        local preyZone = RS.DB:GetActivePreyZone()
        if preyZone and activity.mapID == preyZone then
            score = score + 15  -- strong pull toward the prey zone
        end
    end

    -- Weekly reset urgency: WEEKLY and WEEKLY_EVENT types get escalating bonuses
    -- as the reset approaches. In normal play they carry no extra pull.
    if activity.type == "WEEKLY" or activity.type == "WEEKLY_EVENT" then
        local secs = secsUntilReset()
        if secs then
            if secs < RESET_URGENT_SECS then
                -- < 4h: critical — weekly loss imminent, override nearby WQs
                score = score + 30
                activity.isExpiringSoon = true  -- also triggers the router's urgency pass
            elseif secs < RESET_WARNING_SECS then
                -- < 24h: day-before window — start pulling weeklies forward
                score = score + 12
            elseif secs < RESET_NORMAL_SECS then
                -- < 48h: mild nudge only
                score = score + 5
            end
            -- > 48h: no bonus — treat weeklies as low-detour "on the way" stops
        end
    end

    return score
end

-- ============================================================
-- Mark an activity as manually completed (persisted per character)
-- ============================================================
function RS.Scanner:MarkCompleted(activityID)
    if RS_CharData then
        RS_CharData.completedWeeklies[activityID] = true
    end
end

function RS.Scanner:MarkIncomplete(activityID)
    if RS_CharData then
        RS_CharData.completedWeeklies[activityID] = nil
    end
end

-- Returns true if the given type is one of the profile-managed types
-- (i.e., it appears in activityOrder). Leveling types like CAMPAIGN,
-- QUESTLINE, BONUS_OBJECTIVE etc. are NOT profile types.
local PROFILE_TYPES = {
    WEEKLY = true, WEEKLY_EVENT = true, DUNGEON = true, WORLD_QUEST = true,
    DELVE = true, ROTATING_EVENT = true, HOUSING = true, BATTLEGROUND = true,
    RARE = true, PROFESSION = true, DECOR = true,
}
function RS.Scanner:IsProfileType(activityType)
    return PROFILE_TYPES[activityType] or false
end

-- Shortcut called from main
function RS:ScanQuests()
    return RS.Scanner:GetActiveActivities()
end
