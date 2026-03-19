-- Expansions/Leveling/Database.lua
-- Quest classification, XP scoring, and campaign tracking for leveling (80-90).
--
-- LOAD ORDER: After Expansions/Leveling/Zones.lua

local leveling = RS.Expansion:GetExpansion("Leveling")
if not leveling then return end

local DB = {}
leveling.db = DB

-- ============================================================
-- WARBAND XP BONUS
-- 5% per level 90 character, up to 25% (5 characters).
-- Detected via achievements 42328 (5%) through 42332 (25%).
-- ============================================================
DB.WARBAND_XP_ACHIEVEMENTS = { 42332, 42331, 42330, 42329, 42328 }  -- check highest first
DB.WARBAND_XP_BONUS = { 25, 20, 15, 10, 5 }

function DB:GetWarbandXPBonus()
    for i, achID in ipairs(self.WARBAND_XP_ACHIEVEMENTS) do
        local _, _, _, completed = GetAchievementInfo(achID)
        if completed then
            return self.WARBAND_XP_BONUS[i]
        end
    end
    return 0
end

-- ============================================================
-- QUEST CLASSIFICATION
-- Maps Enum.QuestClassification values to RouteSweet activity types.
-- ============================================================
DB.CLASSIFICATION = {
    [0]  = "IMPORTANT",       -- Important (orange !)
    [1]  = "LEGENDARY",       -- Legendary
    [2]  = "CAMPAIGN",        -- Campaign (shield icon)
    [3]  = "CALLING",         -- Calling
    [4]  = "META",            -- Meta quest
    [5]  = "RECURRING",       -- Recurring
    [6]  = "QUESTLINE",       -- Questline / local story
    [7]  = "NORMAL",          -- Normal side quest
    [8]  = "BONUS_OBJECTIVE", -- Bonus objective
    [9]  = "THREAT",          -- Threat
    [10] = "WORLD_QUEST",     -- World quest (shouldn't appear while leveling)
}

-- Priority order for leveling: campaign > important > questline > bonus > normal
DB.TYPE_PRIORITY = {
    CAMPAIGN        = 10,
    IMPORTANT       = 8,
    LEGENDARY       = 9,
    QUESTLINE       = 6,
    BONUS_OBJECTIVE = 5,
    NORMAL          = 3,
    RECURRING       = 2,
    CALLING         = 4,
    META            = 1,
    THREAT          = 7,
    WORLD_QUEST     = 3,
}

-- Category defaults for leveling activity durations (seconds)
DB.DURATION_DEFAULTS = {
    CAMPAIGN        = 5 * 60,    -- campaign quests are usually short
    IMPORTANT       = 5 * 60,
    LEGENDARY       = 8 * 60,
    QUESTLINE       = 5 * 60,
    BONUS_OBJECTIVE = 3 * 60,    -- area objectives are quick
    NORMAL          = 4 * 60,
    RECURRING       = 3 * 60,
    CALLING         = 5 * 60,
    META            = 2 * 60,
    THREAT          = 5 * 60,
}

-- ============================================================
-- XP SCORING
-- Converts raw XP reward into a routing score.
-- Higher XP/minute = better route efficiency.
-- ============================================================

-- Base XP per level for rough percentage calculation (Midnight 80-90)
-- These are approximate; exact values vary by level.
DB.XP_PER_LEVEL_APPROX = {
    [80] = 400000,
    [81] = 420000,
    [82] = 450000,
    [83] = 480000,
    [84] = 510000,
    [85] = 550000,
    [86] = 590000,
    [87] = 640000,
    [88] = 690000,
    [89] = 750000,
}

-- Returns estimated XP reward for a quest (includes warband bonus).
-- Tries GetQuestLogRewardXP first (works for quests in log and task quests).
-- Returns 0 if unavailable.
function DB:GetQuestXP(questID)
    if not questID then return 0 end
    local xp = 0
    pcall(function()
        local totalXP, baseXP = GetQuestLogRewardXP(questID)
        xp = totalXP or baseXP or 0
    end)
    -- GetQuestLogRewardXP already includes warband bonus in totalXP
    return xp
end

-- Converts XP into a score for routing. Higher = do this sooner.
-- Score is XP / estimated_duration, so high-XP quick quests rank highest.
-- Campaign quests get a flat bonus regardless of XP.
function DB:ScoreQuest(questID, questType, estimatedDuration)
    local xp = self:GetQuestXP(questID)
    local durationMin = (estimatedDuration or 300) / 60  -- convert to minutes
    if durationMin < 1 then durationMin = 1 end

    -- Base score: XP per minute of estimated time
    local score = xp / (durationMin * 100)  -- scale down to reasonable range

    -- Type priority bonus
    local typePriority = self.TYPE_PRIORITY[questType] or 3
    score = score + typePriority * 2

    -- Campaign quests always get a big bonus — they gate progression
    if questType == "CAMPAIGN" then
        score = score + 30
    elseif questType == "IMPORTANT" then
        score = score + 20
    elseif questType == "QUESTLINE" then
        score = score + 10
    end

    -- Bonus objectives get a proximity bonus (they're done "on the way")
    if questType == "BONUS_OBJECTIVE" then
        score = score + 5
    end

    return score
end

-- ============================================================
-- QUEST CLASSIFICATION HELPER
-- Uses C_QuestInfoSystem.GetQuestClassification when available,
-- falls back to C_QuestLine info and C_CampaignInfo.
-- ============================================================
function DB:ClassifyQuest(questID, questLineInfo)
    -- Try the direct classification API first
    if C_QuestInfoSystem and C_QuestInfoSystem.GetQuestClassification then
        local ok, classification = pcall(C_QuestInfoSystem.GetQuestClassification, questID)
        if ok and classification then
            local mapped = self.CLASSIFICATION[classification]
            if mapped then return mapped end
        end
    end

    -- Fall back to quest line info flags
    if questLineInfo then
        if questLineInfo.isCampaign then return "CAMPAIGN" end
        if questLineInfo.isImportant then return "IMPORTANT" end
        if questLineInfo.isLegendary then return "LEGENDARY" end
        if questLineInfo.isLocalStory then return "QUESTLINE" end
    end

    -- Fall back to C_CampaignInfo
    if C_CampaignInfo and C_CampaignInfo.IsCampaignQuest then
        local ok, isCampaign = pcall(C_CampaignInfo.IsCampaignQuest, questID)
        if ok and isCampaign then return "CAMPAIGN" end
    end

    return "NORMAL"
end

-- ============================================================
-- DELVER'S CALL — XP OPTIMIZATION
-- These weekly quests scale XP with player level. Combined turn-in
-- at level ~88.5 yields 1.25-1.5 levels of XP. Strategy:
--   - Below 88: complete criteria (do the delves) but DO NOT turn in
--   - At 88+: turn in all at once for massive XP
-- ============================================================

-- Known Delver's Call quest IDs (detected dynamically via name matching too)
DB.DELVERS_CALL_PATTERN = "Delver's Call"
DB.DELVERS_CALL_TURNIN_LEVEL = 88

-- Checks if a quest is a Delver's Call quest by name pattern
function DB:IsDelversCall(questID)
    if not questID then return false end
    local title = ""
    pcall(function() title = C_QuestLog.GetTitleForQuestID(questID) or "" end)
    return title:find(self.DELVERS_CALL_PATTERN) ~= nil
end

-- Returns the status of all Delver's Call quests in the log.
-- { { questID, title, isComplete, objectives } ... }
function DB:GetDelversCallStatus()
    local results = {}
    local numEntries = C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries() or 0

    for i = 1, numEntries do
        local info = nil
        pcall(function() info = C_QuestLog.GetInfo(i) end)
        if info and info.questID and info.title and info.title:find(self.DELVERS_CALL_PATTERN) then
            -- Check if all objectives are complete
            local allDone = false
            pcall(function()
                local objs = C_QuestLog.GetQuestObjectives(info.questID)
                if objs and #objs > 0 then
                    allDone = true
                    for _, obj in ipairs(objs) do
                        if not obj.finished then allDone = false; break end
                    end
                end
            end)

            table.insert(results, {
                questID    = info.questID,
                title      = info.title,
                isComplete = allDone,
            })
        end
    end

    return results
end

-- Scores a Delver's Call quest for leveling routing.
-- If criteria complete but player < 88: very low score (HOLD)
-- If criteria complete and player >= 88: very high score (TURN IN NOW)
-- If criteria incomplete: normal delve priority (go do the delve)
function DB:ScoreDelversCall(questID, isComplete)
    local level = UnitLevel("player") or 80

    if isComplete then
        if level >= self.DELVERS_CALL_TURNIN_LEVEL then
            -- Turn in immediately — massive XP at this level
            return 50  -- highest priority
        else
            -- Hold for later — don't turn in yet
            return -10  -- very low, but keep in list with HOLD note
        end
    else
        -- Criteria not complete — route to delve (moderate priority)
        return 15
    end
end

-- ============================================================
-- CAMPAIGN PROGRESS TRACKING
-- ============================================================

-- Returns current campaign state for the player.
-- { campaignID, name, state, currentChapter, totalChapters }
function DB:GetCampaignProgress()
    local results = {}
    if not C_CampaignInfo or not C_CampaignInfo.GetAvailableCampaigns then
        return results
    end

    local ok, campaignIDs = pcall(C_CampaignInfo.GetAvailableCampaigns)
    if not ok or not campaignIDs then return results end

    for _, campaignID in ipairs(campaignIDs) do
        local info = nil
        pcall(function() info = C_CampaignInfo.GetCampaignInfo(campaignID) end)
        if info then
            local state = 0
            pcall(function() state = C_CampaignInfo.GetState(campaignID) end)

            local currentChapter = nil
            pcall(function() currentChapter = C_CampaignInfo.GetCurrentChapterID(campaignID) end)

            local chapterIDs = {}
            pcall(function() chapterIDs = C_CampaignInfo.GetChapterIDs(campaignID) or {} end)

            table.insert(results, {
                campaignID     = campaignID,
                name           = info.name or "Unknown Campaign",
                state          = state,       -- 0=Invalid, 1=Complete, 2=InProgress, 3=Stalled
                currentChapter = currentChapter,
                totalChapters  = #chapterIDs,
                chapterIDs     = chapterIDs,
            })
        end
    end

    return results
end

-- Returns the next quest in the current campaign chain, or nil.
function DB:GetNextCampaignQuest()
    local campaigns = self:GetCampaignProgress()
    for _, campaign in ipairs(campaigns) do
        -- InProgress = 2
        if campaign.state == 2 and campaign.currentChapter then
            -- Get the quest line for this chapter
            if C_QuestLine and C_QuestLine.GetQuestLineQuests then
                local ok, questIDs = pcall(C_QuestLine.GetQuestLineQuests, campaign.currentChapter)
                if ok and questIDs then
                    for _, qID in ipairs(questIDs) do
                        local completed = false
                        pcall(function() completed = C_QuestLog.IsQuestFlaggedCompleted(qID) end)
                        if not completed then
                            return qID, campaign
                        end
                    end
                end
            end
        end
    end
    return nil, nil
end
