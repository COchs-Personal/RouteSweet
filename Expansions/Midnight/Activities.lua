-- Expansions/Midnight/Activities.lua
-- Dynamic activity builders for Midnight expansion.
-- Registers the BuildDynamicActivities callback on the Midnight expansion.
--
-- LOAD ORDER: After Expansions/Midnight/Database.lua

local midnight = RS.Expansion:GetExpansion("Midnight")
if not midnight then return end

local DB = midnight.db
if not DB then return end

-- ============================================================
-- ROUTE NODE BUILDERS
-- ============================================================

-- Dungeon weekly: routes to Halduron before pickup, dungeon entrance after.
local function buildDungeonActivity()
    if DB:DungeonWeeklyDone() then return nil end

    local dungeon, questID = DB:GetActiveDungeonQuest()
    if not dungeon then
        return {
            id       = "dungeon_weekly_halduron",
            name     = "Weekly Dungeon — Pick Up from Halduron",
            mapID    = RS.Zones.MAP_IDS.SILVERMOON,
            x        = 0.460, y = 0.490,
            type     = "WEEKLY",
            duration = 5 * 60,
            rewards  = { "rep", "gold" },
            priority = 2,
            notes    = "Halduron Brightwing offers a weekly dungeon quest (any difficulty). Rewards 1,000 rep with chosen faction.",
            questID  = nil,
        }
    end

    return {
        id       = "dungeon_weekly_" .. dungeon.id,
        name     = dungeon.name .. " (Weekly)",
        mapID    = dungeon.mapID,
        x        = dungeon.entranceCoords.x,
        y        = dungeon.entranceCoords.y,
        type     = "WEEKLY",
        duration = 25 * 60,
        rewards  = { "rep", "gold", "gear" },
        priority = 2,
        notes    = dungeon.notes .. (dungeon.normalOnly and " Normal only." or ""),
        questID  = questID,
    }
end

-- Soiree: returns 0–5 nodes covering everything left to do this week.
local function buildSoireeActivities()
    local nodes = {}
    local haven = { mapID = RS.Zones.MAP_IDS.EVERSONG, x = 0.434, y = 0.475 }

    -- 1. Main faction choice
    local ok1, done1 = pcall(C_QuestLog.IsQuestFlaggedCompleted, DB.SOIREE.FAVOR_OF_THE_COURT)
    if not (ok1 and done1) then
        local tokenCount = DB:GetTokenCount()
        table.insert(nodes, {
            id       = "soiree_choice",
            name     = "Saltheril's Soiree — Choose Subfaction",
            mapID    = haven.mapID, x = haven.x, y = haven.y,
            type     = "WEEKLY_EVENT",
            duration = 3 * 60,
            rewards  = { "rep", "cosmetics" },
            priority = 1,
            notes    = "Pick which subfaction to invite this week (warband-wide). Grants " .. tokenCount .. " Saltheril's Favor token(s) to spend.",
            questID  = DB.SOIREE.FAVOR_OF_THE_COURT,
        })
    end

    -- 2. Token distribution
    if DB:TokensWaitingToSpend() then
        local tokenCount = DB:GetTokenCount()
        local chosenKey  = DB:GetChosenSubfaction()
        local repNote    = chosenKey and DB:GetRepImpactNote(chosenKey) or "Choose subfaction first."
        table.insert(nodes, {
            id       = "soiree_tokens",
            name     = "Saltheril's Soiree — Spend " .. tokenCount .. " Token(s)",
            mapID    = haven.mapID, x = haven.x, y = haven.y,
            type     = "WEEKLY_EVENT",
            duration = 3 * 60,
            rewards  = { "rep", "cosmetics" },
            priority = 1,
            notes    = "Hand tokens to subfaction reps at the Haven. Each = 30 Brimming Arcana + 25 Latent Arcana + 100 rep + 35 Coffer Key Shards. " .. repNote,
            questID  = DB.SOIREE.THE_SUBTLE_GAME,
        })
    end

    -- 3. Active token weekly quests
    local tokenWeeklies = DB:TokenWeekliesActive()
    if tokenWeeklies > 0 then
        table.insert(nodes, {
            id       = "soiree_token_weeklies",
            name     = "Saltheril's Soiree — Subfaction Quests (" .. tokenWeeklies .. "x)",
            mapID    = haven.mapID, x = haven.x, y = haven.y,
            type     = "WEEKLY_EVENT",
            duration = tokenWeeklies * 5 * 60,
            rewards  = { "rep", "cosmetics" },
            priority = 2,
            notes    = tokenWeeklies .. " short subfaction quest(s) active from token spend.",
            questID  = DB.SOIREE.TOKEN_WEEKLY_QUEST,
        })
    end

    -- 4. Fortify the Runestones
    if not DB:FortifyDone() then
        local chosenKey = DB:GetChosenSubfaction()
        local name      = "Saltheril's Soiree — Fortify the Runestones"
        local questID   = nil
        local repNote   = ""

        if chosenKey then
            name    = "Fortify the Runestones: " .. DB.SOIREE.SUBFACTION_NAMES[chosenKey]
            questID = DB.SOIREE.FORTIFY_RUNESTONES[chosenKey]
            repNote = " | Rep this week: " .. DB:GetRepImpactNote(chosenKey)
        end

        table.insert(nodes, {
            id       = "soiree_fortify",
            name     = name,
            mapID    = haven.mapID, x = 0.500, y = 0.500,
            type     = "WEEKLY_EVENT",
            duration = 20 * 60,
            rewards  = { "rep", "cache", "cosmetics" },
            priority = 1,
            notes    = "Charge a Runestone with Latent Arcana + defend it. Pinnacle cache + 150 Brimming Arcana + 300 subfaction rep + 2,000 Silvermoon Court rep." .. repNote,
            questID  = questID,
        })
    end

    -- 5. Bonus grounds objective (daily, not weekly)
    local ok5, done5 = pcall(C_QuestLog.IsQuestFlaggedCompleted, DB.SOIREE.BONUS_OBJECTIVE)
    if not (ok5 and done5) then
        table.insert(nodes, {
            id       = "soiree_bonus",
            name     = "Saltheril's Soiree — Grounds Tasks",
            mapID    = haven.mapID, x = haven.x, y = haven.y,
            type     = "WEEKLY_EVENT",  -- was DAILY_EVENT (orphaned type); use WEEKLY_EVENT so it shows in routes
            duration = 8 * 60,
            rewards  = { "cosmetics" },
            priority = 3,
            notes    = "Daily grounds tasks around the Haven. Rewards 25 Brimming Arcana. Resets daily.",
            questID  = DB.SOIREE.BONUS_OBJECTIVE,
        })
    end

    return nodes
end

-- Housing: returns 0-1 nodes
local function buildHousingActivity()
    local nodes = {}
    if DB:HousingMetaDone() then return nodes end

    local faction = UnitFactionGroup and UnitFactionGroup("player") or "Horde"
    local nbhd = (faction == "Alliance") and DB.HOUSING.NEIGHBORHOODS.founders_point
                                           or DB.HOUSING.NEIGHBORHOODS.razorwind_shores

    local tasks = { "Endeavor tasks" }
    if DB:LandscapePhotoAvailable() then
        table.insert(tasks, "Landscape Photography (Corlen Hordralin)")
    end

    table.insert(nodes, {
        id       = "housing_neighborhood",
        name     = "Housing: " .. nbhd.name,
        mapID    = nbhd.mapID,
        x        = nbhd.x,
        y        = nbhd.y,
        type     = "HOUSING",
        duration = 15 * 60,
        rewards  = { "community_coupons", "house_xp", "decor" },
        priority = 2,
        notes    = "Enter neighborhood portal. Complete: " .. table.concat(tasks, ", ") ..
                   ". Community Coupons never expire — lower priority if already capped.",
        questID  = DB.HOUSING.META_QUEST,
    })

    return nodes
end

-- ============================================================
-- REGISTER BuildDynamicActivities ON MIDNIGHT EXPANSION
-- enabledTypes: set of enabled activity type IDs from the active profile
-- ============================================================
midnight.BuildDynamicActivities = function(enabledTypes)
    local nodes = {}

    -- Dungeon weekly
    if enabledTypes["DUNGEON"] then
        local dungeonNode = buildDungeonActivity()
        if dungeonNode then table.insert(nodes, dungeonNode) end
    end

    -- Soiree (WEEKLY_EVENT)
    if enabledTypes["WEEKLY_EVENT"] then
        local soireeNodes = buildSoireeActivities()
        for _, node in ipairs(soireeNodes) do table.insert(nodes, node) end
    end

    -- Housing
    if enabledTypes["HOUSING"] then
        local housingNodes = buildHousingActivity()
        for _, node in ipairs(housingNodes) do table.insert(nodes, node) end
    end

    -- Special Assignment (weekly rotating instanced content)
    if enabledTypes["WEEKLY"] or enabledTypes["WEEKLY_EVENT"] then
        local sa = DB:GetActiveSpecialAssignment()
        if sa then
            table.insert(nodes, {
                id       = sa.id,
                name     = sa.name,
                mapID    = sa.mapID,
                x        = 0.5, y = 0.5,  -- zone center; exact coords vary per assignment
                type     = "WEEKLY",
                duration = 20 * 60,
                rewards  = { "gear", "rep", "cache" },
                priority = 1,
                notes    = "Weekly Special Assignment. Instanced content, rewards pinnacle gear.",
                questID  = sa.questID,
            })
        end
    end

    -- UATV progress note (meta quest, not a routable stop but informs priority)
    -- Vault-eligible activities get a score boost if vault slots are incomplete
    -- (handled in scoring, not as a separate node)

    -- Delves (bountiful delves detected via POI)
    if enabledTypes["DELVE"] then
        local bountiful = DB:GetBountifulDelves()
        for _, delve in ipairs(bountiful) do
            table.insert(nodes, {
                id       = "delve_" .. delve.poiID,
                name     = "Bountiful: " .. (delve.name or "Unknown"),
                mapID    = delve.mapID,
                x        = delve.x,
                y        = delve.y,
                type     = "DELVE",
                duration = 8 * 60,
                rewards  = { "gear", "cache" },
                priority = 2,
                notes    = "Bountiful Delve — guaranteed loot. Counts toward Great Vault.",
            })
        end

        -- Delve weekly quests
        local delveWeeklies = {
            { qID = DB.DELVES.CALL_TO_DELVES,  name = "Call to Delves" },
            { qID = DB.DELVES.MIDNIGHT_DELVES,  name = "Midnight Delves" },
        }
        for _, dw in ipairs(delveWeeklies) do
            local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, dw.qID)
            if not (ok and done) then
                -- Check if in quest log
                local ok2, inLog = pcall(C_QuestLog.IsOnQuest, dw.qID)
                if ok2 and inLog then
                    table.insert(nodes, {
                        id       = "delve_weekly_" .. dw.qID,
                        name     = dw.name,
                        mapID    = RS.Zones.MAP_IDS.SILVERMOON or 2393,
                        x        = 0.5, y = 0.5,
                        type     = "DELVE",
                        duration = 10 * 60,
                        rewards  = { "gear", "cache" },
                        priority = 2,
                        notes    = "Weekly delve quest.",
                        questID  = dw.qID,
                    })
                end
            end
        end
    end

    -- Rare mobs (unkilled this week)
    if enabledTypes["RARE"] then
        local unkilled = DB:GetUnkilledRares()
        for _, rare in ipairs(unkilled) do
            table.insert(nodes, {
                id       = "rare_" .. rare.questID,
                name     = rare.name,
                mapID    = rare.mapID,
                x        = rare.x,
                y        = rare.y,
                type     = "RARE",
                duration = 2 * 60,
                rewards  = { "rep", "mounts", "cosmetics" },
                priority = 1,
                notes    = "Weekly rare kill — rep + mount/cosmetic chance.",
                questID  = rare.questID,
            })
        end
    end

    -- Profession knowledge (treasures, studies, weekly quests)
    if enabledTypes["PROFESSION"] then
        -- One-time treasures + studies with exact map coords
        local treasures = DB:GetUncollectedProfTreasures()
        for _, t in ipairs(treasures) do
            local label = t.kind == "study" and "Prof Study" or "Prof Treasure"
            table.insert(nodes, {
                id       = "prof_" .. t.profKey .. "_" .. t.questID,
                name     = label .. ": " .. t.profKey:sub(1,1):upper() .. t.profKey:sub(2) .. " (" .. t.kp .. " KP)",
                mapID    = t.mapID,
                x        = t.x,
                y        = t.y,
                type     = "PROFESSION",
                duration = 1 * 60,
                rewards  = { "professions" },
                priority = t.kind == "study" and 3 or 2,
                notes    = t.kp .. " Knowledge Points — " .. t.profKey .. " " .. t.kind,
                questID  = t.questID,
            })
        end

        -- Weekly quests (notebook + treatise at Silvermoon hub)
        local weeklies = DB:GetIncompleteProfWeeklies()
        for _, w in ipairs(weeklies) do
            local label = w.kind == "treatise" and "Treatise" or "Prof Quest"
            table.insert(nodes, {
                id       = "prof_weekly_" .. w.profKey .. "_" .. w.kind,
                name     = label .. ": " .. w.profKey:sub(1,1):upper() .. w.profKey:sub(2),
                mapID    = w.mapID,
                x        = w.x,
                y        = w.y,
                type     = "PROFESSION",
                duration = 3 * 60,
                rewards  = { "professions" },
                priority = 2,
                notes    = "Weekly " .. w.kind .. " — " .. w.profKey,
                questID  = w.questID or (w.questIDs and w.questIDs[1]),
            })
        end

        -- Skinning daily lures (if player has skinning)
        local playerProfs = DB:GetPlayerProfessions()
        local hasSkinning = false
        for _, sl in ipairs(playerProfs) do
            if sl == 2917 then hasSkinning = true; break end
        end
        if hasSkinning then
            for _, lure in ipairs(DB.SKINNING_LURES) do
                local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, lure.questID)
                if not (ok and done) then
                    table.insert(nodes, {
                        id       = "skin_lure_" .. lure.key,
                        name     = "Lure: " .. lure.key:sub(1,1):upper() .. lure.key:sub(2),
                        mapID    = lure.mapID,
                        x        = lure.x,
                        y        = lure.y,
                        type     = "PROFESSION",
                        duration = 5 * 60,
                        rewards  = { "professions", "gold" },
                        priority = 1,
                        notes    = "Daily skinning lure hunt.",
                        questID  = lure.questID,
                    })
                end
            end
        end
    end

    -- Housing decor treasures (only when inside a neighborhood)
    if enabledTypes["DECOR"] then
        local decor = DB:GetAvailableDecor()
        for _, d in ipairs(decor) do
            table.insert(nodes, {
                id       = "decor_" .. d.questID,
                name     = d.name,
                mapID    = d.mapID,
                x        = d.x,
                y        = d.y,
                type     = "DECOR",
                duration = 1 * 60,
                rewards  = { "housing_decor" },
                priority = 1,
                notes    = "Housing decor blueprint — collect for your house.",
                questID  = d.questID,
            })
        end
    end

    return nodes
end
