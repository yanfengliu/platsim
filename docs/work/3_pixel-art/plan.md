# Replace illustrated art with a cohesive pixel world

Status: verified; Git delivery is identified by main and the retained delivery manifest
Owner: Codex integration owner
Created: 2026-11-07
Updated: 2026-11-07

## Problem and outcome

The owner finds the illustrated art too similar to another game and requests pixel art. Replace the visual vocabulary with original crisp pixel terrain, layered cave scenery, workshop buildings and readable settlers, while retaining smooth animation. The owner then requested believable furniture and equipment proportions and explicitly authorized real multi-grid footprints. The owner also requested tiered build menus because one permanent numbered button per object cannot scale.

## Scope

Change world art, palette and UI framing; remove the runtime dependency on the old generated paintings. Preserve digging anatomy, interpolation, camera controls, accessibility and resource rates. Beds occupy 2x1, generators and cisterns 2x2, beacons 2x3, and lamps and airferns 1x2; small planters and ladder segments remain 1x1. Placement, reservation, cancellation, foundation protection and inspection must cover the complete footprint. Refresh the README image and playable Windows/web builds. The integration owner handles terrain, renderer wiring, verification and delivery; bounded asset and character implementation lanes own separate modules. A simulation lane owns complete footprint validation and regression cases; a UI lane owns tiered menus and focus tests; the independent reviewer inspects the integrated result.

## Approach

Author compact pixel shapes and finite-color textures in repository-native Godot code. Use nearest texture sampling, pixel clusters and stepped edges rather than filtering the old art. Give the world blue-violet slate, jade vegetation and amber equipment. Cache generated textures and retained terrain commands. Keep UI text sharp at normal screen resolution and preserve scalable controls.

## Acceptance criteria

- Build opens categories, then a focused item list with sizes and costs; Dig and Cancel stay readily available, and all catalog items remain reachable at compact and enlarged UI sizes.
- Larger items visibly match their true occupied grid area, with full-footprint placement previews and no overlaps or floating supports.
- The rendered world clearly reads as cohesive pixel art, including scenery, terrain, resources, buildings and all settler states.
- Real keyboard/mouse digging, construction, pause, Escape settings and compact controls work; animation and cache regression suites stay green.
- The README shows the new style, image freshness checks pass, and source/assets remain within repository limits.
- Independent review, merged main, GitHub CI and task-owned process/output cleanup complete delivery.

## Implementation steps

- Create original pixel asset and settler modules while the owner replaces terrain and integrates the renderer.
- Inspect full-resolution gameplay, directional digging and compact/scaled interfaces; repair visible defects.
- Refresh README and builds, run gates and independent review, then merge and push.

## Outcome

Integration checks have reached 1,552 passing assertions across six suites (569 simulation, 291 motion, 403 UI, 62 terrain, 157 digging, 70 pixel art). One renderer and one test inference annotation were corrected during import. The first real-input pass reached every category/item at 1280, 720 and 320 pixels, completed a 2x2 generator, and checked complete blueprint cancellation/refund and support protection. Rendered checks caught unbounded vertical content at compact and enlarged sizes. The final layout bounds both catalog and detail scrolling, keeps every menu and footer on screen, and preserves exact desktop map coordinates across placement/cancellation. Independent review verified the repaired captures. The complete browser lifecycle passes. The repeated native Windows 1x/3x workload has zero active intervals above 16.7 ms (worst 9.268/13.987 ms), after a measured ladder-query regression was repaired. Independent review covers all fixes. Acceptance and limitations are recorded in acceptance.md; main and the retained delivery manifest identify the delivered revision and CI result.
