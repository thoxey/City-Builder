# Data Model: Quest Dialogue Foundation

Authored events and character definitions remain JSON dictionaries loaded by existing
systems. Dialogue session and portrait state are transient and excluded from saves and
gameplay hashes.

## DialogueEvent

Existing event envelope with `event_type: "dialogue"`.

| Field | Meaning | Validation |
|---|---|---|
| `event_id` | Stable pending/event identity | Non-empty and unique through EventSystem |
| `trigger` | Existing event trigger metadata | Unchanged |
| `payload.participants` | Allowed semantic speaker IDs | Two or three unique IDs; contains `player` |
| `payload.entry_node_id` | First dialogue node | Resolves to exactly one node |
| `payload.nodes` | Branch graph | Non-empty unique `node_id` values |

The trigger character is not implicitly the only NPC. Participants are explicit because
a three-way scene may contain two NPC character IDs.

## DialogueNode

| Field | Meaning | Validation |
|---|---|---|
| `node_id` | Stable node identity in one event | Non-empty and unique |
| `beats` | Ordered presentation content | Array of valid speech/narration beats |
| `body` | Temporary legacy content | Used only when `beats` is absent |
| `on_enter` | Effects committed with the node decision | Existing effect dictionaries; not applied on visual entry |
| `options` | Player replies and destinations | Array; zero means terminal node |

Normalization rules:

1. If `beats` exists, validate and preserve its authored order.
2. Else if `body` is non-empty, produce one narration beat with that text.
3. Else produce a stable `empty_dialogue_node` validation error.
4. Every non-empty option `next` resolves to a node in the same event.
5. Visible and headless traversal stop with `dialogue_cycle_limit` after 128 committed
   nodes rather than looping indefinitely.

## DialogueBeat

Tagged union normalized to one of:

```text
SpeechBeat {
  type: "speech"
  speaker: "player" | <participant character_id>
  expression: <semantic expression name>
  text: <non-empty display text>
}

NarrationBeat {
  type: "narration"
  text: <non-empty display text>
}
```

Speech side is derived, never authored: `player` maps left; every other participant maps
right. Narration has no side or active speaker.

## DialogueOption

| Field | Meaning | Validation |
|---|---|---|
| `label` | Player's displayed and transcript reply | Non-empty string |
| `next` | Destination node, or empty to complete | Resolves when non-empty |
| `effects` | Existing authored effects | Array of effect dictionaries |

Selecting an option creates one transcript speech row with semantic speaker `player`.
The option is the commit boundary for the current node.

## ExpressionSet

Fields added to a character definition:

```text
default_expression: <semantic name>
expressions: {
  <semantic name>: <res:// texture path>
}
```

Resolution order:

1. Authored beat expression if declared and loadable.
2. Character `default_expression` if declared and loadable.
3. Character legacy `portrait` if loadable.
4. Deliberately illustrated missing-art texture.

Stable diagnostics distinguish `unknown_dialogue_speaker`, `unknown_expression`,
`missing_default_expression`, `missing_portrait_resource`, `missing_dialogue_node`, and
`dialogue_cycle_limit`.

The reserved `player` semantic identity resolves to the configured presentation
character `ambrose` for this milestone. Dialogue data never names Ambrose for player
speech.

## DialogueSession

Transient state owned by DialoguePlugin:

| Field | Meaning | Validation |
|---|---|---|
| `event_id` | Current pending event | Still pending until completion |
| `normalized_event` | Detached validated graph | Never mutates EventSystem record |
| `node_id` | Current node | Present in normalized graph |
| `beat_index` | Current beat cursor | `-1` before first beat; bounded by beat count |
| `mode` | Reveal/input mode | `REVEALING`, `READY`, `CHOOSING`, or `DONE` |
| `revealed_characters` | Visible prefix length | Zero through text length |
| `transcript_rows` | Append-only presentation rows | Authored/selected order |
| `player_expression` | Latest resolved player expression | Retained while inactive |
| `counterpart_id` | Current/latest right-slot NPC | Participant or empty before first NPC |
| `counterpart_expression` | Latest right-slot expression | Belongs to counterpart ID |
| `follow_latest` | Whether transcript tracks bottom | False after intentional upward scroll |
| `node_committed` | Guards node effects/navigation | False until choice or terminal completion |

```text
open node -> append first beat -> REVEALING
REVEALING --advance--> READY
READY --advance, more beats--> REVEALING
READY --final beat + options--> CHOOSING
CHOOSING --select option--> commit -> next node / DONE
READY --final terminal advance--> commit -> DONE
```

Natural timer completion also moves `REVEALING -> READY`. It never advances a beat.

## PortraitSlotState

Two transient records:

```text
PlayerSlot {
  semantic_id: "player"
  presentation_character_id: "ambrose"
  expression
  active
}

CounterpartSlot {
  character_id
  expression
  active
}
```

NPC speech replaces the complete counterpart record before reveal. Player speech leaves
the counterpart unchanged and inactive. Narration leaves both records unchanged and
inactive.

## TranscriptRow

Append-only UI model:

| Field | Meaning |
|---|---|
| `kind` | `speech` or `narration` |
| `speaker` | Semantic speaker for speech; empty for narration |
| `display_name` | Resolved name retained after portrait swaps |
| `side` | Derived `left`, `right`, or `none` |
| `full_text` | Immutable authored/choice text |
| `visible_characters` | Reveal prefix length for current row |

Past rows are never rebuilt when a new beat is appended.

## Commit and Interruption Semantics

A node has exactly one commit boundary:

- choice node: accepted option selection;
- terminal node: surface/confirm activation after its final beat is ready.

At commit, DialoguePlugin asks EventSystem to apply deferred node effects followed by
selected-option effects. It then navigates or, when terminal, performs existing semantic
completion and pending acknowledgement. Before commit, closing the application or
loading another map may discard DialogueSession without changing the pending ID or
applying node effects. On reload, Inbox reconstructs the available item from EventSystem
and the presentation restarts safely.

## Persistence

No new saved fields are added. Existing `DataMap.pending_dialogue_event_ids` remains the
durable recovery record. Expression, transcript, scroll, reveal, participant slot, and
cursor state are reconstructed each time a pending conversation is opened.
