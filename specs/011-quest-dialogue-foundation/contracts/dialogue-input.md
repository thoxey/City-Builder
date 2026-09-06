# Contract: Dialogue Input and Reveal

## Shared advance command

All accepted advance inputs call one DialoguePlugin command, conceptually:

```text
advance_dialogue() -> {
  accepted: bool,
  transition: "reveal_completed" | "beat_started" | "conversation_completed" | "ignored",
  event_id: String,
  node_id: String,
  beat_index: int,
  mode: String
}
```

The return value is an internal/test projection, not a new public playtest operation.

| Current mode | Condition | Result |
|---|---|---|
| `REVEALING` | Any beat | Fill current row; become `READY` |
| `READY` | More beats | Append/start exactly one beat; become `REVEALING` |
| `READY` | Final beat, choices exist | Show choices; become `CHOOSING` |
| `READY` | Final beat, terminal node | Commit/complete; become `DONE` |
| `CHOOSING` | Any ordinary advance | Ignore |
| `DONE` | Any input | Ignore |

Natural reveal completion changes only `REVEALING -> READY`.

## Input sources

- Left mouse press or touch press on non-interactive dialogue surface.
- Space.
- Enter.
- `dialogue_advance` input action, mapped to controller confirm.

Each physical event is accepted once, marked handled, and may produce at most one table
transition. Echo/repeat key events are ignored.

## Control precedence

The following controls stop event propagation and do not call ordinary advance:

- dialogue choice buttons;
- vertical scrollbar interactions;
- return-to-latest affordance;
- any future explicitly interactive control within the frame.

Speech bubbles, narrative text, empty transcript space, frame decoration, and the small
portrait overlap remain part of the surface target. There is no Continue/Finish-line
button.

## Reveal timing

- Rate is expressed as characters per second.
- The current row exists at final width before its first character is visible.
- Punctuation delays are presentation-only and deterministic.
- Test/instant mode displays the full beat immediately and enters `READY`.
- A reveal timer never applies effects, navigates, chooses, or closes.
