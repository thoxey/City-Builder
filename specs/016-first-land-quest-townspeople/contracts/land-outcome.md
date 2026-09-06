# Contract: First Land Quest Outcome

## Entry point

BuildableArea exposes:

```text
apply_land_grant(grant_id: String, area: Dictionary) -> Dictionary
```

It is the only entry point used by FirstLandQuest. Quest/dialogue code must never edit
`DataMap.allowed_cells`.

## Validation

Reject without mutation or receipt when:

- `grant_id` is empty;
- map state is unavailable;
- area is missing/malformed;
- a rectangle has non-positive width/height;
- a polygon has no valid cells;
- any coordinate cannot be represented by the existing land payload parser; or
- the requested cell count exceeds the declared safe content bound.

Stable reasons include `grant_id_missing`, `map_unavailable`, `grant_area_missing`,
`grant_area_invalid`, and `grant_area_too_large`.

## Idempotent application

If `land_grants_applied[grant_id].applied` is already true, return `already_applied`
without calling `_expand()` or emitting `buildable_area_expanded`.

For a valid first application:

1. Parse the entire requested cell set.
2. Canonically sort/deduplicate it.
3. Calculate existing overlaps.
4. Expand through BuildableArea's shared `_expand()` path.
5. Write a receipt even when every requested cell was already buildable.
6. Return detached requested, added, and overlap counts plus sorted added cells.

```text
{
  applied: true,
  already_applied: false,
  grant_id: String,
  requested_cell_count: int,
  added_cell_count: int,
  overlapping_cell_count: int,
  added_cells: Array<Coordinate>,
  total_cells: int,
  reason: ""
}
```

## Separation from patron donation

`land_grants_applied["first_land_quest_parcel"]` and
`patron_donations_applied["aristocrat"]` are independent. Applying either does not mark,
suppress, resize, or complete the other. If their authored shapes overlap, each keeps a
receipt and reports only cells newly added at its own application time.

## Outcome timing

The recommended outcome is eligible only after:

- one valid approach flag is committed;
- `first_land_quest_agreed` is committed in the common terminal node; and
- the negotiation event is no longer pending.

FirstLandQuest writes its own outcome/completion receipts only after BuildableArea
returns applied/already-applied evidence. A rejected grant leaves the quest in `AGREED`
with a stable diagnostic and is safe to retry after content repair.

## Determinism

Grant geometry is authored, not random. Cell parsing, deduplication, and output ordering
are stable. Equivalent visible/headless paths produce the same allowed-cell set and
normalized receipt regardless of renderer timing.
