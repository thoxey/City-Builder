# Verification Results

Run on 2026-09-06 with Godot 4.6.2 and a writable `user://` directory.

| Gate | Result |
|---|---|
| BuildableArea + Community unit suites | PASS — 70/70 tests, 624 assertions |
| Community + progression + player UI integration suites | PASS — 15/15 tests, 579 assertions |
| Fixed-seed full-town scenario | PASS — 60/60 meaningful placements, 100% success, 0 rooted failures |
| Rooted donation | PASS — +192 unique cells, 448 total, repeated receipt +0 |
| Visual capture | PASS — inverted 5%-white perceptual non-buildable mask at 1280×720, starting zoom 60, Forward+ |

Follow-up inversion verification: the combined focused BuildableArea and player
UI regression run passes 24/24 tests with 79 assertions. Its presentation
contract reports 256 clear rooted cells and 261,888 veiled cells across the
512×512 rendered ground; radial and placement modes retain the same clear cells
and increase the veil from 0.0125 to 0.02 linear alpha (5% to 8% perceptual opacity).

The unit run reports one GUT warning for two unfreed test children and the usual
engine-exit orphan/resource diagnostics. The integration run reports one
existing float/int comparison warning in the first-patron fixture; all selected
tests completed with exit code 0.

Two independent seed-6066 replay processes against the same current tree
produced the identical state hash
`97f9a572217d4dfa12de8feb8f9a66589aa25fa416aaf48e10a12450712bf83b`.
Their evidence is also byte-equivalent after removing timing fields, including
land, population, building manifest, operations, checkpoints, proximity
evidence, and average qualities.
