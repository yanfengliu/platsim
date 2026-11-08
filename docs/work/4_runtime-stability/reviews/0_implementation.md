# Review 0: implementation

## Target

Base 530d053aac978db1ae2b0c3ffa0a6f1e8b4aa87c in yanfengliu/platsim. The uncommitted cap configuration, runner and new runtime stability test are retained under ignored output/crash-diagnostics/review with manifest hashes: project 8ab30937efa3c0d3f13d132588d3eeace779edeb53d13623c56a6f89a95b0f11; runner 65c920499a2a23da23968551b11145eca66d808e0016d34b9a1fc943e8de6646; test 29ff748d633c5e1a8a078dbb54cd62ed1d2f215ee1f54c03b5a95c004d16b1ab. The later comment-only test adjustment is identified separately below. The original watchdog is retained there as original-run-soak.ps1, reconstructed from its exact recorded edit, with original run evidence in wrapper-only-monitor. These inputs remain retained until bound to a recoverable revision or superseded only for execution, never silently treated as repaired coverage.

## Reviewers and coverage

Independent GPT-6 Astra at xhigh, read-only subagent stability_review. Read the exact frozen source and integration code, diagnostic claims and measured evidence. No engine, browser or GUI launch; no mutations. This was one independent review, not a two-CLI review.

## Reports

### GPT-6 Astra

One blocking diagnostic finding; no blocking defect found in the production frame-cap change.

- **RS-1 — P2: Watchdog measures the console launcher, not Godot.** run-soak.ps1:14 samples and limits the process launched at line 7, which is _console.exe. Godot's [4.7.2 wrapper source](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/platform/windows/console_wrapper_windows.cpp) launches the actual engine as a child and waits. The retained samples confirm this: peak private memory is only 1,339,392 bytes, with 0.015625 CPU seconds, while the engine reports roughly 50.8 million tracked bytes. The 1 GiB guard therefore cannot detect excessive engine memory. Launch the real executable headlessly with redirected streams, or measure verified descendants, and rerun before retaining the external-memory-watchdog claim in defect-register.md:9. The time limit and tree cleanup remain meaningful.
- **RS-2 — P3, nonblocking: Painter count is assumed rather than measured.** runtime_stability_test.gd:100 returns _terrain_cells.size() * 2; consequently line 111 would pass if each cell contained one or three painters. Count actual pair members and require two per cell. Production currently creates exactly two at world_view.gd:413, so this is a test-strength issue.

Integration review found the lifecycle assertions grounded in actual production behavior: scale changes retain and reparent the world while freeing the old UI at main.gd:491; terrain replacement queues old painters and targets for deletion at world_view.gd:392 and line 441. The bounded accumulator at main.gd:534 also supports the stated finite-loop assessment.

The completed soak records 180.002 seconds, 10,770 frames, 180 simulation seconds, and 497 checks with zero failures, with unchanged node/object counts and no orphan nodes. Those engine-level results remain useful despite RS-1. They do not establish native GPU stability. The incident description and mitigation wording correctly leave causation unproven.

Reviewed the manifest's frozen bytes against base 530d053, plus the subsequent comment-only test change (A7B8C6C...). README suite-count correction is also verified. I launched no engines, browsers, or GUI processes and made no changes. Final acceptance still needs the corrected watchdog evidence and the owner's remaining gates.

## Findings and disposition

| ID | Finding | Disposition and reason | Repair or follow-up |
|---|---|---|---|
| F0 | RS-1, wrapper-only memory monitoring | Accepted. The measured launcher is not representative of engine memory. | Start actual engine directly with --headless; repeat bounded measurement and request review 1. |
| F1 | RS-2, inferred painter count | Accepted. Count actual pair members and require exactly two per cell. | Repaired test and repeat regression/soak; request review 1. |

## Verification

The first new suite failed 36 assertions because its source target expectation was 1x1; exact Godot 4.7.2 viewport.cpp clamps dimensions to 2x2. Correcting that expectation and retaining the disabled-target assertion yielded 436 passing lifecycle checks. The six existing suites passed 1,552 checks. The initial 180-second soak passed 497 engine-level checks but its external process-memory measurements are invalid for the engine, as F0 explains. An isolated proposed subagent probe was rejected by automatic approval review and was not retried; the minimum-size fact was established from official source. Root's separately approved bounded headless gates used the dummy renderer. Software WebGL capture completed normal construction/digging through real controls, verified SwiftShader, and produced an inspected 1440x900 image. Native GPU stability remains untested.

## Round outcome

Production load mitigation has no blocking code finding. Diagnostic acceptance waits for the corrected engine-memory measurement and follow-up review. F0 and F1 remain open in this historical round; closure belongs to review 1.
