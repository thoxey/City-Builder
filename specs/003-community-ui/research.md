# Research: Community Insight UI

## Existing UI constraints

- HUD owns a top-centre 630 px panel.
- Palette owns the bottom-left.
- DayNight owns the bottom-right.
- Inbox and Dashboard occupy the top/right edge.
- Dashboard already shows a multiline Community text summary but its primary
  responsibility is Patron progression.
- Most game UI is constructed in plugin GDScript at runtime rather than authored
  as standalone scenes.
- Community already emits population and quality signals and exposes bounded
  snapshots, resident records, effect summaries, activities, migration counters,
  and personality distribution.

## Decisions

### Use the existing right sidebar as a tabbed shell

**Decision**: Add Community and Patrons tabs to Dashboard’s existing panel.

**Why**: A second right-side CanvasLayer would overlap Dashboard and Inbox. The
tab shell preserves a single collapse control and gives detailed Community
content enough vertical space.

**Rejected**: A permanent second panel, because 1280×720 cannot accommodate it;
a modal, because frequent diagnosis should not stop play; HUD-only disclosure,
because resident/effect detail is too dense.

### Use a read-only presentation projection

**Decision**: Expand `CommunityInspector` into a pure projector that joins
canonical Community state with catalog names, schedules, and configured
thresholds.

**Why**: Current snapshots contain most numeric truth but not every display
label or time-context field. A pure projection prevents UI Controls from
duplicating formulas and provides a stable test seam.

**Rejected**: Letting each widget derive its own values, because sorting,
fallbacks, and risk thresholds would drift; storing display aggregates in the
save, because they are derived state.

### Treat neighbourhoods as home-anchor aggregations

**Decision**: Aggregate residents at canonical residential anchors and relate
them to authored effect radii.

**Why**: This makes composition spatially legible without introducing districts,
zoning, factions, or new simulation state.

### Show current/target, not a fabricated long-term history

**Decision**: Quality detail compares canonical current and target values. The
overview may show direction since the prior authoritative update only.

**Why**: The simulation does not persist history. A sparkline would imply data
that does not exist and add unbounded storage.

### Use paging/row reuse for resident scale

**Decision**: Create only visible/paged resident rows and update them in place.

**Why**: Community supports 500 resident records. Rebuilding hundreds of Control
nodes on each exact-hour tick is unnecessary and threatens the frame budget.

### Keep programme changes canonical

**Decision**: UI invokes `Community.set_programme` and waits for
`community_programme_changed` before committing visual state.

**Why**: This preserves one gameplay truth and makes error/rejection behavior
testable. Previews describe authored effect themes, not predicted personal
scores.

### Use text and shape with color

**Decision**: Every quality, sign, trend, warning, and lens has a label/icon or
symbol in addition to color.

**Why**: Color-only bars are inaccessible and ambiguous when positive and
negative effects coexist on one quality.

## Required narrow simulation exposure

The UI needs a read-only presentation snapshot containing configured departure
and relocation thresholds/grace values, schedule metadata for displayed source
effects, current programme options, participant/affected resident IDs, and
building display names. These fields are projections of existing state/content;
they do not add balance behavior.

## Open implementation checks

- Confirm the cleanest canonical map-selection hook in Builder without stealing
  placement/demolition clicks.
- Verify whether existing global Theme resources are sufficient or whether a
  small Community-specific theme/stylebox set is needed.
- Measure whether paging alone is sufficient at 500 residents before building a
  custom virtualized list.

