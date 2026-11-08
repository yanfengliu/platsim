# Review 1: integration

## Target

Base commit 9649814, exact staged patch SHA256 5c44eb6fd3db1ffdb97c2c2bdd8fedc646f13f742361addf9f7ce16cb80df2e1, retained under ignored output/mosslight/evidence/review-1.patch in the primary checkout. The index is frozen while the code review runs. This revision includes the multilevel terrain, illustrated assets, modal/input repairs, paused animation and landmark-based help.

## Reviewers and coverage

Codex CLI gpt-6-astra at xhigh reviews the staged source in a read-only sandbox. An independent Astra visual reviewer inspected full-resolution exported screenshots at 1280x800, 720x560 and 320x640 plus zoomed prop art and title screens. The Claude lane could not authenticate in round 0 and remains unavailable; no Claude approval is claimed.

## Reports

### Codex Astra code review

**Verdict: request changes — two P2 gameplay/input bugs remain.** The frozen index matches the supplied SHA256 against `9649814`; later unstaged changes were excluded.

1. **P2 — Queued construction still loses its foundation when digging finishes first.** [simulation.gd:250](C:/Users/38909/Documents/github/platformer/.worktrees/mosslight/mosslight/scripts/simulation.gd:250) protects completed buildings only. On a fresh paused colony, queue a farm at `(19,16)`, then dig `(19,17)`, and resume. Mara reaches and excavates the foundation before Pip can finish construction. The farm then has no valid work goals, permanently reserving materials until manually canceled; ladders cannot restore its required solid floor. Protect queued construction too, or cancel/refund the invalidated build. The [regression test:159](C:/Users/38909/Documents/github/platformer/.worktrees/mosslight/mosslight/tests/simulation_test.gd:159) waits for 80% construction progress, covering only the opposite completion order.

2. **P2 — Compact layout changes tile targeting during a dig drag.** [main.gd:462](C:/Users/38909/Documents/github/platformer/.worktrees/mosslight/mosslight/scripts/main.gd:462) hides Info immediately after the first accepted dig. At `720×560`, select Dig and drag horizontally across adjacent rock cells: hiding the description/inspection enlarges the world viewport while the pointer remains held. [world_view.gd:52](C:/Users/38909/Documents/github/platformer/.worktrees/mosslight/mosslight/scripts/world_view.gd:52) calculates targeting from the viewport’s changing center, so subsequent motion targets another row. Keep the layout stable during dragging or compensate the camera.

**Coverage:** Reviewed indexed simulation, tests, UI/input, rendering, imports, atlas metadata, export presets, tooling, and CI. Resource references and atlas bounds pass static checks; the largest image is 513,302 bytes, below 512 KiB. The prior arrow-routing, terminal-modal, and Help drag-clear repairs appear sound by inspection; focus semantics were cross-checked against [Godot’s source](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/scene/gui/control.cpp).

**Limitations:** Findings are source-derived, without engine/browser reproduction. No tests, exports, or applications were launched. The revised actual-control win and art acceptance remain unverified here. The official download checksum could not be retrieved.

**Unchanged-file check:** Read [scripts/build.mjs:10](C:/Users/38909/Documents/github/platformer/.worktrees/mosslight/scripts/build.mjs:10); it still validates and copies Emberwake’s original entry point and source. Existing Emberwake source, tests, commands, and CI are unchanged.

### Independent Astra visual review

No material visual blockers in the supplied full-resolution renders.

- **Illustration and terrain:** Lush cavern lighting, hanging roots, foliage, and detailed buildings establish the requested illustrated look. Distinct terraces and ladders clearly communicate height in all three `illustration-colony-*` captures.
- **UI:** Resource values, primary controls, and settler names remain legible at 1280×800, 720×560, and 320×640. Both title actions fit fully inside each `illustration-title-*` modal. Compact toolbars visibly scroll; screenshots alone do not establish interaction behavior.
- **Transparency:** `illustration-prop-alpha-closeup.png` shows clean building silhouettes without visible atlas rectangles, checkerboards, or stray neighboring sprites.

Optional polish: settlers are noticeably simpler and flatter than the richly shaded props and cavern, especially in the close-up. This is a stylistic consistency issue, not an acceptance blocker.

## Findings and disposition

| ID | Finding | Disposition and reason | Repair or follow-up |
|---|---|---|---|
| F6 | A queued blueprint can lose its foundation before building begins | Accepted and reproduced in Godot | Shared planned/completed foundation ownership; focused 168 checks fail 77 before and zero after; complete suite passes 277 |
| F7 | Compact Dig hides details and shifts tile targeting during a held drag | Accepted | Keep details open during Dig; actual-control red/green retest and follow-up review required |
| F8 | Detailed terrain is resubmitted every frame and renders at 2–4 frames/s | Accepted from actual hardware-GPU measurements | Cache unchanged terrain; normal and wide GPU performance, visual invalidation and full route must pass before delivery |

The optional settler shading refinement is recorded without expanding this prototype's acceptance scope. Earlier F0–F3 repairs appeared sound to the source reviewer; F6 extends F1 to the opposite completion order. F4/F5 visual repairs passed the independent render inspection.

## Verification

The reviewed simulation passed 214 checks. A focused terrain gate fails seven of thirteen checks against the original flat map and passes all thirteen against the new map. Real input checks passed title actions and clipping at all nine required sizes, Help scrolling, modal drag release, keyboard toolbar scrolling, and visible character-head/lamp-bulb inspection. The revised route physically reached the quarry, collected ore/fuel and built the beacon with all four settlers at full health, but was stopped after the hardware-GPU performance defect was confirmed. A second sample measured five animation callbacks in 2395 ms (2.09 frames/s) while the browser was visible and focused; simulation advanced only 1.6 seconds at 3x. That is failed acceptance, not a complete-route pass. No task browser processes remained after cleanup. Logs, screenshots and read-only state are retained as counterevidence.

The code lane's unchanged scripts/build.mjs:10 citation was checked against the source. No failed sandbox command markers were found; Git warnings about inaccessible global configuration did not prevent source reads. Its final indexed patch digest still matched the target.

## Round outcome

Visual acceptance passed, but code and performance changes were required. F6–F8 repairs need the next exact-source review and affected runtime checks before complete gameplay acceptance.
