# Requirements Checklist: Connected First-Town Loop

**Purpose**: Verify that connectivity, operation, balance, Community consequences, and feedback are specified before planning.
**Created**: 2026-09-05
**Feature**: [spec.md](../spec.md)

## Specification quality

- [x] CHK001 The intended connected gameplay loop and player value are explicit.
- [x] CHK002 Road access, route reachability, operation, and contribution are distinct concepts.
- [x] CHK003 Disconnected placement behavior and simulation timing are unambiguous.
- [x] CHK004 Employment, commerce, output, income, demand, and Community integration have testable outcomes.
- [x] CHK005 Early balance outcomes are measurable without mandating a new economy subsystem.
- [x] CHK006 Player explanations distinguish every major idle-building reason.
- [x] CHK007 Edge cases cover footprints, components, schedules, allocation, demolition, rehoming, and visual/simulation separation.

## Constitution and design readiness

- [x] CHK008 One canonical connectivity decision surface serves gameplay, UI, visuals, and playtests.
- [x] CHK009 Allocation and hourly outcomes are deterministic and independent of render frames.
- [x] CHK010 Community effect arithmetic remains owned by Community and authored data.
- [x] CHK011 Balance changes require same-seed before/after traces and retain milestone-005 reachability.
- [x] CHK012 Story-independent scenarios remain runnable with narrative presentation disabled.
- [x] CHK013 Unit, integration, scenario, balance, performance, and visual test seams are identified.

## Planning validations

- [x] CHK014 Prototype the minimum canonical connectivity projection using the existing road graph.
- [x] CHK015 Define deterministic resident-to-destination allocation priority with representative ties.
- [ ] CHK016 Freeze the current roadless and connected early-city traces before tuning.
- [x] CHK017 Inventory missing Community effects across every starter T1/T2 choice.
- [x] CHK018 Confirm whether the legacy Satisfaction metric is removed or replaced with a genuinely distinct measure.
- [ ] CHK019 Validate the proposed early cash ceiling and tier-two window through human playtest review.

## Spatial-incentive validation

- [x] CHK020 “Spread out” is defined through resident exposure, local-effect coverage, connectivity, road use, route distance, and land use rather than a hidden density score.
- [x] CHK021 Compact and spread acceptance scenarios hold non-road buildings, capacity, seed, resources, and elapsed time constant.
- [x] CHK022 The desired spatial benefit and its network/land trade-off are both measurable.
- [ ] CHK023 Freeze matched compact and spread baseline traces before changing spatial effects or costs.
- [x] CHK024 Inventory every starter nuisance and local benefit radius, stacking group, affected resident set, and player-facing reason.
- [ ] CHK025 Confirm through human playtest that the spread incentive is noticeable without making compact layouts non-viable.

## Community-shaped layout validation

- [x] CHK026 Automated rules measure resident experience and felt spatial trade-offs without introducing a hidden beauty score, green quota, asset-diversity bonus, or prescribed silhouette.
- [x] CHK027 Resident-serving nature, nature-integrated neighbourhoods, cosmetic-only content, and community-driven player edits have explicit definitions.
- [x] CHK028 Isolated-object progression, unlimited duplicate stacking, nuisance cancellation, blank sprawl, and repeated-item spam have explicit rejection rules.
- [x] CHK029 The automated matrix isolates placement, service, connectivity, nature mix, cohort preference, and trade-off hypotheses through admissible matched pairs.
- [x] CHK030 The Blind Neighbourhood Test combines unprompted player behaviour, canonical simulation evidence, and anonymised fixed-view visual review.
- [x] CHK031 Freeze the migration path from raw city-wide Attractiveness to resident-served residential demand before tuning; prove unserved nature cannot advance demand or progression.
- [x] CHK032 Inventory every nature item as functional or cosmetic-only and reconcile its Community effects, stacking group, cash/land cost, palette messaging, and progression contribution.
- [x] CHK033 Extend snapshots and comparisons with exposure, distinct coverage, stacking ordinal, roads, routes, assignments, spend, land, and pair-manifest validation before recording baselines.
- [x] CHK034 Freeze every matched and adversarial scenario in [layout-validation-strategy.md](../layout-validation-strategy.md), including one holdout seed and any exploit found by bounded layout search.
- [ ] CHK035 Pilot the neutral human brief and visual rubric with three non-acceptance players, then freeze the build, seeds, thresholds, camera, and moderator rules.
- [ ] CHK036 Complete the 12-player acceptance cohort, independent visual review, and four-player durability continuation with preserved evidence.
- [x] CHK037 Reject planning or implementation tasks that omit any applicable `FR-033`–`FR-041`, `SC-017`–`SC-025`, or required evidence class.
- [x] CHK038 Freeze which existing scarcity makes spread materially costly—or approve a minimal one-time road cost—so inert distance and free road count cannot satisfy the trade-off gate.
