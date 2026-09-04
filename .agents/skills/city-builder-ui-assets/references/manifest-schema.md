# UI asset manifest schema

Use JSON unless the surrounding asset pipeline already has another canonical
format. Keep stable identifiers and paths machine-readable.

## Common fields

```json
{
  "id": "housing-capacity",
  "label": "Housing capacity",
  "family": "community-icons",
  "role": "semantic-icon",
  "motif": "green house containing an orange rising arrow",
  "source_path": "masters/housing-capacity.png",
  "source_dimensions": [1254, 1254],
  "runtime": [
    {"path": "game/housing-capacity.png", "dimensions": [128, 128]}
  ],
  "display_size_range": [16, 24],
  "colour_mode": "RGBA",
  "colour_space": "sRGB",
  "alpha": "straight",
  "background_rule": "opaque parchment disc; transparent exterior",
  "palette_roles": ["building", "capacity", "ink", "paper"],
  "accessibility_label": "Housing capacity",
  "approval": "approved"
}
```

## Conditional fields

- Stateful control: `state`, `fallback_state`, `component_id`.
- Nine-slice: `slice_margins`, `content_margins`, `minimum_dimensions`,
  `horizontal_mode`, `vertical_mode`, `draw_center`.
- Tileable: `tile_axes`, `tile_dimensions`, `seam_proof`, `repeat_mode`.
- Atlas member: `atlas_path`, `region`, `original_dimensions`, `trim_offset`,
  `pivot`, `rotated`, `padding`, `extrusion`.
- Cursor/marker: `hotspot` or `anchor` in source-pixel or normalised coordinates.
- Illustration: `aspect_ratio`, `focal_point`, `safe_region`, and crop variants.
- Generated art provenance: `prompt_version`, `reference_ids`, model/tool when
  useful, and the approved source revision. Do not place secrets or transient
  local URLs in manifests.

Coordinates must declare their origin and units. Slice margins use integer
pixels in left/top/right/bottom order. Normalised pivots use `[0,1]` coordinates.

The manifest should describe shipped truth, not every experimental output. Keep
rejected concepts in review material rather than the production manifest.
