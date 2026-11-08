# Mosslight pixel art

The current scenery and building sprites are original integer-grid drawings authored in `scripts/pixel_assets.gd`. They do not sample or reduce the previous illustrated assets. The module builds each texture once and shares it for the lifetime of the process; there are no asset downloads or image-generation calls at runtime.

Building images use navy outlines, copper and amber machinery, jade plants and cyan glass/crystal. They contain only fully opaque color pixels and transparent background pixels. Their native sizes range from 20×36 for the work lantern to 40×36 for the generator; the renderer uses nearest sampling. Every sprite is bottom-aligned with transparent gutters. The seven kinds are a quilted camp cot, mushroom tray, breathing-fern planter, box work lantern, flywheel generator, glass dew tank and cut-crystal beacon.

The opaque 512×288 backdrop uses stepped silhouettes, flat color bands, sparse strata clusters and a narrow mineral-lit opening. Its distant arches and framing walls leave the center quiet for authoritative terrain and settlers. All traversable cave edges, resources, plants and characters remain drawn from gameplay state rather than baked into this backdrop.
