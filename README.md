# RouteSweet
### WoW Midnight 12.0.1 — Shortest-Path World Quest & Event Route Planner

---

## What It Does

RouteSweet automatically builds an optimised travel route across all active world quests, weekly events, and timed activities in Quel'Thalas. It minimises total travel time using a **Nearest-Neighbour + 2-opt TSP algorithm** while accounting for:

- **Skyriding vs static mount speeds** (togglable, with short/medium/long distance speed profiles)
- **Portal zone penalties** — Harandar and Voidstorm require portal transit via Silvermoon; the router batches same-zone visits to minimise redundant portal hops
- **7-minute base quest time** (configurable) per stop
- **Expiry urgency** — quests expiring within 4 hours are pulled to the front of the route
- **Abundance cave rotation** — automatically detects which cave is active (8-hour cycle) and shows time remaining
- **Stormarion Assault timer** — 30-minute event spawn in Voidstorm

---

## Installation

1. Download/clone this folder
2. Place `RouteSweet/` into `World of Warcraft/_retail_/Interface/AddOns/`
3. Launch WoW and enable the addon in the AddOns menu
4. Optionally install **TomTom** for enhanced waypoint arrows (the addon falls back to Blizzard native waypoints if TomTom isn't present)

**Note:** This addon does **not** require or conflict with WeakAuras, which is deprecated in Midnight. It uses only out-of-combat APIs (`C_TaskQuest`, `C_QuestLog`, `C_Reputation`, `C_Map`, `C_WeeklyRewards`) that are fully supported in 12.0.1.

---

## Usage

| Command | Action |
|---|---|
| `/rs` | Open/close the route window |
| `/rs scan` | Rescan all world quests and rebuild route |
| `/rs skyriding` | Toggle between Skyriding and static mount |
| `/rs reset` | Clear this week's manual completion data |
| `/rs help` | Show all commands |

**In the UI:**
- **Left-click** a stop → Sets a waypoint (TomTom arrow or native Blizzard waypoint)
- **Right-click** a stop → Mark as done (removes from route)
- **⟳ Scan** button → Rescan quests
- **🐉 Skyriding / 🦅 Static** toggle → Switch mount type and rebuild route instantly
- **Minimap button** → Left-click to toggle, right-click to rescan, drag to reposition

---

## Route Display

Each row shows:

| Column | Description |
|---|---|
| `#` | Stop order in the optimised route |
| Activity | Name with type icon (● WQ, ◆ Weekly, ★ Event, ◎ Rotation, ⚡ Timed) |
| Zone | Zone name |
| Travel | Flight time to this stop from previous stop |
| Est. | Estimated activity duration |
| Total | Cumulative time elapsed at end of this stop |

Travel time colour coding:
- 🟢 Green = under 90 seconds
- 🟡 Gold = 90s–4 minutes  
- 🟠 Orange = over 4 minutes (consider portal or batching)

Urgent activities (expiring within 4 hours) are highlighted in **red**.

---

## How the Routing Works

```
1. Scan all active world quests via C_TaskQuest.GetQuestsOnMap()
2. Scan static weeklies (Saltheril's Soiree, Legends of the Haranir, etc.)
3. Detect active Abundance cave (server time % 8hr rotation cycle)
4. Score each activity (reward type + expiry urgency + base priority)
5. Build NxN travel time cost matrix using zone coordinates + flight speeds
6. Run Nearest-Neighbour greedy algorithm from player's current position
7. Run 2-opt improvement passes to eliminate crossing paths
8. Apply portal zone batching (group Harandar/Voidstorm visits together)
9. Annotate stops with portal waypoints, cumulative times, and urgency flags
```

---

## Skyriding Speed Model

Skyriding uses variable speeds based on flight distance (momentum build-up):

| Distance | Speed | Notes |
|---|---|---|
| < 500 yards | ~40 yd/s | Short hop, no momentum |
| 500–1500 yards | ~75 yd/s | Medium flight |
| > 1500 yards | ~110 yd/s | Full speed with dives |

Static mount uses a flat **26 yd/s** (280% flight speed).

Both modes add overhead for mount-up (2s) and dismount/walk-to-objective (8s).

---

## Portal Zone Travel Times

| Route | Estimated Time | Notes |
|---|---|---|
| Silvermoon → Harandar portal | ~2.5 min | West side of Silvermoon |
| Silvermoon → Voidstorm portal | ~2.5 min | West side of Silvermoon |
| Harandar → Voidstorm (direct) | ~1.5 min | Portal at lower level of The Den |
| Voidstorm → Harandar (direct) | ~1.5 min | Portal at Stormarion Citadel |
| Eversong → Zul'Aman (Skyriding) | ~1.5 min | |
| Eversong → Zul'Aman (Static) | ~2.5 min | |

**Note:** Harandar and Voidstorm have direct portals to each other — the router no longer routes through Silvermoon when travelling between them.

---

## Quest IDs (sourced from Wowhead)

All IDs verified at wowhead.com. Use `/run print(C_QuestLog.IsQuestFlaggedCompleted(NNNNN))` in-game to confirm.

| Activity | Quest | ID | Wowhead |
|---|---|---|---|
| Saltheril's Soiree | Weekly task | 91966 | /quest=91966 |
| Saltheril's Soiree | Meta (World Tour) | 93889 | /quest=93889 |
| Legends of the Haranir | Lost Legends (pick-up) | 89268 | /quest=89268 |
| Legends of the Haranir | Legendary Prosperity (turn-in) | 93932 | /quest=93932 |
| Legends of the Haranir | Meta (World Tour) | 93891 | /quest=93891 |
| Stormarion Assault | World Quest | 90962 | /quest=90962 |
| Stormarion Assault | Meta (World Tour) | 93892 | /quest=93892 |
| Weekly: Abundance | Weekly meta (20,000 pts) | 89507 | /beta/quest=89507 |
| Midnight: World Tour | Expansion meta quest | 95245 | /quest=95245 |

`questIDTurnin` is used for completion detection where available (more reliable than the pick-up quest ID, which clears on accept rather than completion).

---

## Configuration (RS_Settings)

Saved in `SavedVariables`. You can edit these directly or we'll add a proper options panel in a future release:

| Key | Default | Description |
|---|---|---|
| `useSkyriding` | `true` | Skyriding speed model |
| `questTime` | `7` | Minutes per quest/activity |
| `filterExpiringSoon` | `true` | Boost priority of expiring quests |
| `autoScan` | `true` | Rescan when opening world map |
| `waypointOnSelect` | `true` | Set waypoint on stop click |
| `portalBuffer` | `2` | Extra minutes added for portal transitions |

---

## Remaining nil Quest IDs

Most quest IDs are now populated from Wowhead. The only remaining `nil` entry is:

- **Weekly Dungeon Quest (Biergoth)** — this NPC offers a different quest each week targeting a specific dungeon; there is no single static ID to track. Completion is handled by manual right-click marking in the UI.

If you discover additional IDs (e.g. future patch weeklies), add them to the relevant entry in `Core/Zones.lua` and they will be picked up automatically.

---

## Known Limitations

- **Secret values**: In Midnight 12.0, quest reward APIs can return opaque "secret values" when in combat. All scanning is wrapped in `pcall` to prevent errors, but reward type detection (gear/gold/rep) may occasionally fall back to "misc".
- **Abundance caves**: Rotation slot is estimated from server time modulo; exact cave order isn't published by Blizzard and may drift slightly.
- **Stormarion Assault**: The 30-minute spawn cycle start time isn't exposed via API; the addon flags it as available but can't confirm the next wave timer without a server event hook.
- **Quest IDs**: Some `questID` values are `nil` pending in-game confirmation post-launch. Completion detection for those activities falls back to manual right-click marking.

---

## Roadmap

- [ ] Options panel UI (quest time slider, priority toggles)  
- [ ] Legacy content mode (Khaz Algar / TWW activities for alts)
- [ ] Prey hunt integration (Normal / Hard / Nightmare tracking)
- [ ] Great Vault progress display
- [ ] Multi-character warband view (flag Warband-locked activities)
- [ ] Export route as macro `/way` list

---

## Acknowledgements

Travel time model informed by community speed testing from Wowhead and MMO-Champion forums. Zone map IDs from the Warcraft Wiki API reference. Coordinate data from Icy Veins TomTom waypoint guides.
