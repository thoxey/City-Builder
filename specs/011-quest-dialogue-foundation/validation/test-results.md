# Focused Test Results

Validated on 2026-09-06 with Godot 4.6.2 stable.

| Scope | Result | Assertions |
|---|---:|---:|
| `test/unit/dialogue` | 65/65 passing | 270 |
| `test/integration/dialogue` | 1/1 passing | 13 |
| Inbox, EventSystem, CharacterSystem, Playtest, Builder, PlayerUI | 116/116 passing | 759 |
| `test/integration/progression` with writable `user://` | 8/8 passing | 548 |

Commands were the focused commands in `quickstart.md`, using
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path .`, GUT's
`addons/gut/gut_cmdln.gd`, the directories above, `-ginclude_subdirs`, and `-gexit`.

Covered normalization, legacy records, reveal timing, one-event/one-transition input,
append-only rows, bottom-aware scrollback, semantic portraits, three-person swapping,
choice gating, late commit, acknowledgement, recovery, semantic playtest resolution,
and progression save/load. There were no test failures. GUT reported its existing
orphan/resource-exit warnings; no assertion failed because of them.
