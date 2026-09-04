# Game UI asset taxonomy

Classify the requested object before choosing a canvas, generation prompt, or
export. One screen commonly combines several of these types.

## Fixed-size symbols

**Icons and glyphs** — inventory concepts, metrics, actions, status, warnings,
navigation, input prompts. Design at the smallest intended display size first;
retain a large master. Variants may be semantic rather than simple recolours.

**Badges, counters, pips, and markers** — compact overlays on another control.
Reserve a quiet centre or attachment edge. Test against the host component and
at worst-case digit counts.

**Cursors, reticles, pins, and map markers** — require a declared hotspot or
anchor. Provide normal/pressed/blocked variants and test over light, dark, and
busy scenes.

## Stateful controls

**Buttons, tabs, toggles, checkboxes, radio controls, dropdown arrows, scroll
handles, sliders, and steppers** need a state matrix. Typical rows are normal,
hover, pressed, focused, selected/checked, and disabled. Generate the base family
coherently, then assemble a labelled state sheet deterministically.

Focus is not the same as hover. It must remain visible when overlaid on normal or
pressed art. Do not represent disabled or selected state with colour alone.

## Resizable containers

**Panels, windows, menu backgrounds, dialogue boxes, tooltips, cards, buttons,
input fields, list rows, headers, and framed slots** should normally be nine-slice
or engine-drawn StyleBoxes. Preserve corners, allow edges to stretch or tile, and
keep the centre calm enough for arbitrary content and localisation.

Use fixed bitmaps only for intentionally fixed compositions such as a title card
or decorative splash.

## Repeating and modular art

**Tileable fills** — paper grain, subtle print noise, cloth, hatch, or ornamental
pattern. Require seamless opposite edges and a 3×3 proof. Keep contrast low under
text.

**Edge/corner sets** — modular frames, dividers, ribbons, borders, or map edges.
Provide inner/outer corners, horizontal/vertical edges, ends, junctions, and any
caps the layout can produce. Use a grid sheet only when every cell shares a
declared size.

**Progress and meter parts** — track, fill, cap, tick, marker, warning region,
and indeterminate animation. Separate fill from frame so value changes do not
distort decoration.

## Compound information graphics

**Maps, overlays, legends, charts, radial menus, wheels, and relationship lines**
combine engine geometry, labels, and art. Keep reusable art separate from dynamic
data. Prefer code for lines, fills, numerical labels, and changing regions; use
art for frames, pins, legends, masks, and texture accents.

## Illustrative UI

**Portraits, avatars, item art, empty states, tutorials, loading art, and quest
vignettes** can carry more detail and may not use the parchment disc. Preserve a
high-resolution master and define crop/focal-safe variants for every target
aspect ratio. Keep text out of the image.

## Decorative support

**Dividers, flourishes, corner ornaments, stamps, ink splats, tape, page curls,
and paper shadows** should be separate, reusable overlays. They provide character
without forcing every functional component to contain unique decoration.

## Decide what should not be an image

Prefer engine-native text, simple rules, flat fills, dynamic progress, selection
rectangles, and data-driven charts when artwork would obstruct scaling,
localisation, accessibility, or state changes. Combine those primitives with the
theme palette and a small number of illustrated assets.
