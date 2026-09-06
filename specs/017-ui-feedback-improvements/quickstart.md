# Quickstart: UI and Feedback Improvements

Run focused automated verification:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-ui-feedback-gut.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit/dialogue,res://test/unit/player_ui,res://test/unit/palette,res://test/unit/builder,res://test/unit/demand \
  -ginclude_subdirs -gexit
```

Run relevant integration verification:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-ui-feedback-integration.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/integration/player_ui,res://test/integration/dialogue \
  -ginclude_subdirs -gexit
```

Capture normal-renderer visual evidence:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --log-file /tmp/city-builder-ui-feedback-visual.log \
  --script res://scripts/capture_ui_feedback_validation.gd
```
