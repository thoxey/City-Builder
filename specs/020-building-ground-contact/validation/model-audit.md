# Catalogue Ground-Contact Audit

**Date**: 2026-09-06
**Catalogue source**: live `BuildingCatalog.get_summary()`
**Renderer**: Godot 4.6.2 Forward+ on Metal, macOS
**Coverage**: 31/31 live definitions, four rotations per definition
**Decision freeze**: completed before catalogue, Builder, transform, or model repair edits

Each model was rendered with Builder's first-mesh extraction, authored transform,
footprint auto-centring, and placement rotation over a high-contrast canonical footprint
guide. Programmatic overall and near-ground bounds, before/after runtime and
upstream-source hashes, material/texture bindings, and first-mesh readability are
recorded in `model-audit.json`. Bounds prioritized review but did not determine the
verdict.

The approved repair order was applied literally: visual pass, then footprint-matched
grass underlay, then whole-asset transform, then mesh repair. No asset is uniformly
undersized on both ground axes: every failing candidate already fills one axis or has
intentional asymmetric architecture. Consequently, no transform or Blender mesh repair
is justified by the pre-change audit.

## Mandatory Town Hall checkpoint

`building_town_hall` fails all four pre-change rotations. Its 2×2 model envelope spans
2.000 cells in one axis but only 1.100 cells in the other, leaving nearly half of the
declared depth untreated. Uniform scale would expand the full axis to about 3.64 cells.
The approved first repair is therefore `grass_underlay`, with dedicated post-change 0°
and 90° close/town-context evidence required before any other repair is batched.

Pre-change evidence: [Town Hall four-rotation sheet](contact-sheets/before/building_town_hall.png)

## Approved catalogue decisions

| Building ID | Footprint | Near-ground X×Z | Decision | Approved rationale | Evidence |
|---|---:|---:|---|---|---|
| `building_crazy_golf` | 1×1 | 1.000×1.000 | `pass` | Complete bordered course slab. | [sheet](contact-sheets/before/building_crazy_golf.png) |
| `building_duck_pond` | 1×1 | 1.000×1.000 | `pass` | Full opaque pond surround; grass must not bleed through water. | [sheet](contact-sheets/before/building_duck_pond.png) |
| `building_garage` | 1×1 | 1.000×0.880 | `grass_underlay` | Correct architecture/hardstanding, incomplete short-axis base; scale would overflow. | [sheet](contact-sheets/before/building_garage.png) |
| `building_lumber_mill` | 1×1 | 1.000×0.886 | `grass_underlay` | Centred fenced yard, incomplete short-axis base; scale would overflow. | [sheet](contact-sheets/before/building_lumber_mill.png) |
| `building_members_club` | 1×1 | 1.000×1.000 | `pass` | Complete hardstanding and curb slab. | [sheet](contact-sheets/before/building_members_club.png) |
| `building_nature_patch` | 1×1 | 1.000×0.999 | `pass` | Vegetated base is visually full-cell. | [sheet](contact-sheets/before/building_nature_patch.png) |
| `building_nightclub` | 1×1 | 1.000×0.625 | `grass_underlay` | Correctly sized terrace leaves broad depth bands; scale would overflow substantially. | [sheet](contact-sheets/before/building_nightclub.png) |
| `building_pipe_factory` | 1×1 | 0.992×0.997 | `pass` | Sub-percent bevel inset; concrete slab reads as complete. | [sheet](contact-sheets/before/building_pipe_factory.png) |
| `building_pirate_radio` | 1×1 | 1.000×0.930 | `grass_underlay` | Thin continuous short-axis strip; full axis rules out uniform scale. | [sheet](contact-sheets/before/building_pirate_radio.png) |
| `building_postwar_midblock` | 1×1 | 0.762×1.000 | `grass_underlay` | Broad exposed bands around centred block; scale would overflow. | [sheet](contact-sheets/before/building_postwar_midblock.png) |
| `building_postwar_terrace` | 1×1 | 1.000×0.998 | `pass` | Base reaches the footprint outline at visual tolerance. | [sheet](contact-sheets/before/building_postwar_terrace.png) |
| `building_postwar_tower_block` | 1×1 | 1.000×0.829 | `grass_underlay` | Grounded podium leaves a persistent short-axis strip. | [sheet](contact-sheets/before/building_postwar_tower_block.png) |
| `building_pub` | 1×1 | 0.872×0.989 | `grass_underlay` | Intentional asymmetric garden composition has an incomplete base; transform would damage it. | [sheet](contact-sheets/before/building_pub.png) |
| `building_restaurant` | 1×1 | 0.911×1.000 | `grass_underlay` | Grounded paved base leaves a repeatable edge band; scale would overflow. | [sheet](contact-sheets/before/building_restaurant.png) |
| `building_small_a` | 1×1 | 0.873×1.000 | `grass_underlay` | Correct house/garden scale with incomplete short-axis landscaping. | [sheet](contact-sheets/before/building_small_a.png) |
| `building_small_b` | 1×1 | 0.902×1.000 | `grass_underlay` | Correct shop/forecourt scale with a visible outer band. | [sheet](contact-sheets/before/building_small_b.png) |
| `building_small_c` | 2×2 | 2.000×1.757 | `grass_underlay` | Centred tower/podium leaves broad depth strips; scale would exceed two cells. | [sheet](contact-sheets/before/building_small_c.png) |
| `building_small_d` | 1×1 | 1.000×0.846 | `grass_underlay` | Walled landscaped base leaves a visible short-axis strip. | [sheet](contact-sheets/before/building_small_d.png) |
| `building_theatre` | 1×1 | 0.645×1.000 | `grass_underlay` | Correct theatre scale with broad exposed bands; scale would overflow. | [sheet](contact-sheets/before/building_theatre.png) |
| `building_town_hall` | 2×2 | 2.000×1.100 | `grass_underlay` | Mandatory failure; four-cell underlay is the only safe minimal treatment. | [sheet](contact-sheets/before/building_town_hall.png) |
| `building_windmill` | 1×1 | 1.000×0.907 | `grass_underlay` | Walled grass plot leaves a persistent edge strip; scale would overflow. | [sheet](contact-sheets/before/building_windmill.png) |
| `grass` | 1×1 | 1.000×1.000 | `pass` | Purpose-built grass plane fills the footprint exactly. | [sheet](contact-sheets/before/grass.png) |
| `grass_trees` | 1×1 | 0.998×1.000 | `pass` | Integrated terrain plate is visually full-cell. | [sheet](contact-sheets/before/grass_trees.png) |
| `grass_trees_tall` | 1×1 | 0.844×0.791 | `grass_underlay` | Ground plate is incomplete while elevated vegetation already spans the full overall axis. | [sheet](contact-sheets/before/grass_trees_tall.png) |
| `pavement` | 1×1 | 0.998×0.998 | `pass` | Full hardstanding; retain `replace`. | [sheet](contact-sheets/before/pavement.png) |
| `pavement_fountain` | 1×1 | 1.000×1.000 | `pass` | Full paved surround; retain `replace`. | [sheet](contact-sheets/before/pavement_fountain.png) |
| `road_corner` | 1×1 | 1.000×1.000 | `pass` | Full road/kerb plate; retain `replace`. | [sheet](contact-sheets/before/road_corner.png) |
| `road_intersection` | 1×1 | 1.000×1.000 | `pass` | Full intersection surface; retain `replace`. | [sheet](contact-sheets/before/road_intersection.png) |
| `road_split` | 1×1 | 1.000×1.000 | `pass` | Full split-road surface; retain `replace`. | [sheet](contact-sheets/before/road_split.png) |
| `road_straight` | 1×1 | 1.000×1.000 | `pass` | Full straight-road surface; retain `replace`. | [sheet](contact-sheets/before/road_straight.png) |
| `road_straight_lightposts` | 1×1 | 1.000×1.000 | `pass` | Full road surface beneath elevated light posts; retain `replace`. | [sheet](contact-sheets/before/road_straight_lightposts.png) |

## Audit totals

- `pass`: 15
- `grass_underlay`: 16
- `transform`: 0
- `mesh_repair`: 0
- readable non-empty first mesh: 31/31
- material present: 31/31
- texture bindings resolved: 31/31 (embedded for city-builder assets; intentional
  external `models/Textures/colormap.png` for the five road assets)

## Final post-change verification

The Town Hall checkpoint was implemented and approved before the remaining 15 authored
underlays were applied. Its dedicated real-Builder run covers preview and cold-loaded
placement at 0° and 90°, close and town-context zooms, and both 1280×720 and 1920×1080.
All 16 captures and all four GroundMap snapshots pass. The four occupied 2×2 cells use
the single depth-biased underlay item while surrounding roads, pavement, pond, and
hardstanding remain `replace`.

The settled catalogue was then recaptured at all four rotations. Three independent
visual reviews checked the before/after sheets at original resolution for exposed guide,
footprint overflow, hard-surface bleed, z-fighting, floating seams, and rotation
discontinuity. That review is an explicit 31-ID, four-rotation `after_review` record in
`audit-decisions.json`; capture code cannot infer a pass merely from the chosen repair.
Every repaired row passes:

| Building ID | Before | After verdict | Final evidence |
|---|---|---|---|
| `building_garage` | incomplete base | pass, 4/4 rotations | [before](contact-sheets/before/building_garage.png) · [after](contact-sheets/after/building_garage.png) |
| `building_lumber_mill` | incomplete base | pass, 4/4 rotations | [before](contact-sheets/before/building_lumber_mill.png) · [after](contact-sheets/after/building_lumber_mill.png) |
| `building_nightclub` | incomplete base | pass, 4/4 rotations | [before](contact-sheets/before/building_nightclub.png) · [after](contact-sheets/after/building_nightclub.png) |
| `building_pirate_radio` | incomplete base | pass, 4/4 rotations | [before](contact-sheets/before/building_pirate_radio.png) · [after](contact-sheets/after/building_pirate_radio.png) |
| `building_postwar_midblock` | incomplete base | pass, 4/4 rotations | [before](contact-sheets/before/building_postwar_midblock.png) · [after](contact-sheets/after/building_postwar_midblock.png) |
| `building_postwar_tower_block` | incomplete base | pass, 4/4 rotations | [before](contact-sheets/before/building_postwar_tower_block.png) · [after](contact-sheets/after/building_postwar_tower_block.png) |
| `building_pub` | incomplete base | pass, 4/4 rotations | [before](contact-sheets/before/building_pub.png) · [after](contact-sheets/after/building_pub.png) |
| `building_restaurant` | incomplete base | pass, 4/4 rotations | [before](contact-sheets/before/building_restaurant.png) · [after](contact-sheets/after/building_restaurant.png) |
| `building_small_a` | incomplete base | pass, 4/4 rotations | [before](contact-sheets/before/building_small_a.png) · [after](contact-sheets/after/building_small_a.png) |
| `building_small_b` | incomplete base | pass, 4/4 rotations | [before](contact-sheets/before/building_small_b.png) · [after](contact-sheets/after/building_small_b.png) |
| `building_small_c` | incomplete base | pass, 4/4 rotations | [before](contact-sheets/before/building_small_c.png) · [after](contact-sheets/after/building_small_c.png) |
| `building_small_d` | incomplete base | pass, 4/4 rotations | [before](contact-sheets/before/building_small_d.png) · [after](contact-sheets/after/building_small_d.png) |
| `building_theatre` | incomplete base | pass, 4/4 rotations | [before](contact-sheets/before/building_theatre.png) · [after](contact-sheets/after/building_theatre.png) |
| `building_town_hall` | incomplete 2×2 base | pass, 4/4 rotations | [before](contact-sheets/before/building_town_hall.png) · [after](contact-sheets/after/building_town_hall.png) |
| `building_windmill` | incomplete base | pass, 4/4 rotations | [before](contact-sheets/before/building_windmill.png) · [after](contact-sheets/after/building_windmill.png) |
| `grass_trees_tall` | incomplete base | pass, 4/4 rotations | [before](contact-sheets/before/grass_trees_tall.png) · [after](contact-sheets/after/grass_trees_tall.png) |

Additional repaired-only before and after sheets cover the production camera's exact
close/wide size limits (15.0 and 80.0) at both required resolutions. The eight sets are
`before-1280-close`, `before-1280-wide`, `before-1920-close`, `before-1920-wide`,
`after-1280-close`, `after-1280-wide`, `after-1920-close`, and `after-1920-wide`, with 16
sheets in each. The added high-resolution before evidence reconstructs the frozen
presentation by suppressing only the derived underlay; unchanged model, source, and
authored-transform hashes make that reconstruction reproducible without a catalogue edit.

The alignment harness uses the live Builder for preview and committed GridMap state,
saves with `ResourceSaver`, clears the map, reloads with
`ResourceLoader.CACHE_MODE_IGNORE`, and checks GridMap item, orientation, canonical
rotated footprint, GroundMap treatment, and transformed first-mesh bounds. All 64
repaired-asset/rotation rows pass at a 0.0001 tolerance.

The final machine-readable audit reports 31/31 entries captured with Forward+, all 124
rotation verdicts passing, readable non-empty first meshes and intact material/texture
bindings. Before/after runtime and upstream-source hashes are equal for all 31 entries.
No transform or mesh repair was needed.
