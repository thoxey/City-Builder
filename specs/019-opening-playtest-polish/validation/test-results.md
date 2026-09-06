# Test results

Validated on 2026-09-06 with Godot 4.6.2 stable on macOS/Apple M2 Max and
Node/Vitest from the repository lockfile.

| Check | Result |
|---|---|
| Focused quickstart Godot suite | 21 scripts, 137/137 tests, 1,374 assertions, exit 0 |
| Expanded feature-affected Godot suite | 53 scripts, 319/319 tests, 2,887 assertions, exit 0 |
| Full `res://test` Godot suite | 152 scripts, 739/739 tests, 7,408 assertions, exit 0 |
| BuildingCatalog compatibility/exclusion suite | 19/19 tests, 105 assertions, exit 0 |
| Event/manifest validation suite | 29/29 tests, 208 assertions, exit 0 |
| Progression repository validation suite | 6/6 tests, 9 assertions, exit 0 |
| Data editor tests | 8 files, 80/80 tests, exit 0 |
| Data editor production build | TypeScript and Vite build passed; only the existing large-chunk advisory |
| Headless manifest export | 5 characters, 1 patron, 31 buildings, 10 events, 7 flags; exit 0 |
| Same-seed balance/replay | Two byte-identical seed-19019 reports; scenario and feature probes passed |
| Real-stack opening/save playthrough | Success; 9 receipts, one handoff, all six compatibility flags true |
| Normal-renderer capture | 18/18 real-main-scene captures at both supported resolutions; no failures or panel/guidance/Dashboard intersections |

The expanded affected run includes Builder, BuildingCatalog, Palette, Playtest,
UniqueRegistry, tutorial, Dashboard, placement-consequence, PlayerUI, progression,
and save/load coverage. The full run includes all current unit, contract, and
integration tests in the dirty worktree.

The full run retained 31 non-failing GUT warnings. The final affected run retained
10 existing unfreed-child and float/int comparison advisories.
Godot also reported its existing exit cleanup diagnostics (45 `Body3D` RIDs in the
full run and 22 in the affected run,
ObjectDB instances, and four resources). A preliminary sandboxed run failed only
because Godot could not write its `user://tests` and `user://test_fixtures`
directories; the required writable-`user://` rerun passed every test.

Save/load compatibility covers real Builder cold-save/load fixtures for a historical
completed four-road receipt and incomplete nine- and ten-road states at the new gate,
plus completed tutorial receipt/handoff parity, Builder ID renumbering, and
demolished/replacement home evidence. An upgraded multi-home fixture preserves the
historical anchor score, backfills the exact non-anchor score, saves the migrated row,
cold-loads it again, and then records the expected `-10` adjacency delta from that other
home. A separate exact-ID plain-grass fixture verifies legacy catalogue behavior. The
plain-grass record survives load, resolves through the catalogue, follows the normal
cosmetic-only inspection path, and demolishes normally.
Machine-readable fixture results are recorded in `save-load-compatibility.json`.
The direct scenario emitted every tutorial event exactly once, recorded adjacency
`-10` and repair `+20`, and produced state hash
`281d5bbaac63f9902a3182481fc6594c892ee22ee8e3ce2586bb6ef91330b4b8`.

Manifest audit confirmed Postwar Terrace threshold 40, Pub threshold 15, and
`palette_excluded: true` in both the plain-grass body and summary. Plain `grass`
retains its stable ID and `grass` pool identity; the player-facing pool members are
exactly `grass_trees` and `grass_trees_tall`. A repeated export was semantically
identical after ignoring `exported_at` (normalized SHA-256
`e429abd359ba3c58cc0d30c603af888a53068dfc27618190e39ff930b93901ca`).

The normal-renderer capture ran through the real main scene with authoritative
placement quotes, tutorial/Dashboard projections, and committed Grass choices. Its
manifest reports `success: true`, renderer `forward_plus`, display server `macOS`,
and no failures. It records the panel, guidance, and Dashboard rectangles and asserts
their safe-margin separation at every visible-panel state and viewport.

The historical tutorial boundary was also re-run at seed 19019 from an isolated archive
of pre-feature commit `d04d3b01c2db7aa76ce54fa5a77f979762283b6d`. Three rooted
roads remained on B02, four wrote the historical count-4 receipt and advanced to B03,
and the complete run emitted exactly one handoff with cold-load parity. The complete
probe is serialized in `baseline-before.json`.

Final scope audit: feature 019 added no model asset or repair, world-space placement
capsule, broad progression/building/service system, or bottom-bar redesign. Concurrent
unrelated dirty-worktree changes were preserved. `git diff --check` passed after the
implementation and verification changes.
