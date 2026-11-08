# Review 3: integration

## Target

Protected-report collection and its attribution, based on dc5393b4ab71fef3a9fa16175ae2c85507477839. Reviewed authored documents are preserved exactly in ../snapshots/plan-3.md, ../snapshots/design-3.md and ../snapshots/defect-register-3.md; their hashes appear in the authored report. Raw evidence remains ignored and local because diagnosis is unresolved. Original authored review SHA256 is 53461630133b33a57e8f11e0e94f3793126f28e300f89e6a1afc27e015bb2e4c.

## Reviewers and coverage

GPT-6 Astra at xhigh, independent forensic_review. Offline verification of all collected WER files, timestamp conversion, preservation hashes, collector bounds, saved folder/log/alternate-location evidence and updated documentation. No protected reads, live log queries, elevation, engines or graphics operations by the reviewer. Root performed the authorized collection and safe metadata/log queries. Authored report follows unchanged.

## Reports

### GPT-6 Astra

Independent forensic collection review, 2026-11-08, by forensic_review.

No blocking discrepancy was found in the observed collection, copy preservation, or report-event attribution. The collected evidence does not identify the November 7 freeze's cause.

The review started from repository HEAD dc5393b4ab71fef3a9fa16175ae2c85507477839. Evidence paths below are relative to C:/Users/38909/.codex/worktrees/platsim-mosslight/platsim/output/native-freeze. The collection directory is protected-reports/collection-20261108T203921149Z-b9f356c9. I read every one of its 44 copied .wer files and independently extracted EventTime, EventType and Sig[0].Value; EventTime was converted from the decimal Windows FILETIME value with DateTime.FromFileTimeUtc, rather than accepting the supplied summary's attribution.

| Reviewed artifact | SHA256 |
| --- | --- |
| administrator-collection-launch.json | 53a4fed5a2b057042f5e33b77dd6b28ed8bd1fef69c882ee48b31879c443fd6a |
| protected-reports/collection-20261108T203921149Z-b9f356c9/inventory.json | 871a059bd60da9f9f24649e979d34847ee9aca52e047d2fdaf104a95ca26820e |
| wer-summary.json | f266f57458fb6f6819df8131950a614c518b9626288a40b90848e878045a77df |
| wer-folder-metadata.json | 4b88b72b81f4595565c465e7f3c028ef130b82ee66c0f8300605f4c578801e2b |
| collect-protected-reports.ps1 | 9b6712355a006a345b526d1126139f4263f40d76ad2aa11eb1bd72b32843d0c5 |
| alternate-dump-locations.json | 4248f0e741e009f0a4b449d8ed7f903193b4ff1df210a837e9212158500b1a75 |
| vendor-app-dump-locations.json | e4f4d5804d29152c69be2eed8e15b73b7aadd7a271360ca5b8e91754e1aafcd8 |
| diagnostic-log-timeline.json | cce5cd375cc48509327d15856fb835f95fa71f0a223e1058f02839e555c5d6f5 |
| whea-record-header.json | ca09b772332a3d28d8747dc71365099bc8fde5ae614122f0a249ffeeaa3e24e5 |

The launch record at lines 2-8 records PID 2700, explicit approval, the exact reviewed collector hash, exit code 0, and execution from 2026-11-08T20:39:20.8204658Z to 20:39:21.9886056Z. Inventory lines 2-9 and 642-643 record administrator=true, 44 reports, 1,067,418 report bytes, zero copied dump bytes and an empty error list. I independently counted 44 .wer files totaling exactly 1,067,418 bytes. Every file has exactly one corresponding copied inventory entry; its current length equals the inventory size, and its SHA256 equals both the inventory and supplied summary. Every file contains exactly one EventTime field, and all 44 independently parsed timestamps, event types and codes match wer-summary.json. There are no failed comparisons, no recorded budget skips, and no unexpected files beyond the reports, inventory and completion marker. The largest report is 84,198 bytes, so all reports are below the 256 KiB per-file cap; count and aggregate size are also below the reviewed 64-report/8 MiB limits. The inventory contains 90 records: two dump metadata entries, 44 WER folders and their 44 reports.

The independent whole-report-set manifest SHA256 is b59e75525fdef7a89ae9da438fb78678db423e4b1d40d7efbf11d50371333158. Its input is UTF-8 text, sorted by filename using PowerShell Sort-Object file, with each line formed as filename, one space, decimal byte length, one space, lowercase file SHA256, then LF, including the final LF. Individual hashes remain recoverable from the hashed inventory. These comparisons establish preservation relative to the collection manifest; I did not reopen protected source files, and the collector records hashes of the copied files rather than separate pre-copy source hashes.

All 44 report EventTimes precede the incident. The earliest is 2025-01-13T05:25:44.8226677Z. The newest is report-3.wer, whose line 3 is EventTime=134372807708392348, converting to 2026-10-24T01:59:30.8392348Z, or October 23 at 18:59:30.8392348 PDT. Its SHA256 is 96e815ec59f0926387542be850c399c0549f6834a3ef3f2d8546c15973838c41. The review compares these times with the incident window November 7, 21:20-21:50 PST, equivalent to November 8, 05:20-05:50 UTC. The newer folder and file modification times cannot make these older events incident evidence.

| Recorded event type and raw code | Count |
| --- | ---: |
| LiveKernelEvent, 1b8 | 27 |
| LiveKernelEvent, 1a8 | 14 |
| LiveKernelEvent, 141 | 1 |
| LiveKernelEvent, 15e | 1 |
| BlueScreen, ef | 1 |

The historical code 141 report is report-43.wer, EventTime at line 3: 2026-03-15T20:04:28.1973788Z; its SHA256 is b2da2d3aca9466e1df50e929359737160956fa4f2e05f138b45e25e0fd02d997. The BlueScreen report is report-37.wer, EventTime at line 3: 2026-07-29T02:19:14.2482554Z, corresponding to July 28 locally; its SHA256 is 29da89f9e2774d42f6a6432cf5aebd9e2eed4afc4df3197e773b7b3d384ee087. Neither is evidence that the November incident produced that failure class. No Mosslight application-crash or application-hang record occurs among the 44 copied reports.

Inventory lines 11-24 list only two files under the recursively enumerated standard dump roots: C:/Windows/LiveKernelReports/NDIS-20250112-2125.dmp, 4,180,182,196 bytes, modified January 12, 2025; and C:/Windows/Minidump/072826-10812-01.dmp, 11,811,303 bytes, modified July 28, 2026. Both lie outside the incident window and were not copied. The old NDIS file being larger than 512 MiB does not explain the absence of an incident copy: its timestamp excluded it before the budget check. The July file's recorded CreationTime is in 2023, so LastWriteTime, its filename and the July WER event are the relevant historical attribution; CreationTime alone is not the crash time. Dump contents were not inspected by this review.

wer-folder-metadata.json lines 3-4 and 2509-2510 contain 500 ReportArchive folders and 44 ReportQueue folders. The integration owner supplied the acquisition command: each root was enumerated with Get-ChildItem -Directory -Force -ErrorAction Stop into an array, whose count and Name/CreationTime/LastWriteTime fields were emitted without a first-N cap. I checked every retained metadata entry but did not independently re-enumerate the protected roots. The newest archived-folder LastWriteTime is November 6 at 18:31:03 PST. All 44 queue folders have post-incident LastWriteTimes around November 8 at 08:01 PST, but their CreationTimes predate the incident, and their report EventTimes are historical. All 44 match the collector's Kernel_ category and were included despite falling outside the folder-time window. No selected metadata folder is missing from the inventory; none of the 44 were selected by incident-window timestamp alone.

The integration owner subsequently requested an offline spot-check of saved alternative-location checks. alternate-dump-locations.json lines 2-8 record CrashDumpEnabled=3, DumpFile=C:/WINDOWS/MEMORY.DMP, MinidumpDir=C:/WINDOWS/Minidump and no DedicatedDumpFile value. Lines 12-19 explicitly record PathNotFound for MEMORY.DMP and a completed current-user CrashDumps query with no matching files. The owner describes that match scope as Mosslight/Godot/dwm; the JSON does not embed the matching predicate, so this is not a claim that the directory has no files at all. vendor-app-dump-locations.json has eight NVIDIA application entries pointing to the same C:/ProgramData/NVIDIA Corporation/CrashDumps directory, each recording that the path does not exist. These snapshots address specific additional locations without changing the collection's source scope. I did not read the registry or those directories myself.

The saved diagnostic-log-timeline.json contains 12 Kernel-WHEA/Operational events and one Kernel-WHEA/Errors event, with empty error lists for both queries. Every retained event is after the recorded boot start at 21:41:22 PST; the earliest is 21:41:23.4776296. The Errors record at lines 105-113 is event 20 at 21:41:28.9597542 PST. I independently decoded its XML RawData hex: 952 bytes, CPER signature, terminating signature 0xffffffff, three sections, severity 2, valid bits 2, declared length 952 and header flags zero. Numeric timestamp byte components are century 20, year 26, month 11, day 8, hour 5, minute 41 and second 28, giving 2026-11-08T05:41:28Z. The timestamp-valid bit is set and the precise bit is clear. All these decoded fields match whea-record-header.json lines 4-12. The cited WHEA enumeration labels severity 2 corrected. This is a reporting timestamp after reboot with Precise=false, not proof of a hardware fault before the freeze or of its cause. I did not decode the individual error sections or independently re-fetch the linked Microsoft definitions.

The three retained WER diagnostic channel entries at diagnostic-log-timeline.json lines 119-145 each have an empty event list and an explicit NoMatchingEventsFound record, not an access-denied record. The integration owner identifies the query interval as November 7, 21:00-22:15 PST; that range is not embedded as a separate query-metadata object in this JSON. These saved query results cannot prove that no event ever existed outside the selected interval or channels. No live event-log query or additional research was performed by this reviewer.

The defensible absence statement is: at collection time, these two standard recursive dump roots yielded no incident-window dump, and none of the 44 collected WER reports describes an event in the incident window. The saved additional-location checks also yielded no incident artifact at their stated locations and matching scope. This is not evidence that no driver or hardware fault occurred, that the game is safe to rerun, or that no incident artifact exists anywhere. The collector itself does not cover all configured alternative paths, per-user WER/local-dump locations or other diagnostic stores; the later checks close only the specific gaps described above. Its WER selection generally excludes unrelated categories whose folder LastWriteTime falls outside the fixed window; no such recently modified folder appears in the retained metadata, but folder timestamps still are not EventTime. Deleted, rotated, unwritten or unflushed evidence is outside the collection's ability to establish. Historical kernel reports show prior events, not causation for this freeze.

I also checked the updated documentation against the reviewed evidence, including the change from pending approval to fulfilled collection and an unresolved diagnostic blocker. The following paths are repository-relative, rather than evidence-root-relative:

| Reviewed document | SHA256 |
| --- | --- |
| docs/work/5_native-freeze/plan.md | a84a6680009ea085d3c51359b0915928f91d30e145e7225b9b1a7b283fd01b5c |
| docs/work/5_native-freeze/design.md | 1f4581518dc878d7e05faec6df73a4d678bdf37ae52db76d1deddec03a87ebe7 |
| docs/learning/defect-register.md | e7cfc5ef6be5f70f353be563547c5b7c1d94945ec99980fc4b2ae1543bb19fe1 |

No blocking factual discrepancy was found in plan.md lines 37-53, design.md lines 33-49 or the protected-collection paragraph at defect-register.md line 13. Counts, timestamps, approval status, corrected WHEA severity with Precise=false, location-specific absence and the unknown cause agree with the evidence and stated acquisition scope. The record appropriately leaves work 5 blocked on causal evidence or separate matching-hardware reproduction; completing collection is not completing the diagnosis. This documentation spot-check does not independently revalidate earlier source audits, upstream issue histories, model attribution, live process cleanup, or the named content gates.

I did not query Windows event logs, research fault codes, access protected originals, run the collector or UAC, launch any engine or graphics tool, change settings, or upload evidence. The follow-up WHEA and alternative-location checks above used only saved local JSON. The only file written by this review is output/native-freeze/review/collection-review-3.md; all source evidence was read without modification.

## Findings and disposition

No new material finding. The independent review agrees that collection approval is fulfilled and that the available evidence does not establish the freeze's cause. Existing work-unit findings F0-F3 remain closed as recorded in earlier rounds; the unresolved causal diagnosis is not reclassified as a repaired defect.

## Verification

All 44 report sizes and preservation hashes match, and independent FILETIME conversion agrees for every report. None falls in the incident window. CPER header decoding independently agrees with corrected severity and a non-precise reporting timestamp after reboot. The owner additionally checked the current-user WER path (absent), verified the collector exited and found zero task-owned persistent game/browser/collector processes. Raw query limitations and missing evidence remain explicit. Documentation-only gates comprise README-image hashing, work-document structure, whitespace/content and secret checks; no runtime suite or native launch is warranted by this documentation-only checkpoint.

The default staged whitespace check flagged the preserved defect-register snapshot's CRLF line endings. Its exact bytes match the reviewed digest and must remain unchanged under the work-document preservation rule. A CRLF-aware Git check retains the ordinary trailing-space, blank-EOF and space-before-tab checks while recognizing CR as a line terminator; a separate line-content check confirms no trailing spaces or tabs. No snapshot renormalization or persistent Git configuration change was made.

## Round outcome

No blocking discrepancy in the collected facts or their stated limits. The records are suitable for integration. Work 5 remains blocked on causal incident evidence or a separate matching GPU reproduction, not on permission to collect existing reports. Neither collection success nor this review certifies the native build safe to run.
