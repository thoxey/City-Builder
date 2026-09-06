# Final validation results

Captured 2026-09-06 with Godot 4.6.2 debug on Apple M2 Max, macOS arm64.

## Complete suite

Command: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit`

Result: 152 scripts, 738 tests, 7,370 assertions, 738 passing, zero failures, 103.358 seconds. GUT reported 31 existing warning groups and the existing teardown diagnostics (561 test orphans, 45 leaked physics RIDs, four resources still in use). These did not fail assertions and were present independently of the acceptance behavior.

## Required focused gates

- Community runtime boundary: 9/9 passed, including canonical/compiled totals, preindexed handles, candidate multipliers, schedule/formula parity, revision invalidation, rebuild parity, detached explanations, and cache exclusion.
- Community plus transaction integration: 95/95 passed.
- Community UI: 31/31 passed; 500-resident projection measured 13.497 ms under the 16.7 ms gate.
- Player-visible committed stats: 1/1 passed. Cash, income, and homes remain at their old values before the scheduler flush and all update after it.
- Migration/People stale-delta and maintained movement-tier regressions: 6/6 passed.
- Placement consequence parity: 4/4 passed; 500-resident/135-source median 10.591 ms.
- 512-person/256-vehicle-slot combined loop: passed its 8 ms p95 gate.

## Scenario and persistence gates

- Three compiled 135-building/140-resident/240-hour runs passed all budgets (9.600–9.815 s, 13.663–14.404 ms hourly p95, 26.511–27.668 ms hourly max) and produced identical state and ledger hashes.
- The frozen hour-240 checkpoint remains `8b1856d363d08568c1f8824d0dc0d0ebc117365e03f37b55d74efee099aefec4`; the stable final snapshot after deferred guide/presentation work is recorded separately below.
- A full canonical-evaluator run produced the same state hash `fa19631150065fb74ba228104e843ae0a59a02e051e913748ce38a17c0733004` and ledger hash `adcc840bc5e503c48159d3bca947688aa0699aa56c2554090bbfc8aea0ed5163`.
- Reversed contributor registration passed `test_hourly_transaction_determinism.gd`.
- The rendered runner generated, saved, cold-loaded, warmed, and profiled the reference town successfully.
- Community persistence, legacy migration, save/hash cache exclusion, and progression cold-round-trip suites passed in the complete run.

## Failures encountered and resolved

- The initial recursive run exposed the user-reported gap: the status bar was not registered with the presentation scheduler. The new real committed-hour integration test now guards it.
- A subsequent run caught stale assignment-change IDs being replayed by People; a one-shot regression was added and the repeated work removed.
- Load-sensitive Community UI and placement quote timing failures were reduced through bounded row work and explicitly invalidated source reuse. The final recursive run is green.

No unresolved regression remains. Teardown leak/orphan diagnostics are pre-existing non-assertion warnings and are reported separately above.
