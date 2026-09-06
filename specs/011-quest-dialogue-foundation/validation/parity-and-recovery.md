# Parity and Recovery Evidence

Validated on 2026-09-06.

The dialogue integration suite passed 1/1 tests with 13 assertions. The visible and
headless parity suite passed all four cases as part of the 65-test dialogue run.

- The first-option branch produced identical ordered `visited_node_ids`,
  `ordered_effects`, arrival transition, and final acknowledgement in visible and
  headless modes.
- A missing destination was rejected before effects or acknowledgement in both modes.
- A cyclic graph stopped after exactly 128 visited nodes with
  `dialogue_cycle_limit`; neither path acknowledged completion.
- The data-only Baba/Flick/player fixture played in the unchanged renderer with speaker
  order Baba, Flick, player, Baba and sides right, right, left, right.
- Interruption before the choice left flags empty and the event pending. Map-load
  redispatch projected one Inbox entry despite duplicate redispatch calls. Completion
  committed `branch_node`, `branch_careful`, then `careful_terminal`, revealed Baba's
  want once, removed the pending ID, and did not redispatch again.

Command:

```text
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/city-builder-dialogue-integration.log -s addons/gut/gut_cmdln.gd -gdir=res://test/integration/dialogue -ginclude_subdirs -gexit
```
