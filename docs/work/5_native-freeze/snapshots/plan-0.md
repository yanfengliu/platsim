# Investigate native Windows freeze without risking the workstation

Status: active
Owner: Codex integration owner
Created: 2026-11-07
Updated: 2026-11-07

## Problem and outcome

The owner requests the actual cause of the Windows freeze while explicitly avoiding another workstation crash. The cave appeared, the image froze, and the owner held the power button to restart. The earlier frame cap was only a load mitigation. Seek causal evidence through existing records, native implementation review and genuinely isolated reproduction; do not substitute a plausible hypothesis for a diagnosis.

## Scope

No native graphics workload, graphics-driver API probe, driver/settings change or stress test runs on this PC. Preserve shader caches and incident artifacts unchanged. Root owns Windows forensics and isolation options; native_backend_audit provides a bounded read-only review of exact Godot 4.7.2 Windows/GLES3 code and offline cache containers. Protected reports require a separate Windows administrator token; an explicit scoped collector is prepared for user approval. Dumps remain local and ignored.

## Approach

Establish which executable was launched, compare successful observer runs with normal standalone initialization, inspect existing kernel/Windows error reports, validate cached shader containers without loading them, and map renderer allocations and native calls. Use a fresh remote CI VM only if its test can narrow a live hypothesis; it cannot reproduce this NVIDIA hardware/driver combination with a software renderer. No connected remote machine or self-hosted repo runner is currently available.

## Acceptance criteria

- Keep the workstation's graphics path untouched throughout investigation.
- Preserve evidence and report denied or unavailable reads explicitly.
- Identify a cause only when incident evidence or a controlled reproduction supports it; otherwise state the specific missing evidence.
- Record confirmed facts, rejected hypotheses and remaining hypotheses separately, with exact source and artifact provenance.
- Review findings independently, deliver records and any substantiated changes to main, and clean task-owned resources.

## Implementation steps

- Read scoped Windows timeline, launch history, effective timeout configuration and protected report inventory.
- Audit native renderer/cache/profile paths and safely validate preserved binary cache structure.
- Determine whether isolated reproduction can test an actionable hypothesis; execute only off this PC.
- Review causal claims, preserve evidence and deliver the investigation outcome.

## Outcome

Pending. Explorer UserAssist identifies the primary platsim Mosslight.exe launch at 2026-11-07 21:37:25.940 PST, matching the empty log's timestamp. The Kernel-Power power-button timestamp is 21:40:18.534 PST. This supports the reported forced shutdown after the freeze; it does not identify the triggering subsystem.

Correction to work 4: the earlier LiveKernelReports/Windows Error Reporting directory searches suppressed access errors. Explicit checks now show those protected folders are inaccessible with the current non-administrator token. Their empty listings did not establish that no incident dump exists. The July minidump is genuinely readable and historical. A reviewed, read-only collection script is prepared at output/native-freeze/collect-protected-reports.ps1, with user approval pending for Windows elevation. No ACL or registry changes are proposed.

Successful earlier native logs identify desktop OpenGL 3.3 on NVIDIA RTX 4090 / 616.64, but also report shader-cache directory creation failure. Those runs did not exercise persistent cache loading. Existing AppData cache files were copied and hashed without modification: five files, 992,458 bytes and 22 opaque program binaries. Exact Godot-format offline parsing found no malformed lengths, truncation, trailing data or unexpected variant counts. This rejects gross cache-container corruption; it cannot validate NVIDIA shader machine code.

Native transparent cache targets allocate both RGBA8 and DEPTH24_STENCIL8 attachments, about 94.5 MiB for this map before other resources and driver overhead. This corrects any interpretation of the previous 47.3 MiB color-only estimate as total GPU memory. No render feedback cycle or obvious resource-lifetime violation was found. Native cache loading and per-executable NVIDIA profile association differ from the previous observer tests, but neither is a proven trigger.

Windows timeout settings currently explicitly set TdrDelay=30 and TdrDdiDelay=30 seconds, with recovery enabled (TdrLevel=3). Microsoft documents defaults of 2 and 5 seconds respectively. They remain unchanged. These settings can delay recovery; they do not establish why the GPU or desktop stopped progressing.
