# Contract: Authoritative Change Set and Projection

## Publication

Every successful authoritative mutation publishes exactly one immutable AuthoritativeChangeSet after StateVersion increments. Covered sources are hourly transactions, building place/replace/demolish, map load, and map clear.

Required fields:

- `change_id`, `source_kind`, and `source_id`
- `pre_state_version` and `post_state_version`
- canonically ordered `domains`
- sorted affected `entity_keys` per domain
- bounded aggregate `deltas`
- resulting `dependency_revisions`

A failed command publishes no committed change set.

## Domain Mapping

Each source declares its possible domains. A mapping test fails when:

- a mutation changes gameplay data without listing its domain;
- a listed domain has no actual or explicitly conservative dependency;
- an unknown free-form domain is published;
- affected identities are unordered or unstable.

## Projection Registration

`register_projection(projection_id, dependency_domains, projector) -> Result`

`get_projection(projection_id, state_version = current) -> DetachedPayload`

- Projection IDs are unique and named for one consumer/use case.
- Dependencies are explicit and finite.
- Cached results are reusable only while all dependency revisions match.
- Returned mutable containers are detached from cache storage.
- Operational projectors must not call diagnostic projectors.
- Diagnostic projections use a separate explicit API and timing boundary.

## Building Mutation Rules

- Builder completes existing validation before mutation.
- Apply and index updates share one expected pre-version.
- Place, replace, demolish, load, and clear identify affected cells, structure IDs, programmes, occupancy, topology, and presentation domains.
- A failure leaves authoritative and derived versions unchanged.
- During migration, GameEvents compatibility signals are emitted from the committed change set, not from intermediate mutation steps.
