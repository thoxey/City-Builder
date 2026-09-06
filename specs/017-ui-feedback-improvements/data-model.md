# Data Model: UI and Feedback Improvements

## Dialogue keyword occurrence

Transient presentation record:

- `keyword`: exact authored casing
- `quality`: `opportunity | liveability | beauty | belonging`
- `icon_path`: established runtime icon path, or empty when unavailable
- `start`: character offset in the authored string
- `length`: authored keyword length

The authored string remains authoritative; occurrences are never saved.

## Demand hover projection

- `bucket_id`: `residential | industrial | commercial`
- `display_name`: `Homes | Work | Shops`
- `current_available`: non-negative `DemandBucket.unserved`
- `lifetime_earned`: monotonic `DemandBucket.total_demand`
- `lifetime_targets`: ordered array of:
  - `building_id`
  - `display_name`
  - `threshold`
  - `reached`

## Authored held-building effect

Detached palette-entry record:

- `quality`: canonical Community quality
- `amount`: non-zero signed authored value
- `scope`: authored scope, or `city` for base Beauty
- `reason`: optional authored reason
- `source`: `attractiveness_base | community_effect`

The array explicitly excludes anchor/cell, affected residents/buildings,
neighbours, stacking, simulated application totals, and before/after values.

## Placement dock row

Transient presentation record:

- `kind`: `cash | demand | community`
- `icon_path`
- `label`
- `signed_value`
- `tooltip`
- `icon_available`

## Feedback animation

- `duration_seconds`: `3.2`
- `progress`: clamped `elapsed / duration` in `[0, 1]`
- `alpha`: `pow(1 - progress, 1.35)`
- `cleanup`: queue-free after the duration tween completes
