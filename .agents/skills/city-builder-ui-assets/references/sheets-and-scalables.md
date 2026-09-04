# Sheets and scalable assets

## Exploration sheet

Use while choosing a direction. Show 4–12 clearly separated, labelled concepts
at a common apparent scale. Vary silhouette, pose, object metaphor, and emphasis;
do not present tiny colour changes as separate concepts. This is review material,
not a runtime atlas.

## Family or shape-language sheet

Shows a semantic family together—arrows, residents, buildings, warnings, tabs,
or corners—to detect drift. Use consistent cells and include actual-size insets.
The 52-icon contact sheet in `sprites/community_icons/review/` is this kind.

## State sheet

Columns usually represent normal, hover, pressed, focus, disabled, and selected;
rows represent components or sizes. Label the sheet for humans and keep a
machine-readable manifest for implementation. Ensure every state differs by
shape, position, border, pattern, or icon as well as colour.

## Component kit sheet

Presents panels, buttons, fields, tabs, slots, dividers, badges, meters, and
scroll parts at their intended relationships. Include slice guides, minimum
dimensions, content insets, and examples with short and long labels. This is the
best review sheet for a complete menu skin.

## Nine-slice / nine-patch source

A resizable component is divided into a 3×3 grid:

- four corners remain unchanged;
- top/bottom edges stretch or tile horizontally;
- left/right edges stretch or tile vertically;
- centre stretches, tiles, or is omitted.

Keep slice boundaries out of corner decoration and away from uneven line joins.
Make opposite edges compatible if tiling is desired. Record left, top, right,
and bottom margins plus the minimum safe control size. Test very wide, very tall,
and minimum-size instances with real text.

For this hand-inked style, tiling edges often preserves line weight better than
large stretching, but repeated motifs must not create an obvious machine rhythm.

## Tileable texture sheet

Deliver the base tile plus a 3×3 repeated proof. For directional textures, label
the repeat axis. A texture that only tiles horizontally is not a general 2D tile.
Avoid distinctive marks at the centre or seam that reveal the repetition.

For paper/noise under text, use subtle luminance variation and no hard high-
contrast flecks. Apply semantic colour and readable ink above the texture.

## Modular edge/corner sheet

Use a fixed grid for top/bottom/left/right edges, four outer corners, four inner
corners, caps, T-junctions, and crosses as needed. Provide a map from cell name to
region. Do not mix variable-size cells in a grid that assumes uniform slicing.

## Icon atlas

An atlas is a runtime optimisation, not the source of truth. Keep individual
masters and runtime PNGs; build the atlas deterministically. Use consistent cell
or region metadata, transparent padding, and edge extrusion where filtering can
sample neighbours. In Godot, `AtlasTexture.filter_clip` can help prevent region
bleeding, but atlas regions do not tile correctly in nodes such as `TextureRect`.
Keep tileables and nine-slices out of a general icon atlas unless the engine path
is explicitly tested.

Useful atlas layouts:

- **Uniform grid:** same-size icons or animation frames; easiest to slice.
- **Padded grid:** same logical cell with transparent optical padding.
- **Tight packed atlas:** variable rectangles plus JSON/engine metadata; smallest
  disk area but cannot be safely inferred by grid.
- **Animation strip:** ordered frames on one axis; use only for one coherent clip.
- **Multi-animation grid:** rows are named clips, columns are frames; record frame
  counts because not every row must be full.

Do not ask an image model to honour exact atlas cell order. Generate/refine the
art, then pack with deterministic tools.

## Handoff metadata

Every scalable or sheet asset should state:

- source and runtime paths;
- full dimensions and colour mode;
- cell size or named regions;
- padding/extrusion;
- pivot, hotspot, or anchor where relevant;
- nine-slice margins and content insets;
- tile axes and seamlessness proof;
- state names and fallback state;
- intended display-size range and scale behaviour.

## Reference sheets to maintain as the system grows

Do not create empty sheets pre-emptively, but add each when that asset family
enters production:

1. Palette sheet: named semantic colours, hex values, pairings, and accessible
   alternatives.
2. Shape-language sheet: silhouettes, ink weight, joins, corners, arrows,
   people, buildings, punctuation, and prohibited forms.
3. Approved asset wall: accepted assets with names and motifs.
4. Scale/optical-weight sheet: representative icons at every used display size.
5. Component anatomy sheet: button, tab, panel, tooltip, slot, meter, scrollbar,
   cursor, and marker construction.
6. Interaction-state matrix: normal, hover, pressed, focus, disabled, selected,
   warning/destructive where used.
7. Nine-slice specification sheet: slice margins, content insets, minimum size,
   and stretch/tile mode.
8. Tileability sheet: 3×3 proofs for every repeated fill, edge, and border.
9. Atlas/export sheet: regions, padding, extrusion, trim offsets, pivots, and
   metadata examples.
10. Context sheet: HUD, menu, inspector, tooltip, map, and noisy-world proofs.
11. Do/don't sheet: weak silhouettes, excess detail, wrong palette, baked text,
   realism, and other observed drift.
12. Accessibility proof: grayscale/colour-vision checks, contrast, focus, and
   redundant non-colour cues.
