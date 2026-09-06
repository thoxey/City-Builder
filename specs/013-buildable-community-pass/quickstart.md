# Quickstart: Buildable Area and Community Quality Playtest Pass

Use Godot 4.6.x and a writable `user://` location.

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --quit --path .

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-013-unit.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit/buildable_area,res://test/unit/community \
  -ginclude_subdirs -gexit

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-013-integration.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/integration/community,res://test/integration/progression,res://test/integration/player_ui \
  -ginclude_subdirs -gexit

CITY_BUILDER_REBALANCE_EVIDENCE_PATH=res://specs/013-buildable-community-pass/validation/rebalance-after.json \
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-013-replay.log \
  -s res://scripts/run_town_rebalance.gd

/Applications/Godot.app/Contents/MacOS/Godot --path . \
  -s res://scripts/capture_buildable_area_validation.gd
```

Inspect both 1280×720 captures. At the camera's normal starting zoom of 60,
confirm the complete clear/white boundary is visible, the active veil is more prominent,
and roads/buildings/placement feedback remain legible.
