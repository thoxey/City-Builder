# Quickstart Validation: Transactional Performance Architecture

This guide describes the validation sequence implementation must satisfy. It does not authorize implementation or replace the detailed contracts.

## Prerequisites

- Godot 4.6.2 at `/Applications/Godot.app/Contents/MacOS/Godot`
- Repository root as the current directory
- Debug/headless build for contracts and deterministic scenarios
- Reference saved/rendered town and baseline evidence recorded in `validation/baseline.md`

## 1. Contract and focused unit gates

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/contract/simulation,res://test/contract/presentation,res://test/contract/performance,res://test/unit/simulation,res://test/unit/presentation,res://test/unit/performance -ginclude_subdirs -gexit
```

Expected: stable registration/order, atomic rejection, change-set immutability, projection versioning, invalidation coalescing/catch-up, and evidence schema all pass.

## 2. Domain-focused gates

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit/community,res://test/unit/dashboard,res://test/unit/people,res://test/unit/traffic,res://test/integration/simulation,res://test/integration/presentation,res://test/integration/performance -ginclude_subdirs -gexit
```

Expected: migration dependency reuse/invalidation, independent UI presenters, operational-vs-diagnostic separation, incremental building indexes, stable traffic fairness, and maintained people order pass.

## 3. Deterministic parity

Run the canonical scenario at least three times with normal and reversed contributor registration order. Record:

- final authoritative state hash;
- canonical intent-ledger hash;
- migration decisions and resident identities;
- traffic admission and completion order;
- per-hour change-set domains and versions.

Expected: all authoritative and ordered outputs match. Timing values may differ and must not enter either hash.

Canonical-evaluator comparison command:

```sh
CITY_BUILDER_COMMUNITY_EVALUATOR=canonical CITY_BUILDER_REBALANCE_EVIDENCE_PATH=/tmp/community-canonical.json /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/community-canonical.log -s res://scripts/run_town_rebalance.gd
```

## 4. Full suite

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
```

Expected: zero failures before any compatibility adapter is removed.

## 5. Canonical performance playthrough

```sh
/usr/bin/time -lp /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://scripts/run_performance_playthroughs.gd
```

Expected: three 135-building/240-hour runs meet the [performance evidence contract](contracts/performance-evidence.md), including the 06:00 boundary and final hashes.

## 6. Rendered reference profile

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --log-file /tmp/city-builder-rendered.log -s res://scripts/run_rendered_performance_profile.gd
```

The runner creates and cold-loads the named reference save, warms for 120 frames, then records three 180-frame samples with UI and people visible. Explicit diagnostics and load/warm-up are excluded.

Expected: median ≥60 FPS, process-time percentiles within budget, and at least 95% main-thread time attributed to named boundaries or `engine_unattributed`.

## 7. Rollout gate

For each compatibility adapter:

1. list all remaining consumers;
2. run its focused contract and parity tests;
3. run deterministic replay and the full suite;
4. remove the adapter only when no consumer remains;
5. rerun the canonical scenario before merging.

Store evidence in `specs/015-transactional-performance/validation/`. Performance reports are diagnostic artifacts and must not modify gameplay saves or hashes.

Delivered reports are `benchmark-headless.json`, `benchmark-rendered.json`, the combined `benchmark-after.json`, `parity-report.json`, `test-results.md`, and `acceptance-report.md` in that directory.
