# Test Results

Validated on 2026-09-06 with Godot 4.6.2 and writable
`HOME=/tmp/city-builder-tutorial-user`.

- Current focused tutorial, Dashboard, dialogue, EventSystem, Playtest, and
  opening-tutorial integration run: **158/158 tests passed, 871 assertions**.
- Current core tutorial edge-case run: **10/10 tests passed, 68 assertions**.
- Tutorial integration immediately followed by the progression save/load
  matrix: **9/9 tests passed, 563 assertions**. This specifically verifies the
  child-process isolation used by the real-stack scenario.
- Adjacent Traffic, Demand, Community, progression, and dialogue run:
  **125/125 tests passed, 1,361 assertions**. The first command also named a
  nonexistent legacy `test/unit/attractiveness` directory; GUT reported that
  path as a harness error while every discovered test passed. Attractiveness
  behavior is exercised by the core and real-stack scenario.
- Final complete unit/integration run: **543/543 tests passed, 3,638
  assertions** across 113 scripts.
- Headless editor scan exited 0 with no script parse or class-registration
  errors.
- Spec Kit prerequisite check resolved the feature directory and tasks.

Expected environment noise remains: macOS CA lookup, Godot MCP connection
attempts during editor startup, known orphan/resource teardown messages, image
load warnings in existing content tests, and fixture trash warnings. None
caused a failed test in the final run.
