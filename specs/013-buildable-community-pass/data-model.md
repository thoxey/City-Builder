# Data Model: Buildable Area and Community Quality Playtest Pass

## Authoritative buildable mask

- Runtime owner: `BuildableArea._allowed: Dictionary[Vector2i, bool]`
- Persistence mirror: `DataMap.allowed_cells: Array[Vector2i]`
- Queries: `is_allowed`, `allowed_count`, `allowed_cells`
- Mutations: seed/load, `expand_rect`, and `apply_donation`
- Invariant: each coordinate occurs once in authority state; presentation never mutates the mask.

## Derived buildable presentation

- `normal_style`: perceptual 5% white overlay (0.0125 linear framebuffer alpha).
- `emphasized_style`: perceptual 8% white overlay (0.02 linear framebuffer alpha).
- `buildable_clear_cell_count`: authoritative cells represented by transparent mask pixels.
- `non_buildable_cell_count`: remaining cells in the finite 512×512 rendered terrain.
- `presentation_rect`: the rendered ground extent, not a placement-authority boundary.
- Lifecycle: refresh after `_load_or_seed`, successful `_expand`, and input-mode emphasis transitions.
- Persistence: none; always regenerated from authority state.

## Community balance records

Existing `CommunityEffectProfile` records remain unchanged in shape:

- `effect_id`
- `quality`
- `manifestation`
- `amount`
- `scope`
- `radius` / `schedule` / `capacity`
- `stacking_group`
- `reason`

This pass changes authored numeric values only. The evaluator continues to group independently by quality, stacking group, and sign, applying ordinal multipliers `[1.0, 0.5, 0.25, 0.0…]`.

## Persisted resident result

Each `CommunityResident` round-trips:

- `current_qualities`
- `target_qualities`
- `composite_happiness`
- existing identity/home/assignment/departure fields

`applied_effects` remains bounded transient diagnostic state and is recomputed
from the current authored sources after load.
