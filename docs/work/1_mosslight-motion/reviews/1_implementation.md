# Review 1: implementation

## Target

Repository: platformer. Rechecked the frozen uncommitted repairs for work 8 against base `e97177b80dd7f5c0a3d727e692c0fcd988187e4a` and the retained round-0 source on 2026-11-07 in `C:/Users/38909/Documents/github/platformer/.worktrees/mosslight-motion`. Scope includes the nine source, test, tooling and documentation files listed below. The Godot runner and README are newly covered in this round; the UI-settings helper and tests were also read again. Generated Godot import metadata and UID files are outside this review target.

The integration owner retained these exact nine files under the primary checkout's ignored `output/mosslight-motion/evidence/review-1/`, using their basenames. The reviewer verified those copies against the following raw SHA256 digests. All nine working-file hashes were identical at review start and end, with no line-ending normalization.

| Reviewed path | SHA256 |
|---|---|
| `mosslight/scripts/cave_art.gd` | `66C244C298C7D1AAC8A20FAAC0AABE22580CAC5C2CC308824DF0C6DF30FF61D7` |
| `mosslight/scripts/main.gd` | `9762567B27897F69062BBF11FB5B367262F9F947CC81D473D2FD1D42BB5CEC3A` |
| `mosslight/scripts/world_view.gd` | `F230E833DE0E0D8D3D02E46E90EEDD9C3582EDB5D0F0A92DEAD22325A61B07F7` |
| `mosslight/scripts/presentation_motion.gd` | `4A14BD576169E32419B512965AA75D6F99F4019EFCD70FA4DCA47A9D83E36C38` |
| `mosslight/scripts/ui_settings.gd` | `558922EB0A0A020C6B2557A6D1CF6A156E138494CEC6376D2D7E52258176E573` |
| `mosslight/tests/presentation_motion_test.gd` | `9FC3C127C1468EA2B8932510AAF2AF3CD1EE2651903E2CA480D37F9195C5E201` |
| `mosslight/tests/ui_settings_test.gd` | `A15FAD7F71A3823E3EB6E9B0B1088CA2CB8C7919277E38B59EBC82B28A39C784` |
| `mosslight/tools/godot.mjs` | `642F0789CADC9D9BCD41A7ACD9DA9F1C92010793F2FE3B967D781261F11FD87F` |
| `mosslight/README.md` | `7A0CB48BFA61B7E1BEE6A3FC48F0D5FADD1F7521BA470359EA5B181EF5D638B4` |

## Reviewers and coverage

Independent reviewer: `/root/motion_review`, returning to verify F0 and F1 from round 0 and inspect the newly included runner and README. The reviewer read the repair diffs against retained round-0 files, the repaired presentation helper, new regression-test paths, UI-settings source and tests, the Godot runner, README, accumulator references in production code, and the CI workflow that invokes the runner. The unchanged world-view digest matches its round-0 reviewed bytes.

This was a source recheck with no source edits, GUI interaction, game or browser launches, test execution, heavy gates, or performance measurements. The reviewer authored only this new review record. Independent runtime acceptance remains with the integration owner's gates and rendered checks.

## Reports

### /root/motion_review

**F0 is closed for the reviewed source.** Production `mosslight/scripts/main.gd` now retains `_accumulator` through `_toggle_pause`, `_on_focus_lost`, `_new_overlay` and `_close_overlay`; outside initialization, the only reset is `_restart` at line 992, alongside the authoritative and presentation resets. `_process` at lines 440-453 adds elapsed time only while the colony is running. The helper's `present()` at `mosslight/scripts/presentation_motion.gd:61-74` simply freezes when inactive and resumes ordinary interpolation from the retained fraction. The former first-resume-frame return and segment rebasing are gone. In the original 3x/60 fps failure sequence, a paused alpha-0 position `x` now advances to `x + 0.105` on the first resumed frame and `x + 0.21` on the next tick, rather than holding and then jumping a full tick.

The source regression coverage now addresses both sides of that contract. `mosslight/tests/presentation_motion_test.gd:353-416` runs the accumulator order over 60/120 fps, 1x/3x, seven paused fractions, straight travel and a turn; it checks frozen frames, the first resumed displacement, subsequent spacing, retained travel and path bounds. Its optional accumulator-reset negative control targets the removed behavior. Lines 320-346 instantiate the actual production scene and call its pause, resume, focus-loss, menu and restart handlers, preventing a copied accumulator driver from being the only protection. These are source observations; this reviewer did not execute the checks or independently reproduce the reported results.

**F1 is closed for the reviewed source.** The helper's `_read_activity()` at `mosslight/scripts/presentation_motion.gd:28-34` recognizes the actual `Resting` task prefix, and `pose()` at line 110 publishes one `visual_resting` predicate requiring a live resting settler, arrival at the sampled endpoint and a settled walking weight. `mosslight/scripts/cave_art.gd:161` consumes that predicate directly. The renderer no longer narrows it to exact `"Resting"`, so the unchanged simulation's `"Resting on the ground — needs a reachable bed"` task is covered. Endpoint checking also prevents reduced-motion zero gait weight from lying a settler down before visible arrival. The motion tests include ground rest, bed approach and arrival, reduced-motion approach and arrival, and death separation.

**No additional actionable source finding.** `mosslight/tools/godot.mjs:105-117` awaits all three existing suite paths in order for both `test` and `verify`, preserving rejection on a failed suite and import-before-test behavior for `verify`. The unchanged `.github/workflows/mosslight.yml:31-34` imports the project and calls this runner's `test`, so the README's expanded CI-suite description matches that wiring. The README's menu, scale and inspection controls match production routing. The session-only UI settings retain the requested preset while applying viewport caps, and the tests exercise compact limits, restoration on enlargement, invalid preset rejection and monotonic caps. No new issue was found in the repairs or these additional files; this conclusion does not substitute for rendered viewport checks.

Grounding retained from round 0: unchanged `mosslight/scripts/simulation.gd:485-499` moves at `2.1 * dt`, while lines 603-605 set the ground-rest task. The repairs leave those authoritative movement, survival and task rules unchanged.

## Findings and disposition

| ID | Finding | Disposition and reason | Repair or follow-up |
|---|---|---|---|
| F0 | Resume recreates a full-tick movement jump | Closed by independent source recheck. Fractional time survives every production pause/menu path, and ordinary interpolation replaces resume rebasing. | Reviewed `main.gd`, `presentation_motion.gd` and regression-test hashes above. Runtime execution of the checks remains part of integration verification. |
| F1 | Ground-resting settlers lose their resting pose | Closed by independent source recheck. The renderer consumes the shared task-prefix-aware rest predicate with arrival and gait guards. | Reviewed `cave_art.gd`, `presentation_motion.gd` and regression-test hashes above. Rendered behavior remains part of integration verification. |

## Verification

Read-only file and Git inspection verified the repair diffs, production call paths, test coverage, suite wiring, documentation consistency, stable start/end hashes and matching retained review-1 copies. No tests or GUI checks were run by this reviewer. The integration owner's reported passing test counts were not independently executed or used to claim frame-rate or rendered-motion acceptance. No reviewed source changed during this round.

## Round outcome

F0 and F1 are closed on the exact reviewed source, with no new actionable finding. Source review accepts these repairs and the newly covered runner and README. Sustained Windows frame rate, observed animation quality, real input behavior, viewport layouts, final repository gates and CI remain separate integration acceptance requirements. Round 0 remains unchanged as the historical first-draft report.
