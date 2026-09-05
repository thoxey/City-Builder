# Requirements Checklist: Radial Build UI and Player HUD

**Purpose**: Verify that specification and design are ready for implementation.
**Created**: 2026-09-04
**Feature**: [spec.md](../spec.md)

## Specification quality

- [x] CHK001 User value and scope are stated without prescribing gameplay rule changes.
- [x] CHK002 Player-facing surfaces to retain, replace, and remove are explicitly inventoried.
- [x] CHK003 Radial hierarchy, wedge limit, paging, placement handoff, and cancellation are defined.
- [x] CHK004 Pointer, keyboard, and gamepad behavior have testable outcomes.
- [x] CHK005 Locked/blocked states are visible, explainable, and canonical.
- [x] CHK006 Edge cases cover empty data, paging boundaries, resize, modal priority, and live availability changes.
- [x] CHK007 Success criteria are measurable and include release/debug separation.

## Design readiness

- [x] CHK008 Palette and Builder ownership boundaries preserve One Gameplay Truth.
- [x] CHK009 Catalog metadata avoids category inference and supports content-author extensibility.
- [x] CHK010 UI asset family, source/runtime paths, display sizes, manifest, and proof requirements are defined.
- [x] CHK011 Theme and radial geometry responsibilities distinguish engine-native UI from raster art.
- [x] CHK012 Test seams cover projection, input ownership, UI, assets, performance, release export, and scenario regressions.

## Remaining implementation validations

- [ ] CHK013 Prototype seven/eight-wedge Custom Control geometry in Godot 4.6.
- [ ] CHK014 Confirm controller bindings/glyph policy on target controllers.
- [ ] CHK015 Validate compact top-bar breakpoint after legacy surface removal.

