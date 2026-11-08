# Review 0: implementation

## Target

Base commit 9649814, exact staged patch SHA256 7360a75371bbd9771447dbb7dcdff98bba1e8aaf3b04c980177f70c5f4a9b6dd. The recoverable patch is intentionally retained under ignored output/mosslight/evidence/review-0.patch in the primary checkout. The reviewer detected concurrent unstaged presentation repairs and explicitly excluded them, reading the Git index. Report line references identify the staged revision, not later repairs.

## Reviewers and coverage

Independent Codex CLI 0.163.0, gpt-6-astra at xhigh, in a read-only sandbox. Serial review of simulation, presentation, tests, exports and workflow. The CLI read unchanged scripts/build.mjs:15 and its content was checked against the source. No failed sandbox command markers were found. Claude CLI 2.1.308 with the required pin could not authenticate because its OAuth access token had expired; that lane abstained before review. No private authentication or session data is retained here.

## Reports

### Codex Astra
Found **four actionable defects** in the staged patch. SHA256 matches `7360A75371BBD9771447DBB7DCDFF98BBA1E8AAF3B04C980177F70C5F4A9B6DD`; HEAD matches base `9649814`. References below use **staged line numbers** and exclude concurrent unstaged edits.

These are source-verified findings; the reproduction sequences were not executed in Godot.

1. **P1 — Keyboard focus consumes the vertical tile-cursor controls.** [main.gd:491](C:/Users/38909/Documents/github/platformer/.worktrees/mosslight/mosslight/scripts/main.gd:491)
   Start, select a tool with a digit, then press Up or Down. The world has keyboard focus, but cursor movement runs in `_unhandled_key_input`. Godot first moves focus to controls above/below the world and consumes the event, so these presses never move the cursor; Enter then activates the focused button. This blocks general construction by keyboard. Handle world cursor keys before focus navigation while preserving normal button navigation. Confirmed against [Godot’s input dispatch](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/scene/main/viewport.cpp).

2. **P2 — Previously queued digging can permanently disable a completed building.** [simulation.gd:442](C:/Users/38909/Documents/github/platformer/.worktrees/mosslight/mosslight/scripts/simulation.gd:442)
   From a fresh colony, queue a lamp at `(19,17)`, advance five seconds, then queue digging at `(19,18)`. The dig passes foundation protection because the lamp is still under construction. The lamp finishes first, but excavation completion never rechecks protection and removes its floor. The building becomes permanently inactive. Applied to the beacon, this prevents winning: another beacon is rejected, and neither floor restoration nor building removal exists. Revalidate foundation protection when excavation completes.

3. **P2 — Keyboard navigation can discard the outcome screen and its only restart action.** [main.gd:528](C:/Users/38909/Documents/github/platformer/.worktrees/mosslight/mosslight/scripts/main.gd:528), [main.gd:611](C:/Users/38909/Documents/github/platformer/.worktrees/mosslight/mosslight/scripts/main.gd:611)
   At an outcome screen, Tab through to the underlying `?` button, activate it, then close Help. The overlay blocks mouse input but leaves underlying controls in the keyboard focus chain. Help replaces the outcome, and closing it exposes the terminal colony without a restart button. `_last_status` already records the terminal status, so the outcome never reappears. Constrain modal focus and preserve the terminal screen when closing Help. The focus escape follows [Godot’s focus traversal](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/scene/gui/control.cpp).

4. **P2 — Opening Help during dragging leaves excavation latched on.** [world_view.gd:69](C:/Users/38909/Documents/github/platformer/.worktrees/mosslight/mosslight/scripts/world_view.gd:69), [main.gd:532](C:/Users/38909/Documents/github/platformer/.worktrees/mosslight/mosslight/scripts/main.gd:532)
   Hold left mouse with Dig selected, press H, release the mouse, close Help with Escape, then move across rock. Opening the overlay disables world input without clearing `_dig_drag`; the release is ignored by the early return. Subsequent mouse movement queues excavation without a held button. Clear drag state when suspending world interaction.

Reviewed simulation, UI, renderer, tests, export helper/presets and CI serially. Relevant unchanged source inspected: [scripts/build.mjs:15](C:/Users/38909/Documents/github/platformer/.worktrees/mosslight/scripts/build.mjs:15), which preserves the separate Emberwake build.

Both helper syntax checks and staged whitespace checks passed. Godot tests, exports, CI and rendered responsive checks were **not run**; there is no visual acceptance claim. `docs/learning/lessons.md` was absent. No files were changed or GUI/browser/server processes launched.


### Coordinator visual inspection

Full-resolution browser renders showed an initial camera fitted before container layout, making desktop settlers too small and leaving a large blank margin. The title's focused start button also had low contrast and an unsupported arrow glyph. Later screenshots confirmed corrected camera framing, legible settlers and distinct buildings. Real keyboard testing independently reproduced the focus-navigation defect.

## Findings and disposition

| ID | Finding | Disposition and reason | Repair or follow-up |
|---|---|---|---|
| F0 | Keyboard cursor events consumed by UI focus | Accepted; reproduced with real browser keys | Explicit world-focused input routing; final control retest required |
| F1 | Excavation/construction foundation race | Accepted; can permanently disable a unique beacon | Simulation worker repairing execution validation and reverse queue ordering with a class-wide test |
| F2 | Outcome modal loses its restart action through background Help | Accepted | Trap modal focus and preserve terminal outcome on Help close; final real terminal check required |
| F3 | Help during dragging leaves digging latched | Accepted | Clear drag state at suspension and retest held-mouse sequence |
| F4 | Initial desktop camera framing makes settlers tiny | Accepted from rendered evidence | Wait for settled layout and frame inhabited colony; corrected render inspected |
| F5 | Focused start button contrast and unsupported glyph | Accepted from rendered evidence | Dark focus/hover text and plain title action; compact rerender required |

## Verification

At this review, 90 simulation checks and clean Godot import/web export passed. Earlier real browser screenshots covered 1280x800, 720x560, 320x640 and compact boundaries; those established defects and did not accept the final repair. The corrected input build passed real keyboard construction, duplicate rejection and exact cancellation refunds. A full 3x survival run was in progress. No native macOS execution was available.

## Round outcome

Four independent material findings accepted, plus two coordinator visual findings. The reviewed implementation is not accepted for delivery. Repairs and exact-revision follow-up review are required; later results belong to the next round.
