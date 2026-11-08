# Review 4: implementation

## Target

Repository: platformer. On 2026-11-07, reviewed the regional terrain raster implementation and its display repair in `C:/Users/38909/Documents/github/platformer/.worktrees/mosslight-motion`, based on `e97177b80dd7f5c0a3d727e692c0fcd988187e4a`. This round covers shared-world region rendering, atlas guards and outer-edge clipping, dirty-region coverage, layer order, ownership, fractional-zoom display geometry, and the frozen expanded terrain suite.

The source that contained the seam finding is retained under the primary checkout's ignored `output/mosslight-motion/evidence/review-4-before/world_view.gd`, with raw SHA256 `75763FE9D11A6C1906B831A280C34E254F9D2E72D6E4478A522AD12E3979CBCD`. The integration owner reconstructed that file and the reviewer verified its exact hash and diff against the final target. It already includes the outer-map raster clipping correction. The repaired world view and frozen terrain test are retained under ignored `output/mosslight-motion/evidence/review-4-after/`; their copies match the working files. The unchanged runner and README remain recoverable from `evidence/review-3/`.

| Reviewed path | Final raw SHA256 |
|---|---|
| `mosslight/scripts/world_view.gd` | `BCFDAB84778EDB52F780F41573477EA26ED7CE10BC6B27D15EAB0F11AB1A3F48` |
| `mosslight/tests/terrain_cache_test.gd` | `E765FC92BCC05BAE9B11FF26FF89F29F2DAB08EBCCA8A754E63D3AD85ADD50A1` |
| `mosslight/tools/godot.mjs` | `C33116931953665B03C8F9A1C64E1D9F3FA8735732E4C82EECD5C46F2DE86D96` |
| `mosslight/README.md` | `B7C063773A0CD654E399EC4C016FF1362EC480A62D69CFD73B53DA865E660E88` |

## Reviewers and coverage

Independent reviewer: `/root/motion_review`. The first source pass found the independent-Control snapping defect before the repair froze. This final pass checked the repaired code and stable terrain test, including their differences from the retained prior versions. Official Godot documentation and the exact pinned Godot 4.7.2 source were consulted to establish shared-world, atlas-filtering and Control-render-transform behavior.

The reviewer did not read the terrain test while it was unstable. No source was edited and no game, browser, GUI, runtime tests, export jobs, heavy gates or performance measurements were launched by this reviewer. Only this authored review record was written. The reviewed source hashes stayed stable during the final frozen recheck.

## Reports

### /root/motion_review

**F2 — [P2] Separate TextureRect controls could open fractional-zoom seams.** In the retained before target, `world_view.gd:450-451` assigned each regional `TextureRect` a fractional screen position and width. Godot 4.7.2's `Control::_update_canvas_item_transform()` rounds each Control's rendered origin when GUI snapping is enabled, while `TextureRect` in scale mode draws using its unrounded size. At zoom 0.85, a four-cell region is 95.2 pixels wide, but adjacent snapped origins can be 96 pixels apart, leaving a 0.8-pixel gap; other boundaries overlap. Texture guard texels cannot fill geometry outside the display rectangle. This was a source-derived defect, not a claimed screenshot observation. The exact engine behavior is visible in [Godot 4.7.2 Control source](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/scene/gui/control.cpp) and [TextureRect source](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/scene/gui/texture_rect.cpp).

**F2 is closed in the final source.** `TerrainPatch` at `world_view.gd:17-21` is a `Node2D` that draws its atlas into a local rectangle. `_position_terrain_chunks()` at lines 451-459 moves the common `_terrain_surface` Control once and positions each patch relative to that common origin. GUI snapping therefore affects the shared origin only, matching the previous full-texture origin behavior, and no longer independently moves the region boundaries. Neighboring patches retain the same fractional coordinate system and do not change the global UI snapping setting. The test at `terrain_cache_test.gd:433-449` checks non-Control patch identity, common parent and coincident horizontal/vertical edges at zoom 0.55, 0.85, 1.12 and 2.5 with a fractional camera position.

**No additional actionable regional-rendering source defect found.** Regional viewports reference the same explicit `World2D` that contains the unique retained terrain painters. This sharing is supported by Godot's [viewport world documentation](https://docs.godotengine.org/en/stable/tutorials/rendering/viewports.html#worlds). Each regional viewport is attached to the tree before its canvas transform is assigned, and that transform maps the world-space raster origin to the regional texture origin. The master terrain viewport stays disabled and its old texture display stays hidden; the regional surface is inserted before air, infrastructure and dynamic layers.

Each core retains 70 source pixels per world tile. Interior raster rectangles include two guard pixels; clipping those rectangles to world bounds preserves the old full texture's outer-edge clamp behavior. Atlas crops display only each nonoverlapping core, with filtering permitted to sample the guard pixels. This matches the documented [AtlasTexture region and filter behavior](https://docs.godotengine.org/en/stable/classes/class_atlastexture.html). Patch displays retain the existing premultiplied-alpha material and inherit linear filtering. The art routines, shared rock-before-growth ordering and cell draw-list ownership are unchanged from the preceding source review.

The dirty footprint extends one cell to either side, one cell above, and through the two cells below each changed cell, covering the authored side outlines, floor growth and ceiling-vine overhangs. Regions outside map bounds are excluded. Initial construction marks every region, and subsequent requests remain confined to intersecting regions. A dimension reset detaches and queues deletion of old regional viewports and displays before rebuilding the domain. Same-clock reset invalidation from round 3 remains present. No additional accumulating node or resource lifetime defect was found.

**The expanded terrain suite checks the changed contracts.** The test preserves the existing retained-cell checks and replaces the obsolete single-full-viewport-size assertion with exact regional core coverage at the same 70 pixels per tile. It checks shared-world identity, complete single coverage without overlaps or holes, partial edge regions, atlas padding/crop coordinates, canvas transforms, bounded dirty-region and pixel counts, cross-region vine invalidation, the disabled master, camera-only reuse, fractional adjacency and retired-region cleanup. The optional legacy comparison measures the previous production raster request rather than substituting a copied implementation.

The test explicitly probes whether the renderer consumes `UPDATE_ONCE`. Only the headless dummy renderer may require manually acknowledging completion; production requests are inspected before that test-only acknowledgement. A native renderer failing the probe records a test failure. This preserves the distinction between testing scheduling and observing actual GPU completion. Trace art and headless state checks cannot establish final filtered pixels, absence of visible seams, or frame pacing.

The four-suite runner and README hashes are unchanged from round 3 and remain consistent with the added terrain suite. No new finding was identified in those files.

## Findings and disposition

| ID | Finding | Disposition and reason | Repair or follow-up |
|---|---|---|---|
| F0 | Resume recreates a full-tick movement jump | Remains closed; outside this incremental terrain change. | Prior accepted repair and integration checks remain applicable. |
| F1 | Ground-resting settlers lose their resting pose | Remains closed; outside this incremental terrain change. | Prior accepted repair and integration checks remain applicable. |
| F2 | Independent Control snapping opens regional texture seams | Closed by independent source recheck. Native Node2D patches now share one snapped origin and retain coincident fractional boundaries. | Exact repaired world/test hashes above; source regression checks four zoom levels. Native filtered-pixel acceptance remains separate. |

## Verification

Read-only source inspection, the exact before/after diff, engine-source lookup and raw hash checks established the defect mechanism and repaired behavior. The reviewer verified the retained before file and final world/test copies. The integration owner reports 61 passing terrain checks; this reviewer did not execute those checks or audit their logs. No runtime, visual or GPU result is inferred from that report. The before target and final target are distinct and both remain recoverable.

## Round outcome

Final source review accepts the regional cache and display repair at the exact hashes above, with F2 closed and no additional actionable source finding. This acceptance is distinct from native measurements of the previously observed topology hitches, filtered seam and art inspection at fractional zoom, final repository gates, exports and CI. Earlier authored rounds remain unchanged as historical records.
