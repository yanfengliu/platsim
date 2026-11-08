# Pixel art, object scale and build menus

## Outcome

Original low-resolution pixel assets replace the painted scenery, terrain, props and settlers. A shared slate, jade and amber palette, hard texture sampling and square UI framing carry the new style; continuous movement and articulated digging retain their presentation clocks.

Buildings use real bottom-left anchored footprints: beds 2x1, generators/cisterns 2x2, beacons 2x3, lamps/airferns 1x2, and planters/ladder segments 1x1. Complete area validation, reservations, support protection, work access and cancellation use that geometry. Sprite dimensions and previews match it. The generator and planter move slightly within the starting hollow to keep the intended expansion sites clear; the tall beacon now fits beside the upper-roost beds.

Build opens Access, Furniture, Life support and Power, then the items in that category. Items show dimensions and material costs. A selected-item Change button returns to its category. Inspect, Dig and Cancel remain directly available; B opens Build, and permanent object shortcuts 2 through 9 are removed. Escape, pause and UI scaling remain available.

## Checks

All six Godot suites pass 1,552 checks: simulation 569, presentation 291, UI 403, terrain 62, digging 157 and pixel art 70. Simulation includes a full twenty-minute command-only win, every occupied cell, both foundation columns, refunds and invalidation during assignment, execution, completion and production. Pixel tests verify actual sprite fit and complete preview geometry across three zooms. The terrain test checks vegetation invalidation beneath both columns of a bed.

Real keyboard/mouse acceptance reaches every catalog item at 1280x800, 720x560 and 320x640. It verifies complete readable costs after keyboard-driven scrolling, overlap refusal, both protected support columns, cancellation from non-anchor cells, exact refunds, completed 2x2 construction and non-anchor inspection. Fixed, zoomed and panned screenshots cover the enlarged props and previews. The README uses an inspected 1440x900 capture of real construction and excavation; its source/image freshness gate passes.

The first rendered layout exposed clipped content at 720x560 and a 150% selected-item panel taller than its window. Changing to Cancel then moved the cave by 44 pixels beneath the pointer. Bounded catalog/detail scrolling and compact height budgets fix the cause. New geometry tests cover all eight items at compact sizes and 150%/200% scaling, long inspection text and exact stable desktop map bounds; a real same-coordinate click now cancels its intended blueprint. Independent review verified full-resolution repaired captures.

The final browser pass also completes title/help/settings checks at nine viewport widths, 150%/200% scaling, modal focus and pause preservation, and a twelve-pose horizontal dig followed by paused cancellation, Settings, requeue and completion at 3x. Its owned browser and localhost server are closed.

The first native 3x run exposed 25 active frame intervals over 16.7 ms (maximum 29.571 ms), despite a high average. Profiling traced repeated route searches to general footprint checks inside ladder detection. A direct 1x1 ladder query keeps positions, resources, jobs and 45,133 lookup results equivalent while reducing the worst instrumented simulation step from 26.942 to 8.779 ms. Seven new tests cover whole-world ladder equivalence and planned/canceled/completed/removed access. The failing native run remains preserved. The same native workload on the repaired build passes: 1x averages 206.36 rendered frames/s with a 9.268 ms maximum active interval; 3x averages 194.70 with a 13.987 ms maximum. None of the 2,785 active 1x frames or 2,411 active 3x frames exceeds 16.7 ms. Gameplay topology intervals are 9.116, 13.555, 11.482 and 7.463 ms. Moving/climbing samples and work clocks advance without duplicate active samples. Measurements use render-completion observation on Windows/RTX 4090 at 1280x800, with startup, deliberate pause and capture readback excluded; they do not certify monitor/compositor presentation or unmeasured wide/scaled native workloads.

Eighteen downward poses, including ten intermediate strikes, and two upward poses were inspected. The unchanged renderer also passes an isolated, clearly labeled production-art sleeping-bed fixture at normal and maximum game zoom. Its occupant fits the two-cell bed. Independent review 1 closes F0 (UTF-8 separator), F1 (layout overflow/pointer movement) and F2 (3x pathfinding spikes). All required local gates pass, including final README freshness/import. Git main and the retained delivery manifest identify the delivered revision and CI result.

## Evidence and limitations

Raw output is intentionally ignored. Retain the exact historical review targets, initial failed layout evidence, final browser scripts/captures, suite logs and native input/timing evidence with the playable delivery under the primary checkout's output/mosslight-pixel directory. Review 0 is historical pixel-only coverage; review 1 covers the expanded integrated target and its fixes. Neither historical target should be discarded merely because a later revision passes.

macOS export creation is not a Mac runtime test. There are no live-game saves in this prototype. The app-managed checkout remains linked to this chat; after delivery it is detached at the merged main revision and its task branch is removed.
