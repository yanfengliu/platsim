# Review 6: implementation

## Target

Repository: platformer. Independently rechecked the F3 digging-strike repair on branch `codex/mosslight-digging` in `C:/Users/38909/Documents/github/platformer/.worktrees/mosslight-digging`, based on `8f3655a1b78d28f2288edbcc1969c9fda5175f0f`, on 2026-11-07. The target is the final frozen helper with a direction-specific ceiling preparation and a controlled tip trajectory, plus the frozen 128-check digging test. The integration owner and test worker confirmed the helper and test hashes before this recheck.

The reviewer retained all eight source files below under the primary checkout's ignored `output/mosslight-digging/evidence/review-6/`, using their basenames. Raw source and retained-copy hashes matched at retention and were rechecked at the end. These identify the exact reviewed bytes; round 5's original target remains separately retained.

| Reviewed path | Raw SHA256 |
|---|---|
| `mosslight/scripts/digging_motion.gd` | `FFFE6B4D99F82618244DF691EBBA7AE8508E8F1493FEB51EADDDBE581EF029D8` |
| `mosslight/scripts/digging_motion.gd.uid` | `71506406F7B75E7035ED4C98ACC35CC9980AF019714968C0D94244716C1FFC8F` |
| `mosslight/scripts/cave_art.gd` | `83546918DDD7F64D076F5B6CA99F6E5DBEA5F9102BD6BF32EE0A9AD27BB90B97` |
| `mosslight/scripts/presentation_motion.gd` | `E973272FA927526AD541B2A82C7198CADC582138D032AAD71C9B4BF67F9B36DC` |
| `mosslight/scripts/world_view.gd` | `2FE9228620692BE4C757DEB434D5170B6C7E205C847F13A0754BAB0788E9FBBF` |
| `mosslight/tests/digging_animation_test.gd` | `B7FF0B008C6D47A3FF09D5BA2E696C7592F5A5E4B43FA9FD576FC72E0D1B2C48` |
| `mosslight/tools/godot.mjs` | `A2FE2D68C0A6B8EFB197FA4E5457F236432B5097630D692F08F2EF6B02A0DF0B` |
| `mosslight/README.md` | `FB0228551CE46782A6EDD133CB561D90682CAF56C18CF426E4B7CEE3E9B34AAF` |

Only the helper and digging test differ from round 5 among these eight files. The production artist, lifecycle helper, world wiring, runner and README remain byte-identical. Generated import metadata, unrelated UID files and the integration owner's capture instrumentation are outside this source review.

## Reviewers and coverage

Independent reviewer: `/root/motion_review`. This round checks the whole F3 directional-approach class, including the original ceiling windup/withdrawal and the horizontal late-strike overshoot, without narrowing acceptance to the first reported upward example. It also checks that the repair preserves rigid hand attachment, phase continuity, bounded presentation work and the existing lifecycle integration.

The reviewer read the full frozen helper and test, compared both against the exact retained round 5 sources, re-read the production artist and presentation lifecycle, and checked unchanged simulation job-goal and cancellation code. The reviewer independently calculated the repaired source geometry, read and retained the worker's original-red and final-five-suite logs, and verified hashes. No game, GUI, browser, GPU job or runtime test was launched by this reviewer. No production or test source was edited. This round adds only this authored report and ignored evidence copies.

## Reports

### /root/motion_review

**F3 closed; no new actionable source finding.** In `mosslight/scripts/digging_motion.gd:27-33`, ceiling work now prepares below the face with a low grip and crouched body, then extends upward. Lines 42-56 control the pointed end with a quadratic path and solve the grip backward from that point along the rotating rigid shaft. That removes the original coupling in which grip interpolation plus rotation could send the pointed end through the rock or reverse its normal direction just before the contact beat.

The chosen control points make the tip's inward coordinate monotonic over the entire accelerated strike. For horizontal work, the normal coordinate approaches contact as `C - (C - R) * (1 - t)^2`; for downward work, it advances as `R + (C - R) * t^2`. For upward work, the three y control values decrease from about `1.244790` through `0.17` to `-0.08`. The acceleration parameter increases continuously from zero to one. Mirroring x preserves these properties for leftward work and both vertical facings. This reasoning covers the interval, rather than relying only on the new test's four late samples.

Independent calculation of the actual frozen formulas gives the following settler-local tip positions. These are source-math results, not a Godot runtime observation.

| Target | Phase 0.50 | Phase 0.51 | Phase 0.52 contact |
|---|---|---|---|
| Right | `(1.004752, 0.062342)` | `(1.027116, 0.228956)` | `(1.035000, 0.420000)` |
| Left | `(-0.004752, 0.062342)` | `(-0.027116, 0.228956)` | `(-0.035000, 0.420000)` |
| Up, facing right | `(0.782960, 0.030989)` | `(0.725679, -0.029488)` | `(0.660000, -0.080000)` |
| Down, facing right | `(0.640943, 0.483212)` | `(0.655033, 0.740261)` | `(0.660000, 1.035000)` |

The upward tip is on the open side at the start of the accelerated strike, about `(1.049536, 1.244790)`, and moves upward into the ceiling underside. Its final segment decreases y by about `0.050512`. The horizontal final segment now moves inward by about `0.007884`, instead of reversing outward by about `0.020094` as in the retained original. Contact retains the existing small art inset. The downward trajectory also continues into its intended face.

The repaired grip joins the existing ready, contact, recoil and recovery poses continuously. Shaft endpoints, head and both hands are still derived from one grip and angle, so changing the grip solution does not detach either hand or alter shaft length. The phase wrap returns exactly to the ready pose in the independent calculation. At 120 equal samples per cycle, the calculated largest tip step is approximately `0.154240` tiles horizontally, `0.076207` upward and `0.237561` downward, within the unchanged `< 0.25` test bound. Those cycle samples are a geometry check, not a claim about actual frame cadence at 1x or 3x.

The unchanged artist at `cave_art.gd:198-214` subtracts the torso offset from the hand endpoints before drawing under the torso transform, then lines 236-250 restore the settler transform and draw the tool and hands from the same rig coordinates. The new upward body offset therefore preserves attachment. The helper adds constant-sized arithmetic to the existing bounded calls; it introduces no node creation, persistent particles or growing collection. The six-chip and five-trail-sample limits remain unchanged. No source-level performance regression was identified; native frame pacing still requires measurement.

The lifecycle and authority assessment from round 5 remains applicable because those files are identical. The reviewer re-read the rendered-arrival activation guard, speed-scaled dig clock, paused early return, job-switch clock reset, reduced-motion suppression and immediate raw actor cancellation guard. The diff still leaves `main.gd` and `simulation.gd` unchanged. As grounding outside the patch, `simulation.gd:226-237` admits cardinal neighboring job positions, so the corrected upward and horizontal cases occur through normal gameplay; lines 309-320 clear the worker's job, path and task on cancellation, matching the presentation guard.

The frozen test adds 24 independent face-plane/normal checks across all four targets and both facing values. It checks preparation on the open side, early strike outside the rock and four final inward increments. Its expected planes come from the selected neighboring tile rather than the helper's chosen contact coordinates. The optional retained-helper mode can exercise the actual old helper with the same checks. The pre-existing grip, rotation, endpoint, effect, lifecycle, actual-artist and `< 0.25` continuity assertions remain; the continuity change adds diagnostic output and clearer wording without loosening the condition. The five-suite runner remains awaited and unchanged.

## Findings and disposition

| ID | Finding | Disposition and reason | Repair or follow-up |
|---|---|---|---|
| F0 | Resume recreates a full-tick movement jump | Remains closed; accepted accumulator behavior is unchanged. | Prior acceptance remains applicable. |
| F1 | Ground-resting settlers lose their resting pose | Remains closed; the shared resting-body predicate is unchanged. | Prior acceptance remains applicable. |
| F2 | Independent Control snapping opens regional texture seams | Remains closed; regional display geometry is unchanged. | Prior acceptance remains applicable. |
| F3 | Strikes approach or finish contact from the rock side | Closed in the exact frozen helper above. Direction-specific preparation and monotonic tip paths correct ceiling entry and horizontal reversal while preserving rigid attachment. | The added whole-class regression checks all four inward normals and both facings. Rendered/native acceptance remains the integration owner's separate gate. |

## Verification

The reviewer read and retained `digging-f3-original-red.log`, SHA256 `FF61AFB049C32067F53A01F6CD42722EABED67CC03DC13F854C73489D879D01F`, and `digging-f3-five-suites-green.log`, SHA256 `F2763B0509CB343079404E0842777E1AECF2A13D4C9C7EE098F54E856D31C5C0`, under the same primary `review-6` evidence directory. The first records 24 approach checks with 10 failures, covering upward preparation/entry/direction and horizontal reversal. The final log records simulation 277, motion 291, UI settings 77, terrain 62 and digging 128 checks, all with zero failures: 835 total. The test worker identified the original and final helper hashes for these runs. The reviewer inspected their output and frozen source but did not independently execute the runs.

Independent verification in this round comprises exact-source comparison, full repair/test reading, production call-path reading, arithmetic evaluation of the frozen geometry, and start/end source-hash checks. No visual capture was inspected in this round; round 5's supplied downward paused images do not establish the final upward repair or natural-cadence quality. Final real-input rendered checks, exports and native GPU/frame-time acceptance remain outside this review.

## Round outcome

The frozen digging repair passes this independent source review. F3 is closed and F0-F2 remain closed, with no new actionable source finding. This is source acceptance of the exact recorded target, distinct from the integration owner's pending rendered and native performance acceptance.
