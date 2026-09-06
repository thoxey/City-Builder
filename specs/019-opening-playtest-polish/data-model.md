# Data Model: Opening Playtest Polish

## Filtered location row

Transient presentation record derived from the existing consequence quote:

- `kind`: `quality | attractiveness | affected | reach | invalid | replacement | access | uncertainty`
- `text`: existing human-readable row text
- `tone`: existing semantic colour key
- `icon`: existing icon slug
- `tooltip`: optional existing explanation
- `actionable`: true when the row is a warning even without a numeric change
- `semantic_delta`: optional unformatted numeric delta used to decide visibility

The row is not saved. Zero/change filtering occurs before any decimal or sign formatting.

## Tutorial road evidence

Existing evidence fields retain their schema:

- `rooted_road_cells`: stable ordered coordinates
- `rooted_road_count`: canonical RoadNetwork count
- `required_rooted_road_count`: projection constant `10`
- `receipt_id`: existing `opening.rooted_roads_connected`

An existing valid receipt remains authoritative even if its historical evidence count is
below ten.

## Adjacent-home observation

Persisted inside the existing tutorial experiment/receipt shape:

- `anchor_home`: first member of the deterministically selected pair
- `adjacent_home`: second member of the pair
- `baseline`: score evidence captured before the qualifying placement, or null
- `after_adjacency`: score evidence captured after placement, or null
- `adjacency_result`: existing
  `pending | penalty_observed | no_penalty | baseline_unavailable`
- `home_baselines`: ordered baseline records retained for every eligible home observed
  before a later qualifying placement
- pair ordering: lowest stable `(internal_id, anchor.x, anchor.z)` first

Each `home_baselines` row contains the observed `internal_id`, the detached `home`
record, its immutable `score`, and a stable `identity` made from `building_id`, anchor,
and ordered footprint coordinates. Builder may renumber runtime internal IDs during a
cold load, so the tutorial rebinds saved baseline rows to currently loaded homes by
that stable identity. When an upgraded incomplete save predates `home_baselines`, the
tutorial preserves its historical anchor baseline and samples only the missing eligible
homes at the load boundary, before the player's next placement; those migrated rows are
then persisted normally. Saved explanatory evidence is not rewritten. A demolished
home that is absent from the authoritative building registry is not a candidate, and a
later replacement records its own baseline rather than inheriting the removed home's
runtime identity.

Both homes must be eligible early residential buildings and have canonical footprint
distance at most one. At least one member must come from the newly observed placement for
a new causal observation.

## Primary direction

Detached Dashboard decision input/output:

- `source`: `opening_tutorial | first_quest | character | patron | fallback`
- `source_id`: stable tutorial, quest, character, or patron ID
- `phase`: active/pending/completed state from the owning projection
- `text`: owner-provided direction or existing Dashboard formatting result
- `priority`: deterministic internal ordering; not persisted

Dashboard does not own or save tutorial/quest progress.

## Unique unlock profiles

Existing `UniqueProfile` fields with changed authored values:

| Building ID | Bucket | Lifetime threshold | Other rules |
|---|---|---:|---|
| `building_postwar_terrace` | `residential` | 40 | unchanged |
| `building_pub` | `commercial` | 15 | unchanged |

## Palette-excluded building

Authored building field:

- `palette_excluded`: boolean, defaults to `false`

Runtime projection:

- BuildingCatalog retains the structure, stable ID, model, metadata, and summary.
- The detached summary includes `palette_excluded`.
- Palette omits excluded indices before entry/pool construction.
- Playtest choices inherit Palette membership and cannot select excluded content.
- Old saves may still resolve and operate on the catalogue item.

For this pass only `building_id = "grass"` sets `palette_excluded: true`.
