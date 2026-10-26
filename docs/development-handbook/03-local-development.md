# Install and prepare development

## Install exactly the add-on tree

Inspect the repository and TOC before copying files. For this repository, the repository root contains `RouteSweet.lua`, `RouteSweet.toc`, `Core`, `UI`, `Expansions` and `Textures`. The installed structure must put `RouteSweet.toc` directly inside the selected client's `Interface/AddOns/RouteSweet` directory. An extra nested download folder can make the client fail to discover the add-on. Do not copy the whole repository's documentation or version-control directory into the game by accident.

Use the actual retail game installation selected in the launcher. Different installations or compatibility prefixes can have different add-on and saved-data trees. On NixOS, the game itself is an external platform dependency; this repository does not define a pinned native launcher or a full game installation recipe. Keep that uncertainty separate from Lua source portability. Installing or changing the host's launcher/graphics configuration is outside an ordinary add-on code edit.

Enable RouteSweet in the game's AddOns list and inspect its displayed version and compatibility warning. TomTom is optional according to the source README; the current waypoint module provides native map pins. Do not add an unneeded background web server or model service to solve an add-on load failure.

## Establish a safe development instance

Before updating an installed copy, exit the game normally and back up its add-on source and the relevant account and character SavedVariables files. Use a separate test character/profile where possible. The client writes SavedVariables during its own lifecycle, so editing those files while the client is running can be overwritten on exit. Keep account identifiers, character information, bag/quest data and full diagnostic dumps private.

Record the tested source commit and installed destination identity in a local report without publishing machine paths or account names. A source checkout and an installed add-on are two copies. A test result is useful only when you know which one the game loaded. Compare a deliberate harmless version or diagnostic marker when necessary, then remove temporary product clutter before publication.

## Configuration in source and SavedVariables

| Setting or record | Meaning | Current default or behavior |
|---|---|---|
| useSkyriding | Preferred flight model when live detection cannot decide | true |
| questTime | Fallback activity minutes |7; personal/category timing can take precedence |
| autoScan | Scan from relevant map events | true |
| waypointOnSelect | Selection navigation preference | true in defaults |
| portalBuffer | Additional portal transition allowance |2 minutes |
| combatHide | Window behavior during combat | hide_show_on_exit |
| activeProfile and profiles | Read-only default or custom ordered preferences | Default plus named custom profiles |
| completedWeeklies | Per-character manual completion markers | Cleared by real reset epoch or explicit reset |
| activityTimes | Per-character sample count total and last duration | Retained across normal weekly reset |
| RS_DumpData | Diagnostic capture | Character-scoped and potentially private |

`GetActiveProfile` returns the built-in default when the requested profile is missing. `CreateProfile` copies activity and reward lists; later-added nested profile fields need an explicit copy/migration decision. Do not assume its one-level `DeepCopy` recursively handles arbitrarily nested future schemas. Settings UI callbacks and scanner consumers must agree on the shape.

## Validation without a game client

The inspected repository has no conventional npm or Python application test command. A Lua syntax check, if an appropriate Lua compiler is already available, can catch parse errors but cannot supply Blizzard frames, events or restricted API semantics. Use source review and a small future stubbed test harness for pure routing/timing calculations, then actual client acceptance for integration. Do not present an absent test suite as passing.

A practical future harness can supply a minimal `RS` table, load the independent module being tested, and replace time/map APIs with controlled functions. Keep such tests separate from the live client and record precisely which APIs were stubbed. Source errors that occur only in combat or after asynchronous map loading still need the real boundary checked.

## Normal close and data retention

Use `/rs stop` to end a navigation chain and clear the active pin; hiding the route window is a different action. Finish the game session through normal logout or quit so the client can write SavedVariables. Back up saved data with the game closed before changing versions. Do not use `/rs reset` or `/rs resettime` as generic troubleshooting commands: they deliberately remove completion or learned timing data.
