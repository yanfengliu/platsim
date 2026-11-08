# Review 2: implementation

## Target

Repository: platformer. On 2026-11-07, reviewed the one-line compact-menu label repair against the exact round-1 `main.gd` retained in the primary checkout's ignored `output/mosslight-motion/evidence/review-1/`, plus the four new Godot script UID sidecars. The worktree remains `C:/Users/38909/Documents/github/platformer/.worktrees/mosslight-motion`, based on `e97177b80dd7f5c0a3d727e692c0fcd988187e4a`.

The reviewed `main.gd` SHA256 was `75FD88FC217B7893BA978928CB8D73867B611E3C27544125403FF1E1CBECF177` at both start and end. Its sole delta from round 1 is line 378 assigning `_menu_button.text = "Menu"` at every window width instead of selecting the compact hamburger glyph. The other eight files covered by round 1 retain their recorded hashes. The integration owner was asked to retain the exact main file and UID sidecars under ignored `output/mosslight-motion/evidence/review-2/` before further source edits; that retention had not yet been verified when this report was authored.

| New sidecar | Content | SHA256 |
|---|---|---|
| `mosslight/scripts/presentation_motion.gd.uid` | `uid://73ij1ossrdks` | `72A2AAFEE94138EC374F331FF8E219787EE8099AACCAEAB5830CAB5D736A8242` |
| `mosslight/scripts/ui_settings.gd.uid` | `uid://c8n7up8e3ap04` | `89768F2287D0E5C9580F56532DCF0D98E3A3EDBA8D5CF27A2CCEF1D7A68024D2` |
| `mosslight/tests/presentation_motion_test.gd.uid` | `uid://b267pq7emgq2j` | `D97E4F6D35B49036621268D26CD75AEC2E83DDA316F8AF3CD83D695AC99A31C3` |
| `mosslight/tests/ui_settings_test.gd.uid` | `uid://xjjscwk3m0xl` | `AB48569F7A5F473DF6E2B1AFA1657EE3DFF3669748332DE499AD758B74D22F97` |

## Reviewers and coverage

Independent reviewer: `/root/motion_review`. Read the actual one-line diff, surrounding responsive-layout code, all nine script UID files for duplicate checking, and the four new sidecar files. Compared the nine round-1 source/documentation hashes to bound the incremental review. No other code changed within that scope. Capture fallback records are acceptance instrumentation and were outside this source review, as were generated asset import metadata.

The reviewer made no source edits and launched no GUI, game, browser, runtime tests or heavy gates. This new review record is the only reviewer-authored edit for the round.

## Reports

### /root/motion_review

**No actionable finding in the label repair.** Replacing the compact glyph with the existing ASCII `Menu` label removes that label's dependency on the unavailable glyph. The assignment changes display text only: it retains the existing button, pressed callback, Escape route, focus identity, tooltip and scale behavior. Responsive pause-label and spacing branches remain unchanged. The broader label can affect compact layout width, so actual 320px fitting and clickability require the integration owner's planned rendered recheck; source inspection alone does not accept that result.

**No actionable finding in the UID additions.** All four sidecars contain one well-formed `uid://` identifier, each has its corresponding GDScript file, and their identifiers are distinct from each other and from every existing script UID in the project. They follow the existing checked-in sidecar pattern and contain no runtime logic or environment-specific path.

F0 and F1 remain closed: neither the accumulator repair nor the shared resting predicate changed after round 1. No additional finding is assigned in this round.

## Findings and disposition

| ID | Finding | Disposition and reason | Repair or follow-up |
|---|---|---|---|
| F0 | Resume recreates a full-tick movement jump | Remains closed. Relevant production and helper bytes are unchanged from the accepted round-1 repair. | Integration runtime checks remain separate. |
| F1 | Ground-resting settlers lose their resting pose | Remains closed. Presentation and art bytes are unchanged from the accepted round-1 repair. | Integration rendered checks remain separate. |

## Verification

Read-only diff inspection established that the label assignment is the only change among the nine previously reviewed files. Raw hashes identify the exact main file and sidecars. A read-only check verified UID syntax, corresponding script existence and uniqueness across all nine script UID files. No runtime tests, visual checks or performance measurements were run by this reviewer. The integration owner's earlier viewport results predate this label change and are not presented as acceptance of its compact layout.

## Round outcome

Source recheck accepts the one-line label repair and four UID sidecars, with no new actionable finding. Exact target retention and the planned compact-HUD and scale visual rechecks remain integration responsibilities. This round makes no new frame-rate or rendered-layout acceptance claim.
