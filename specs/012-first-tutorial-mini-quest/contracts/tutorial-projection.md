# Contract: Opening Tutorial Projection

## Projection shape

`OpeningTutorial.get_projection()` returns a detached JSON-safe record:

```text
TutorialProjection {
  schema_version: 1
  revision: int
  tutorial_id: "opening_tutorial"
  step_id: OpeningStepId
  status: "active" | "waiting" | "blocked" | "complete"
  projection_key: String
  beat_id: "B01".."B18" | ""
  speaker_id: "ambrose"
  expression: String
  copy_key: String
  copy_args: Dictionary
  progress: { current, required, unit }
  blocker: { code, evidence } | null
  target: { kind, id, label } | null
  full_dialogue_event_id: String
}
```

The projection contains semantic keys/arguments, not final display prose and not live
Resource/Node references. During the placeholder implementation, every `copy_key`
resolves to the approved literal labelled form
`AMBROSE PLACEHOLDER: <beat purpose>`.

## Stable variants

One step may select different approved beat variants from canonical facts:

- nature progress versus Beauty-not-positive blocker;
- home demand wait versus affordable placement;
- observed adjacency penalty versus no-penalty/content diagnostic;
- workplace placement versus access/radius blocker versus participation wait;
- shop placement versus rooted-access blocker; and
- terminal completion.

`projection_key` is `tutorial_id|step_id|beat_id|variant`. Numeric progress is excluded,
so dismissing a compact direction keeps it dismissed while only its counter changes.
Changing semantic step or blocker variant creates a new direction that may appear.

## Progress and blockers

Progress values come from canonical evidence and never estimate future simulation:

- roads: rooted road cell count / 4;
- nature: distinct stable IDs / 2 plus city Beauty in `copy_args`;
- affordability: Demand quote `have` / `cost`;
- workplaces/shops: exact rooted route and offending-radius evidence;
- participation: identified work assignment count / 1.

Blocker evidence uses stable IDs, coordinates, radii, route reasons, and measured scores.
It must not contain a tile-specific placement preview or recommend a location as legal.

## Dashboard handoff

While the opening tutorial is incomplete, Dashboard gives its projection priority over
patron `next_step` and the old Town Hall override. Dashboard resolves:

- Ambrose display name/expression texture through CharacterSystem;
- `copy_key` plus `copy_args` through approved tutorial content;
- target labels through BuildingCatalog; and
- the final dictionary shape consumed by `CompactGuidanceView`.

When the tutorial projection is complete/empty, existing patron guidance resumes.
CompactGuidanceView retains its current dismissal, pointer consumption, responsive
layout, and suppression for `modal`, `radial`, and `inspection` input modes.

## Full exchange dispatch

Beats B05, B09, B15, and B18 use EventSystem dialogue records with stable event IDs.
The projection may name an event ID for observability, but OpeningTutorial fires it only
when the corresponding durable presentation receipt is absent. EventSystem remains
responsible for pending recovery, dialogue validation, traversal, effects, and
acknowledgement.

Dispatching a full exchange does not grant gameplay completion. Conversely, headless
tutorial reconciliation does not load portraits or require a modal to exist. Headless
acceptance resolves pending dialogue through the existing Dialogue command when testing
narrative parity.

## Presentation receipt meaning

- Compact beat: receipt means its approved projection was first published.
- Full exchange: receipt means EventSystem accepted/fired the stable authored event.
- Receipt does not mean a compact bubble is currently visible or a pending dialogue has
  been acknowledged.
- Duplicate refreshes or reloads never dispatch a receipted beat again.

## Safety rules

- Copy for an unapproved key is empty and produces `tutorial_copy_unapproved`; draft
  alternatives are never selected.
- A measured no-penalty result selects diagnostic/neutral copy and never penalty prose.
- A missing historical baseline selects `baseline_unavailable` copy and never invents a
  before score.
- Work/shop trade-off arguments list actual authored effects; they do not promise an
  effect absent from current content.
