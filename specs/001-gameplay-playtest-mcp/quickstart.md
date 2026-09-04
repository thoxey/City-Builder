# Quickstart: Validate the Gameplay Playtest MCP

This guide is the end-to-end acceptance path after implementation. It proves the
bridge and deterministic play loop; it does not tune balance values itself.

## Prerequisites

- Godot 4.6.x installed at the configured project path.
- The project open in Godot with the Godot MCP editor plugin enabled.
- Node dependencies already installed in `server/`.
- Godot's `user://` location writable for fixtures and optional traces.
- MCP client restarted after the `city-playtest` entry is built/configured.

## Build and Test

From the repository root:

```bash
cd server
npm run build
npm test
```

Run the GUT suite with recursive unit discovery:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path . \
  --log-file /tmp/city-builder-gut.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit \
  -ginclude_subdirs \
  -gexit
```

Expected: all MCP contract, Builder parity, clock, and Playtest tests pass. If
catalog fixtures cannot write under `user://`, rerun outside the restricted
workspace sandbox before interpreting those failures as code regressions.

## Connect the Two MCP Surfaces

The project should retain the general Godot MCP and add the small playtest MCP:

```json
{
  "mcpServers": {
    "godot-mcp-pro": {
      "command": "node",
      "args": ["/absolute/project/path/server/build/index.js"]
    },
    "city-playtest": {
      "command": "node",
      "args": ["/absolute/project/path/server/build/playtest-index.js"]
    }
  }
}
```

Reconnect the MCP client. Use the general Godot MCP to run the main project and
inspect debug output. Use only `city-playtest` for semantic gameplay actions.

## Smoke Scenario

1. Call `playtest_start` with `scenario_id: fresh_city` and `seed: 1`.
2. Confirm the returned session is `ready`, sequence is `0`, no structures are
   present, and the starting resource values match authored defaults.
3. Call `playtest_get_choices`; select an available residential tier-one choice.
4. Call `playtest_place` at a valid starter cell with request `place-001`.
5. Confirm status `applied`, the concrete pooled variant is recorded, the
   building appears in the snapshot, and the appropriate fulfilled demand moves.
6. Call `playtest_advance` for 24 hours with request `advance-001`.
7. Confirm exactly 24 hourly updates, simulation day rollover, and coherent
   downstream population/demand/economy values.
8. Call `playtest_demolish` on any footprint cell with request `demolish-001`.
9. Confirm the building disappears and fulfilled demand is recalculated.

## Rejection and Idempotency Checks

- Place outside the starter mask: expect `outside_buildable_area` and unchanged
  state hash.
- Place on occupied land with replacement disabled: expect
  `occupied_footprint` or `replacement_required` and unchanged state hash.
- Retry the exact successful request id: expect `duplicate`, the original
  sequence/result, and no second building.
- Send a stale `expected_sequence`: expect `sequence_conflict` and no mutation.
- Advance `-1` or `1001` hours: expect `invalid_hours` and no emitted hour.

## Deterministic Replay Check

Run `early_city_baseline` ten times using the same seed and action list. Compare
normalized final snapshots and milestone hours.

Expected:

- all balance-relevant state hashes match;
- pooled variants match;
- hourly update counts match;
- wall-clock timestamps/durations may differ and are ignored.

Then run the scenario over a declared small seed set to ensure random variation
is intentional and traceable rather than timing-dependent.

## Human Review Checkpoints

Use the general Godot MCP screenshot capability at these milestones:

- fresh city;
- first positive industrial output/tax income;
- first tier-two unlock;
- first meaningful starter-land pressure.

Review whether the automated strategy still produces a legible, plausible city.
State metrics establish reproducibility; they do not replace visual play feel.

## Ready for Balance Iteration When

- all checks above pass;
- 20 consecutive scenario runs require no manual input;
- gameplay rejections are fully classified;
- UI versus playtest parity is proven;
- an unchanged baseline trace is stored before the first tuning adjustment.
