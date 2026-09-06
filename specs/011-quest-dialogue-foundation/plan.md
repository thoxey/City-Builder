# Implementation Plan: Quest Dialogue Foundation

**Branch**: `codex/009-performance-foundation` | **Date**: 2026-09-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/011-quest-dialogue-foundation/spec.md`

## Summary

Replace the current single-portrait, single-body CK3-style dialogue modal with an
accumulating illustrated conversation thread. Extend existing event nodes with ordered
speech/narration beats; keep player bubbles and portrait fixed left, use one swapping
NPC counterpart slot on the right, reveal text progressively, and make the entire
non-interactive conversation surface the advance target. There is no Continue button.

DialoguePlugin remains the presentation/traversal coordinator. A pure schema helper
normalizes new and legacy event data, and a dedicated programmatic thread view owns
layout and transient presentation state. EventSystem remains the only effect/pending
authority, Inbox remains the pending entry point, and visible/headless paths share late
node-commit semantics so interrupted conversations restart without duplicate effects.

## Technical Context

**Language/Version**: GDScript 4.x on Godot 4.6.x

**Primary Dependencies**: Existing PluginBase/PluginManager/GameEvents architecture;
DialoguePlugin, EventSystem, InboxPlugin, CharacterSystem, PatronSystem, PlayerUI theme
assets, Godot `Control`, `ScrollContainer`, `RichTextLabel`/`Label`, `TextureRect`,
`Tween`, and `InputMap`

**Storage**: Existing JSON event and character definitions; no new saved fields;
`DataMap.pending_dialogue_event_ids` remains the durable recovery source

**Testing**: GUT 9.3 unit/integration tests, existing deterministic Playtest resolver,
headless first-town scenario, authored-data manifest export, normal-renderer screenshot
capture, and manual visual review

**Target Platform**: Godot desktop game, initially macOS local playtesting; reference
viewport 1920×1080 with 1280×720 minimum and 3840×2160 maximum validation

**Project Type**: Desktop game with plugin-based gameplay, narrative, and programmatic UI

**Performance Goals**: Reveal updates remain below one 16.7 ms frame; a 200-beat
transcript appends without rebuilding prior rows; inactive dialogue adds no per-frame
work

**Constraints**: Whole-surface advance with no Continue button; one input event causes
at most one transition; player always left; all NPCs right; only two visible portrait
slots; static expressions first; headless resolution cannot load UI/art; no generic
QuestSystem or objective tracker; core simulation remains narrative-independent

**Scale/Scope**: One production arrival quest vertical slice, two- and three-person
fixtures, up to three declared participants, up to 128 committed nodes per traversal,
and a 200-beat presentation stress fixture

## Constitution Check

*GATE: Passed before research and re-checked after design.*

- **I. One Gameplay Truth — PASS**: Dialogue requests existing EventSystem effects and
  existing CharacterSystem/PatronSystem transitions. It does not mutate city state
  directly or create quest progression state.
- **II. Deterministic, Controllable Simulation — PASS**: Beat order, reveal state,
  node traversal, first-option headless resolution, and effect order are deterministic.
  Presentation timing does not affect simulation outcomes.
- **III. Observable and Explainable State — PASS**: Normalization and advance return
  stable diagnostics/transitions; visible/headless tests compare ordered visited nodes,
  effects, pending acknowledgement, and progression.
- **IV. Data-Driven Balance, Narrative Separation — PASS**: Conversation copy,
  participants, expressions, and choices remain authored data. Presentation can be
  disabled and first-town/core balance scenarios remain semantically resolvable.
- **V. Small Interfaces and Layered Verification — PASS**: One schema helper, one view,
  and existing plugin methods are sufficient. Verification spans pure schema, UI state,
  integration, replay, and visual evidence.
- **Project constraints — PASS**: Godot 4.6.x and plugin/event boundaries are preserved;
  unrelated systems are not coupled to `builder.gd`.
- **Quality gates — PASS BY DESIGN**: Test seams precede implementation; focused/full
  GUT, writable `user://`, deterministic first-town, manifest, and visual checks appear
  in [quickstart.md](quickstart.md).

No constitutional exception or complexity justification is required.

## Design Phases

### Phase A — Freeze compatibility and failing contracts

Capture current visible/headless outcomes for legacy body-only arrival and landmark
events. Add failing pure-schema, reveal-state, input, expression fallback, transcript,
effect-commit, inbox recovery, and visible/headless parity tests before replacing UI.

### Phase B — Normalize dialogue content

Add `plugins/dialogue/dialogue_schema.gd`. It returns a detached normalized event and
ordered stable diagnostics. It supports `participants`, ordered `beats`, legacy `body`
projection, speaker/expression validation, graph destination validation, and the
existing 128-node traversal ceiling.

Extend the data-editor manifest/export validation to carry the new event/character
fields without transforming semantic expression names into packing indices.

### Phase C — Build the thread view

Add `plugins/dialogue/dialogue_thread_view.gd`, built programmatically to match the
repository's existing UI convention. It owns:

- a dimmed full-screen CanvasLayer surface;
- one resizable inner dialogue frame containing header/status, transcript, choices,
  return-to-latest control, and concise interaction hint;
- fixed bottom-left player and bottom-right counterpart portrait hosts outside the
  frame, with only about 5% overlap and safe content insets;
- append-only left speech, right speech, and centred unboxed narration rows;
- active/inactive portrait presentation and right-slot character swaps;
- bottom-aware scrolling and viewport-responsive layout.

Create `themes/dialogue_theme.tres` using reusable nine-slice/StyleBox resources. Reuse
existing button and scrollbar families where they fit. Keep names, copy, and choices as
engine text. Portrait/frame assets are separate from layout code so final art can
replace temporary derivatives.

### Phase D — Implement reveal and whole-surface input

DialoguePlugin owns `REVEALING`, `READY`, `CHOOSING`, and `DONE`. The view appends a
final-size row, then DialoguePlugin advances its visible prefix using deterministic
characters-per-second timing. Instant mode goes directly to `READY`.

Add `dialogue_advance` to `project.godot` for controller confirm. Left-click/tap on the
frame's non-interactive surface plus Space, Enter, and the action call the same advance
method. The view contains no Continue/Finish-line button. Choice, scrollbar, and
return-to-latest input is consumed before it can reach surface advance.

### Phase E — Share late commit and completion semantics

Refactor node traversal so visual entry does not execute `on_enter`. At option selection
or terminal ready-advance, call one node-commit helper that guards duplicate execution,
applies node effects then option effects, and navigates or completes. Completion keeps
the existing arrival transition and EventSystem acknowledgement.

Refactor `resolve_pending_event()` to use the same normalized graph and commit order,
selecting the first valid option without constructing UI or loading textures.

### Phase F — Expressions and authored vertical slice

Extend character data with `default_expression` and semantic `expressions`. Resolve an
authored expression, then default, then legacy portrait, then the illustrated
missing-art fallback. Keep `talking_videos` unchanged. Configure semantic `player` to
use Ambrose temporarily in one DialoguePlugin mapping.

Migrate `aristocrat_residential_arrival` into the first production conversation with
player/NPC speech, narration, expression changes, at least one player choice, and a
terminal node. Keep a three-person fixture using Flick to prove right-slot swapping;
do not require Flick's arrival event to become the production vertical slice.

### Phase G — Recovery, performance, and release evidence

Prove that interruption before commit applies no effects and EventSystem reprojects one
pending Inbox item after load. Compare visible and headless normalized outcomes. Run the
200-beat append test, all dialogue/inbox/event/progression tests, full GUT, deterministic
first-town, manifest export, and normal-renderer captures at all three viewports.

## Project Structure

### Documentation (this feature)

```text
specs/011-quest-dialogue-foundation/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── dialogue-authoring.md
│   ├── dialogue-input.md
│   └── dialogue-completion.md
├── checklists/requirements.md
├── validation/
└── tasks.md
```

### Source Code (repository root)

```text
plugins/dialogue/
├── dialogue_plugin.gd
├── dialogue_schema.gd
└── dialogue_thread_view.gd
plugins/inbox/inbox_plugin.gd
plugins/event_system/event_system_plugin.gd
plugins/character_system/character_system_plugin.gd
addons/data_editor_tools/manifest_exporter.gd
data/
├── characters/{ambrose,aristocrat_residential,aristocrat_commercial}.json
└── events/characters/aristocrat_residential/arrival.json
themes/dialogue_theme.tres
art/ui/dialogue/
sprites/ui/dialogue/
scripts/capture_dialogue_validation.gd
test/
├── integration/dialogue/
└── unit/{dialogue,inbox,event_system,character_system,playtest}/
```

**Structure Decision**: Preserve programmatic plugin UI. Add one pure schema helper and
one focused view class; keep traversal/effects in DialoguePlugin and pending ownership
in EventSystem/Inbox. Add a dialogue-specific theme/assets rather than expanding the
global player theme with one-off portrait geometry.

## Asset Plan

- Reuse `modal-confirmation-frame.png` as a temporary panel fallback; produce a reviewed
  dialogue nine-slice only if the existing frame cannot support the target proportions.
- Reuse existing button states for actual choices only; no advance button asset exists.
- Reuse current scrollbar assets and ornamental divider where legible.
- Add reusable portrait frame and active-emphasis overlays with high-resolution masters,
  Godot-ready derivatives, manifests, actual-size proofs, and noisy-gameplay context
  proofs under the established UI art pipeline.
- Keep expression masters individually named by semantic state. Runtime atlas creation
  is optional and must preserve region metadata; authored data never references cells.
- Use current portraits as neutral fallback until final expression artwork is approved.

## Test Seams

- Pure normalized-event fixtures for valid, legacy, malformed, missing-destination, and
  cyclic graphs.
- Reveal clock injection or direct deterministic step method independent of `_process`.
- Internal `advance_dialogue()` result projection for one-input/one-transition tests.
- View signal/locator hooks for surface, control precedence, transcript row order,
  portrait slot state, scroll-follow state, and responsive geometry.
- Stub EventSystem recording ordered node/option effects and acknowledgement.
- Stub CharacterSystem expression definitions and arrival transitions.
- Inbox reload fixture preserving EventSystem pending IDs while discarding session state.
- Shared visible/headless normalized traversal outcome comparison.
- Screenshot capture with deterministic instant text and forced active-left,
  active-right, narration, three-way swap, choices, long text, and scrollback states.

## Post-Design Constitution Re-check

All gates remain satisfied. The only durable authority remains the existing pending ID
and existing progression data. Late commit removes duplicate-on-restart risk without a
new save schema. Headless resolution uses no presentation assets. UI extraction adds
two narrowly scoped scripts rather than a framework. No Complexity Tracking entry is
needed.

## Complexity Tracking

No constitutional violations.
