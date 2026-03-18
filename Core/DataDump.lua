-- Core/DataDump.lua
-- Live character data poller for RouteSweet
-- Fires on PLAYER_LOGIN (after 8s delay) and writes a readable snapshot
-- to RS_DumpData (SavedVariablesPerCharacter).
--
-- USAGE:
--   Automatic: runs 8 seconds after every login
--   Manual:    /rs dump
--
-- TO SHARE WITH DEVELOPER:
--   Option A — /rs dump then /reload (required — portal flush is unreliable), then open:
--     WTF/Account/<ACCOUNT>/<SERVER>/<CHARACTER>/SavedVariables/RouteSweet.lua
--     Copy the RS_DumpData = { ... } block and paste it into chat.
--   Option B — /rs dump prints a reminder to /reload after.
--
-- SECTIONS IN OUTPUT:
--   character      — name, realm, level, class, faction
--   quests         — completion + in-log flags for all known RS quest IDs
--   housing        — meta quest, rotating weekly scanner, endeavor task scanner,
--                    housing API probe, Community Coupons, House XP
--   reputations    — standing + value for all Midnight factions
--   currencies     — all known Midnight currencies
--   tokens         — bag item counts (Saltheril's Favor etc.)
--   weekly_cache   — Great Vault / weekly reward chest progress
--   raw_quest_log  — FULL quest log snapshot (every active quest ID + title)
--   raw_currencies — ALL currencies with quantity > 0 (for ID discovery)
--   notes          — discovery snippets, unconfirmed IDs, mechanic flags

RS.Dump = RS.Dump or {}

-- ============================================================
-- QUEST IDS TO POLL
-- ============================================================
local QUEST_IDS = {
    -- ---- Saltheril's Soiree ----
    soiree_favor_of_court        = 89289,  -- CONFIRMED
    soiree_the_subtle_game       = 91693,  -- CONFIRMED
    soiree_token_weekly          = 89307,  -- CONFIRMED (first instance only; see log scan for multiples)
    soiree_bonus_objective       = 91966,  -- CONFIRMED
    soiree_unlock_honored_guests = 91628,  -- CONFIRMED (one-time)
    soiree_unlock_high_esteem    = 91629,  -- CONFIRMED (one-time)
    soiree_meta_world_tour       = 93889,  -- CONFIRMED
    soiree_fortify_magisters     = 90573,  -- CONFIRMED
    soiree_fortify_blood_knights = 90574,  -- CONFIRMED
    soiree_fortify_farstriders   = 90575,  -- CONFIRMED
    soiree_fortify_shades        = 90576,  -- CONFIRMED

    -- ---- Legends of the Haranir ----
    legends_pickup               = 89268,  -- CONFIRMED
    legends_turnin               = 93932,  -- CONFIRMED
    legends_meta_world_tour      = 93891,  -- CONFIRMED

    -- ---- Stormarion Assault ----
    stormarion_assault_wq        = 90962,  -- CONFIRMED
    stormarion_meta_world_tour   = 93892,  -- CONFIRMED

    -- ---- Abundance ----
    abundance_weekly_meta        = 89507,  -- CONFIRMED (beta)

    -- ---- The Arcantina ----
    -- Pocket-dimension tavern, mapID 2541 (CONFIRMED dump 2026-03-11)
    -- Access: Personal Key to the Arcantina (item 253629, 15min CD) or Silvermoon Inn portal
    -- 9 total rotating weekly Patron quests (Housing Decor rewards), one active per week
    -- API does NOT set is_weekly=true on patron quests — track by completed flag instead
    arcantina_meta               = 93767,  -- CONFIRMED (Wowhead): meta, rewards Spark of Radiance + Apex Cache
    -- Week 1 patron quest CONFIRMED from dump 2026-03-11:
    arcantina_patron_wk1         = 92320,  -- CONFIRMED: "Still Behind Enemy Portals" (Broken Shore)
    -- Remaining 8 patron quest IDs unknown — will populate as they rotate in weekly:
    arcantina_patron_wk2         = 0,  -- UNKNOWN
    arcantina_patron_wk3         = 0,  -- UNKNOWN
    arcantina_patron_wk4         = 0,  -- UNKNOWN
    arcantina_patron_wk5         = 0,  -- UNKNOWN
    arcantina_patron_wk6         = 0,  -- UNKNOWN
    arcantina_patron_wk7         = 0,  -- UNKNOWN
    arcantina_patron_wk8         = 0,  -- UNKNOWN
    arcantina_patron_wk9         = 0,  -- UNKNOWN

    -- ---- Midnight World Tour ----
    midnight_world_tour          = 95245,  -- CONFIRMED

    -- ---- Dungeon weeklies (Halduron Brightwing) ----
    dungeon_windrunner_spire     = 93751,  -- CONFIRMED
    dungeon_murder_row           = 93752,  -- CONFIRMED
    dungeon_magisters_terrace    = 93753,  -- CONFIRMED
    dungeon_maisara_caverns      = 93754,  -- ESTIMATED
    dungeon_den_of_nalorakk      = 93755,  -- ESTIMATED
    dungeon_the_blinding_vale    = 93756,  -- ESTIMATED
    dungeon_nexus_point_xenas    = 93757,  -- ESTIMATED
    dungeon_voidscar_arena       = 93758,  -- ESTIMATED

    -- ---- Housing: known fixed IDs ----
    -- "Midnight: Housing" meta — participate in Endeavors + collect Community Coupons
    housing_meta                  = 93769,  -- CONFIRMED: wowhead.com/quest=93769
    -- "Landscape Photography" — weekly from Corlen Hordralin, active when matching Endeavor runs
    -- CONFIRMED: in log at Founder's Point 2026-03-11, is_weekly=true
    housing_landscape_photography = 92608,  -- CONFIRMED
    -- "Decor Treasure Hunt" — observed in quest log at Founder's Point 2026-03-11
    -- Likely a companion activity to the active Endeavor this week
    housing_decor_treasure_hunt     = 93088,  -- CONFIRMED in log (Horde/Razorwind variant)
    housing_decor_treasure_hunt_alt = 92975,  -- CONFIRMED in raw quest log 2026-03-11 (Alliance variant)
    -- "Be a Good Neighbor" Endeavor task — neighborhood cleanup (cobwebs, weeds, fences)
    housing_be_good_neighbor      = 92610,  -- ESTIMATED: sequential from 92608
    -- Housing intro / unlock chain (one-time; tells us if player has housing set up)
    housing_intro_silvermoon      = 91800,  -- ESTIMATED
    housing_plot_claimed          = 91801,  -- ESTIMATED
    -- Rotating weekly: crest vendor purchase quest — rotates each reset, ID unknown
    -- First observed live ID as anchor; scanner below handles discovery
    housing_rotating_weekly_v1    = 93780,  -- ESTIMATED: first observed rotating weekly ID
}

-- ============================================================
-- ROTATING WEEKLY SCAN RANGE
-- Housing weekly changes ID each reset. We scan a range around
-- the known anchor and report any quest found in log or completed.
-- ============================================================
local HOUSING_WEEKLY_SCAN = {
    min = 93760,
    max = 93830,
}

-- ============================================================
-- ENDEAVOR TASK SCAN RANGES
-- Endeavor tasks appear as quests in the player's log while active.
-- We scan two blocks: the 92580-93200 range where housing quests cluster
-- (92608 = Landscape Photography, 93088 = Decor Treasure Hunt confirmed),
-- and the 93760-93830 housing block.
-- 93766 "Midnight: World Quests" is explicitly excluded — it is a world quest
-- tracker that appears in EVERY neighborhood dump and is NOT a housing task.
-- ============================================================
local HOUSING_ENDEAVOR_EXCLUDE = {
    [93766] = true,  -- "Midnight: World Quests" — world quest tracker, NOT housing
}

local ENDEAVOR_SCAN_RANGES = {
    { min = 92580, max = 93200, label = "housing_quest_block" },
    { min = 93760, max = 93830, label = "housing_weekly_block" },
}

-- ============================================================
-- FACTION IDS  — CONFIRMED via name-scan dump 2026-03-11
-- ============================================================
local FACTION_IDS = {
    silvermoon_court  = 2710,  -- CONFIRMED: "Silvermoon Court"
    harati            = 2704,  -- CONFIRMED: "Hara'ti"
    magisters         = 2711,  -- CONFIRMED: "Magisters"
    blood_knights     = 2712,  -- CONFIRMED: "Blood Knights"
    farstriders       = 2713,  -- CONFIRMED: "Farstriders"
    shades_of_the_row = 2714,  -- CONFIRMED: "Shades of the Row"
    amani_tribe       = 2696,  -- CONFIRMED: "Amani Tribe"
    midnight_exp      = 2698,  -- CONFIRMED: "Midnight" (expansion-level faction)
    the_singularity   = 2699,  -- CONFIRMED: "The Singularity"
    -- sunreaver_remnants: "Sunreaver Onslaught" (1388) is the old MoP faction — no Midnight equivalent found
    -- neighborhood_founders_point / neighborhood_razorwind_shores: not present as reputation factions
}

-- FACTION_SEARCH kept for fallback discovery of any new factions added in future patches
local FACTION_SEARCH = {
    silvermoon_court  = "silvermoon court",
    harati            = "hara'ti",
    magisters         = "magisters",
    blood_knights     = "blood knight",
    farstriders       = "farstrider",
    shades_of_the_row = "shades of the row",
    amani_tribe       = "amani tribe",
}

-- ============================================================
-- CURRENCY IDS
-- CONFIRMED from dump 2026-03-11: IDs 3000-3100 contain only TWW/11.0 currencies.
-- Midnight currencies are NOT in the 3020-3026 estimated block.
-- ID 3026 = "Cosmetic" (generic currency, not House XP).
-- All Midnight currency IDs remain UNCONFIRMED — raw scan expanded to find them.
-- ============================================================
-- All Midnight currency IDs CONFIRMED via full raw_currencies scan (dump 2026-03-11T21:32Z)
-- Currency tab only shows currencies you've encountered — list is complete for this character.
local CURRENCY_IDS = {
    -- ── Core Midnight progression currencies ──────────────────────────────
    brimming_arcana     = 3379,  -- qty=777; primary Midnight spending currency
    coffer_key_shards   = 3310,  -- qty=0 (spent); 35 per Soiree token
    voidlight_marl      = 3316,  -- qty=8026; Voidstorm zone currency
    community_coupons   = 3363,  -- qty=259, max=2000; housing/social; Misc tab
    unalloyed_abundance = 3377,  -- qty=1100; Abundance weekly system
    party_favor         = 3352,  -- qty=0; Saltheril's Soiree social currency
    dawnlight_manaflux  = 3378,  -- qty=0; Eversong/Silvermoon currency (purpose TBD)
    remnant_of_anguish  = 3392,  -- qty=1944; Voidstorm/void zone currency
    luminous_dust       = 3385,  -- qty=59; likely crafting/gathering currency
    untainted_mana_crystals = 3356, -- qty=0; Silvermoon questing currency
    shard_of_dundun     = 3376,  -- qty=7; rare drop currency (purpose TBD)
    angler_pearls       = 3373,  -- qty=0; fishing currency
    hellstone_shard     = 3309,  -- qty=67; adjacent to Coffer Key Shards

    -- ── Faction rep & renown (Midnight) ───────────────────────────────────
    -- Each faction has two IDs: spendable rep (qty=0) and renown rank tracker
    silvermoon_court_rep    = 3365,  -- "Silvermoon Court" spendable rep, qty=0
    silvermoon_court_renown = 3371,  -- "Renown - Silvermoon Court", rank=11
    harati_rep              = 3370,  -- "The Hara'ti" spendable rep, qty=0
    harati_renown           = 3369,  -- "Renown - The Hara'ti", rank=11
    amani_tribe_rep         = 3354,  -- "The Amani Tribe" spendable rep, qty=0
    amani_tribe_renown      = 3355,  -- "Renown - The Amani Tribe", rank=11
    magisters_rep           = 3397,  -- "Magisters" subfaction rep, qty=0
    blood_knights_rep       = 3398,  -- "Blood Knights" subfaction rep, qty=0
    farstriders_rep         = 3390,  -- "Farstriders" subfaction rep, qty=0
    shades_rep              = 3396,  -- "Shades of the Row" subfaction rep, qty=0

    -- ── Season 1 Dawncrest upgrade crests ─────────────────────────────────
    -- Each tier has two IDs; higher qty is the spendable one
    adventurer_dawncrest    = 3391,  -- qty=170 (3383=0 is the display/cap tracker)
    veteran_dawncrest       = 3342,  -- qty=10  (3341=0)
    champion_dawncrest      = 3344,  -- qty=0   (3343=0)
    hero_dawncrest          = 3346,  -- qty=0   (3345=0)
    myth_dawncrest          = 3348,  -- qty=0   (3347=0)

    -- ── Housing minigame personal best records ─────────────────────────────
    housing_postal_alliance_rt1 = 3431,
    housing_postal_alliance_rt2 = 3432,
    housing_postal_alliance_rt3 = 3433,
    housing_postal_horde_rt1    = 3434,
    housing_postal_horde_rt2    = 3435,
    housing_postal_horde_rt3    = 3436,

    -- ── Midnight profession knowledge (3150-3160) ─────────────────────────
    -- Tracked separately via profession panel; included here for completeness
    midnight_alchemy_knowledge      = 3150,  -- qty=4
    midnight_leatherworking_knowledge = 3157, -- qty=1
    -- (remaining profession knowledge IDs 3151-3160 confirmed, qty=0)
}

-- ============================================================
-- BAG ITEMS  (items that live in bags, not the currency tab)
-- ============================================================
local BAG_ITEMS = {
    saltheril_favor_token        = 238987,  -- CONFIRMED; Soiree turn-in token
    latent_arcana                = 242241,  -- CONFIRMED; bag item not currency, qty=172 in dump
    mysterious_skyshards         = 255826,  -- CONFIRMED; bag item, qty=24 in dump (purpose TBD)
    personal_key_to_arcantina    = 253629,  -- CONFIRMED (Wowhead); Warband Toy, 15min CD
}

-- ============================================================
-- HELPERS
-- ============================================================

local function safeGet(fn, ...)
    local ok, val = pcall(fn, ...)
    return ok and val or nil
end

local function buildQuestLogLookup()
    local lookup = {}
    local n = safeGet(C_QuestLog.GetNumQuestLogEntries) or 0
    for i = 1, n do
        local info = safeGet(C_QuestLog.GetInfo, i)
        if info and info.questID and info.questID > 0 and not info.isHeader then
            lookup[info.questID] = {
                title    = info.title or "?",
                isWeekly = info.frequency == Enum.QuestFrequency.Weekly,
                isDaily  = info.frequency == Enum.QuestFrequency.Daily,
            }
        end
    end
    return lookup
end

local function questStatus(qid, log)
    local completed = safeGet(C_QuestLog.IsQuestFlaggedCompleted, qid) or false
    local entry = log and log[qid]
    return {
        id        = qid,
        completed = completed,
        in_log    = entry ~= nil,
        title     = entry and entry.title or nil,
        is_weekly = entry and entry.isWeekly or nil,
        is_daily  = entry and entry.isDaily or nil,
    }
end

-- Scan all loaded factions and build a lookup: lowercased name -> factionData
local function buildFactionNameIndex()
    local index = {}
    if not C_Reputation or not C_Reputation.GetNumFactions then return index end
    local n = safeGet(C_Reputation.GetNumFactions) or 0
    for i = 1, n do
        local d = safeGet(C_Reputation.GetFactionDataByIndex, i)
        if d and d.factionID and d.factionID > 0 and d.name then
            index[d.name:lower()] = d
        end
    end
    return index
end

local function factionData(key, fid, nameIndex)
    -- Primary: direct ID lookup (all IDs confirmed 2026-03-11)
    if fid and fid > 0 then
        local d = safeGet(C_Reputation.GetFactionDataByID, fid)
        if d then
            local renown, renownMax
            if C_MajorFactions and C_MajorFactions.GetMajorFactionData then
                local rd = safeGet(C_MajorFactions.GetMajorFactionData, fid)
                if rd then renown = rd.renownLevel; renownMax = rd.renownMaxLevel end
            end
            return {
                id = fid, name = d.name or key,
                standing = d.reaction, value = d.currentStanding,
                threshold_next = d.nextReactionThreshold,
                renown = renown, renown_max = renownMax,
            }
        end
    end
    -- Fallback: name-based search (catches factions added in future patches)
    local searchTerm = FACTION_SEARCH[key]
    if searchTerm and nameIndex then
        for nameLower, d in pairs(nameIndex) do
            if nameLower:find(searchTerm, 1, true) then
                return {
                    id = d.factionID, name = d.name,
                    standing = d.reaction, value = d.currentStanding,
                    status = "found_by_name_search",
                }
            end
        end
    end
    return { id = fid or 0, name = key, status = "NOT_FOUND" }
end

local function currencyData(key, cid)
    local info = safeGet(C_CurrencyInfo.GetCurrencyInfo, cid)
    if not info then return { id = cid, name = key, status = "NOT_FOUND" } end
    return {
        id = cid, name = info.name or key,
        quantity = info.quantity, max = info.maxQuantity, total = info.totalEarned,
    }
end

local function bagItemCount(key, itemID)
    local count = safeGet(GetItemCount, itemID) or 0
    return { id = itemID, name = key, count = count }
end

local function characterInfo()
    return {
        name    = UnitName("player"),
        realm   = GetRealmName(),
        level   = UnitLevel("player"),
        class   = select(2, UnitClass("player")),
        faction = UnitFactionGroup("player"),
    }
end

-- Expose for use in Run() which is a method call (colon syntax loses local scope)
RS.Dump.characterInfo = characterInfo

-- ============================================================
-- HOUSING API PROBE
-- Enumerates every function in plausible housing namespaces.
-- Records what actually exists in 12.0.1 live so we can build
-- against the real API surface after the dump comes back.
-- ============================================================
local function probeHousingAPIs()
    local result = {
        namespaces   = {},
        house_info   = nil,
        neighborhood = nil,
        endeavor     = nil,
        plot         = nil,
        errors       = {},
    }

    -- Map namespace names to try
    local NS = { "C_PlayerHousing", "C_Housing", "C_Garrison", "C_PlayerInfo" }
    for _, name in ipairs(NS) do
        local obj = _G[name]
        if type(obj) == "table" then
            local fns = {}
            for k, v in pairs(obj) do
                if type(v) == "function" then table.insert(fns, k) end
            end
            table.sort(fns)
            result.namespaces[name] = fns
        else
            result.namespaces[name] = "NOT_PRESENT"
        end
    end

    -- Try known and guessed function signatures
    local function tryHousingFn(label, ...)
        local fns = { ... }
        for _, fn in ipairs(fns) do
            if type(fn) == "function" then
                local ok, val = pcall(fn)
                if ok and val ~= nil then
                    return val
                elseif not ok then
                    table.insert(result.errors, label .. ": " .. tostring(val))
                end
            end
        end
        return nil
    end

    if C_Housing then
        -- GetCurrentNeighborhoodGUID — confirmed safe, returns GUID string
        local neighborhoodGUID = safeGet(C_Housing.GetCurrentNeighborhoodGUID)
        result.neighborhood = neighborhoodGUID

        -- GetCurrentHouseInfo — confirmed safe read
        result.house_info = safeGet(C_Housing.GetCurrentHouseInfo)

        -- GetPlayerOwnedHouses — confirmed safe, returns owned house list
        result.owned_houses = safeGet(C_Housing.GetPlayerOwnedHouses)

        -- HasHousingExpansionAccess — confirmed safe, returns bool
        result.has_expansion_access = safeGet(C_Housing.HasHousingExpansionAccess)

        -- GetMaxHouseLevel — safe read
        result.max_house_level = safeGet(C_Housing.GetMaxHouseLevel)

        -- GetCurrentHouseLevelFavor requires houseGuid
        -- house_info struct confirmed: { ownerName, plotID, neighborhoodName, houseName,
        --   neighborhoodGUID, houseGUID } — note field is "houseGUID" (all caps)
        if result.house_info and type(result.house_info) == "table" then
            local guid = result.house_info.houseGUID or result.house_info.houseGuid
            if guid then
                result.house_level_favor = safeGet(C_Housing.GetCurrentHouseLevelFavor, guid)
            end
        end

        -- UIMapID for current neighborhood
        if neighborhoodGUID then
            result.neighborhood_map_id = safeGet(C_Housing.GetUIMapIDForNeighborhood, neighborhoodGUID)
        end

        -- NOTE: C_NeighborhoodInitiative calls removed — they taint the UI and trigger
        -- "blocked from an action only available to the Blizzard UI" on login.
        -- NOTE: RequestCurrentHouseInfo() removed — server request, causes taint.
        -- NOTE: pairs() enumeration on C_NeighborhoodInitiative removed — also taints.
        result.neighborhood_initiative_present = (C_NeighborhoodInitiative ~= nil)
    end

        -- housing_related_globals scan removed — served its purpose in earlier dumps.
        -- pairs(_G) on protected namespaces can contribute to UI taint.

    return result
end

-- ============================================================
-- HOUSING SECTION BUILDER
-- ============================================================
local function buildHousingDump(log)
    local h = {
        quests          = {},
        rotating_weekly = { scan_min = HOUSING_WEEKLY_SCAN.min, scan_max = HOUSING_WEEKLY_SCAN.max, found = {} },
        endeavor_tasks  = { found = {} },
        api_probe       = probeHousingAPIs(),
        community_coupons = currencyData("community_coupons", CURRENCY_IDS.community_coupons),
        house_xp          = currencyData("house_xp",          CURRENCY_IDS.house_xp),
        notes           = {},
    }

    -- Fixed housing quest checks
    local fixedHousingKeys = {
        "housing_meta", "housing_landscape_photography",
        "housing_decor_treasure_hunt", "housing_decor_treasure_hunt_alt",
        "housing_be_good_neighbor",
        "housing_intro_silvermoon", "housing_plot_claimed",
        "housing_rotating_weekly_v1",
    }
    for _, key in ipairs(fixedHousingKeys) do
        local qid = QUEST_IDS[key]
        if qid then h.quests[key] = questStatus(qid, log) end
    end

    -- Rotating weekly scanner
    for qid = HOUSING_WEEKLY_SCAN.min, HOUSING_WEEKLY_SCAN.max do
        if not HOUSING_ENDEAVOR_EXCLUDE[qid] then
            local completed = safeGet(C_QuestLog.IsQuestFlaggedCompleted, qid) or false
            local entry = log[qid]
            if completed or entry then
                table.insert(h.rotating_weekly.found, {
                    id = qid, completed = completed,
                    in_log = entry ~= nil,
                    title = entry and entry.title or "(completed, not in log)",
                    is_weekly = entry and entry.isWeekly,
                })
            end
        end
    end
    h.rotating_weekly.count = #h.rotating_weekly.found

    -- Endeavor task scanner — excludes known false positives (e.g. 93766 world quest tracker)
    for _, range in ipairs(ENDEAVOR_SCAN_RANGES) do
        for qid = range.min, range.max do
            if not HOUSING_ENDEAVOR_EXCLUDE[qid] then
                local entry = log[qid]
                if entry then
                    table.insert(h.endeavor_tasks.found, {
                        id = qid, title = entry.title,
                        is_weekly = entry.isWeekly, is_daily = entry.isDaily,
                        scan_block = range.label,
                    })
                end
            end
        end
    end
    h.endeavor_tasks.count = #h.endeavor_tasks.found

    -- Annotate noteworthy gaps
    if h.rotating_weekly.count == 0 then
        h.notes.rotating_weekly_not_found =
            "No rotating housing weekly in scan range " ..
            HOUSING_WEEKLY_SCAN.min .. "-" .. HOUSING_WEEKLY_SCAN.max ..
            ". May be outside range, or not available this reset."
    end
    if h.api_probe.namespaces["C_Housing"] == "NOT_PRESENT" then
        h.notes.api_namespace_missing =
            "C_Housing not present. Check housing_related_globals list for actual namespace."
    end

    return h
end

-- ============================================================
-- RAW QUEST LOG SNAPSHOT  (full active log, sorted by ID)
-- ============================================================
local function buildRawQuestLog(log)
    local entries = {}
    for qid, info in pairs(log) do
        table.insert(entries, {
            id = qid, title = info.title,
            is_weekly = info.isWeekly, is_daily = info.isDaily,
        })
    end
    table.sort(entries, function(a, b) return a.id < b.id end)
    return entries
end

-- ============================================================
-- RAW CURRENCY SCAN
-- All Midnight currency IDs confirmed via full scan (dump 2026-03-11).
-- Keeping targeted scans to catch any new currencies added in future patches,
-- and to track weekly-resetting quantities on confirmed currencies.
-- ============================================================
local function buildRawCurrencies()
    local found = {}

    -- Scan confirmed Midnight ID block (3300-3440) — all relevant IDs in this range.
    -- Include zero-qty so we can see newly-awarded currencies even if not yet earned.
    for cid = 3300, 3440 do
        local info = safeGet(C_CurrencyInfo.GetCurrencyInfo, cid)
        if info and info.name and info.quantity ~= nil then
            table.insert(found, {
                id = cid, name = info.name,
                quantity = info.quantity, max = info.maxQuantity,
                total = info.totalEarned,
            })
        end
    end

    -- Small legacy scan for Champion's Seal (241) and anything below 500
    -- that may carry over week-to-week (limit to non-zero only, much faster)
    for cid = 1, 500 do
        local info = safeGet(C_CurrencyInfo.GetCurrencyInfo, cid)
        if info and info.name and info.quantity and info.quantity > 0 then
            table.insert(found, {
                id = cid, name = info.name,
                quantity = info.quantity, max = info.maxQuantity,
                total = info.totalEarned,
            })
        end
    end

    table.sort(found, function(a, b) return a.id < b.id end)
    return found
end

-- ============================================================
-- BAG SCAN FOR MIDNIGHT CURRENCIES
-- Community Coupons and Arcana currencies may be bag items
-- rather than tracked via C_CurrencyInfo. Scan all bags for
-- known and unknown Midnight-named items.
-- ============================================================
local function buildMidnightBagScan()
    local found = {}
    -- Bail entirely if C_Container isn't available in this build
    if not (C_Container and C_Container.GetContainerNumSlots
        and C_Container.GetContainerItemLink) then
        return found
    end
    -- Confirmed bag items: latent_arcana=242241, mysterious_skyshards=255826.
    -- Scanning by keyword for any remaining unknowns (brimming arcana as bag item unlikely
    -- now that 3379 confirmed as currency, but keeping broad scan for safety).
    local keywords = {
        "brimming", "coffer", "voidlight", "dawncrest",
        "arcana", "coupon", "shard", "saltheril", "skyshard",
    }
    for bag = 0, 4 do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local link = C_Container.GetContainerItemLink(bag, slot)
            if link then
                local itemName = link:match("%[(.-)%]") or ""
                local nameLower = itemName:lower()
                local matched = false
                for _, kw in ipairs(keywords) do
                    if nameLower:find(kw) then matched = true; break end
                end
                if matched then
                    -- C_Container.GetContainerItemInfo returns a table in modern API
                    local info = C_Container.GetContainerItemInfo and
                                 C_Container.GetContainerItemInfo(bag, slot)
                    local count = (type(info) == "table" and info.stackCount)
                               or (type(info) == "number" and info)  -- legacy fallback
                               or 1
                    local itemID = link:match("item:(%d+)")
                    table.insert(found, {
                        bag = bag, slot = slot,
                        name = itemName,
                        id = tonumber(itemID),
                        count = count,
                    })
                end
            end
        end
    end
    return found
end

-- ============================================================
-- C_CurrencyInfo API PROBE
-- Community Coupons are warbound (Miscellaneous tab) and may
-- require a different API call than GetCurrencyInfo. Dump all
-- available functions on C_CurrencyInfo so we can identify
-- any warband/account-specific currency accessors.
-- ============================================================
local function buildCurrencyApiProbe()
    local result = {
        warband_candidates = {},
        coupon_scan = {},
    }

    -- Check only for specific known warband-related function names — no pairs() enumeration
    -- which can taint the UI. These are the candidates most likely to exist.
    if C_CurrencyInfo then
        local candidates = {
            "GetWarbandCurrencyInfo", "GetAccountCurrencyInfo",
            "GetBackpackCurrencyCount", "GetCurrencyListInfo",
            "GetCurrencyListSize", "GetAllCurrencies",
            "GetWarbandCurrencies", "GetSharedCurrencies",
        }
        for _, fname in ipairs(candidates) do
            if type(C_CurrencyInfo[fname]) == "function" then
                local ok, val = pcall(C_CurrencyInfo[fname])
                table.insert(result.warband_candidates, {
                    name = fname,
                    exists = true,
                    result = ok and tostring(val) or ("ERR: " .. tostring(val)),
                })
            else
                table.insert(result.warband_candidates, { name = fname, exists = false })
            end
        end

        -- Community Coupons ID 3363 confirmed. Verify directly rather than scanning 1-9999.
        local couponInfo = safeGet(C_CurrencyInfo.GetCurrencyInfo, 3363)
        if couponInfo then
            table.insert(result.coupon_scan, {
                id = 3363, name = couponInfo.name,
                quantity = couponInfo.quantity, max = couponInfo.maxQuantity,
                isAccountWide = couponInfo.isAccountWide,
                isWarbound = couponInfo.isWarbound,
            })
        else
            table.insert(result.coupon_scan, { id = 3363, status = "NOT_READABLE" })
        end
    else
        result.warband_candidates = "C_CurrencyInfo NOT_PRESENT"
    end

    return result
end


function RS.Dump:Run(silent)
    local log = buildQuestLogLookup()

    local dump = {
        _version       = RS.VERSION,
        _timestamp     = date("!%Y-%m-%dT%H:%M:%SZ"),
        _patch         = "12.0.1",
        character      = self.characterInfo(),
        quests         = {},
        housing        = buildHousingDump(log),
        reputations    = {},
        currencies     = {},
        tokens         = {},
        weekly_cache   = {},
        raw_quest_log  = buildRawQuestLog(log),
        raw_currencies = buildRawCurrencies(),
        midnight_bag_scan = buildMidnightBagScan(),
        currency_api_probe = buildCurrencyApiProbe(),
        notes          = {},
    }

    -- Non-housing quests
    local housingQuestKeys = {
        housing_meta=1, housing_landscape_photography=1, housing_be_good_neighbor=1,
        housing_intro_silvermoon=1, housing_plot_claimed=1, housing_rotating_weekly_v1=1,
    }
    for label, qid in pairs(QUEST_IDS) do
        if not housingQuestKeys[label] then
            dump.quests[label] = questStatus(qid, log)
        end
    end

    -- Reputations — direct ID lookup, name-scan fallback for future patches
    local nameIndex = buildFactionNameIndex()
    for key, fid in pairs(FACTION_IDS) do
        dump.reputations[key] = factionData(key, fid, nameIndex)
    end

    -- Full faction list for discovery (factions with ID > 2600 = current/recent content)
    local allFound = {}
    for nameLower, d in pairs(nameIndex) do
        if d.factionID and d.factionID > 2600 then
            table.insert(allFound, { id = d.factionID, name = d.name })
        end
    end
    table.sort(allFound, function(a,b) return a.id < b.id end)
    dump.notes.all_factions_above_2600 = allFound

    -- Currencies (known list)
    for key, cid in pairs(CURRENCY_IDS) do
        dump.currencies[key] = currencyData(key, cid)
    end

    -- Bag items
    for key, iid in pairs(BAG_ITEMS) do
        dump.tokens[key] = bagItemCount(key, iid)
    end

    -- Weekly cache / Great Vault
    -- Guard: Enum.WeeklyRewardChestThresholdType values may be nil in this build
    if C_WeeklyRewards and C_WeeklyRewards.GetActivities
    and Enum.WeeklyRewardChestThresholdType then
        local enumType = Enum.WeeklyRewardChestThresholdType
        local types = {}
        if enumType.Activity   then types[enumType.Activity]   = "activity"   end
        if enumType.Raid       then types[enumType.Raid]       = "raid"       end
        if enumType.MythicPlus then types[enumType.MythicPlus] = "mythic_plus" end
        if enumType.PvP        then types[enumType.PvP]        = "pvp"        end

        for enum, label in pairs(types) do
            local acts = safeGet(C_WeeklyRewards.GetActivities, enum)
            if acts then
                dump.weekly_cache[label] = {}
                for _, a in ipairs(acts) do
                    table.insert(dump.weekly_cache[label], {
                        threshold = a.threshold, progress = a.progress,
                        completed = a.progress >= a.threshold, itemLevel = a.level,
                    })
                end
            end
        end

        if next(types) == nil then
            dump.weekly_cache._status = "Enum.WeeklyRewardChestThresholdType present but all values nil"
        end
    else
        dump.weekly_cache._status = "C_WeeklyRewards or Enum.WeeklyRewardChestThresholdType not available"
    end

    -- Notes
    dump.notes.housing_global_scan =
        "/run for k in pairs(_G) do local l=k:lower() if " ..
        "l:find('housing') or l:find('endeavor') or l:find('neighborhood') " ..
        "then print(k) end end"

    dump.notes.soiree_token_mechanic =
        "CONFIRMED (screenshot 2026-03-11): Base 3 tokens from Favor of the Court. " ..
        "Bonus tokens shown on faction choice cards as '+1 [Saltheril's Favor]'. " ..
        "Not all factions offer a bonus token every week. " ..
        "Values and availability rotate each weekly reset. " ..
        "soiree_choice_cache populated when player opens choice dialog."

    -- Soiree choice cache: populated by GOSSIP_SHOW hook when choice screen opens.
    -- Contains live rep values and token offers for this week's reset.
    -- Empty until player has opened the Favor of the Court dialog this session.
    dump.soiree_choice_cache = RS_CharData and RS_CharData.soireeChoiceCache or {
        _status = "not_seen_yet",
        _note   = "Populated when player opens Favor of the Court (quest 89289) dialog. " ..
                  "Reads gossip/frame text to extract weekly rep values and token offers per card.",
    }

    -- Arcantina discovery probe
    -- Fires extra data when player is inside the Arcantina instance
    local currentMapID = C_Map.GetBestMapForUnit("player")
    dump.notes.current_map_id = currentMapID
    dump.notes.current_map_name = currentMapID and (function()
        local info = C_Map.GetMapInfo(currentMapID)
        return info and info.name or "unknown"
    end)() or "unknown"

    -- If inside an unfamiliar zone (not one of our known outdoor zones), dump extra context
    -- Arcantina mapID 2541 confirmed — include in known list.
    -- unknown_zone_probe will still fire for any truly new/unrecognized zone.
    local knownOutdoorMaps = { [2393]=1, [2395]=1, [2413]=1, [2437]=1, [2405]=1, [2536]=1, [2541]=1 }
    if currentMapID and not knownOutdoorMaps[currentMapID] then
        dump.notes.unknown_zone_probe = {
            mapID       = currentMapID,
            name        = dump.notes.current_map_name,
            hint        = "Possible Arcantina or other instance — check mapID and quest log",
            quest_log   = dump.raw_quest_log,  -- already populated above
        }
    end

    dump.notes.arcantina_instructions =
        "Arcantina mapID 2541 CONFIRMED (dump 2026-03-11). " ..
        "Week 1 patron quest CONFIRMED: 92320 'Still Behind Enemy Portals' (Broken Shore). " ..
        "8 remaining patron quest IDs unknown — run /rs dump inside Arcantina each week to capture " ..
        "the new quest in raw_quest_log. Look for Arcantina-tagged quests with IDs in 90000-95000 range."

    dump.notes.arcantina_key_model =
        "HOTFIXED 2026-03-09: Personal Key to the Arcantina (item 253629, Warband Toy). " ..
        "Use Key (2s) -> loads into Arcantina pocket-dimension instance (own mapID, TBD). " ..
        "Exit portal inside Arcantina deposits player at Silvermoon Inn (Wayfarer's Rest). " ..
        "Total to Silvermoon ~38s. Permanent portal back to Arcantina also at Silvermoon Inn. " ..
        "15-minute cooldown. Functionally a second Silvermoon hearthstone. " ..
        "9 total rotating weekly Patron quests (Housing Decor). Meta quest ID: 93767."

    RS_DumpData = dump

    if not silent then
        print(string.format(
            "|cffC8A96ERouteSweet:|r Dump complete — " ..
            "%d quests in log, %d currencies found, %d housing tasks found.",
            #dump.raw_quest_log, #dump.raw_currencies,
            (dump.housing.endeavor_tasks.count or 0) + (dump.housing.rotating_weekly.count or 0)
        ))
        print("|cffaaaaaa  /reload then share: WTF/Account/.../SavedVariables/RouteSweet.lua|r")
    end

    return dump
end

-- ============================================================
-- AUTO-RUN ON LOGIN
-- ============================================================
function RS.Dump:AutoRun()
    C_Timer.After(8, function()
        RS.Dump:Run(true)
        print("|cffC8A96ERouteSweet:|r Login snapshot saved. " ..
              "Type |cffC8A96E/rs dump|r to refresh.")
    end)
end

-- ============================================================
-- SOIREE CHOICE SCREEN CAPTURE
-- Hooks the gossip/frame shown when the player opens the
-- Favor of the Court quest dialog (quest 89289).
-- Reads each faction card's rep changes and token offer,
-- stores result in RS_CharData.soireeChoiceCache.
--
-- The choice screen uses a scrolling gossip frame where each
-- option text contains the rep delta lines and token text.
-- We capture the raw gossip option strings and parse them
-- so future route/advice logic can use this week's actual values.
-- ============================================================
local soireeFrame = CreateFrame("Frame")
soireeFrame:RegisterEvent("GOSSIP_SHOW")
soireeFrame:SetScript("OnEvent", function(self, event)
    -- Only fire if Favor of the Court is the active quest in the dialog
    -- Check: is quest 89289 in log and not yet completed this week?
    if not C_QuestLog then return end
    local favorDone = C_QuestLog.IsQuestFlaggedCompleted(89289)
    if favorDone then return end

    -- Read all gossip options from the active gossip frame
    local _secondsUntil = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
                          and C_DateAndTime.GetSecondsUntilWeeklyReset()
    local _resetEpoch = _secondsUntil and (GetServerTime() - (7*24*3600 - _secondsUntil)) or nil
    local cache = {
        _captured_at  = date("!%Y-%m-%dT%H:%M:%SZ"),
        _weekly_reset = _resetEpoch,  -- epoch of the current week's reset (Tuesday 15:00 UTC)
        factions = {},
        raw_options = {},
    }

    -- C_GossipInfo.GetOptions() returns array of {name, texture, gossipOptionID, ...}
    local opts = C_GossipInfo and C_GossipInfo.GetOptions and C_GossipInfo.GetOptions()
    if opts then
        for i, opt in ipairs(opts) do
            table.insert(cache.raw_options, {
                index = i,
                name  = opt.name or "",
                type  = opt.type or "",
            })
        end
    end

    -- Also read the quest reward text lines from the active gossip quest if available
    -- This is the richer source — each faction "Send Invitation" button opens a detail
    -- view with the full rep change text. We can't intercept that without clicking,
    -- so we store raw_options for now and parse on next read.

    -- Faction name mapping to internal keys
    local nameMap = {
        ["Magisters"]        = "magisters",
        ["Blood Knights"]    = "blood_knights",
        ["Farstriders"]      = "farstriders",
        ["Shades of the Row"] = "shades_of_row",
    }

    -- Parse option names: each option text is typically the faction name
    -- Full rep text is in gossip detail text, which requires GetActiveQuest-style reads.
    -- Store what we can; the detail parse below catches more on QUEST_DETAIL.
    for _, opt in ipairs(cache.raw_options) do
        for fullName, key in pairs(nameMap) do
            if opt.name and opt.name:find(fullName) then
                cache.factions[key] = cache.factions[key] or {
                    name        = fullName,
                    gossip_text = opt.name,
                    has_token   = nil,   -- populated by QUEST_DETAIL hook below
                    rep_changes = {},    -- populated by QUEST_DETAIL hook below
                }
            end
        end
    end

    cache._status = (#cache.raw_options > 0) and "captured" or "gossip_empty"

    RS_CharData = RS_CharData or {}
    RS_CharData.soireeChoiceCache = cache
end)

-- QUEST_DETAIL fires when a player clicks a gossip option that leads to quest detail.
-- The detail frame text contains the full rep change and token lines.
local detailFrame = CreateFrame("Frame")
detailFrame:RegisterEvent("QUEST_DETAIL")
detailFrame:SetScript("OnEvent", function(self, event)
    local cache = RS_CharData and RS_CharData.soireeChoiceCache
    if not cache or cache._status ~= "captured" then return end

    -- Read quest reward text from the detail frame (QuestFrameRewardPanel / C_QuestLog)
    local title = GetTitleText and GetTitleText() or ""

    -- Faction name from detail title (e.g. "Send an Invitation to the Magisters")
    local nameMap = {
        ["Magisters"]         = "magisters",
        ["Blood Knights"]     = "blood_knights",
        ["Farstriders"]       = "farstriders",
        ["Shades of the Row"] = "shades_of_row",
    }

    local activeKey = nil
    for fullName, key in pairs(nameMap) do
        if title:find(fullName) then activeKey = key; break end
    end
    if not activeKey then return end

    -- Read reward text lines — GetRewardText() returns the "You will receive:" block
    local rewardText = GetRewardText and GetRewardText() or ""
    local questText  = GetQuestText  and GetQuestText()  or ""
    local fullText   = questText .. "\n" .. rewardText

    local entry = cache.factions[activeKey] or {}
    entry.detail_text = fullText
    entry.has_token   = fullText:find("Saltheril's Favor") ~= nil

    -- Parse rep change lines: "+125 Magisters", "-100 Farstriders", etc.
    local repChanges = {}
    for sign, amount, faction in fullText:gmatch("([%+%-])(%d+)%s+([^\n]+)") do
        table.insert(repChanges, {
            faction = faction:match("^(.-)%s*$"),  -- trim trailing whitespace
            amount  = tonumber(amount) * (sign == "-" and -1 or 1),
        })
    end
    if #repChanges > 0 then entry.rep_changes = repChanges end

    cache.factions[activeKey] = entry
    RS_CharData.soireeChoiceCache = cache
end)


