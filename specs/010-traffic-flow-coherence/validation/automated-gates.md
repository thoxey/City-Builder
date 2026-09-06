# Automated Release Gates

Captured 2026-09-06 with Godot `4.6.2.stable.official.71f334935` and GUT
9.3.0. Every command below exited zero.

| Gate | Result | Assertions / evidence |
|---|---:|---:|
| `test/unit/traffic` | 37/37 passing | 139 |
| `test/unit/people` | 27/27 passing | 84 |
| `test/unit/playtest` | 29/29 passing | 114 |
| `test/integration/traffic_flow` | 5/5 passing | 42 |
| Complete `test/unit` | 422/422 passing | 2,183 |
| Complete `test/integration` | 29/29 passing | 736 |
| Traffic-flow scenario | 10/10 identical | trace `9f97c76d2c2a125d853508fb8b424913d8aaade3bfa228e9664f6fa95c59625d` |
| Civilian scenario | 10/10 identical | trace `6c21bd99bdc7eb37b401333f4816ee4a728b3f39e500b635ffedbd0b216b3fc6` |
| First-town loop | success | roadless, connected, and disconnected assertions passed |

The traffic-flow scenario held the canonical route blocked for 600 fixed steps,
produced byte-identical normalized traces, and detected all nine required injected
faults. Its live authority smoke used only the established `start`, `place`, and
`advance` operations. Machine-readable evidence is in `last-run.json`.

The first-town loop recorded these gameplay hashes:

- roadless: `12ab031246ca61174751ed7d1310fa1d41df5b7edf4258806550b56aff44f024`
- connected: `432ba1cf436cb67a3af8c6eba0458bb655720a3ddbb9d9c62b8f5f930bd0b0b3`
- disconnected: `5a8627adb672d001a59a126cfef82a7ac1a2c2b2596f3141982d6b80db827787`

## Observed warnings and expected negative-path logs

- Focused suites retain the established GUT orphan/unfreed-object notices and Godot
  ObjectDB/resource-in-use exit notices.
- The full unit run reported 23 warnings, 302 run orphans (382 including globals),
  six leaked `GodotBody3D` RIDs, ObjectDB instances, and four resources in use at
  exit. The warnings include intentional invalid-catalogue, duplicate-ID,
  missing-model, modal-reentry, and direct-image-load test cases.
- The complete integration run reported the established Float/Int comparison warning,
  five run orphans (23 including globals), and the ObjectDB/one-resource exit notice.
- Playtest logs for `step_visual_time` and `get_traffic_flow` are intentional negative
  assertions proving that no public visual stepping or traffic command exists.
- The civilian runner retained the established ObjectDB/two-resource exit notice.

No warning caused a non-zero gate, and none identifies a feature-010 assertion or
runtime diagnostic failure.
