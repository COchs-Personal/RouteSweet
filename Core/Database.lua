-- Core/Database.lua
-- Expansion-agnostic database for RouteSweet
--
-- Contains shared player-tool helpers that apply to all expansions:
--   • Flight mode detection (Skyriding vs Static)
--
-- Expansion-specific data (Soiree, Housing, Dungeons, Currencies, Factions)
-- lives in Expansions/<name>/Database.lua and registers via the expansion system.
--
-- RS.DB is aliased to the active expansion's database at runtime by
-- RS.Expansion:DetectActive(). The methods defined here are copied onto
-- whichever expansion DB becomes active, so RS.DB:DetectFlightMode() works
-- regardless of which expansion is loaded.

RS.DB = RS.DB or {}

-- ============================================================
-- FLIGHT MODE DETECTION
-- Reads actual game state to determine skyriding vs static flight.
-- Expansion-agnostic — works at any level, in any zone.
-- Returns:
--   mode    = "skyriding" | "static" | "unknown"
--   speedYps = current movement speed in yards/sec (nil if not mounted)
--   source  = human-readable string explaining what was detected
--   hasSkyridingAura, flying, mounted = raw detection flags
-- ============================================================
local DYNAMIC_FLIGHT_SPELL_IDS = {
    [388699] = true,  -- Skyriding passive (universal)
    [404468] = true,  -- Renewed Proto-Drake: Skyriding
    [369922] = true,  -- Windborne Veloci: Skyriding
    [388552] = true,  -- Highland Drake: Skyriding
}

function RS.DB:DetectFlightMode()
    local speedYps = nil
    local mode     = "unknown"
    local source   = "not mounted"

    local currentSpeed = GetUnitSpeed("player") or 0
    local mounted = IsMounted()
    local flying = IsFlying()

    local hasSkyridingAura = false
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        hasSkyridingAura = C_UnitAuras.GetPlayerAuraBySpellID(388699) ~= nil
    else
        for i = 1, 40 do
            local _, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", i)
            if not spellID then break end
            if DYNAMIC_FLIGHT_SPELL_IDS[spellID] then
                hasSkyridingAura = true
                break
            end
        end
    end

    if hasSkyridingAura then
        mode   = "skyriding"
        source = "Skyriding aura active"
    elseif flying and mounted then
        mode   = "static"
        source = "flying, no Skyriding aura"
    elseif mounted and not flying then
        mode   = RS_Settings and RS_Settings.useSkyriding and "skyriding" or "static"
        source = "ground-mounted (using saved preference)"
    else
        mode   = RS_Settings and RS_Settings.useSkyriding and "skyriding" or "static"
        source = "unmounted (using saved preference)"
    end

    if currentSpeed > 0 then
        speedYps = currentSpeed
    end

    return mode, speedYps, source, hasSkyridingAura, flying, mounted
end
