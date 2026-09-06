# Dialogue Workshop: First Land Quest and Townspeople

**Status**: Workshop material only — no runtime prose approved

**Hard rule**: Everything under “copy options” is an unapproved draft. Selecting a
structural option does not approve its wording. Final lines and option labels must be
worked through scene by scene and recorded in the approval table before implementation.

## Dramatic purpose

The quest should turn “the starter plot is full” into the player's first negotiation
with a person who has power over the town. Ambrose believes an old acquaintance can be
persuaded; Sir William should resist for an intelligible reason, not merely demand a
button press. The eventual grant should feel like permission carrying expectations.

The two short aftermath scenes then show why “more room” does not solve planning by
itself. The same shop/new parcel creates paired, credible disagreements: access versus
domestic calm, and visual stewardship versus shared public life.

## Decisions needed before prose approval

### D1 — Who does the player speak as?

- **A. Ambrose is the player's speaking proxy (recommended for current code).** Use
  semantic `player` for Ambrose and do not also include an `ambrose` participant. This
  matches the current player portrait/name mapping and needs no new art.
- **B. Ambrose is a separate guide.** Add and approve a distinct player presentation
  identity before writing player options. This is clearer if the player is the mayor,
  but expands scope to a name/portrait/expression decision.
- **C. The player is silent.** Ambrose and Sir William speak, but player “choices” become
  direction prompts rather than spoken replies. This weakens the conversation contract
  and is not recommended.

### D2 — Sir William's place association

- **A. A manor/estate house just beyond the starter boundary (recommended).** Strong
  landownership logic and a useful visual promise, but needs a new scenic/story building
  model and an approved name.
- **B. An estate office/gate lodge at the boundary.** Cheaper/smaller visual scope and a
  natural place to negotiate access, but makes Sir William feel less grand.
- **C. An existing civic room at Town Hall.** No new world art, but the prompt's likely
  house staging and Sir William's territorial presence become much weaker.

Provisional place-name families (not approved): formal (`Howarth Hall`, `William's
Estate`), local (`Brackenleigh`, `Foxcombe House`), comic (`Lower Upper Hall`, `The
Smaller Great House`). The final choice should fit the project's naming voice.

### D3 — First outcome

- **A. Immediate equivalent parcel for every approach (recommended).** Sir William
  grants one authored strip/parcel; the choice records narrative posture only.
- **B. Promise plus one follow-up objective.** Stronger quest arc but delays the requested
  land reward and risks absorbing another workstream.
- **C. Different parcels by approach.** Mechanically expressive but introduces an early,
  hard-to-read permanent consequence before balance evidence exists.

Exact shape remains to be selected after seeing the approved Sir William place on the
map. Candidate scales for playtest, not approval: 32, 48, or 64 new cells contiguous with
the rooted starter boundary.

### D4 — Aftermath timing

- **A. Two paired vignettes immediately after the grant (recommended).** Completes the
  four-viewpoint promise in this quest and makes the land consequence personal.
- **B. One pair before and one pair after negotiation.** Better pacing variety but makes
  the petition feel interrupted.
- **C. Introduce all four via Inbox over the next day.** Naturalistic, but adds scheduling
  and can leave the workstream apparently incomplete.

## Provisional recurring cast foundations

The roles are proposed first; names and voice anchors are separate approvals. Each
person wants something concrete, accepts a real cost, and has a line they will not cross.

| Viewpoint | Provisional role | Recognizable desire | Accepts | Will not accept | Primary tension |
|---|---|---|---|---|---|
| Opportunity | Young shop assistant, delivery rider, or job seeker | Work and useful shops within a route they can actually travel | Some bustle and denser streets | Being priced/routed out of opportunity | Livability's wish for distance and quiet |
| Livability | Night worker, carer, or parent near the first homes | Sleep, safety, clean air, and daily needs without constant disturbance | A slightly longer trip for domestic calm | Noise, fumes, or crowding presented as inevitable progress | Opportunity's tolerance for bustle |
| Beauty | Gardener, sign painter, stonemason, or retired groundskeeper | A town whose streets, edges, and landmarks show care and continuity | Spending space/money on planting and finish | Blank utility sprawl or treating appearance as frivolous | Belonging's tolerance for messy, popular use |
| Belonging | Club secretary, publican's organizer, choir lead, or long-time neighbour | Shared places where different residents meet and feel they have a stake | Noise/crowding at sensible hours | Exclusive spaces or technically efficient places nobody shares | Beauty's preference for order and restraint |

### Naming palettes (choose/edit; unapproved)

- **Grounded ensemble**: Nell Carter, Tom Broom, Maisie Wren, Idris Price.
- **Broader comic ensemble**: Dot Quick, Wilf Hush, Verity Green, Reggie Allsorts.
- **Place-rooted ensemble**: names derived from the eventual town/estate and local family
  history; this requires the user to supply or approve the locality vocabulary first.

### Voice-anchor options

These are directions, not final prose:

- **Opportunity**: quick concrete verbs; sees routes, opening hours, wages, and chances;
  jokes by moving the conversation forward; avoids corporate/business jargon.
- **Livability**: measured and specific; notices time of day and domestic consequence;
  dry understatement rather than scolding; avoids being written as anti-growth.
- **Beauty**: sensory and craft-aware; notices materials, sightlines, trees, and upkeep;
  can be exacting but not precious; avoids “pretty versus practical” clichés.
- **Belonging**: speaks in names, rituals, invitations, and who is missing; warmth can turn
  firm around exclusion; avoids generic community slogans.

## Recommended staged scene map

The IDs below are stable structural proposals. They are not approval of copy.

### Scene S1 — The petition begins

**Event purpose**: Pay off tutorial B18, explain the land constraint, travel/transition
to Sir William's place, and end with a clear player approach.

**Participants**:

- D1-A: `player` (presented as Ambrose) and `aristocrat_patron`.
- D1-B: `player`, `ambrose`, and `aristocrat_patron`.

**Beat inventory**:

| ID | Speaker / expression | Beat and motivation | Gameplay outcome |
|---|---|---|---|
| LQ01 | Ambrose / thoughtful | Notices that a functioning town is now pressing against its first boundary | Connects first shop to land need |
| LQ02 | Ambrose / concerned | Explains Sir William controls adjoining land and is persuadable because they have history | Names quest objective and relationship |
| LQ03 | Narration | Moves to/establishes the approved residence or estate place | Establishes world association |
| LQ04 | Sir William / neutral | Greets Ambrose as an acquaintance and makes clear he already knows the town's experiment | Avoids stranger exposition |
| LQ05 | Sir William / disapproving or thoughtful | Raises a stewardship concern: more land can magnify poor planning | Gives resistance a motive |
| LQ06 | Ambrose/player / thoughtful | Frames the petition without promising a perfect town | Leads to choice |
| LQ07 | Player choice | Practical, community, or stewardship approach | Sets exactly one semantic approach flag |
| LQ08A-C | Sir William / thoughtful | Tests the selected argument rather than instantly capitulating | Branch acknowledgement only |
| LQ09 | Narration | Brief pause or place detail that lets the choice land | Pacing beat |
| LQ10 | Sir William / pleased | Grants or promises the approved outcome with a clear boundary/expectation | Commits `first_land_quest_agreed` |

**Choice motivations and semantic outcomes**:

| Approach ID | What the player argues | Sir William hears | Mechanical outcome (recommended) |
|---|---|---|---|
| `practical_case` | The town has demonstrated useful demand and needs room to function | Competence, growth, and accountability | Set approach flag; converge on same parcel |
| `community_case` | People already rely on the town and need room for daily life | Obligation to residents and continuity | Set approach flag; converge on same parcel |
| `stewardship_case` | Expansion can protect the whole estate if boundaries/design are handled well | Care for land and legacy | Set approach flag; converge on same parcel |

**Copy options — unapproved drafts**:

For LQ01/LQ02, choose a tonal lane before line editing:

- **Direct/dry**: “The shop has done its job rather too well. We have customers and no
  elbow room.” / “The next field is Sir William's. Fortunately, so is the argument.”
- **Warm/observant**: “Look at them using it already. A town can outgrow its first map
  before anyone admits it has begun.” / “Sir William owns the adjoining ground. He also
  remembers me, which may yet count in our favour.”
- **Broader comic**: “We have built a shop, attracted a queue, and run out of town in
  roughly that order.” / “Sir William has land. I have a history of returning his books.
  Between us, we may have the makings of a negotiation.”

For LQ05, Sir William's resistance can emphasize:

- **Stewardship**: expansion without a plan merely spreads the mistakes.
- **Legacy**: he will not have an inherited estate remembered as spare squares on a map.
- **People**: he has heard both praise and complaints and wants evidence the player sees
  residents, not only buildings.

Provisional choice-label shapes (not approved final text):

- Practical: “Give us room, and we'll prove the town can sustain it.”
- Community: “The people already here need room to make this a home.”
- Stewardship: “Let us grow in a way that leaves your land better connected, not used up.”

### Scene S2 — Opportunity versus Livability

**Event purpose**: Make the first shop's location personal through two understandable,
opposed reactions. This can refer only to evidence the game can honestly project.

**Participants**: `player`, approved Opportunity townsperson, approved Livability
townsperson.

| ID | Speaker / expression | Beat and motivation | Gameplay outcome |
|---|---|---|---|
| LQ11 | Opportunity / pleased or concerned | Names how route distance/opening access affects work or shopping | Establishes access desire |
| LQ12 | Livability / concerned | Names a specific nearby-home consequence without opposing all shops | Establishes domestic cost |
| LQ13 | Opportunity / thoughtful | Concedes the cost but explains what excessive distance excludes | Makes tension reciprocal |
| LQ14 | Livability / thoughtful | Concedes usefulness and asks for separation/mitigation rather than removal | Avoids a correct-answer caricature |
| LQ15 | Player optional choice | Acknowledge access, calm, or the need to balance both | Records no balance mutation; optional narrative flag |

**Copy kernels — unapproved**:

- Opportunity: “Near enough to use” / “a job after the last bus” / “a shop is no use if
  getting there costs the evening.”
- Livability: “near is not the same as beside” / “the sign goes dark; the noise does not”
  / “progress ought to let somebody sleep.”
- Mutual concession: each person names one condition under which the other's preferred
  placement would be acceptable.

### Scene S3 — Beauty versus Belonging

**Event purpose**: Reframe the new parcel as a design responsibility and show that a
lively shared place can conflict with visual order without either desire being foolish.

**Participants**: `player`, approved Beauty townsperson, approved Belonging townsperson.

| ID | Speaker / expression | Beat and motivation | Gameplay outcome |
|---|---|---|---|
| LQ16 | Beauty / concerned or thoughtful | Sees the raw boundary/edge and asks what kind of place it will become | Establishes stewardship desire |
| LQ17 | Belonging / pleased | Imagines a shared use and names who would gather there | Establishes social desire |
| LQ18 | Beauty / thoughtful | Accepts use/liveliness but resists careless finish or placeless sprawl | Makes tension reciprocal |
| LQ19 | Belonging / concerned | Accepts care/order but resists exclusivity or pristine emptiness | Prevents sentimentality |
| LQ20 | Narration or player | Leaves the parcel visibly open to the player's authorship | Completes viewpoint foundation |

**Copy kernels — unapproved**:

- Beauty: “an edge tells you what a place thinks of itself” / “planting is not what you
  add after the important work” / “leave one view worth walking toward.”
- Belonging: “somewhere with enough chairs” / “a tidy square nobody may use is only a
  diagram” / “give people a reason to say ours.”

## Expression plan

Use only established semantic keys: `neutral`, `pleased`, `disapproving`, `angry`,
`surprised`, `concerned`, and `thoughtful`. The workshop deliberately favors thoughtful/
concerned distinctions; anger should be reserved for a genuinely sharper approved
version and not used merely to make conflict obvious.

Each new townsperson needs at minimum `neutral`, `pleased`, `concerned`, and `thoughtful`
approved art or an explicitly approved temporary fallback policy. Final beat authoring
must validate every expression against the character's own map.

## Gameplay outcome options

### Recommended invariant outcome

All three petition approaches:

1. set one approach flag at choice commit;
2. converge on the common agreement node;
3. acknowledge the negotiation event;
4. apply the same `first_land_quest_parcel` through BuildableArea once;
5. dispatch the two paired aftermath events in stable order; and
6. write quest completion after both are acknowledged.

The selected approach is retained for later authored reactions but has no hidden balance
effect in this workstream.

### Alternative follow-up shape

If D3-B is selected, LQ10 records one approved objective such as demonstrating connected
access or preserving a boundary feature. The objective must use canonical evidence,
remain one step, and grant the same parcel on completion. Exact objective and copy would
need a second specification pass before implementation.

## Approval record

| Item | Status | Approved selection/copy |
|---|---|---|
| D1 player/Ambrose identity | Pending | — |
| D2 Sir William place association/name/staging | Pending | — |
| D3 land outcome and exact geometry | Pending | — |
| D4 aftermath timing | Pending | — |
| Four roles, names, relationships, and voice anchors | Pending | — |
| Scene S1 LQ01–LQ10 exact prose and choice labels | Pending | — |
| Scene S2 LQ11–LQ15 exact prose | Pending | — |
| Scene S3 LQ16–LQ20 exact prose | Pending | — |
| Expression assignments and portrait/fallback policy | Pending | — |
| Runtime scene package | Not authorized | — |

## Suggested next workshop step

Approve or edit D1–D4 first. Then workshop S1 only, selecting one tonal lane and revising
LQ01–LQ10 line by line. The two townsperson pairs should be named and voiced after Sir
William's scene has fixed the game's dialogue register.
