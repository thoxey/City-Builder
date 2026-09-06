# Feature Specification: UI and Feedback Improvements

**Feature Branch**: `017-ui-feedback-improvements`
**Created**: 2026-09-06
**Status**: Implemented and verified
**Input**: Workstream 4 in `NEXT_IDEA_PROMPTS.md`

## Scope

This feature improves the legibility of community-value language, demand
progression, placement feedback, and the authored effects of the building held
for placement. It reuses the established UI and Community icon families.

Tile-specific simulation, affected-neighbour evaluation, hovered-cell totals,
and comparisons between map locations are explicitly excluded. Those belong to
workstream 5, “Live placement consequences.” No balance, authored dialogue, or
building-effect values change in this workstream.

## User Scenarios & Testing

### User Story 1 - Community language is visually anchored (Priority: P1)

When Ambrose speaks the names Opportunity, Livability (or the established
British spelling Liveability), Beauty, and Belonging, each whole keyword has its
matching Community icon immediately beside it.

**Independent Test**: Present an Ambrose line containing mixed capitalization,
repeated keywords, punctuation, wrapping, and an absent icon; verify exact
authored text remains available, every resolvable whole-word occurrence maps to
the correct icon, and missing art falls back to text alone.

**Acceptance Scenarios**:

1. **Given** Ambrose says all four keywords, **When** the line is rendered,
   **Then** every occurrence has the matching established icon beside it.
2. **Given** a keyword differs only by capitalization or uses “Liveability,”
   **When** it is rendered, **Then** it maps without changing the authored word.
3. **Given** a keyword is repeated or adjacent to punctuation, **When** the line
   wraps, **Then** all whole-word instances remain represented and readable.
4. **Given** the icon resource is missing, **When** the line is rendered,
   **Then** the exact authored text remains readable with no broken markup.
5. **Given** another character or narration uses the same word, **When** it is
   rendered, **Then** this Ambrose-specific treatment is not applied.

---

### User Story 2 - Demand progression is explicit (Priority: P1)

Hovering Homes, Work, or Shops demand shows the current spendable amount and
the lifetime total ever earned using unambiguous labels. Lifetime-based unique
building requirements are listed as lifetime targets, including the 75 Homes
target for the Postwar Mid-Block.

**Independent Test**: Supply known current/lifetime bucket snapshots and unique
profiles, refresh the status bar, and assert the three values and unlock target
copy independently of on-screen abbreviation.

**Acceptance Scenarios**:

1. **Given** Homes demand has 18 available and 75 lifetime, **When** hovered,
   **Then** the tooltip says “Current available: 18” and “Lifetime earned: 75.”
2. **Given** the Postwar Mid-Block requires 75 lifetime Homes demand, **When**
   Homes demand is hovered, **Then** the building name and 75 lifetime target
   are visible even if other prerequisites are unmet.
3. **Given** Work or Shops demand is hovered, **When** profiles exist for that
   bucket, **Then** only that bucket’s lifetime targets are listed in threshold
   order.

---

### User Story 3 - Placement feedback lingers without clutter (Priority: P2)

Community-value icons rising from a newly placed building lose opacity more
quickly at the start, then ease into a slower taper over a bounded lifetime.

**Independent Test**: Sample the canonical feedback-alpha function at declared
times and verify it is monotonic, initially steeper than its final taper, fully
visible at start, and zero at the bounded end.

**Acceptance Scenarios**:

1. **Given** a building with authored Community or base Beauty effects is
   placed, **When** feedback appears, **Then** its icons rise and share the same
   bounded eased opacity curve.
2. **Given** the feedback lifetime elapses, **When** the animation completes,
   **Then** the feedback node is removed and cannot become permanent clutter.

---

### User Story 4 - A held building explains its authored trade-offs (Priority: P1)

While a building is held for placement, the dock shows its authored costs and
intrinsic Community effects using signed values and established icons. Demand
uses the relevant Homes, Work, or Shops icon; Community values use Opportunity,
Liveability, Beauty, and Belonging icons. Cash is shown when non-zero.

**Independent Test**: Feed the dock a detached palette entry containing cash,
demand, base Beauty, and Community effects, then verify the projected rows,
signs, icon resources, fallbacks, and absence of placement-cell preview data.

**Acceptance Scenarios**:

1. **Given** a held building costs 5 Homes demand, **When** placement begins,
   **Then** a Homes icon and `-5` are shown.
2. **Given** it has `+4 Beauty` and `-2 Liveability` authored effects, **When**
   held, **Then** signed rows with the corresponding icons are shown.
3. **Given** a pool contains differing authored values, **When** its stable
   representative is held, **Then** the dock labels the representative values
   rather than inventing a combined or tile-specific result.
4. **Given** placement moves between map cells, **When** the tile preview changes,
   **Then** these authored rows do not absorb neighbour, exposure, or simulated
   location consequences.

## Requirements

- **FR-001**: Keyword decoration MUST apply only to Ambrose-presented speech.
- **FR-002**: Keyword matching MUST be case-insensitive, whole-word, repeatable,
  punctuation-safe, and support both `Livability` and `Liveability`.
- **FR-003**: Decoration MUST preserve the exact authored text for reveal,
  persistence, diagnostics, accessibility, and missing-resource fallback.
- **FR-004**: Inline icons MUST use the established game-ready Community assets
  and MUST remain adjacent to the named word under supported wrapping.
- **FR-005**: Homes, Work, and Shops hover details MUST separately label current
  spendable demand and monotonic lifetime demand.
- **FR-006**: Demand hover details MUST expose every positive lifetime-based
  unique-building threshold for their bucket with an authored display name.
- **FR-007**: Lifetime requirements MUST never be described as current/spendable
  requirements.
- **FR-008**: Placement feedback opacity MUST be deterministic, monotonic, reach
  zero within 3.5 seconds, and decay more steeply during its first half than its
  final quarter.
- **FR-009**: Placement feedback MUST remove itself when the animation completes.
- **FR-010**: The held-building dock MUST show non-zero cash cost, demand cost,
  authored base Beauty, and authored Community effects with explicit signs.
- **FR-011**: Held-building effect rows MUST use established icons and text, so
  colour is not the sole carrier of quality, polarity, or cost.
- **FR-012**: The dock MUST derive these rows solely from the selected palette
  entry’s authored/base metadata and MUST ignore hovered-cell preview data.
- **FR-013**: Missing optional icons MUST retain a readable signed text fallback.
- **FR-014**: The three changed surfaces MUST remain readable at 1280×720,
  1920×1080, and 3840×2160 without blocking placement controls.

## Success Criteria

- **SC-001**: Automated mapping tests pass for all four qualities, both
  liveability spellings, mixed case, repeats, substrings, and missing icons.
- **SC-002**: Automated demand tests prove current/lifetime values and the 75
  Homes lifetime target are presented distinctly.
- **SC-003**: Automated placement-dock tests prove every displayed number is
  signed and sourced only from authored entry metadata.
- **SC-004**: Automated timing tests prove the opacity curve and cleanup bound.
- **SC-005**: Visual evidence at all three supported resolutions shows readable
  wrapped dialogue, hover details, held-building rows, and representative
  feedback-animation samples.
