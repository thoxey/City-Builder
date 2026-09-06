# Automated verification

Verified on 2026-09-06 with Godot 4.6.2 stable on macOS (Apple M2 Max).

## Focused feature suite

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/placement-consequences-final.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit/placement_consequences,res://test/integration/placement_consequences \
  -ginclude_subdirs -gexit
```

Result: **10 tests, 47 assertions, all passed**.

This covers canonical invalid reasons, rotated multi-cell footprints,
replacement confirmation, 100 repeated no-mutation quotes, panel presentation
states, panel cancellation, community parity, attractiveness parity, replacement
home removal, and the representative performance fixture.

The 500-resident/135-source benchmark recorded an 11-sample median of
**12.554 ms** and maximum of **12.985 ms**, below the 16 ms median budget.

## Affected regressions

The affected builder, palette, player UI, attractiveness, and player UI
integration suites completed with **58 tests, 641 assertions, all passed**.
The community unit suite completed separately with **51 tests, 563 assertions,
all passed**. The split run avoids hiding the slower community simulation tests
inside the UI-focused result.

## Import and renderer checks

The headless editor import check exited 0 without parse errors. The normal
renderer capture run exited 0 and generated all five entries in
`screenshots/manifest.json` using Metal on Apple M2 Max.

Expected environment/test-harness noise remained: macOS CA certificate lookup,
the unavailable local Godot MCP endpoint, the repository's duplicate portrait
UID warning, GUT orphan/resource warnings, and sandboxed editor-settings writes.
None caused a test, import, or capture failure.

## Integrated repository gate

After workstreams 4 and 5 were combined, the full `res://test` suite was rerun
with writable `user://` storage: **566/566 tests passed across 116 scripts, with
3,751 assertions and exit code 0**. This run measured the representative
placement quote at a 12.341 ms median and 12.722 ms maximum. Existing
non-failing cleanup warnings remained.
