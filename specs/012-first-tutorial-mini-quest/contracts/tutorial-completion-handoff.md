# Contract: Opening Tutorial Completion Handoff

## Durable fact

The terminal record is persisted inside `DataMap.opening_tutorial_state`:

```text
completion_handoff: {
  receipt_id: "tutorial_opening_completed"
  applied: true
  shop: <detached BuildingEvidence>
}
```

`applied` is false/missing until every prior step receipt exists and a qualifying
tier-one commercial building has a rooted route from the Town Hall.

## Edge signal

After writing the receipt and terminal state, emit exactly once for that save:

```text
GameEvents.tutorial_opening_completed({
  "tutorial_id": "opening_tutorial",
  "receipt_id": "tutorial_opening_completed",
  "shop_building_id": String,
  "shop_anchor": {"x": int, "z": int}
})
```

The payload is detached, JSON-safe, and contains no Workstream 2 state, dialogue, land
grant, or effect command.

## Atomic order

Within one reconciliation call:

1. Write `opening.first_shop_placed` if absent.
2. Set `current_step_id = "complete"`.
3. Write `completion_handoff.applied = true` with shop evidence.
4. Publish the complete tutorial projection.
5. Emit `tutorial_opening_completed` once.
6. Dispatch the B18 approved placeholder dialogue through EventSystem if its separate
   presentation receipt is absent.

The persistent write precedes callbacks. Re-entrant reconciliation therefore observes
completion and cannot emit again.

## Consumer obligations

Workstream 2 must treat the durable receipt as the source of truth:

- reconcile it on boot/map load;
- listen to the signal for immediate same-session activation;
- make its own activation idempotent; and
- never require B18 acknowledgement or inspect tutorial UI state.

This workstream does not create, start, or author Sir William's land quest.

## Reload and duplication behavior

- Loading a completed save publishes complete state but does not re-emit the edge signal.
- Duplicate shop/road/map signals do not change the handoff.
- Demolishing the qualifying shop after completion does not revoke the receipt.
- If B18 is still pending at save time, EventSystem restores that pending dialogue by
  its existing contract without re-emitting the gameplay handoff.
- Visible and headless runs write identical completion state for identical actions.

## Verification contract

Focused tests must prove:

- receipt-before-signal ordering under a re-entrant listener;
- exactly one signal for duplicate invalidations and multiple qualifying shops;
- zero signals when loading an already completed save;
- persistent shop evidence survives cold ResourceSaver/ResourceLoader round-trip;
- demolition after completion does not regress or re-emit;
- B18 pending/acknowledgement is independent from the durable gameplay fact; and
- a future Workstream 2 stub reaches the same activation from either map-load receipt
  reconciliation or the live signal, exactly once.
