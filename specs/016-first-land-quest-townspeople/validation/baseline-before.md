# Baseline Before Implementation

**Date**: 2026-09-06

**Scope**: Existing OpeningTutorial, Dialogue, EventSystem, BuildableArea,
CharacterSystem, and adjacent integration foundations. Workstream 2 made no runtime
source/data changes before this run.

## Command

See the focused foundation command in `../quickstart.md`.

## Result

- GUT discovered 19 scripts and 160 tests.
- 155 tests passed.
- 4 tests failed and 1 was reported risky/pending.
- The process exited 1.

This is a recorded concurrent/pre-implementation baseline, not a Workstream 2 release
result. Startup encountered a parse error in concurrently edited PlayerUI code:
`PlacementConsequencesPanel` was referenced while that separate workstream's new script
was still being added. The opening real-stack child exited 1, and persistence cases then
could not create their `user://tests/*.res` files. Those cascades are outside Workstream
2 and are not counted as regressions introduced here.

The parent workstream coordinator will rerun the integrated suite after the runtime
agents finish. Workstream 2 automated verification remains unchecked until approved
content is implemented and its own focused/scenario/full gates pass.

## Useful passing foundation evidence

- Opening tutorial core: 10/10 passed.
- Dialogue core: 17/17 passed.
- Dialogue expressions: 9/9 passed, including semantic `player` → Ambrose mapping.
- Dialogue input: 8/8 passed.
- The run continued through the focused unit foundations and reported 155 passing tests
  overall before the concurrent/persistence failures were summarized.

Full output: `/tmp/city-builder-first-land-foundation.log` (local ephemeral evidence).
