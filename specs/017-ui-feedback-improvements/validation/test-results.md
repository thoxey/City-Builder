# Automated Verification

Validated on 2026-09-06 with Godot 4.6.2 and GUT 9.3.0.

## Focused unit regression

Command: the focused command in `quickstart.md`, covering Dialogue, PlayerUI,
Palette, Builder, and Demand.

- 18 scripts
- 156 tests passed, 0 failed
- 1,152 assertions
- Exit code 0

Coverage includes whole-word Ambrose decoration and fallback, exact authored
text, demand current/lifetime targets, representative intrinsic effects, signed
dock rows, exclusion of live preview values, 4K surface scaling/safe insets, and
the deterministic 3.2-second feedback curve.

## Relevant integration regression

Command: the PlayerUI and Dialogue integration command in `quickstart.md`.

- 5 scripts
- 6 tests passed, 0 failed
- 32 assertions
- Exit code 0

The clean shell, input priority, radial availability/placement, and interrupted
dialogue recovery flows remain green.

## Additional simulation confidence

The Community unit suite completed independently with 51/51 tests and 563
assertions. An opening-tutorial scenario run also completed with
`success=true`, no failures, and deterministic state hash
`616cca4f9767305436d93244caf155899266764b1829c28aa0028b1d9309a651`.

Godot reports its existing macOS CA warning and GUT/ObjectDB orphan/resource
cleanup warnings after successful runs. They do not change the zero exit codes
or assertion totals.

## Integrated repository gate

After workstreams 4 and 5 were combined, the full `res://test` suite was rerun
with writable `user://` storage: **566/566 tests passed across 116 scripts, with
3,751 assertions and exit code 0**. The live-consequence benchmark inside that
run recorded a 12.341 ms median. Existing non-failing cleanup warnings remained.
