# Build-menu image-generation prompt set

The masters were produced with the built-in image-generation workflow using the existing Community icon wall and the approved six-direction exploration board as visual references.

Shared production prompt:

> Individual high-resolution game UI master in approved exploration direction C: a rough-edged, rimless warm-parchment medallion; scratchy, gently irregular thick near-black ink; flat opaque muted spot colours; a broad joined silhouette; controlled asymmetry; economical internal detail; and at most three comic emphasis marks. Keep the subject completely contained, optically centred, and margin-safe. No baked text, letters, numbers, keys, labels, logos, watermark, signature, gradients, realistic lighting, soft shadows, photorealism, sterile vector geometry, thin outlines, excessive detail, or cropping. Use straight-alpha RGBA with a genuinely transparent exterior.

Zoning modifier:

> Residential primary mass is green `#58705A`; commercial primary mass is teal-blue `#2E8290`; industrial primary mass is orange `#C9743F`. Near-black ink `#171713` and parchment `#E7D3AD` remain constant. Colour supports meaning; silhouette must remain sufficient in grayscale.

Component modifier:

> Keep central content areas quiet. Concentrate character at corners or one small edge anchor. Maintain simple continuous edge runs for deterministic nine-slicing. Focus, disabled, and destructive overlays must communicate through brackets, hatch, or fracture geometry rather than hue alone.

Each asset's final subject motif, palette roles, reference IDs, and prompt-version identifier are recorded in `manifest.json`.

## Scalable component skin — built-in image generation

Shared component prompt:

> One standalone, front-facing game UI component in the selected clipped-ticket direction, using thick gently irregular ink `#171713`, quiet parchment `#E7D3AD`, flat muted palette accents, controlled asymmetry, and restrained print character. Preserve a genuinely transparent exterior and an empty centre for engine-rendered content. Keep corner and edge bands simple enough for deterministic nine-slicing. No icons, text, letters, numbers, keyboard symbols, prices, labels, charts, example content, gradients, gloss, soft shadows, photorealism, thin outlines, modern corporate styling, excessive ornament, watermark, or signature.

Exploration prompt:

> A landscape review sheet with exactly four separated component mini-families: clipped tickets, offset capsules, folded ledgers, and architectural brackets. Each family shows a status bar, dock, drawer, tooltip, modal, button, tabs, meter, scrollbar, and badge at a common apparent scale. Vary silhouettes, corners, edge rhythms, and tab connections materially. Use the approved icon wall only as a locked reference and the gameplay screenshot only for readability; do not redraw or alter the icons.

Asset modifiers:

- Large frames: quiet parchment fields, simple continuous edges, character only at headers, exposed corners, or attachment notches.
- Buttons and tabs: shared slice geometry; hover lifts, pressed lowers, selected gains a mustard structural outline, disabled gains interrupted hatch, and focus remains a separate transparent overlay.
- Radial overlays: sparse annular-sector edge treatments only; transparent centres; focus ticks, selected double arc, disabled hatch/broken arc, and destructive fracture.
- Meter: separate empty track, horizontal repeat fill, pennant-shaped warning marker, and inward-facing end caps.
- Dividers: separate horizontal, vertical, short ornamental, and section-header rules with quiet compatible middle runs.
- Scrollbar: separate vertical track, handle, cap pair, and empty arrow-button base; handle states retain three grip notches and use structural state differences.
- Badges: separate neutral side-notched disc, active lifted tab, and warning pointed shield, all with empty centres.
- Parchment: low-contrast two-axis seamless print grain with no focal mark; deterministic mirrored-quadrant repair supplies exact opposite edges.

The built-in image-generation workflow produced the exploration and primary raster sources. ImageMagick performed checkerboard removal, alpha cleanup, state alignment, repeat construction, runtime resizing, nine-slice assembly, and proof composition. Per-asset repairs are recorded in `manifest.json`.
