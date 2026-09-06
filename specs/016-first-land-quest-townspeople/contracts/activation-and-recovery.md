# Contract: First Land Quest Activation and Recovery

## Ownership

- OpeningTutorial owns the prerequisite completion receipt and live edge signal.
- FirstLandQuest owns only its versioned phase/receipts and reconciliation.
- EventSystem owns event records, fire counts, pending IDs, flags, and effect execution.
- Dialogue owns visible/headless graph traversal and emits a detached completion edge.
- BuildableArea owns grant validation, cell expansion, and land receipts.

## Activation source of truth

Activation is eligible only when:

```text
DataMap.opening_tutorial_state.completion_handoff = {
  receipt_id: "tutorial_opening_completed",
  applied: true
}
```

The transient `GameEvents.tutorial_opening_completed` signal requests immediate
reconciliation but cannot substitute for the receipt. Tutorial B18 pending/
acknowledgement state is ignored.

## Exactly-once activation order

1. Normalize quest state.
2. Confirm the durable tutorial receipt.
3. If quest completion exists, return `COMPLETED`.
4. If an approved quest event is pending, project `PENDING` without firing.
5. If activation receipt exists or the event's life-of-save count is non-zero, recover
   from pending/flags/receipts without firing.
6. Otherwise write `first_land_quest.activated` and phase `AVAILABLE`.
7. Persist/synchronize state.
8. Call EventSystem `fire(invitation_event_id)` once.
9. Confirm the pending ID and project `PENDING`, or diagnose `dispatch_failed` while
   retaining the activation receipt.

Writing before the callback makes re-entrant signal handling idempotent.

## Dialogue completion edge

After `_complete_semantics()` has acknowledged a dialogue, Dialogue emits:

```text
dialogue_completed({
  event_id: String,
  visited_node_ids: Array<String>,
  ordered_effects: Array<Dictionary>,
  acknowledged: true
})
```

The payload is detached. The signal is observational: listeners may reconcile their own
state but cannot alter Dialogue's completed session or retroactively change effects.

## Recovery matrix

| Durable evidence | Pending? | Reconciled behavior |
|---|---:|---|
| no tutorial receipt | any | `LOCKED`; never dispatch |
| tutorial receipt; no activation/count | no | write activation, dispatch once |
| activation/count | yes | `PENDING`; EventSystem redispatch owns presentation |
| approach flag | yes | retain selected approach; pending branch restarts safely |
| agreement flag | yes | `AGREED`; do not grant until negotiation is acknowledged |
| agreement flag | no | apply/reconcile approved outcome exactly once |
| grant receipt | no | write/repair outcome and completion receipts |
| completion receipt | no | `COMPLETED`; never replay |

Contradictory multiple approach flags produce `multiple_approach_flags`; missing event
after activation produces `activated_event_missing`; event count without activation
repairs the activation receipt rather than firing again.

## Save/load

Quest state, EventSystem counts/flags/pending IDs, and land receipts persist. Transcript,
beat cursor, portrait, and reveal state do not. Loading a pending scene restarts it via
EventSystem's existing redispatch behavior. Loading an agreed/acknowledged scene resumes
outcome application without dialogue replay.

## Headless parity

Headless resolution chooses the first approved option as it does for all dialogue. The
scenario declares that option's approach ID. After Dialogue acknowledges the event, the
same quest reconciliation applies the same common outcome and receipts as visible play.
