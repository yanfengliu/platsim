# Investigate Windows system freeze and bound runtime load

Status: complete
Owner: Codex integration owner
Created: 2026-11-07
Updated: 2026-11-07

## Problem and outcome

The owner reports the Windows game appeared, then the entire PC froze or restarted within seconds. Identify evidence of unbounded work or memory growth, bound unnecessary rendering load, and report diagnostic limits without calling an unproven mitigation a crash fix.

## Scope

Read Windows shutdown and application records, audit runtime loops and resource ownership, add an explicit 60 FPS limit across exports, and add bounded lifecycle and headless soak regression coverage. No driver changes, machine configuration changes, or native GPU reproduction while the freeze remains unexplained. The root owns diagnostics, config, execution and delivery; the renderer audit agent owns the static audit and new test file.

## Approach

The shipped build relies on VSync and driver/display behavior without an application frame limit. Cap rendering at 60 FPS while retaining existing VSync and interpolation. Preserve the renderer: its finite startup allocations are not evidence of a leak. Exercise production lifecycle methods with deferred frees and a monitored headless soak. Refresh the required README capture using software WebGL in an owned headless browser with hardware acceleration disabled.

## Acceptance criteria

- Record confirmed shutdown evidence separately from hypotheses and historical reports.
- Verify the effective 60 FPS cap and bounded scene, scale, map/cache and menu lifecycles.
- Complete a bounded headless memory run with a watchdog; record samples, resource counts and limits.
- Pass gates and independent review, produce labeled mitigated exports, merge/push, follow CI and clean owned processes.
- Do not claim native GPU stability or resolution of the system freeze without evidence.

## Implementation steps

- Collect scoped Windows records and audit loops, cache sizes and resource lifetimes.
- Add the cap and tests, execute bounded headless checks, refresh the image without hardware acceleration, and rebuild exports.
- Review, document, deliver and retain diagnostic evidence.

## Outcome

Windows recorded Kernel-Power 41 at 2026-11-07 21:41:26 PST with BugcheckCode 0 and a nonzero PowerButtonTimestamp. This confirms an unclean restart and is compatible with a forced shutdown after a hang; it does not identify what caused the hang. No current minidump, recent LiveKernelReports file, scoped memory-exhaustion event or Godot application-crash event was found. WER reports emitted after reboot reference older watchdog dumps and are not attributed to this incident. A corrected PCIe root-port warning is likewise not a demonstrated cause. Post-reboot free RAM is not crash-time memory evidence. Raw records remain ignored under output/crash-diagnostics.

**Correction from work 5 (2026-11-07):** The protected LiveKernelReports and WER folder searches above suppressed access errors. Explicit follow-up reads show the current token cannot access those folders. Their empty results did not establish that no incident dump or report exists. The readable minidump is historical, but protected reports remain unexamined pending a scoped administrator collection. The owner's later clarification confirms the image froze and they held the power button to restart.

Static audit of 530d053 found no demonstrated unbounded script loop or retained per-frame growth. The default map creates 2,496 terrain painters, 84 terrain targets and one infrastructure target, approximately 47.3 MiB of declared RGBA8 color storage before driver overhead. A missing application cap permits higher frame rates; this is a concrete load exposure, not a proven cause. Earlier short native frame tests used the matching editor engine with the exported pack, and did not establish standalone-export GPU startup or long-run memory stability.

The work allocator exposed two formatting errors in the prior completed pixel-art record. Its status is normalized to complete and its acceptance text is retained within the plan; no historical test claim is strengthened.

The corrected headless soak ran the actual engine executable directly for 180.000 seconds: 10,800 frames and 180 simulation seconds, with 534 assertions passing. It held 2,772 nodes, 4,697 objects and zero orphan nodes; tracked static memory changed from 50,765,517 to 50,771,725 bytes. External private memory peaked at 77.3125 MiB; after warmup it moved from 75.421875 to 75.2890625 MiB. Process identity was captured with --headless and no children. The watchdog imposed a 1 GiB private-memory and 240-second wall-time limit; PID 29628 exited normally. These measurements cover the engine's CPU allocations under the tested workload, not GPU memory or driver behavior. The earlier wrapper-only memory measurement is retained as invalid process-memory evidence, with its review finding and repair in reviews 0 and 1.

The software-only browser explicitly reported ANGLE SwiftShader before loading the game. Real controls built two life-support items, excavated the quarry entrance and began another dig; no page/console errors occurred. The inspected README capture is 1440x900. All browser contexts, task daemon, children and localhost server were closed. No native graphical run was attempted after the crash report. Windows and macOS exports were rebuilt; macOS runtime remains untested.

Windows event interpretation follows [Microsoft's Event 41 guidance](https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/event-id-41-restart); the load mitigation follows [Godot's Engine.max_fps documentation](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-max-fps). Neither source establishes this incident's cause.

Final local gates pass: README freshness/import and 2,024 checks across seven suites (569 simulation, 291 motion, 403 UI, 62 terrain, 157 digging, 70 pixel art, 472 runtime stability). The additional timed run passes 534 checks. Both independent review findings are closed in review 1. The standalone release executable exits normally after 120 supported headless iterations; a matching headless engine separately loads that exact exported pack, verifies its effective max_fps=60 and advances the production scene for two simulation seconds. The initial release smoke timed out because release CLI help omits the editor-only --script flag; it did not execute the observer. That failed harness attempt is preserved and superseded by these supported checks, not interpreted as a demonstrated game hang.

The original reported Windows artifact SHA256 is 7f19f971a4bd37443f544b118242939ab7372ae578ea6aa5e5188925dd239baf. The capped Windows export is 6da7b0a654cac5dc299e796977dfd45822d4cba345f8149bdcca70f9f8282dcb; macOS archive is 6c14e859092b8bea34c62d6d17d8ff40139b36c131e72cc0f4c5ce1e9f35565b. These are mitigated builds, not certified crash fixes. The README image represents the same capped source. Code delivery and CI closure are recorded below.

The bounded diagnostic and mitigation work is complete in code commit d110aebd77ef054dfca94986e8947eede91ff5e5, merged to platsim/main and pushed. [GitHub CI 42453711556](https://github.com/yanfengliu/platsim/actions/runs/42453711556) completed successfully, including capture/import, all seven suites and runtime cleanup. This completion does not resolve the reported system freeze: native GPU stability, GPU memory behavior and the incident cause remain unproven.

Current Windows/macOS/web artifacts, the gameplay image, PLAY.md and delivery.json are under the primary checkout's output/mosslight. Raw diagnosis, failed/corrected measurements, exact review targets, process audit and CPU-only browser capture are deliberately retained under C:/Users/38909/Documents/github/platsim/output/mosslight-stability/evidence; paths above beginning output/crash-diagnostics now map to evidence/crash-diagnostics, and software-capture retains the browser evidence. The reported original executable is retained there as Mosslight-before-fps-cap.exe. Copied evidence and exports are hash-verified before redundant worktree outputs are removed. No task-owned game, browser or localhost server remains. The app-managed worktree is retained as this chat's project location, detached at delivered main; the completed task branch is removed.
