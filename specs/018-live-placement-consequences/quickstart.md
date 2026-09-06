# Quickstart: Live Placement Consequences

## Focused tests

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit/placement_consequences,res://test/integration/placement_consequences \
  -ginclude_subdirs -gexit
```

## Affected regression suites

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit/builder,res://test/unit/community,res://test/unit/player_ui,res://test/unit/attractiveness,res://test/integration/player_ui \
  -ginclude_subdirs -gexit
```

## Import check

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --quit --path .
```

## Manual review

At 1280×720 and 1920×1080, hold a nature patch, garage, home, road, and multi-cell building. Compare near/far homes, rotate, hover invalid land and replacement, cancel, then load a save. Confirm the location panel stays readable and distinct from intrinsic build details.
