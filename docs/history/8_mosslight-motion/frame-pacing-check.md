# Excavation frame-pacing reproduction

## Fixed workload and acceptance

Use the ordinary seed-42 main scene, full-resolution illustrated assets, 1280x800 native Compatibility rendering, and the retained engine-input workload in output/motion-native/input_fixture.gd. It starts 1x travel/climbing toward the shaft plug, switches to 3x and queues four adjacent digs, then pans/zooms and opens 150% Settings. Use the same wall-clock sample windows and capture exclusions as native-cache-final-analysis.json, including the actual 3x resume from 22.0 seconds. Report all eligible intervals above 16.7ms, terrain-hash correlations, p50/p95/p99/max, moving-position duplicates and pose-clock progression. Check a second camera view and enlarged UI. Preserve the original artwork with full-resolution captures and a title pixel comparison.

The requested target is smooth 60fps-or-better native rendering and animation. Passing averages alone is insufficient when the ordinary excavation workload still produces repeatable 23–68ms stalls. A cache optimization must eliminate those repeatable topology stalls without lowering fidelity or hiding work.

## Disqualifiers

Reject lower render resolution, missing geometry/decorations, changed simulation speed or job rules, fewer digs, skipped or shortened workload windows, exclusions that hide topology updates, fake movement or direct simulation mutation, browser-only performance evidence, stale export files, or a solution that moves the whole-cave cost into another recurring operation. Native OS delivery remains unverified because the automation bridge failed; the native benchmark is explicitly engine-input instrumentation, with separate real-input browser gates.

## Retained attempts

Original whole-cave redraw: four 63–68ms frames, all exactly coinciding with terrain-hash changes. Retained per-cell commands: actual geometry generation falls to five affected cells and title pixels match exactly, but the full render target still rerasterizes and produces 23.467/46.275/34.319/23.070ms topology frames. The revised 3x window also includes five early 18–26ms frames instead of hiding the resume interval. Raw traces, captures and immutable pack hashes are retained under output/motion-native; source snapshots are in primary output/mosslight-motion/evidence/review-1 and review-3.

## Accepted comparison

The final candidate retains per-cell commands in one shared World2D and renders only dirty 4x4-cell regions at the original 70 pixels per cell. Two-pixel guard bands preserve filtering and original outer-map clamping. One common snapped origin and Node2D patches avoid independent Control rounding seams. The final pack SHA256 is 61f8eadbaad15e34bc99a5dbae64954cf194c21f962c182c8f4b42cfa713aa04. The unchanged workload passes on the RTX 4090 at 1280x800: 1x/3x/wide/resumed-150% averages are 304.5/300.0/307.6/312.9fps; every measured active frame stays below 16.7ms, including all four topology changes (10.495/15.067/12.763/10.046ms). Moving-position duplicates are zero, and every eligible gait/work clock advances. The first three startup seconds and the specified screenshot-readback windows remain excluded; the initial 214.975ms cache build is retained explicitly in the raw trace. Title comparison differs in only 15 of 1,024,000 pixels by one RGB level. Final native title, excavation, climbing/work poses, fractional wide view and 150% Settings were inspected. No simulation rule, artwork resolution or workload was reduced.

Independent source review 4 closes the fractional-zoom seam finding on world_view.gd SHA256 bcfdab84778edb52f780f41573477ea26ed7ce10bc6b27d15eab0f11ab1a3f48. The 62-check production terrain gate covers CPU locality, regional scheduling, shared canvas, overhang/filter boundaries, layer order and resets; the prior whole-target raster approach fails all four GPU-locality assertions. native-regions-acceptance.json retains measurements, exclusions, hashes and zero-owned-process cleanup. These are render-completion intervals on the matching native engine running the unchanged export pack; standalone release OS input, compositor scanout and natural-cadence video remain outside this evidence.
