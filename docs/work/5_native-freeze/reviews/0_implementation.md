# Review 0: implementation

## Target

Base 9c1fe74778eff04b13030435263422a314bb7072, the first protected-report collector and draft work plan. Exact collector bytes remain in ignored output/native-freeze/review/collector-0.ps1 (SHA256 4577f064c3e14b6358e93231029ea30f3506178cf69fbce8257567c59094ba1a); reviewed authored plan bytes are retained in ../snapshots/plan-0.md (SHA256 ee4029d8667f7416d13c3279e7504f57580ac134017b2fb847ba8bc98ff4014c). The collector is a local evidence tool, not shipped game code. Its ignored originals remain required by the continuing investigation.

## Reviewers and coverage

GPT-6 Astra at xhigh, independent forensic_review agent. Static review of the collector, causal claims and local evidence; no collector, engine, driver or UAC execution. Reviewer's original findings F1/F2/F3 map to work-unit IDs F0/F1/F2 respectively; the authored wording below retains the original IDs. Only the response's memory-citation footer is omitted.

## Reports

### GPT-6 Astra

**Request changes before elevation: one blocking boundedness issue.**

Reviewed base `9c1fe74778eff04b13030435263422a314bb7072`, with exact preserved targets:

- Collector SHA256: `4577f064c3e14b6358e93231029ea30f3506178cf69fbce8257567c59094ba1a`
- Plan SHA256: `ee4029d8667f7416d13c3279e7504f57580ac134017b2fb847ba8bc98ff4014c`

**F1 — P2, blocking collector approval:** [collector line 39](C:/Users/38909/.codex/worktrees/platsim-mosslight/platsim/output/native-freeze/collect-protected-reports.ps1:39) copies every matching historical `Report.wer` without a byte limit, file-count limit, or incident-time restriction. The 512 MiB budget at lines 7 and 21 covers dumps only. This does not meet the requested bounded collection. Add explicit per-file and aggregate WER limits, recording skipped files and reasons; include WER bytes in the resulting inventory.

Two further limits should be addressed or explicitly retained:

- **F2 — diagnostic coverage:** [collector line 36](C:/Users/38909/.codex/worktrees/platsim-mosslight/platsim/output/native-freeze/collect-protected-reports.ps1:36) restricts WER to four kernel categories and three application-crash prefixes. Other categories, including application hangs, are neither collected nor inventoried. An empty result establishes only that this whitelist yielded nothing. Bounded incident-window folder metadata across categories would avoid assuming the triggering subsystem.
- **F3 — retry preservation:** [collector line 11](C:/Users/38909/.codex/worktrees/platsim-mosslight/platsim/output/native-freeze/collect-protected-reports.ps1:11) reuses a fixed destination; lines 23, 39, and 46 overwrite deterministic filenames. A retry can replace earlier collection evidence. Prefer a fresh run directory or refuse an existing destination. The destination presently does not exist, and inspected existing ancestors are ordinary directories, so this is not an observed redirected-write condition.

The script contains no graphics-driver probes, engine execution, network/upload operations, registry writes, ACL changes, or source-file mutation commands. Its PowerShell syntax parses without errors. `output/` is ignored at [.gitignore line 153](C:/Users/38909/.codex/worktrees/platsim-mosslight/platsim/.gitignore:153).

The plan correctly keeps the actual cause unconfirmed. Its launch timestamp agrees with [Explorer evidence line 20](C:/Users/38909/.codex/worktrees/platsim-mosslight/platsim/output/native-freeze/explorer-launch-history.json:20); independently converting [PowerButtonTimestamp line 259](C:/Users/38909/.codex/worktrees/platsim-mosslight/platsim/output/native-freeze/system-timeline.json:259) gives `2026-11-08T05:40:18.5337352Z`, matching the stated local time. The five cache inventory sizes sum to 992,458 bytes. The cache-format and native-allocation implementation claims remain the separate native audit’s responsibility; valid containers and finite attachments cannot prove GPU stability or causation.

I made no edits and did not run the collector, UAC, engines, browsers, or driver utilities. No task-owned persistent processes or artifacts were created.

## Findings and disposition

| ID | Finding | Disposition and reason | Repair or follow-up |
|---|---|---|---|
| F0 (author F1) | WER copying lacks a bound | Accepted; the dump budget does not limit WER. | Add per-file, count and aggregate limits; verify in round 1. |
| F1 (author F2) | Whitelisted categories leave incomplete evidence | Accepted; inventory every incident-window category and relevant historical hangs. | Widen bounded collection and retain explicit absence limits; round 1. |
| F2 (author F3) | A retry could overwrite evidence | Accepted; use a fresh timestamp/GUID directory and refuse reuse. | Preserve every collection separately; round 1. |

## Verification

PowerShell syntax parsing passed without execution. Evidence timestamp conversion and cache-size sum were checked independently. The collector was not dispatched. Native allocation and shader-format implementation details were assigned to the separate native audit.

## Round outcome

Changes required before elevation, with all three findings accepted. Actual cause remains unconfirmed. Independent static review does not authorize Windows elevation.
