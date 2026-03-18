-- Core/TravelTools.lua
-- Class-specific teleports, toys, and profession tools for routing shortcuts.
-- Detects player class at init, registers known travel spells, checks cooldowns.
-- FlightTime.lua queries this to find cheaper routes.
--
-- LOAD ORDER: After Core/Database.lua, before Core/FlightTime.lua

RS.TravelTools = RS.TravelTools or {}

local TT = RS.TravelTools

-- ============================================================
-- SPELL COOLDOWN HELPER (12.0 API)
-- GetSpellCooldown was REMOVED in 11.0.0.
-- Must use C_Spell.GetSpellCooldown which returns a table.
-- ============================================================
function TT:GetSpellCDRemaining(spellID)
    if not spellID then return 0 end
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
        if ok and info and info.duration and info.duration > 0 then
            local remaining = (info.startTime + info.duration) - GetTime()
            return math.max(0, remaining)
        end
        return 0
    end
    -- Legacy fallback (pre-11.0, shouldn't be needed in 12.0)
    if GetSpellCooldown then
        local ok, start, dur = pcall(GetSpellCooldown, spellID)
        if ok and start and dur and dur > 0 then
            local remaining = (start + dur) - GetTime()
            return math.max(0, remaining)
        end
    end
    return 0
end

-- Returns true if spell is known and off cooldown (or within buffer seconds)
function TT:IsSpellReady(spellID, bufferSecs)
    if not spellID then return false end
    if not self:IsSpellKnown(spellID) then return false end
    local cd = self:GetSpellCDRemaining(spellID)
    return cd <= (bufferSecs or 2)
end

-- Check if player knows a spell (12.0 API)
function TT:IsSpellKnown(spellID)
    if not spellID then return false end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
        return ok and known
    end
    -- Legacy fallback
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, spellID)
        return ok and known
    end
    if IsSpellKnown then
        local ok, known = pcall(IsSpellKnown, spellID)
        return ok and known
    end
    return false
end

-- ============================================================
-- TRAVEL TOOL DEFINITIONS
-- Each tool: { spellID, name, class (nil=any), destination mapID,
--              cooldown (seconds), castTime (seconds), type }
-- type: "teleport" (self), "portal" (group), "hearthstone", "toy"
-- ============================================================

-- Midnight-relevant destinations mapped to our zone IDs
local SILVERMOON = 2393

TT.TOOLS = {
    -- ── MAGE TELEPORTS ──────────────────────────────────────
    -- Midnight Silvermoon (new in 12.0)
    { spellID = 1259190, name = "Teleport: Silvermoon City",   class = "MAGE", faction = "Horde",
      destMapID = SILVERMOON, cooldown = 0, castTime = 10, ttype = "teleport" },
    -- Old Silvermoon (BC)
    { spellID = 32272,   name = "Teleport: Silvermoon",        class = "MAGE", faction = "Horde",
      destMapID = SILVERMOON, cooldown = 0, castTime = 10, ttype = "teleport" },
    -- Orgrimmar (Horde hub — has portal to Silvermoon)
    { spellID = 3567,    name = "Teleport: Orgrimmar",         class = "MAGE", faction = "Horde",
      destMapID = nil, cooldown = 0, castTime = 10, ttype = "teleport", hubCity = true },
    -- Stormwind (Alliance hub)
    { spellID = 3561,    name = "Teleport: Stormwind",         class = "MAGE", faction = "Alliance",
      destMapID = nil, cooldown = 0, castTime = 10, ttype = "teleport", hubCity = true },
    -- Dornogal (Khaz Algar — TWW hub)
    { spellID = 446540,  name = "Teleport: Dornogal",          class = "MAGE",
      destMapID = nil, cooldown = 0, castTime = 10, ttype = "teleport", hubCity = true },
    -- Valdrakken (Dragonflight hub)
    { spellID = 395277,  name = "Teleport: Valdrakken",        class = "MAGE",
      destMapID = nil, cooldown = 0, castTime = 10, ttype = "teleport", hubCity = true },
    -- Oribos (Shadowlands)
    { spellID = 344587,  name = "Teleport: Oribos",            class = "MAGE",
      destMapID = nil, cooldown = 0, castTime = 10, ttype = "teleport", hubCity = true },

    -- ── MAGE PORTALS (group — same destinations) ────────────
    { spellID = 1259194, name = "Portal: Silvermoon City",     class = "MAGE", faction = "Horde",
      destMapID = SILVERMOON, cooldown = 0, castTime = 10, ttype = "portal" },
    { spellID = 32267,   name = "Portal: Silvermoon",          class = "MAGE", faction = "Horde",
      destMapID = SILVERMOON, cooldown = 0, castTime = 10, ttype = "portal" },

    -- ── DRUID ────────────────────────────────────────────────
    { spellID = 193753,  name = "Dreamwalk",                   class = "DRUID",
      destMapID = nil, cooldown = 60, castTime = 10, ttype = "teleport",
      notes = "Emerald Dreamway hub — portals to multiple zones" },
    { spellID = 18960,   name = "Teleport: Moonglade",         class = "DRUID",
      destMapID = nil, cooldown = 600, castTime = 10, ttype = "teleport" },

    -- ── DEATH KNIGHT ─────────────────────────────────────────
    { spellID = 50977,   name = "Death Gate",                  class = "DEATHKNIGHT",
      destMapID = nil, cooldown = 60, castTime = 4, ttype = "teleport",
      notes = "Acherus: The Ebon Hold. Cast again to return." },

    -- ── MONK ─────────────────────────────────────────────────
    { spellID = 126892,  name = "Zen Pilgrimage",              class = "MONK",
      destMapID = nil, cooldown = 60, castTime = 10, ttype = "teleport",
      notes = "Peak of Serenity / Temple of Five Dawns. Cast again to return." },

    -- ── SHAMAN ───────────────────────────────────────────────
    { spellID = 556,     name = "Astral Recall",               class = "SHAMAN",
      destMapID = nil, cooldown = 600, castTime = 10, ttype = "hearthstone",
      notes = "Second hearthstone on separate 10min cooldown. Same bind location." },

    -- ── GENERAL TOYS / ITEMS ─────────────────────────────────
    -- Hearthstone (all classes)
    { spellID = 8690,    name = "Hearthstone",                 class = nil,
      destMapID = nil, cooldown = 900, castTime = 10, ttype = "hearthstone",
      itemID = 6948 },
    -- Dalaran Hearthstone
    { spellID = 1245828, name = "Dalaran Hearthstone",         class = nil,
      destMapID = nil, cooldown = 1200, castTime = 10, ttype = "toy",
      itemID = 140192, notes = "Teleports to Dalaran (Deadwind Pass in retail)" },
    -- Garrison Hearthstone
    { spellID = 171253,  name = "Garrison Hearthstone",        class = nil,
      destMapID = nil, cooldown = 1200, castTime = 10, ttype = "toy",
      itemID = 110560, notes = "Teleports to Draenor garrison" },
    -- Arcantina Key (Midnight-specific, warband toy)
    { spellID = 1255801, name = "Key to the Arcantina",        class = nil,
      destMapID = SILVERMOON, cooldown = 900, castTime = 2, ttype = "toy",
      itemID = 253629,
      notes = "Use → Arcantina (8s) → exit portal → Silvermoon Inn (~38s total)" },
}

-- ============================================================
-- INITIALIZATION
-- Detects player class/faction and builds the available tools list.
-- Called once at PLAYER_ENTERING_WORLD.
-- ============================================================
TT._available = nil  -- populated by Init
TT._initialized = false

function TT:Init()
    local _, classFilename = UnitClass("player")
    local faction = UnitFactionGroup("player")
    self._playerClass   = classFilename  -- "MAGE", "DRUID", etc.
    self._playerFaction = faction          -- "Alliance" or "Horde"
    self:Refresh()

    -- Register for events that indicate deferred data is now available.
    -- TOYS_UPDATED: toy collection finishes loading (C_ToyBox.HasToy returns stale before this)
    -- SPELLS_CHANGED: spellbook data loaded or spells learned/unlearned
    -- PLAYER_ENTERING_WORLD: zone change can affect available spells (e.g. restricted zones)
    if not self._initialized then
        self._initialized = true
        local eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("TOYS_UPDATED")
        eventFrame:RegisterEvent("SPELLS_CHANGED")
        eventFrame:SetScript("OnEvent", function(_, event)
            -- Debounce: SPELLS_CHANGED can fire rapidly
            if TT._refreshTimer then TT._refreshTimer:Cancel() end
            TT._refreshTimer = C_Timer.NewTimer(1, function()
                TT:Refresh()
                TT._refreshTimer = nil
            end)
        end)
    end
end

-- Rebuilds the available tools list.
-- Called on init, TOYS_UPDATED, and SPELLS_CHANGED.
function TT:Refresh()
    self._available = {}
    local cls = self._playerClass
    local fac = self._playerFaction
    if not cls then return end  -- Init hasn't run yet

    for _, tool in ipairs(self.TOOLS) do
        -- Class filter: nil = any class, otherwise must match
        local classOK = (tool.class == nil) or (tool.class == cls)
        -- Faction filter: nil = any faction, otherwise must match
        local factionOK = (tool.faction == nil) or (tool.faction == fac)

        if classOK and factionOK then
            local known = false
            if tool.itemID then
                -- Hearthstone is always known
                if tool.itemID == 6948 then
                    known = true
                else
                    -- Toy/item: check via C_ToyBox.HasToy (may return false before TOYS_UPDATED)
                    if C_ToyBox and C_ToyBox.HasToy then
                        pcall(function() known = C_ToyBox.HasToy(tool.itemID) end)
                    end
                    -- Fallback: check via PlayerHasToy (older global, still works in 12.0)
                    if not known and PlayerHasToy then
                        pcall(function() known = PlayerHasToy(tool.itemID) end)
                    end
                    -- Fallback: check quest completion for toys that have unlock quests
                    -- (e.g. Arcantina Key = quest 86903)
                    if not known and tool.itemID == 253629 then
                        if IsQuestFlaggedCompleted then
                            pcall(function() known = IsQuestFlaggedCompleted(86903) end)
                        end
                        -- Manual override from settings
                        if not known then
                            known = RS_Settings and RS_Settings.hasArcantinaKey or false
                        end
                    end
                end
            else
                -- Spell: check via multiple APIs for resilience
                known = self:IsSpellKnown(tool.spellID)
            end

            if known then
                table.insert(self._available, tool)
            end
        end
    end
end

-- ============================================================
-- QUERY API — used by FlightTime and Routing
-- ============================================================

-- Returns all available travel tools for this character.
function TT:GetAvailable()
    if not self._available then self:Init() end
    return self._available
end

-- Returns the best (lowest cost) travel tool that reaches destMapID,
-- or nil if none available. Cost = cast time + cooldown remaining.
function TT:GetBestToolTo(destMapID)
    if not destMapID then return nil end
    if not self._available then self:Init() end

    local best = nil
    local bestCost = math.huge

    for _, tool in ipairs(self._available) do
        if tool.destMapID == destMapID then
            local cd = self:GetSpellCDRemaining(tool.spellID)
            if cd <= 2 then  -- available (within GCD buffer)
                local cost = tool.castTime + cd
                if cost < bestCost then
                    bestCost = cost
                    best = tool
                end
            end
        end
    end

    return best, bestCost
end

-- Returns the best hearthstone-type tool available (Hearthstone, Astral Recall, etc.)
function TT:GetBestHearth()
    if not self._available then self:Init() end

    local best = nil
    local bestCD = math.huge

    for _, tool in ipairs(self._available) do
        if tool.ttype == "hearthstone" then
            local cd = self:GetSpellCDRemaining(tool.spellID)
            if cd < bestCD then
                bestCD = cd
                best = tool
            end
        end
    end

    return best, bestCD
end

-- Returns true if the player has any teleport to the given mapID
-- that is currently off cooldown.
function TT:HasReadyTeleportTo(destMapID)
    local tool, cost = self:GetBestToolTo(destMapID)
    return tool ~= nil
end

-- Returns a summary string of available tools (for tooltip/debug)
function TT:GetSummary()
    if not self._available then self:Init() end
    local lines = {}
    for _, tool in ipairs(self._available) do
        local cd = self:GetSpellCDRemaining(tool.spellID)
        local status = cd <= 2 and "|cff00ff00Ready|r" or ("|cffff4444" .. math.ceil(cd) .. "s|r")
        table.insert(lines, "  " .. tool.name .. " — " .. status)
    end
    return table.concat(lines, "\n")
end
