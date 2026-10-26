# RouteSweet Operations Guide

RouteSweet is this repository's Lua add-on source. It runs inside World of Warcraft, rather than as a Node or Python server. Keep this revision separate from the other RouteSweet repository and any unmerged development profile; install one selected version at a time.

**Operating status.** Source-defined in-game workflow with NixOS host and current patch unverified.

## Start the application

Choose the intended source revision and place its RouteSweet add-on folder in the selected retail game instance under `Interface/AddOns`. Check that the add-on manifest and files are directly in that folder, not inside an extra nested download folder. Enable it in the game AddOns menu. TomTom is optional. Open the route window with `/rs`; `/rs scan` refreshes route data.

## Check that it works

Out of combat, open the route window, scan, and select a stop to set its waypoint. Right-click marking can handle activities without automatic completion detection. The inspected README describes `/rs skyriding` for travel mode and `/rs help` for command help. Check the exact installed version before following a newer development command.

## If something goes wrong

If the add-on does not appear, inspect its folder nesting and manifest/game compatibility. If scanning produces incomplete rewards during combat, try again out of combat. Estimated cave rotations and event availability are documented limitations, not a service-health failure. Do not use `/rs reset` to troubleshoot a window problem; it clears manual completion data.

## Close the session

Hide the window with `/rs` when done. For a full session end, log out or quit the game normally so SavedVariables are written. Back them up with the game closed before replacing versions. Do not run both repository copies under competing add-on folder names.

## Known limitation and next repair

The source describes a particular game patch and platform-neutral Lua. Current game compatibility and the NixOS game-launcher environment remain separate qualification work. A reference to supported APIs in the README is a source claim, not a fresh game-client test.

## Before you begin

Choose the exact application or game instance, source version, and working copy. Development and installed releases can use different save locations. Preserve original documents, media, and game saves before an update. Stop through the normal save and quit controls; interrupt only a remaining foreground process you personally started.

## Keep troubleshooting scoped

Record the first error, source revision, working directory, and selected instance. Check the stated prerequisites before changing anything. Preserve useful work before resets. Stop only the process or dedicated dependency you own; do not kill by a guessed port or broad name. Keep credentials and private records out of reports. Migrations, seeds, volume deletion, deployment, and new model downloads are separate operations, not generic restart fixes.

## Normal operating sequence

![Normal operating sequence](operating-flow.svg)

## Maintaining this guide

Keep this Markdown, the editable Word edition, PDF, and operating-flow.svg together here. Update them when merged commands, storage, dependencies, or limits change. Edit Word and export PDF independently when convenient, then inspect the affected pages. No running AIOS service is needed to read or maintain these documents.

Source-defined instructions and known gaps are distinguished above. This documentation task did not launch the application or prove a new production workflow. Verify changes locally on NixOS; use a topic PR and human merge for owned source. Deployment is separate, and routine hosted CI remains disabled.

## Source and edition

Edition 26 October 2026. Repository COchs-Personal/RouteSweet. Inspected source revision `468d396d6f8c069741eaccb5c443ea75df086603`.

Source files: [README.md](https://github.com/COchs-Personal/RouteSweet/blob/468d396d6f8c069741eaccb5c443ea75df086603/README.md).

[Editable Word edition](Operations_Guide.docx) | [PDF edition](Operations_Guide.pdf)

For architecture, code-level explanations, worked change recipes, and detailed recovery, use the [development handbook](../development-handbook/README.md).
