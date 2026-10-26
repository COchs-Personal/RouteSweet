# Understand RouteSweet

RouteSweet is a Lua add-on running inside a selected retail World of Warcraft client. It gathers available activities, estimates travel and activity time, ranks a useful route, and presents navigation stops. It does not run as a Node service, a Python simulation or a standalone website. The game client owns event delivery, map and quest APIs, frames, timers and the writing of SavedVariables to disk. That runtime boundary explains most installation and troubleshooting decisions.

## This repository and the installed add-on

COchs-Personal/RouteSweet stores its installable source at the repository root. Install that one selected source tree as an add-on folder named RouteSweet. A second repository with a similar name is not a second component to start; it is another source revision for the same add-on identity. Installing competing copies can make you test the wrong code or overwrite saved settings. Record the exact repository, commit and game-client installation used for a test.

The inspected manifest declares Interface 120001 and a version label v0.0.3, while the bootstrap's `RS.VERSION` is 1.0.0. These are source declarations, not a fresh claim of compatibility with today's client patch. A future release should reconcile version metadata and verify the installed game API. The README's early roadmap is also behind parts of the current implementation: profiles, settings UI, leveling activity support and personal timing exist in source even though some old descriptions still list related features as future work.

## The useful mental model

An activity is something the player may choose to do: a world quest, weekly task, event, dungeon or supported leveling objective. It has an ID, map coordinates, type, estimated duration, rewards, priority and possibly a quest ID or expiry. The scanner turns game API responses and expansion data into these normalized records. Normalized means different inputs are translated into the same shape before routing.

The router chooses an ordering, not a guarantee of mathematical perfection. Its nearest-neighbor pass chooses a cheap next stop; a 2-opt pass reverses segments when doing so improves the cost. Scoring and zone preferences bias that cost toward useful stops. Portal batching and navigation annotations then adapt the result to the game's geography. The displayed time is an estimate built from travel plus activity duration, and personal measurements can replace category defaults over time.

## Definitions for a self-taught maintainer

A table is Lua's general-purpose collection and record type. A namespace such as `RS.Scanner` groups functions under the shared add-on object. A colon call such as `RS.Scanner:GetActiveActivities()` passes that object as `self`. A callback is a function the game calls later after an event or timer. A debounce cancels a pending timer and schedules a later one, so a burst of quest changes does not trigger repeated full scans immediately.

A cost matrix stores the estimated cost from every activity to every other activity. A directed cost can differ in opposite directions because portals, hearths and cooldowns are not symmetric. A heuristic is a practical approximation used when a globally optimal solution would be expensive or unnecessary. A SavedVariable is a Lua global the client persists through the add-on manifest; it is not a database server or a file the add-on writes through ordinary operating-system file access.

## What a route does and does not prove

A row appearing in the route proves that the scanner produced a candidate under current settings and that the router included it. It does not prove the objective is available to every character, that an estimated rotation is correct, that a reward is unlocked or that arriving completes the activity. Game APIs can be delayed, unavailable or restricted, and static IDs can become stale after patches. Manual marking exists for activities whose completion cannot be inferred reliably.

Treat the source-defined travel model, quest IDs and event schedules as implementation assumptions that need client evidence. This handbook explains how to inspect and repair those assumptions without inventing authoritative current game facts. Native NixOS game-client and add-on behavior require their own real qualification; reading platform-neutral Lua does not establish that the surrounding game launcher and graphics environment work.
