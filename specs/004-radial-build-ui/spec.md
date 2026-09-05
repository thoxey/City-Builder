# Feature Specification: Radial Build UI and Player HUD

**Feature Branch**: `004-radial-build-ui` *(planning identifier; no branch created)*

**Created**: 2026-09-04

**Status**: Draft

**Input**: User description: "Make a full UI plan with radial creation menus with icons, and remove the existing debug panels."

## Purpose

Replace the prototype's overlapping text panels and keyboard-reference overlays
with a coherent player-facing interface. Building creation becomes a fast,
icon-led two-level radial flow; resources, town health, time, notifications, and
insight panels occupy stable screen regions; development controls no longer
appear in ordinary play.

This feature changes presentation and input routing, not placement,
affordability, unlock, demolition, simulation, or save/load rules. Every build
selection and action still delegates to Palette, Builder, Economy, Demand,
UniqueRegistry, and Community.

## Screen Architecture

### Top status bar

One responsive bar replaces duplicate counters. It contains cash and hourly
balance; attractiveness and output; residential, industrial, and commercial
demand; population/capacity and Community happiness; and compact entry points
for Town Insights and Inbox. At 1280 px, secondary labels may collapse to icons
with tooltips, but values and warnings remain available. Satisfaction and
Community happiness remain explicitly distinct.

### Bottom tool dock

A bottom-centre dock contains Build, the current tool, and contextual prompts.
During placement it shows the selected icon/name, cost or demand gate, rotate,
place, and cancel. During demolition it uses an unmistakable destructive state.
Day/Night remains bottom-right, restyled in the shared theme. Notifications do
not obscure the dock.

### Right insight drawer

The existing Community/Patrons drawer remains the single detailed right-side
surface. Inbox and Dialogue retain their existing higher interaction priority.

### Removed prototype/debug surfaces

| Existing surface | Current owner | Outcome |
|---|---|---|
| `M3 Debug` Satisfy/Complete/Reset strip | `QuestDebug` | No player UI; progression remains testable through development interfaces. |
| Save/load/clear/control legend | `Main/CanvasLayer/DevCommands` | Remove from scene. |
| Large instruction texture | `Main/CanvasLayer/Bottom/Instructions` | Remove; controls are engine text in context. |
| Duplicate `Res`, `Com`, `Work` labels | `Main/CanvasLayer/Top` | Remove; unified bar owns these values. |
| Bottom-left `Build (Q/E)` list | `Palette` | Replace with radial menus and tool dock. |
| Road direction/network overlay | `RoadDebug` | Debug-build only and hidden by default; absent/inert in release. |

Save/load/clear shortcuts may remain available to developers in debug builds,
but MUST NOT occupy or be advertised in the player HUD. Playtest remains
development-only and headless.

## Radial Creation Menu

### Entry and geometry

- Open through a `build_menu` action (default keyboard `B`), gamepad face
  button, or Build dock button.
- Open around the pointer for mouse and screen centre for keyboard/gamepad,
  clamped inside a safe area.
- Use at most eight equal-angle wedges, minimum 56 px icon targets at 1280×720,
  and a dead zone that prevents accidental selection.
- The centre action is Close on categories and Back on items.
- While open, the radial owns input and suspends camera, placement, demolition,
  and world inspection.

### Two-level hierarchy

The first wheel contains only non-empty authored groups, in this order:

1. Roads & Paths
2. Homes
3. Commerce
4. Industry
5. Nature
6. Leisure & Civic
7. Landmarks & Story

Selecting a group opens its item wheel. A group over eight entries uses seven
items plus Next; later pages include Previous while never exceeding eight
wedge actions. Ordering is stable and authored. A pool remains one player item
(for example, House); the existing placement rule still chooses its variant.

### Wedge content and availability

Each wedge has a unique silhouette icon, short engine-rendered label, visible
focus outline/lift, and a pattern plus lock/block glyph when unavailable.
Focused item details show name, cash cost, demand cost, uniqueness/prerequisite
state, and one canonical unavailable reason. Unavailable entries remain visible
for progression clarity but cannot enter placement. Text is never baked into
art.

### Input behavior

- Pointer: hover focuses, click confirms, and click centre/outside closes.
- Keyboard: arrows or Q/E move, Enter/Space confirms, Escape backs/closes.
- Gamepad: left stick selects by angle after a dead-zone threshold, confirm
  selects, cancel backs; returning to centre keeps the last deliberate focus.
- Focus order is deterministic and state meaning never relies on color alone.

### Placement handoff

Confirming an available item closes the radial, selects Palette by stable ID,
and enters the existing Builder preview. The same item stays active after a
successful placement. Escape cancels placement; reopening restores the last
valid group/page/current item. If availability changes, Palette publishes the
canonical state, Builder updates safely, and the dock explains the block.
Radial selection never mutates cash, demand, progression, GridMap, or saves.

## Icon and Theme System

The UI uses the established mid-century British comic language: near-black
hand-inked structure, parchment grounds, flat muted colors, strong silhouettes,
and restrained emphasis marks.

- Icons are fixed-size RGBA PNG symbols with high-resolution masters and
  separate runtime derivatives.
- HUD icons display at 16–24 px; dock/item icons at 24–32 px; radial icons at
  56–72 px. Default runtime exports are 128 px compact and 256 px radial.
- Building nouns remain green; capacity/growth orange; civic systems teal;
  available emphasis mustard; care/happiness rose; warnings/destruction red;
  inactive structure olive-grey.
- Every entry authors `ui_group`, `ui_order`, and `ui_icon` in its building or
  pool data. A category fallback and a generic missing-art icon prevent broken
  controls.
- A shared Godot Theme owns colors, fonts, spacing, StyleBoxes, focus states,
  and metrics. Radial arcs, hit regions, labels, values, and focus geometry are
  engine-rendered.
- Handoff includes masters, runtime derivatives, manifest records, and
  actual-size proofs over parchment and the busiest gameplay screenshot.

## User Scenarios & Testing

### User Story 1 — Choose and place visually (Priority: P1)

As a player, I can choose a building from icons and categories without cycling
through an opaque list.

**Why this priority**: Building is the primary interaction loop.

**Independent Test**: From a fresh city, select Roads & Paths → Road, place
three cells, then select Nature → Duck Pond and place it.

**Acceptance Scenarios**:

1. **Given** normal play, **When** Build opens, **Then** the category wheel is fully visible and world actions are suspended.
2. **Given** a category, **When** confirmed, **Then** its items show icons, names, and canonical availability.
3. **Given** an available item, **When** confirmed, **Then** the existing Builder preview shows it.
4. **Given** a pooled item, **When** placed repeatedly, **Then** authoritative pool selection is unchanged.
5. **Given** placement, **When** Escape is pressed, **Then** it ends without placing or charging.

---

### User Story 2 — Understand unavailable choices (Priority: P1)

As a player, I can see locked choices and what they require instead of having
them silently disappear.

**Why this priority**: Resource and progression rules must be explainable.

**Independent Test**: Verify cash-, demand-, story-, and already-built gates in
a fresh city against Palette's canonical decisions.

**Acceptance Scenarios**:

1. **Given** insufficient cash, **When** an item is focused, **Then** cost, block pattern, and cash reason appear.
2. **Given** unmet demand/story prerequisites, **When** focused, **Then** readable requirements appear without internal IDs.
3. **Given** a unique already placed, **When** shown, **Then** it cannot be confirmed.
4. **Given** availability changes while open, **When** Palette refreshes, **Then** focus remains stable where possible and the new rule cannot be bypassed.

---

### User Story 3 — Play without prototype clutter (Priority: P1)

As a player, I see one readable HUD and no debug or duplicate panels.

**Why this priority**: Old overlays otherwise compete with the new menu.

**Independent Test**: Launch normal debug play and a release export at 1280×720
and compare the screen with the removal inventory.

**Acceptance Scenarios**:

1. **Given** ordinary play, **When** loaded, **Then** all six replaced/removed surfaces are absent.
2. **Given** release, **When** loaded, **Then** QuestDebug, RoadDebug, and Playtest are absent or inert.
3. **Given** debug play without an explicit overlay flag, **When** loaded, **Then** RoadDebug is hidden and test tooling has no panel.
4. **Given** drawer, Inbox, time controls, and dock, **When** each is used at 1280×720, **Then** primary actions remain unobscured.

---

### User Story 4 — Build without a mouse (Priority: P2)

As a keyboard or gamepad player, I can traverse, inspect, select, place, and
cancel with visible focus.

**Independent Test**: Complete User Story 1 with keyboard only and gamepad only.

**Acceptance Scenarios**:

1. **Given** a wheel, **When** focus moves, **Then** exactly one wedge has a non-color focus indicator and visible details.
2. **Given** paged items, **When** focus wraps/paginates, **Then** order is deterministic and never traps focus.
3. **Given** any radial level, **When** cancel is pressed, **Then** it backs one level or closes and restores play focus.
4. **Given** the gamepad stick returns to centre, **Then** last deliberate focus remains.

---

### User Story 5 — Extend through data and assets (Priority: P2)

As a content author, I can add/reorder a building and give it an icon without
editing radial layout code.

**Independent Test**: Add fixture entries with valid and missing icon metadata
and verify grouping, order, pagination, and fallback.

**Acceptance Scenarios**:

1. **Given** valid UI metadata, **When** loaded, **Then** the entry appears in its group without radial code changes.
2. **Given** more than eight group entries, **When** opened, **Then** every entry is reachable without overlap.
3. **Given** missing art, **When** rendered, **Then** fallback art appears and a diagnostic is logged.
4. **Given** pool metadata, **When** rendered, **Then** one choice represents all random variants.

## Edge Cases

- No catalog/available entries and a category that becomes empty.
- Pointer at every viewport edge/corner; resize while open.
- Groups with 1, 8, 9, and 20 items.
- Long localized names, four-digit costs, and increased text scale.
- Switching input device while open.
- Dialogue, Inbox, inspect mode, or overbuild confirmation opening mid-flow.
- Current entry becomes unavailable/removed or loses its icon.
- Build-menu and place/cancel inputs arriving in one frame.
- Color disabled and noisy day/night backgrounds.
- Release export accidentally including development plugins.

## Requirements

### Functional Requirements

- **FR-001**: Palette MUST expose a read-only menu projection with stable ID, display name, group, order, icon, pool state, costs, availability, and canonical unavailable reason.
- **FR-002**: UI selection MUST call Palette by stable ID and MUST NOT mutate Palette internals or gameplay resources.
- **FR-003**: Radial navigation MUST use category/item levels with at most eight wedges per page.
- **FR-004**: Pointer, keyboard, and gamepad MUST support traverse, confirm, back, and close.
- **FR-005**: An open radial MUST suppress world actions until closed.
- **FR-006**: A valid item MUST hand off to existing Builder preview/placement.
- **FR-007**: Unavailable items MUST stay visible, explain their gate with non-color cues, and reject confirmation.
- **FR-008**: Pools MUST remain one item and preserve placement-time member selection.
- **FR-009**: Placement MUST repeat the current item; cancel MUST have no side effects.
- **FR-010**: Last valid group/page/focus MUST be remembered transiently.
- **FR-011**: Building/pool data MUST author validated `ui_group`, `ui_order`, and `ui_icon` metadata with fallbacks.
- **FR-012**: Pagination MUST expose all entries deterministically.
- **FR-013**: One top bar MUST replace duplicate resource, demand, and Community counters.
- **FR-014**: One tool dock MUST show inactive, placement, blocked, and demolition contexts.
- **FR-015**: Community/Patrons, Inbox, Dialogue, notifications, and Day/Night MUST remain functional and non-overlapping.
- **FR-016**: QuestDebug MUST NOT activate in release or construct a panel in ordinary debug play.
- **FR-017**: RoadDebug MUST be release-inert and debug-hidden unless explicitly enabled.
- **FR-018**: DevCommands, instruction bitmap, duplicate scene counters, and old Palette list MUST be removed from ordinary play.
- **FR-019**: Development commands MAY remain through non-player interfaces but MUST NOT appear as production UI.
- **FR-020**: Shared UI tokens/states MUST live in a reusable Godot Theme.
- **FR-021**: Icons MUST have accessible labels/tooltips and state meaning MUST work without color.
- **FR-022**: UI MUST remain usable at 1280×720, wider desktops, and supported text scaling.
- **FR-023**: Menu refresh/navigation MUST NOT scan the full catalog per frame or rebuild the whole UI repeatedly.
- **FR-024**: Transient UI state MUST NOT affect save data or deterministic hashes.

### Key Entities

- **BuildMenuModel**: Read-only groups, entries, availability, and current selection.
- **BuildMenuGroup**: Authored group with label, icon, order, and entry IDs.
- **BuildMenuEntry**: Standalone building or pool plus presentation and availability.
- **RadialPage**: At most eight wedges plus a centre action.
- **RadialFocusState**: Transient input/navigation state.
- **UIAssetRecord**: Semantic key, source/runtime paths, sizes, and accessibility.
- **PlayerHUDState**: Projection for the top bar and tool dock.

## Success Criteria

- **SC-001**: A first-time tester reaches placement in at most three confirmations without Q/E.
- **SC-002**: 100% of catalog/pool entries appear exactly once or raise an explicit metadata error.
- **SC-003**: Every unavailable fixture shows the correct reason and rejects selection.
- **SC-004**: Pages with 1, 8, 9, and 20 fixtures never exceed eight non-overlapping wedges.
- **SC-005**: Keyboard-only and gamepad-only tests complete open → category → item → placement → cancel with visible focus.
- **SC-006**: At 1280×720 no HUD/drawer/Inbox/time/notification/radial primary action overlaps another.
- **SC-007**: Normal-play screenshots contain none of the six removed surfaces.
- **SC-008**: Release verification finds no active QuestDebug, RoadDebug, or Playtest UI/service.
- **SC-009**: All radial icons are recognizable at 56 px over parchment and the reference gameplay screenshot.
- **SC-010**: Opening/navigation of a warm menu stays below 2 ms CPU and mutates no gameplay state.
- **SC-011**: Existing placement, affordability, unique, Community UI, deterministic replay, and full scenario tests pass.

## Assumptions and Scope Boundaries

- "with cons" is interpreted as "with icons."
- Desktop Godot 4.6.x remains the target; touch gestures are out of scope.
- Main menu, settings, save browser, remapping, and tutorial campaign are out of scope.
- Existing Community/Patrons detail is retained and themed, not redesigned.
- Demolition gets a dock state but is not part of the creation hierarchy.
- Community icon masters establish the visual language; new build icons form a
  separate `build-menu` family.
