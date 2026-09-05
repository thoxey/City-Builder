# Requirements Checklist: Save Continuity and Desktop Release

**Purpose**: Verify that persistence, lifecycle UI, recovery, and release acceptance are specified before planning.
**Created**: 2026-09-05
**Feature**: [spec.md](../spec.md)

## Specification quality

- [x] CHK001 Save continuity is defined as equivalent future simulation, not only visible reconstruction.
- [x] CHK002 Persisted authoritative, reconstructable derived, and transient state are explicitly separated.
- [x] CHK003 Validation and reconciliation order prevents partial live-town mutation.
- [x] CHK004 Manual slots, autosave, Continue, overwrite, atomic replacement, and recovery behavior are defined.
- [x] CHK005 Title, pause, settings, destructive navigation, and quit flows have testable outcomes.
- [x] CHK006 Legacy, corrupt, unsupported, interrupted, and missing-content cases are covered.
- [x] CHK007 A real exported-build smoke flow and development-service exclusion are required.
- [x] CHK008 Success criteria cover parity, deterministic continuation, fault safety, performance, accessibility, and release.

## Constitution and design readiness

- [x] CHK009 Save/load uses canonical state and one documented reconciliation boundary.
- [x] CHK010 Post-load deterministic replay compares identical actions and exact hours.
- [x] CHK011 UI and automation consume structured save/load outcomes rather than parsing logs.
- [x] CHK012 Release builds keep playtest and development capabilities absent or inert.
- [x] CHK013 Unit, integration, determinism, fault-injection, UI, and release test seams are identified.
- [x] CHK014 Dependencies on milestones 005 and 006 are explicit and do not pull balance changes into this scope.

## Planning validations

- [ ] CHK015 Inventory every current DataMap field and every authoritative runtime field missing from it.
- [ ] CHK016 Choose the save envelope and atomic replacement mechanism supported by Godot 4.6 on macOS.
- [ ] CHK017 Define the exact reconciliation dependency order and load-complete signal contract.
- [ ] CHK018 Build representative current/legacy/corrupt/interrupted fixture inventory.
- [ ] CHK019 Confirm autosave coalescing and unsaved-change policy through UX review.
- [ ] CHK020 Confirm primary macOS export contents and development-only exclusion strategy.
