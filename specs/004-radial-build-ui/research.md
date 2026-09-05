# Research: Radial Build UI and Player HUD

## Existing-state audit

- Most UI is created imperatively by plugins; `main.tscn` also contains legacy
  labels, a control legend, and an instruction texture.
- Palette owns the authoritative set of pooled/standalone build entries but
  currently exposes only affordable IDs and Q/E selection.
- Builder owns placement, rotation, demolition, overbuild confirmation, and
  Community inspect click routing.
- HUD, Community HUD, QuestDebug, Inbox, Dashboard, Palette, and DayNight each
  create independent CanvasLayers/anchors, producing overlap at 1280×720.
- QuestDebug is currently always loaded. RoadDebug is also always loaded.
  PluginManager only gates Playtest on `OS.is_debug_build()`.
- Building JSON supplies category/pool/cost, but the present categories are too
  coarse for a player menu and there is no stable icon/group/order metadata.
- Existing Community icons and the local UI asset guidance define a usable
  visual language and production pipeline.

## Decisions

### Use a toggle-open, two-level radial

**Decision**: Build button/B opens a category wheel; confirming opens an item
wheel; item confirmation closes into placement.

**Why**: Toggle-open works for pointer, keyboard, and gamepad, permits reading
locked reasons, and avoids timing-sensitive hold/release selection. Two levels
keep individual wheels below the eight-wedge legibility limit.

**Rejected**: One wheel containing every building (too dense); cascading linear
menus (does not meet the requested interaction); hold-and-release only (poor for
accessibility and locked-state explanation).

### Keep unavailable entries visible

**Decision**: Palette projects every entry with an availability state/reason.

**Why**: The current affordable-only list hides progression. The canonical
systems already decide cash, demand, prerequisites, and uniqueness; the UI
should expose their decision, not reproduce it.

### Author menu semantics in catalog data

**Decision**: Add `ui_group`, `ui_order`, and `ui_icon` to building or pool
definitions and validate them during catalog load.

**Why**: Existing `category=generic|unique` cannot distinguish homes, industry,
commerce, leisure, and story roles reliably. Guessing from plugin metadata would
couple presentation to simulation. Pool metadata owns the player-facing pooled
choice and overrides member UI metadata.

### Render radial geometry in Godot

**Decision**: Use a custom Control for wedges/hit testing plus ordinary Labels,
TextureRects, and focus StyleBoxes; use raster art only for icons/decorations.

**Why**: Geometry must respond to entry count, pagination, safe areas, input
angle, text scaling, and availability. A pre-painted wheel would be brittle and
would bake layout into art.

### Centralize shell/theme ownership

**Decision**: Add a PlayerUI plugin and reusable Theme. It composes top bar,
tool dock, and radial overlay while existing domain plugins provide data/actions.

**Why**: One layout owner can enforce safe regions and modal priority. Domain
plugins remain gameplay authorities.

### Gate developer plugins explicitly

**Decision**: PluginManager uses a development-only activation policy for
QuestDebug, RoadDebug, and Playtest. QuestDebug loses its player panel;
RoadDebug starts disabled even in debug builds and requires an explicit flag.

**Why**: `OS.is_debug_build()` alone would still show clutter in normal editor
play. Release must be inert, while intentional diagnostics remain available.

### Preserve transient UI state only in memory

**Decision**: Open level, page, hover, last group, and focus are not saved.

**Why**: They are convenience state and must not affect replay hashes or older
saves. Palette's stable selected ID remains runtime state as today.

## UI asset decisions

- New family: `build-menu`, made of fixed-size symbols rather than an atlas for
  the first pass. Profiling must justify any later atlas.
- Masters live under `art/ui/build-menu/masters/`; runtime PNGs under
  `sprites/ui/build-menu/`; manifest at `art/ui/build-menu/manifest.json`.
- Category/item masters are at least 4× their largest 72 px display target;
  runtime export is 256×256 RGBA. Compact copies may be 128×128.
- Actual-size proof includes 24, 32, 56, and 72 px on parchment plus 56 px over
  `specs/003-community-ui/validation/screenshots/overview.png`.
- Text, prices, counters, radial arcs, selection, and disabled hatching remain
  engine-rendered. No text is generated inside bitmap art.
- Controls need distinct normal, hover, pressed, focused, selected, and disabled
  treatment; focus cannot be a hover recolor.

## Open implementation checks

- Validate the best Custom Control drawing/hit-test approach in Godot 4.6 with a
  seven/eight-wedge prototype before producing the full icon set.
- Confirm default gamepad button names on the target controllers and present
  prompts through action names, not hard-coded glyphs.
- Measure whether the top bar needs a compact breakpoint below 1440 px after
  replacing the duplicate scene labels.
- Decide whether Q/E remains a placement convenience after usability testing;
  it must no longer be the only discovery path.

