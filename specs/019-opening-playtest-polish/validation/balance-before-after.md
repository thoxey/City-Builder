# Same-seed balance and replay comparison

Seed `19019` was recorded before implementation and run twice afterward with the same
`first_town/opening_balance` fixture. The two post-change JSON reports are byte-for-byte
identical.

| Opening-balance evidence | Before | Current verified result |
|---|---:|---:|
| Semantic trace hash | `b31852b709cb8cd2ca442ecacac72464b73f016e1ddd3997d63cc0db1c61525c` | `1aba200a47823356e6f9756ca1c34fa28e3be49f3c3ddc8775aa6e00f55c2398` |
| Final state hash | `49ab87ecfcf0de90cf8e42736e4bd2fa86789b62e9e4908849067ba03fcc160c` | `3685cd8765aa13c64b331d5f2792d1c2af9edb3cfc2b290f521598db76985c8b` |
| First home / work / shop | hour 0 / 0 / 0 | hour 0 / 0 / 0 |
| Postwar Terrace placement | hour 0 at the old lifetime-Homes 25 boundary | hour 50 at lifetime Homes 40.192 |
| Endpoint | hour 113 | hour 113 |

The declared balance difference is the Terrace waiting for lifetime Homes 40 instead
of 25; the endpoint and first ordinary home/work/shop milestones are unchanged. The
hashes also cover corrected tutorial evidence serialization and the rest of the current
dirty runtime, so the hashes are reported as reproducibility evidence rather than used
to infer additional balance changes.

The post-change run includes explicit real-stack feature probes:

| Feature probe | Verified result |
|---|---|
| Rooted roads | 9 cells: no receipt and B02 remains active; 10 cells: receipt count 10 and B03 becomes active, all at hour 0 |
| Adjacency copy | Stable observed pair; direction contains “another home” |
| Tutorial terminal gate | First qualifying rooted shop at hour 2; tutorial complete; exactly one persisted handoff |
| Dashboard priority | First-land-quest direction selected; no `0/100` commercial-demand direction |
| Postwar Terrace | locked at lifetime Homes 39; available at 40 |
| Pub | locked at lifetime Shops 14; available at 15 |
| Grass pool | 100 committed choices: `grass` 0, `grass_trees` 55, `grass_trees_tall` 45 |

The feature probe's tutorial state hash is
`4afa50e348602395d4f3beadc2ab4418c8bad57fd2470398da4c4d4c933c0588`;
the Grass selection hash is
`e46907f58d5ad4dc01421b187f78475885e6d7d22dc51756aca38a527b377f5f`.
Both hashes and every concrete selection are identical in
`balance-after-a.json` and `balance-after-b.json`.

The pre-change balance capture recorded the old four-road, Terrace-25, Pub-10, and
three-member Grass fixtures. A second same-seed runtime probe was run from an isolated
archive of source commit `d04d3b01c2db7aa76ce54fa5a77f979762283b6d`, with only
the scenario seed and serialized probe fields instrumented. It proves the historical
road boundary directly: three rooted roads left B02 incomplete, the fourth wrote a
receipt with count 4 and advanced to B03. The same run completed with one handoff,
one of each tutorial event, cold-load parity, and state hash
`616cca4fbba7b1c6cea5e87d8b5f561bde2785399c63479141c1898daf07ab79`.
The current real-stack probe and Builder cold-save/load fixtures prove the new 9/10
boundary while retaining that completed four-road receipt and the unchanged
exactly-once first-shop terminal contract. The Builder fixtures also prove that an
upgraded multi-home adjacency lesson preserves its historical anchor score and persists
newly backfilled non-anchor evidence across a second cold load.
