# Research: Buildable Area and Community Quality Playtest Pass

## Buildable-area authority and lifecycle

**Decision**: Keep `_allowed` in `BuildableArea` as the only gameplay authority and derive a presentation mesh from `allowed_cells()`.

**Rationale**: Builder already gates every footprint with `BuildableArea.is_allowed()`. `DataMap.allowed_cells` is only the persistence mirror. `map_loaded` and `buildable_area_expanded` already cover seed/load/donation lifecycle events.

**Alternative rejected**: Encoding boundary state into GroundMap would introduce a second map-shaped store and would entangle legality presentation with terrain population.

## Overlay geometry

**Decision**: Generate one 512×512 binary mask texture over a four-vertex ground plane. Each authoritative cell writes a transparent pixel; every other rendered ground cell remains white. Apply a perceptual 5% normal veil through an unshaded alpha shader. In Forward+'s linear framebuffer this uses alpha 0.0125, avoiding the excessive wash produced by a literal 0.05 linear blend over dark grass.

**Rationale**: The mask handles rectangles, overlaps, disjoint grants, and holes without generating roughly 262,000 cell quads. Depth testing and a small ground offset allow roads and buildings to remain visually dominant, while the sharp clear/veiled transition communicates the boundary.

**Alternative rejected**: A bounding rectangle cannot represent future non-rectangular donations; per-cell geometry across the entire ground would be unnecessarily large.

## Presentation emphasis

**Decision**: Treat both `radial` and `placement` player input modes as emphasized, rebuilding the same mask at perceptual 8% / linear alpha 0.02.

**Rationale**: Builder already emits a canonical mode transition, including the build menu's `radial` mode. No direct coupling to PlayerUI or Palette is needed.

## Initial camera framing

**Decision**: Change the normal starting zoom from 30 to 60 while retaining the
existing player-controlled 15–80 zoom range.

**Rationale**: At 1280×720, zooms below 60 leave at least one corner of the new
16×16 perimeter behind a HUD band. Zoom 60 is the smallest tested whole-boundary
framing; players can immediately zoom in once they have read the available land.

## Starting land

**Decision**: Change only `ROOTED_STARTER_RECT` from `(-7,-7,14,14)` to `(-8,-8,16,16)`; retain the legacy `STARTER_RECT` unchanged.

**Rationale**: This produces the requested 256-cell centred opening area without migrating historical non-rooted fixtures. The existing eastward patron donation (`x=8..19`, `z=-8..7`) then contributes 192 new cells to a rooted save and has no overlap with the 16×16 seed.

## Community audit

Current opening sources are:

| Source | Liveability | Beauty | Belonging | Reach |
|---|---:|---:|---:|---|
| Secure home | +20 | — | — | resident |
| Nature Patch | +4 | +6 | — | radius 2 |
| Duck Pond | +6 | +12 | +4 | radius 2 / participant |
| Small Commercial | — | — | +3 | participant |
| Town Hall | bustle −8/−4 | — | +2 | home route band / radius 3 |
| Garage | −7 noise | −4 visual | — | radius 1 |

The established fixed-seed 60-place town ends at Liveability 68.8143, Beauty 56.3298, and Belonging 50.4525. Liveability and Beauty respond materially; Belonging is positive but barely moves because its guaranteed civic source reaches only a small fraction of early homes and participant effects compete with work/activity assignment.

**Decision**: Strengthen only existing early civic/social effects: widen the unique Town Hall's belonging radius and raise its amount; modestly raise the generic local-shop encounter. Retain nature values, negative industry effects, the 50 baseline, the 0.1 hourly response rate, and the existing 1.0/0.5/0.25/0 stacking curve.

**Rationale**: Belonging becomes accessible through a unique non-spammable civic anchor and ordinary commerce while Liveability/Beauty already have strong positive sources. Existing garage/Town Hall negatives remain spatially understandable and recoverable. No easy cosmetic source is added, and repeated identical sources remain capped at 1.75×.

## Verification strategy

- Unit: seed bounds/counts, expansion overlap/idempotency, overlay geometry/style/lifecycle, evaluator positive/negative/stacking, exact persistence.
- Integration: fixed-seed mixed early town and matched poor layout, including full Community hour updates.
- Deterministic replay: run the established `first_town/rebalance` seed 6066 before and after and record quality deltas.
- Visual: capture normal and placement-emphasized frames at 1280×720, camera zoom 60, and inspect that the complete boundary is readable without covering city feedback.
