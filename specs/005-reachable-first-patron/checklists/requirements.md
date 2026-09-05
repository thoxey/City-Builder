# Requirements Checklist: Reachable First-Patron Progression

**Purpose**: Verify that the progression specification is complete and ready for technical planning.
**Created**: 2026-09-05
**Feature**: [spec.md](../spec.md)

## Specification quality

- [x] CHK001 The complete first-patron outcome and player value are explicit.
- [x] CHK002 Progression correctness is separated from connectivity, final balance, narrative content, and lifecycle work.
- [x] CHK003 Character, request, patron, landmark, and land-expansion ordering are defined.
- [x] CHK004 Authored demand and tier requirements have an unambiguous runtime meaning.
- [x] CHK005 New-game gating and legacy-save reconciliation are both specified without weakening one another.
- [x] CHK006 Edge cases cover simultaneous signals, demolition, load boundaries, content changes, and duplicate effects.
- [x] CHK007 Success criteria are deterministic, measurable, and observable through existing interfaces.

## Constitution and design readiness

- [x] CHK008 All actions pass through existing canonical placement, demand, unique, event, and land rules.
- [x] CHK009 The canonical scenario does not depend on finished narrative presentation.
- [x] CHK010 Stable rejection reasons and trace milestones satisfy observable/explainable-state requirements.
- [x] CHK011 Provisional data corrections require an unchanged before trace.
- [x] CHK012 Unit, integration, scenario, regression, and visual test seams are identified before planning.

## Planning validations

- [x] CHK013 Measure the current shortest legal route and identify the exact first unreachable transition.
- [x] CHK014 Decide provisional character thresholds using the frozen pre-change trace.
- [x] CHK015 Inventory legacy save fixtures needed for request-before-arrival reconciliation.
- [x] CHK016 Confirm player-facing copy for the three new progression lock reasons.

**Planning evidence**: `research.md` proves the 10,000 industrial threshold is
unreachable and selects the provisional value 100; `data-model.md` and the
scenario contract define the boundary fixtures; `progression-projection.md`
defines stable reason priority and authored-name presentation.
