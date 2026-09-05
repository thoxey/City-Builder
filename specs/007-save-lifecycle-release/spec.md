# Feature Specification: Save Continuity and Desktop Release

**Feature Branch**: `007-save-lifecycle-release` *(planning identifier; no branch created)*

**Created**: 2026-09-05

**Status**: Draft

**Input**: User description: "Preserve the complete first-town simulation across save and load, add normal game lifecycle screens, and verify a distributable desktop build."

## 1. Purpose

Make the connected first-town loop safe to leave and return to. A player must be
able to start a town, pause, save, quit, relaunch, continue, and receive the same
future simulation outcomes as if play had never been interrupted.

This milestone replaces developer shortcut continuity with a player-facing game
lifecycle and proves the first real desktop export. It does not add new city
simulation systems.

## 2. Scope Boundary

### In scope

- A versioned save-game contract covering all authoritative and accrued
  first-town state.
- Deterministic restoration and reconciliation order.
- At least two manual save slots, one autosave stream, save metadata, and
  corruption-safe writes.
- Backward-compatible loading of current repository saves where possible.
- Title, Continue, New Town, Load, pause, settings, return-to-title, and quit
  flows.
- Autosave at safe progression and time boundaries.
- Basic local desktop settings stored separately from town saves.
- A primary desktop export preset and an exported-build smoke test.
- Release verification that development-only playtest and debug capabilities are
  absent or inert.

### Explicitly out of scope

- Cloud saves, account sync, cross-device transfer, shared towns, or multiplayer.
- Steam/Epic/platform SDKs, achievements, installers, notarisation, store
  submission, patching, or crash telemetry.
- Windows, Linux, console, or mobile certification in the initial milestone.
- Full input remapping, localization, mod save compatibility, or multiple player
  profiles.
- Save thumbnails, replay playback UI, or unlimited named save files.
- Rebalancing connectivity, economy, demand, Community, or progression.
- Persisting transient visual agents, open animations, placement previews, or
  debug sessions.

## 3. Save Continuity Contract

### 3.1 Version and identity

Every new save records:

- a monotonically managed save schema version;
- a stable save/slot identity;
- creation and last-written timestamps;
- game/content version information sufficient to diagnose compatibility;
- a player-facing summary containing town day/time, cash, population/capacity,
  building count, and latest completed patron milestone; and
- the complete authoritative town payload.

The loader validates version, required fields, and payload integrity before
mutating the running town. Unsupported or damaged saves remain listed with a
clear reason and never partially apply.

### 3.2 Persisted authoritative state

The save payload includes at minimum:

- placed structure stable IDs, anchors, orientations, and footprint data needed
  for compatible reconstruction;
- cash and all non-derived economy balances;
- total demand accumulated in every bucket;
- simulation absolute hour and time of day;
- character states, patron states, narrative flags, and event counts;
- buildable cells and completed land donations;
- Community residents, personal seeds, current/target qualities, retention and
  homelessness timers, activity data needed for reconciliation, RNG state,
  migration day/counters, and programmes;
- player-facing town UI preferences that are already save-specific; and
- any milestone-005/006 state that cannot be deterministically derived from the
  fields above.

Fulfilled demand, attractiveness, road components, operational building state,
resident assignments, current output, and current hourly income should be
re-derived from authoritative world state when that yields the same canonical
result. If planning proves any such field cannot be reconstructed without
changing the next simulation outcome, the minimum missing authority must be
persisted and documented.

### 3.3 Transient state

The following are not part of town simulation persistence:

- visible person and car transforms or journey animation progress;
- open radial pages, hover/focus, placement preview, selector position, toast,
  notification animation, or confirmation modal;
- active playtest session IDs, request caches, traces, or debug overlays;
- mesh, graph, catalog, or view-model caches that can be rebuilt; and
- current render interpolation.

A save records only committed gameplay. A placement preview or unconfirmed
replacement is neither charged nor written.

### 3.4 Restore and reconciliation

Loading follows one observable transaction:

1. read and validate the candidate without changing the live town;
2. prepare a compatible canonical payload or report failure;
3. stop simulation advancement and world input;
4. apply structures and authoritative state;
5. rebuild derived registries, demand fulfilment, connectivity, operation,
   attractiveness, progression, Community projections, and UI in documented
   dependency order;
6. emit one canonical load-complete event after all synchronous reconciliation;
7. expose a balance-relevant snapshot for parity verification; and
8. resume in a paused player state so the player can inspect before time moves.

If any required step fails, the prior live town remains intact or the game
returns safely to the title screen. The loader must never present a partially
restored city as successful.

### 3.5 Deterministic continuation

For the same save and subsequent ordered inputs:

- loading twice produces equivalent post-load balance state;
- advancing a declared number of hours after load produces the same result as an
  uninterrupted run from the save point; and
- transient visual differences do not participate in the balance hash.

## 4. Slot and Autosave Contract

- The player has at least two manual slots and one autosave stream.
- Continue opens the newest valid save across those sources.
- Each slot shows its validation state and summary before the player commits to
  loading or overwriting it.
- Overwriting a populated manual slot requires confirmation.
- Saving writes a temporary candidate, validates it, atomically replaces the
  destination, and retains the previous valid revision as a recovery backup.
- A failed or interrupted write preserves the prior valid slot.
- Autosave occurs at a safe in-game day boundary, first-patron/land-expansion
  milestone, and intentional return to title or quit when committed state has
  changed.
- Autosaves are coalesced so several events in one action do not trigger several
  writes.
- Manual saving is available from the pause menu when the current state can be
  serialized safely.
- Existing `map_slot1.res`, `map_slot2.res`, and compatible current-save data are
  detected through a documented one-time migration or legacy-load path rather
  than silently ignored.

## 5. Player Lifecycle and Settings

### 5.1 Title screen

The title screen provides:

- **Continue** — enabled only when a valid save exists;
- **New Town** — starts the canonical fresh-map state, with confirmation if it
  would discard unpersisted active progress;
- **Load Town** — opens the slot browser;
- **Settings** — opens local presentation settings; and
- **Quit** — exits the desktop application cleanly.

The title screen must not instantiate or advance a live town simulation behind
the menu.

### 5.2 Pause menu

Pause stops simulation time and world actions while retaining the rendered town.
It provides Resume, Save Town, Load Town, Settings, Return to Title, and Quit.
Destructive navigation warns when committed changes have not been saved or
autosaved successfully.

Dialogue, inbox, radial, inspection, placement, demolition, and overbuild modes
must resolve input priority deterministically with pause. Pausing never confirms
or cancels a pending gameplay action implicitly.

### 5.3 Local settings

The initial settings scope includes:

- master, music/ambience, and effects volume;
- windowed/full-screen display mode; and
- supported UI/text scale.

Settings persist independently of town slots and apply at title and in-game.
Input rebinding and platform-specific graphics presets are deferred.

## 6. User Scenarios & Testing

### User Story 1 — Continue the same town after relaunch (Priority: P1)

As a player, I can save, quit the application, relaunch it, and continue from the
same town state without losing progress or changing future simulation outcomes.

**Why this priority**: A city builder requires durable multi-session play. A
save that restores only visible buildings but changes the simulation is not
continuity.

**Independent Test**: Play the connected canonical town to a mid-progression
checkpoint, save, capture state, terminate, relaunch, Continue, capture state,
then advance both loaded and uninterrupted branches by the same 168 hours.

**Acceptance Scenarios**:

1. **Given** a valid manual save, **When** the game is relaunched and Continue is selected, **Then** the restored balance-relevant state matches the saved checkpoint.
2. **Given** loaded and uninterrupted branches from the same checkpoint, **When** identical actions and 168 hours are applied, **Then** their milestone outcomes and final state hashes are equivalent.
3. **Given** an in-progress placement preview, **When** the town is saved from a valid pause state, **Then** only previously committed buildings and costs appear after load.

---

### User Story 2 — Manage understandable save slots (Priority: P1)

As a player, I can identify, create, overwrite, and load local saves without
remembering developer keyboard shortcuts or file paths.

**Why this priority**: Player-facing continuity requires discoverable slots and
safe destructive actions.

**Independent Test**: Create two towns in separate manual slots plus an
autosave, inspect their summaries, overwrite one with confirmation, and load
each remaining valid state.

**Acceptance Scenarios**:

1. **Given** empty and populated slots, **When** the browser opens, **Then** each slot clearly shows empty, valid, legacy, recoverable, damaged, or unsupported state.
2. **Given** a populated manual slot, **When** overwrite is requested, **Then** confirmation identifies the town summary being replaced.
3. **Given** multiple valid saves, **When** Continue is selected, **Then** it loads the most recently completed valid write rather than an invalid newer file.
4. **Given** a legacy compatible save, **When** it loads successfully, **Then** the next manual save writes the current schema without overwriting the legacy source until validation succeeds.

---

### User Story 3 — Pause and leave safely (Priority: P1)

As a player, I can pause at any ordinary gameplay moment and leave or change
settings without the town progressing behind the menu.

**Why this priority**: Reliable lifecycle boundaries are necessary for both save
safety and ordinary play.

**Independent Test**: Open each interactive game mode, invoke pause, attempt
world input, change a setting, resume, and verify time/action ownership.

**Acceptance Scenarios**:

1. **Given** normal play, **When** pause opens, **Then** simulation hours, placement, demolition, camera actions, and inspection stop until Resume.
2. **Given** dialogue or confirmation owns input, **When** pause is requested, **Then** one documented priority rule prevents both interfaces acting on the same input.
3. **Given** unsaved committed changes and a failed autosave, **When** Return to Title or Quit is selected, **Then** the player receives a clear save/discard/cancel choice.
4. **Given** changed audio or display settings, **When** the game returns to title or relaunches, **Then** those settings remain applied independently of the loaded town.

---

### User Story 4 — Recover safely from damaged or older saves (Priority: P1)

As a player, I am not trapped or allowed to destroy a good town when one save is
damaged, interrupted, or from an older compatible schema.

**Why this priority**: Save corruption has disproportionate impact in a
long-running city builder.

**Independent Test**: Exercise truncated, invalid, unsupported, interrupted-write,
backup-recovery, and supported-legacy fixtures without mutating a loaded control
town.

**Acceptance Scenarios**:

1. **Given** a corrupt primary slot with a valid backup, **When** recovery is chosen, **Then** the backup loads and remains distinguishable until saved normally.
2. **Given** a corrupt slot without recovery, **When** it is selected, **Then** loading is blocked with an actionable reason and the current town is unchanged.
3. **Given** an unsupported future schema, **When** inspected, **Then** the game refuses to guess or downgrade it destructively.
4. **Given** an interrupted replacement write, **When** the game restarts, **Then** the last completed valid revision remains available.

---

### User Story 5 — Run a real desktop build (Priority: P2)

As a developer or tester, I can launch a distributable desktop build and complete
the core start-save-relaunch-continue loop without editor or development
services.

**Why this priority**: Release-only failures and accidental debug tooling cannot
be proven absent through unit policy checks alone.

**Independent Test**: Produce the primary desktop export, launch it outside the
editor, start a town, play through 24 simulation hours, save, quit, relaunch,
Continue, and inspect plugin/runtime state.

**Acceptance Scenarios**:

1. **Given** the release preset, **When** the project exports, **Then** all required scenes, models, data, UI assets, fonts, sound, and save migrations are included.
2. **Given** the exported build, **When** it launches, **Then** no Playtest, RoadDebug, QuestDebug, MCP service, or developer command surface is active.
3. **Given** a release-created save, **When** the build relaunches and Continues, **Then** the restored town passes the same parity contract as the development build.
4. **Given** a normal quit, **When** all writes finish or the player elects to discard, **Then** the process exits without leaving a partial destination save.

## 7. Edge Cases

- No saves exist, only an autosave exists, or the newest file is invalid.
- Two files report identical timestamps.
- A save is attempted while placement, demolition, overbuild confirmation,
  dialogue, or inbox interaction is active.
- Several autosave triggers occur in one landmark-completion call stack.
- The application closes during temporary write, validation, replacement, or
  backup rotation.
- Disk write fails or local storage is unavailable.
- A save references a removed building, character, patron, event, programme, or
  model.
- A legacy building has no stored footprint cells or uses a changed footprint.
- A save contains residents beyond current housing capacity.
- A save occurs immediately before migration, departure, opening-hour, or tier
  transition and resumes on the exact boundary.
- A route or operational assignment changed immediately before save.
- Loading while a different live town exists fails midway.
- Full-screen or UI-scale settings make lifecycle controls exceed 1280×720.
- A release build attempts to deserialize debug-only state.
- The player requests quit while a save is still in progress.

## 8. Requirements

### Functional Requirements

- **FR-001**: Every newly written town save MUST declare a save schema version and stable slot identity.
- **FR-002**: Save metadata MUST provide last-written time, game/content version, day/time, cash, population/capacity, building count, and latest patron milestone without loading the town into play.
- **FR-003**: The save payload MUST contain every authoritative and accrued field listed in section 3.2.
- **FR-004**: Accrued demand totals and simulation absolute hour/time of day MUST round-trip exactly.
- **FR-005**: Derived state MAY be rebuilt only when rebuilding produces the same canonical post-load and subsequent simulation outcomes.
- **FR-006**: Transient state listed in section 3.3 MUST NOT affect save parity or be restored as committed gameplay.
- **FR-007**: Loading MUST validate and prepare a candidate before mutating the current live town.
- **FR-008**: Loading MUST reconcile systems in documented dependency order and publish success only after canonical state is ready.
- **FR-009**: A failed load MUST preserve the prior live town or return safely to title without presenting partial success.
- **FR-010**: Identical continuation inputs after load MUST produce the same balance-relevant outcomes as uninterrupted play.
- **FR-011**: The game MUST provide at least two manual save slots and one autosave stream.
- **FR-012**: Continue MUST select the newest valid completed save and MUST ignore invalid newer candidates.
- **FR-013**: Manual overwrite MUST require confirmation with the destination slot summary.
- **FR-014**: Writes MUST use validated temporary output, atomic destination replacement, and one prior valid recovery revision.
- **FR-015**: Interrupted or failed writes MUST leave the prior completed destination loadable.
- **FR-016**: Autosaves MUST trigger at safe day, major progression, and intentional-exit boundaries and MUST coalesce duplicate triggers.
- **FR-017**: The loader MUST support or clearly reject current legacy slot files through a non-destructive documented migration path.
- **FR-018**: New Town, Continue, Load Town, Settings, and Quit MUST be available from a title screen that does not advance a hidden town.
- **FR-019**: Pause MUST stop simulation and world actions and provide Resume, Save, Load, Settings, Return to Title, and Quit.
- **FR-020**: Pause and every existing modal/tool mode MUST have one deterministic input-priority contract.
- **FR-021**: Unsaved progress plus failed/no autosave MUST produce a save/discard/cancel choice before destructive navigation.
- **FR-022**: Master, ambience/music, effects, display mode, and supported UI/text scale settings MUST persist separately from town saves.
- **FR-023**: A primary desktop export preset MUST include every runtime dependency and exclude editor-only content where safe.
- **FR-024**: Playtest, MCP, QuestDebug, RoadDebug, and developer command capabilities MUST be absent or inert in the exported release.
- **FR-025**: The exported build MUST complete the start, 24-hour play, save, quit, relaunch, and Continue smoke flow.
- **FR-026**: Save/load operations MUST expose structured success or failure reasons suitable for UI and automated tests.
- **FR-027**: Save and migration behavior MUST have fixture coverage for valid, legacy, corrupt, unsupported, interrupted, and recoverable states.
- **FR-028**: The milestone-005 progression and milestone-006 connected-balance scenarios MUST remain deterministic across save/load boundaries.

### Key Entities

- **Save Envelope**: Schema, identity, timestamps, version compatibility, summary, integrity status, and authoritative payload.
- **Town Payload**: Persisted committed state needed to reconstruct one town and its future deterministic simulation.
- **Save Slot**: Manual or autosave destination, current validation state, summary, primary revision, and recovery revision.
- **Load Transaction**: Candidate validation, compatibility/migration, staged application, reconciliation, outcome, and parity snapshot.
- **Local Settings**: Device-level audio, display, and accessibility presentation preferences independent of town data.
- **Lifecycle State**: Title, loading, playing, paused, saving, returning to title, and quitting, with allowed transitions and input owner.
- **Release Artifact**: Exported desktop build, content version, preset, and smoke-test evidence.

## 9. Success Criteria

### Measurable Outcomes

- **SC-001**: A checkpoint captured immediately before save and immediately after load has an equivalent balance-relevant snapshot after excluding documented transient fields.
- **SC-002**: Ten loaded continuations and ten uninterrupted continuations from the same checkpoint produce equivalent final hashes after 168 identical simulation hours.
- **SC-003**: Save fixtures at every milestone-005 progression boundary restore the same building set, cash, demand totals, clock, residents, land, character/patron state, flags, programmes, and event counts.
- **SC-004**: In every simulated interrupted-write phase, the previous completed slot remains valid and loadable.
- **SC-005**: Valid, legacy, corrupt, unsupported, interrupted, and recoverable fixtures all produce their specified structured outcomes without partially changing a control town.
- **SC-006**: Continue chooses the newest valid completed save in 100% of ordering and corruption fixtures.
- **SC-007**: Title, save browser, pause, settings, destructive-navigation confirmation, and Continue flows are fully operable by keyboard and gamepad at 1280×720.
- **SC-008**: A representative save containing at least 100 buildings and 500 residents validates, loads, reconciles, and becomes interactive within two seconds on the development machine.
- **SC-009**: The primary desktop release export completes successfully and launches without missing-resource or parse errors.
- **SC-010**: The exported build completes the full start, 24-hour play, save, quit, relaunch, and Continue smoke test with no editor connection.
- **SC-011**: Release inspection finds zero active development-only services or player-visible developer controls.
- **SC-012**: All existing Godot, server, deterministic scenario, Community, progression, connectivity, Player UI, and release-gate tests remain passing.

## 10. Assumptions

- Milestones 005 and 006 have produced a reachable and balanced canonical town
  whose state is the continuity acceptance payload.
- The initial supported release target is macOS desktop on the current
  development environment; other desktop platforms can reuse the contract in
  later milestones.
- Local filesystem saves are sufficient; no account or network service is
  required.
- At least two manual slots preserve the current two-slot expectation while the
  autosave provides Continue and recovery convenience.
- One recovery revision per slot is adequate for the first release.
- Existing Godot `Resource` saves may be migrated or wrapped, provided the new
  envelope can be validated before applying it.
- Save summaries use text and metadata only; thumbnails are deferred.
- Returning to title or quitting may wait briefly for a current save transaction
  to finish, with visible status and a bounded failure path.

## 11. Test Seams

- **Unit**: envelope validation, schema migration, summary ordering, slot
  selection, atomic-write state machine, settings, and lifecycle transitions.
- **Integration**: Builder/DataMap through clock, Demand, Community,
  CharacterSystem, PatronSystem, BuildableArea, connectivity, economy, UI, and
  one load-complete boundary.
- **Determinism**: checkpoint/load versus uninterrupted branch comparison over
  identical action lists and 168 hours.
- **Fault injection**: every read/write/replacement stage, corrupt payloads,
  missing content, unsupported versions, and recovery revision selection.
- **UI**: title, slot browser, pause, settings, confirmations, input priority,
  accessibility, and 1280×720 layout.
- **Release**: actual exported artifact launch, runtime dependency inspection,
  development-plugin absence, and end-to-end continuation smoke.

## 12. Dependency and Handoff

This specification depends on both `005-reachable-first-patron` and
`006-connected-first-town-loop`. It is complete only when the canonical town can
cross a real process boundary and continue with equivalent future outcomes in an
exported desktop build.
