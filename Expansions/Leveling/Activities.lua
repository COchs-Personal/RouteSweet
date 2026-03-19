-- Expansions/Leveling/Activities.lua
-- Dynamic quest discovery for leveling characters (80-89).
-- Scans three sources:
--   1. C_QuestLog.GetQuestsOnMap        — available + in-progress quests (yellow !, objectives)
--   2. C_QuestLine.GetAvailableQuestLines — storyline context (campaign/important/local story)
--   3. C_TaskQuest.GetQuestsOnMap        — bonus objectives and area quests
--
-- Results are merged, deduplicated, classified, and scored by XP efficiency.
--
-- LOAD ORDER: After Expansions/Leveling/Database.lua

local leveling = RS.Expansion:GetExpansion("Leveling")
if not leveling then return end

local DB = leveling.db
if not DB then return end

-- ============================================================
-- TYPE ICONS for the UI (reuses Midnight patterns)
-- ============================================================
local TYPE_LABELS = {
    CAMPAIGN        = "Campaign",
    IMPORTANT       = "Important",
    LEGENDARY       = "Legendary",
    QUESTLINE       = "Story",
    BONUS_OBJECTIVE = "Bonus",
    NORMAL          = "Side Quest",
    RECURRING       = "Recurring",
    CALLING         = "Calling",
    META            = "Meta",
    THREAT          = "Threat",
}

-- ============================================================
-- QUEST LINE DATA REQUEST
-- C_QuestLine requires an async request before data is available.
-- We request on first scan and cache per-zone per-session.
-- ============================================================
local _questLineRequested = {}

local function requestQuestLines(mapID)
    if _questLineRequested[mapID] then return end
    if C_QuestLine and C_QuestLine.RequestQuestLinesForMap then
        pcall(C_QuestLine.RequestQuestLinesForMap, mapID)
        _questLineRequested[mapID] = true
    end
end

-- ============================================================
-- SCAN: C_QuestLog.GetQuestsOnMap
-- Returns available quest givers + in-progress quests with map coords.
-- ============================================================
local function scanQuestLog(mapID, seen, results)
    if not C_QuestLog or not C_QuestLog.GetQuestsOnMap then return end

    local ok, quests = pcall(C_QuestLog.GetQuestsOnMap, mapID)
    if not ok or not quests then return end

    for _, qi in ipairs(quests) do
        local qID = qi.questID or qi.questId
        if qID and not seen[qID] then
            -- Skip completed quests
            local completed = false
            pcall(function() completed = C_QuestLog.IsQuestFlaggedCompleted(qID) end)
            -- Only include quests that are actionable:
            --   isQuestStart = true → yellow ! on map, available to pick up
            --   inProgress = true   → already in quest log, being worked on
            -- Skip everything else (future/gated content, completed quests)
            local inLog = false
            pcall(function() inLog = C_QuestLog.IsOnQuest(qID) end)
            local isActionable = qi.isQuestStart or qi.inProgress or inLog

            if not completed and isActionable then
                seen[qID] = true

                local questMapID = qi.mapID or mapID
                local x, y = qi.x or 0.5, qi.y or 0.5

                -- Get quest line info for classification
                local questLineInfo = nil
                if C_QuestLine and C_QuestLine.GetQuestLineInfo then
                    pcall(function()
                        questLineInfo = C_QuestLine.GetQuestLineInfo(qID, questMapID)
                    end)
                end

                local questType = DB:ClassifyQuest(qID, questLineInfo)
                local title = ""
                pcall(function()
                    title = C_QuestLog.GetTitleForQuestID(qID) or ""
                end)
                if title == "" then
                    title = "Quest #" .. qID
                end

                local duration = DB.DURATION_DEFAULTS[questType] or 300
                local xp = DB:GetQuestXP(qID)
                local score = DB:ScoreQuest(qID, questType, duration)

                local label = TYPE_LABELS[questType] or "Quest"
                local namePrefix = qi.isQuestStart and "[!] " or ""

                table.insert(results, {
                    id           = "lv_" .. qID,
                    questID      = qID,
                    name         = namePrefix .. title,
                    mapID        = questMapID,
                    x            = x,
                    y            = y,
                    type         = questType,
                    duration     = duration,
                    rewards      = xp > 0 and { "xp" } or { "misc" },
                    xpReward     = xp,
                    score        = score,
                    priority     = DB.TYPE_PRIORITY[questType] or 3,
                    notes        = label .. (xp > 0 and (" — " .. xp .. " XP") or ""),
                    isQuestStart = qi.isQuestStart,
                    inProgress   = qi.inProgress or inLog,
                    questLineInfo = questLineInfo,
                })
            end
        end
    end
end

-- ============================================================
-- SCAN: C_QuestLine.GetAvailableQuestLines
-- Enriches with storyline context. May discover quests not in GetQuestsOnMap.
-- ============================================================
local function scanQuestLines(mapID, seen, results)
    if not C_QuestLine or not C_QuestLine.GetAvailableQuestLines then return end

    requestQuestLines(mapID)

    local ok, questLines = pcall(C_QuestLine.GetAvailableQuestLines, mapID)
    if not ok or not questLines then return end

    for _, qli in ipairs(questLines) do
        local qID = qli.questID
        if qID and not seen[qID] then
            local completed = false
            pcall(function() completed = C_QuestLog.IsQuestFlaggedCompleted(qID) end)
            -- Also skip account-completed if we don't need it
            if qli.isAccountCompleted then completed = true end

            -- Only include actionable quests: available to pick up or in progress
            local inLog = false
            pcall(function() inLog = C_QuestLog.IsOnQuest(qID) end)
            local isActionable = qli.isQuestStart or qli.inProgress or inLog

            if not completed and not qli.isHidden and isActionable then
                seen[qID] = true

                local questType = DB:ClassifyQuest(qID, qli)
                local title = qli.questName or ("Quest #" .. qID)
                local duration = DB.DURATION_DEFAULTS[questType] or 300
                local xp = DB:GetQuestXP(qID)
                local score = DB:ScoreQuest(qID, questType, duration)

                local label = TYPE_LABELS[questType] or "Quest"
                local storyLabel = qli.questLineName and (" [" .. qli.questLineName .. "]") or ""

                table.insert(results, {
                    id           = "lv_" .. qID,
                    questID      = qID,
                    name         = title,
                    mapID        = qli.startMapID or mapID,
                    x            = qli.x or 0.5,
                    y            = qli.y or 0.5,
                    type         = questType,
                    duration     = duration,
                    rewards      = xp > 0 and { "xp" } or { "misc" },
                    xpReward     = xp,
                    score        = score,
                    priority     = DB.TYPE_PRIORITY[questType] or 3,
                    notes        = label .. storyLabel .. (xp > 0 and (" — " .. xp .. " XP") or ""),
                    isQuestStart = qli.isQuestStart,
                    inProgress   = qli.inProgress,
                    questLineInfo = qli,
                })
            end
        end
    end
end

-- ============================================================
-- SCAN: C_TaskQuest.GetQuestsOnMap (bonus objectives, area quests)
-- ============================================================
local function scanBonusObjectives(mapID, seen, results)
    if not C_TaskQuest or not C_TaskQuest.GetQuestsOnMap then return end

    local ok, quests = pcall(C_TaskQuest.GetQuestsOnMap, mapID)
    if not ok or not quests then return end

    for _, qi in ipairs(quests) do
        local qID = qi.questID or qi.questId
        if qID and not seen[qID] then
            local completed = false
            pcall(function() completed = C_QuestLog.IsQuestFlaggedCompleted(qID) end)

            if not completed then
                -- Only include if it's a task/bonus, not a world quest (those are max-level)
                local isWQ = false
                if C_QuestLog.IsWorldQuest then
                    pcall(function() isWQ = C_QuestLog.IsWorldQuest(qID) end)
                end

                if not isWQ then
                    seen[qID] = true

                    local questMapID = qi.mapID or mapID
                    local title = ""
                    pcall(function()
                        title = C_TaskQuest.GetQuestInfoByQuestID(qID) or ""
                    end)
                    if title == "" then
                        pcall(function() title = C_QuestLog.GetTitleForQuestID(qID) or "" end)
                    end
                    if title == "" then title = "Bonus #" .. qID end

                    local xp = DB:GetQuestXP(qID)
                    local duration = DB.DURATION_DEFAULTS.BONUS_OBJECTIVE
                    local score = DB:ScoreQuest(qID, "BONUS_OBJECTIVE", duration)

                    -- Check progress if it's an area objective
                    local progress = nil
                    if C_TaskQuest.GetQuestProgressBarInfo then
                        pcall(function() progress = C_TaskQuest.GetQuestProgressBarInfo(qID) end)
                    end

                    local progressNote = progress and (" (" .. math.floor(progress) .. "%)") or ""

                    table.insert(results, {
                        id           = "lv_bonus_" .. qID,
                        questID      = qID,
                        name         = title .. progressNote,
                        mapID        = questMapID,
                        x            = qi.x or 0.5,
                        y            = qi.y or 0.5,
                        type         = "BONUS_OBJECTIVE",
                        duration     = duration,
                        rewards      = xp > 0 and { "xp" } or { "misc" },
                        xpReward     = xp,
                        score        = score,
                        priority     = DB.TYPE_PRIORITY.BONUS_OBJECTIVE,
                        notes        = "Bonus Objective" .. progressNote .. (xp > 0 and (" — " .. xp .. " XP") or ""),
                        inProgress   = progress and progress > 0,
                    })
                end
            end
        end
    end
end

-- ============================================================
-- BuildDynamicActivities — registered on the Leveling expansion
-- Called by RS.Expansion:BuildDynamicActivities(enabledTypes)
-- ============================================================
leveling.BuildDynamicActivities = function(enabledTypes)
    local results = {}
    local seen = {}

    -- Get scan zones from registration
    local scanZones = leveling.scanZoneIDs or {}

    for _, mapID in ipairs(scanZones) do
        -- Quest log quests (main source — quest givers + in-progress)
        scanQuestLog(mapID, seen, results)

        -- Quest lines (storyline enrichment + missed quests)
        scanQuestLines(mapID, seen, results)

        -- Bonus objectives / area quests
        scanBonusObjectives(mapID, seen, results)
    end

    -- ── DELVER'S CALL QUESTS ───────────────────────────────
    -- These are in the quest log (not map-discovered). Add special handling.
    local delversCall = DB:GetDelversCallStatus()
    local playerLevel = UnitLevel("player") or 80
    for _, dc in ipairs(delversCall) do
        if not seen[dc.questID] then
            seen[dc.questID] = true
            local score = DB:ScoreDelversCall(dc.questID, dc.isComplete)
            local holdNote = ""
            if dc.isComplete and playerLevel < DB.DELVERS_CALL_TURNIN_LEVEL then
                holdNote = " |cffff8800[HOLD — turn in at " .. DB.DELVERS_CALL_TURNIN_LEVEL .. "]|r"
            elseif dc.isComplete and playerLevel >= DB.DELVERS_CALL_TURNIN_LEVEL then
                holdNote = " |cff00ff00[TURN IN NOW]|r"
            end

            -- Delver's Call quests don't have map coords — use Silvermoon turn-in
            -- or the delve entrance if criteria incomplete
            local mapID = 2393  -- Silvermoon (turn-in NPC)
            local x, y = 0.5, 0.5
            if not dc.isComplete then
                -- Route to any delve entrance in current zones
                -- (the quest auto-tracks to the right delve)
                mapID = nil  -- will be set by the quest tracker
            end

            table.insert(results, {
                id           = "lv_dc_" .. dc.questID,
                questID      = dc.questID,
                name         = dc.title .. holdNote,
                mapID        = mapID or 2393,
                x            = x,
                y            = y,
                type         = "CALLING",
                duration     = dc.isComplete and 30 or 480,  -- turn-in is fast, doing the delve is ~8min
                rewards      = { "xp" },
                xpReward     = DB:GetQuestXP(dc.questID),
                score        = score,
                priority     = dc.isComplete and (playerLevel >= DB.DELVERS_CALL_TURNIN_LEVEL and 10 or 1) or 6,
                notes        = "Delver's Call" .. holdNote,
                inProgress   = true,
                isDelversCall = true,
            })
        end
    end

    -- Also scan the player's current map if it's not in the scan list
    -- (handles being in a sub-zone or instance entrance area)
    local playerMapID = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if playerMapID then
        local alreadyScanned = false
        for _, mapID in ipairs(scanZones) do
            if mapID == playerMapID then alreadyScanned = true; break end
        end
        if not alreadyScanned then
            scanQuestLog(playerMapID, seen, results)
            scanQuestLines(playerMapID, seen, results)
            scanBonusObjectives(playerMapID, seen, results)
        end
    end

    return results
end
