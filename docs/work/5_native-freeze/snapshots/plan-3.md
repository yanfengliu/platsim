# Investigate native Windows freeze without risking the workstation

Status: blocked
Owner: Codex integration owner
Created: 2026-11-07
Updated: 2026-11-08

## Problem and outcome

The owner requests the actual cause of the Windows freeze while explicitly avoiding another workstation crash. The cave appeared, the image froze, and the owner held the power button to restart. The earlier frame cap was only a load mitigation. Seek causal evidence through existing records, native implementation review and genuinely isolated reproduction; do not substitute a plausible hypothesis for a diagnosis.

## Scope

No native graphics workload, graphics-driver API probe, driver/settings change or stress test runs on this PC. Preserve shader caches and incident artifacts unchanged. Root owns Windows forensics and isolation options; native_backend_audit provided a bounded read-only review of exact Godot 4.7.2 Windows/GLES3 code and offline cache containers. The owner approved the scoped Windows administrator collector on November 8; collection completed. Raw reports remain local and ignored.

## Approach

Establish which executable was launched, compare successful observer runs with normal standalone initialization, inspect existing kernel/Windows error reports, validate cached shader containers without loading them, and map renderer allocations and native calls. See [the findings and source references](design.md). Use a fresh remote CI VM only if its test can narrow a live hypothesis; it cannot reproduce this NVIDIA hardware/driver combination with a software renderer. No connected remote machine or self-hosted repo runner is currently available.

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

The actual cause remains unconfirmed after protected-report collection and the available safe forensic checks. Further causal diagnosis is blocked on incident-specific evidence or a controlled reproduction on a separate matching GPU machine. No configured remote GPU machine is available, and local reproduction remains excluded by the owner's instructions. This is an evidence limitation, not pending administrator permission.

Explorer UserAssist identifies the primary platsim Mosslight.exe launch at 2026-11-07 21:37:25.940 PST, matching the empty log's timestamp. The Kernel-Power power-button timestamp is 21:40:18.534 PST. This supports the reported forced shutdown after the freeze; it does not identify the triggering subsystem.

Correction to work 4: the earlier LiveKernelReports/Windows Error Reporting directory searches suppressed access errors. Their empty listings did not establish that no incident dump exists. The November 8 approved administrator collection now examined those locations successfully, without changing ACLs or registry values. It found two historical dumps (January 2025 NDIS and July 2026 minidump), no incident-window dump, and 44 historical kernel WER reports totaling 1,067,418 bytes. Collection reported zero errors and zero budget skips; all copied sizes and hashes were verified. The newest report's EventTime is October 23, 2026 at 18:59:30 PDT, despite queue-file modification timestamps on November 8. None describes the Mosslight incident.

Successful earlier native logs identify desktop OpenGL 3.3 on NVIDIA RTX 4090 / 616.64, but also report shader-cache directory creation failure. Those runs did not exercise persistent cache loading. Existing AppData cache files were copied and hashed without modification: five files, 992,458 bytes and 22 opaque program binaries. Exact Godot-format offline parsing found no malformed lengths, truncation, trailing data or unexpected variant counts. This rules out malformed container lengths and truncation; it cannot validate NVIDIA shader machine code.

Native transparent cache targets allocate both RGBA8 and DEPTH24_STENCIL8 attachments, about 94.5 MiB for this map before other resources and driver overhead. This corrects any interpretation of the previous 47.3 MiB color-only estimate as total GPU memory. No render feedback cycle or obvious resource-lifetime violation was found. Native cache loading and per-executable NVIDIA profile association differ from the previous observer tests, but neither is a proven trigger.

Windows timeout settings currently explicitly set TdrDelay=30 and TdrDdiDelay=30 seconds, with recovery enabled (TdrLevel=3). Microsoft documents defaults of 2 and 5 seconds respectively. They remain unchanged. These settings can delay recovery; they do not establish why the GPU or desktop stopped progressing.

The collector's initial independent review requested bounded WER copying, wider incident-window inventory and preservation across retries. All three repairs passed static re-review ([round 0](reviews/0_implementation.md), [round 1](reviews/1_implementation.md)). The statically reviewed script SHA256 is 9b6712355a006a345b526d1126139f4263f40d76ad2aa11eb1bd72b32843d0c5. A separate claim check ([round 2](reviews/2_design.md)) requested narrower wording about cache corruption, which was corrected to container truncation. The owner then explicitly authorized execution; the same hashed script ran once with an administrator token on November 8, exited 0, and was cleaned up. Raw reports, cache copies, parser output and collector snapshots remain in ignored output/native-freeze for the unresolved investigation. No game or driver process was launched.

Additional checks found no incident record in the retained WER diagnostic channels, no configured full dump, no matching user crash dump, and no existing configured NVIDIA application dump folder. WHEA records in the scoped interval are recorded after reboot; the 952-byte error record has corrected severity, a valid but non-precise reporting timestamp at 21:41:28 PST, and no previous-error flag. It does not establish a pre-freeze hardware failure. Full report-folder metadata contains no Mosslight/Godot/dwm match and no folder created during or after the incident; the newest archive folder is November 6. These checks cannot prove that no evidence was ever generated, deleted, or stored elsewhere.

This checkpoint changes documentation only. The README-image hash, work-document structure and Git whitespace checks cover the records without launching Godot. Runtime suites are not rerun for these records. The collection and attribution receive independent review in [round 3](reviews/3_integration.md). No causal code fix, driver change, settings change, debugger installation or risky reproduction is justified by these records. Resume this same work unit if incident evidence or isolated matching GPU capacity becomes available.
