# Smooth Mosslight motion and scalable settings

Status: delivered
Owner: Codex
Created: 2026-11-07
Updated: 2026-11-07

## Problem and outcome

The owner reports choppy Windows animation and requires at least 60 frames/s as well as smooth motion, plus an Escape menu with Settings and a way to enlarge the UI. Character rendering currently samples authoritative positions directly from a 10Hz simulation, so a fast renderer still shows stepped travel.

## Scope

Interpolate rendering between unchanged simulation ticks, make walking/climbing/work poses continuous, measure Windows GPU frame pacing, and remove measured rendering bottlenecks without reducing illustration quality. Add a keyboard-accessible Escape pause menu and Settings with immediate UI scaling that remains usable across supported viewports. UI scale applies for the current session including colony retries; no save-game or persistent settings format is introduced. Preserve existing survival balance, art, input protections and Emberwake.

## Approach

Work in isolated codex/mosslight-motion from e97177b. Coordinator owns world_view.gd, cave_art.gd, integration and browser acceptance. The motion worker owns the presentation helper and class regression tests; the presentation worker owns main.gd and UI helpers. Tooling owns native verification, exports and run instructions. Simulation remains at 10Hz; main brackets each step with WorldView begin_simulation_step/end_simulation_step and passes accumulator alpha, render delta, speed and running state to present_frame. Fractional accumulator time survives pauses and menus, and resets with a new colony. Headless browser tests cover real controls; native GPU rendering must be measured on Windows because headless Godot uses a dummy renderer. Any necessary native window is announced, owned by PID and closed with its children.

## Acceptance criteria

- [x] Whole-class red/green coverage detects 10Hz stepping and verifies continuous walking/climbing at 1x and 3x, stable pause/resume/reset, and pose changes between simulation ticks.
- [x] Actual Windows GPU render frame pacing sustains the requested 60fps target in normal, wide, moving-worker and excavation contexts, with frame-time distributions recorded rather than only an average. Visually inspect real motion and original artwork. Measurement is engine-input replay on the matching native engine, not OS-input or compositor certification.
- [x] Escape opens the menu from world and focused controls; Settings changes UI size immediately, preserves world coordinates/zoom, and remains keyboard accessible at primary sizes and compact breakpoints, with reachable back/reset actions at large scales.
- [x] Godot import/tests/exports, existing npm gates, artifact limits, secret and record checks pass. Independent exact-source review findings are resolved and checked.
- [x] Merge and push to main, follow CI, retain updated playable builds/evidence, and close owned browser/native/server processes. Remove the isolated worktree and branch at closure.

## Implementation steps

- [x] Confirm the affected platform is the Windows build; inspect the 10Hz rendering path and create isolated worktree and work unit 8.
- [x] Implement motion and UI in disjoint lanes; prepare native/browser acceptance and repeatable failing-before checks.
- [x] Integrate, review, measure and inspect the result, then deliver updated builds and source.

## Outcome

All 707 Godot checks pass: 277 simulation, 291 motion, 77 UI and 62 terrain checks; npm check, all 108 Emberwake tests and build pass. Windows, web and universal Mac exports pass. Independent review closed resume, resting and fractional-zoom cache-seam findings. Full-resolution regional terrain caching removes the measured excavation stalls without reducing illustration detail: all measured active native gameplay frames stay below 16.7ms, with a 15.067ms maximum, 300–313fps section averages and no repeated moving positions. Real-input browser acceptance passes nine viewports, 150/200% scaling, world pointer mapping, keyboard scrolling and modal state restoration. The natural 1200-second expedition wins with all four settlers healthy; outcome menus and fresh-colony retry preserve UI scale. Native OS input automation and compositor timestamps remain unavailable, so the Windows result is explicitly instrumented native GPU evidence. Native Mac execution is untested; the browser's 53fps sample does not meet a browser 60fps claim. Code 8e6b2b46eda111a7f8542ea32841e6d4fa553927 is merged and pushed to main, both CI workflows pass, and updated playable builds plus evidence are retained in the primary checkout's output folders. Owned-process audits are clear; closure removes the isolated checkout and branch while retaining the app-managed checkout. See acceptance.md for exact hashes, CI links and limits.
