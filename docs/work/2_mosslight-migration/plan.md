# Move Mosslight to platsim and correct digging poses

Status: active
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

Integration and independent review are complete. Historical work units retain exact source bytes and provenance, all 864 Godot checks pass, final desktop/web exports pass, and final Windows startup succeeds. The reviewed candidate and migrated runtime resources are equivalent apart from generated scene identity. Remote delivery, post-push CI, guarded platformer restoration and final cleanup remain active.
