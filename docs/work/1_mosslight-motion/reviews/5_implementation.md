# Review 5: implementation

## Target

Repository: platformer. Reviewed the digging-animation follow-up on branch `codex/mosslight-digging` in `C:/Users/38909/Documents/github/platformer/.worktrees/mosslight-digging`, based on `8f3655a1b78d28f2288edbcc1969c9fda5175f0f`, on 2026-11-07. The review covers the new digging rig, production artist, presentation lifecycle, job wiring, frozen initial digging test, fifth-suite runner and README. This is the first digging draft, before the F3 directional-approach repair.

The reviewer retained exact source copies under the primary checkout's ignored `output/mosslight-digging/evidence/review-5/`, using the basenames below. Source copies were retained before reporting F3; the test and runner were read after their worker confirmed the frozen hashes. The integration owner began the repair after retention was confirmed, so these hashes identify the reviewed original target rather than the subsequently changing worktree.

| Reviewed path | Raw SHA256 |
|---|---|
| `mosslight/scripts/digging_motion.gd` | `6FCFA442814D1EA83D7F89321BD0A2FE776B35C4A2F7EBE023A637BE368FB5D3` |
| `mosslight/scripts/digging_motion.gd.uid` | `71506406F7B75E7035ED4C98ACC35CC9980AF019714968C0D94244716C1FFC8F` |
| `mosslight/scripts/cave_art.gd` | `83546918DDD7F64D076F5B6CA99F6E5DBEA5F9102BD6BF32EE0A9AD27BB90B97` |
| `mosslight/scripts/presentation_motion.gd` | `E973272FA927526AD541B2A82C7198CADC582138D032AAD71C9B4BF67F9B36DC` |
| `mosslight/scripts/world_view.gd` | `2FE9228620692BE4C757DEB434D5170B6C7E205C847F13A0754BAB0788E9FBBF` |
| `mosslight/tests/digging_animation_test.gd` | `56DE643A79C9094A1254043B2B9783C226C41F1EC57750FBA3300F546FBE13CE` |
| `mosslight/tools/godot.mjs` | `A2FE2D68C0A6B8EFB197FA4E5457F236432B5097630D692F08F2EF6B02A0DF0B` |
| `mosslight/README.md` | `FB0228551CE46782A6EDD133CB561D90682CAF56C18CF426E4B7CEE3E9B34AAF` |

## Reviewers and coverage

Independent reviewer: `/root/motion_review`. Assigned lens: actual rock contact in all four directions, rigid tool and hand attachment, readable windup/strike/contact/recoil, continuous poses, pause/cancel/rest/death/reduced-motion behavior, simulation isolation and bounded presentation work.

The reviewer read the actual source diffs, complete new rig and frozen test, production artist and presentation call paths, and unchanged simulation job-goal and cancellation logic. No prior reviewer report was used to derive the finding. The reviewer also inspected two already-generated images at original resolution without launching a browser or game: the 720x540 `digging-contact-sheet.png` and 1280x800 `dig-normal.png`. They were copied into the same retained evidence directory. These are paused real-gameplay samples supplied by the integration owner, not a natural-cadence recording.

No game, GUI, browser, GPU job or runtime test was launched by this reviewer. The reviewer performed a small independent numerical calculation of the source rig formulas, wrote this record, and retained evidence; no production or test source was edited. Generated asset import metadata and unrelated UID files were outside this review. `docs/learning/lessons.md` was absent.

## Reports

### /root/motion_review

**F3 — [P2] Strikes can approach or finish their impact from the rock side.** In the reviewed `mosslight/scripts/digging_motion.gd:22-37`, every target direction uses the same raised grip and windup angle, and the strike interpolates the grip and angle rather than controlling the pick tip's approach. For the valid upward job target `(0, -1)`, that puts the pointed end inside the ceiling tile during windup, then moves it downward toward the final impact point. The endpoint is on the intended face, but the visible strike approaches from the rock side and withdraws toward open space instead of entering the ceiling underside. Horizontal strokes exhibit a smaller overshoot and outward reversal before contact.

The source formulas give this counterexample in settler-local tile coordinates. The upward target occupies `x in [0, 1]`, `y in [-1, 0]`; its open-side face is `y = 0`.

| Cycle phase | Pick-tip position | Meaning |
|---|---|---|
| `0.32` | `(0.02142667, -0.71305448)` | Raised pose is already deep inside the ceiling tile. |
| `0.51` | `(0.61680914, -0.20539394)` | End of accelerated strike remains inside the rock. |
| `0.52` | `(0.66, -0.08)` | Contact lies near the correct face, but the final motion increased y by `0.12539394`, away from the ceiling. |

For the rightward target, the same retained formulas produce `(1.03850194, 0.01713713)` at phase `0.50`, `(1.05509400, 0.21265588)` at `0.51`, then `(1.035, 0.42)` at contact. The last segment moves x by `-0.020094`, away from the right rock after entering it; the leftward stroke mirrors this overshoot and reversal. The reviewer independently calculated these values after the test worker reported the additional manifestations. They belong to the same F3 approach-direction class.

This is a trajectory defect rather than an endpoint or attachment defect. The initial test checks the final face point and confirms that the pick tip matches it, but does not check the side from which the tip approaches or its final inward direction. Keep preparation on the open side and make each directional strike enter its face while retaining the rigid shaft and attached hands, with a regression for all four target normals. The integration owner accepted F3 and assigned the geometry repair and test extension; this round does not verify that later repair.

**No additional actionable source finding.** For the reviewed first draft, the rig's contact endpoints correspond to the correct neighboring faces in all four directions. The left pose mirrors the right one, both grips stay on the rigid shaft, and the piecewise geometric poses join at windup, strike, contact, recoil, recovery and cycle wrap. The artist compensates hand positions for the torso transform and redraws the hands over the tool, preserving their attachment. The supplied downward-dig contact sheet shows distinct raised, striking and recovery poses with visible debris, rather than only vertical tool bobbing. The normal frame retains readable controls and a visible worker, but these images do not establish upward geometry or natural-cadence quality.

Presentation activation requires a live, stationary worker with an assigned dig job and rendered arrival at the sampled endpoint. Target offsets come from that actual job cell. The dig clock advances at render cadence using simulation speed, freezes on pause, resets for another job, and is suppressed for travel, rest, death, construction and reduced motion. `pose()` additionally checks the current actor job/task/path so a paused UI cancellation hides the tool before the next simulation step. Job arrays are read only; renderer poses remain independent copies. The diff leaves `simulation.gd` and `main.gd` unchanged, and world-view changes only supply jobs to the existing reset and simulation-step presentation calls. The rig creates at most six debris pieces and five trail samples, with no persistent particle collection or unbounded accumulation. Source inspection does not establish the resulting GPU frame time.

The frozen initial test checks broad tool rotation, tip excursion, rigid grips, cycle continuity, contact endpoints, timed bounded effects, body weight shift, speed-scaled clocks, authority isolation, pause/resume, cancellation and arrival guards. Its artist probe invokes the real `CaveArt` inside a valid draw callback and records the actual stroke and ellipse calls while still calling their production implementations. The optional legacy-artist comparison targets the previous fixed-angle implementation. This coverage is useful, but the missing approach-direction check allowed F3 to pass. The fifth suite is awaited by the existing runner, and the README accurately names five suites.

Grounding outside the patch: unchanged `simulation.gd:226-237` supplies cardinal neighboring job positions, so the upward target is part of actual gameplay rather than a hypothetical unsupported input. Unchanged lines 309-320 clear the assigned actor job, path and task when cancelling, matching the new immediate visual-cancellation guard.

## Findings and disposition

| ID | Finding | Disposition and reason | Repair or follow-up |
|---|---|---|---|
| F0 | Resume recreates a full-tick movement jump | Remains closed; its accepted accumulator behavior is unchanged. | Prior acceptance remains applicable. |
| F1 | Ground-resting settlers lose their resting pose | Remains closed; the shared resting-body predicate remains present. | Prior acceptance remains applicable. |
| F2 | Independent Control snapping opens regional texture seams | Remains closed; regional display geometry is unchanged. | Prior acceptance remains applicable. |
| F3 | Strikes approach or finish contact from the rock side | Accepted; pending repair. The numeric traces show a deep ceiling windup and outward final movement for upward and horizontal strokes. | Open-side preparation, inward strike geometry and a regression across all four target normals are assigned. A subsequent independent round must verify the frozen repair. |

## Verification

Exact source copies and digests were retained before repairs. The independent formula calculation above confirms the upward counterexample; it is not a Godot execution claim. Original-resolution image inspection covered the supplied downward-dig paused contact sheet and normal 1280x800 frame only. Their retained hashes are `7B043BD65B2A943052B8316A380EE6118DEE9EF72B2B76C742C5BD017755EE55` and `1AE809AE9E40145F099C08AAF0C067AB68150736487D7961160E6EF59BB60A71`, respectively.

The integration owner and test worker report 104 passing digging checks, 811 passing checks across all five suites, and 12 of 13 failing legacy-artist checks. This reviewer read the test source but did not execute or audit those runs. The worker subsequently added approach-direction checks and reported failures against the retained original helper; that changing test is outside this round's exact frozen test target. Browser input coverage, native frame pacing, normal-cadence animation and the later directional repair remain outside this round's acceptance.

## Round outcome

The digging first draft has one material finding, F3, pending repair and independent recheck. F0-F2 remain closed. The downward captures show the requested broader swing and impact content, but this round does not accept the final digging implementation, all-direction rendered behavior or native performance. Preserve the original target and this authored report when the directional repair lands.
