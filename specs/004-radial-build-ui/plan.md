# Implementation Plan: Radial Build UI and Player HUD

**Branch**: `004-radial-build-ui` *(planning identifier; no branch created)* | **Date**: 2026-09-04 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/004-radial-build-ui/spec.md`

## Summary

Replace the prototype Palette list and debug overlays with an icon-led,
two-level radial build flow and a coherent HUD shell. A new PlayerUI plugin owns
the top status bar, bottom tool dock, radial overlay, safe areas, and shared
Theme. Palette projects all build entries with canonical availability and
accepts stable-ID selection; Builder adopts explicit input modes but retains all
placement/demolition authority. Catalog/pool JSON authors UI grouping, order,
and icon keys. QuestDebug, RoadDebug, and Playtest are gated away from release,
and ordinary play no longer displays developer panels.

## Technical Context

**Language/Version**: GDScript, Godot 4.6.x; JSON content metadata

**Primary Dependencies**: Plugin/event architecture, Palette, BuildingCatalog,
Builder, Economy, Demand, UniqueRegistry, HUD, Dashboard/Community, Inbox,
Dialogue, DayNight, GUT 9.3.0

**Storage**: Existing JSON building/pool definitions plus a UI asset manifest;
no new save-game fields

**Testing**: Pure GUT projection/paging tests, input-mode units, Godot UI scene
tests, plugin integration tests, asset validation/proofs, screenshots, release
activation inspection, deterministic replay, and a full build scenario

**Target Platform**: Godot 4.6.x desktop, minimum supported layout 1280×720

**Project Type**: Plugin-based Godot desktop game

**Performance Goals**: 60 fps; warm radial open/focus under 2 ms; no per-frame
catalog scan or full UI rebuild; one rendered-frame response to availability

**Constraints**: One gameplay truth; no UI-side affordability formulas; at most
eight wedges; pointer/keyboard/gamepad parity; visible focus and non-color state;
no normal-play debug overlays; no deterministic/save impact

**Scale/Scope**: Seven build groups, current catalog plus fixtures up to 20
entries/group, two radial levels, unified top bar/dock, retained insight drawer

## Constitution Check

*GATE: Passed before design and re-checked after Phase 1.*

| Principle | Plan evidence | Gate |
|---|---|---|
| One Gameplay Truth | Palette projects canonical decisions and revalidates selection; Builder remains the only placement path. | PASS |
| Deterministic Simulation | UI focus/page/open state is transient; stable order uses authored order plus ID; replay hashes are unchanged. | PASS |
| Observable State | Every unavailable wedge exposes a canonical reason; placement dock exposes current tool state. | PASS |
| Data-Driven / Narrative-Separate | Group/order/icon keys are authored in catalog/pool data with fallbacks; story groups do not create narrative dependencies. | PASS |
| Small Interfaces / Layered Verification | One read-only menu projection, one stable-ID selection command, and explicit input-mode boundary form the test seams. | PASS |
| Project Constraints | Godot 4.6.x and plugin/event architecture remain; test tooling is release-inert. | PASS |

Post-design check: centralizing presentation in PlayerUI changes UI ownership but
does not introduce a gameplay write path or architectural exception.

## Project Structure

### Documentation

```text
specs/004-radial-build-ui/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/build-menu-contract.md
├── checklists/requirements.md
└── validation/
```

### Planned source and asset changes

```text
plugins/player_ui/
├── player_ui_plugin.gd
├── radial_build_menu.gd
├── radial_wedge.gd
├── status_bar.gd
└── tool_dock.gd

themes/
└── player_ui_theme.tres

art/ui/build-menu/
├── masters/
├── proofs/
└── manifest.json

sprites/ui/build-menu/
├── categories/
├── entries/
└── controls/

data/buildings/**/*.json
plugins/palette/palette_plugin.gd
plugins/palette/palette_entry.gd
plugins/building_catalog/building_catalog_plugin.gd
plugins/hud/hud_plugin.gd
plugins/day_night/day_night_plugin.gd
plugins/dashboard/dashboard_plugin.gd
plugins/inbox/inbox_plugin.gd
plugins/quest_debug/quest_debug_plugin.gd
plugins/road_debug/road_debug_plugin.gd
scripts/builder.gd
scripts/plugin_manager.gd
scripts/game_events.gd
scenes/main.tscn
project.godot

test/unit/player_ui/
test/unit/palette/
test/unit/plugin_manager/
test/integration/player_ui/
specs/004-radial-build-ui/validation/
```

**Structure Decision**: PlayerUI owns composition and interaction presentation;
domain plugins expose data/actions. Runtime-created controls remain consistent
with the project, while reusable scripts and a Theme replace scattered local
styling. Raster sources and runtime derivatives remain separate with a manifest.

## Phase 0: Research Outcome

Research in [research.md](research.md) resolves hierarchy, unavailable states,
metadata ownership, geometry/art division, debug gating, and transient state.
Only prototype validations remain: wedge drawing/hit testing, controller prompt
policy, and the responsive top-bar breakpoint.

## Phase 1: Design

### 1. Catalog and Palette projection

Extend catalog summaries and PaletteEntry with player-facing UI metadata.
BuildingCatalog validates group IDs, integer order, and icon keys. Pool sidecars
own metadata for pooled choices. Palette builds a detached `BuildMenuModel` on
entry or availability changes and emits only when its revision changes.

Availability must be obtained through narrow canonical decision methods. Where
current systems return only booleans, add reason-bearing read-only decisions to
those systems or a Palette adapter that delegates to them; do not copy numeric
rules into PlayerUI. `request_select_entry` revalidates before selection.

### 2. Input-state boundary

Replace Builder's independent `_process` action polling assumptions with an
explicit mutually exclusive mode/controller. Priority is:

```text
dialogue/confirmation > radial > community inspection > demolition > placement > world
```

PlayerUI requests radial mode and emits a selected stable ID. Builder receives
only accepted Palette selection. The confirming event is consumed so it cannot
also place. Existing placement, rotate, road paint, overbuild, and demolition
methods remain the authoritative commands.

### 3. Radial control

Prototype a Custom Control that draws equal-angle wedges and performs polar hit
testing. Clamp the origin using outer radius plus label/focus padding. Construct
deterministic category and paged item views from the model. Reuse nodes/textures,
update only changed states, and retain focus when possible.

Keep centre Back/Close a separate focusable action. Drive pointer angle,
clockwise keyboard traversal, and stick angle through one focus function.
Page-navigation wedges are ordinary actions and count toward the eight limit.

### 4. Player shell migration

Create the top bar and dock under PlayerUI. Move HUD presentation bindings into
the bar or expose an HUD projection, then remove the old HUD CanvasLayer.
Integrate Town Insights and Inbox entry points without duplicating their detail
panels. Apply the shared Theme to Dashboard/Community, Inbox, and DayNight.

Remove `Main/CanvasLayer/Top`, `Bottom/Instructions`, and `DevCommands`; retain
Toast until notifications fully own transient feedback. Remove Palette's list UI
while preserving its model. Test safe areas at minimum and wide layouts.

### 5. Development UI separation

Add a plugin activation classification (`runtime`, `debug_opt_in`,
`debug_headless`) or equivalent explicit policy. QuestDebug must not build UI;
its useful mutations migrate to the existing playtest/test surface if not
already represented. RoadDebug is `debug_opt_in=false` by default. Playtest is
debug/headless only. Release tests assert all three are absent/inert.

### 6. Asset production and theme

Before the full batch, create a labelled exploration sheet for the new
`build-menu` family with materially different silhouettes, then approve one
direction. Produce category icons, one icon per standalone/pool entry, and
Back/Close/Next/Previous/Lock/Missing/Build/Demolish controls. Preserve masters,
format deterministic PNG derivatives, create manifest records, and validate
actual-size proofs on calm and noisy backgrounds.

The Theme defines typography, parchment/ink surfaces, spacing, radii, focus,
disabled hatch/outline, destructive state, and compact/wide metrics. It must
not rely on icon recoloring for meaning.

## Test Seams and Verification

| Seam | Verification |
|---|---|
| Catalog metadata | Fixtures for valid, invalid, missing, pooled, and duplicate order values. |
| Palette projection | Exact-once entries, canonical reasons, detached data, stable revision/order. |
| Pagination | 1/8/9/20 items; maximum eight actions and full reachability. |
| Radial geometry | Polar boundaries, dead zone, edge clamping, resize, long labels. |
| Input modes | One owner/event, confirm-not-place, modal priority, focus restoration. |
| Placement handoff | Pool behavior, repeat placement, live block, cancel without spend. |
| Shell | 1280×720 and wide screenshots; no overlap or removed surfaces. |
| Accessibility | Pointer/keyboard/gamepad parity, visible focus, grayscale/non-color review. |
| Assets | Manifest/dimensions/alpha/path validation and actual-size proof review. |
| Release | Plugin activation test plus exported runtime inspection. |
| Regression | Recursive GUT, deterministic replay, Community UI, full build scenario. |

## Delivery Sequence

1. Foundation: metadata schema, canonical availability decision, projection,
   selection command, and input-mode tests.
2. MVP: category/item radial with temporary approved fallback icons, Build dock,
   pointer/keyboard input, and placement handoff.
3. Player shell: unified top bar, removed prototype panels, layout integration.
4. Complete input: gamepad, pagination, resizing, modal and live-update behavior.
5. Art/theme: approved icon family, runtime derivatives, manifest, proofs, and
   shared component styling.
6. Hardening: debug/release gating, accessibility, performance, scenario and
   export verification.

Each milestone can be reviewed independently. Implementation must not begin the
full icon batch until radial geometry and minimum display size are validated.

## Complexity Tracking

No constitution violations require justification.

