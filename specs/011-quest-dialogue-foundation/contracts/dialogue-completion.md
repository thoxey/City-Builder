# Contract: Dialogue Commit and Completion

## Ownership

- EventSystem owns authored records, event conditions, pending IDs, and effect execution.
- Inbox owns the visible queue projection and opens a selected pending record.
- DialoguePlugin owns normalized traversal and presentation only.
- CharacterSystem and PatronSystem own progression state.
- Playtest uses DialoguePlugin's headless resolver; no second narrative path is added.

## Node commit

A visible node commits exactly once:

```text
choice node:
  append selected option as player row
  apply node.on_enter effects
  apply selected option.effects
  enter option.next OR complete

terminal node:
  final beat is READY
  player activates surface/confirm
  apply node.on_enter effects
  complete
```

Merely opening an event, entering a node, starting a beat, completing text reveal,
scrolling, or closing the application does not commit node effects.

## Event completion

Completion preserves the existing semantic order within one handled input:

1. Commit the final node's deferred effects.
2. Perform the existing event-specific progression transition, including arrival to
   want-revealed where applicable.
3. Acknowledge the EventSystem pending ID.
4. Clear transient DialogueSession state and hide presentation.

Repeated completion calls after `DONE` are ignored. An already acknowledged event is
rejected by the headless resolver as not pending.

## Interruption and reload

Before commit, the pending ID remains in `DataMap.pending_dialogue_event_ids`. Map load
rebuilds the Inbox projection from EventSystem. Reopening begins the current event from
its entry node with an empty transient transcript; no effects have been applied by the
discarded presentation.

This milestone does not persist mid-conversation beat, text, portrait, transcript,
scroll, or node cursors.

## Headless parity

Headless resolution:

- normalizes the same authored record;
- starts from the same entry node;
- selects the first valid option at each choice node;
- commits each node's entry effects followed by that option's effects;
- uses the same 128-node bound;
- performs the same final semantic progression and acknowledgement;
- never builds, reveals, or depends on UI/portrait resources.

The normalized visible and headless outcome projection must match on ordered effects,
visited node IDs, final progression state, and pending acknowledgement.
