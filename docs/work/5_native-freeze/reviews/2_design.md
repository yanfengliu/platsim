# Review 2: design

## Target

Base 9c1fe74778eff04b13030435263422a314bb7072 and the preliminary native investigation report, preserved exactly in ../snapshots/design-2.md with SHA256 4ec9262cf47b6ab5f2f3a1fe83b294d9f74e09f44f924a5fcccbc743ea48ddc2. Supporting native audit is retained in ignored output/native-freeze/review/native-audit.md, SHA256 752f6c35113ef112c36481caf68718078de5c2dfa4c01d3e6c108a5fb39a2c69.

## Reviewers and coverage

GPT-6 Astra at xhigh, independent forensic_review claim check against retained local evidence and the native_backend_audit report. This review verifies attribution and bounds of the claims, not native GPU stability. Author F4 maps to work-unit F3; original wording is preserved below. The report's introductory confirmation that earlier reports were saved is omitted.

## Reports

### GPT-6 Astra

Reviewed design SHA256 `4ec9262cf47b6ab5f2f3a1fe83b294d9f74e09f44f924a5fcccbc743ea48ddc2` against local evidence and native-audit SHA256 `752f6c35113ef112c36481caf68718078de5c2dfa4c01d3e6c108a5fb39a2c69`.

**F4 — minor factual wording correction:** [design.md line 17](C:/Users/38909/.codex/worktrees/platsim-mosslight/platsim/docs/work/5_native-freeze/design.md:17) says the checks exclude “gross corruption in the preserved files.” The parser establishes container bounds and structure; matching preservation hashes cannot exclude corruption already present within opaque payload bytes. Replace that phrase with **“container truncation”**, matching the native audit’s narrower conclusion. This does not block collection.

No other blocking findings within this bounded check. Cache counts and sizes match the retained JSON; all five preserved files independently match inventory hashes. The native log confirms the renderer identification and shader-cache-directory failure. Render-graph, attachment-allocation, and profile statements agree with the native audit. The design appropriately leaves the trigger unconfirmed.

I did not independently re-fetch upstream issue histories or verify remote-runner availability. Only the two requested report files were written; no collector, elevation, engine, or graphics operation ran.

## Findings and disposition

| ID | Finding | Disposition and reason | Repair or follow-up |
|---|---|---|---|
| F3 (author F4) | Container integrity does not establish payload integrity | Accepted; hashes of preserved input do not validate original opaque data. | Replace gross-corruption wording with container truncation in design and plan. |

## Verification

The owner preserved the reviewed design before editing and applied the requested wording exactly. The qualification that opaque binary semantics remain unvalidated is retained. Root's earlier primary-source reads support upstream issue history and runner availability; this reviewer did not independently verify them. No native execution was performed.

## Round outcome

The minor factual correction was applied. No material claim-review finding remains within the reviewed scope. Actual causation and protected incident evidence are still unavailable; the review does not authorize elevation or certify the executable safe to launch.
