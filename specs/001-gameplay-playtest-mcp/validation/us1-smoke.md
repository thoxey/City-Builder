# US1 Live Smoke Evidence

Date: 2026-09-04  
Godot: 4.6.2.stable  
Node: local project runtime

The separate `city-playtest` MCP advertised exactly these six tools:
`playtest_start`, `playtest_get_state`, `playtest_get_choices`,
`playtest_place`, `playtest_demolish`, and `playtest_advance`.

The running game was then exercised through the same bounded
`city_playtest` request/response route used by the editor adapter:

| Operation | Result | Sequence | Buildings | Hour | State hash prefix |
|---|---:|---:|---:|---:|---|
| start fresh_city seed 1 | ready | 0 | 0 | 6 | `43416145` |
| get_state | ready | 0 | 0 | 6 | `43416145` |
| place residential_t1 at 0,0 | applied | 1 | 1 | 6 | `858c006b` |
| advance 1 hour | applied | 2 | 1 | 7 | `2dc1744d` |
| demolish at 0,0 | applied | 3 | 0 | 7 | `7dc40b2b` |

The initial observation hash was unchanged, placement selected a concrete pool
variant, advancement emitted exactly one gameplay hour, and demolition resolved
the placed building through its footprint.

One desktop-environment caveat was observed: two simultaneously open Godot
editors can race to become the MCP server's active editor connection. The
repeatable live test is therefore opt-in with `RUN_LIVE_GODOT=1` and expects one
editor instance with the scene playing.
