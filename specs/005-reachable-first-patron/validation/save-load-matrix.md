# Progression Save/Load Matrix

Date: 2026-09-05  
Boundary: real `ResourceSaver` followed by
`ResourceLoader.CACHE_MODE_IGNORE` and Builder's normal `map_loaded`
reconciliation signal.

| Boundary fixture | Character state | Pending dialogue | Story structures | Patron/receipt | Result |
|---|---|---|---|---|---|
| Before arrival | `NOT_ARRIVED`/missing defaults | none | none | `LOCKED`, no receipt | pass |
| After arrival | `ARRIVED` | arrival ID retained; event count 1 | tier-one prerequisite retained | `LOCKED`, no receipt | pass |
| After reveal | `WANT_REVEALED` | acknowledged; event count remains 1 | prerequisite retained | `LOCKED`, no receipt | pass |
| After satisfaction | `SATISFIED` | none | prerequisite and request retained | `LOCKED`, no receipt | pass |
| Patron available | all three `SATISFIED` | none | all three requests retained | `LANDMARK_AVAILABLE`, no receipt | pass |
| Completion/donation | all three `CONTRIBUTES_TO_LANDMARK` | completion ID retained; event count 1 | requests and Theatre retained | `COMPLETED`, receipt retained | pass |

Every fixture also preserved accrued demand totals and allowed cells. The final
fixture retained a donated cell outside the starter plot.

Additional reconciliation checks:

- An `ARRIVED` legacy character with its request already placed advances through
  reveal to `SATISFIED` exactly once.
- A revealed character whose request is absent after load remains revealed.
- Pending dialogue redispatch does not increment its event count.
- Reapplying a patron donation with an existing receipt adds zero cells.
- A completed legacy patron missing its receipt repairs the donation without a
  duplicate completion event.

Result: SC-005, SC-006, and SC-007 pass across the boundary matrix and focused
reconciliation tests.
