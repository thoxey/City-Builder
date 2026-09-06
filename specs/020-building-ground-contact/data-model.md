# Data Model: Building Ground Contact

## Building ground treatment

Authored root field on each building definition:

- `ground_treatment`: `replace | grass_underlay`
- default: `replace`

BuildingCatalog includes the normalized value in its detached summary. Unknown values
fail content validation and normalize to `replace` only for runtime safety; release
validation must not silently accept them.

The field is not stored in `DataMap` or building registry records. Current catalogue data
plus the stable saved `building_id` derive treatment on load.

## GroundMap item policy

- `normal_grass`: existing grass item used for unoccupied cells.
- `grass_underlay`: same mesh/material with one declared negative vertical bias.
- `empty`: no GroundMap item beneath an occupant using `replace`.

Derived transition table:

| Cell state | GroundMap result |
|---|---|
| unoccupied | `normal_grass` |
| occupied by `replace` building | `empty` |
| occupied by `grass_underlay` building | `grass_underlay` |

Replacement resolves directly from the final occupant. Demolition resolves to
`normal_grass`.

## Ground-contact audit row

- `building_id`: stable catalogue ID
- `definition_path`
- `model_path`
- `model_hash_before`
- `model_hash_after`: optional until repaired
- `source_model_path`
- `source_hash_before`
- `source_hash_after`: optional until the final recapture
- `footprint_cells`
- `model_scale`, `model_offset`, `model_rotation_y`
- `overall_bounds`: projected X/Y/Z min/max
- `near_ground_bounds`: projected horizontal min/max at declared ground band
- `first_mesh_readable`: boolean
- `materials`, `texture_bindings`: integrity summary
- `rotation_results`: results/evidence for 0/90/180/270
- `status`: `pass | grass_underlay | transform | mesh_repair`
- `rationale`
- `before_evidence`, `after_evidence`
- `approved`: boolean

## Transform repair record

Existing upstream `game_transform` record:

- `model_scale`: uniform positive float
- `model_offset`: three finite floats
- `model_rotation_y`: finite degrees
- owning `asset_id` equal to stable building ID

The logical footprint remains unchanged.

## Mesh repair recipe

Only when required:

- `asset_id`
- `source_model_path`
- `source_hash`
- `tool_version`
- `operations`: ordered deterministic repair operations
- `material_policy`
- `first_mesh_policy`
- `output_path`
- `output_hash`
- `validation_evidence`

The recipe may be driven through Blender MCP or CLI, but its result and inputs must not
depend on interactive session state.
