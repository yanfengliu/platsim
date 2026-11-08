# Historical Mosslight motion and digging

Status: complete
Owner: Codex
Created: 2026-11-07
Updated: 2026-11-07

## Problem and outcome

Retain the original authored records for smooth colony motion, scalable settings, terrain rendering and the first full digging strike. The complete status is the source plan's recorded historical status at platformer 53ae474700af2c17bc97da156a66b09e883f78a0; it does not certify the current correction or relocation.

## Scope

This unit preserves the committed docs/work/8_mosslight-motion population. The source plan and supporting documents are under historical/; all authored review rounds 0 through 6 remain under reviews/ in their original order. The uncommitted follow-up pose correction and its review belong to the separate current migration work unit.

## Approach

The new platsim allocation 1_mosslight-motion identifies an imported historical deliverable. Original platformer work ID 8 is provenance, not a platsim allocation. The supported importer records each retained file's exact SHA-256 and original repository, revision and path. The six-commit extracted history at a0fb07c25699fd25f313375dc3a9f11117bc16df holds the corresponding bytes under docs/history/8_mosslight-motion/.

Original commit IDs, source paths, CI links, output locations and acceptance limits remain unchanged in the historical documents. Refer to [the original plan](historical/plan.md) for their original meaning; current repository state and delivery are recorded in the new migration plan.

## Acceptance criteria

- Preserve every committed source file byte-for-byte, including all review findings and dispositions.
- Match each retained file to both the original source blob and the extracted-history blob.
- Keep the original complete status explicitly historical and preserve its original verification limits.

## Implementation steps

- Import the source population through the canonical importWorkUnit allocator with exact legacyFiles provenance.
- Carry this allocation and its retained bytes into the migration branch without changing source reports.
- Check the registered structure and byte mapping when the migration is integrated.

## Outcome

Historical source state: complete, as recorded in [historical/plan.md](historical/plan.md) at platformer 53ae474700af2c17bc97da156a66b09e883f78a0. This wrapper adds provenance and a repository-local allocation; it introduces no new gameplay acceptance claim. The retained review rounds apply only to their named historical targets. The original full history bundle and source evidence are retained outside platformer refs under platsim output/migration-backup.
