# Mosslight Godot survival prototype

Status: active
Owner: Codex
Created: 2026-11-07
Updated: 2026-11-07

## Problem and outcome

Build the owner's approved Mosslight concept as a playable Godot prototype: four colonists dig and build a living cave habitat while balancing food, air and power. Keep the existing Emberwake game available. The owner rejected the flat blockout and requested good graphics, then selected detailed stylized illustration; delivery now requires a visually rich multilevel living grotto.

## Scope

One side-view cave map with an upper sleeping roost, stepped inhabited terraces and a lower resource chamber; autonomous workers, eight buildings, room air mixing, simple resources, pause/speed, keyboard and mouse controls, win/loss and retry. Detailed original illustrated scenery, organic terrain surfaces, vegetation and expressive settlers. Native Godot source plus web export for actual-control verification. No persistence, multiplayer, copied commercial assets or external runtime services. macOS compatibility is configured but cannot be run natively on this Windows host.

## Approach

GDScript with Godot Compatibility rendering. The Node-free simulation owns colony state; presentation consumes it and submits commands. Room-level air and short production chains keep consequences readable. The agreed contract and file ownership are in [design.md](design.md). Three delegated lanes implement simulation, presentation and tooling in one isolated worktree with disjoint file ownership. An independent exact-revision review follows integration.

## Acceptance criteria

- [x] Godot imports cleanly and simulation tests cover navigation, digging, resource accounting, room mixing, production and terminal states.
- [x] Starter infrastructure spans at least three elevations; an ordinary playable expedition traverses the lower shaft using built ladders. The flat-map regression fails the old terrain. Visually inspect detailed illustrated artwork, organic connected terrain, depth, foliage, characters and buildings at default and moved/zoomed cameras.
- [x] Real keyboard/mouse controls work in an exported headless browser; inspected full-resolution renders fit 1280x800, 720x560, 320x640 and compact breakpoint widths.
- [x] Illustrated rendering sustains at least 30 frames/s on the verified hardware GPU at normal and wide cave views; cached scenery updates after excavation, construction, camera movement and resize.
- [x] Existing npm syntax, simulation and build gates pass; work records and staged artifact/secret/size checks pass.
- [ ] Independent review findings are resolved or explicitly recorded, code is merged and pushed, CI is followed, and task-owned processes and disposable outputs are cleaned.

## Implementation steps

- [x] Record approved design, allocate work unit 7 and create codex/mosslight isolated worktree from 9649814.
- [x] Simulation worker: authoritative grid, workers, jobs, both foundation-race orderings and multilevel terrain; 277 checks pass, including the full command-only twenty-minute route. Focused terrain and foundation gates are red on the original defects and green on the repairs.
- [x] Presentation worker: original illustrated cave, responsive controls, cached rendering and playable Godot scene.
- [x] Tooling worker: portable engine, export presets, verification commands, native packages and run instructions.
- [ ] Coordinator: integrate, inspect real play, run gates, obtain independent review and land verified result.

## Outcome

Mosslight is implemented with detailed original illustration and four inhabited elevations linked to a lower quarry. The complete simulation passes 277 checks; the old flat map fails seven of thirteen terrain checks, and the queued-foundation defect fails 77 of 168 focused checks before repair. A full ordinary keyboard/mouse expedition physically descended the shaft, mined ore and roots, built the beacon and won after 1200 simulation seconds with all four settlers at full health; actual victory/retry and modal focus passed all three primary viewports. The source-bound run excludes only a subsequent one-line tool-switch latch clear, independently reviewed and verified with four actual-control red/green cases on the final export. Compact center and near-boundary Dig strokes preserve exact target mapping after text wraps.

Full-resolution fixed, zoomed, moved and arbitrary camera views accept the illustrated cave, props, vegetation, settlers and clean alpha. World-space caches corrected a measured 2–4 frames/s failure to 52.5/56.4/57.5 frames/s in normal/moving/wide RTX4090 samples; a warmed 3x run advanced three simulation seconds per second. Final actual controls pass all nine title breakpoints, three primary viewports, keyboard construction/tool scrolling, tall-sprite inspection, modal drag clearing and pause pixel stability. A keyboard harness initially polled faster than the read-only snapshot cadence; the same visibility/action assertions pass when each Tab waits for fresh state, with no source change. Windows and universal Intel/Apple Silicon Mac packages are built from the final source, and Windows passes a hidden headless launch. Native Mac execution and notarization are not claimed. All 108 existing Emberwake tests, syntax/build and work-record checks pass. Review reports and failed counterevidence are retained; the Claude lane was unavailable through expired authentication. Merge/push, CI and final cleanup remain pending.
