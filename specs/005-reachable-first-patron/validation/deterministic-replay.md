# Deterministic Replay

Date: 2026-09-05  
Scenario: `first_patron_reachable` schema 2  
Seed: `5005`

Ten clean Playtest sessions executed the same 109 public commands. Every run
completed at simulation hour 1,011 with population 329, 256 allowed cells, the
same 15 ordered progression milestones, and the same balance-relevant final
state hash.

The projection digest below is SHA-256 over a compact JSON object containing
`success`, `action_count`, each milestone's ID and state hash, and the final
state hash. Session IDs, wall-clock time, and pretty-print whitespace are
excluded.

| Run | Outcome | Milestones | Final state hash | Projection digest |
|---:|---|---:|---|---|
| 1 | pass | 15 | `a6d8e75a9ed56eb02705091514b2166ff21cc457677df7a10576693cc7b2a2c4` | `ae02912bc6de6e9dc9a6ec33f3ca6a3b97abebb1f1f9bbfd7caae9b55ada4eaa` |
| 2 | pass | 15 | `a6d8e75a9ed56eb02705091514b2166ff21cc457677df7a10576693cc7b2a2c4` | `ae02912bc6de6e9dc9a6ec33f3ca6a3b97abebb1f1f9bbfd7caae9b55ada4eaa` |
| 3 | pass | 15 | `a6d8e75a9ed56eb02705091514b2166ff21cc457677df7a10576693cc7b2a2c4` | `ae02912bc6de6e9dc9a6ec33f3ca6a3b97abebb1f1f9bbfd7caae9b55ada4eaa` |
| 4 | pass | 15 | `a6d8e75a9ed56eb02705091514b2166ff21cc457677df7a10576693cc7b2a2c4` | `ae02912bc6de6e9dc9a6ec33f3ca6a3b97abebb1f1f9bbfd7caae9b55ada4eaa` |
| 5 | pass | 15 | `a6d8e75a9ed56eb02705091514b2166ff21cc457677df7a10576693cc7b2a2c4` | `ae02912bc6de6e9dc9a6ec33f3ca6a3b97abebb1f1f9bbfd7caae9b55ada4eaa` |
| 6 | pass | 15 | `a6d8e75a9ed56eb02705091514b2166ff21cc457677df7a10576693cc7b2a2c4` | `ae02912bc6de6e9dc9a6ec33f3ca6a3b97abebb1f1f9bbfd7caae9b55ada4eaa` |
| 7 | pass | 15 | `a6d8e75a9ed56eb02705091514b2166ff21cc457677df7a10576693cc7b2a2c4` | `ae02912bc6de6e9dc9a6ec33f3ca6a3b97abebb1f1f9bbfd7caae9b55ada4eaa` |
| 8 | pass | 15 | `a6d8e75a9ed56eb02705091514b2166ff21cc457677df7a10576693cc7b2a2c4` | `ae02912bc6de6e9dc9a6ec33f3ca6a3b97abebb1f1f9bbfd7caae9b55ada4eaa` |
| 9 | pass | 15 | `a6d8e75a9ed56eb02705091514b2166ff21cc457677df7a10576693cc7b2a2c4` | `ae02912bc6de6e9dc9a6ec33f3ca6a3b97abebb1f1f9bbfd7caae9b55ada4eaa` |
| 10 | pass | 15 | `a6d8e75a9ed56eb02705091514b2166ff21cc457677df7a10576693cc7b2a2c4` | `ae02912bc6de6e9dc9a6ec33f3ca6a3b97abebb1f1f9bbfd7caae9b55ada4eaa` |

Result: SC-002 passes with 10/10 equivalent normalized traces.

A post-convergence canonical replay repeated the same 109 actions and matched
the recorded 15 milestones, hour 1,011, population 329, 256 allowed cells, and
final state hash after next-step projection priority was aligned across UI and
automation.
