# Review 3: implementation

## Target

Repository: platformer. On 2026-11-07, reviewed retained terrain draw lists, their reset invalidation repair, the frozen terrain regression suite, and the fourth-suite runner/documentation changes in `C:/Users/38909/Documents/github/platformer/.worktrees/mosslight-motion`, based on `e97177b80dd7f5c0a3d727e692c0fcd988187e4a`. The world-view diff was compared with the exact source retained for round 1; the prior main-label repair from round 2 remains unchanged.

The integration owner retained the exact four reviewed files under the primary checkout's ignored `output/mosslight-motion/evidence/review-3/`, using their basenames. The reviewer verified that each retained copy matches the working file. All four raw SHA256 digests remained stable during the final frozen-source recheck.

| Reviewed path | SHA256 |
|---|---|
| `mosslight/scripts/world_view.gd` | `4A25DDB7AB1372714065DA0F94DD01B7CBE92668ADF83F38263EBCD573368D99` |
| `mosslight/tests/terrain_cache_test.gd` | `12E5C59DD5BDFD9F63150C3A3F7EB049A1CC1AB64988F5E67FEB2A8791A96626` |
| `mosslight/tools/godot.mjs` | `C33116931953665B03C8F9A1C64E1D9F3FA8735732E4C82EECD5C46F2DE86D96` |
| `mosslight/README.md` | `B7C063773A0CD654E399EC4C016FF1362EC480A62D69CFD73B53DA865E660E88` |

## Reviewers and coverage

Independent reviewer: `/root/motion_review`. Assigned lens: terrain invalidation completeness, compositing order, reset behavior, retained node identities, cleanup and memory lifetime, regression coverage, and risks compared with the previous whole-cache redraw. An initial source pass covered the retained-cell implementation before the test froze; the final recheck read the entire frozen test and reset invalidation delta and bound the combined assessment to the exact hashes above.

The reviewer read the actual world-view diff and relevant current source, unchanged `CaveArt` terrain functions, simulation terrain/building mutation paths, the runner and README changes, and the frozen test. Hash checks also confirmed that the six other previously reviewed core/test files retain their latest accepted bytes. `simulation.gd` and `project.godot` remain unchanged from the base. Generated asset metadata, capture fallback instrumentation and other acceptance harnesses are outside this source target.

No game, browser or GUI was launched, and no runtime tests, export jobs, heavy gates or performance measurements were run by this reviewer. Only this review record was written.

## Reports

### /root/motion_review

**No actionable invalidation or layering defect found.** Each solid-cell signature covers its material, all four adjacent open/closed states, and occupancy immediately above. These are the varying inputs used by `CaveArt.rock`, `ground_growth` and `ceiling_growth`; their other choices depend only on fixed cell coordinates, constants and the unchanged art resource. Excavating a cell invalidates its old commands and the exposed sides of its four neighbors. A building changes the occupancy input for its supporting floor. Material changes do not unnecessarily invalidate neighboring exposure. Empty cells retain a `[0]` signature and issue no terrain commands.

The rock and growth painters sit under separate ordered parent groups. Each group receives cells in the same row-major order as the old loops, preserving all-rocks-before-all-growth compositing and the ordering of growth that extends across cell boundaries. Each callback binds the existing art helper to its own `CanvasItem` and supplies the same world-space cell position and `CACHE_TILE` scale as before. The full-resolution viewport, display transform and art routines are unchanged; this patch retains drawing commands rather than reducing geometry or texture quality.

**No actionable reset, ownership or accumulation defect found.** Same-size changes preserve painter identities and queue redraw only for changed signatures. A dimension change detaches and queues deletion of every old painter, clears the old coordinate/signature domain, and creates the new domain under the same two groups. Normal world destruction owns those groups and their descendants. The number of painters stays bounded at two per world cell; repeated excavation does not append replacement nodes. The shared art helper's canvas reference is reassigned before every nonempty cell callback uses it.

The final `reset_motion()` change at `mosslight/scripts/world_view.gd:113-114` sets `_observed_time` to `-1.0`. The simulation clock is nonnegative, so the next `_refresh_caches()` recomputes terrain and infrastructure hashes even when a reset reuses the previous clock value. This fixes the same-clock stale-hash case without throwing away unchanged cell commands. Existing main reset routing calls `reset_motion()` immediately after resetting simulation authority.

**The frozen terrain test meaningfully exercises the changed behavior.** `mosslight/tests/terrain_cache_test.gd` uses the real world-view class and production refresh and paint callbacks. It checks the five-cell excavation footprint, all four exposure directions, diagonal stability, both air-cell paint passes, material changes, occupancy addition/removal, infrastructure-only activity changes, retained node identities, unchanged and camera-only frames, viewport dimensions, retired-node deletion, and same-clock invalidation. The test also connects actual `CanvasItem.draw` signals and checks the observed redraw footprint when those signals are available. Its trace art intentionally avoids expensive geometry; therefore these checks do not establish final pixels or GPU frame time. The optional legacy comparison loads the retained production world-view method rather than replacing it with a copied full-map algorithm.

The fourth-suite addition in `mosslight/tools/godot.mjs` is sequential and awaited, preserving existing failure propagation for both `test` and `verify`. The README consistently describes all four suites, and the previously reviewed CI workflow still calls this test entry point. No actionable runner or documentation mismatch was found.

**Performance acceptance remains separate.** Retaining per-cell commands removes whole-cave GDScript geometry reconstruction on excavation, but a dirty terrain viewport still rerasterizes the full texture. Source inspection cannot establish that the previously observed 65-68 ms excavation frames are gone. The native GPU measurement and rendered comparisons must judge the repaired build; the earlier average frame rate does not accept those frame spikes.

## Findings and disposition

| ID | Finding | Disposition and reason | Repair or follow-up |
|---|---|---|---|
| F0 | Resume recreates a full-tick movement jump | Remains closed. Main and presentation-helper hashes match the accepted prior repairs. | Integration runtime verification remains separate. |
| F1 | Ground-resting settlers lose their resting pose | Remains closed. Presentation-helper and art hashes match the accepted prior repairs. | Integration rendered verification remains separate. |

No new actionable source finding is assigned in this round. The same-clock cache invalidation issue was found by the integration regression work and was already repaired in this frozen target; the reviewer checked that repair and its regression coverage.

## Verification

Read-only source inspection, diffs and raw hashes verified the final target, matching retained copies, unchanged related code, terrain-art input coverage, reset routing, ownership and suite wiring. The integration owner reports 33 passing terrain checks with actual draw signals, 678 total passing Godot checks and three successful exports. Those executions were not independently run or their logs audited by this reviewer, and they are not evidence here of GPU frame-pacing acceptance. The frozen reviewed files did not change during this recheck.

## Round outcome

Final source review accepts the retained terrain draw-list implementation, reset repair, terrain test and fourth-suite wiring at the exact hashes above, with no new actionable finding. F0 and F1 remain closed. This source acceptance is distinct from pending native excavation frame-time measurements, rendered-art checks, final repository gates and CI acceptance. Earlier authored rounds remain unchanged as historical reports.
