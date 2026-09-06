# Quest Dialogue Foundation Baseline

Captured 2026-09-06 before feature 011 runtime changes, using Godot 4.6.2 and
GUT 9.3.0.

## Focused suite

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-dialogue-baseline.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit/dialogue,res://test/unit/inbox,res://test/unit/event_system,res://test/unit/character_system,res://test/unit/playtest \
  -ginclude_subdirs -gexit
```

- Scripts: 12
- Tests: 88 passed, 0 failed
- Assertions: 242
- GUT warnings: 6
- Existing orphan warning: 116 total reported at process exit
- Process exit: 0

The macOS headless runner also emitted its pre-existing system CA certificate warning
and final resource/object leak diagnostics. Neither affected the passing result.

## Legacy visible traversal

The body-only fixture opened at `n_start`, rendered the node `body`, and constructed
the authored option buttons. Selecting an option applied that option's effects and
navigated to exactly its `next` node; selecting the final option closed the modal.
Node `on_enter` effects were applied immediately by the pre-change `_enter_node()`.
A terminal node with no options received a generated `Continue` button.

The representative two-node traversal was `n_start -> n_middle -> close`. The
production residential-arrival record was also body-only and authored as
`n_start -> n_end -> close`, with option labels `Continue` and `Close`.

## Effects, acknowledgement, and arrival transition

The focused visible tests established that option effects were forwarded once to
EventSystem. Closing a `character_arrived` dialogue called
`CharacterSystem.mark_want_revealed(character_id)` and then acknowledged the pending
dialogue ID. A non-arrival dialogue did not perform the character transition.

The focused headless fixture selected the first authored option, applied
`set_flag(met_alice)`, transitioned the character from `ARRIVED` to
`WANT_REVEALED`, and acknowledged the pending `headless` event. Unknown events and
known-but-not-pending events were rejected. The pre-change headless traversal applied
each node's `on_enter` effects followed by its selected first-option effects, stopping
after at most 128 visited nodes.

The production residential arrival's final authored option applied
`set_flag(met_aristocrat_residential)` before the same arrival reveal and pending
acknowledgement semantics.
