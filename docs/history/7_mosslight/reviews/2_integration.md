# Review 2: integration

## Target

Exact staged implementation against base 9649814, full binary patch SHA256 d2f6d3119a1ed57b66b4e08b27020223bbd38220c4be07f097557314ce68720c, retained under ignored output/mosslight/evidence/review-2.patch in the primary checkout. Focused changes from round 1 cover foundation ownership, keeping Dig details open, and world-space render caches. Later camera-compensation and tool-switch repairs are excluded from this round and reviewed separately.

## Reviewers and coverage

Codex CLI 0.163.0, gpt-6-astra at xhigh, read-only sandbox. It read the four changed source/test files and relevant surrounding code, verified the indexed patch before and after review, and cited unchanged scripts/build.mjs:10. That citation was checked; no failed sandbox command markers were found. The unavailable Claude lane remains an abstention.

## Reports

### Codex Astra

**Verdict: one remaining P2 defect in F7.** The full staged binary patch matched the supplied SHA256 before and after review.

- **P2 — Dig can still change rows during a horizontal drag.** [main.gd:464](C:/Users/38909/Documents/github/platformer/.worktrees/mosslight/mosslight/scripts/main.gd:464) preserves Info visibility, but feedback and inspection still have variable heights. At 320×640, accepting a dig replaces wrapped feedback with the short confirmation and adds inspection text. Their minimum heights at lines 283–291 do not reserve fixed space; [Godot’s wrapped labels resize with content](https://docs.godotengine.org/en/stable/classes/class_label.html#class-label-property-autowrap-mode). This changes the world height while `_dig_drag` remains active. Because [world_view.gd:174](C:/Users/38909/Documents/github/platformer/.worktrees/mosslight/mosslight/scripts/world_view.gd:174) maps input using the current height, a horizontal drag near a row boundary can queue the adjacent row. Reserve stable label heights during dragging and cover long/short feedback transitions with near-boundary input tests. This is a source-derived finding; displacement was not measured.

F6’s guards and fixtures cover all seven non-ladder types, ordering, stale execution/completion, and refunds. No additional concrete F6/F8 defect found after tracing cache lifetime, transforms, composition, invalidation, input routing, and restart.

Runtime acceptance remains open: no application, browser, or test launches; reported check counts, FPS, pixels, and native/Web behavior were not independently verified. No edits or earlier review reports read.

Unchanged-file check: [scripts/build.mjs:10](C:/Users/38909/Documents/github/platformer/.worktrees/mosslight/scripts/build.mjs:10) remains unchanged against `9649814` and checks Emberwake’s entry files.
## Findings and disposition

| ID | Finding | Disposition and reason | Repair or follow-up |
|---|---|---|---|
| F6 | Queued blueprint foundation race | Resolved; all seven non-ladder kinds and both completion orders covered | 277 simulation checks pass; focused gate 77 red before and zero after |
| F7 | Wrapped compact text still changes tile targeting | Accepted; independent runtime reproduced 7–10px residual viewport changes | Preserve world-to-screen mapping with camera compensation; next review covers this repair |
| F8 | Repeated detailed draw submission gives 2–4 frames/s | Resolved in measured normal, moving and wide views | Two world-space caches retain max-zoom detail; measured 52.5, 56.4 and 57.5 frames/s on verified RTX4090 hardware; actual screenshot inspected |

## Verification

Combined Godot import, 277 simulation checks and web export passed. The cached renderer retained the illustrated terrain, foliage, props, glows, layer order and clean alpha in full-resolution inspection. Normal and wide fixed views and actual camera movement passed the hardware performance gate. The first partial Dig repair targeted all three center cells correctly, but failed the stricter viewport test; it was not accepted as complete. The revised full route remains in progress, and final exports/CI are pending.

## Round outcome

Foundation and renderer repairs accepted within their measured bounds. F7 remained open on this exact target and required the next camera-compensation review.
