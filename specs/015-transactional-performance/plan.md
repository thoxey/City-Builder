# Implementation Plan: Transactional Performance Architecture

**Branch**: `015-transactional-performance` | **Date**: 2026-09-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/015-transactional-performance/spec.md`

## Summary

Replace direct hourly mutation through synchronous signal fan-out with one deterministic transaction coordinator. Plugins and building programmes remain independent contributors: they register through dependency injection, read one immutable hour context, and submit typed intents. The coordinator validates and reduces all intents into one atomic authoritative commit, retains an intent-level ledger, and emits one immutable change set.

Use that change set to drive a separate presentation scheduler. UI presenters register their invalidation domains independently, dirty state coalesces until one end-of-frame flush, and hidden presenters retain only the latest required version. Split bounded operational projections from explicit diagnostics, incrementally maintain placement-dependent indexes, cache migration batch facts, replace per-frame people/traffic copying and sorting with stable maintained order, and enforce boundary-specific performance budgets.

## Technical Context

**Language/Version**: GDScript 4.x on Godot 4.6.2; JSON configuration and evidence

**Primary Dependencies**: Existing PluginBase/PluginManager dependency injection, GameState/Builder shared-city authority, Community-owned resident authority, DataMap persistence projection, GameEvents compatibility signals, GUT 9.3.0, MultiMesh rendering, Builder and Playtest command seams

**Storage**: Existing DataMap save-state dictionaries remain the durable projection of authoritative domain state; compiled indexes, transaction/presentation records, and performance records are rebuildable runtime data or bounded diagnostics and never become save authority

**Testing**: GUT unit, contract, and integration suites; deterministic replay; headless canonical city runners; rendered-town profiling

**Target Platform**: Desktop Godot game; current macOS development machine is the reference timing environment

**Project Type**: Plugin-oriented Godot desktop game

**Performance Goals**: 135-building/240-hour run ≤35 s; hourly transaction p95 ≤16.7 ms and max ≤33.3 ms; placement median ≤16.7 ms, p95 ≤33.3 ms, max ≤50 ms; operational UI projections p95 ≤8 ms; combined 512-person/256-car loop p95 ≤8 ms; rendered median ≥60 FPS

**Constraints**: Preserve one gameplay authority and one clock; no partial hourly state; deterministic ordering; no contributor or presenter coupling; diagnostics excluded from hashes/saves; compatibility adapters remain until parity gates pass; no balance or visual redesign

**Scale/Scope**: 30 active plugins, 135 reference buildings, 240 simulated hours, 20 migration candidates per daily batch, 512 civilians, 256 vehicle slots, all current dashboard/community/HUD presenters, three repeated benchmark runs

## Constitution Check

*GATE: Passed before research and re-checked after Phase 1 design.*

- **One Gameplay Truth — PASS**: GameState/Builder remains authoritative for shared city state and Community remains authoritative for resident simulation, with DataMap as its persistence projection. Coordinators accept proposals and publish committed deltas; neither transaction records, compiled indexes, projections, caches, nor presenters become state authorities. Builder/Playtest remain the command seam.
- **Deterministic, Controllable Simulation — PASS**: DayNight remains the clock. Stable contributor/intent keys, explicit reducer order, immutable pre-state contexts, atomic commit, and registration-order tests replace implicit signal ordering. Timing records never affect decisions or hashes.
- **Observable, Explainable State — PASS**: Intent ledger entries preserve per-contributor proposals and dispositions. Change sets explain aggregate effects. Full diagnostics remain available explicitly while routine reads use bounded projections.
- **Data-Driven Balance and Narrative Separation — PASS**: Existing balance/configuration values remain external data. The transaction layer moves execution structure only and does not add tuning or narrative rules.
- **Small Interfaces, Layered Verification — PASS**: Simulation, change-set, projection, presentation, and performance contracts are explicit and independently testable. Each story has contract, focused integration, parity, replay, and scenario seams.
- **Plugin/Event Architecture — PASS**: New coordinators are injectable plugins with narrow registries. Contributors and presenters know contracts, not peers. Existing direct signals are removed only after adapter-backed migration.
- **Post-design re-check — PASS**: The design introduces coordination boundaries but no alternate clock, save model, simulation authority, or UI ownership graph. No constitutional exception is required.

## Project Structure

### Documentation (this feature)

```text
specs/015-transactional-performance/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── tasks.md
├── contracts/
│   ├── authoritative-change-set.md
│   ├── performance-evidence.md
│   ├── presentation-invalidation.md
│   ├── community-runtime-boundaries.md
│   └── simulation-transaction.md
├── checklists/
│   ├── requirements.md
│   └── architecture-performance.md
└── validation/
    ├── baseline.md
    ├── baseline-before.json
    ├── hourly-listener-inventory.md
    ├── parity-us1.json
    ├── parity-us2.json
    ├── parity-us3.json
    ├── parity-us4.json
    ├── benchmark-after.json
    ├── parity-report.json
    ├── adapter-inventory.md
    ├── acceptance-report.md
    └── test-results.md
```

### Source Code (repository root)

```text
plugins/
├── simulation/
│   └── simulation_transaction_plugin.gd   # hourly collection/validation/commit
├── presentation/
│   ├── presentation_scheduler_plugin.gd   # domain invalidation and one flush
│   └── projection_registry.gd             # versioned operational projections
├── performance/
│   └── performance_monitor_plugin.gd      # non-authoritative samples/budgets
├── day_night/day_night_plugin.gd          # delegates one hourly boundary
├── city_stats/city_stats_plugin.gd        # resource intent contributor/reducer
├── economy/economy_plugin.gd              # economic contributor/commit adapter
├── community/
│   ├── community_plugin.gd                # contributor, migration context/cache
│   ├── community_inspector.gd             # explicit diagnostic projection
│   └── community_panel.gd                 # independently registered presenter
├── dashboard/dashboard_plugin.gd          # dirty presenter, bounded selectors
├── hud/hud_plugin.gd                      # dirty presenter, bounded selectors
├── people/people_plugin.gd                # maintained order and relevance sets
└── traffic/car_manager_plugin.gd          # stable origin queues/admission cursor

scripts/
├── simulation/
│   ├── hour_context.gd
│   ├── simulation_intent.gd
│   ├── transaction_ledger_entry.gd
│   └── authoritative_change_set.gd
├── presentation/
│   ├── invalidation_domains.gd
│   └── presenter_registration.gd
├── performance/
│   ├── performance_budget.gd
│   └── performance_sample.gd
├── builder.gd                              # building mutation change sets
├── plugin_manager.gd                       # coordinator plugin registration
├── run_performance_playthroughs.gd         # headless budgets
└── run_rendered_performance_profile.gd     # rendered frame budgets

test/
├── contract/
│   ├── simulation/
│   ├── presentation/
│   └── performance/
├── unit/
│   ├── simulation/
│   ├── presentation/
│   ├── performance/
│   ├── community/
│   ├── dashboard/
│   ├── people/
│   └── traffic/
└── integration/
    ├── performance/
    ├── simulation/
    └── presentation/
```

**Structure Decision**: Extend the existing plugin and test layout. Coordination lives in injectable plugins, immutable value contracts live under `scripts/`, and domain behavior remains in its current owner. No generic service locator or presenter-to-presenter references are introduced.

## Delivery Design

### Phase A — Evidence and Contracts

Freeze the current 135-building baseline and add contract fixtures before moving behavior. Introduce immutable transaction/change-set/performance value records, stable IDs, registries, and compatibility adapters. All new timing paths are opt-in and non-authoritative.

### Phase B — Hourly Transaction Spine

Add the SimulationTransaction plugin as DayNight’s one injected hourly transaction boundary; it does not depend back on DayNight. Move resource supply/demand and economy first to prove declarative dependencies. Then migrate community, demand, satisfaction, workplace, residential, commercial, patrons, and other hourly consumers incrementally. A reducer computes dependent results from intents; contributors do not call peers. DayNight and domain-owned compatibility adapters emit legacy signals only after commit until parity and replay gates pass.

### Phase C — Presentation Boundary

Add canonical invalidation domains and a scheduler that translates committed change sets into coalesced dirty presenter registrations. Migrate dashboard, community panel/overlay, HUD, and remaining UI independently. A visibility predicate prevents hidden projection work; version comparison provides catch-up. GameEvents adapters feed equivalent change sets for non-hourly commands during migration.

### Phase D — Projections and Building Mutations

Define small named operational projections for each visible consumer and retain CommunityInspector/Playtest full snapshots only as explicit diagnostics. Make Builder produce a mutation change set after atomic place/replace/demolish. Use affected entity/domain keys to update road, occupancy, programme, attractiveness, operation, and presentation indexes incrementally.

Community follows the explicit boundary contract in
`contracts/community-runtime-boundaries.md`: authored dictionaries compile into
a disposable typed runtime index, operational evaluation returns domain values,
and `CommunityInspector` alone materializes bounded presentation explanations.
The index is owned by Community, revision-keyed, absent from saves, and never
read by a presenter.

### Phase E — Domain Hot Loops

Cache immutable migration batch contexts by explicit dependency revisions. Replace CarManager’s repeated origin discovery, sorting, and pending-array duplication with stable per-origin FIFO queues plus a deterministic origin cursor. Maintain People’s resident order on insert/remove, process only active/relevant sets, and keep diagnostic sorting outside the normal frame.

### Phase F — Budgets and Rollout

Attribute main-thread time at every named boundary, enforce headless and rendered budgets, disable hot-path debug output by default, and run focused contracts, full GUT, deterministic replay, full-city scenarios, and three-run benchmarks. Remove an adapter only when its consumers have migrated and parity evidence is green.

## Dependency and Rollout Order

```text
Evidence/contracts
    └── Hourly transaction spine
          ├── Presentation boundary
          │     └── Operational projections + building mutation change sets
          └── Migration cache
Presentation boundary + projection contracts
    └── People/traffic/render relevance work
All stories
    └── Final budget enforcement and adapter removal
```

The P1 transaction story is the architectural MVP. P2 can begin once change-set contracts are stable. P3 and P4 can then proceed in parallel by domain, but adapter removal and final performance claims wait for the combined parity gate.

## Test Seams

- **Contract**: record validation, stable ordering, reducer conflict rules, change-set immutability, Community authority/runtime/view boundaries, invalidation coalescing, visibility catch-up, evidence schema.
- **Unit**: coordinator state machine, reducers, projection cache versions, migration dependency revisions, stable traffic queues, maintained people order, budget statistics.
- **Integration**: real plugin registration and injection, DayNight single transaction, GameState atomic commit, Builder change sets, independent dashboard/community/HUD presentation.
- **Deterministic replay**: same seed and reversed contributor registration order produce identical state hashes, ledgers, traffic/migration decisions, and snapshots.
- **Scenario**: canonical 240-hour city plus placement and migration boundaries, using Builder/Playtest only.
- **Rendered**: representative town with UI, people, and cars, reporting frame process/render attribution and percentile budgets.

## Complexity Tracking

No constitution violations require exceptions.
