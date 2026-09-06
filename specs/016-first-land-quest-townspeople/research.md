# Research: First Land Quest and Townspeople

## Existing capability audit

- `OpeningTutorial` persists `completion_handoff.applied` before emitting
  `GameEvents.tutorial_opening_completed`. Its Workstream 2 contract explicitly requires
  boot reconciliation and independence from B18 presentation.
- EventSystem loads JSON events, records event counts, persists pending dialogue IDs,
  applies ordered `set_flag` effects, and redispatches pending records after map load.
- Dialogue normalizes two- or three-participant graphs, commits effects late, restarts
  safely after interruption, and has visible/headless traversal parity. It currently
  exposes completion as a return/outcome seam but not a runtime completion signal.
- Sir William already exists as `aristocrat_patron` with portrait and all seven stable
  semantic expressions. No residence/estate building or model currently identifies his
  place in the world.
- Community already uses the canonical quality IDs `opportunity`, `liveability`,
  `beauty`, and `belonging` and gives ordinary residents deterministic weighted
  personalities. Named recurring townspeople need authored anchors, not a replacement
  generator.
- BuildableArea is the only live land-cell authority. Its existing patron donation
  receipt is keyed by patron ID and reserved for the later landmark chain, so reusing
  `aristocrat` for this quest would conflate two progression moments.
- Dialogue's two portrait slots allow at most player plus two NPC participants. Four
  minor viewpoints therefore cannot be staged legibly in one event.
- Dialogue currently maps semantic `player` to Ambrose's portrait and display name.
  Treating Ambrose as a separate NPC while also offering player choices would therefore
  duplicate his identity. The scene package must decide whether the player acts through
  Ambrose or whether a distinct player presentation identity is required.

## Technical decisions

1. **One focused quest reconciler.** Add `FirstLandQuest` as a narrow plugin owning a
   versioned state dictionary. It observes tutorial receipts, event pending/count/flags,
   dialogue completion, and BuildableArea receipts; it never traverses dialogue or edits
   cells directly.
2. **Receipt before dispatch.** Write `activation.applied` before calling EventSystem's
   direct `fire()` entry point. On boot, the same reconciliation checks the durable
   tutorial receipt and dispatches only when neither pending, fired, nor completed.
3. **Use existing late-commit flags.** Approved options set one stable approach flag;
   the shared terminal node sets `first_land_quest_agreed`. Land is not granted from an
   option effect. This keeps an interrupted branch pending and ensures all approved
   branches reach an explicit common agreement.
4. **Add a semantic completion edge.** Dialogue emits a detached completion outcome
   after acknowledgement. The quest reconciler uses it for same-session progress and
   uses flags plus pending IDs on load. This is a small generic seam, not a second event
   authority.
5. **Quest-specific land receipts.** Extend BuildableArea with an idempotent authored
   grant entry point keyed by `grant_id`, persisted separately from patron donations.
   It reuses `LandDonationPayload.cells_from_dict()` and `_expand()`.
6. **Content/data separation.** Store place association, approved scene event IDs,
   grant geometry, and the four stable profile IDs in one quest definition. Dialogue
   prose remains in EventSystem JSON; named townsperson motivations/voice/reaction tags
   live in character definitions.
7. **Staged vignettes.** Use an Ambrose invitation, a player/Ambrose/Sir William
   negotiation, and short two- or three-person reaction vignettes. This exercises the
   established renderer without expanding its participant limit.
8. **Equivalent first parcel by default.** Unless the user explicitly chooses
   branch-dependent outcomes, all petition approaches set different narrative flags but
   converge on the same first grant. A first full quest should not hide a permanent land
   penalty behind an uncalibrated prose choice.
9. **No runtime placeholders without approval.** Workstream 1's labelled placeholder
   content was explicitly approved. That precedent does not authorize new placeholder
   prose here, so event/character implementation waits for this workstream's approval.

## Creative decisions deliberately deferred

- Sir William's residence/estate identity, staging mode, and any required model/art.
- Whether Ambrose is the player's speaking proxy or a separate guide; the latter needs
  an approved player name/presentation mapping before this scene can render correctly.
- The four townspeople's names, biographies, voice anchors, relationships, and portrait
  approach.
- Which workshop beat/choice package becomes the scene and every final written line.
- Whether the immediate-grant recommendation is accepted and the exact parcel geometry.
- Whether reaction vignettes occur before or after the negotiation terminal grant.

## Alternatives rejected

- **Triggering from B18 acknowledgement** is brittle and violates the tutorial handoff
  contract; gameplay completion, not presentation, is authoritative.
- **Reusing the later aristocrat patron donation** would pre-consume the landmark reward
  and couple independent quest chains.
- **Direct `allowed_cells` mutation from dialogue effects** would violate One Gameplay
  Truth and make overlap/idempotency diagnostics inconsistent.
- **One four-NPC group scene** exceeds the established participant contract and would
  turn this narrative slice into a dialogue-renderer redesign.
- **Using random Community residents as the recurring cast** would not provide stable
  identities or authored voice continuity across saves/content.
- **Encoding a townsperson as a stat label** would produce tutorial mascots rather than
  people with conflicting, understandable preferences.
- **Implementing purpose-text placeholders automatically** would bypass the explicitly
  requested collaborative authorship checkpoint.
