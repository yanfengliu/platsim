# Migration and pose acceptance

## Repository boundary and recovery

The owner explicitly selected `yanfengliu/platsim` as Mosslight's home, said platformer is a different game, and authorized rewriting platformer history to remove the misplaced simulation work. The chat project is now platsim and its managed checkout is C:/Users/38909/.codex/worktrees/platsim-mosslight/platsim. No new chat was created.

A verified full platformer Git bundle, the uncommitted correction patch/files, raw filtered history stream and exact source/import commit map are retained locally in the platsim primary checkout under ignored output/migration-backup. The clean platformer target is 54e0a270a65a5d92cd444e4ecbc4e23acbc83eac, preserving the latest concurrent fleet sync. The original remote tip is 53ae474700af2c17bc97da156a66b09e883f78a0. Independent history inspection finds no Emberwake source, tests, package, existing CI or instruction changes in the removed Mosslight portion. Updating remote main uses that exact expected tip as a force-with-lease guard and occurs only after platsim delivery is verified. No other remote branch is deleted or overwritten.

## Extracted development history

Native Git fast-export/import preserves the six meaningful Mosslight commits, their messages, authors and dates, while filtering out Emberwake ancestry and the fleet-only merge. Project paths retain the mosslight/ prefix, so Godot helpers and export presets keep their original repository-relative paths. The workflow is included; Node 24.12.0 is copied separately. Each filtered commit tree was independently compared by Git blob ID, with every selected file identical.

| Original platformer commit | Imported platsim commit | Verified files |
| --- | --- | ---: |
| 7d6b0daa11d42b183c6feb1f3181029e0ec50f4c | c75e39f0ad2fc6d91407db08c0d24e2247ab4936 | 35 |
| e97177b80dd7f5c0a3d727e692c0fcd988187e4a | 6e9df286d134540e112e9af3bd35d8e38c45307a | 35 |
| 8e6b2b46eda111a7f8542ea32841e6d4fa553927 | a8130bb39e66691ae70a70c1e0398b425a03673f | 55 |
| 8f3655a1b78d28f2288edbcc1969c9fda5175f0f | d1a1694704a4bf6be6bf5602f886389060b7ad21 | 55 |
| ff79ed1cfe2f222a2dc82b667396d07c81fdebeb | f7f9d9ec9f1ed53802758afccbfba0de73b2e71a | 61 |
| 53ae474700af2c17bc97da156a66b09e883f78a0 | a0fb07c25699fd25f313375dc3a9f11117bc16df | 61 |

Original work documents are initially mapped into docs/history in the extracted historical commits. The current tree imports them through the official work-document allocator into units 0_mosslight and 1_mosslight-motion, preserving exact bytes, review order, SHA256 and source provenance. Existing source plans/acceptance records reside under historical/ with current-format wrappers. Duplicate intermediate archive files are removed only after verifying every indexed Git blob is retained; checkout CRLF conversions are not mistaken for authored-byte changes. Current work2 preserves the uncommitted source review exactly and owns final migration status. Platsim's original scaffold, license and fleet block remain intact.

## Digging pose correction

The rejected Swing image revealed an independent art defect: tip/angle guidance could overextend the hands, while invented elbow offsets and unmirrored shoulders produced disconnected-looking sleeves. The new rig owns both shoulders, elbows and wrists with 0.36/0.35-tile arm segments; complete mirroring and separate sleeve/cuff strokes connect the figure to the two-handed shaft. A smaller pick, authored grip arcs and coordinated head/body poses keep the tool outside inflated face, hair and cap bounds. A smooth rear-shoulder lift prevents the hand crossing its shoulder socket. Impact direction, job timing, pause behavior and survival simulation stay unchanged.

The shipped helper fails all25 new anatomy checks. Three initial production candidates exposed head/recoil collisions and wrist/shoulder singularities; failed logs and source are retained. The hard-problem reproduction/disqualifiers were fixed before two independent branches. Both a grip-path detour and a shoulder-girdle pose passed the frozen checks. The chosen shoulder route preserves the already-verified body/head/tool trajectory; 24,008 off-grid phases and continuity intervals pass, with maximum joint step0.096463 below0.12, maximum reach0.629316 below0.69 and minimum head clearance1.036451. No assertion was relaxed. Four new actual-artist assertions verify complete shoulder-elbow-hand draw chains.

All864 Godot checks pass in the dedicated repository:277 simulation,291 motion,77 UI,62 terrain and157 digging. Root npm commands run import, those suites and the web export. The new dependency-free manifest/lock passes npm ci --ignore-scripts and npm audit --omit=dev --audit-level=high with zero vulnerabilities. Platformer's108 independent Emberwake tests also pass before restoration; no Emberwake runtime or test files are imported here.

## Rendered evidence and performance bounds

The reviewed candidate has18 native downward phase captures including10 intermediate strike poses, two actual upward job captures, and twelve horizontal browser poses. Real keyboard/mouse checks pass all nine UI widths, the1280x800/720x560/320x640 gameplay sizes, paused cancellation, Escape/Settings at150% and completion at3x. The independent reviewer inspected35 rendered images and found no blocking pose/source issue. Headless browser cleanup reports zero owned processes and console errors. The native input replay is through ordinary production controls and the unchanged export pack in the matching official engine; it does not mutate gameplay state.

RTX4090 native timing averages177.9fps at1x and174.1fps at3x; p99 intervals are10.125ms and11.364ms. Maximum intervals are14.923ms and19.980ms. Two of2,148 measured3x frames exceed16.7ms:17.986ms on a terrain-change frame and19.980ms later. They are retained explicitly, so this result is not an every-frame60fps guarantee. All eligible moving and work-clock pairs advance. OS-input delivery, compositor timing, natural-cadence video, native Mac execution and browser60fps remain outside the verified claims. The final migrated export identities and packed-resource comparison are recorded with delivery when complete.

## Final exported artifacts

Final Windows, web and Mac exports passed, with Windows SHA256 cc0dad5295c18719cefc8f727bd56ccf831fc7ca64f7a502529d0c5d166507d4, web PCK cc1015904b857ab29c6545ce766851aa6dc111713d39885c9a1aa3ce84176e4c and Mac ZIP 53e64fdbb16f51ff85c62bfcafdda7e04085f00206d82b8fd37854eae116c074. Final Windows headless startup exits normally with no errors. Both final Windows and web packs differ from their reviewed candidates only at four generated root scene ID bytes; all other thirty resources, all seven compiled scripts and decoded node properties match. This supports carrying the bounded candidate evidence forward, without claiming byte-identical artifacts or a new native timing run. The independent migration review in reviews/0_implementation.md closes with no blockers. All task-owned export processes exited.

## Delivered repository boundary

Implementation ce4950ed2aaab1b07113e5f603ab6bb32487e439 is on platsim/main with successful Mosslight CI run42445061341. Platformer main and all advertised refs now resolve to the clean54e0a270a65a5d92cd444e4ecbc4e23acbc83eac; its new Game checks run42445149081 passes. Local all-ref history no longer contains the Mosslight paths after task-branch cleanup. The complete pre-rewrite bundle and current source patch remain only as recovery evidence in ignored platsim output. No platformer force push beyond the explicitly authorized expected-tip update was made.
