# Feature Specification: Quest Dialogue Foundation

**Feature Branch**: `codex/009-performance-foundation` (feature directory is independent)

**Created**: 2026-09-06

**Status**: Ready for implementation planning

**Input**: User description: "Implement quests primarily as illustrated text-conversation threads. Player speech is on the left and other characters are on the right; narrative appears between bubbles. Two portraits sit just outside the frame, retain their latest expressions, and mute when inactive. Text reveals progressively. One activation completes the current reveal and a distinct next activation advances. The whole conversation surface is the advance target, with no Continue button. Support two- and three-way conversations and safe branching into existing progression."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Read and Advance a Conversation (Priority: P1)

As a player, I can read an accumulating conversation thread and advance it naturally by
clicking anywhere on the non-interactive conversation surface. While a line is
revealing, one activation completes that line; a separate later activation starts the
next beat. There is no persistent Continue button competing with the conversation.

**Why this priority**: The reveal-and-advance rhythm is the core interaction. The
feature does not feel like a conversation unless it is predictable, immediate, and
comfortable to click through.

**Independent Test**: Open a linear fixture containing player speech, NPC speech, and
narration. Use only surface clicks to complete and advance every beat, then repeat with
keyboard and controller confirm input. Verify each input causes exactly one transition.

**Acceptance Scenarios**:

1. **Given** a speech or narrative beat is still revealing, **When** the player activates the conversation surface, **Then** the current beat appears in full and the next beat does not begin.
2. **Given** the current beat is fully visible, **When** the player activates the conversation surface again, **Then** exactly the next beat is appended and begins revealing.
3. **Given** a terminal beat is fully visible and no choices remain, **When** the player activates the conversation surface, **Then** the conversation completes without displaying a Continue button.
4. **Given** the player clicks a scrollbar, scroll affordance, or dialogue choice, **When** that control handles the input, **Then** the surface does not also advance the conversation.
5. **Given** Space, Enter, or controller confirm is pressed, **When** no choice has focus and the conversation is active, **Then** it follows the same one-input/one-transition rule as a surface click.

---

### User Story 2 - Follow Speakers, Expressions, and Narration (Priority: P1)

As a player, I can immediately tell who is speaking and how they feel while retaining
the complete conversational context. My speech is always on the left. Every non-player
character speaks on the right. Portraits update before their lines reveal, and prose
narration sits plainly between speech bubbles.

**Why this priority**: Speaker clarity and emotional state are the main presentational
value beyond the existing single-body dialogue panel.

**Independent Test**: Play one two-person fixture and one three-person fixture. Verify
player-left/NPC-right alignment, expression changes, right-slot character swaps,
narrative rows, inactive muting, and transcript ordering without resolving a branch.

**Acceptance Scenarios**:

1. **Given** the player speaks, **When** the beat begins, **Then** a left-aligned bubble is appended and the fixed bottom-left player portrait becomes active with the authored expression.
2. **Given** an NPC speaks, **When** the beat begins, **Then** a right-aligned named bubble is appended and the bottom-right counterpart portrait shows that NPC and authored expression before text starts revealing.
3. **Given** a different NPC speaks in a three-way scene, **When** their beat begins, **Then** the right portrait slot swaps to that NPC while the player remains fixed on the left.
4. **Given** a narration beat begins, **When** it is appended, **Then** it appears as centred unboxed prose and both portraits become inactive without losing their latest character or expression.
5. **Given** one participant is not speaking, **When** another beat is active, **Then** the inactive portrait retains its last expression and is visibly muted through opacity/desaturation plus a non-colour active-state distinction.
6. **Given** the transcript exceeds its viewport, **When** new beats arrive while the player remains at the bottom, **Then** the newest beat stays visible; if the player has scrolled up, their position is preserved and a return-to-latest affordance appears.

---

### User Story 3 - Choose a Reply and Resolve Progression Safely (Priority: P1)

As a player, I can choose an authored reply after a node's conversation beats. My
selected reply becomes part of the left-side transcript, the branch continues or
closes, and gameplay effects occur exactly once through the existing event and
progression authorities.

**Why this priority**: A readable presentation is not an implementable quest feature
unless it can branch, complete, survive interruption, and preserve current progression
semantics.

**Independent Test**: Open a pending arrival dialogue, play to a choice, select each
branch in separate runs, interrupt and reload before committing a choice, and resolve
the same event headlessly. Verify visible and headless outcomes match and no effect,
acknowledgement, or progression transition duplicates.

**Acceptance Scenarios**:

1. **Given** a node has choices, **When** its final beat completes, **Then** choices appear inside the dialogue frame and ordinary surface advance is disabled until a choice is selected.
2. **Given** the player selects a choice, **When** it is accepted, **Then** the choice label is appended as a left-side player bubble before the destination node begins or the conversation closes.
3. **Given** a choice has effects, **When** it is selected, **Then** those effects and the completed node's entry effects are applied exactly once by the existing event authority.
4. **Given** a conversation is interrupted before a choice or terminal completion is committed, **When** the game is loaded again, **Then** the durable pending event is available from the inbox and presentation restarts without duplicating effects.
5. **Given** an automated playtest resolves the same pending event, **When** it follows the authored first-option path, **Then** it produces the same progression effects, acknowledgement, and final character transition as the visible path.

---

### User Story 4 - Author Dialogue Without Rebuilding the Renderer (Priority: P2)

As a content author, I can describe ordered speech and narrative beats, participants,
expressions, nodes, choices, and effects in event data. New conversations and new
characters do not require custom presentation code.

**Why this priority**: The first quest can ship with code-authored fixtures, but quests
become a sustainable feature only when content and presentation are cleanly separated.

**Independent Test**: Validate representative correct and incorrect event records,
including legacy body-only nodes, missing expressions, unknown speakers, and a
three-person participant list. Confirm stable validation/fallback outcomes.

**Acceptance Scenarios**:

1. **Given** a node contains an ordered mixture of speech and narration beats, **When** it is opened, **Then** the renderer plays them in authored order.
2. **Given** an existing node contains only the legacy body field, **When** it is opened during migration, **Then** it renders as one compatible beat and preserves its current branch/effect behavior.
3. **Given** an expression is absent for a valid participant, **When** the beat begins, **Then** the participant's declared default expression is used and a stable diagnostic is produced.
4. **Given** a speaker is neither `player` nor an authored participant, **When** data is validated, **Then** the record is rejected or diagnosed with a stable reason instead of silently assigning the wrong portrait.
5. **Given** dedicated player art is unavailable, **When** a `player` beat is rendered, **Then** the configured Ambrose stand-in is used without requiring quest records to name Ambrose.

### Edge Cases

- A beat has empty text, an unknown type, a missing speaker, or a non-string expression.
- A participant exists but has no expression map, no default expression, or a missing texture.
- Two different NPCs speak consecutively and the right portrait must swap without affecting prior bubbles.
- Narration is first, narration follows an NPC swap, or several narration beats are consecutive.
- The player clicks very rapidly while a reveal timer is active or during the same rendered frame.
- The player clicks inside a speech bubble, on empty transcript space, on a portrait overlap, on the scrollbar, or on a choice.
- The player scrolls upward while text is revealing and a new beat is appended.
- A line is very long, includes punctuation, or includes multibyte characters.
- A node has no beats and no legacy body, no options, a missing destination, or a node cycle.
- The viewport is resized while the modal is open, including 1280×720 and 3840×2160 bounds.
- Presentation is disabled for headless play, or an event is resolved after a save/load redispatch.
- The application closes after a conversation opens but before a choice or terminal completion is committed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST render a dialogue event as one accumulating vertically scrollable transcript contained entirely within the dialogue frame.
- **FR-002**: A dialogue node MUST support an ordered `beats` collection containing speech and narration beats.
- **FR-003**: A speech beat MUST identify its semantic speaker, expression, and text; a narration beat MUST contain text and MUST NOT require a speaker.
- **FR-004**: The system MUST retain temporary compatibility with a node's legacy `body` field by projecting it into one renderable beat when `beats` is absent.
- **FR-005**: Player speech and selected replies MUST always render as left-aligned bubbles; NPC speech MUST always render as right-aligned bubbles with a visible speaker name.
- **FR-006**: The player portrait slot MUST remain fixed at the bottom-left and the current counterpart portrait slot MUST remain fixed at the bottom-right.
- **FR-007**: Speech bubbles, narration, choices, scroll controls, status, and essential instructions MUST remain inside the frame; portrait artwork MUST sit outside the lower corners with only approximately 5% of its width overlapping the frame and no overlap into the transcript content inset.
- **FR-008**: The participant's authored expression MUST be visible before the first character of their speech begins revealing.
- **FR-009**: The active speaker portrait MUST be full-strength and receive a non-colour emphasis; inactive portraits MUST retain their latest state while appearing approximately half-muted.
- **FR-010**: Narration MUST deactivate both portraits while preserving the fixed player and most recently shown counterpart expressions.
- **FR-011**: Two- and three-person conversations MUST use the same two presentation slots; a newly speaking NPC MUST replace the right-slot character before their text reveals.
- **FR-012**: The semantic `player` participant MUST resolve through one presentation mapping; the first implementation MUST use Ambrose as an explicit stand-in without writing `ambrose` into quest beat data.
- **FR-013**: Character definitions MUST support a stable semantic expression map and a declared default expression independent of sprite-sheet coordinates or talking-video indices.
- **FR-014**: A missing authored expression MUST fall back to the participant's default expression; missing participant art MUST use an intentional illustrated fallback and emit a stable diagnostic.
- **FR-015**: Beat text MUST reveal progressively at a deterministic configurable rate; instant presentation MUST be available to tests and future accessibility settings.
- **FR-016**: Activating the non-interactive conversation surface while text is revealing MUST complete only the current beat.
- **FR-017**: Activating the non-interactive conversation surface while the current beat is ready MUST append/start only the next beat, or complete the conversation if the ready beat is terminal.
- **FR-018**: The visible presentation MUST NOT include a persistent Continue/Finish-line button; the surface itself is the pointer/touch advance target.
- **FR-019**: Surface click/tap, Space, Enter, and controller confirm MUST route through one advance command and one input event MUST cause at most one state transition.
- **FR-020**: Scrollbars, return-to-latest controls, and choice controls MUST consume their own input and MUST NOT also invoke surface advance.
- **FR-021**: Choices MUST appear only after all beats in their node are complete, remain inside the frame, and disable ordinary advance until an option is selected.
- **FR-022**: A selected option label MUST be appended to the transcript as a player-left bubble before navigation or closure.
- **FR-023**: Node entry effects and selected-option effects MUST be committed exactly once at the node's explicit choice or terminal-completion boundary; merely entering or revealing a node MUST NOT commit effects.
- **FR-024**: Dialogue completion MUST acknowledge the pending event and perform existing semantic progression transitions only after the terminal node is explicitly completed.
- **FR-025**: Interrupting presentation before a commit boundary MUST leave the durable event pending and MUST NOT duplicate effects when presentation restarts.
- **FR-026**: The existing headless dialogue resolver MUST traverse the same node/effect/acknowledgement semantics as visible presentation while selecting the first authored option.
- **FR-027**: The transcript MUST auto-scroll while the player remains at its latest position; manual scrollback MUST be preserved and expose a return-to-latest affordance when new content exists below.
- **FR-028**: Dialogue MUST continue to suppress world/build input while open, and higher-priority choice controls MUST take precedence over surface advance.
- **FR-029**: Event triggering, pending event IDs, authored effect execution, and character/patron progression MUST remain owned by their existing systems; dialogue presentation MUST NOT create a second quest-state authority.
- **FR-030**: Core city-building scenarios MUST remain runnable with narrative presentation disabled and MUST NOT depend on portrait or story assets.
- **FR-031**: The feature MUST remain legible and operable at 1280×720, 1920×1080, and 3840×2160 desktop viewports.
- **FR-032**: The first vertical slice MUST include a real pending arrival conversation exercising player speech, NPC speech, narration, an expression change, a choice, and terminal completion.
- **FR-033**: Automated fixtures MUST also cover a three-way conversation where two NPC identities share and swap the right portrait slot.

### Key Entities

- **Dialogue Event**: Existing authored event envelope whose payload declares participants, entry node, nodes, choices, and effects.
- **Dialogue Node**: One branch point containing ordered beats, deferred entry effects, and zero or more player options.
- **Dialogue Beat**: Ordered speech or narration content with type-specific fields.
- **Dialogue Participant**: A semantic identity allowed to speak, including the reserved `player` identity and character-backed NPC identities.
- **Expression Set**: Character-owned semantic expression names, a default, and their runtime portrait resources.
- **Dialogue Session**: Transient visible traversal state: event/node/beat cursor, reveal mode, transcript rows, latest expressions, current counterpart, scroll-follow state, and uncommitted choice state.
- **Pending Dialogue ID**: Existing durable EventSystem-owned identity retained until semantic completion.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In automated input tests, 100% of reveal-time activations complete only the current beat and 100% of ready-time activations advance exactly one beat.
- **SC-002**: The finished visible presentation contains zero persistent Continue or Finish-line buttons; all covered terminal linear conversations can be completed through surface/confirm input.
- **SC-003**: Two-person and three-person fixtures produce the exact authored transcript order with 100% of player rows on the left and 100% of NPC rows on the right.
- **SC-004**: Before every covered speech reveal begins, the correct active participant and semantic expression are already present; narration leaves both portraits inactive with their latest state intact.
- **SC-005**: At 1280×720, 1920×1080, and 3840×2160, all transcript and choice content remains within the frame, both portraits remain readable outside it, and no essential text or control overlaps or clips.
- **SC-006**: Covered legacy body-only dialogue events preserve their current branch, effect, acknowledgement, and progression outcomes during migration.
- **SC-007**: Reopening an interrupted pending conversation before a commit boundary causes zero duplicated effects and leaves exactly one pending ID until successful completion.
- **SC-008**: Visible and headless resolution of each vertical-slice branch produce identical normalized effects, acknowledgement state, and character/patron progression.
- **SC-009**: A 200-beat stress fixture appends and scrolls without rebuilding prior transcript rows and keeps dialogue presentation below one 16.7 ms frame per reveal update on the reference development machine.
- **SC-010**: Existing EventSystem, Inbox, Dialogue, progression, persistence, playtest, first-town, and deterministic replay suites continue to pass.

## Assumptions

- The first implementation is a conversation foundation plus one real quest vertical slice, not a generic objective tracker or new QuestSystem.
- Ambrose is a temporary visual stand-in for the reserved `player` participant; dedicated player portrait direction is a later art decision.
- Static expression portraits ship first. Existing talking videos remain separate and are not part of expression selection in this milestone.
- Dialogue session presentation state is transient. An interruption before a commit boundary restarts the still-pending node rather than persisting partial text or scroll position.
- A choice label is the canonical player reply text shown in the transcript.
- Node entry effects can be deferred until the node's explicit choice or terminal-completion boundary without changing intended current content behavior.
- Existing input suppression and pending-dialogue persistence contracts remain the integration foundation.
- A full accessibility/settings screen is outside this feature; deterministic instant-text and reveal-rate hooks are included so settings can connect later.
- Dedicated final portrait and frame artwork may replace temporary assets without changing the authored dialogue schema or traversal logic.
