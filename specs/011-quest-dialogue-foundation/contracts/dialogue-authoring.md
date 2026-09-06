# Contract: Dialogue Authoring

## Event payload

```json
{
  "event_id": "aristocrat_residential_arrival",
  "event_type": "dialogue",
  "trigger": {
    "event": "character_arrived",
    "character_id": "aristocrat_residential"
  },
  "enabled_if": "",
  "payload": {
    "participants": [
      "player",
      "aristocrat_residential",
      "aristocrat_commercial"
    ],
    "entry_node_id": "n_start",
    "nodes": [
      {
        "node_id": "n_start",
        "beats": [
          {
            "type": "speech",
            "speaker": "player",
            "expression": "concerned",
            "text": "We appear to have acquired a broadcaster."
          },
          {
            "type": "speech",
            "speaker": "aristocrat_residential",
            "expression": "surprised",
            "text": "Acquired? I arrived under my own steam."
          },
          {
            "type": "narration",
            "text": "An untuned radio begins to whistle."
          },
          {
            "type": "speech",
            "speaker": "aristocrat_commercial",
            "expression": "concerned",
            "text": "Has anyone checked who owns the tower?"
          }
        ],
        "on_enter": [],
        "options": [
          {
            "label": "Then we shall find you a frequency.",
            "next": "n_end",
            "effects": []
          }
        ]
      },
      {
        "node_id": "n_end",
        "beats": [
          {
            "type": "narration",
            "text": "The whistle resolves itself into half a trumpet solo."
          }
        ],
        "on_enter": [],
        "options": []
      }
    ]
  }
}
```

## Validation rules

- `participants` contains two or three unique non-empty IDs and includes `player`.
- `entry_node_id` resolves to one node.
- Node IDs are unique and every non-empty option destination resolves.
- A speech beat's speaker is `player` or appears in `participants`.
- A speech beat has non-empty text and a semantic expression name.
- A narration beat has non-empty text and no required speaker/expression.
- Unknown beat types, malformed fields, missing destinations, and empty normalized nodes
  produce stable validation errors.
- Traversal is bounded at 128 committed nodes.

Validation returns a detached normalized record and an ordered diagnostic list. It does
not modify the EventSystem-owned source dictionary.

## Legacy projection

If a node has no `beats` key and has a non-empty `body`, normalization produces:

```json
{
  "type": "narration",
  "text": "<legacy body>"
}
```

Existing options, destinations, node effects, completion, and headless first-option
behavior remain unchanged. If `beats` exists, `body` is ignored.

## Character expression fields

```json
{
  "character_id": "aristocrat_residential",
  "portrait": "res://data/characters/aristocrat_residential/portrait.png",
  "default_expression": "neutral",
  "expressions": {
    "neutral": "res://data/characters/aristocrat_residential/expressions/neutral.png",
    "concerned": "res://data/characters/aristocrat_residential/expressions/concerned.png",
    "surprised": "res://data/characters/aristocrat_residential/expressions/surprised.png"
  }
}
```

Expression keys are semantic and stable. Files may later be atlased without changing
quest data. `talking_videos` is a separate legacy/potential-animation field and is not
read as an expression map.
