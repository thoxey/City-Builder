# Contract: Community Runtime and Presentation Boundaries

This contract narrows the transactional-performance design for Community. It
preserves the authority established by `002-community-happiness-simulation` and
the pure presentation boundary established by `003-community-ui` while allowing
the hourly evaluator to use compact, derived runtime data.

## Ownership

| Layer | Owner | Representation | May mutate gameplay? |
|---|---|---|---|
| Authored balance/content | Building catalog and Community data files | Validated JSON and Resources; stable string IDs are allowed | No |
| Shared city authority | `GameState` and Builder-owned structures | Placed structures, cells, and registry records | Only through canonical commands/commit |
| Community domain authority | `Community` plugin | `CommunityResident` state, assignments, RNG state, migration state | Only during an authoritative Community commit |
| Save representation | `DataMap` | Backward-compatible JSON-safe records | Only as the persistence projection of a load or committed mutation |
| Compiled runtime index | `Community`-owned runtime helper | Typed numeric IDs, packed arrays, bitmasks, spatial spans, and revision keys | No; fully rebuildable |
| Operational projection | Named projection producer | Small detached read model for one consumer | No |
| Diagnostic projection | `CommunityInspector` or explicit playtest inspection | Detached, bounded explanatory records | No |
| View model and Controls | `CommunityInspector` and Community UI presenters | Detached dictionaries/arrays and UI state | No |

`Community` remains the live authority for residents. `DataMap` is its durable
serialization boundary, not a second independently mutable resident model. A
compiled index is a disposable acceleration structure and MUST NOT become an
authority merely because it is faster to query.

## Dependency direction

```text
authored data --------> runtime compiler --------> compiled runtime index
      |                                                |
      v                                                v
Community domain authority <---- pure evaluation / transaction intents
      |
      +----> DataMap persistence projection
      |
      +----> committed change set ----> operational projection ----> presenter
      |
      +----> explicit snapshot --------> diagnostic projection ----> presenter/test
```

Dependencies point to the right or back into the single domain commit. The UI
MUST NOT read the compiled index, calculate happiness, or write `Community`,
`GameState`, or `DataMap`. The runtime compiler and evaluator MUST NOT reference
Controls, presenter state, player-facing labels, or persistence APIs.

## Compilation boundary

1. Stable authored string IDs are validated and translated once into finite
   numeric IDs at load, programme change, or another declared dependency
   revision.
2. The compiled representation may contain global channels, spatial influence
   spans, direct resident/participant links, schedule bitmasks, and canonical
   integer stacking keys.
3. Each compiled artifact records the exact topology, structures, programme,
   occupancy, schedule, balance, and time revisions on which it depends.
4. A mismatch makes the artifact unusable. Rebuild or selective invalidation is
   deterministic; wall-clock TTL and opportunistic stale reads are forbidden.
5. Compiled artifacts are absent from saves, canonical hashes, public snapshots,
   balance decisions other than as an equivalent acceleration of the canonical
   rules, and presentation models.

## Evaluation boundary

- The normal hourly path consumes `CommunityResident` domain inputs and a
  revision-matched compiled runtime view.
- Its operational result contains numeric quality totals and the smallest stable
  provenance required for an authoritative update. It does not allocate
  player-facing effect dictionaries.
- Stacking order, schedule boundaries, scopes, rounding, personality weights,
  sensitivity, migration decisions, and deterministic tie-breaks remain exactly
  equivalent to the canonical evaluator.
- Rich `AppliedEffect` display records are materialized only by an explicit,
  bounded explanation projection. Any explanation data retained for save
  compatibility is a domain record, not a UI model, and contains no labels or
  Control state.
- A missing, stale, or invalid compiled view fails closed to a deterministic
  rebuild or the canonical evaluator; it never silently changes an outcome.

## Presentation boundary

- Presenters consume named operational or diagnostic projections, never live
  resident objects or the compiled index.
- Projection payloads are detached. Mutating a returned payload cannot mutate
  Community, `GameState`, `DataMap`, another projection, or a future result.
- Routine HUD and overview refreshes do not request full resident/effect data.
- Resident/place explanations are explicit diagnostic requests and remain
  bounded by the existing Community UI limits.
- UI commands continue through semantic domain APIs such as
  `Community.set_programme`; visual state changes only after the authoritative
  change is committed.

## Required gates

1. Canonical and compiled evaluators produce identical ordered results and
   four-decimal totals for all existing Community fixtures.
2. Identical seeds and actions produce identical resident state, migration
   decisions, persistence records, and hashes with the compiled path enabled or
   disabled.
3. Rebuilding the runtime index at any valid revision produces the same result
   as incrementally maintaining it.
4. Cache/index records are absent from saves and canonical hashes.
5. Mutation tests prove that operational and diagnostic projections are
   detached from their sources and from each other.
6. UI tests prove that no presenter calculates Community outcomes or writes
   Community, `GameState`, or `DataMap` fields.
7. Instrumentation reports compilation/invalidation, operational evaluation,
   diagnostics, persistence projection, and presentation as separate boundaries.
