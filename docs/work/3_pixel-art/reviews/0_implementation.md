# Review 0: implementation

## Target

The uncommitted pixel-art conversion in `yanfengliu/platsim`, branch `codex/pixel-art`, over base `a8e879cf64373a790c2f0c039ad11bb9af559262`. The exact tracked delta is retained in ignored `output/pixel-review/0/tracked.patch` (SHA-256 `cef2e07756ddd7cd87a2d5d625ea5f45383f4983934adf5002ff0b73ad3142ac`); new files are copied under `output/pixel-review/0/untracked/`. `output/pixel-review/0/manifest.json` records every reviewed modified, deleted and new input, its byte size and SHA-256 (manifest SHA-256 `2f1b6f6c1b25a71b5218d00789fe9432496a7c2925aa93dc5f2ff6ce25aec997`). The review report itself is excluded from that target. Preserve these inputs until the integration owner binds the reviewed contents to a recoverable commit.

Scope: original scenery and building sprites, settlers, terrain primitives, renderer sampling and integration, UI framing, asset removal, the new pixel-art suite and its runner, README image and associated documentation. Acceptance for this target was the cohesive pixel style, preserved motion/digging/mechanics and controls, bounded caching, and a representative current README capture described in the work plan. The owner's subsequent request for realistic item scale and true multi-grid footprints expands the implementation after this snapshot; occupancy, placement, construction jobs and starting-layout changes for that request are outside this round.

## Reviewers and coverage

Codex independent reviewer, `gpt-6-astra` at `xhigh`, explicitly configured by the integration owner to the fleet pin. This reviewer read the actual worktree diff, all new game modules and the pixel-art test, relevant unchanged renderer, motion and digging code, the existing terrain/digging tests, build runner and CI workflow. It inspected supplied rendered images at original resolution and read the integration owner's gate logs. It made no source edits, Git mutations, runtime launches or browser/GUI launches; only the assigned review record and ignored review evidence were written. No second CLI lane was requested for this round.

Grounding outside changed hunks includes `mosslight/scripts/world_view.gd:180` (cache invalidation and view transforms) and `mosslight/tests/digging_animation_test.gd:350` (execution of the actual production artist across 48 poses in every direction). Source inspection and supplied acceptance evidence are distinct coverage; this reviewer did not independently replay the interactive scripts or rerun expensive runtime gates.

## Reports

### Codex independent reviewer

No actionable source defect found in the inspected target. The terrain, scenery, props and explorers are authored from integer-grid shapes rather than resized copies of the removed painting assets. The fixed palette, stepped cave silhouettes, jade growth and amber machinery read consistently in the full-resolution README image and colony captures. The square UI framing keeps text and controls readable at the sampled normal, compact and enlarged sizes.

Texture creation is bounded by the seven whitelisted building kinds plus one fixed 512 by 288 backdrop. Unsupported kinds return before cache insertion. Generation occurs only on cache misses; the painter uses shared textures afterward. The existing retained terrain invalidation and four-cell chunk structure remain intact, while all relevant texture consumers request nearest sampling. The new stroke and ellipse loops operate on bounded local artwork. Native GPU frame timing was not run before this round closed, so the practical frame budget remains unverified by this review.

Simulation, presentation motion, digging motion and UI settings have no source delta. The settler module still consumes the continuous presentation clock, directional rig, both articulated arm chains, shared pick geometry and timed debris. The real-artist digging test continues through `CaveArt.settler` into the replacement module, so this change has not silently bypassed that regression suite. Its geometry assertions establish rig consumption, not final raster appearance; rendered directional poses remain the separate visual check.

The 34 new checks cover reusable texture identity, dimensions, nonempty hard-alpha artwork, compact color counts, distinct image contents, unknown kinds, backdrop coverage and nearest sampling on world layers and terrain chunks. Different image hashes establish different contents, rather than proving distinct silhouettes by themselves; direct visual inspection supplies that part of acceptance. The existing motion, anatomy, lifecycle and cache suites remain necessary and were retained unchanged.

The README image is a real 1440 by 900 game view with current pixel terrain, all four settlers, readable resource/tool controls and active dig work. It is 155206 bytes, below the binary limit. The inspected freshness log matches its image/source manifest. No remaining runtime reference to the deleted illustration atlas/backdrop was found. The review's text-diff and new-file secret scan found no credential material; a broad scan's only match came from a Git binary patch encoding.

## Findings and disposition

No material findings identified in the frozen pixel-only target. The integration owner owns final dispositions and target-to-commit binding. Native frame pacing was not run and the horizontal interaction helper did not complete its final click sequence; neither is inferred to pass. The helper timeout has not established a product defect. The expanded footprint work requires a new numbered review of its actual integrated target.

## Verification

Read `output/pixel-checks/tests.log`: six suites, 898 checks, zero failures (simulation 277, motion 291, UI settings 77, terrain cache 62, digging 157, pixel art 34). The terrain log explicitly reports that autonomous viewport completion is unavailable under the headless dummy renderer; it does not establish GPU raster completion or frame pacing. Read the successful import, current-image check and web-build logs, and the Windows headless startup result (exit zero, no error output). Native export provenance hashes cover the same game files in this target. macOS export creation is not a macOS runtime test.

Personally inspected at original resolution: `docs/images/gameplay.jpg`; the 1280 by 800 and 320 by 640 colony views; the 200 percent colony view; the 1280 by 800 title; compact and 200 percent settings; and all twelve horizontal digging phases 00 through 11. These samples show the complete pick changing orientation, reaching the queued left rock face and returning while the actor braces; the cave and controls remain legible. The owner reports the nine-viewport title/settings and 150/200 percent real-input script passed; the first combined horizontal lifecycle run timed out in its click helper after producing its phase captures, so that run is not recorded as a completed interaction pass.

The reviewer ran `git diff --check`, compared untouched simulation/motion/settings files to the base, checked changed-file sizes, searched for deleted-asset references and inspected the patch/new-file secret scan. No whitespace error, changed runtime dependency on an old illustration, oversized retained input or relevant secret was found. The checkout has no `docs/learning/lessons.md` or `docs/policies/local-rules.md` to read; these absences predate this target.

## Round outcome

Closed on 2026-11-07 as a historical assessment of the preserved pixel-only snapshot after the owner expanded the task to realistic scale and true multi-grid footprints. No material source or sampled visual defect was found in this target. Native directional/GPU frame-pacing acceptance was not run, the horizontal helper's final interaction sequence remains incomplete, and final acceptance is not claimed. This report does not cover later source edits or the new footprint implementation. Retain the exact ignored patch and untracked-file copies until their contents are bound to a recoverable repository input; resume independent review in the next numbered round once the integrated source and evidence are ready.
