-- RouteSweet.lua
-- Main entry point for the RouteSweet addon
-- WoW Midnight 12.0.1 compatible (no restricted combat APIs used)

RS = RS or {}
RS.VERSION = "1.0.0"

-- ============================================================
-- DEFAULT SETTINGS
-- ============================================================
-- ============================================================
-- PROFILE SYSTEM
-- Default profile is read-only. Custom profiles copy from it.
-- Stored in RS_Settings.profiles[name], active = RS_Settings.activeProfile
-- ============================================================
RS.DEFAULT_PROFILE = {
    -- Activity types: enabled = included in route calculations
    -- Order = priority score bonus (index 1 = highest bonus, stepping down by 2 per position)
    activityOrder = {
        { id = "WEEKLY",         label = "Weekly Quest",     enabled = true  },
        { id = "WEEKLY_EVENT",   label = "Weekly Events",    enabled = true  },
        { id = "DUNGEON",        label = "Dungeons",         enabled = true  },
        { id = "WORLD_QUEST",    label = "World Quests",     enabled = true  },
        { id = "DELVE",          label = "Delves",           enabled = false },
        { id = "ROTATING_EVENT", label = "Rotating Events",  enabled = true  },
        { id = "HOUSING",        label = "Housing",          enabled = true  },
        { id = "RARE",           label = "Rare Mobs",        enabled = false },
        { id = "PROFESSION",     label = "Profession KP",    enabled = false },
        { id = "DECOR",          label = "Housing Decor",    enabled = false },
        { id = "BATTLEGROUND",   label = "Battlegrounds",    enabled = false },
    },
    -- Reward weights: enabled = counts toward scoring
    -- Order = relative strength (index 1 = weight 10, index 2 = 8, stepping by 2)
    rewardOrder = {
        { id = "gear",             label = "Equipment",         enabled = true  },
        { id = "cache",            label = "Apex Cache",        enabled = true  },
        { id = "rep",              label = "Reputation",        enabled = true  },
        { id = "gold",             label = "Gold",              enabled = true  },
        { id = "voidlight_marl",   label = "Voidlight Marl",    enabled = true  },
        { id = "community_coupons",label = "Community Coupons", enabled = true  },
        { id = "brimming_arcana",  label = "Brimming Arcana",   enabled = true  },
        { id = "coffer_key_shards",label = "Coffer Key Shards", enabled = true  },
        { id = "mounts",           label = "Mounts",            enabled = true  },
        { id = "cosmetics",        label = "Cosmetics",         enabled = true  },
        { id = "housing_decor",    label = "Housing Decor",     enabled = true  },
        { id = "professions",      label = "Professions",       enabled = true  },
        { id = "house_xp",         label = "House XP",          enabled = false },
        { id = "spark_of_radiance",label = "Spark of Radiance", enabled = true  },
    },
    -- Zone preferences: per-zone score modifier for routing variety
    -- "prefer" = +20 score, "normal" = 0, "avoid" = -20 score
    -- Keyed by mapID. Only non-"normal" entries need to be stored.
    -- Example: { [2437] = "prefer", [2395] = "avoid" }
    zonePreferences = {},
}

local DEFAULTS = {
    useSkyriding        = true,
    questTime           = 7,
    showMinimapButton   = true,
    filterExpiringSoon  = true,
    autoScan            = true,
    waypointOnSelect    = true,
    portalBuffer        = 2,
    hearthLocation      = "none",
    hearthOnCooldown    = false,
    hasArcantinaKey     = false,
    arcantinaOnCooldown = false,
    -- Combat visibility: "always" | "hide_show_on_exit" | "hide_until_toggle"
    combatHide          = "hide_show_on_exit",
    -- Prey hunt: auto-detected via C_MajorFactions faction 2764 (Prey: Season 1)
    -- Renown rank determines features:
    --   Rank 1: 1 prey/zone (4 total), no teleport
    --   Rank 2: 2 prey/zone (8 total), auto-teleport, random hunts unlocked
    --   Rank 4: nightmare difficulty, possibly 3 prey/zone (12 total)
    -- preyRandomHunts: opt-in for random hunts (costs currency, no zone/type control)
    preyRandomHunts     = false,
    activeProfile       = "Default",
    profiles            = {},
}


-- ============================================================
-- PROFILE HELPERS
-- ============================================================

-- Deep-copy a table (one level of nested tables supported)
function RS.DeepCopy(orig)
    local copy = {}
    for k, v in pairs(orig) do
        if type(v) == "table" then
            local inner = {}
            for k2, v2 in pairs(v) do inner[k2] = v2 end
            copy[k] = inner
        else
            copy[k] = v
        end
    end
    return copy
end

-- Deep-copy an activityOrder or rewardOrder list (list of tables)
function RS.DeepCopyList(list)
    local copy = {}
    for i, item in ipairs(list) do
        copy[i] = RS.DeepCopy(item)
    end
    return copy
end

-- Returns the currently active profile table (read-only Default or a custom profile)
function RS:GetActiveProfile()
    local name = RS_Settings and RS_Settings.activeProfile or "Default"
    if name == "Default" then
        return RS.DEFAULT_PROFILE
    end
    local p = RS_Settings and RS_Settings.profiles and RS_Settings.profiles[name]
    return p or RS.DEFAULT_PROFILE
end

-- Creates a new custom profile copying from Default; returns it
function RS:CreateProfile(name)
    if not RS_Settings.profiles then RS_Settings.profiles = {} end
    local p = {
        activityOrder = RS.DeepCopyList(RS.DEFAULT_PROFILE.activityOrder),
        rewardOrder   = RS.DeepCopyList(RS.DEFAULT_PROFILE.rewardOrder),
    }
    RS_Settings.profiles[name] = p
    return p
end

-- Deletes a custom profile; falls back to Default if it was active
function RS:DeleteProfile(name)
    if name == "Default" then return end
    if RS_Settings.profiles then RS_Settings.profiles[name] = nil end
    if RS_Settings.activeProfile == name then
        RS_Settings.activeProfile = "Default"
    end
end

-- Returns ordered list of profile names (Default always first)
function RS:GetProfileNames()
    local names = { "Default" }
    if RS_Settings and RS_Settings.profiles then
        local custom = {}
        for k in pairs(RS_Settings.profiles) do table.insert(custom, k) end
        table.sort(custom)
        for _, n in ipairs(custom) do table.insert(names, n) end
    end
    return names
end

-- ============================================================
-- INITIALIZATION
-- ============================================================
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("WORLD_MAP_OPEN")
frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")   -- entering combat
frame:RegisterEvent("PLAYER_REGEN_ENABLED")    -- leaving combat
frame:RegisterEvent("TOYS_UPDATED")            -- toy collection loaded/changed
frame:RegisterEvent("UPDATE_UI_WIDGET")        -- prey crystal state changes

-- Track whether we hid the UI on combat entry so we can restore it
local _hiddenForCombat = false

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "RouteSweet" then
            RS:Initialize()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        RS:OnPlayerEnteringWorld()

    elseif event == "QUEST_LOG_UPDATE" then
        if RS._expansionActive then RS:OnQuestLogUpdate() end

    elseif event == "WORLD_MAP_OPEN" then
        if RS._expansionActive and RS_Settings and RS_Settings.autoScan then
            RS:ScanQuests()
        end

    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        if not RS._expansionActive then return end
        if RS.UI and RS.UI.isOpen then
            RS.UI:UpdateSkyBtn()
            RS:BuildRoute()
            RS.UI:Refresh()
        else
            if RS.DB and RS.DB.DetectFlightMode then
                local mode = RS.DB:DetectFlightMode()
                if RS_Settings then
                    RS_Settings.detectedFlightMode = mode
                    RS_Settings.useSkyriding = (mode == "skyriding")
                end
            end
        end

    elseif event == "UPDATE_UI_WIDGET" then
        -- Prey crystal state changed — refresh footer display
        if not RS._expansionActive then return end
        local widgetInfo = ...
        if widgetInfo and RS.DB and RS.DB._preyWidgetID
            and widgetInfo.widgetID == RS.DB._preyWidgetID then
            if RS.UI and RS.UI.isOpen and RS.UI.Refresh then
                RS.UI:Refresh()
            end
        end

    elseif event == "UNIT_AURA" then
        if not RS._expansionActive then return end
        local unit = ...
        if unit == "player" and RS.UI and RS.UI.isOpen then
            RS.UI:UpdateSkyBtn()
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entering combat
        local mode = RS_Settings and RS_Settings.combatHide or "hide_show_on_exit"
        if mode ~= "always" then
            if RS.UI and RS.UI.isOpen then
                _hiddenForCombat = true
                -- Use raw frame Hide to bypass isOpen flag so we can restore later
                if RS.UI.frame then RS.UI.frame:Hide() end
            else
                _hiddenForCombat = false
            end
            if RS.Settings and RS.Settings.frame and RS.Settings.frame:IsShown() then
                RS.Settings.frame:Hide()
            end
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Leaving combat
        local mode = RS_Settings and RS_Settings.combatHide or "hide_show_on_exit"
        if mode == "hide_show_on_exit" and _hiddenForCombat then
            if RS.UI and RS.UI.frame then RS.UI.frame:Show() end
        end
        _hiddenForCombat = false

    elseif event == "TOYS_UPDATED" then
        -- Toy collection has finished loading. Re-check Arcantina Key ownership.
        -- C_ToyBox.HasToy() can return false on login before this event fires.
        RS:DetectArcantinaKey()
    end
end)

-- Checks all available APIs for Arcantina Key ownership and sets RS_Settings.hasArcantinaKey.
-- Called on ADDON_LOADED (with delay), PLAYER_ENTERING_WORLD (with delay), and TOYS_UPDATED.
-- PlayerHasToy() is the older global form; C_ToyBox.HasToy() is the namespace form.
-- Both check the same underlying collection; we try both to maximise compatibility.
-- Quest 86903 ("The Arcantina") is a permanent character flag set when the key was granted.
function RS:DetectArcantinaKey()
    if not RS_Settings then return end
    -- Already confirmed in this session — no need to recheck
    if RS_Settings.hasArcantinaKey then
        if RS.UI and RS.UI.UpdateToolBar then RS.UI:UpdateToolBar() end
        return
    end
    -- Try PlayerHasToy (global function, available in all retail versions)
    if PlayerHasToy and PlayerHasToy(253629) then
        RS_Settings.hasArcantinaKey = true
    -- Try C_ToyBox.HasToy (namespace form)
    elseif C_ToyBox and C_ToyBox.HasToy and C_ToyBox.HasToy(253629) then
        RS_Settings.hasArcantinaKey = true
    -- Fallback: permanent quest completion flag
    elseif IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(86903) then
        RS_Settings.hasArcantinaKey = true
    end
    if RS.UI and RS.UI.UpdateToolBar then RS.UI:UpdateToolBar() end
end

function RS:Initialize()
    -- Merge saved settings with defaults
    if not RS_Settings then
        RS_Settings = CopyTable(DEFAULTS)
    else
        for k, v in pairs(DEFAULTS) do
            if RS_Settings[k] == nil then
                RS_Settings[k] = v
            end
        end
    end

    if not RS_CharData then
        RS_CharData = {
            completedWeeklies = {},
            lastReset         = 0,
            activityTimes     = {},   -- personal timing per activity/quest { n, total, last }
        }
    end
    -- Back-fill for characters whose RS_CharData predates this version
    if not RS_CharData.activityTimes then RS_CharData.activityTimes = {} end
    -- Migrate old split wqTimes table into unified activityTimes if present
    if RS_CharData.wqTimes then
        for k, v in pairs(RS_CharData.wqTimes) do
            if not RS_CharData.activityTimes[k] then
                RS_CharData.activityTimes[k] = v
            end
        end
        RS_CharData.wqTimes = nil
    end

    -- Check if weekly reset has occurred and clear completed weeklies
    RS:CheckWeeklyReset()

    -- Auto-detect Arcantina Key ownership.
    -- Toy data may not be loaded yet at ADDON_LOADED, so we try now with a short
    -- delay and also respond to TOYS_UPDATED which fires when the collection is ready.
    C_Timer.After(1, function() RS:DetectArcantinaKey() end)

    -- Build UI
    RS.UI:Init()
    RS.Minimap:Init()

    -- Hook MapCanvas.MapSet to rescan when player navigates the world map.
    -- C_TaskQuest data only populates after the player views a zone in the map UI.
    -- This triggers a rescan + rebuild so new WQs appear in the route.
    pcall(function()
        EventRegistry:RegisterCallback("MapCanvas.MapSet", function()
            if not RS._expansionActive then return end
            -- Debounce: MapCanvas.MapSet fires rapidly while navigating
            if RS._mapSetTimer then RS._mapSetTimer:Cancel() end
            RS._mapSetTimer = C_Timer.NewTimer(0.5, function()
                RS:ScanQuests()
                RS:BuildRoute()
                if RS.UI and RS.UI.isOpen and RS.UI.Refresh then RS.UI:Refresh() end
                RS._mapSetTimer = nil
            end)
        end)
    end)

    print("|cffC8A96ERouteSweet|r v" .. RS.VERSION .. " loaded. Type |cffC8A96E/rs|r to open.")
end

function RS:OnPlayerEnteringWorld()
    -- Detect which expansion(s) apply to this character
    local hasActive = RS.Expansion:DetectActive()
    if not hasActive then
        print("|cffC8A96ERouteSweet|r v" .. RS.VERSION ..
              " — No supported expansion for level " .. (UnitLevel("player") or "?") ..
              ". Supported: " .. RS.Expansion:ListSupported())
        RS._expansionActive = false
        return
    end
    RS._expansionActive = true

    -- Initialize travel tools (class teleports, toys, etc.)
    if RS.TravelTools and RS.TravelTools.Init then
        RS.TravelTools:Init()
    end

    -- Clear any stale chain from a previous session
    if RS.Waypoint and RS.Waypoint.Stop then RS.Waypoint:Stop() end
    C_Timer.After(2, function()
        RS:ScanQuests()
        RS:BuildRoute()
        -- GetBindLocation() resolves correctly after the player fully enters the world.
        if RS.UI and RS.UI.UpdateToolBar then RS.UI:UpdateToolBar() end
        -- Re-detect Arcantina Key (toy data may not be loaded at ADDON_LOADED).
        RS:DetectArcantinaKey()
        if RS.UI and RS.UI.isOpen and RS.UI.Refresh then RS.UI:Refresh() end
    end)
    if RS.Dump and RS.Dump.AutoRun then RS.Dump:AutoRun() end
end

function RS:OnQuestLogUpdate()
    -- Debounce rapid quest log updates
    if RS._questUpdateTimer then
        RS._questUpdateTimer:Cancel()
    end
    RS._questUpdateTimer = C_Timer.NewTimer(1, function()
        RS:ScanQuests()
        if RS.UI and RS.UI.isOpen then
            RS.UI:Refresh()
        end
    end)
end

function RS:CheckWeeklyReset()
    -- Use the game's own authoritative reset epoch via GetSecondsUntilWeeklyReset.
    -- Tuesday 10:00 AM EST (15:00 UTC) for US realms — but we never hardcode this;
    -- the game's API is the source of truth regardless of maintenance schedule.
    -- Off-cycle maintenance (hotfixes, emergency restarts) does NOT trigger a weekly
    -- reset and must not clear weeklies. Only an actual weekly epoch change counts.
    --
    -- Strategy: compute the epoch of the most recent weekly reset as
    --   resetEpoch = now - (sevenDays - secondsUntilNextReset)
    -- and compare that against the stored lastReset epoch.
    -- If they differ by more than a few minutes (clock skew buffer), a real weekly
    -- reset has occurred since we last logged in.

    local secondsUntilNext = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
                             and C_DateAndTime.GetSecondsUntilWeeklyReset()
    if not secondsUntilNext then return end  -- API unavailable, skip

    local now        = GetServerTime()
    local sevenDays  = 7 * 24 * 3600
    local resetEpoch = now - (sevenDays - secondsUntilNext)

    -- Buffer of 5 minutes to absorb clock skew / login timing jitter
    local SKEW_BUFFER = 300
    if resetEpoch > ((RS_CharData.lastReset or 0) + SKEW_BUFFER) then
        RS_CharData.completedWeeklies = {}
        RS_CharData.soireeChoiceCache = nil
        RS_CharData.lastReset = resetEpoch
        -- NOTE: activityTimes is intentionally NOT cleared here.
        -- World quest IDs are stable per-quest definition and accumulate
        -- meaningful signal across resets. See Core/Timing.lua for details.
    end
end

-- ============================================================
-- SLASH COMMANDS
-- ============================================================
SLASH_RS1, SLASH_RS2 = "/rs", "/routesweet"
SlashCmdList["RS"] = function(msg)
    local cmd = strtrim(msg):lower()
    if cmd == "scan" then
        RS:ScanQuests()
        RS.UI:Refresh()
    elseif cmd == "dump" then
        RS.Dump:Run(false)
        print("|cffaaaaaa  File: WTF/Account/<ACCOUNT>/<REALM>/<CHAR>/SavedVariables/RouteSweet.lua|r")
    elseif cmd == "nav" or cmd == "start" then
        local route = RS.currentRoute
        if route and route.stops and #route.stops > 0 then
            RS.Waypoint:Start(route.stops)
            RS.UI:UpdateNavBtn()
            RS.UI:UpdateProgressBar()
        else
            print("|cffC8A96ERouteSweet:|r No route loaded. Try /rs scan first.")
        end
    elseif cmd == "stop" then
        RS.Waypoint:Stop()
        RS.UI:UpdateNavBtn()
        RS.UI:UpdateProgressBar()
        print("|cffC8A96ERouteSweet:|r Navigation stopped.")
    elseif cmd == "reset" then
        RS_CharData.completedWeeklies = {}
        print("|cffC8A96ERouteSweet:|r Weekly data cleared.")
    elseif cmd == "resettime" or cmd:sub(1, 10) == "resettime " then
        -- /rs resettime        → clear ALL personal timing data
        -- /rs resettime all    → same
        -- (per-key reset is internal only; no safe way to expose raw keys to user)
        if RS.Timing then
            RS.Timing:ResetAll()
            print("|cffC8A96ERouteSweet:|r All personal timing data cleared. Estimates will use category defaults until you complete activities again.")
        end
    elseif cmd == "skyriding" then
        RS_Settings.useSkyriding = not RS_Settings.useSkyriding
        print("|cffC8A96ERouteSweet:|r Skyriding " .. (RS_Settings.useSkyriding and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
        RS:BuildRoute()
        RS.UI:Refresh()
    elseif cmd == "arcantina" then
        -- Manual toggle of Arcantina Key ownership for when auto-detection fails.
        -- Auto-detection tries PlayerHasToy(253629), C_ToyBox.HasToy(253629),
        -- IsQuestFlaggedCompleted(86903), and TOYS_UPDATED event. Use this only
        -- if all three automatic methods fail (rare toy-box loading edge case).
        RS_Settings.hasArcantinaKey = not RS_Settings.hasArcantinaKey
        print("|cffC8A96ERouteSweet:|r Arcantina Key manually set to "
            .. (RS_Settings.hasArcantinaKey and "|cff88ff88OWNED|r" or "|cff888888NOT OWNED|r")
            .. ". (Auto-detect runs at login via PlayerHasToy(253629) and TOYS_UPDATED.)")
        if RS.UI and RS.UI.UpdateToolBar then RS.UI:UpdateToolBar() end
    elseif cmd == "help" then
        print("|cffC8A96E-- RouteSweet Commands --|r")
        print("  |cffC8A96E/rs|r - Toggle main window")
        print("  |cffC8A96E/rs scan|r - Rescan world quests")
        print("  |cffC8A96E/rs nav|r - Start navigation chain from stop 1")
        print("  |cffC8A96E/rs stop|r - Stop navigation and clear waypoint")
        print("  |cffC8A96E/rs dump|r - Write character data snapshot to SavedVariables")
        print("  |cffC8A96E/rs skyriding|r - Toggle Skyriding/static flight")
        print("  |cffC8A96E/rs arcantina|r - Toggle Arcantina Key ownership (manual override if auto-detect fails)")
        print("  |cffC8A96E/rs resettime|r - Clear all personal timing data (resets to category defaults)")
    else
        RS.UI:Toggle()
    end
end
