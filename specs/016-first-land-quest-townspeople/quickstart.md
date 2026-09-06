# Quickstart: First Land Quest and Townspeople

## Current checkpoint

The feature is planned but intentionally not runnable yet. Complete and record the
creative approvals in `dialogue-workshop.md` before adding runtime quest/event/
townsperson data.

## Focused foundation baseline

From the repository root:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-first-land-foundation.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit/opening_tutorial,res://test/unit/dialogue,res://test/unit/event_system,res://test/unit/buildable_area,res://test/unit/character_system,res://test/integration/opening_tutorial,res://test/integration/dialogue,res://test/integration/progression \
  -ginclude_subdirs -gexit
```

## Post-implementation focused suite

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-first-land-tests.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit/first_land_quest,res://test/unit/opening_tutorial,res://test/unit/dialogue,res://test/unit/event_system,res://test/unit/buildable_area,res://test/unit/character_system,res://test/unit/playtest,res://test/integration/first_land_quest,res://test/integration/opening_tutorial,res://test/integration/dialogue,res://test/integration/progression \
  -ginclude_subdirs -gexit
```

## Full opening-to-land scenario

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-first-land-scenario.log \
  -s res://scripts/run_first_land_quest_scenario.gd
```

Run twice and compare semantic state/action hashes, pending IDs, approach flag, grant
receipt, added-cell set, four profile IDs, and completion receipt.

## Manifest/content audit

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . \
  --log-file /tmp/city-builder-first-land-manifest.log \
  --quit-after 300
```

Then run the established manifest exporter and confirm every runtime event beat/option
and townsperson identity is present in the workshop approval table, with no draft,
provisional, TODO, or unauthorized placeholder markers.

## In-game review

At 1280×720, 1920×1080, and 3840×2160:

1. Complete the opening shop with B18 unread, then with B18 already read.
2. Confirm the approved Sir William place is understandable before/within the scene.
3. Read Scene S1 naturally and verify expressions, acquaintance, choice clarity, and
   consequence.
4. Read S2/S3 and check that all four people have distinct wants, concessions, and
   tensions without sounding like stat labels.
5. Confirm the granted parcel is visually and mechanically legible immediately.
6. Save/reload before a choice, after agreement, after grant, and after completion.
