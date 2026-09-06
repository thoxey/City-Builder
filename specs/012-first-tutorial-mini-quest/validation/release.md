# Release Verification

Workstream 1 is implemented and verified for the user-approved placeholder-copy
scope.

- Spec, plan, task list, contracts, and quickstart are complete.
- Runtime state is monotonic, persisted, observable through Playtest, and based
  on canonical game authorities.
- All 18 beats use the approved literal `AMBROSE PLACEHOLDER:` convention; the
  four full beats export through EventSystem and dialogue validation.
- The standalone opening scenario passes with deterministic hash parity, nine
  receipts, one handoff, truthful score deltas, early action recovery, duplicate
  idempotence, demolition non-regression, and cold-load parity.
- Visual proofs pass at 1280×720, 1920×1080, and 3840×2160.
- Final regression: **543/543 tests passed, 3,638 assertions**.
- `git diff --check` passes.

Remaining risk is editorial rather than mechanical: the labels are intentionally
placeholder copy. They are accepted for this implementation pass but should be
replaced and re-reviewed if characterful final dialogue is later commissioned.
