# Review 3: integration

## Target

Final camera-compensation and tool-switch changes on top of review 2. Exact source snapshots are retained under ignored output/mosslight/evidence/review-3-world_view.gd (SHA256 e632d4ac6c0ba4a5936f7ee6f1952479ac759794801ea07bf1d590b8f7d250e9) and review-3-main.gd (SHA256 8077b0f8f4c951bbe845d4aca6cc937545908d27c0a3a6f2b4a71cdbfa70c5a5) in the primary checkout. All other implementation source is unchanged from review 2.

## Reviewers and coverage

A fresh independent gpt-6-astra reviewer at xhigh inspected the actual working source and relevant input paths, verified both hashes, and made no edits or runtime launches. This focused subagent review supplements the two comprehensive/focused Codex CLI rounds; it is not represented as a second CLI lane.

## Reports

### Independent Astra: camera compensation

Verdict: the new compensation is correct; one existing input interaction remains outside the unstaged delta.

- **[P2] Changing tools during held Dig retains the drag latch.** `main.gd:411` changes `selected_tool` without clearing pointer state. Hold Dig, press `3` or `X`, then move: `world_view.gd:266` continues emitting activations, now repeatedly building or cancelling jobs. Clear the Dig latch when changing tools.

The added algebra preserves `global_center − camera × tile_unit`. Stabilization precedes hit testing and cache refresh; release, pause, focus loss, and overlay paths disable further compensation. Each new stroke captures fresh bounds.

Read the actual source, adjacent input handlers, and regression scripts. Working source and retained snapshot both match SHA256 `e632d4ac6c0ba4a5936f7ee6f1952479ac759794801ea07bf1d590b8f7d250e9`. No files changed or tests/GUI launched.

### Independent Astra: tool-switch repair follow-up

F9 is resolved by the inspected repair at `mosslight/scripts/main.gd:412`. Clearing pointer state before changing tools prevents held Dig motion from activating Build or Cancel, stops obsolete drag compensation, and leaves release handling and subsequent fresh clicks intact. No new input regression found by source inspection. Verified `main.gd` SHA256 `8077b0f8f4c951bbe845d4aca6cc937545908d27c0a3a6f2b4a71cdbfa70c5a5`; `world_view.gd` still matches the previously accepted hash. Read-only review; no runtime or GUI testing performed.

## Findings and disposition

| ID | Finding | Disposition and reason | Repair or follow-up |
|---|---|---|---|
| F7 | Compact wrapping shifts targets during a held drag | Resolved by camera compensation; label content can resize without moving world points on screen | Real 720x560 and 320x640 strokes preserve mapping within 0.00002px and queue all three intended cells with no extra row |
| F9 | Changing tools while holding Dig applies the new tool repeatedly | Resolved; source repair independently verified and actual-control red/green passed | Four pre-repair cases accidentally built three beds or canceled two blueprints; final source clears the latch, changes no jobs on motion, and accepts a fresh click |

## Verification

Godot import, 277 simulation checks and web export passed. The ordinary quarry-to-victory run reached 1200 simulation seconds with all four settlers at health 100, 34 food, 114.94 water, 18 biomass and 199.76 power. Actual victory/retry and modal focus passed all three primary viewports. Its source snapshots and exported PCK hash are retained in natural-route-source evidence; the only later source delta is the one-line tool-selection latch clear, which does not affect this route's released-button tool changes. That delta passed its own four actual-control red/green cases on the final export. At 720x560 and 320x640, held Dig paths at the upper 6% and lower 94% of cells preserve screen mapping and queue exactly the intended three cells despite wrapping height changes. Final Windows and universal Mac exports were built from the same source; Windows launched headlessly with exit 0 and no engine errors. Mac native execution remains untested. Final keyboard polling and cleanup are still being checked.

## Round outcome

No remaining material source findings. F7 and F9 pass their actual-control checks. Final keyboard toolbar focus, scrolling and Enter activation pass at all three viewports after correcting the harness to wait for the read-only snapshot's 250ms cadence; its earlier faster polling could skip intermediate focus and failed without demonstrating a source defect. The same action and visibility assertions were preserved. All nine title breakpoints, Help/drag release, sprite inspection, paused-pixel equality and an arbitrary pan/zoom view pass on the final export. Both final browser sessions report zero remaining owned processes. Final repository delivery remains pending.
