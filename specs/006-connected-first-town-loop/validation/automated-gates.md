# Automated Gate Record

Captured 2026-09-05.

- Full Godot unit suite: 52 scripts, 320 tests, 1,816 assertions, all passing.
- Full Godot integration suite: 9 scripts, 17 tests, 664 assertions, all passing.
- Data editor: 63 tests passing; production TypeScript/Vite build passing.
- MCP server: 34 active tests passing (28 environment-gated tests skipped) and
  production TypeScript build passing.
- Headless Godot import/parse: passing.
- Full-stack connected-town scenario: passing.
- Matched-layout matrix: 10/10 pairs admissible and passing; nature-only
  adversary rejected.
- Determinism: all 21 scenario sides produced identical hashes across ten runs.
- Bounded exploit search: 36 nature combinations checked; no fourth-or-later
  duplicate gain found.
- Forward+ visual evidence: six 1280×720 captures, including two connected,
  nature-integrated 75-hour mid-game towns, matched layouts, canonical operation
  inspection, and live home/new/overlap placement feedback.
- Milestone-005 canonical patron regression: passing.

## Town Hall cadence mini-goal

- Fresh-town rule: only the free 2×2 Town Hall is initially selectable;
  duplicate placement, demolition, and replacement are rejected canonically.
- Rooted construction: roads grow from the Town Hall component and every
  functional building in the accepted run has canonical road access.
- Road-distance balance: shops receive +20% at 0–5 tiles and +10% at 6–10;
  homes receive −8/−4 Liveability respectively. The run realized £280 in
  incremental proximity income.
- Cadence: 15/15 at five minutes, 30/30 at ten, and 60/60 at twenty, with
  60/60 successful meaningful attempts and non-negative cash throughout.
- Final mix: one Town Hall, 16 homes, 13 shops, 13 workplaces, 17 functional
  nature places, 75 road tiles, 75 residents, and 11 useful choices remaining.
- Visual evidence: Forward+ 1280×720 capture with exact 135-item manifest
  (60 meaningful structures plus 75 road tiles).

Godot reports the repository's existing GUT orphan/resource warnings at exit;
there are no test failures. T001 remains open because no trustworthy pre-change
trace was captured before tuning; the provenance gap is documented in
`baseline-before.md`. Human behaviour, visual-review, and durability gates
remain deliberately open in Phase 9 of `tasks.md`.
