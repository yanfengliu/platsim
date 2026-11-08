# Move Mosslight to platsim and correct digging poses

Status: complete
Owner: Codex integration owner
Created: 2026-11-07
Updated: 2026-11-07

## Problem and outcome

The owner clarified that Mosslight belongs in yanfengliu/platsim and platformer is a different game. Move the project and its meaningful development history, finish the requested digging-pose correction, and rewrite platformer history to its clean Emberwake revision under the owner's explicit authorization.

## Scope

Preserve platsim's scaffold and fleet registration, the six Mosslight development and acceptance commits, exact historical work records, and the current uncommitted pose correction. Restore platformer to 54e0a270a65a5d92cd444e4ecbc4e23acbc83eac while preserving unrelated work. Retain recovery data outside platformer refs. The integration owner completes source, tooling, review, verification and delivery.

## Approach

Import only Mosslight project, workflow and historical documentation paths. Registered historical units 0_mosslight and 1_mosslight-motion retain exact committed source bytes and provenance. This unit owns current migration and pose-correction status; old completion claims remain historical.

The source worktree's uncommitted pose review is preserved exactly at [historical/7_implementation.md](historical/7_implementation.md), SHA-256 d5915bb6f2010b7a07ce96c92c41c2560f27c6f0a2534842374e6456ab1d2041. Its original numbering and source references are historical provenance. It has no committed source revision, and its coverage does not automatically transfer to the final imported revision. New final-revision reviews begin at reviews/0_implementation.md.

## Acceptance criteria

- Deliver the corrected Mosslight project in platsim with its six meaningful historical commits and no imported Emberwake code.
- Verify source/history mappings, required project gates and the requested behavior against the final revision.
- Restore platformer advertised main history to the clean revision using an exact force-with-lease after verified backups.
- Merge and push the final platsim work, follow CI, and clean only task-owned resources after retaining required evidence.

## Implementation steps

- Preserve original repository history, uncommitted correction files and required evidence.
- Integrate the extracted history, historical records, corrected source and platsim commands.
- Record independent source and migration review, then complete the required verification.
- Deliver both repository outcomes and document exact revisions, results and remaining limits.

## Outcome

Delivered implementation ce4950ed2aaab1b07113e5f603ab6bb32487e439 to platsim/main; [Mosslight CI](https://github.com/yanfengliu/platsim/actions/runs/42445061341) passed all 864 Godot checks. The six extracted historical commits are ancestors of that merge, and the independent migration review closes with no blockers. Final Windows, Mac and web builds plus verification evidence are retained under the primary platsim output directory; Windows headless startup passed, and Mac execution remains untested.

Restored platformer/main locally and remotely to 54e0a270a65a5d92cd444e4ecbc4e23acbc83eac with the exact expected-old-tip force-with-lease. Its 108 local tests and [Game checks CI](https://github.com/yanfengliu/platformer/actions/runs/42445149081) pass. All advertised refs are clean; git log --all for the misplaced Mosslight paths returns no commits after removing the task branch. The unrelated Emberwake files are unchanged. Recovery bundles, source patch, original artwork and evidence live in ignored platsim output, outside platformer refs. Existing hosting caches or old local reflogs are not claimed to be erased.

The old pose and verification worktrees and their branches were removed after verifying retained source and evidence. The old app checkout is clean at the restored revision; the app refused archiving it because another active chat still uses it, so it remains untouched after restoration. This chat belongs to the platsim project and keeps its managed platsim checkout. No task-owned browser, GUI or server remains. Temporary history-import storage was removed. The final record update changes documentation only; source and artifact hashes remain those accepted by review 0.
