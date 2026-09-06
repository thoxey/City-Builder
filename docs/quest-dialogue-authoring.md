# Quest Dialogue Authoring

Quest dialogue is ordinary EventSystem data rendered by DialoguePlugin. New dialogue
requires JSON and character art metadata; it does not require renderer changes.

The normative contracts are:

- [Dialogue authoring contract](../specs/011-quest-dialogue-foundation/contracts/dialogue-authoring.md)
- [Dialogue commit and completion contract](../specs/011-quest-dialogue-foundation/contracts/dialogue-completion.md)
- [Dialogue interaction contract](../specs/011-quest-dialogue-foundation/contracts/dialogue-interaction.md)

## Event shape

Declare two or three semantic participants. `player` is the player-facing semantic ID
and is presented as Ambrose; quest files should never use `ambrose` as a speaker.

```json
{
  "event_id": "example_arrival",
  "event_type": "dialogue",
  "trigger": {"event": "character_arrived", "character_id": "example_character"},
  "enabled_if": "",
  "payload": {
    "participants": ["player", "example_character"],
    "entry_node_id": "n_start",
    "nodes": [{
      "node_id": "n_start",
      "beats": [
        {"type":"speech", "speaker":"player", "expression":"concerned", "text":"Something is afoot."},
        {"type":"narration", "text":"A suspicious hinge squeaks."},
        {"type":"speech", "speaker":"example_character", "expression":"neutral", "text":"Quite so."}
      ],
      "on_enter": [{"kind":"set_flag", "target":"met_example_character"}],
      "options": [{"label":"Investigate it.", "next":"n_end", "effects":[]}]
    }, {
      "node_id": "n_end",
      "beats": [{"type":"narration", "text":"The matter is provisionally settled."}],
      "on_enter": [],
      "options": []
    }]
  }
}
```

Beat order is transcript order. Speech needs `speaker`, `expression`, and non-empty
`text`; narration needs only non-empty `text`. Every non-empty option destination must
name a node in the same event. Traversal is capped at 128 committed nodes.

## Character expressions

Character JSON may declare a semantic expression map while retaining the existing
portrait fallback:

```json
{
  "portrait": "res://data/characters/example/portrait.png",
  "default_expression": "neutral",
  "expressions": {
    "neutral": "res://data/characters/example/expressions/neutral.png",
    "concerned": "res://data/characters/example/expressions/concerned.png"
  }
}
```

The stable portrait vocabulary is `neutral`, `pleased`, `disapproving`, `angry`,
`surprised`, `concerned`, and `thoughtful`. Dialogue beats author one of those semantic
names; they never address a contact-sheet row, column, or numeric index. Ambrose, Baba
Soyink, and Sir William use transparent black line-art files over the dialogue view's
light parchment medallion. Their legacy `portrait` and `talking_videos` remain separate
fallback/media contracts. Flick remains on the earlier provisional expression set until
her approved line-art sheet is available.

## Compact in-game guidance

The live town HUD reuses the dialogue portrait and speech-bubble language for one
dismissible direction at a time. This is a presentation of Dashboard's canonical
next-step projection, not a second quest or placement system: it cannot apply
effects, advance dialogue, or select a build item. Clicking anywhere on the compact
surface or its × button consumes that pointer event and hides the current semantic
direction, preventing the click from also reaching placement or world selection.
Ordinary refreshes do not reopen a dismissed direction; a changed canonical direction
may appear again.

Ambrose voices generic growth, tier, and founding directions. A character with an
approved `/line_art/` expression map may voice their own arrival or requested
placement, and a patron representative may voice the landmark placement. Characters
without approved line art—including Flick—remain described by Ambrose. The compact
surface resolves semantic expression names through the same default-expression and
legacy-portrait fallback order as full dialogue; authors never provide sheet indices.

The compact surface remains visible over ordinary world and placement modes, and is
suppressed during modal dialogue, radial navigation, and Community inspection. It is
responsive at 1280×720, 1920×1080, and 3840×2160 and stays clear of the bottom tool
dock and right-hand insights drawer.

Resolution order is authored expression, declared default expression, legacy
`portrait`, then the intentional missing-art portrait. Unknown or absent art produces
stable diagnostics and does not change traversal semantics. The latest expression is
retained when a speaker becomes inactive. Ambrose stays on the left; the latest NPC is
swapped into the right slot before their line reveals. Narration makes both portraits
inactive without losing either identity.

## Choices, effects, and completion

Entering or revealing a node never applies `on_enter`. A choice commits once when the
player selects it: the selected label is appended as a player-left row, then node
effects run in authored order, followed by option effects. A terminal node commits when
the final beat is ready and the conversation surface is activated. Completion then
performs existing arrival/patron progression, acknowledges the EventSystem pending ID,
clears transient session state, and hides the dialogue.

This late boundary is the recovery guarantee. If presentation is interrupted before a
commit, the durable pending ID remains in `DataMap.pending_dialogue_event_ids`; map load
reprojects it into Inbox and the transient transcript starts again with no duplicated
effects.

Headless playtest resolution uses the same normalized graph, first valid option at each
choice, node-then-option effect ordering, 128-node bound, progression transition, and
acknowledgement.

## Interaction and legacy migration

There is no Continue or Finish button. Click or tap any non-interactive part of the
conversation, press Space or Enter, or use controller confirm. One physical event makes
at most one transition: revealing text completes first; a later event starts the next
beat, opens choices, or commits a terminal node. Choice, scrollbar, and return-to-latest
controls consume input and never also advance the surface.

Legacy nodes with a non-empty `body` remain supported and normalize to one narration
beat. Existing option order, first-option headless traversal, effect order, and
completion semantics are preserved. Migrate by adding `participants`, replacing each
`body` with ordered `beats`, and replacing generic continuation labels with meaningful
player replies. Do not change trigger IDs or established progression flags during a
presentation-only migration.
