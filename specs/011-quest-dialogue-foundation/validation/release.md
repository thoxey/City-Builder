# Release Validation

Validated on 2026-09-06 with a writable Godot `user://` location.

## Full regression

```text
Scripts: 107
Tests: 499/499 passing
Assertions: 3148
Time: 56.173 seconds
```

Command:

```text
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/city-builder-dialogue-full.log -s addons/gut/gut_cmdln.gd -gdir=res://test/unit,res://test/integration -ginclude_subdirs -gexit
```

The run retained existing test-fixture warnings and Godot orphan/RID/resource-exit
diagnostics but had no failed tests.

## Deterministic scenarios

```text
FIRST_PATRON_SCENARIO success=true actions=109 hours=1011 population=329 land=256 hash=84f468c06973514bd6ae51406858d84814c3192b257b3f1cd28464ce72df216a
FIRST_TOWN_LOOP success=true failures=0
```

The focused recovery and parity evidence confirms the dialogue event stays pending until
the ordered effects, arrival transition, and acknowledgement complete. Presentation can
remain disabled for deterministic headless traversal without changing those semantics.

Release disposition: **pass** for Feature 011. No genuine design blocker remains.
