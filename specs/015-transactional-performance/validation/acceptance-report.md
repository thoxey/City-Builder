# Acceptance report

All Transactional Performance Architecture success criteria pass on the reference machine.

| Criterion | Result | Evidence |
|---|---|---|
| SC-001 deterministic replay | Pass | Three state/ledger-identical compiled runs, canonical evaluator match, reversed-registration integration test. |
| SC-002 atomic rejection | Pass | Transaction coordinator tests preserve state/version and attribute failures. |
| SC-003 coalesced presentation | Pass | Scheduler, presenter contract, real core-presenter tests, and committed status-bar regression. |
| SC-004 ≤35 s scenario | Pass | 9.600, 9.725, 9.815 s versus 46.626–47.423 s baseline. |
| SC-005 hourly ≤16.7 ms p95 / ≤33.3 ms max | Pass | p95 13.663–14.404 ms; max 26.511–27.668 ms versus 479.610–505.230 ms baseline maxima. |
| SC-006 building commands | Pass | Atomic/incremental suites pass; representative placement quote median 10.591 ms. |
| SC-007 bounded projections | Pass | Named-projection tests pass; Community UI 500-resident projection 13.497 ms under its existing 16.7 ms list gate; operational selector budget tests pass. |
| SC-008 entity loop ≤8 ms p95 | Pass | Combined 512-person/256-vehicle-slot integration gate passes. |
| SC-009 rendered budgets | Pass | Median 16.567–16.593 ms (60.27–60.36 FPS), p95 16.885–16.965 ms, max 16.990–34.456 ms. |
| SC-010 layered gates | Pass | 738/738 complete GUT suite plus all canonical runs. |
| SC-011 attribution | Pass | Every frame is assigned to named boundaries or explicit `engine_unattributed`; rendered reports include both. |
| SC-012 Community boundaries | Pass | 9/9 boundary contract, full canonical/compiled scenario identity, rebuild parity, save/hash exclusion, detached bounded explanation tests. |

The compiled runtime remains Community-owned, typed, numeric, revision-keyed, disposable, and absent from DataMap, saves, snapshots, hashes, UI models, and presenter code. Authored JSON/Resources remain the source format. GameState/Builder retains placed-city authority; Community retains resident authority and writes DataMap only at explicit persistence boundaries.

Compatibility adapters remain only where consumers still exist. The normal runtime routes hourly mutations through the transaction coordinator; fallback `hour_changed` hooks are inactive when that dependency is present.

## Constitution and runtime-boundary review

- Plugin ownership and dependency injection remain explicit; no service locator, alternate clock, background authority, external database, or ECS layer was introduced.
- Builder/GameState remains the placed-city command authority. Community is the sole live resident authority; DataMap is refreshed only as the durable save projection.
- Authored JSON and Resource dictionaries remain unchanged as authoring inputs. The compiled runtime is derived, disposable, deterministic, and revision-invalidated.
- Transactions validate all intents before commit, advance StateVersion once, publish a canonical change set, and expose independent bounded ledger rows.
- Presenters receive named detached projections and cannot calculate or mutate gameplay outcomes.
- Compatibility paths were inventoried and retained until their remaining consumers can be migrated behind separate parity gates.
