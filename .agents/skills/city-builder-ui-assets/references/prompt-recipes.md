# Prompt recipes

Use image generation for raster concepts and artwork. Use deterministic tooling
for resizing, alpha cleanup, slices, sheets, atlases, and metadata.

## Shared style block

> Vintage mid-century British comic-inspired game UI illustration; warm printed
> wit; thick, gently irregular near-black ink `#171713`; flat opaque muted spot
> colours from the project palette; bold joined asymmetric silhouette; dynamic
> pose or object lean; economical internal marks; at most two or three comic
> emphasis ticks at the active edge. No eyes or mouths by default. No text,
> letters, numbers, gradients, glossy effects, soft shadows, photorealism,
> watermark, or signature.

Describe the visual properties rather than asking to copy a specific artist,
publication, character, or existing illustration.

## Circular semantic icon

> Create one finished circular UI icon. Warm parchment disc `#E7D3AD`, genuinely
> transparent outside; generous even padding; near-black structural ink; flat
> semantic colours; readable at [minimum] px. The recurring noun keeps its locked
> colour and the modifier supplies the second colour. Concept: [motif].

Always specify the motif as visible shapes, not an abstract label alone. Preserve
the high-resolution result, then format runtime derivatives separately.

## Shape exploration sheet

> One clean concept sheet containing [6] separated alternatives for [asset]. All
> alternatives share the established palette, line weight, apparent scale, and
> neutral review background. Vary silhouette/metaphor/pose substantially. Place
> no production text inside the designs; optional review labels may sit outside
> each cell and will not be exported.

Use this for review only. Crop/redraw the selected direction as an individual
high-resolution master; do not ship cells cut directly from a low-resolution
exploration sheet.

## Nine-slice panel or menu background

> One front-facing rectangular UI panel source designed for nine-slice use in the
> established comic style. Preserve simple continuous corner shapes and straight
> or intentionally tileable edge bands. Keep the central content area quiet and
> low-contrast. Concentrate decoration at [header/top-left/corners]. No text and
> no content examples. Symmetric technical boundary even if the ink contour has
> controlled hand-made wobble.

After generation, rebuild/clean boundaries if needed, choose slice margins, and
test minimum, wide, and tall layouts. AI output alone is not proof of sliceability.

## Seamless paper or ornamental tile

> One square seamless tile of [paper grain/subtle hatch/ornament], matching the
> project parchment and print character. Opposite edges must join exactly in both
> axes. Low contrast suitable beneath UI text. No focal centre, isolated object,
> border, lighting gradient, shadow, text, watermark, or signature.

Test as a 3×3 repeat. Repair seams deterministically or regenerate; never claim a
tile is seamless from visual intuition at 1×1.

## Stateful button family

First define one base button and its nine-slice behaviour. Then request coherent
variations for normal, hover, pressed, focus overlay, disabled, and selected.
State differences should use structure: lift/depression, border, rays, offset,
pattern, or icon—not hue alone. Assemble the reviewed assets into a state sheet
with exact dimensions and metadata after generation.

## Portrait or empty-state illustration

Permit more line detail, pose, hair, and clothing, while keeping the same ink and
palette. Specify target aspect ratios, focal point, and crop-safe margins. Keep
all interface copy outside the bitmap.

## Revision prompt

State what must remain locked before the requested change:

> Preserve composition, silhouette, palette assignments, parchment treatment,
> line weight, padding, and transparency exactly. Change only [specific issue].

Use the previous image as a reference when editing. Avoid broad style restatement
that gives the model permission to redesign unrelated features.
