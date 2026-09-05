# Community-Shaped Layout Validation Strategy

**Feature**: [Connected First-Town Loop](spec.md)

**Purpose**: Prove that ordinary play encourages intentional neighbourhoods
mixing homes, reachable shared places, productive buildings, and functional
nature without using a hidden beauty score or making one layout template
dominant.

## 1. Decision rule

No single score can approve this outcome. Acceptance requires all three evidence
classes:

1. **Simulation evidence**: named resident effects, exposure, coverage,
   participation, migration, economy, and progression move in the intended
   direction under controlled layouts.
2. **Behaviour evidence**: unprompted players use those rules to make spatial
   decisions and can explain the relevant resident or place consequence.
3. **Visual evidence**: independent reviewers see integrated nature,
   intentional composition, variety, and readable neighbourhood structure in
   fixed-view screenshots.

A layout that looks attractive but serves nobody, scores well through repeated
object spam, or succeeds only after the moderator explains the intended design
fails. A mechanically healthy town that most players regard as incoherent also
fails. Visual review remains evidence and never becomes an in-game score.

## 2. Gameplay guardrails

- Beauty is a resident quality, not a universal layout judgement.
- Blank distance earns nothing. Benefits come from named local effects,
  nuisance avoidance, or reachable participation.
- Progression-relevant nature must serve an occupied or candidate home or a
  reachable participant. Unserved decoration is permitted but balance-neutral.
- Positive duplicate stacking has a finite tail: `100%`, `50%`, `25%`, then
  `0%` for further same-group sources affecting the same resident.
- Different authored functions may combine; different asset IDs receive no
  abstract variety bonus.
- Greenery does not erase pollution or noise. Positive and negative effects are
  retained and explained independently.
- A spatial trade-off must alter a scarce choice. Cash, occupied starter land,
  a forgone useful placement, fulfilled capacity, or milestone timing qualify;
  inert route length does not.
- Compact and distributed towns must both remain viable and win on different
  declared dimensions.
- Different Community outlooks must be able to favour different viable places
  or programmes.

## 3. Required observability before tuning

Extend canonical snapshots and comparison reports with:

- `community.spatial.exposures[]`: effect, source, resident, source/resident
  anchors, distance, radius, stacking ordinal/multiplier, and applied amount;
- coverage by effect and stacking group using stable distinct resident IDs;
- road-cell count, component IDs, and assigned route distances;
- resident work/activity assignments and fulfilled capacities;
- occupied land, used extent, remaining buildable land, cumulative income, and
  spend by category;
- pair-manifest validation showing exact held constants and deliberate
  differences.

The comparator rejects an inadmissible pair before calculating deltas. It does
not silently compare different building capacity, resident streams, seeds,
budgets, or durations.

## 4. Automated scenario matrix

All primary pairs run for 168 exact hours unless the scenario tests an immediate
boundary. Each accepted layout repeats ten times to prove deterministic
exposure, coverage, assignments, milestones, and state hashes.

| Pair or adversary | Held constant | Deliberate difference | Pass gate |
|---|---|---|---|
| Compact clustered / spread integrated | Homes, workplace, shop, Pond, Nature Patch, capacities, residents, seed, cash, duration | Anchors and required roads | Spread reduces nuisance exposure, improves mean Beauty and Liveability by the frozen meaningful margin, covers more distinct residents, and fulfils no fewer required jobs. |
| Nature served / nature unserved | Exact building multiset, roads, capacity, residents, seed, cash, duration | Nature beside homes versus unused edge land | Served town gains at least `+3` Beauty and `+2` Liveability or Belonging; unserved objects add no demand, migration, unlock, or progression benefit. |
| Amenity clustered / distributed | Two occupied neighbourhoods, two identical amenities, all other state | Amenity anchors | Distributed copies cover more distinct residents; a resident is counted once per source/effect and follows stacking rules. |
| Functional green mix / repeated spam | Equal nature-cell and cash envelope, essential capacity, seed, duration | Authored nature functions and anchors | Mix is no worse on distinct-resident Beauty coverage and improves Liveability or Belonging; fourth and later overlapping duplicate sources add zero. |
| Built-only / nature integrated | Equal homes, productive capacity, seed, starting resources, duration | Nature purchase and occupied land | Mixed town improves Beauty plus Liveability or Belonging while recording its cash/land/opportunity cost and receiving no free output or income. |
| Spread connected / bridge removed | All anchors and content | One critical road cell | Local effects remain; invalid work/activity assignments, participant effects, output, and income clear on the next simulation update. |
| Blank compact / blank sprawl | Homes, shop, seed, capacity, no nature or nuisance | Empty distance and roads | Community qualities do not improve merely because extent or route length increased. |
| Cohort A / cohort B | Town, candidates, economic state, available programmes | Identity/Freedom/Care weights | At least two viable place or programme options reverse order; there is no universal cohort-independent winner. |
| Radius boundary | Source and resident identities | Homes at `radius-1`, `radius`, `radius+1`, including diagonals | Canonical Manhattan inclusion, stable exposure IDs, and UI overlay agree exactly. |
| Same bounding box | Extent, buildings, capacity, seed, duration | Home/source positions | Outcomes follow resident exposure and coverage rather than extent. |
| Nature-only exploit | Starting grant, seed, duration | Repeated nature with no homes or participants | No population, assignment, output, income, demand milestone, tier-two unlock, or patron progress arises from object count. |

After the fixed matrix passes, run a bounded adversarial search over small legal
layouts with fixed content. Review the Pareto-leading layouts for repeated-item
concentration, unserved nature, and checkerboard convergence. This search is a
diagnostic gate: any newly discovered dominant exploit becomes a named frozen
scenario before tuning is accepted.

## 5. Blind Neighbourhood Test

### Stages

1. **Pilot — 3 players**: validate the brief, timing, telemetry, and rubric; do
   not count these sessions toward acceptance.
2. **Formative — two waves of 4 fresh players**: change at most one mechanic
   family between waves and preserve both result sets.
3. **Acceptance — 12 fresh players**: four city-builder regulars, four casual or
   occasional players, and four genre newcomers. Freeze build, brief, seeds,
   rubric, and thresholds before the first session.
4. **Durability — 4 acceptance players**: continue the same town for one more
   hour after the opening objective.

If acceptance narrowly misses one threshold, run six additional fresh players
on the unchanged build. Do not tune midway and combine cohorts.

### Neutral session brief

Allow 30 minutes and say only:

> Start from this empty plot. Reach tier two, keep the town financially viable,
> and leave it in a state you would choose to continue playing. There is no
> single correct solution.

Do not say *beautiful*, *community*, *nature*, *spread*, *buffer*, or
*neighbourhood*. Give control help only. Avoid continuous think-aloud; at fixed
intervals ask, “What are you trying to solve now?” A moderator hint marks all
subsequent related behaviour as prompted and ineligible for the unprompted
gate.

Follow with an 8–10 minute diagnosis task using a compact functioning town whose
homes have nuisance exposure and uneven amenity coverage:

> Residents are beginning to leave. Improve this town without deleting its
> main employer or ending with negative cash.

Finish with an 8-minute retrospective. Replay three placement or redevelopment
moments and ask, in order: which decisions mattered most; which area works best
and least well; what evidence changed the plan; what another ten minutes would
change; whether anything seemed worth repeating mechanically; whether resident
or place feedback influenced an edit; and only then what role nature and
separation played. Ask whether success and visual preference felt aligned.

### Behaviour record

Record timestamp, action, before/after screenshot, prior UI evidence viewed,
the player's stated reason, and the next canonical snapshot. An action is
**community-driven** only when it was unprompted, the player gives a
substantially correct resident/place reason, and the next snapshot confirms the
intended exposure, coverage, or participation change.

Record as failures or exploits:

- nature dumped on unused edge land solely for a global number;
- mechanical repetition of one amenity;
- greater extent without improved exposure or coverage;
- disconnected attractive places that serve nobody;
- packed layouts that ignore local effects yet dominate progression; and
- convergence on one prescribed successful template.

### Acceptance thresholds

- At least 9 of 12 players take one unprompted functional nature or
  nuisance-buffering action.
- At least 7 of 12 improve both positive coverage and nuisance separation.
- At least 8 of 12 make one correctly understood feedback-to-layout edit.
- At least 8 of 12 use at least one functional nature source plus a second
  nature function or reachable shared place for different explained roles when
  those choices are simultaneously unlocked and affordable.
- No more than 2 of 12 adopt repeated single-item spam as the apparent optimum.
- At least 9 of 12 reach the economic/progression objective.
- At least three materially different successful layout families appear.
  Families are classified by frozen topology evidence such as number of
  centres, road structure, nuisance buffering, and distribution of
  resident-serving nature—not by alternate skins on the same arrangement.
- At least 3 of 4 durability players retain or extend functional mixed green
  neighbourhoods.

## 6. Blind visual review

Capture final towns with one frozen full-town framing rule, camera angle,
lighting state, and UI visibility. Assign random IDs. Three reviewers who do
not know the player, simulation results, or build version rate each town from
1–5 for:

- intentional and readable composition;
- integration of nature with buildings;
- visual variety without mechanical repetition;
- welcoming community focal points; and
- coherent roads and land use.

Do not reward raw town size or empty space. Require a cohort median of at least
`3.5/5` for nature integration and intentional composition, with at least two of
three reviewers agreeing. A greater-than-two-point reviewer spread marks the
town contested instead of averaging disagreement away. Against a frozen
pre-change screenshot set, candidate towns must win at least 65% of anonymised
pairwise comparisons without scoring worse on road coherence.

## 7. Evidence and change control

- Pre-register pair manifests, scenarios, seeds, thresholds, human brief, and
  rubric before final tuning.
- Reserve at least one map/seed as a holdout never used while tuning.
- Preserve raw traces, comparison reports, screenshots, anonymised behaviour
  sheets, reviewer ratings, and a concise decision record.
- Test optimisers as well as decorators; do not recruit only players already
  inclined to make pretty towns.
- Do not count visual variety unless alternatives were unlocked and affordable.
- Change one mechanic family per matched tuning pass.
- A discovered exploit becomes a deterministic regression scenario.
- Passing automated scenarios cannot waive a failed behaviour or visual gate,
  and subjective review cannot waive a failed deterministic rule.
