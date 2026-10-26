# Troubleshooting known gaps and recovery

## Troubleshoot by pipeline stage

| Symptom | First evidence | Safe repair direction |
|---|---|---|
| Add-on absent from menu | Installed folder and direct TOC location | Correct the one selected add-on tree; avoid duplicate nested folders |
| Error before window opens | First Lua error and TOC order | Confirm namespace/registry/providers load before consumers |
| Empty route after login | Character level, active modules and map data | Wait for the real API response, view target map and scan again |
| Story quest shown as world quest | API source and normalized record type | Review scanner classification and duplicate filtering |
| Completed weekly returns | Turn-in ID, reset epoch and manual marker | Distinguish accepted/completed/turned-in data; do not clear all settings |
| Route order differs from shortest distance | Score, urgency, zone preferences and portal costs | Inspect biased ordering separately from displayed time |
| Wrong estimate after First group | Stop wrapper and totals | Inspect group chaining and cumulative offsets for this exact repository |
| Quest stop will not advance on arrival | Quest ID and turn-in event | Proximity alone intentionally does not finish a quest |
| Personal average seems wrong | Count, total, last sample and activity key | Diagnose sample origin before a targeted data-reset decision |
| UI disappears in combat | combatHide and restore state | Check configured visibility behavior before rebuilding frames |
| Dump seems huge or private | Captured sections and character identity | Keep raw capture local and share only the necessary sanitized finding |

## Repository-specific findings

The First-zone branch needs a regression fixture for unwrapped final coordinates and complete totals. The shared scanner currently merges quest-log map entries into the world-quest path without the development tree's source-specific story-quest exclusion. Leveling quest-line requests can also need explicit asynchronous prefetch/retry evidence. These are observed source differences, not a claim that an installed character has reproduced each defect. Fix them in this repository with its own tests and review; do not silently treat a neighboring checkout as this revision.

The two version declarations disagree and the README describes several older paths and roadmap items. Reconcile them in a documentation/release task tied to actual source. A developer should not need to infer whether a settings panel exists or whether an entry belongs in the expansion directory. Completion means the TOC, bootstrap display, installation instructions and screenshots of the current interface identify the same release.

The source is rich in client integration but lacks an inspected conventional automated suite. Prioritize small pure fixtures for route membership, directed cost, timing aggregation, weekly reset and saved-schema migration. Add integration observations for delayed map data, restricted values, combat transitions and actual quest completion. Do not use `pcall` alone as proof of correctness: suppressing an exception can still leave a plausible but wrong fallback result.

## Data and estimate limitations

Some event rotations and spawn availability are estimated from time or static data. API comments and old quest-ID confirmations are not perpetual guarantees. Record which observation confirmed an ID and which client revision it applied to. Keep unknown IDs explicitly unknown, with a manual completion path where needed. Do not add fabricated IDs to make a table look complete.

The personal average accumulates samples without a fixed moving-window cap. That is simple and stable, but a major objective change can leave old timings influencing new estimates. A future versioned activity key or reviewed migration may be useful. Acceptance should prove old good data is preserved when compatible and invalidated only for a stated reason when the activity's meaning changes.

Routing has preference biases, heuristic limits and directed travel effects. A proposed speed improvement must preserve membership and annotation correctness before optimizing execution time. Use final route cost and useful stop ordering as outcomes; do not claim a better route solely because an intermediate matrix calculation runs faster.

## Recovery and safe rollback

Close the game before restoring a previous add-on tree or SavedVariables backup. Restore only the intended add-on and its matching schema-compatible saved data, retaining the failed version and a sanitized error report for diagnosis. Do not replace the whole game profile or another add-on's settings. A source rollback does not automatically reverse a saved-data migration, which is why versioned migration tests and pre-update copies matter.

Stopping navigation with `/rs stop` is ordinary cleanup. Clearing completion or learned timing is a separate data operation. Normal logout/quit gives the client a chance to persist current variables. The actual game installation and NixOS launcher remain external to this source tree and need their own preserved profiles and qualification evidence.

## Prioritized continuation plan

First establish reproducible pure test fixtures and source/installed-version identification. Next close the repository-specific scanner/grouping issues with isolated expected-route examples. Then verify saved-data migration and a real supported client journey, including a fresh map-data case and a portal route. Finally improve measured estimate quality and scalability only after the basic contracts are trustworthy. Each repair should name its files, expected user result and retained data; a later developer should be able to prove it without an assistant explaining an earlier session.
