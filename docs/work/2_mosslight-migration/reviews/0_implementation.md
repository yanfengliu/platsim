# Review 0: implementation

## Target

Final imported Mosslight implementation and repository boundary in platsim, reviewed on 2026-11-07. The working tree combines the existing platsim scaffold at `9f11247067de4733f929663f3fe0ec98af0aa540` with the six-commit extracted history ending at `a0fb07c25699fd25f313375dc3a9f11117bc16df`, plus the reviewed pose correction, root package commands and registered documentation. At review time the merge is prepared, not committed or pushed; this report does not claim remote delivery.

The exact reviewed working-tree target is retained under the primary platsim checkout's ignored `output/migration-review/0/`: `reviewed-target.patch` applies to imported head a0fb07c, `untracked-target/` preserves new inputs, `source-target/` preserves key source/tooling bytes, and `target-manifest.json` records 80 existing tracked/new inputs. The patch SHA-256 is `f4628dac3ac223d55ffe0447d951c6b2593d12e285e3201ad055a589faa893b9`; the target-manifest SHA-256 is `7c31a0ead81893c0edaa846ebf6538319d95f5105591754bd1966b86590e56b6`. The report itself and later delivery-status edits are outside that snapshot. The imported base remains recoverable through the retained history and recovery bundle.

| Reviewed input | SHA-256 |
| --- | --- |
| `mosslight/scripts/digging_motion.gd` | `e8d415f6c5d39c69410a50ef3a56e97af257ac992111c258dbeb08284232f5a4` |
| `mosslight/scripts/cave_art.gd` | `52133ddc2c3e99658181739c684f7d706e57aee73462aa1008e616e9ee82fc42` |
| `mosslight/tests/digging_animation_test.gd` | `fb858215f0e0a49ef5cb7f5aeb34f0af52ee98148a85c806d708ca2078faa558` |
| `package.json` | `5e2f6acee8fe57c09d131ba048baf34fb49ca7963ecf77000ce5601848b60931` |
| `package-lock.json` | `0a94797d5bd33ace0e88c9c8f61835f93a3b6f3904808629a7aa5a4118c38ab8` |
| `.github/workflows/mosslight.yml` | `d0ec8f301954f0c854f7a3b2a0de75b316143d857cf59f78345c44bec0ac412a` |

## Reviewers and coverage

Codex independent reviewer using the fleet-pinned review configuration. This is a new review of the platsim target, not an edit to the historical source review. Read the actual new tree, full import-boundary diff, project/export configuration, both portable helpers, workflow, package and lock, current documentation and registry. Independently compared Git trees, metadata, file hashes and resource inventories. No subagents, second CLI reviewer, source changes, runtime/GPU/browser launches or test execution occurred on this lane. Other lanes' gate/export logs were read directly and are attributed as such.

The original pose report remains unchanged at `historical/7_implementation.md`, SHA-256 `d5915bb6f2010b7a07ce96c92c41c2560f27c6f0a2534842374e6456ab1d2041`. This reviewer authored that report after inspecting 35 images, then checked the imported files and final resource differences rather than assuming its coverage transferred.

## Reports

### Codex migration and exact-source review

No blocking migration or source defect found. All six original/imported commit pairs were independently compared by mode, path and blob ID after the documented `docs/work/7_mosslight` and `docs/work/8_mosslight-motion` to `docs/history` mapping. Their selected trees contain 35, 35, 55, 55, 61 and 61 files, with zero differences. Author identity, author timestamp and commit message match for each pair. The filtered history contains only the Mosslight project, its workflow and its authored work records; it does not import Emberwake source, tests, root package or existing workflow. Historical mentions of the original repository remain deliberate provenance.

All 21 registered historical files match their recorded SHA-256 values in `docs/work/registry.json`. The current wrappers distinguish their historical complete status from current migration acceptance, and `docs/work/.gitattributes` preserves exact historical bytes. The original platsim license, instruction files and fleet registration remain intact; README/package additions point at the dedicated game. Old authored reviews are neither renumbered internally nor rewritten as new approvals.

Of 41 current project/workflow files compared against the reviewed pose worktree, 39 are byte-identical. The two differences are the one-sentence repository-home correction in `mosslight/README.md` and EOF whitespace in `digging_motion.gd`. Removing trailing whitespace makes the helper text identical to the earlier c32f5b53 source. The artist and regression test retain their exact reviewed hashes. Consequently the prior arm/contact/lifecycle source assessment still applies to the actual imported implementation, with no gameplay change introduced by relocation.

The root commands in `package.json:10-16` all dispatch to Mosslight helpers. The new lock has only the root package and no dependency graph or install script. Node is pinned by `.nvmrc` to 24.12.0 and constrained to major 24 by the manifest. Outside the changed pose hunks, `mosslight/tools/godot.mjs:6-7` derives its project and repository from its own module URL, lines 64-101 stage exports beneath that repository and clean them in finally, and lines 105-107 run all five suites. `mosslight/tools/serve.mjs` derives the exported root in the same manner and binds to localhost. Keeping the mosslight/ directory preserves resource paths and export-preset output paths; no runtime/tool reference points back to platformer.

The imported CI workflow uses the new root .nvmrc, read-only repository permissions, the checksum-verified Godot 4.7.2 archive and the same repository-relative import/test commands (`.github/workflows/mosslight.yml:18-34`). Cleanup remains guarded and unconditional. CI performs import and all five suites; it does not claim native GPU acceptance or export every desktop target. Its first execution after the migration push remains the integration owner's delivery gate.

The retained platformer recovery bundle matches the recorded SHA-256 `350e63d6a24cf49c96902ed14205fe1e5aad662870d8156c6980aeef20e66dec`; `git bundle verify` succeeds and identifies complete history containing the pre-migration tip. The inspected clean-target-to-original-tip diff contains Mosslight paths and its README/ignore/devlog/defect/work-record additions, with no Emberwake runtime, test, package, existing CI or instruction change. The planned exact force-with-lease and delivery-before-rewrite sequence in design.md is consistent with preserving concurrent work. This review has not performed or certified the remote rewrite; the owner must still check the actual advertised tips and final result when executing it.

## Findings and disposition

No actionable source or migration finding. Initial read-only Git status attempts failed because the assigned platsim worktree is outside this agent's original Windows sandbox root. The same reads succeeded with the authorized sandbox escalation; no Git configuration was changed. This was a tool-access limitation, not an imported-repository defect.

The remaining delivery steps are integration work rather than hidden approvals: commit the reviewed merge and records, push platsim, follow CI, execute the authorized guarded platformer restoration, verify both remote results and retain required outputs before cleanup. Later source or workflow changes require review where they invalidate this target.

## Verification

Read the new platsim `output/migration-checks` logs: root npm import/check and web build succeed, and all 864 Godot checks pass (277 simulation, 291 presentation motion, 77 settings, 62 terrain, 157 digging). Read npm-ci evidence reporting one audited root package and zero vulnerabilities; the dependency-free manifest and lock agree. The prior 108 Emberwake tests are evidence for the separate platformer tree, not tests imported into or rerun as part of platsim's npm test. `git diff --check` passes for the reviewed tracked changes. No runtime tests were executed by this reviewer.

Inspected both the initial and final export resource comparisons and their scripts. The final web and Windows inventories each contain the same 31 resource paths as their corresponding reviewed candidate. In each pair 30 payload hashes match, including all seven compiled game scripts, textures, atlas and project configuration. The sole changed packed main scene differs at its generated root unique-ID bytes; its sole Control node, path, properties and script binding match. The scene dumps confirm that distinction. This establishes semantic resource equivalence for carrying the earlier rendered evidence forward; it does not establish identical PCK or executable bytes. Final Windows/web/Mac export manifests and the Windows headless smoke log are retained separately. Mac export success is not native Mac execution.

The prior rendered acceptance remains explicitly bounded: 18 downward native captures, two upward preparation/contact captures and twelve horizontal browser poses, plus three normal/compact gameplay views. Typical measured native timing exceeds 60 fps, but two of 2,148 included 3x frames exceed 16.7 ms: 17.986 ms and 19.980 ms. The 3x p99 is 11.364 ms; the 1x maximum is 14.923 ms. There is no every-frame 60 fps guarantee, OS-input/compositor certification, natural-cadence video, native Mac acceptance or browser-60fps claim. The current migration design preserves these limits.

No browser, GUI, server or watcher was launched by this reviewer. Reviewed source/evidence snapshots are intentionally retained. No source files, historical reports or shared Git settings were edited by this lane. The checkout has no docs/learning/lessons.md or docs/policies/local-rules.md, so no contents are attributed to those absent files.

## Round outcome

Closed with no blocking finding for the exact imported implementation and repository boundary described above. The current source, tooling and retained history satisfy the migration review criteria; remote delivery, post-push CI and the guarded platformer rewrite remain the integration owner's required completion checks. This report preserves the prior pose and performance qualifications and does not enlarge them.
