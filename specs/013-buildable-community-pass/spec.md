# Feature Specification: Buildable Area and Community Quality Playtest Pass

**Feature Branch**: `013-buildable-community-pass`
**Created**: 2026-09-06
**Status**: Complete
**Input**: Make the buildable boundary legible in play, enlarge the rooted starter plot to 16×16, and make a measured early-game Liveability/Beauty/Belonging tuning pass.

## User Scenarios & Testing

### User Story 1 - Read the available land at a glance (Priority: P1)

A player can see the complete land they may build on during normal play and can read it even more clearly while choosing or previewing a building.

**Why this priority**: The buildable mask is a foundational spatial rule; hiding it makes every placement decision harder to understand.

**Independent Test**: Start and load a game, open and close the build menu, enter placement, and apply a land donation. At normal gameplay zoom, buildable land remains clear while a white veil covers only the non-buildable rendered terrain without covering roads, buildings, previews, or selection feedback.

**Acceptance Scenarios**:

1. **Given** a fresh game, **When** normal gameplay begins, **Then** every buildable cell remains visually clear and every non-buildable ground cell has a subtle 5%-opacity white overlay.
2. **Given** the build menu or placement preview is active, **When** the mode changes, **Then** the non-buildable veil becomes more prominent without changing legal cells.
3. **Given** a saved game or a patron expansion, **When** the authoritative mask changes, **Then** the presentation is rebuilt from the current `BuildableArea` cells.

---

### User Story 2 - Begin with modestly more rooted-town space (Priority: P2)

A fresh rooted town begins with a 16×16 area centred around the origin, while legacy non-rooted fixtures keep their 8×8 area.

**Why this priority**: The first connected-town layout needs a little more room without invalidating historical fixtures.

**Independent Test**: Seed rooted and non-rooted maps and inspect exact bounds/counts, then apply overlapping and non-overlapping donations twice.

**Acceptance Scenarios**:

1. **Given** a fresh rooted map, **When** `BuildableArea` seeds, **Then** it contains exactly 256 cells from `(-8,-8)` through `(7,7)`.
2. **Given** a fresh non-rooted map, **When** it seeds, **Then** it retains the 64-cell 8×8 legacy mask.
3. **Given** donated land, **When** expansion is applied, **Then** only previously unavailable cells are added and replaying the donation adds none.

---

### User Story 3 - Shape all three early community qualities (Priority: P3)

A player making ordinary early choices can improve Liveability, Beauty, and Belonging, while poor adjacency remains harmful and repeated identical buildings have sharply bounded returns.

**Why this priority**: Each displayed quality needs an understandable, reachable feedback loop during the opening town.

**Independent Test**: Run fixed-seed evaluator and full-town fixtures for mixed, poor-adjacency, repeated-source, and save/load cases.

**Acceptance Scenarios**:

1. **Given** a connected early town with housing, local commerce, and functional nature, **When** several hours pass, **Then** average Liveability, Beauty, and Belonging all rise above the neutral baseline.
2. **Given** homes next to noisy/visually harsh early industry and Town Hall bustle, **When** effects are evaluated, **Then** the relevant qualities are lower than in the sensible mixed layout and the negative source/reason remains visible.
3. **Given** four or more identical positive sources, **When** effects are evaluated, **Then** the fourth and later copies add no score beyond the existing diminishing-return ceiling.
4. **Given** a tuned community state, **When** it is persisted and loaded into a fresh Community instance, **Then** current/target qualities and composite happiness are preserved.

### Edge Cases

- Irregular or disjoint donation masks punch transparent holes for every authoritative cell rather than assuming one bounding rectangle.
- An empty or unavailable map hides the overlay safely.
- Expansion overlap does not create duplicate cells or double-draw authority state.
- Build-menu emphasis and placement emphasis share one presentation state and do not affect placement evaluation.
- Negative and positive effects in the same stacking group retain independent diminishing-return sequences.

## Requirements

### Functional Requirements

- **FR-001**: The game MUST leave every authoritative buildable cell clear and render a persistent perceptual 5%-opacity white overlay over non-buildable rendered terrain.
- **FR-002**: The non-buildable overlay MUST be visually stronger while the radial build menu or placement mode is active.
- **FR-003**: Roads, structures, selection markers, and placement previews MUST remain readable above or through the buildable presentation.
- **FR-004**: The presentation MUST refresh after initial seed, `map_loaded`, and `buildable_area_expanded`.
- **FR-005**: Presentation code MUST query `BuildableArea`; it MUST NOT maintain or consult a second legality mask.
- **FR-006**: A fresh rooted town MUST seed `Rect2i(-8, -8, 16, 16)` (256 unique cells).
- **FR-007**: A non-rooted/legacy map MUST continue to seed `Rect2i(-4, -4, 8, 8)` (64 unique cells).
- **FR-008**: Donation expansion MUST add only cells absent from the authoritative set, persist the result, and remain idempotent by patron receipt.
- **FR-009**: Existing community effects/baselines/radii/response mechanisms MUST be tuned so ordinary early housing, commerce, civic, and nature choices can improve Liveability, Beauty, and Belonging.
- **FR-010**: Existing legible negative local effects MUST remain and must be avoidable by spatial separation.
- **FR-011**: Repeated identical positive effects MUST retain a hard diminishing-return ceiling: multipliers 1.0, 0.5, 0.25, then 0.0.
- **FR-012**: Community save/load MUST preserve the resulting current qualities, target qualities, and composite happiness; applied-effect diagnostics remain derived from current buildings on the next simulation tick.
- **FR-013**: The pass MUST NOT add a new simulation system, change placement legality, or modify unrelated content.
- **FR-014**: The normal starting camera framing MUST show the complete rooted 16×16 perimeter at 1280×720 while retaining the existing player zoom range.

### Key Entities

- **BuildableArea mask**: Unique `Vector2i` cells owned by the BuildableArea plugin and mirrored to `DataMap` for persistence.
- **Buildable-area presentation**: A derived ground plane whose mask texture is transparent for authoritative cells and white for non-buildable rendered terrain.
- **Community effect**: Existing authored quality delta with scope, radius/schedule, manifestation, reason, and stacking group.
- **Community resident state**: Persisted current/target quality values and composite happiness; applied-effect diagnostics are derived again from current buildings.

## Success Criteria

### Measurable Outcomes

- **SC-001**: At 1280×720 and normal gameplay zoom, a captured fresh-town frame visibly shows all four sides of the 16×16 starter boundary.
- **SC-002**: Automated mask assertions report 256 transparent buildable cells and 261,888 veiled cells across the 512×512 rendered terrain, with normal opacity exactly 5% perceptual / 0.0125 linear and a stronger 8% / 0.02 active mode.
- **SC-003**: Rooted and legacy seed tests pass with exact counts/bounds of 256/`(-8..7)` and 64/`(-4..3)` respectively.
- **SC-004**: Donation tests prove exact unique-cell deltas and no change from a repeated receipt.
- **SC-005**: A fixed-seed ordinary mixed early town ends with average Liveability, Beauty, and Belonging each above 50.
- **SC-006**: A deterministic poor-adjacency case scores lower in its affected qualities than the matched sensible case.
- **SC-007**: A deterministic repeated-identical-source case proves source four and later add exactly 0.0 beyond the 1.75× group ceiling.
- **SC-008**: Save/load comparison preserves each resident's current qualities, target qualities, and composite happiness exactly.

## Assumptions

- The current isometric camera, ground grid, and transparent unshaded materials remain in use.
- `player_input_mode_changed` is the canonical presentation signal for build-menu and placement emphasis.
- Existing nature places are functional, cash-costed, and road-rooted; no new decorative source is introduced.
- The existing deterministic evaluator stacking curve is retained and made explicit in coverage rather than redesigned.
