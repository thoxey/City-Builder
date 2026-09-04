# Contract: Community UI View Model

## Producer

`CommunityInspector.project(snapshot, catalog_context, clock_context,
display_config, previous_projection = {}) -> Dictionary`

The producer is pure: it does not mutate inputs, read wall-clock time, emit
signals, or change gameplay state.

## Required output

The returned dictionary conforms to `CommunityUIModel` in `data-model.md` and:

1. includes exactly four quality records in canonical order;
2. preserves every displayed AppliedEffect as a distinct row;
3. marks fields unavailable from canonical data as unavailable/unknown rather
   than fabricating a value;
4. resolves player-facing names through authored catalog/cohort data with stable
   fallbacks;
5. excludes raw seeds and internal IDs from default presentation records;
6. uses stable ordering independent of Dictionary insertion order;
7. bounds resident and effect collections to configured limits;
8. returns no mutable reference owned by Community or GameState.

## Refresh contract

- A new projection is requested after Community population/quality,
  programme, structure placement/demolition, map load, and exact-hour events.
- Multiple signals in one simulation transition are coalesced into one deferred
  refresh.
- Controls update existing rows where identities remain stable.
- A missing selected resident/building produces a stale-selection state and
  returns to the nearest valid parent view.

## Programme command contract

`request_programme_change(anchor, programme_id)` validates the selection against
the projected options and delegates to `Community.set_programme`.

- Success is displayed only after `community_programme_changed`.
- Failure retains the previous visible programme and shows a concise reason.
- No UI path writes `DataMap.community_programmes` directly.

## Selection contract

- Inspect mode is explicit and visibly active.
- A consumed inspection click never also places, replaces, or demolishes.
- Leaving inspect mode restores normal Builder input.
- Demolishing the selected building clears place selection on the canonical
  demolition event.

## Accessibility contract

- Every actionable control is reachable by keyboard/gamepad in a deterministic
  focus order.
- Escape moves detail → section → closed panel, one level at a time.
- Every color-coded value has text, sign, icon, or pattern redundancy.
- Scroll containers keep focused controls visible.
- Required content remains available at 1280×720 without two-dimensional
  scrolling.

## Performance contract

- No full projection or resident Control rebuild occurs in `_process`.
- At 500 residents, aggregate projection meets the 16.7 ms target on the
  development machine.
- Visible resident Controls are bounded by the chosen page/window size.
- Notification history and previous-projection storage are bounded.

