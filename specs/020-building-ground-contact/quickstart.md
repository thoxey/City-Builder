# Quickstart: Building Ground Contact

## 1. Freeze catalogue and model evidence

Run the model audit against every live BuildingCatalog definition before changing ground
treatment, transforms, or source assets. Preserve:

- stable building/model IDs and paths;
- source/runtime hashes;
- footprint and transform data;
- projected overall and near-ground bounds;
- first-mesh/material/texture integrity; and
- four-rotation normal-renderer contact sheets.

Write the inventory and review decisions under
`specs/020-building-ground-contact/validation/`.

## 2. Focused Godot verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-ground-contact-gut.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit/building_catalog,res://test/unit/builder,res://test/integration/builder,res://test/integration/save \
  -ginclude_subdirs -gexit
```

## 3. Model pipeline verification

Use the repository's configured Python environment for the existing model tools. Verify
upstream transform/repair inputs first, then run the wiring and packaging commands only
after the audit has frozen current hashes. Do not overwrite unrelated concurrent model or
building-data work.

If a mesh repair is required and no Blender MCP connection is available, use:

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
  --disable-autoexec --python tools/model_ground_contact/apply_repairs.py
```

The repair script/manifest must verify expected source hashes before writing outputs.

## 4. Lifecycle and deterministic verification

Exercise both `replace` and `grass_underlay` through preview, commit, four rotations,
replacement, demolition, save, clear, and load. Compare normalized gameplay snapshots and
hashes before/after; visual GroundMap state is the only intended difference.

## 5. Visual and performance review

Capture every failing asset before and after at 1280×720 and 1920×1080 with footprint
edges visible. Give the Town Hall dedicated close and town-context captures at 0° and 90°.
At minimum verify:

- no void or unfinished strip;
- no grass over roads, pavement, water, or hardstanding;
- no z-fighting or floating seam at camera zoom extremes;
- preview/commit/load visual parity; and
- no greater than 5% median regression in reference-town load, placement, or frame time.
