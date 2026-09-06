# Contract: Road Route Cache

## Authority

`RoadNetwork.get_route_between_buildings(origin_id, destination_id)` remains the single canonical building route resolver. Caching is transparent to callers.

## Cache lifetime

- Entries are valid only for the current road-network topology revision.
- Place, demolish, replace, map load and clear flow through `_rebuild()` and clear route and building-anchor caches.
- Both successful and failed deterministic route results may be cached.

## Copy safety

- Stored results are detached from the resolver's working values.
- Every returned cached result is deeply duplicated.
- Mutating a prior returned path, endpoint, cell or error payload cannot affect a later query.

## Diagnostics

The network exposes non-authoritative counts for cache hits, misses and current entries. These counters MAY be used by tests and performance reports and MUST NOT enter snapshots, saves or hashes.

## Behavioral invariants

- Route status, reason, distance, endpoints, access modes and stable shortest path are identical with or without a warm cache.
- Origin/destination order is significant.
- Missing buildings, missing access, disconnected components and same-stop routes remain distinguishable.
