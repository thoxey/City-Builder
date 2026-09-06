# Quickstart: Automated Opening Balance Playtest

From the repository root:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-opening-balance.log \
  -s scripts/run_opening_balance_playtest.gd
```

The command writes
`specs/014-opening-balance-playtest/validation/baseline-report.json` and exits non-zero
if any seed, bound, endpoint, or deterministic replay gate fails.

Focused tests:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-opening-agent-tests.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit/playtest -ginclude_subdirs -gexit
```

The baseline is ready for a later tuning pass when all runs succeed, primary replay is
stable, every wait is explained, and the report identifies the binding opening wait.
Compare later introductory Homes boosts of 0, 5, 10, 15, 20, and 25 against this frozen
baseline; do not change those values in this workstream.
