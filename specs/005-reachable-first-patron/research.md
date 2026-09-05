# Phase 0 Research: Reachable First-Patron Progression

## Decision 1: Retain UniqueRegistry as story-building gate authority

**Decision**: Remove the unused `CharacterSystem -> UniqueRegistry` and
`PatronSystem -> UniqueRegistry` dependency edges. Make UniqueRegistry depend on
CharacterSystem and PatronSystem, then include `want_not_revealed` and
`patron_not_ready` in its existing `evaluate_unlock()` decision.

**Rationale**: Builder, Palette, and Playtest already use UniqueRegistry for
unique availability. Extending that choke point makes their decisions converge
without adding a second rules service or coupling progression directly into
Builder.

**Alternatives considered**:

- A new Progression plugin would duplicate much of UniqueRegistry's role and
  create another decision that consumers could apply inconsistently.
- Letting each UI and command layer inspect CharacterSystem/PatronSystem would
  preserve the current parity problem.

## Decision 2: Derive attained tier from placed catalog evidence

**Decision**: BuildingCatalog exposes a pure bucket-tier projection by scanning
the canonical `GameState.building_registry`. Pool buildings use their pool's
authored bucket/tier; unique chain buildings use `UniqueProfile.bucket/tier`.

**Rationale**: Tier is authored catalog metadata over canonical placed state.
It is derived, cheap at current city scale, and must not become a separately
persisted counter that can drift after demolition or load.

**Alternatives considered**:

- Inferring tier from fulfilled demand conflates two independent gates.
- Persisting attained tier introduces reconciliation and migration work with no
  additional information.

## Decision 3: Share one semantic arrival-resolution transition

**Decision**: Dialogue owns one semantic resolver for an authored pending event.
Visible option buttons and a debug-only Playtest action both traverse that same
event/effect path; CharacterSystem advances ARRIVED only when the arrival event
successfully closes.

**Rationale**: Narrative-disabled automation otherwise strands every character
at ARRIVED. A shared command exercises the real state rule while keeping
unfinished presentation out of core simulation tests.

**Alternatives considered**:

- Auto-revealing every arrival changes normal player ordering.
- A Playtest-only `set_character_state` command violates One Gameplay Truth.

## Decision 4: Re-present unresolved arrival dialogue after load

**Decision**: Persist an ordered, idempotent `pending_dialogue_event_ids` list in
DataMap. EventSystem records the ID before presentation, Inbox projects the
persisted queue, and successful visible or headless resolution removes it.
Legacy ARRIVED saves with no pending ID reconstruct the matching arrival event
without incrementing its lifetime event count.

**Rationale**: Inbox pending records are currently transient while event counts
are incremented on delivery. Persisting ARRIVED but losing the queue otherwise
creates a permanent dead end.

**Alternatives considered**:

- Persisting complete event records duplicates authored data; stable event IDs
  are the smallest durable representation.
- Resetting the event count duplicates historical event accounting.

## Decision 5: Make land donation an acknowledged patron operation

**Decision**: BuildableArea exposes idempotent
`apply_donation(patron_id, area) -> newly_added_cells`. PatronSystem calls it
synchronously during completion and records `patron_donations_applied` in
DataMap. Completed legacy states missing a receipt are repaired without
re-emitting patron completion.

**Rationale**: The current downstream signal cascade cannot prove that state,
character promotion, donation, and completion publication represent one
authoritative transition. A receipt makes repeated load and overlapping cells
explicit and testable.

**Alternatives considered**:

- Relying only on allowed-cell set deduplication cannot distinguish a completed
  donation from a never-applied one.
- Persisting added-cell lists per event is unnecessary; patron ID plus canonical
  authored area is sufficient.

## Decision 6: Apply the smallest trace-backed reachability corrections

**Decision**: Change `aristocrat_industrial.arrival_threshold` from 10,000 to
100 and regenerate the editor manifest entry. During full-stack replay, also
lower Community's neutral migration threshold from 60 to its authored quality
baseline of 50, raise the daily candidate batch from 4 to 20, and raise the
commercial-output ratio from 0.5 to 0.75. These are provisional reachability
values for milestone 005, not the final pacing balance owned by milestone 006.

**Rationale**: Before the first donation, the starter plot has 64 cells. The
industrial chain supplies 63 fulfilled demand and the remaining 61 cells can
add at most 305 via tier-one garages, for a hard maximum of 368. A threshold of
10,000 is therefore impossible. A value of 100 matches the other two characters
and is naturally crossed by any route capable of producing the commercial
demand required by the Members' Club.

The first real replay then exposed two additional finite-route failures that the
static cap calculation could not show. Neutral homes evaluate to the authored
quality baseline of 50, so a migration threshold of 60 admitted almost nobody;
even once eligible, a four-resident daily batch stretched an otherwise legal
route to roughly eighty in-game days. Finally, the legal industrial footprint
produced 264 worker output: at ratio 0.5 that yielded 158.4 commercial demand,
only 28.4 unserved after the chain spend, below the Members' Club requirement of
60. Ratio 0.75 yields 198 total and 68 unserved, clearing the existing authored
gate without changing that gate or adding cells.

**Alternatives considered**:

- Lowering story-building demand costs would rewrite the authored quest chain
  rather than repair the simulation inputs feeding it.
- Increasing starting land or injecting residents/demand in the scenario would
  bypass normal gameplay and violate the unchanged fresh-town contract.
- Setting migration threshold below 50 or raising the batch above 20 would be a
  broader pacing choice without reachability evidence.

## Decision 7: Use real semantic replay and Resource boundaries

**Decision**: Add a versioned, action-bearing `first_patron_reachable` scenario
run through Playtest and use actual `ResourceSaver`/`ResourceLoader` fixtures
for progression boundaries.

**Rationale**: Existing replay tests use a fake plugin and existing persistence
tests swap DataMap in memory. Neither observes runtime signal order, resource
cache behavior, pending-arrival replay, or donation duplication.

**Alternatives considered**:

- Direct fixture mutation would prove only test setup.
- A bespoke scenario script outside Playtest would create a second command path.

## Decision 8: Expand the deterministic hash and milestone trace

**Decision**: The playtest snapshot/hash includes bucket tier evidence,
character states/gates, patron state, donation receipts, flags, event counts,
and gate decisions. The trace records ordered first-occurrence milestone records
with action sequence, simulation time, relevant evidence, and a normalized
state hash.

**Rationale**: The current progression snapshot includes only unique
unlocked/placed IDs, allowing materially different story states to hash equally.

**Alternatives considered**:

- Comparing only the final building set misses event, state, and donation drift.

## Decision 9: Persist accrued demand totals narrowly

**Decision**: Add `demand_totals` to DataMap and keep it synchronized by Demand.
On map load, totals restore before fulfilled capacity is rebuilt from placed
structures. Versioned envelopes, slots, autosaves, and lifecycle UX remain in
milestone 007.

**Rationale**: Unique thresholds use unserved demand (`total - fulfilled`). A
cold load that resets totals to the starting grant can change which chain item
is legal even when every visible building and progression state is identical.

**Alternatives considered**:

- Same-process in-memory load tests mask the defect because live totals survive.
- Deferring all demand persistence to milestone 007 makes milestone 005's
  progression-boundary acceptance tests false confidence.

## Verified baseline

- Godot 4.6.2 recursive unit suite: 256/256 tests, 1,618 assertions.
- Player UI integration suite: 5/5 tests, 19 assertions.
- Data editor: 56/56 tests plus successful TypeScript/Vite build.
- Server source suite: 15 passed, 13 opt-in skipped.
- Existing headless radial scenario completes four actions but does not exercise
  character dialogue, patron completion, save/load, or land donation.

Exact commands and expected evidence are recorded in [quickstart.md](quickstart.md).
