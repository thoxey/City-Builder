# Baseline Evidence

Captured 2026-09-06 before runtime implementation with Godot
`4.6.2.stable.official.71f334935` and GUT 9.3.0.

| Suite | Result | Assertions |
|---|---:|---:|
| `test/unit/traffic` | 20/20 passing | 71 |
| `test/unit/people` | 16/16 passing | 47 |
| `test/unit/playtest` | 27/27 passing | 108 |
| `test/integration/civilian_simulation` | 6/6 passing | 23 |

Baseline People performance at 512 proxies over 300 samples was 0.6626 ms average,
1.0820 ms maximum, with a 4.4550 ms diagnostic snapshot.

Tracked runtime media inventory (`*.wav`, `*.mp3`, `*.ogg`, `*.glb`, `*.png`,
`*.jpg`, `*.jpeg`, `*.webp`) contains 1,060 files. The SHA-256 digest of the sorted
per-file SHA-256 inventory is:

`34575ea3d24ca59d1b6118af3bec5961e009f3dde2708a1ae96442bb34f785d6`

Observed pre-existing warnings:

- macOS headless certificate lookup reports `get_system_ca_certificates`.
- Some established GUT suites report unfreed children/orphans.
- Godot reports ObjectDB instances and one resource still in use at exit.

All four commands exited zero; these warnings are baseline limitations, not introduced
by feature 010.
