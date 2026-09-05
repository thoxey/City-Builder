# Validation Results: Reachable First Patron

**Date**: 2026-09-05  
**Result**: Pass

## Acceptance evidence

- The canonical scenario completed in 109 public gameplay actions at hour 1011
  with population 329, all three contributors complete, the Theatre built, and
  buildable land expanded from 64 to 256 cells.
- Ten clean canonical replays produced the same 15 ordered milestones, final
  state hash, and aggregate replay digest. See `deterministic-replay.md`.
- The tracked runtime contract executed the same scenario through the server and
  running Godot game in 120.5 seconds: 1 test passed.
- Six real ResourceSaver/ResourceLoader boundary fixtures passed with cache
  bypass and exact-once reconciliation. See `save-load-matrix.md`.

## Automated gates

| Gate | Result | Evidence |
|---|---:|---|
| Godot recursive unit suite | Pass | 291 tests, 1,720 assertions |
| Focused progression integration | Pass | 7 tests, 543 assertions, including 460 parity assertions |
| Focused progression save/load | Pass | 2 tests, 61 assertions |
| Player UI integration | Pass | 5 tests, 19 assertions |
| Server suite | Pass | 34 tests passed; 28 opt-in tests skipped |
| Server TypeScript build | Pass | No type errors |
| Live server/Godot progression contract | Pass | 1 test in 120.5 seconds |
| Data editor suite | Pass | 60 tests |
| Data editor production build | Pass | No type errors |
| Godot editor import/parse | Pass | Exit code 0; no script parse errors |
| Progression content validator | Pass | 5 tests |
| Progression refresh benchmark | Pass | 0.049 ms average, 0.098 ms maximum over 500 samples |
| Character progression focus | Pass | 19 tests |
| Dashboard progression focus | Pass | 10 tests |

## Non-blocking diagnostics

- Godot continues to print existing orphan/resource cleanup warnings at process
  exit and reports the existing duplicate portrait UID during import.
- A clean runtime may report retired building IDs from the user's prior local
  save before the canonical scenario resets its map.
- Vite reports its existing large-chunk advisory after a successful build.
- One progression integration assertion produces Godot's numeric Float/Int
  comparison warning while still comparing equal values.

None of these diagnostics changed the gate results or canonical state evidence.
