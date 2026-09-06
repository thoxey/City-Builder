# Contract: Presentation Invalidation

## Registration

`register_presenter(presenter_id, domains, is_visible, present) -> Result`

- Presenter IDs are unique.
- Domains are canonical invalidation domains.
- The presenter references the scheduler contract only, never another presenter.
- Registration/unregistration is safe before or after a flush, but cannot mutate the active iteration.

## Dirtying

`invalidate(change_set) -> void`

- Dirty domains are derived from the committed change set.
- Repeated changes coalesce as a set plus latest target version.
- The scheduler stores no unbounded per-presenter change history.
- Invalidations schedule at most one deferred presentation flush.

## Flush

`flush() -> PresentationReport`

- Captures one committed StateVersion at start.
- Each relevant visible presenter runs at most once.
- Presenters read operational projections representing the captured version.
- Hidden presenters perform no projector/presenter work and remain `dirty_hidden`.
- A presenter dirtied during its refresh or another refresh is queued for the next boundary.
- Presenter errors are isolated and reported; they do not roll back gameplay or prevent unrelated presenters from being attempted.

## Visibility Catch-up

When a dirty hidden presenter becomes visible, the scheduler queues it once for the latest target/current version. It does not replay intermediate change sets.

## Required Evidence

PresentationReport contains flush version, queued/presented/skipped/failed presenter IDs, coalesced domains, elapsed time per presenter/projection, and next-flush count. It is diagnostic and excluded from saves and hashes.
