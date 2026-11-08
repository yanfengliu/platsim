# Review 7: implementation

## Target

Mosslight's correction for the owner-reported awkward intermediate digging pose, reviewed on 2026-11-07 against base `53ae474700af2c17bc97da156a66b09e883f78a0`. The reviewed changes are the articulated arm/tool helper, its artist, the digging regression tests, and the associated devlog, defect-register and plan changes. The helper, artist and test bytes were frozen during this review.

| File | SHA-256 |
| --- | --- |
| `mosslight/scripts/digging_motion.gd` | `c32f5b538a3aa0311604d8670307e35230460ef37eb22ea305c1e3f19484a3d3` |
| `mosslight/scripts/cave_art.gd` | `52133ddc2c3e99658181739c684f7d706e57aee73462aa1008e616e9ee82fc42` |
| `mosslight/tests/digging_animation_test.gd` | `fb858215f0e0a49ef5cb7f5aeb34f0af52ee98148a85c806d708ca2078faa558` |

The exact source snapshots and complete scoped patch are retained under the primary checkout's ignored `output/mosslight-pose/evidence/review-7/`. The reviewed base recovers unchanged dependencies; the evidence also includes the unchanged presentation helper and world view read for call-site verification. A hash alone is not the recovery mechanism. Generated import metadata and UID files are outside this review's authored-code scope.

## Reviewers and coverage

Codex delegated independent reviewer, using the fleet's pinned review configuration. Read the complete changed helper, artist and test code, the complete scoped diff, the unchanged presentation lifecycle, and the world-view call sites. The review did not delegate further, edit implementation/tests, run Godot/browser/GPU workloads, or launch a second CLI reviewer. Runtime logs and native captures were produced by the integration/tooling lanes and independently inspected here. No Claude report is claimed.

The original rejected `output/mosslight-digging/digging-poses.png` was inspected before the new captures. All 18 downward native PNGs at 1280 by 800 and the two upward preparation/contact PNGs were inspected at their original resolution. The downward series includes ten distinct strike phases from 0.33152 through 0.50202, as well as ready, preparation, contact, recoil and recovery. The reviewer then inspected all twelve horizontal browser pose samples and the normal-scale digging captures at 1280 by 800, 720 by 560 and 320 by 640.

## Reports

### Codex independent source and pose review

No blocking source defect found. The old artist's independently invented elbows are replaced by one rig-owned chain per arm. `digging_motion.gd:13-19` solves the two fixed bone lengths; lines 103-117 place and mirror both sockets, elbows, wrists and the rigid tool together. The reviewed cardinal poses stay within the reachable range exercised by the retained checks, and the signed bend choice is stable rather than switching solution branches. The added rear-socket lift stays inside the existing coat silhouette; it does not move authority or the character's world position.

The draw order is coherent in `cave_art.gd:186-238`: the far sleeve is drawn behind the coat, the head uses its authored local offset, and the near sleeve is drawn after the head with the tool and both hands on top. Each sleeve is a connected shoulder-elbow-hand chain in lines 241-251. Both hand centers remain on the same rotating shaft; the pick is smaller without changing shaft length or inventing an independent impact point. The native downward series visibly corrects the rejected extended/disconnected-hand appearance and clears the cap in the intermediate frames. The upward preparation and contact frames show a low preparation followed by a strike into the underside, with the pick clear of the head.

Contact and lifecycle behavior remain intact. `digging_motion.gd:27-38` retains the neighboring rock-face coordinates, with the upward tangential contact moved near the edge of that same tile; lines 81-85 hold the contact beat, and lines 120-135 retain clock wrapping and bounded trail/debris timing. The unchanged `presentation_motion.gd:73-100` advances the presentation clock only while running and actively working, and lines 112-129 return a duplicate presentation pose while suppressing canceled/traveling work. The unchanged `world_view.gd:501-516` still draws jobs and settlers through the normal dynamic layer. This review found no simulation, persistence, job-lifecycle or pause change in the diff.

The new tests cover the reported defect class beyond the rejected screenshot: both arms' fixed lengths/reach, full-cycle joint movement, complete shaft/pick clearance against inflated head bounds, mirroring, and actual arm-chain draw calls. They retain the separate inward-normal approach and real neighboring-face oracles. Two limits remain: the 240-sample continuity threshold is a geometric bound, not proof of perceptually smooth motion at display cadence; and the draw probe records local coordinates before CanvasItem transforms, so it cannot independently detect a misplaced drawing transform. Those limits make the actual rendered checks necessary. The inspected pixels show no resulting defect in the downward, upward or horizontal views. In the horizontal sequence, the curled elbows stay visibly attached through preparation, the near-contact frame and recovery, with the pick clear of the cap. Normal-scale and compact captures keep the working settler and selected rock visible.

The changes add a bounded number of trigonometric/IK operations and sleeve draw calls per visible working settler. They introduce no unbounded state, image rasterization, scene nodes, external assets or runtime dependency. The native timing analysis reports 1x p99 10.125 ms and maximum 14.923 ms across 2,401 included frames; 3x p99 is 11.364 ms and maximum 19.980 ms across 2,148 included frames. Two 3x frames exceed 16.7 ms: one at a terrain change and one later without a terrain change. This sample supports typical performance above 60 fps but cannot support the earlier run's stronger every-included-frame-under-16.7-ms claim. The reviewer has not attributed the two hitches to this patch or certified compositor timing.

## Findings and disposition

No new actionable source or rendered-pose finding. Earlier finding IDs are preserved in their authored rounds; this review does not rewrite those reports. The timing qualification and coverage limits above remain explicit and are not converted into an every-frame performance claim.

## Verification

Read the retained `five-suites.log`: simulation 277, presentation motion 291, settings 77, terrain 62 and digging 157 checks, all with zero failures, totaling 864. Read the shipped-helper red log: all 25 anatomy checks fail. The reviewer did not re-execute these suites. The native capture source manifest matches the frozen helper/artist hashes above. The source review also checked that the 25 anatomy regressions and artist-chain checks are additional assertions, not relaxed replacements for the prior rigidity, contact, direction or lifecycle checks. The retained held-out diagnostic exercises 24,008 off-grid/random phases and offset continuity intervals with zero failing configurations; its candidate bytes match the reviewed production helper. This strengthens sampled geometry coverage without claiming to replace pixels or video.

Read the npm logs: static check and build pass, and all 108 Emberwake tests pass. Read the browser acceptance log and its executed interaction code: it uses actual keyboard/mouse controls, queues the horizontal job at (17, 19), samples twelve poses by normal pause/resume input, cancels while paused, preserves pause through Settings, and completes a requeued job at 3x. Its result reports title/help/settings checks at all nine required widths, 150/200 percent scaling, keyboard reset, focus/pointer checks and zero remaining task processes. The reviewer inspected the fifteen horizontal/gameplay PNGs named above; the coordinator owns the separate full UI screenshot acceptance.

The native evidence consists of actual GPU PNGs and accompanying observed pose metadata from ordinary engine-input workloads, paused through normal controls for inspection. It is not a natural-cadence video, OS-input certification or compositor-timing measurement. Upward intermediate/recovery phases and right-facing rendered poses are covered by source/tests rather than this native capture set. All 20 inspected native PNGs, their per-frame metadata, the fifteen inspected browser PNGs and the browser acceptance log are retained in the review evidence alongside the source manifest and timing/correlation reports. Native and browser process audits report zero owned processes. The final source hash check still matches all three frozen files above.

No task-owned browser, GUI, server or watcher was launched by this reviewer. Source snapshots, patch, relevant logs and inspected-evidence manifests are intentionally retained; earlier review rounds are unchanged. `docs/learning/lessons.md` is absent in this checkout, so no contents are attributed to it.

## Round outcome

Closed: no blocking defect found in the frozen pose correction after exact-source review and downward, upward and horizontal rendered inspection. The reported awkward-swing defect is corrected within the stated coverage. All 864 Godot checks and 108 Emberwake tests pass in the inspected logs; the two 3x timing outliers remain disclosed. This review does not certify natural-cadence video, OS/compositor timing, native Mac execution, every-frame 60 fps or the later owner-directed repository extraction/history rewrite. The coordinator will retain this authored report and its exact-target evidence with the dedicated game repository; moving those files does not expand this review's scope.
