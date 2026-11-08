# Review 1: implementation

## Target

Repair of F0/RS-1 and F1/RS-2 against base 530d053aac978db1ae2b0c3ffa0a6f1e8b4aa87c. Exact repaired files and hashes are retained under output/crash-diagnostics/review/repaired; the runtime test SHA256 is 0e27f10035e24d6e88b5f95c154c09452ab13e6d92657a60efc3626c7208888c. Code configuration and runner are unchanged from review 0. The monitored soak, process identity and prior invalid wrapper-only measurement are preserved with that target.

## Reviewers and coverage

GPT-6 Astra at xhigh, independent read-only follow-up by stability_review. Read repaired code, manifest and completed evidence. No engine or GUI launches, no mutations. The reviewer's optional CIM read was unavailable in its sandbox; root retained the scoped process identity for inspection.

## Reports

### GPT-6 Astra

Both findings are closed. No new blocking findings.

- **F0 / RS-1:** run-soak.ps1:4 now launches the actual engine directly, headlessly and hidden. Retained identity evidence identifies PID 29628, the correct executable and arguments, and no children. Its completed watchdog record reports exit 0, 77.3125 MiB peak private memory, and steady private memory decreasing from 75.421875 to 75.2890625 MiB.
- **F1 / RS-2:** runtime_stability_test.gd:99 now sums actual painter-array lengths; line 118 separately requires exactly two painters per cell. This matches the production construction loop at world_view.gd:414.
- **Scope wording:** The warm-up comment now accurately describes the exercised scales and modals.

The corrected soak completed 180.000 seconds, 10,800 frames and 180 simulation seconds, passing 534 checks with zero failures. Nodes, objects and orphan counts remained unchanged; tracked static memory increased by only 6,208 bytes. Stderr was empty.

All four current files match the repaired manifest, including test SHA-256 0e27f100... and watchdog c0baf330.... The invalid wrapper-only measurement remains separately preserved.

This closes the diagnostic acceptance blocker. Native GPU stability and the system-freeze cause remain unproven; the owner's final gates and delivery are separate. This follow-up was read-only and launched no engines or GUI processes.

## Findings and disposition

| ID | Finding | Disposition and reason | Repair or follow-up |
|---|---|---|---|
| F0 | Wrapper-only private-memory watchdog | Closed. Actual engine identity and useful private-memory samples verified. | Corrected 180-second bounded run and process cleanup passed. |
| F1 | Inferred painter count | Closed. Actual members are counted and each cell pair is checked. | Corrected regression and soak passed. |

## Verification

Exact repaired manifest matched. The corrected soak passed 534 checks, with empty stderr and exit 0. Measured memory and object counts stay bounded over the tested interval. This evidence does not measure GPU memory or certify native graphics startup. The integration owner's final suite/standalone-headless-export checks and delivery result are recorded in the plan.

## Round outcome

No remaining material review finding in the mitigation or diagnostic changes. The cause of the reported system freeze remains unresolved; it is not reclassified as a fixed defect.
