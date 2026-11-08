# Review 0: implementation

## Target

Repository: platformer. Reviewed the uncommitted first implementation for work 8 against base and HEAD `e97177b80dd7f5c0a3d727e692c0fcd988187e4a` in `C:/Users/38909/Documents/github/platformer/.worktrees/mosslight-motion` on 2026-11-07. Scope was the seven source and test files listed below, including the untracked helpers and tests. README and Godot tooling edits were outside this source review.

The integration owner retained the exact seven reviewed files under the primary checkout's ignored `output/mosslight-motion/evidence/review-0/`, using their basenames. Each raw SHA256 digest was identical at review start and end; no line-ending normalization was needed. These digests identify the reviewed first draft, not subsequent repairs.

| Reviewed path | SHA256 |
|---|---|
| `mosslight/scripts/cave_art.gd` | `E32D1D9DBB4D2C39CCF117A6E28F8A2158744ABA2E037267CE7B82D9E415D2ED` |
| `mosslight/scripts/main.gd` | `7160515F4A73027C5EFA7A06D7CDC6DA9CE5498DA207ECDFD285FF52C6EC1287` |
| `mosslight/scripts/world_view.gd` | `F230E833DE0E0D8D3D02E46E90EEDD9C3582EDB5D0F0A92DEAD22325A61B07F7` |
| `mosslight/scripts/presentation_motion.gd` | `422510486E948732892DA560879846DF80AC589150CC2D0F5CED65DFEFE0E234` |
| `mosslight/scripts/ui_settings.gd` | `558922EB0A0A020C6B2557A6D1CF6A156E138494CEC6376D2D7E52258176E573` |
| `mosslight/tests/presentation_motion_test.gd` | `901BE764CFB92940DE31F534CFE1FA744C7AC070D39E0CA0239886E21CED228A` |
| `mosslight/tests/ui_settings_test.gd` | `A15FAD7F71A3823E3EB6E9B0B1088CA2CB8C7919277E38B59EBC82B28A39C784` |

## Reviewers and coverage

Independent reviewer: `/root/motion_review`. Assigned lens: interpolation continuity with 10 Hz authority and 60/120 fps rendering at 1x/3x; pause, menu, resume and reset; actual work, rest, climbing and facing poses; native UI metrics, cached-world preservation during scale rebuilds, modal history and keyboard focus, survival controls, resize caps and world mapping.

The reviewer read actual diffs, full relevant current source, both new test files and unchanged simulation code. No prior reviews were read. This was a read-only source review: no code edits, game or browser launches, GUI interaction, runtime tests, or frame-rate measurements. The later authorized write of this report is the only review-authored repository edit. The repository's `docs/learning/lessons.md` was absent.

## Reports

### /root/motion_review

**F0 — [P2] Resume recreates a full-tick movement jump.** In the reviewed `mosslight/scripts/presentation_motion.gd:75-82`, the first resumed frame is preserved, but `begin_step()` at lines 42-50 then discards the rebased segment. At 3x and 60 fps, pause a walking settler at interpolation alpha 0: rendered position is `x`, authority is `x + 0.21`. Main clears its accumulator on pause/menu transitions. Resume produces alpha `0.5` and holds `x`; the following frame ticks and renders `x + 0.21`. That is a repeated frame followed by twice the normal `0.105`-tile movement, reintroducing a visible hitch when gameplay resumes. The existing pause test resumes at synthetic alpha 0 and misses the main-loop sequence. Preserve continuity through the next authoritative sample and cover pause/resume through the actual accumulator cadence at both render rates and simulation speeds.

**F1 — [P2] Ground-resting settlers lose their resting pose.** The reviewed `mosslight/scripts/cave_art.gd:162` now accepts only exact task `"Resting"` or the bed-reservation flag. Unchanged `mosslight/scripts/simulation.gd:603-605` sets `"Resting on the ground — needs a reachable bed"` without that flag. Such settlers remain upright while their presentation clock freezes, whereas the previous renderer recognized the ground-rest task. Recognize that actual task while retaining the arrival/gait guard, and cover the predicate consumed by the renderer.

Grounding beyond the patch: unchanged `mosslight/scripts/simulation.gd:485-499` advances movement with `2.1 * dt` and consumes path destinations, establishing the `0.21`-tile authoritative step used in F0. The reviewer also read the bed reservation and arrival paths at lines 466-482 and 587-602, and job execution at lines 607-625. No additional actionable source finding was identified in modal history, Escape dispatch from focused controls, UI scale rebuilds, or coordinate mapping. This absence of further source findings does not establish rendered-layout or performance acceptance.

## Findings and disposition

The following dispositions reflect the integration owner's repair assignment after receiving the authored report; they are not repair verification.

| ID | Finding | Disposition and reason | Repair or follow-up |
|---|---|---|---|
| F0 | Resume recreates a full-tick movement jump | Accepted; pending repair. The accumulator and resume-rebase sequence produces a repeated frame followed by an oversized movement. | Helper worker assigned an actual-main-accumulator test matrix and continuity repair. Independent recheck required after the repaired source freezes. |
| F1 | Ground-resting settlers lose their resting pose | Accepted; pending repair. The helper and renderer disagree about the actual ground-rest task. | Integration owner plans a shared presentation rest predicate consumed by the renderer. Independent recheck required after the repaired source freezes. |

## Verification

Read-only Git and file inspection verified the base revision, reviewed source, new tests, unchanged simulation paths, and identical start/end raw SHA256 hashes for all seven scoped files. No tests were run by this reviewer. Initial Windows frame-rate samples reported by the integration owner were not used as evidence of runtime acceptance; native observer, rendered-state, input and viewport checks were outside this review. The source remained stable throughout the review.

## Round outcome

The first implementation has two material findings, F0 and F1, pending repair and a subsequent independent review round. This round does not accept the final implementation, a sustained frame rate, smooth rendered motion, or viewport coverage. Preserve this report and its reviewed target as historical evidence when repairs change the source.
