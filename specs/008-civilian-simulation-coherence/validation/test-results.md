# Final Automated Test Results

Date: 2026-09-06  
Godot: 4.6.2  
GUT: 9.3.0

## Focused suites

| Suite | Tests | Assertions | Result |
|---|---:|---:|---|
| Community | 43/43 | 533 | PASS |
| People | 16/16 | 47 | PASS |
| Traffic | 15/15 | 51 | PASS |
| Day/night | 6/6 | 16 | PASS |
| Playtest | 23/23 | 96 | PASS |
| Civilian integration | 6/6 | 23 | PASS |
| **Total** | **109/109** | **766** | **PASS** |

The final canonical civilian runner also passed 10/10 byte-identical full-day
replays with 25 checkpoints per replay, zero clean-trace violations, and all eight
injected fault codes detected. The focused diagnostic file passed 2/2 tests and 8
assertions after that final run.

## Complete unit suite

The full `test/unit` command was run with access to Godot's normal writable
application-data directory: **67 scripts, 358/358 tests, 1,933 assertions passed**.
This avoids treating the known sandbox-only `user://` catalogue fixture failures as
product failures.

GUT reported 20 warnings. They are existing test-fixture UI fallback and unfreed
child/orphan diagnostics; Godot also reported RID/ObjectDB/resource allocations at
process shutdown. There were no failed assertions, script errors, or feature
diagnostic violations. These remain test-harness cleanup debt rather than accepted
functional failures.

## Content and first-town regression

- Data editor production build: PASS. Vite emitted its existing large-chunk advisory.
- Data editor tests: 7 files, 76/76 tests PASS.
- First-town loop: `success=true`, zero failures.
- Roadless hash: `12ab031246ca61174751ed7d1310fa1d41df5b7edf4258806550b56aff44f024`.
- Connected hash: `432ba1cf436cb67a3af8c6eba0458bb655720a3ddbb9d9c62b8f5f930bd0b0b3`.
- Disconnected hash: `5a8627adb672d001a59a126cfef82a7ac1a2c2b2596f3141982d6b80db827787`.

All three hashes are byte-for-byte equal to the pre-feature evidence at commit
`4a42cfe`.

## Success-criterion reconciliation

SC-001 through SC-008 are covered by the focused, replay, performance, full-suite,
and first-town evidence. SC-009 is covered by `venue-role-decisions.md` and
`asset-scope-gate.md`. The separate normal-renderer observation remains a manual
evidence gate and is not inferred from headless success.
