# Architecture and Performance Requirements Checklist: Transactional Performance Architecture

**Purpose**: Review whether the written requirements and design fully specify the IoC, transaction, presentation, scaling, rollout, and performance constraints before implementation.
**Created**: 2026-09-06
**Feature**: [spec.md](../spec.md)

## Requirement Completeness

- [x] CHK001 Are ownership and registration requirements defined for contributors, reducers, projections, and presenters? [Completeness, Spec §FR-002, Plan §Project Structure]
- [x] CHK002 Are successful, empty, rejected, stale, conflicting, duplicate, re-entrant, load, and clear transaction cases documented? [Coverage, Spec §Edge Cases, Contract §Simulation Transaction]
- [x] CHK003 Are all authoritative mutation sources that must publish change sets enumerated? [Completeness, Spec §FR-020, Contract §Authoritative Change Set]
- [x] CHK004 Are operational projection and explicit diagnostic responsibilities separately documented? [Completeness, Spec §FR-018–FR-019]
- [x] CHK005 Are hidden, visible, re-dirtied, failed, registered, and unregistered presenter states covered? [Coverage, Contract §Presentation Invalidation]
- [x] CHK006 Are migration, people, traffic, placement, UI, hourly, and rendered workloads all represented in requirements and tasks? [Coverage, Spec §US3–US5, Tasks §Traceability]

## Requirement Clarity

- [x] CHK007 Is “one hourly transaction” defined with precise collection, validation, commit, notification, and clock semantics? [Clarity, Spec §FR-001–FR-010]
- [x] CHK008 Is contributor independence distinguished from per-building runtime object creation? [Clarity, Spec §Assumptions, Research §Decision 2]
- [x] CHK009 Is deterministic ordering fully defined without incidental registration or container order? [Clarity, Spec §FR-009, Contract §Deterministic Order]
- [x] CHK010 Is atomic failure defined as no state/version/hash change rather than rollback after partial mutation? [Clarity, Spec §FR-006, Research §Decision 5]
- [x] CHK011 Is “dirty” defined as coalesced domains plus latest version rather than queued historical events? [Clarity, Data Model §PresenterRegistration]
- [x] CHK012 Are cache invalidation inputs explicitly named for migration and projections? [Clarity, Spec §Edge Cases, Data Model §MigrationBatchContext]
- [x] CHK013 Is traffic fairness expressed through stable FIFO partitions and deterministic origin traversal? [Clarity, Research §Decision 12]

## Requirement Consistency

- [x] CHK014 Do the transaction coordinator and GameState roles remain consistent with the one-gameplay-truth principle? [Consistency, Plan §Constitution Check]
- [x] CHK015 Do immutable pre-hour reads align with same-hour supply/demand/economy semantics through reducers? [Consistency, Research §Decision 3]
- [x] CHK016 Do presenter independence and simultaneous presentation requirements agree across spec, plan, contract, and tasks? [Consistency, Spec §US2, Contract §Presentation Invalidation]
- [x] CHK017 Do compatibility adapters publish only post-commit results in every artifact? [Consistency, Spec §FR-030, Plan §Phase B, Tasks T029]
- [x] CHK018 Are diagnostics consistently excluded from saves, hashes, and gameplay decisions? [Consistency, Spec §FR-019/FR-028, Contracts]
- [x] CHK019 Do all documented performance thresholds match between spec and evidence contract? [Consistency, Spec §SC-004–SC-009, Contract §Initial Gates]

## Acceptance Criteria Quality

- [x] CHK020 Can atomicity be measured with state version, state hash, ledger disposition, and failure code? [Measurability, Spec §SC-001–SC-002]
- [x] CHK021 Can UI coalescing be measured by presenter/projection invocation counts per flush? [Measurability, Spec §SC-003]
- [x] CHK022 Do timing criteria specify workload, statistic, threshold, exclusions, and reference environment? [Measurability, Spec §SC-004–SC-009]
- [x] CHK023 Is the 95% frame-time attribution criterion objectively calculable from nested samples? [Measurability, Spec §SC-011, Contract §Aggregate Report]
- [x] CHK024 Are completion gates defined for contracts, focused suites, replay, full suite, scenarios, and adapter removal? [Completeness, Spec §SC-010, Quickstart §1–§7]

## Dependencies and Rollout

- [x] CHK025 Is the story dependency order documented while preserving independent domain work? [Dependency, Plan §Dependency and Rollout Order]
- [x] CHK026 Is the P1 architectural MVP explicitly identified and independently testable? [Scope, Spec §US1, Tasks §Implementation Strategy]
- [x] CHK027 Are compatibility adapters retained until named parity evidence passes and consumers reach zero? [Recovery, Spec §FR-030, Quickstart §7]
- [x] CHK028 Are task-to-requirement mappings present for every FR and buildable SC? [Traceability, Tasks §Requirement Traceability]

## Boundaries and Assumptions

- [x] CHK029 Are async/background mutation, ECS replacement, balance changes, visual redesign, and engine upgrades explicitly excluded? [Scope, Spec §Assumptions]
- [x] CHK030 Is the bounded, non-save retention policy for detailed ledgers documented without implying permanent player history? [Assumption, Research §Decision 6]
- [x] CHK031 Is rendering optimization constrained to attributed evidence and current visual contracts? [Scope, Research §Decision 13]
- [x] CHK032 Are baseline reproduction caveats and missing raw metadata explicitly identified before implementation? [Dependency, Baseline §Reproduction caveat]
- [x] CHK033 Are shared-city authority, Community resident authority, and DataMap persistence responsibilities distinguished without creating two mutable models? [Consistency, Spec §FR-031, Community Runtime Contract §Ownership]
- [x] CHK034 Are compiled runtime indexes explicitly rebuildable, revision-keyed, non-saveable, non-hashed, and unavailable to presenters? [Boundary, Spec §FR-032, Community Runtime Contract §Compilation Boundary]
- [x] CHK035 Are operational evaluation, explanation diagnostics, and UI view models independently testable with parity and mutation-isolation gates? [Coverage, Spec §FR-033–FR-035/SC-012, Community Runtime Contract §Required Gates]

## Notes

- All 35 requirement-quality checks pass in the pre-implementation review.
- This checklist evaluates the planning artifacts; runtime behavior is validated later by `tasks.md` and `quickstart.md`.
