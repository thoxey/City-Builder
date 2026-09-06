# Research: Quest Dialogue Foundation

## Decision 1: Extend the existing dialogue/event path before adding QuestSystem

**Decision**: Implement the milestone in DialoguePlugin and the existing authored
EventSystem → Inbox → Dialogue path. Do not create a generic QuestSystem yet.

**Rationale**: Current quests are dialogue-led and their durable facts already belong
to character, patron, building, flag, and pending-event state. DialoguePlugin already
owns visible/headless traversal and semantic completion; EventSystem already owns
triggers, effects, and pending IDs.

**Alternatives considered**: A new objective tracker creates a second progression
authority before any objective requires it. Replacing EventSystem would discard tested
pending, replay, and effect contracts.

## Decision 2: Add ordered beats inside existing nodes

**Decision**: Add `payload.participants` and `node.beats`. A beat is either `speech`
with speaker/expression/text or `narration` with text. If `beats` is absent, project the
legacy `body` into a single compatible narration beat.

**Rationale**: Existing nodes, `entry_node_id`, options, destinations, and effects
already model branching. Beats add presentation sequence without changing graph or
headless semantics, and the fallback permits incremental content migration.

**Alternatives considered**: One node per spoken line makes narrative authoring noisy
and couples effects/choices to presentation cadence. A separate screenplay format
would require a second loader and graph.

## Decision 3: Use an explicit one-transition reveal state machine

**Decision**: Use `REVEALING`, `READY`, `CHOOSING`, and `DONE` session modes. One
advance command completes only the current reveal in `REVEALING`, appends only the next
beat in `READY`, and does nothing in `CHOOSING`. A terminal `READY` activation commits
and closes.

**Rationale**: This directly expresses the requested click-twice convention and makes
rapid input testable. Appending the final-size row before revealing prevents layout
jumps.

**Alternatives considered**: Timer-only progression removes player control. One click
that both completes and advances is easy to trigger accidentally. A permanent Continue
button contradicts the agreed surface interaction.

## Decision 4: Make the frame itself the pointer target

**Decision**: The full non-interactive dialogue frame receives left-click/tap. Space,
Enter, and a new `dialogue_advance` action mapped to controller confirm call the same
command. Choice buttons, scrollbars, and return-to-latest consume input before the frame.
No Continue or Finish-line button is built.

**Rationale**: A single large target matches the desired conversational rhythm and is
easier to use than a small repeated control. One command centralizes input semantics.

**Alternatives considered**: Binding raw controller buttons in the plugin duplicates
input policy. Letting child controls bubble creates accidental double transitions.

## Decision 5: Use two fixed presentation slots for any supported cast

**Decision**: Reserve the bottom-left slot and left bubbles for `player`. All NPCs use
right bubbles and the bottom-right counterpart slot. When another NPC speaks, update
the right slot to that identity before reveal. Player speech and narration retain the
most recently displayed NPC.

**Rationale**: The mock-up stays readable and spatially stable in both two- and
three-person scenes. Speaker labels preserve transcript identity after the portrait
changes.

**Alternatives considered**: Three simultaneous portraits crowd the frame and create
layout variants. Arbitrary speaker-to-side assignment weakens the player's stable
conversation identity.

## Decision 6: Keep session presentation transient and commit effects late

**Decision**: Opening/entering/revealing a node does not apply effects. At a selected
choice, atomically apply that node's deferred `on_enter` effects followed by option
effects, append the reply, then navigate or complete. At a terminal node, apply
`on_enter` effects and complete only on the terminal surface activation. A pre-commit
interruption leaves the EventSystem pending ID intact and restarts presentation.

**Rationale**: Current persistent pending IDs already recover conversations after
load, but current immediate `on_enter` execution can duplicate on restart. Late commit
achieves safe interruption without persisting a transcript cursor or creating a new
save schema.

**Alternatives considered**: Persisting every beat/reveal/scroll cursor adds broad
state and migration work. Requiring all entry effects to be idempotent is fragile and
unenforceable for future effects.

## Decision 7: Separate pure authored-data normalization from the renderer

**Decision**: Add a small `dialogue_schema.gd` helper that normalizes/validates
participants, nodes, beats, options, expressions, legacy body fallback, missing
destinations, and traversal bounds. DialoguePlugin consumes normalized records.

**Rationale**: Pure parsing is fast to test without a viewport and keeps malformed data
from leaking into presentation logic. It also gives the data-editor manifest/export
path one reusable contract to mirror.

**Alternatives considered**: Inline dictionary reads in the renderer reproduce the
current permissive behavior and scatter fallback rules. A general schema framework is
unnecessary for one event type.

## Decision 8: Keep UI programmatic but extract one thread view

**Decision**: Follow the repository's current UI convention: build controls in
GDScript. Extract `dialogue_thread_view.gd` for the frame, transcript rows, portraits,
choices, scroll-follow state, layout, and presentation signals; keep traversal,
effects, and completion in DialoguePlugin. Add a dialogue theme resource derived from
the existing player UI family.

**Rationale**: Existing plugins build UI programmatically, while a dedicated view
keeps DialoguePlugin testable and prevents traversal state from becoming entangled with
layout. A theme resource centralizes nine-slice/button/scroll styling.

**Alternatives considered**: Keeping the entire rewrite in DialoguePlugin produces a
large mixed-responsibility script. Introducing a scene-heavy UI pattern only for this
feature would be inconsistent and offers little benefit for a single dynamically
populated modal.

## Decision 9: Address expressions semantically and ship static portraits first

**Decision**: Extend character JSON with `default_expression` and `expressions` mapping
stable names to textures. `player` resolves through a single DialoguePlugin mapping to
Ambrose for this slice. Use existing portraits as safe neutral fallbacks while reviewed
expression crops are prepared. Keep `talking_videos` unchanged and unused by beat
selection.

**Rationale**: Semantic names survive atlas changes and art replacement. Static images
are deterministic, cheap, and match the milestone. The player mapping prevents quest
data from hard-coding temporary Ambrose art.

**Alternatives considered**: Sheet indices leak packing details into content. Reusing
talking-video list positions as expressions is ambiguous and makes exact state timing
harder to verify.

## Decision 10: Append transcript rows and follow only at the bottom

**Decision**: Create each transcript row once and reveal only that row's visible text.
When the scroll is at/near its maximum, follow new content. Otherwise retain the user's
position and show one return-to-latest control inside the frame.

**Rationale**: Rebuilding all prior rows makes long conversations unnecessarily costly
and can reset scroll/focus. Bottom-aware following preserves both conversational flow
and intentional scrollback.

**Alternatives considered**: Forced auto-scroll fights inspection. Virtualizing the
first 200-beat scope adds complexity before profiling demonstrates a need.

## Decision 11: Preserve visible/headless semantic parity

**Decision**: Both paths use the normalized graph and a shared node-commit helper.
Headless resolution selects the first valid authored option, applies the same ordered
effects, observes the same traversal bound, acknowledges the same pending ID, and
performs the same arrival transition.

**Rationale**: This preserves deterministic scenario automation and the constitution's
narrative-separation rule.

**Alternatives considered**: A UI-only quest path would make balance scenarios depend
on presentation. A separate headless interpretation would drift as the schema grows.
