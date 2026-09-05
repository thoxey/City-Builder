# Family generation

Generate 6-10 coherent variants. Resolve the family before individual variants.

## Required family record

```yaml
family_id:
family_invariants:
  region:
  neighbourhood_family:
  use:
  typology_or_compatible_set:
  camera:
  sun_direction:
  scale_band:
  material_palette:
  stylisation:
  mesh_profile:
variant_axes:
variant_manifest:
unique_model_per_variant: true
```

Keep camera, sun, scale, palette, stylisation, base treatment and mesh budgets fixed. Vary only declared architecture: bays, storeys, attachment edge, primary material, restrained roof features, entrance, bay window or occupant expression.

Every variant is a unique model candidate. Do not count texture, colour, material or signage changes as sufficient variation. Each variant must differ geometrically in at least one declared axis, receive a unique `model_id`, and use a unique final model path.

Unless the request says otherwise, an eight-variant background family should contain five ordinary mid-street buildings, two restrained accents and one end/corner condition. Generate landmarks separately.

For a family sheet, arrange variants in a clean 4x2 grid with generous separation and no overlap. Keep every building at compatible apparent scale. Do not add labels inside the image because generated text is not an asset requirement; retain the manifest outside the image.

## Mesh-friendly limits

- One dominant mass plus at most two clearly separated projections for ordinary buildings.
- No foliage crossing façades or roof edges.
- Avoid hairline railings, wires, antennas and dense chimney forests.
- Awnings must not hide shopfront geometry.
- Utility details should be few, thick enough to read and attached cleanly.
- Windows and doors need unambiguous recess depth.
- Avoid transparent glazing that reveals complex interiors.
