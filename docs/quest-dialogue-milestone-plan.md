# Quest Conversation Foundation — Milestone Plan

> Superseded as the implementation source of truth by
> [`specs/011-quest-dialogue-foundation/`](../specs/011-quest-dialogue-foundation/).
> The final input contract uses the whole non-interactive conversation surface to
> complete/advance beats and does not render a persistent Continue button.

**Status:** concept plan for review
**Target:** Godot 4.6.x, desktop, 1920×1080 reference viewport
**Recommended milestone boundary:** one complete dialogue-led quest using the existing EventSystem, Inbox, CharacterSystem, and progression rules

## 1. Product intent

Quests should feel like a live illustrated message thread rather than a conventional visual-novel text box. A conversation accumulates inside a central framed scroll view. Player lines appear on the left, all other characters speak from the right, narrative appears as unboxed prose, and two persistent portrait slots carry the emotional state of the player and the current counterpart.

The first milestone is the **quest conversation foundation**, not a universal quest framework. It should prove one authored quest from trigger to resolution before introducing a generic objective tracker or new quest-state subsystem.

## 2. Experience contract

### Conversation layout

- Present the conversation as a modal over the live town, using the existing input-suppression contract.
- Keep two anchored portrait positions visible throughout: the player at bottom-left and the current counterpart at bottom-right.
- Keep the transcript, narrative, choices, advance control, and conversation status fully inside the dialogue frame.
- Float both portraits outside the frame at its lower corners. Only the inner edge—about 5% of portrait width—should overlap the frame, and it must not intrude into the transcript content inset.
- Reserve left-aligned bubbles for the player. Align every NPC bubble right and retain its speaker label in the transcript.
- Support two- and three-way scenes with the same two portrait slots: when another NPC speaks, swap the right slot to that speaker; during player speech or narration it retains the most recently shown NPC.
- Render narrative as centred plain writing without a bubble.
- Auto-scroll only while the player remains at the bottom. If the player scrolls upward, show a return-to-latest affordance instead of fighting their scroll position.
- At the 1920×1080 reference viewport, target a roughly 1120×720 dialogue surface. Validate at 1280×720 minimum and 3840×2160 maximum.

### Portrait state

- A speech beat activates its presentation slot: full colour, full opacity, slight positional lift, stronger ink frame, and a small non-colour emphasis mark.
- The other portrait retains its most recent character/expression but becomes approximately half-muted through desaturation and opacity.
- A narrative beat deactivates both portraits while retaining both most recent expressions.
- A newly speaking NPC replaces the right-slot character and expression before the first character of their line appears.
- A missing expression falls back to that character's declared default; missing character art falls back to a deliberately illustrated placeholder, never an accidental grey square.

### Reveal and advance rules

Use one deterministic `REVEALING → READY → ADVANCING` contract:

1. When a beat begins, append its final-size container immediately and reveal text at the configured rate.
2. Primary advance while `REVEALING` completes that beat instantly.
3. Primary advance while `READY` starts the next beat.
4. Primary advance must never both complete one beat and advance to the next from the same input event.
5. When choices are visible, primary advance does nothing; the player must choose an option.
6. Mouse click/tap on the conversation surface, Space, Enter, and the standard controller confirm action share the same command.
7. Escape may close only explicitly dismissible/terminal conversations, preserving the current plugin rule.

Default reveal speed should be authored as characters per second, with short punctuation pauses. Settings must offer instant text and a speed control. Reduced-motion/instant-text mode must not delay progress.

## 3. Recommended authored data

Keep the existing event envelope and node graph. Replace each node's single `body` with an ordered `beats` array while retaining `body` as a temporary legacy fallback.

```json
{
  "event_id": "baba_arrival",
  "event_type": "dialogue",
  "trigger": { "event": "character_arrived", "character_id": "aristocrat_residential" },
  "payload": {
    "participants": ["player", "aristocrat_residential", "aristocrat_commercial"],
    "entry_node_id": "arrival",
    "nodes": [
      {
        "node_id": "arrival",
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
            "expression": "delighted",
            "text": "A town without a signal is merely a collection of roofs."
          },
          {
            "type": "narration",
            "text": "Somewhere nearby, an untuned radio begins to whistle."
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
            "label": "Let's find you a frequency.",
            "next": "request",
            "effects": []
          }
        ]
      }
    ]
  }
}
```

Recommended character definition addition:

```json
{
  "default_expression": "neutral",
  "expressions": {
    "neutral": "res://data/characters/ambrose/expressions/neutral.png",
    "concerned": "res://data/characters/ambrose/expressions/concerned.png",
    "surprised": "res://data/characters/ambrose/expressions/surprised.png",
    "delighted": "res://data/characters/ambrose/expressions/delighted.png"
  }
}
```

`player` is a stable semantic participant ID, not a character-resource path. For the first playable slice it may resolve visually to Ambrose as an explicit stand-in; replacing that art later must not require rewriting quest data.

Authoring should address expressions by stable semantic names, not sheet indices. Keep high-resolution expression masters individually. A runtime atlas is optional later and, if introduced, must be built deterministically with region metadata. The existing `talking_videos` field should remain separate until there is an explicit decision to support animated expressions.

## 4. Runtime ownership

### DialoguePlugin

Owns presentation and conversation traversal:

- builds the modal, portraits, transcript, bubble/narrative rows, and choices;
- owns the reveal state machine and unified advance command;
- remembers the player's latest expression plus the latest right-slot NPC and expression for the current session;
- swaps the right slot when a different NPC becomes the active speaker, allowing three-way scenes without adding a third permanent portrait position;
- traverses the existing node graph and requests effects from EventSystem;
- acknowledges the pending dialogue only after semantic completion.

### EventSystem

Remains the source of event triggers, conditions, authored effects, dispatch counts, and pending dialogue IDs. It should not know about text animation, portrait state, or scrolling.

### InboxPlugin

Remains the entry point for pending conversations. Opening an inbox item should hand the record to DialoguePlugin without removing the durable pending ID; the inbox's local projection may hide it while open and restore it if the conversation is abandoned.

### CharacterSystem / PatronSystem

Remain the owners of progression facts. Dialogue choices invoke effects or existing semantic transitions; DialoguePlugin must not become a second quest-state authority.

### Future QuestSystem

Add a generic QuestSystem only when a quest needs durable objectives that are not already represented by character, patron, building, or event state. Its likely responsibilities are quest acceptance, objective progress, completion, failure, and tracker projection—not dialogue rendering.

## 5. UI component and asset plan

Treat this as a component family rather than a single background image:

- responsive inner dialogue panel/frame: `NinePatchRect` or `StyleBoxTexture`, containing every transcript and interaction element;
- speech bubble left/right variants: engine layout plus small reusable tail/frame assets, or nine-slices if the illustrated outline requires them;
- narrative row: engine text with reusable ornamental dividers;
- scroll track/handle: reuse the current UI family where practical;
- portrait frames and active emphasis overlay: reusable transparent assets, anchored outside the panel with an approximately 5% overlap at the lower corners;
- expression portraits: 512–1024 px runtime crops with larger source masters and declared focal-safe regions;
- all dialogue copy, names, choices, and accessibility labels remain engine text.

The mock-up assumes portrait display around 220–300 px at 1080p, 160 px minimum, and 420 px maximum. Production art needs actual-size proofs for active, inactive, narration, long-line, and choice states on both a calm background and a noisy town view.

## 6. Delivery slices

### Slice A — contract and state machine

- Introduce the `participants` and `beats` schema with legacy `body` fallback.
- Add pure parsing/validation helpers for beat type, speaker, expression, and text.
- Implement the reveal/ready/advance state machine independently of layout.
- Lock the rule that one input event performs one transition.

**Exit:** unit tests cover speech, narrative, missing expressions, instant text, click-to-complete, click-to-advance, and choice gating.

### Slice B — transcript UI

- Replace the current CK3-style body panel with the scroll-thread composition.
- Append reusable speech and narrative rows without rebuilding prior rows.
- Implement bottom-aware autoscroll and return-to-latest behaviour.
- Add mouse, keyboard, and controller advance bindings.

**Exit:** the UI can play both a two-person fixture and a three-person fixture containing player-left speech, NPC-right speech, right-slot character swaps, narrative, and a terminal beat at 720p and 1080p.

### Slice C — expression pipeline

- Add stable expression maps and fallback rules to character definitions.
- Connect beat entry to portrait expression and active/inactive presentation.
- Produce the first reviewed expression sets for the player stand-in and two vertical-slice NPCs.
- Preserve masters, runtime crops, manifest metadata, and actual-size/context proofs.

**Exit:** every fixture beat selects the intended expression; inactive and narrative states remain readable without relying on colour alone.

### Slice D — branching and persistence safety

- Render choices only after all node beats are complete.
- Make selected replies part of the visible transcript before entering the next node.
- Apply option effects exactly once and preserve the existing headless first-option path.
- Define interruption behaviour: either persist session cursor and transcript, or restart the still-pending conversation with no effects committed before a choice. The recommended first implementation is to commit effects only on explicit choices/terminal completion and restart presentation safely.

**Exit:** branch, close, reopen, save/load, and headless resolution agree on effects and final progression state.

### Slice E — one real quest vertical slice

- Author one short arrival/request quest using the player slot (Ambrose as temporary stand-in) and at least one current quest character; include a brief second-NPC exchange if the three-way fixture reads cleanly.
- Route it through EventSystem → Inbox → DialoguePlugin → existing progression transition.
- Capture deterministic trace and visual evidence.

**Exit:** a fresh-town scenario triggers, queues, opens, plays, resolves, saves, reloads, and does not duplicate effects or progression.

## 7. Test seams

- **Unit:** schema validation; expression fallback; reveal state transitions; punctuation timing; one-input/one-transition; choice gating; transcript ordering.
- **Integration:** EventSystem dispatch to Inbox; Inbox open/recovery; Dialogue traversal; effect application once; acknowledgement timing; input suppression; headless parity.
- **Persistence:** reload before opening, mid-node interruption, after choice, and after acknowledgement.
- **Input:** mouse, touch-sized target, keyboard, controller, and ignored clicks on scrollbar/choice controls.
- **Visual:** fixed player-left slot, current-NPC-right slot, NPC swap in a three-way scene, portrait/frame overlap, active left, active right, narrative/both inactive, long text, choice state, scrollback, 1280×720, 1920×1080, and noisy-world contrast.
- **Scenario:** one full legal first-town route reaches the same progression milestone with presentation enabled and disabled.

## 8. Acceptance criteria

- A conversation can mix any ordered sequence of speech and narrative beats.
- Player speech and selected replies always appear on the left; all NPC speech appears on the right.
- In two- and three-way scenes, the right portrait shows the current or most recently active NPC while the player portrait remains fixed on the left.
- All transcript and interaction content stays inside the frame; portraits remain outside it with only their inner edge overlapping by approximately 5%.
- The correct participant and expression becomes active before the first revealed character.
- Inactive portraits retain their last expression and are visibly inactive through more than colour alone.
- One input during reveal completes the current beat; a distinct later input advances exactly once.
- Previously revealed content remains in order and is manually scrollable.
- Choices cannot be accidentally skipped and effects execute exactly once.
- Pending dialogue survives interruption without losing or duplicating progression.
- The complete dialogue path remains resolvable headlessly for deterministic playtests.
- UI remains legible and operable at 1280×720 and 1920×1080, including instant-text and reduced-motion settings.

## 9. Decisions to review before implementation

1. **Recommended:** ship static expression portraits first; treat the existing talking videos as a later animation experiment.
2. **Recommended:** make this milestone the conversation foundation plus one real quest, not a generic quest/objective framework.
3. **Recommended:** reserve the left slot for `player` and let all NPCs share the right counterpart slot, which swaps before each new NPC speaks.
4. **Recommended:** use Ambrose as the explicitly labelled player-art stand-in until the dedicated player portrait direction is resolved.
5. Decide whether past speech bubbles retain full contrast or quieten slightly once a new beat begins.
6. Decide whether closing a non-terminal conversation is forbidden, or allowed with a clear “return to inbox” action.
