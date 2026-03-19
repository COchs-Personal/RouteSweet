-- Expansions/Midnight/Database.lua
-- All Midnight-specific quest IDs, currencies, factions, and helper functions.
-- Attaches to the registered Midnight expansion as .db
--
-- LOAD ORDER: After Expansions/Midnight/Zones.lua

local midnight = RS.Expansion:GetExpansion("Midnight")
if not midnight then
    print("|cffff4444RouteSweet:|r Midnight expansion not registered before Database.lua loaded")
    return
end

local DB = {}
midnight.db = DB

-- ============================================================
-- SALTHERIL'S SOIREE — COMPLETE QUEST & TOKEN SYSTEM
-- ============================================================
DB.SOIREE = {
    FAVOR_OF_THE_COURT  = 89289,
    THE_SUBTLE_GAME     = 91693,
    FAVOR_ITEM_ID       = 238987,
    TOKEN_WEEKLY_QUEST  = 89307,
    BONUS_OBJECTIVE     = 91966,
    SALTHERIL_HAVEN_INTRO = 91628,
    HIGH_ESTEEM_UNLOCK    = 91629,

    FORTIFY_RUNESTONES = {
        magisters      = 90573,
        blood_knights  = 90574,
        farstriders    = 90575,
        shades_of_row  = 90576,
    },

    -- Token model: base 3, bonus +1 if chosen faction card shows the offer
    BASE_TOKENS = 3,
    MAX_TOKENS  = 4,

    -- FIX: This table was missing, causing pairs(nil) crash on sub-90 characters
    -- and any character with 0 tokens in bags.
    -- Per context doc: Renown 4+ = 4 tokens, Renown 8+ = 5 tokens.
    -- NOTE: The 3-or-4 model (base + optional bonus) is the confirmed mechanic,
    -- but the renown thresholds were documented in the original comments.
    -- Using the conservative 3/4 model here since the renown-based 5-token
    -- path is unconfirmed with sufficient data.
    TOKENS_BY_RENOWN = {
        [4] = 4,   -- Friend of the Court 1
        [8] = 5,   -- Friend of the Court 2 (unconfirmed, preserving original intent)
    },

    REP_MATRIX_NOTE = "DYNAMIC: changes every weekly reset. See RS_CharData.soireeChoiceCache for live values.",

    SUBFACTION_NPC_POOL = {
        magisters     = { "Esara Verrinde" },
        blood_knights = { "Armorer Roseblade", "Knight-Lord Dranarus" },
        farstriders   = { "Lieutenant Rellian", "Captain Helios" },
        shades_of_row = { "Sereth Duskbringer", "Darkdealer Thelis" },
    },

    SUBFACTION_NAMES = {
        magisters      = "Magisters",
        blood_knights  = "Blood Knights",
        farstriders    = "Farstriders",
        shades_of_row  = "Shades of the Row",
    },

    SUBFACTION_FACTION_IDS = {
        magisters      = 2711,
        blood_knights  = 2712,
        farstriders    = 2713,
        shades_of_row  = 2714,
    },

    SUBFACTION_CURRENCY_IDS = {
        magisters      = 3397,
        blood_knights  = 3398,
        farstriders    = 3390,
        shades_of_row  = 3396,
    },

    SUBFACTION_REPS = {
        magisters      = { npc = "Apprentice Diell",   x = 0.432, y = 0.478 },
        blood_knights  = { npc = "Armorer Goldcrest",  x = 0.440, y = 0.472 },
        farstriders    = { npc = "Ranger Allorn",       x = 0.436, y = 0.468 },
        shades_of_row  = { npc = "Neriv",               x = 0.428, y = 0.474 },
    },

    TOKEN_QUEST_REWARDS = {
        latent_arcana     = 25,
        brimming_arcana   = 30,
        subfaction_rep    = 100,
        coffer_key_shards = 35,
    },

    RUNESTONES = {
        { name = "Elrendar River",      x = 0.68, y = 0.72 },
        { name = "Dawnstar Spire",      x = 0.45, y = 0.28 },
        { name = "Sunstrider Isle",     x = 0.22, y = 0.18 },
        { name = "Ath'ran",             x = 0.58, y = 0.55 },
        { name = "Sanctum of the Moon", x = 0.38, y = 0.82 },
    },
}


-- ============================================================
-- MIDNIGHT FACTIONS
-- ============================================================
DB.FACTIONS = {
    silvermoon_court  = 2710,
    harati            = 2704,
    amani_tribe       = 2696,
    midnight_exp      = 2698,
    the_singularity   = 2699,
    magisters         = 2711,
    blood_knights     = 2712,
    farstriders       = 2713,
    shades_of_the_row = 2714,
}


-- ============================================================
-- MIDNIGHT CURRENCIES
-- ============================================================
DB.CURRENCIES = {
    brimming_arcana         = 3379,
    coffer_key_shards       = 3310,
    voidlight_marl          = 3316,
    community_coupons       = 3363,
    unalloyed_abundance     = 3377,
    party_favor             = 3352,
    dawnlight_manaflux      = 3378,
    remnant_of_anguish      = 3392,
    luminous_dust           = 3385,
    untainted_mana_crystals = 3356,
    hellstone_shard         = 3309,
    latent_arcana_item      = 242241,
    saltheril_favor_token   = 238987,
    silvermoon_court_rep    = 3365,   silvermoon_court_renown = 3371,
    harati_rep              = 3370,   harati_renown           = 3369,
    amani_tribe_rep         = 3354,   amani_tribe_renown      = 3355,
    magisters_rep           = 3397,
    blood_knights_rep       = 3398,
    farstriders_rep         = 3390,
    shades_rep              = 3396,
    adventurer_dawncrest    = 3391,
    veteran_dawncrest       = 3342,
    champion_dawncrest      = 3344,
    -- Crest IDs cross-referenced with MidnightRoutine (3383/3341/3343/3345/3347)
    -- Discrepancy: MR uses 3345/3347 for hero/myth, our dump had 3346/3348.
    -- Including both sets; verify in-game which are correct.
    adventurer_dawncrest    = 3383,
    veteran_dawncrest       = 3341,
    champion_dawncrest      = 3343,
    hero_dawncrest          = 3345,
    myth_dawncrest          = 3347,
    -- Alternate IDs from original dump (may be display vs spendable variants)
    adventurer_dawncrest_alt = 3391,
    veteran_dawncrest_alt    = 3342,
    champion_dawncrest_alt   = 3344,
    hero_dawncrest_alt       = 3346,
    myth_dawncrest_alt       = 3348,
    -- Other tracked currencies
    coffer_key_max          = 600,
    shard_of_dundun         = 3376,
}


-- ============================================================
-- PREY HUNT SYSTEM
-- Three difficulties, 4 completions per week each.
-- Quest IDs from MidnightRoutine reference.
-- ============================================================
DB.PREY = {
    -- Faction 2764 = "Prey: Season 1" (Major Faction with renown ranks 1-10)
    -- Hidden currency 3387 = "Preyseeker's Journey" (progress tracker)
    FACTION_ID       = 2764,
    CURRENCY_ID      = 3387,

    -- Feature unlock quest gates (use IsQuestFlaggedCompleted)
    UNLOCK_NORMAL    = 93086,  -- CONFIRMED: unlocks normal prey (available while leveling)
    UNLOCK_HARD      = 92182,  -- CONFIRMED: unlocks hard mode + 8/8 total + teleport + random (level 90 only)
    UNLOCK_NIGHTMARE = nil,    -- TBD: may not be available yet in Season 1
    UNLOCK_CUSTOM    = nil,    -- TBD: "Preferential Killing" from Astalor Bloodsworn (rank 10)

    NORMAL_QUEST_IDS = {
        91095, 91096, 91097, 91098, 91099, 91100, 91101, 91102, 91103, 91104,
        91105, 91106, 91107, 91108, 91109, 91110, 91111, 91112, 91113, 91114,
        91115, 91116, 91117, 91118, 91119, 91120, 91121, 91122, 91123, 91124,
    },
    HARD_QUEST_IDS = {
        91210, 91212, 91214, 91216, 91218, 91220, 91222, 91224, 91226, 91228,
        91230, 91232, 91234, 91236, 91238, 91240, 91242, 91243, 91244, 91245,
        91246, 91247, 91248, 91249, 91250, 91251, 91252, 91253, 91254, 91255,
    },
    NIGHTMARE_QUEST_IDS = {
        91211, 91213, 91215, 91217, 91219, 91221, 91223, 91225, 91227, 91229,
        91231, 91233, 91235, 91237, 91239, 91241, 91256, 91257, 91258, 91259,
        91260, 91261, 91262, 91263, 91264, 91265, 91266, 91267, 91268, 91269,
    },
    MAX_PER_WEEK     = 4,
    CURRENCY_ID      = 3392,  -- Remnant of Anguish
}

function DB:GetPreyProgress(difficulty)
    local questIDs
    if difficulty == "NORMAL" then questIDs = self.PREY.NORMAL_QUEST_IDS
    elseif difficulty == "HARD" then questIDs = self.PREY.HARD_QUEST_IDS
    elseif difficulty == "NIGHTMARE" then questIDs = self.PREY.NIGHTMARE_QUEST_IDS
    else return 0, self.PREY.MAX_PER_WEEK end

    local count = 0
    for _, qID in ipairs(questIDs) do
        local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, qID)
        if ok and done then count = count + 1 end
    end
    return count, self.PREY.MAX_PER_WEEK
end

function DB:IsPreyCapped(difficulty)
    local done, max = self:GetPreyProgress(difficulty)
    return done >= max
end

-- Returns the player's Prey renown rank (1-10), or 0 if not unlocked.
-- Uses C_MajorFactions.GetMajorFactionData(2764).
function DB:GetPreyRenownLevel()
    if not C_MajorFactions or not C_MajorFactions.GetMajorFactionData then return 0 end
    local ok, data = pcall(C_MajorFactions.GetMajorFactionData, self.PREY.FACTION_ID)
    if not ok or not data then return 0 end
    if not data.isUnlocked then return 0 end
    return data.renownLevel or 0
end

-- Returns prey features using quest-flag detection where available,
-- falling back to renown rank for features without confirmed quest IDs.
function DB:GetPreyFeatures()
    local rank = self:GetPreyRenownLevel()

    -- Quest-flag detection (most reliable)
    local hasNormal = false
    if self.PREY.UNLOCK_NORMAL then
        local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, self.PREY.UNLOCK_NORMAL)
        hasNormal = ok and done
    else
        hasNormal = rank >= 1
    end

    local hasHard = false
    if self.PREY.UNLOCK_HARD then
        local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, self.PREY.UNLOCK_HARD)
        hasHard = ok and done
    else
        hasHard = rank >= 2  -- fallback until quest ID confirmed
    end

    local hasNightmare = false
    if self.PREY.UNLOCK_NIGHTMARE then
        local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, self.PREY.UNLOCK_NIGHTMARE)
        hasNightmare = ok and done
    else
        hasNightmare = rank >= 4  -- fallback
    end

    local hasCustom = false
    if self.PREY.UNLOCK_CUSTOM then
        local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, self.PREY.UNLOCK_CUSTOM)
        hasCustom = ok and done
    end

    return {
        rank            = rank,
        isUnlocked      = hasNormal,
        hasHardMode     = hasHard,
        hasNightmare    = hasNightmare,
        hasCustomHunts  = hasCustom,
        hasTeleport     = hasHard,
        hasRandomHunts  = hasHard,
        preyPerZone     = hasNightmare and 3 or (hasHard and 2 or (hasNormal and 1 or 0)),
        totalBaseHunts  = hasNightmare and 12 or (hasHard and 8 or (hasNormal and 4 or 0)),
    }
end

-- ── PREY HUNT STATE (uses MagicPrey-discovered APIs) ────────
-- C_QuestLog.GetActivePreyQuest()  → questID or nil
-- C_UIWidgetManager.GetPowerBarWidgetSetID() → setID
-- C_UIWidgetManager.GetAllWidgetsBySetID(setID)
--   → look for widgetType == Enum.UIWidgetVisualizationType.PreyHuntProgress
-- C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo(widgetID)
--   → { shownState, progressState, tooltip }
-- progressState: Cold, Warm, Hot, Final/Found

-- Cached prey widget ID (scanned once per session)
DB._preyWidgetID = nil

function DB:ScanPreyWidget()
    self._preyWidgetID = nil
    if not C_UIWidgetManager or not C_UIWidgetManager.GetPowerBarWidgetSetID then return end

    local ok, setID = pcall(C_UIWidgetManager.GetPowerBarWidgetSetID)
    if not ok or not setID then return end

    local targetType = Enum and Enum.UIWidgetVisualizationType
        and Enum.UIWidgetVisualizationType.PreyHuntProgress
    if not targetType then return end

    local ok2, widgets = pcall(C_UIWidgetManager.GetAllWidgetsBySetID, setID)
    if not ok2 or not widgets then return end

    for _, w in ipairs(widgets) do
        if w.widgetType == targetType then
            self._preyWidgetID = w.widgetID
            return
        end
    end
end

-- Returns the active prey quest ID using the dedicated API,
-- falling back to scanning quest IDs if the API doesn't exist.
function DB:GetActivePreyQuest()
    -- Preferred: direct API (12.0+)
    if C_QuestLog.GetActivePreyQuest then
        local ok, questID = pcall(C_QuestLog.GetActivePreyQuest)
        if ok and questID and questID > 0 then
            return questID
        end
    end

    -- Fallback: scan known prey quest IDs
    local allIDs = {}
    for _, qID in ipairs(self.PREY.NORMAL_QUEST_IDS) do allIDs[#allIDs+1] = qID end
    for _, qID in ipairs(self.PREY.HARD_QUEST_IDS) do allIDs[#allIDs+1] = qID end
    for _, qID in ipairs(self.PREY.NIGHTMARE_QUEST_IDS) do allIDs[#allIDs+1] = qID end

    for _, qID in ipairs(allIDs) do
        local ok, onQuest = pcall(C_QuestLog.IsOnQuest, qID)
        if ok and onQuest then return qID end
    end

    return nil
end

-- Returns the mapID of the zone where the player has an active prey quest.
function DB:GetActivePreyZone()
    local questID = self:GetActivePreyQuest()
    if not questID then return nil end

    -- Try C_TaskQuest.GetQuestZoneID (works for prey quests)
    if C_TaskQuest and C_TaskQuest.GetQuestZoneID then
        local ok, zoneID = pcall(C_TaskQuest.GetQuestZoneID, questID)
        if ok and zoneID and zoneID > 0 then return zoneID end
    end

    -- Fallback: walk up from player map to find zone-level map
    local playerMap = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    while playerMap do
        local mapInfo = C_Map.GetMapInfo(playerMap)
        if not mapInfo then break end
        if mapInfo.mapType == (Enum and Enum.UIMapType and Enum.UIMapType.Zone) then
            return playerMap
        end
        playerMap = mapInfo.parentMapID
    end

    return nil
end

-- Returns the current prey hunt state.
-- { questID, questName, state, zone, isInZone, widgetTooltip }
-- state: nil (no hunt), "Cold", "Warm", "Hot", "Final" (found!), "Away" (out of zone)
function DB:GetPreyHuntState()
    local questID = self:GetActivePreyQuest()
    if not questID then return nil end

    local questName = nil
    pcall(function() questName = C_QuestLog.GetTitleForQuestID(questID) end)

    local zoneID = self:GetActivePreyZone()

    -- Scan for widget if not cached
    if not self._preyWidgetID then
        self:ScanPreyWidget()
    end

    -- Read widget state
    if self._preyWidgetID and C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo then
        local ok, info = pcall(
            C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo,
            self._preyWidgetID
        )
        if ok and info and info.shownState == 1 then
            local state = "Cold"
            local ps = info.progressState
            if ps == (Enum.PreyHuntProgressState and Enum.PreyHuntProgressState.Final)
                or ps == (Enum.PreyHuntProgressState and Enum.PreyHuntProgressState.Found) then
                state = "Final"
            elseif ps == (Enum.PreyHuntProgressState and Enum.PreyHuntProgressState.Hot) then
                state = "Hot"
            elseif ps == (Enum.PreyHuntProgressState and Enum.PreyHuntProgressState.Warm) then
                state = "Warm"
            end

            return {
                questID  = questID,
                questName = questName,
                state    = state,
                zone     = zoneID,
                isInZone = true,
                tooltip  = info.tooltip,
            }
        end
    end

    -- Widget not showing — player is out of zone or widget not loaded
    return {
        questID  = questID,
        questName = questName,
        state    = "Away",
        zone     = zoneID,
        isInZone = false,
        tooltip  = nil,
    }
end


-- ============================================================
-- SPECIAL ASSIGNMENTS (8 rotating weekly instanced content)
-- Each has a quest ID and an unlock gate quest ID.
-- ============================================================
DB.SPECIAL_ASSIGNMENTS = {
    { id = "sa_temple",    name = "Special Assignment: Temple",    questID = 91390, unlockID = 94865, mapID = 2395 },
    { id = "sa_ours",      name = "Special Assignment: Ours",      questID = 91796, unlockID = 94866, mapID = 2437 },
    { id = "sa_hunter",    name = "Special Assignment: Hunter",    questID = 92063, unlockID = 94390, mapID = 2413 },
    { id = "sa_shade",     name = "Special Assignment: Shade",     questID = 92139, unlockID = 95435, mapID = 2395 },
    { id = "sa_drink",     name = "Special Assignment: Drink",     questID = 92145, unlockID = 92848, mapID = 2393 },
    { id = "sa_push",      name = "Special Assignment: Push",      questID = 93013, unlockID = 94391, mapID = 2405 },
    { id = "sa_agents",    name = "Special Assignment: Agents",    questID = 93244, unlockID = 94795, mapID = 2405 },
    { id = "sa_precision", name = "Special Assignment: Precision", questID = 93438, unlockID = 94743, mapID = 2413 },
}

function DB:GetActiveSpecialAssignment()
    for _, sa in ipairs(self.SPECIAL_ASSIGNMENTS) do
        -- Check if unlock quest is in log (assignment is available)
        local ok1, inLog = pcall(C_QuestLog.IsOnQuest, sa.unlockID)
        -- Check if the main quest is in log
        local ok2, mainInLog = pcall(C_QuestLog.IsOnQuest, sa.questID)
        -- Check if completed
        local ok3, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, sa.questID)

        if (ok3 and done) then
            -- Already done this week, skip
        elseif (ok1 and inLog) or (ok2 and mainInLog) then
            return sa
        end
    end
    -- Fallback: check which assignment quest is flagged as a world quest this week
    for _, sa in ipairs(self.SPECIAL_ASSIGNMENTS) do
        local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, sa.questID)
        if not (ok and done) then
            -- Check if it's detectable via C_QuestLog
            if C_QuestLog.IsWorldQuest then
                local ok2, isWQ = pcall(C_QuestLog.IsWorldQuest, sa.questID)
                if ok2 and isWQ then return sa end
            end
        end
    end
    return nil
end


-- ============================================================
-- UNITY AGAINST THE VOID (UATV) — Weekly meta quest
-- 13 branch quests, gate quest 93744
-- ============================================================
DB.UATV = {
    GATE_QUEST = 93744,
    BRANCH_QUESTS = {
        93890,  -- UATV branch
        93767,  -- Arcantina meta
        94457,
        93909,  -- Midnight Delves
        93911,
        93769,  -- Housing meta
        93891,  -- Legends meta
        93910,
        93912,
        93889,  -- Soiree meta
        93892,  -- Stormarion meta
        93913,
        93766,  -- World Quests tracker
    },
}

function DB:GetUATVProgress()
    local done = 0
    local total = #self.UATV.BRANCH_QUESTS
    for _, qID in ipairs(self.UATV.BRANCH_QUESTS) do
        local ok, completed = pcall(C_QuestLog.IsQuestFlaggedCompleted, qID)
        if ok and completed then done = done + 1 end
    end
    return done, total
end

function DB:IsUATVGateComplete()
    local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, self.UATV.GATE_QUEST)
    return ok and done
end


-- ============================================================
-- DELVES — Bountiful delve detection via area POIs
-- ============================================================
DB.DELVES = {
    CALL_TO_DELVES   = 84776,
    MIDNIGHT_DELVES  = 93909,
    NULLAEUS         = 93525,
    BOUNTY_ITEM      = 233071,  -- Delver's Bounty

    -- All known delve POI IDs per zone (both normal and active variants).
    -- Bountiful status is detected via poi.description == "Bountiful Delve"
    -- or poi.atlasName containing "bountiful".
    ALL_POIS = {
        { mapID = 2395, poiIDs = { 8425, 8426, 8437, 8438 } },
        { mapID = 2405, poiIDs = { 8429, 8430, 8431, 8432 } },
        { mapID = 2413, poiIDs = { 8433, 8434, 8435, 8436 } },
        { mapID = 2437, poiIDs = { 8441, 8442, 8443, 8444 } },
    },
}

function DB:GetBountifulDelves()
    local bountiful = {}
    if not C_AreaPoiInfo or not C_AreaPoiInfo.GetAreaPOIInfo then return bountiful end

    local seen = {}  -- deduplicate by name
    for _, zone in ipairs(self.DELVES.ALL_POIS) do
        for _, poiID in ipairs(zone.poiIDs) do
            local ok, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, zone.mapID, poiID)
            if ok and info then
                -- Check if this delve is bountiful via description or atlasName
                local isBountiful = false
                if info.description and info.description:find("Bountiful") then
                    isBountiful = true
                elseif info.atlasName and info.atlasName:find("bountiful") then
                    isBountiful = true
                end

                if isBountiful and not seen[info.name] then
                    seen[info.name] = true
                    table.insert(bountiful, {
                        mapID   = zone.mapID,
                        x       = info.position and info.position.x or 0.5,
                        y       = info.position and info.position.y or 0.5,
                        name    = info.name or "Bountiful Delve",
                        poiID   = poiID,
                    })
                end
            end
        end
    end
    return bountiful
end


-- ============================================================
-- GREAT VAULT PROGRESS
-- Uses C_WeeklyRewards.GetActivities() to read slot progress.
-- Activity types: 1=dungeon, 3=raid, 4=world/delve
-- ============================================================
DB.VAULT_THRESHOLDS = {
    [1] = { 1, 4, 8 },   -- Dungeons: 1/4/8 for slots 1/2/3
    [3] = { 2, 4, 6 },   -- Raids: 2/4/6
    [4] = { 2, 4, 8 },   -- World/Delve: 2/4/8
}

function DB:GetVaultProgress()
    local result = {}
    if not C_WeeklyRewards or not C_WeeklyRewards.GetActivities then return result end

    for _, actType in ipairs({1, 3, 4}) do
        local ok, activities = pcall(C_WeeklyRewards.GetActivities, actType)
        if ok and activities then
            local thresholds = self.VAULT_THRESHOLDS[actType] or {1, 4, 8}
            local slotsUnlocked = 0
            local progress = 0
            local nextThreshold = thresholds[1]
            for _, act in ipairs(activities) do
                if act.progress and act.progress > 0 then
                    progress = math.max(progress, act.progress)
                end
            end
            for i, thresh in ipairs(thresholds) do
                if progress >= thresh then
                    slotsUnlocked = i
                else
                    nextThreshold = thresh
                    break
                end
            end
            result[actType] = {
                progress       = progress,
                slotsUnlocked  = slotsUnlocked,
                nextThreshold  = slotsUnlocked < 3 and nextThreshold or nil,
                remaining      = slotsUnlocked < 3 and (nextThreshold - progress) or 0,
            }
        end
    end
    return result
end

-- Returns how many more world/delve activities are needed for next vault slot (0 if all done)
function DB:GetVaultWorldRemaining()
    local vault = self:GetVaultProgress()
    local world = vault[4]
    if not world then return 0 end
    return world.remaining or 0
end


-- ============================================================
-- RENOWN AWARENESS
-- Uses C_MajorFactions to check renown levels.
-- ============================================================
DB.MAJOR_FACTIONS = {
    { id = 2710, name = "Silvermoon Court", maxRenown = 20 },
    { id = 2696, name = "Amani Tribe",     maxRenown = 20 },
    { id = 2704, name = "Hara'ti",         maxRenown = 20 },
    { id = 2699, name = "The Singularity",  maxRenown = 20 },
}

function DB:GetRenownInfo(factionID)
    if not C_MajorFactions or not C_MajorFactions.GetMajorFactionData then
        return nil
    end
    local ok, data = pcall(C_MajorFactions.GetMajorFactionData, factionID)
    if not ok or not data then return nil end
    local isMax = false
    if C_MajorFactions.HasMaximumRenown then
        pcall(function() isMax = C_MajorFactions.HasMaximumRenown(factionID) end)
    end
    return {
        name       = data.name,
        renownLevel = data.renownLevel,
        isMaxed    = isMax,
    }
end

function DB:IsFactionMaxed(factionID)
    local info = self:GetRenownInfo(factionID)
    return info and info.isMaxed or false
end


-- ============================================================
-- CURRENCY CAP READING
-- Reads weekly progress on capped currencies to inform routing.
-- ============================================================
function DB:GetCurrencyProgress(currencyID)
    if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then return nil end
    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
    if not ok or not info then return nil end
    return {
        quantity     = info.quantity or 0,
        maxQuantity  = info.maxQuantity or 0,
        totalEarned  = info.totalEarned or 0,
        useTotalEarnedForMaxQty = info.useTotalEarnedForMaxQty,
        isCapped     = info.maxQuantity and info.maxQuantity > 0 and info.quantity >= info.maxQuantity,
    }
end

-- Returns true if weekly crest cap is reached for a given tier
function DB:IsCrestCapped(crestCurrencyID)
    local prog = self:GetCurrencyProgress(crestCurrencyID)
    return prog and prog.isCapped or false
end


-- ============================================================
-- RARE MOBS — weekly kill quests, from HandyNotes_Midnight
-- Coordinates converted from XXYYYYYY packed format to 0-1 normalized.
-- Each rare has a kill questID (weekly reset) and rep questID.
-- ============================================================
DB.RARES = {
    -- EVERSONG WOODS (achievement 61507, rep faction 2710)
    { name = "Warden of Weeds",          mapID = 2395, x = 0.519, y = 0.738, questID = 91280, repQuestID = 94681 },
    { name = "Harried Hawkstrider",      mapID = 2395, x = 0.451, y = 0.783, questID = 91315, repQuestID = 94682 },
    { name = "Overfester Hydra",         mapID = 2395, x = 0.547, y = 0.602, questID = 92392, repQuestID = 94684 },
    { name = "Bloated Snapdragon",       mapID = 2395, x = 0.366, y = 0.641, questID = 92366, repQuestID = 94685 },
    { name = "Cre'van",                  mapID = 2395, x = 0.627, y = 0.491, questID = 92391, repQuestID = 94686 },
    { name = "Coralfang",               mapID = 2395, x = 0.364, y = 0.364, questID = 92389, repQuestID = 94687 },
    { name = "Lady Liminus",            mapID = 2395, x = 0.367, y = 0.772, questID = 92393, repQuestID = 94688 },
    { name = "Terrinor",                mapID = 2395, x = 0.402, y = 0.854, questID = 92409, repQuestID = 94689 },
    { name = "Bad Zed",                 mapID = 2395, x = 0.491, y = 0.878, questID = 92404, repQuestID = 94690 },
    { name = "Waverly",                 mapID = 2395, x = 0.348, y = 0.210, questID = 92395, repQuestID = 94691 },
    { name = "Banuran",                 mapID = 2395, x = 0.564, y = 0.776, questID = 92403, repQuestID = 94692 },
    { name = "Lost Guardian",           mapID = 2395, x = 0.592, y = 0.792, questID = 92399, repQuestID = 94693 },
    { name = "Duskburn",                mapID = 2395, x = 0.423, y = 0.689, questID = 93550, repQuestID = 94694 },
    { name = "Malfunctioning Construct", mapID = 2395, x = 0.517, y = 0.460, questID = 93555, repQuestID = 94695 },
    { name = "Dame Bloodshed",          mapID = 2395, x = 0.450, y = 0.386, questID = 93561, repQuestID = 94696 },

    -- ZUL'AMAN (achievement 62122, rep faction 2696)
    { name = "Kha'reen",            mapID = 2437, x = 0.400, y = 0.510, questID = 89569 },
    { name = "Taz'zani",            mapID = 2437, x = 0.477, y = 0.533, questID = 89571 },
    { name = "Umbravex",            mapID = 2437, x = 0.305, y = 0.848, questID = 91174 },
    { name = "Murkblood",           mapID = 2437, x = 0.531, y = 0.545, questID = 89578 },
    { name = "Zaela",               mapID = 2437, x = 0.430, y = 0.395, questID = 89580 },
    { name = "Hex Lord Raal",       mapID = 2437, x = 0.297, y = 0.849, questID = 89583 },
    { name = "Maisara",             mapID = 2437, x = 0.430, y = 0.440, questID = 89573 },
    { name = "Goldenmane",          mapID = 2437, x = 0.532, y = 0.545, questID = 91073 },
    { name = "Zek'voz",             mapID = 2437, x = 0.355, y = 0.788, questID = 89570 },
    { name = "Nalorakk's Ghost",    mapID = 2437, x = 0.304, y = 0.847, questID = 89575 },
    { name = "Spiritspeaker",       mapID = 2437, x = 0.450, y = 0.500, questID = 91634 },
    { name = "Thornlash",           mapID = 2437, x = 0.520, y = 0.600, questID = 89579 },
    { name = "Vilebranch Berserker", mapID = 2437, x = 0.480, y = 0.520, questID = 89581 },
    { name = "Ashwalker",           mapID = 2437, x = 0.400, y = 0.450, questID = 89572 },
    { name = "Bonesplitter",        mapID = 2437, x = 0.350, y = 0.800, questID = 91072 },

    -- HARANDAR (achievement 61264, rep faction 2704)
    { name = "Rootwalker",       mapID = 2413, x = 0.542, y = 0.530, questID = 91832 },
    { name = "Thornweaver",      mapID = 2413, x = 0.545, y = 0.351, questID = 92142 },
    { name = "Duskhollow",       mapID = 2413, x = 0.500, y = 0.500, questID = 92154 },
    { name = "Bloomstalker",     mapID = 2413, x = 0.480, y = 0.420, questID = 92168 },
    { name = "Tangleclaw",       mapID = 2413, x = 0.520, y = 0.480, questID = 92172 },
    { name = "Luminshade",       mapID = 2413, x = 0.560, y = 0.380, questID = 92183 },
    { name = "Sporeguard",       mapID = 2413, x = 0.500, y = 0.550, questID = 92191 },
    { name = "Petalfury",        mapID = 2413, x = 0.470, y = 0.460, questID = 92194 },
    { name = "Vinelasher",       mapID = 2413, x = 0.540, y = 0.400, questID = 92137 },
    { name = "Mosscreep",        mapID = 2413, x = 0.490, y = 0.520, questID = 92148 },
    { name = "Bramblethorn",     mapID = 2413, x = 0.530, y = 0.440, questID = 92161 },
    { name = "Witherbark Elder", mapID = 2413, x = 0.510, y = 0.490, questID = 92170 },
    { name = "Gloomfang",        mapID = 2413, x = 0.460, y = 0.540, questID = 92176 },
    { name = "Dreadbough",       mapID = 2413, x = 0.550, y = 0.360, questID = 92190 },
    { name = "Nettlesting",      mapID = 2413, x = 0.480, y = 0.500, questID = 92193 },

    -- VOIDSTORM (achievement 62130, rep faction 2699)
    { name = "Voidtouched Horror",  mapID = 2405, x = 0.264, y = 0.676, questID = 90805 },
    { name = "Stormrager",          mapID = 2405, x = 0.650, y = 0.617, questID = 91048 },
    { name = "Void Sentinel",       mapID = 2405, x = 0.514, y = 0.185, questID = 93946 },
    { name = "Shadow Infuser",      mapID = 2405, x = 0.455, y = 0.423, questID = 93947 },
    { name = "Nullweaver",          mapID = 2405, x = 0.500, y = 0.500, questID = 93895 },
    { name = "Darkstorm",           mapID = 2405, x = 0.480, y = 0.550, questID = 93884 },
    { name = "Riftwalker",          mapID = 2405, x = 0.520, y = 0.450, questID = 91051 },
    { name = "Voidclaw",            mapID = 2405, x = 0.540, y = 0.600, questID = 91050 },
    { name = "Entropy Maw",         mapID = 2405, x = 0.460, y = 0.400, questID = 93966 },
    { name = "Twilight Devourer",   mapID = 2405, x = 0.490, y = 0.520, questID = 93944 },
    { name = "Nether Wraith",       mapID = 2405, x = 0.530, y = 0.480, questID = 93934 },
    { name = "Shatterscale",        mapID = 2405, x = 0.510, y = 0.560, questID = 93953 },
    { name = "Voidbinder",          mapID = 2405, x = 0.470, y = 0.440, questID = 91047 },
    { name = "Eclipse Herald",      mapID = 2405, x = 0.550, y = 0.500, questID = 93896 },
}

function DB:GetUnkilledRares(mapID)
    local unkilled = {}
    for _, rare in ipairs(self.RARES) do
        if not mapID or rare.mapID == mapID then
            local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, rare.questID)
            if not (ok and done) then
                table.insert(unkilled, rare)
            end
        end
    end
    return unkilled
end

function DB:GetRareProgress(mapID)
    local total, done = 0, 0
    for _, rare in ipairs(self.RARES) do
        if not mapID or rare.mapID == mapID then
            total = total + 1
            local ok, completed = pcall(C_QuestLog.IsQuestFlaggedCompleted, rare.questID)
            if ok and completed then done = done + 1 end
        end
    end
    return done, total
end


-- ============================================================
-- HOUSING DECOR TREASURES — neighborhood decor blueprint locations
-- Map IDs: 2352 = Founder's Point (Alliance), 2351 = Razorwind Shores (Horde)
-- From BetterHomes reference data.
-- ============================================================
DB.DECOR_MAPS = {
    FOUNDERS_POINT  = 2352,
    RAZORWIND       = 2351,
}

-- Decor entries: { questID, mapID, x, y, name }
-- Populated dynamically from C_QuestLog since there are ~40-50 per neighborhood
-- and the data is neighborhood-specific. We detect available decor quests in the
-- neighborhood when the player is inside.
function DB:GetAvailableDecor()
    local results = {}
    local playerMapID = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not playerMapID then return results end

    -- Only scan if we're in a housing neighborhood
    if playerMapID ~= self.DECOR_MAPS.FOUNDERS_POINT
        and playerMapID ~= self.DECOR_MAPS.RAZORWIND then
        return results
    end

    -- Use C_QuestLog.GetQuestsOnMap for the neighborhood map
    if C_QuestLog and C_QuestLog.GetQuestsOnMap then
        local ok, quests = pcall(C_QuestLog.GetQuestsOnMap, playerMapID)
        if ok and quests then
            for _, qi in ipairs(quests) do
                local qID = qi.questID or qi.questId
                if qID then
                    local completed = false
                    pcall(function() completed = C_QuestLog.IsQuestFlaggedCompleted(qID) end)
                    if not completed then
                        local title = ""
                        pcall(function() title = C_QuestLog.GetTitleForQuestID(qID) or "" end)
                        table.insert(results, {
                            questID = qID,
                            mapID   = playerMapID,
                            x       = qi.x or 0.5,
                            y       = qi.y or 0.5,
                            name    = title ~= "" and title or ("Decor #" .. qID),
                        })
                    end
                end
            end
        end
    end

    return results
end


-- ============================================================
-- PROFESSION KNOWLEDGE — treasures, studies, weekly quests, hub locations
-- Data from MidnightRoutine/ProfessionKnowledge.lua + Professions.lua
-- ============================================================
DB.PROF_HUB = {
    crafting   = { mapID = 2393, x = 0.450, y = 0.552 },
    treatise   = { mapID = 2393, x = 0.450, y = 0.556 },
    enchanting = { mapID = 2393, x = 0.478, y = 0.538 },
    herbalism  = { mapID = 2393, x = 0.483, y = 0.514 },
    mining     = { mapID = 2393, x = 0.426, y = 0.528 },
    skinning   = { mapID = 2393, x = 0.432, y = 0.556 },
}

DB.PROFESSIONS = {
    { key = "alchemy", skillLine = 2906, catchupCurrency = 3189, treasures = {
        { questID = 89117, mapID = 2393, x = 0.478, y = 0.516, kp = 3 },
        { questID = 89115, mapID = 2393, x = 0.491, y = 0.756, kp = 3 },
        { questID = 89111, mapID = 2393, x = 0.451, y = 0.448, kp = 3 },
        { questID = 89114, mapID = 2437, x = 0.404, y = 0.510, kp = 3 },
        { questID = 89116, mapID = 2536, x = 0.491, y = 0.231, kp = 3 },
        { questID = 89113, mapID = 2413, x = 0.347, y = 0.247, kp = 3 },
        { questID = 89112, mapID = 2405, x = 0.418, y = 0.405, kp = 3 },
        { questID = 89118, mapID = 2405, x = 0.328, y = 0.433, kp = 3 },
    }, studies = {
        { questID = 93794, mapID = 2405, x = 0.526, y = 0.729, kp = 10 },
    }, weekly = { notebook = { 93690 }, drops = { 93528, 93529 }, treatise = 95127 } },

    { key = "blacksmithing", skillLine = 2907, catchupCurrency = 3199, treasures = {
        { questID = 89183, mapID = 2393, x = 0.493, y = 0.613, kp = 3 },
        { questID = 89184, mapID = 2393, x = 0.485, y = 0.748, kp = 3 },
        { questID = 89177, mapID = 2393, x = 0.269, y = 0.603, kp = 3 },
        { questID = 89180, mapID = 2395, x = 0.568, y = 0.407, kp = 3 },
        { questID = 89178, mapID = 2395, x = 0.483, y = 0.757, kp = 3 },
        { questID = 89179, mapID = 2536, x = 0.332, y = 0.658, kp = 3 },
        { questID = 89182, mapID = 2413, x = 0.663, y = 0.508, kp = 3 },
        { questID = 89181, mapID = 2405, x = 0.306, y = 0.689, kp = 3 },
    }, studies = {
        { questID = 93795, mapID = 2405, x = 0.526, y = 0.729, kp = 10 },
    }, weekly = { notebook = { 93691 }, drops = { 93530, 93531 }, treatise = 95128 } },

    { key = "enchanting", skillLine = 2909, catchupCurrency = 3198, treasures = {
        { questID = 89107, mapID = 2395, x = 0.634, y = 0.326, kp = 3 },
        { questID = 89103, mapID = 2395, x = 0.608, y = 0.531, kp = 3 },
        { questID = 89101, mapID = 2395, x = 0.402, y = 0.612, kp = 3 },
        { questID = 89106, mapID = 2437, x = 0.404, y = 0.512, kp = 3 },
        { questID = 89100, mapID = 2536, x = 0.491, y = 0.227, kp = 3 },
        { questID = 89105, mapID = 2413, x = 0.658, y = 0.502, kp = 3 },
        { questID = 89104, mapID = 2413, x = 0.377, y = 0.653, kp = 3 },
        { questID = 89102, mapID = 2405, x = 0.355, y = 0.588, kp = 3 },
    }, studies = {
        { questID = 92374, mapID = 2395, x = 0.434, y = 0.474, kp = 10 },
        { questID = 92186, mapID = 2437, x = 0.316, y = 0.263, kp = 10 },
    }, weekly = { notebook = { 93697, 93698, 93699 }, drops = { 93532, 93533 }, treatise = 95129 } },

    { key = "engineering", skillLine = 2910, catchupCurrency = 3197, treasures = {
        { questID = 89139, mapID = 2393, x = 0.512, y = 0.571, kp = 3 },
        { questID = 89133, mapID = 2393, x = 0.514, y = 0.746, kp = 3 },
        { questID = 89135, mapID = 2395, x = 0.395, y = 0.458, kp = 3 },
        { questID = 89138, mapID = 2536, x = 0.651, y = 0.345, kp = 3 },
        { questID = 89140, mapID = 2437, x = 0.342, y = 0.879, kp = 3 },
        { questID = 89136, mapID = 2413, x = 0.679, y = 0.498, kp = 3 },
        { questID = 89137, mapID = 2405, x = 0.540, y = 0.510, kp = 3 },
        { questID = 89134, mapID = 2405, x = 0.290, y = 0.392, kp = 3 },
    }, studies = {
        { questID = 93796, mapID = 2405, x = 0.526, y = 0.729, kp = 10 },
    }, weekly = { notebook = { 93692 }, drops = { 93534, 93535 }, treatise = 95138 } },

    { key = "herbalism", skillLine = 2912, catchupCurrency = 3196, treasures = {
        { questID = 89160, mapID = 2393, x = 0.490, y = 0.758, kp = 3 },
        { questID = 89158, mapID = 2395, x = 0.642, y = 0.304, kp = 3 },
        { questID = 89161, mapID = 2437, x = 0.419, y = 0.459, kp = 3 },
        { questID = 89157, mapID = 2437, x = 0.418, y = 0.459, kp = 3 },
        { questID = 89155, mapID = 2413, x = 0.511, y = 0.557, kp = 3 },
        { questID = 89162, mapID = 2413, x = 0.381, y = 0.669, kp = 3 },
        { questID = 89159, mapID = 2413, x = 0.366, y = 0.250, kp = 3 },
        { questID = 89156, mapID = 2405, x = 0.346, y = 0.570, kp = 3 },
    }, studies = {
        { questID = 93411, mapID = 2413, x = 0.510, y = 0.508, kp = 10 },
        { questID = 92174, mapID = 2437, x = 0.316, y = 0.263, kp = 10 },
    }, weekly = { notebook = { 93700, 93701, 93702, 93703, 93704 }, drops = { 81425, 81426, 81427, 81428, 81429 }, bonusDrop = 81430, treatise = 95130 } },

    { key = "inscription", skillLine = 2913, catchupCurrency = 3195, treasures = {
        { questID = 89073, mapID = 2393, x = 0.477, y = 0.503, kp = 3 },
        { questID = 89074, mapID = 2395, x = 0.404, y = 0.613, kp = 3 },
        { questID = 89072, mapID = 2395, x = 0.393, y = 0.454, kp = 3 },
        { questID = 89069, mapID = 2395, x = 0.483, y = 0.756, kp = 3 },
        { questID = 89068, mapID = 2437, x = 0.405, y = 0.494, kp = 3 },
        { questID = 89070, mapID = 2413, x = 0.524, y = 0.526, kp = 3 },
        { questID = 89071, mapID = 2413, x = 0.527, y = 0.500, kp = 3 },
        { questID = 89067, mapID = 2405, x = 0.607, y = 0.841, kp = 3 },
    }, studies = {
        { questID = 93412, mapID = 2413, x = 0.510, y = 0.508, kp = 10 },
    }, weekly = { notebook = { 93693 }, drops = { 93536, 93537 }, treatise = 95131 } },

    { key = "jewelcrafting", skillLine = 2914, catchupCurrency = 3194, treasures = {
        { questID = 89122, mapID = 2393, x = 0.506, y = 0.565, kp = 3 },
        { questID = 89127, mapID = 2393, x = 0.555, y = 0.480, kp = 3 },
        { questID = 89124, mapID = 2393, x = 0.286, y = 0.465, kp = 3 },
        { questID = 89125, mapID = 2395, x = 0.567, y = 0.409, kp = 3 },
        { questID = 89129, mapID = 2395, x = 0.397, y = 0.388, kp = 3 },
        { questID = 89123, mapID = 2405, x = 0.306, y = 0.690, kp = 3 },
        { questID = 89128, mapID = 2405, x = 0.542, y = 0.512, kp = 3 },
        { questID = 89126, mapID = 2405, x = 0.629, y = 0.535, kp = 3 },
    }, studies = {
        { questID = 93222, mapID = 2395, x = 0.434, y = 0.474, kp = 10 },
    }, weekly = { notebook = { 93694 }, drops = { 93538, 93539 }, treatise = 95133 } },

    { key = "leatherworking", skillLine = 2915, catchupCurrency = 3193, treasures = {
        { questID = 89096, mapID = 2393, x = 0.448, y = 0.562, kp = 3 },
        { questID = 89092, mapID = 2536, x = 0.452, y = 0.453, kp = 3 },
        { questID = 89089, mapID = 2437, x = 0.331, y = 0.789, kp = 3 },
        { questID = 89091, mapID = 2437, x = 0.308, y = 0.841, kp = 3 },
        { questID = 89090, mapID = 2405, x = 0.348, y = 0.569, kp = 3 },
        { questID = 89094, mapID = 2413, x = 0.518, y = 0.513, kp = 3 },
        { questID = 89095, mapID = 2413, x = 0.361, y = 0.252, kp = 3 },
        { questID = 89093, mapID = 2405, x = 0.538, y = 0.516, kp = 3 },
    }, studies = {
        { questID = 92371, mapID = 2437, x = 0.458, y = 0.658, kp = 10 },
    }, weekly = { notebook = { 93695 }, drops = { 93540, 93541 }, treatise = 95134 } },

    { key = "mining", skillLine = 2916, catchupCurrency = 3192, treasures = {
        { questID = 89147, mapID = 2395, x = 0.380, y = 0.453, kp = 3 },
        { questID = 89145, mapID = 2437, x = 0.419, y = 0.463, kp = 3 },
        { questID = 89151, mapID = 2413, x = 0.388, y = 0.659, kp = 3 },
        { questID = 89149, mapID = 2536, x = 0.336, y = 0.660, kp = 3 },
        { questID = 89150, mapID = 2405, x = 0.418, y = 0.382, kp = 3 },
        { questID = 89148, mapID = 2405, x = 0.287, y = 0.386, kp = 3 },
        { questID = 89146, mapID = 2405, x = 0.542, y = 0.516, kp = 3 },
        { questID = 89144, mapID = 2405, x = 0.300, y = 0.690, kp = 3 },
    }, studies = {
        { questID = 92372, mapID = 2437, x = 0.458, y = 0.658, kp = 10 },
        { questID = 92187, mapID = 2437, x = 0.316, y = 0.263, kp = 10 },
    }, weekly = { notebook = { 93705, 93706, 93707, 93708, 93709 }, drops = { 88673, 88674, 88675, 88676, 88677 }, bonusDrop = 88678, treatise = 95135 } },

    { key = "skinning", skillLine = 2917, catchupCurrency = 3191, treasures = {
        { questID = 89171, mapID = 2393, x = 0.432, y = 0.557, kp = 3 },
        { questID = 89173, mapID = 2395, x = 0.485, y = 0.762, kp = 3 },
        { questID = 89170, mapID = 2437, x = 0.404, y = 0.360, kp = 3 },
        { questID = 89172, mapID = 2437, x = 0.331, y = 0.790, kp = 3 },
        { questID = 89167, mapID = 2536, x = 0.450, y = 0.447, kp = 3 },
        { questID = 89168, mapID = 2413, x = 0.695, y = 0.492, kp = 3 },
        { questID = 89166, mapID = 2413, x = 0.760, y = 0.510, kp = 3 },
        { questID = 89169, mapID = 2405, x = 0.442, y = 0.460, kp = 3 },
    }, studies = {
        { questID = 92373, mapID = 2437, x = 0.458, y = 0.658, kp = 10 },
        { questID = 92188, mapID = 2437, x = 0.316, y = 0.263, kp = 10 },
    }, weekly = { notebook = { 93710, 93711, 93712, 93713, 93714 }, drops = { 88534, 88549, 88536, 88537, 88530 }, bonusDrop = 88529, treatise = 95136 } },

    { key = "tailoring", skillLine = 2918, catchupCurrency = 3190, treasures = {
        { questID = 89079, mapID = 2393, x = 0.358, y = 0.612, kp = 3 },
        { questID = 89084, mapID = 2393, x = 0.317, y = 0.682, kp = 3 },
        { questID = 89080, mapID = 2395, x = 0.463, y = 0.348, kp = 3 },
        { questID = 89085, mapID = 2437, x = 0.404, y = 0.494, kp = 3 },
        { questID = 89078, mapID = 2413, x = 0.705, y = 0.508, kp = 3 },
        { questID = 89081, mapID = 2413, x = 0.698, y = 0.510, kp = 3 },
        { questID = 89082, mapID = 2405, x = 0.619, y = 0.837, kp = 3 },
        { questID = 89083, mapID = 2405, x = 0.614, y = 0.850, kp = 3 },
    }, studies = {
        { questID = 93201, mapID = 2395, x = 0.434, y = 0.474, kp = 10 },
    }, weekly = { notebook = { 93696 }, drops = { 93542, 93543 }, treatise = 95137 } },
}

-- Skinning daily lures (reset daily, not weekly)
DB.SKINNING_LURES = {
    { key = "eversong",  questID = 88545, mapID = 2395, x = 0.4195, y = 0.8005 },
    { key = "zulaman",   questID = 88526, mapID = 2437, x = 0.4769, y = 0.5325, lureItemID = 238653 },
    { key = "harandar",  questID = 88531, mapID = 2413, x = 0.6628, y = 0.4791, lureItemID = 238654 },
    { key = "voidstorm", questID = 88532, mapID = 2405, x = 0.5460, y = 0.6580, lureItemID = 238655 },
    { key = "grand",     questID = 88524, mapID = 2405, x = 0.4325, y = 0.8275, lureItemID = 238656 },
}

-- Returns the player's known profession skill line IDs.
-- Uses GetProfessions() + GetProfessionInfo() API.
-- Base profession skillLine → Midnight expansion skillLine mapping.
-- GetProfessionInfo returns the base ID (e.g. 165 for Leatherworking).
-- Our PROFESSIONS table uses Midnight IDs (e.g. 2915).
local BASE_TO_MIDNIGHT_SKILLLINE = {
    [171] = 2906,  -- Alchemy
    [164] = 2907,  -- Blacksmithing
    [333] = 2909,  -- Enchanting
    [202] = 2910,  -- Engineering
    [182] = 2912,  -- Herbalism
    [773] = 2913,  -- Inscription
    [755] = 2914,  -- Jewelcrafting
    [165] = 2915,  -- Leatherworking
    [186] = 2916,  -- Mining
    [393] = 2917,  -- Skinning
    [197] = 2918,  -- Tailoring
}

function DB:GetPlayerProfessions()
    local result = {}
    if not GetProfessions then return result end
    local prof1, prof2 = GetProfessions()
    for _, idx in ipairs({ prof1, prof2 }) do
        if idx then
            local ok, name, icon, skillLevel, maxSkillLevel, numAbilities, spelloffset, skillLine = pcall(GetProfessionInfo, idx)
            if ok and skillLine then
                -- Map base skillLine to Midnight expansion skillLine
                local midnightSL = BASE_TO_MIDNIGHT_SKILLLINE[skillLine]
                if midnightSL then
                    table.insert(result, midnightSL)
                end
            end
        end
    end
    return result
end

-- Returns uncollected treasures + studies for the player's professions.
function DB:GetUncollectedProfTreasures()
    local playerProfs = self:GetPlayerProfessions()
    if #playerProfs == 0 then return {} end

    local profSet = {}
    for _, sl in ipairs(playerProfs) do profSet[sl] = true end

    local results = {}
    for _, prof in ipairs(self.PROFESSIONS) do
        if profSet[prof.skillLine] then
            -- Treasures (one-time, 3 KP each)
            for _, t in ipairs(prof.treasures) do
                local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, t.questID)
                if not (ok and done) then
                    table.insert(results, {
                        questID  = t.questID,
                        mapID    = t.mapID,
                        x        = t.x,
                        y        = t.y,
                        kp       = t.kp,
                        profKey  = prof.key,
                        kind     = "treasure",
                    })
                end
            end
            -- Studies (one-time, 10 KP each)
            for _, s in ipairs(prof.studies) do
                local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, s.questID)
                if not (ok and done) then
                    table.insert(results, {
                        questID  = s.questID,
                        mapID    = s.mapID,
                        x        = s.x,
                        y        = s.y,
                        kp       = s.kp,
                        profKey  = prof.key,
                        kind     = "study",
                    })
                end
            end
        end
    end
    return results
end

-- Returns incomplete weekly profession quests for the player's professions.
function DB:GetIncompleteProfWeeklies()
    local playerProfs = self:GetPlayerProfessions()
    if #playerProfs == 0 then return {} end

    local profSet = {}
    for _, sl in ipairs(playerProfs) do profSet[sl] = true end

    local results = {}
    for _, prof in ipairs(self.PROFESSIONS) do
        if profSet[prof.skillLine] and prof.weekly then
            -- Notebook/service quest (pick one)
            local notebookDone = false
            for _, qID in ipairs(prof.weekly.notebook or {}) do
                local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, qID)
                if ok and done then notebookDone = true; break end
            end
            if not notebookDone then
                -- Determine hub location based on profession type
                local hub = self.PROF_HUB.crafting
                if prof.key == "enchanting" then hub = self.PROF_HUB.enchanting
                elseif prof.key == "herbalism" then hub = self.PROF_HUB.herbalism
                elseif prof.key == "mining" then hub = self.PROF_HUB.mining
                elseif prof.key == "skinning" then hub = self.PROF_HUB.skinning end

                table.insert(results, {
                    profKey = prof.key,
                    kind    = "notebook",
                    mapID   = hub.mapID,
                    x       = hub.x,
                    y       = hub.y,
                    questIDs = prof.weekly.notebook,
                })
            end

            -- Treatise
            if prof.weekly.treatise then
                local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, prof.weekly.treatise)
                if not (ok and done) then
                    table.insert(results, {
                        profKey = prof.key,
                        kind    = "treatise",
                        mapID   = self.PROF_HUB.treatise.mapID,
                        x       = self.PROF_HUB.treatise.x,
                        y       = self.PROF_HUB.treatise.y,
                        questID = prof.weekly.treatise,
                    })
                end
            end
        end
    end
    return results
end


-- ============================================================
-- DUNGEON DATABASE
-- ============================================================
DB.DUNGEONS = {
    {
        id             = "windrunner_spire",
        name           = "Windrunner Spire",
        mapID          = 2395,
        entranceCoords = { x = 0.355, y = 0.788 },
        weeklyQuestID  = 93751,
        season1        = true,
        normalOnly     = false,
        notes          = "South Eversong, above Ruins of Deatholme.",
    },
    {
        id             = "murder_row",
        name           = "Murder Row",
        mapID          = 2393,
        entranceCoords = { x = 0.570, y = 0.610 },
        weeklyQuestID  = 93752,
        season1        = false,
        normalOnly     = true,
        notes          = "East Silvermoon, above Astalor's Sanctum. Normal only.",
    },
    {
        id             = "magisters_terrace",
        name           = "Magisters' Terrace",
        mapID          = 2536,
        entranceCoords = { x = 0.352, y = 0.784 },
        weeklyQuestID  = 93753,
        season1        = true,
        normalOnly     = false,
        notes          = "Isle of Quel'Danas. Season 1 M+ rotation.",
    },
    {
        id             = "maisara_caverns",
        name           = "Maisara Caverns",
        mapID          = 2437,
        entranceCoords = { x = 0.430, y = 0.395 },
        weeklyQuestID  = 93754,
        season1        = true,
        normalOnly     = false,
        notes          = "Northern Zul'Aman, Maisara Deeps. Season 1 M+ rotation.",
    },
    {
        id             = "den_of_nalorakk",
        name           = "Den of Nalorakk",
        mapID          = 2437,
        entranceCoords = { x = 0.297, y = 0.849 },
        weeklyQuestID  = 93755,
        season1        = false,
        normalOnly     = true,
        notes          = "South Zul'Aman, shrine of Nalorakk. Normal only.",
    },
    {
        id             = "the_blinding_vale",
        name           = "The Blinding Vale",
        mapID          = 2413,
        entranceCoords = { x = 0.500, y = 0.500 },
        weeklyQuestID  = 93756,
        season1        = false,
        normalOnly     = true,
        notes          = "Inside The Blinding Bloom, Harandar. Normal only.",
    },
    {
        id             = "nexus_point_xenas",
        name           = "Nexus-Point Xenas",
        mapID          = 2405,
        entranceCoords = { x = 0.650, y = 0.617 },
        weeklyQuestID  = 93757,
        season1        = true,
        normalOnly     = false,
        notes          = "East Voidstorm. Season 1 M+ rotation.",
    },
    {
        id             = "voidscar_arena",
        name           = "Voidscar Arena",
        mapID          = 2405,
        entranceCoords = { x = 0.514, y = 0.185 },
        weeklyQuestID  = 93758,
        season1        = false,
        normalOnly     = true,
        notes          = "North Voidstorm, Slayer's Rise. Normal only.",
    },
}

-- Build lookups
DB.DUNGEON_BY_QUEST = {}
DB.ALL_DUNGEON_QUEST_IDS = {}
for _, d in ipairs(DB.DUNGEONS) do
    if d.weeklyQuestID then
        DB.DUNGEON_BY_QUEST[d.weeklyQuestID] = d
        table.insert(DB.ALL_DUNGEON_QUEST_IDS, d.weeklyQuestID)
    end
end


-- ============================================================
-- HOUSING DATABASE
-- ============================================================
DB.HOUSING = {
    META_QUEST           = 93769,
    LANDSCAPE_PHOTO      = 92608,
    DECOR_TREASURE_HUNT  = 93088,
    DECOR_TREASURE_HUNT_ALT = 92975,
    ROTATING_WEEKLY_V1   = 93780,
    WORLD_QUESTS_TRACKER_FALSE_POSITIVE = 93766,
    COMMUNITY_COUPONS_CURRENCY = 3363,

    NEIGHBORHOODS = {
        founders_point = {
            name   = "Founder's Point",
            faction= "Alliance",
            mapID  = 2393,
            x = 0.28, y = 0.35,
            notes  = "Alliance neighborhood. Enter via portal behind Cathedral district.",
        },
        razorwind_shores = {
            name   = "Razorwind Shores",
            faction= "Horde",
            mapID  = 2395,
            x = 0.72, y = 0.88,
            notes  = "Horde neighborhood. Ghostlands coastline. Verify coords in-game.",
        },
    },

    KNOWN_THEMES = {
        "Blood Elf", "Dracthyr", "Grummle", "Mechagon", "K'areshi", "Loamm Niffen",
    },
}


-- ============================================================
-- SOIREE HELPERS
-- ============================================================
local SILVERMOON_COURT_RENOWN_CURRENCY_ID = 3371

function DB:GetTokenCount()
    local inBag = 0
    pcall(function() inBag = GetItemCount(self.SOIREE.FAVOR_ITEM_ID) or 0 end)
    if inBag > 0 then return inBag end

    local rank = 0
    pcall(function()
        local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(SILVERMOON_COURT_RENOWN_CURRENCY_ID)
        if info then rank = info.quantity or 0 end
    end)
    local count = self.SOIREE.BASE_TOKENS or 3
    for threshold, tokens in pairs(self.SOIREE.TOKENS_BY_RENOWN or {}) do
        if rank >= threshold and tokens > count then count = tokens end
    end
    return count
end

function DB:FortifyDone()
    for _, qID in pairs(self.SOIREE.FORTIFY_RUNESTONES) do
        local ok, result = pcall(C_QuestLog.IsQuestFlaggedCompleted, qID)
        if ok and result then return true end
    end
    return false
end

function DB:GetChosenSubfaction()
    for key, qID in pairs(self.SOIREE.FORTIFY_RUNESTONES) do
        local ok, result = pcall(C_QuestLog.IsQuestFlaggedCompleted, qID)
        if ok and result then return key end
        local ok2, idx = pcall(C_QuestLog.GetLogIndexForQuestID, qID)
        if ok2 and idx then return key end
    end
    return nil
end

function DB:GetRepImpactNote(chosenKey)
    local cache = RS_CharData and RS_CharData.soireeChoiceCache
    local factionData = cache and cache.factions and cache.factions[chosenKey]

    if factionData and factionData.rep_changes and #factionData.rep_changes > 0 then
        local gains, losses = {}, {}
        for _, change in ipairs(factionData.rep_changes) do
            if change.amount and change.faction then
                if change.amount > 0 then
                    table.insert(gains, "|cff00ff00+" .. change.amount .. " " .. change.faction .. "|r")
                else
                    table.insert(losses, "|cffff4444" .. change.amount .. " " .. change.faction .. "|r")
                end
            end
        end
        local parts = {}
        if #gains  > 0 then table.insert(parts, table.concat(gains,  ", ")) end
        if #losses > 0 then table.insert(parts, table.concat(losses, ", ")) end
        return table.concat(parts, "  ")
    end

    return "|cffaaaaaa(Rep values visible on choice screen)|r"
end

function DB:TokensWaitingToSpend()
    local ok1, idx = pcall(C_QuestLog.GetLogIndexForQuestID, self.SOIREE.THE_SUBTLE_GAME)
    if not (ok1 and idx) then return false end
    local ok2, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, self.SOIREE.THE_SUBTLE_GAME)
    return not (ok2 and done)
end

function DB:TokenWeekliesActive()
    local count = 0
    local qID = self.SOIREE.TOKEN_WEEKLY_QUEST
    pcall(function()
        local numEntries = C_QuestLog.GetNumQuestLogEntries()
        for i = 1, numEntries do
            local info = C_QuestLog.GetInfo(i)
            if info and info.questID == qID and not info.isComplete then
                count = count + 1
            end
        end
    end)
    return count
end

-- ============================================================
-- DUNGEON HELPERS
-- ============================================================
function DB:DungeonWeeklyDone()
    for _, qID in ipairs(self.ALL_DUNGEON_QUEST_IDS) do
        local ok, result = pcall(C_QuestLog.IsQuestFlaggedCompleted, qID)
        if ok and result then return true, qID end
    end
    return false, nil
end

function DB:GetActiveDungeonQuest()
    for _, qID in ipairs(self.ALL_DUNGEON_QUEST_IDS) do
        local ok, idx = pcall(C_QuestLog.GetLogIndexForQuestID, qID)
        if ok and idx then
            return self.DUNGEON_BY_QUEST[qID], qID
        end
    end
    return nil, nil
end

-- ============================================================
-- HOUSING HELPERS
-- ============================================================
function DB:HousingMetaDone()
    local ok, result = pcall(C_QuestLog.IsQuestFlaggedCompleted, self.HOUSING.META_QUEST)
    return ok and result or false
end

function DB:LandscapePhotoAvailable()
    local n = 0
    pcall(function() n = C_QuestLog.GetNumQuestLogEntries() end)
    for i = 1, n do
        local ok, info = pcall(C_QuestLog.GetInfo, i)
        if ok and info and info.questID == self.HOUSING.LANDSCAPE_PHOTO then
            return true
        end
    end
    return false
end

-- DetectFlightMode is now in Core/Database.lua (expansion-agnostic).
-- It is automatically copied onto expansion DBs by Expansion:DetectActive().
