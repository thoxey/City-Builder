# Verification Results

## Passed

- Focused GUT: 4 tests, 16 assertions.
- Opening-balance suite: three declared seeds plus isolated primary replay;
  all four runs successful and replay comparison passed.
- Server tests: 8 files passed, 34 tests passed; 8 files/28 tests skipped by
  their existing configuration.
- Server TypeScript build: passed.
- Normal-renderer run and 1280×720 screenshot: passed and visually inspected.
- Full GUT with all unit and integration directories: 113 scripts, 541 tests,
  3,614 assertions passed. The independently spawning opening-tutorial group
  was listed last to prevent its deferred parent-autoload work from contaminating
  a subsequent group.
- Progression save/load isolation check after the concurrent change: 3 tests,
  66 assertions passed.

## Test-order note

The default alphabetical recursive ordering runs the newly added opening-
tutorial real-stack test before progression save/load. Its child-process wait
allows deferred parent autoload initialization to populate default Ambrose and
patron entries, so that ordering reported 540/541 passing. The progression
suite passed independently (3 tests/66 assertions), and the complete ordered
run passed 541/541. This unrelated order dependency remains a repository risk;
this workstream does not alter tutorial or progression persistence code.
