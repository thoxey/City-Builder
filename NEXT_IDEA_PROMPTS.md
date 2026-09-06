# Next Idea Prompts

Ready-to-use prompts distilled from the playtest notes. Take one prompt at a
time through the Spec Kit workflow, then update its checklist here.

## Run the next workstream

Use this generic prompt whenever you want to pick up the next item:

```text
Open NEXT_IDEA_PROMPTS.md and take the first workstream in the Workflow tracker
that has not been fully completed and verified. Treat that workstream's Prompt
section as the feature brief and carry it through the repository's complete
Spec Kit workflow: create or resume the specification, complete the plan,
generate the tasks, implement them, and verify the result.

Before starting, inspect the repository and the selected workstream's existing
spec or implementation so you resume rather than duplicate work. Follow all
project instructions, preserve unrelated changes, and keep scope within that
one workstream. Update both its detailed checklist and the top Workflow tracker
as each stage is genuinely completed, and add the generated spec-directory link
to its “Spec” line.

Work autonomously through every stage that does not require my creative choice.
If the selected prompt calls for collaborative dialogue writing, approval of
final prose, or another explicit decision from me, prepare the requested beats
or options and pause at that checkpoint instead of inventing approval. Resume
the remaining workflow after I answer.

Do not mark implementation or verification complete until the relevant tests,
in-game checks, visual QA, and acceptance criteria in the selected prompt have
actually passed. When finished, summarize what changed, show the verification
evidence, identify any remaining risks, and tell me which workstream is next.
```

## Workflow tracker

| # | Workstream | Prompt | Spec | Plan | Tasks | Implement | Verify |
|---|---|---|---|---|---|---|---|
| 1 | First tutorial mini-quest | Ready | [x] | [x] | [x] | [x] | [x] |
| 2 | First land quest and townspeople | Ready | [ ] | [ ] | [ ] | [ ] | [ ] |
| 3 | Automated opening balance playtest | Ready | [x] | [x] | [x] | [x] | [x] |
| 4 | UI and feedback improvements | Ready | [ ] | [ ] | [ ] | [ ] | [ ] |
| 5 | Live placement consequences | Ready | [ ] | [ ] | [ ] | [ ] | [ ] |

When starting a workstream, link its generated spec directory beneath the
corresponding prompt. Do not silently expand one workstream to absorb another.

## 1. First tutorial mini-quest

### Tracking

- [x] Specification created
- [x] Plan completed
- [x] Tasks generated
- [x] Implemented
- [x] Automated verification passed
- [x] Dialogue and play-feel reviewed in game
- Spec: [`specs/012-first-tutorial-mini-quest/`](specs/012-first-tutorial-mini-quest/)
- Status: **Implemented and verified for the user-approved literal placeholder
  pass.** The complete beat inventory and copy convention are in
  [`dialogue-workshop.md`](specs/012-first-tutorial-mini-quest/dialogue-workshop.md),
  with verification evidence under the spec's `validation/` directory. The
  placeholder presentation and mechanical pacing were reviewed; replacing the
  labels with characterful final prose remains a separate editorial pass.

### Prompt

```text
Create the first guided mini-quest chain for a fresh town. Its purpose is to
teach the opening town-building loop through charming, characterful dialogue,
not through a dry sequence of instructions.

The intended gameplay sequence is:

1. “Place the Town Hall” is the first guidance the player receives.
2. Placing the Town Hall leads to a prompt to build some road.
3. Once enough road has been placed, the player is asked to place at least two
   different kinds of nature so town Beauty returns to a positive value.
4. The resulting Homes demand leads into placing early housing, such as houses
   or a tower block.
5. Teach that homes placed directly beside one another may have worse quality,
   and encourage the player to add decoration.
6. Introduce industry as somewhere for residents to work and teach the player
   to keep it away from housing.
7. Explain that residents now work and earn money, then introduce the first
   shop. Use its placement to introduce the trade-off between convenient access
   and residential impacts.
8. Completing the first shop should hand off cleanly to the first full-dialogue
   land quest; that later quest is a separate workstream.

Design this as a robust state-driven mini-quest rather than a brittle list of
clicks. Resume correctly after save/load, do not repeat completed guidance, and
handle players who perform steps early or choose valid buildings in an unusual
order. Reuse the existing compact guidance, dialogue, event, progression, and
placement systems wherever their contracts fit.

Dialogue authoring must be collaborative. First identify every required beat,
its speaker, emotional purpose, trigger, gameplay lesson, and whether it belongs
in compact guidance or a fuller exchange. Then help me write the actual dialogue
in my voice, one coherent scene or beat group at a time. Offer alternatives and
editing help, but do not silently settle on final copy or implement placeholder
prose as though I approved it. Clearly mark any temporary copy. Once I approve
the writing, implement it through the project’s established dialogue-authoring
format and expression vocabulary.

Include automated coverage for state transitions, early/out-of-order actions,
save/load recovery, and the handoff after the first shop, plus a short in-game
playtest checklist focused on pacing, clarity, and whether the dialogue is fun.
```

## 2. First land quest and townspeople

### Tracking

- [ ] Specification created
- [ ] Plan completed
- [ ] Tasks generated
- [ ] Implemented
- [ ] Automated verification passed
- [ ] Dialogue and character voices reviewed in game
- Spec: _not started_

### Prompt

```text
Create the first full-dialogue quest, triggered after the player completes the
opening mini-quest and places their first shop. Mr Ambrose explains that the town
needs more land and believes Sir William can be persuaded to give up some of his.
Develop this into a staged scene, likely at Sir William’s house, with the relevant
characters already acquainted. Establish what residence, estate, or other
building association Sir William needs so the quest has a clear place in the
town and world.

Use this quest to begin making planning trade-offs personal through recurring
minor townspeople. Explore four distinct personality viewpoints associated with
Opportunity, Livability, Beauty, and Belonging. They must feel like people with
recognizable desires and conflicting preferences, not labels for four stats. For
example, one person may object that a shop is too far away to walk to while
another dislikes the consequences of living beside it. Define how these voices
can recur in later reactions without trying to build every future encounter now.

Dialogue authoring must be collaborative. Begin with the dramatic purpose,
participants, scene beats, choices, character motivations, expressions, and
gameplay outcomes. Help me write all final dialogue in my own voice by working
through it scene by scene, offering options and editorial feedback. Do not treat
generated placeholder copy as approved final writing. Only implement dialogue
after I have approved it, using the established event/dialogue schema and stable
expression vocabulary.

Specify the quest trigger, completion state, land-related outcome or follow-up,
save/load behavior, and how it avoids replaying. Keep the scope centered on this
first quest, Sir William’s world presence, and the minimum character foundation
needed for the four viewpoints. Include automated narrative/progression tests
and an in-game review checklist for staging, voice, choice clarity, and pacing.
```

## 3. Automated opening balance playtest

### Tracking

- [x] Specification created
- [x] Plan completed
- [x] Tasks generated
- [x] Implemented
- [x] Automated verification passed
- [x] Baseline traces reviewed and ready for a later balance pass
- Spec: [`specs/014-opening-balance-playtest/`](specs/014-opening-balance-playtest/)
- Status: **Complete and verified.** The accepted three-seed baseline, isolated
  primary replay, acceptance audit, and normal-renderer evidence are in the
  spec's [`validation/`](specs/014-opening-balance-playtest/validation/) directory.

### Prompt

```text
Build an automated, AI-directed playtest of the sparse opening game so future
demand and progression balancing can be based on repeatable evidence. This
workstream creates the test and its observability; it must not prematurely tune
the balance values it is intended to measure.

The playtest agent should start from a fresh city, inspect normalized game state
and available choices, and make legal building decisions through the existing
city-playtest MCP. Extend that MCP only where the current semantic tools or state
are genuinely insufficient. The agent should act promptly whenever an intended
building becomes affordable and available rather than advancing time in large,
arbitrary chunks.

Use an explicit, deterministic starter strategy. Maintain a target Beauty of at
least 200, create a simple reusable road grid or another clearly documented
layout that satisfies access and placement rules, and place the buildings needed
to progress through early Homes, Work, and Shops demand. Define a clear default
endpoint during specification—at minimum it should exercise the wait that leads
to the 75 lifetime Homes-demand post-war mid-block unlock, unless repository
rules reveal a more useful adjacent milestone.

Record a machine-readable action trace and milestone report including elapsed
game hours, idle hours between meaningful actions, demand earned and spent,
lifetime demand totals, unlock times, placed buildings, resource constraints,
placement rejections, Beauty over time, and the reason for each wait or action.
Run deterministically for a fixed seed and across a small declared seed set.

The result should make questions such as “where is the player forced to wait?”,
“which resource or rule caused the wait?”, and “how much would an introductory
boost need to change?” straightforward to answer. Provide a baseline report and
a documented command or MCP workflow that can be rerun after later balance
changes. Prove parity with ordinary gameplay commands, bounded execution, useful
failure diagnostics, and stable replay. Finish by identifying the measurements
that a separate balance pass should compare; do not implement the introductory
demand boost in this workstream.
```

## 4. UI and feedback improvements

### Tracking

- [ ] Specification created
- [ ] Plan completed
- [ ] Tasks generated
- [ ] Implemented
- [ ] Automated verification passed
- [ ] Visual QA completed at supported resolutions
- Spec: _not started_

### Prompt

```text
Implement a focused set of UI feedback improvements that make community values,
demand progression, and immediate building effects easier to read.

1. When Ambrose says Opportunity, Livability, Beauty, or Belonging in dialogue,
   render the matching community icon beside the keyword. Define safe behavior
   for wrapping, repeated keywords, capitalization, accessibility, and missing
   icon assets without changing the authored meaning of the dialogue.
2. In the hover details for Homes, Work, and Shops demand, show both the current
   amount and the lifetime total. Make lifetime-based unlock requirements, such
   as 75 total Homes demand ever, visible and unambiguous.
3. Improve the community-value icons that rise from buildings after placement.
   Fade the early portion relatively quickly, then ease into a slower taper so
   the icons linger long enough to read without becoming permanent clutter.
4. While a building is held for placement, show its known intrinsic effects and
   costs with signed values and the appropriate icons: demand cost plus relevant
   Opportunity, Livability, Beauty, and Belonging effects.

Keep item 4 to authored/base information that is known without evaluating the
hovered map cell. Tile-specific simulation, affected-neighbor calculations, and
live comparison of locations belong to the separate “Live placement
consequences” workstream.

Reuse established community icons and visual language. Include automated tests
for value/keyword mapping and displayed data, plus visual QA for animation
timing, readability, localization/wrapping, placement mode, and supported screen
resolutions.
```

## 5. Live placement consequences

### Tracking

- [ ] Specification created
- [ ] Plan completed
- [ ] Tasks generated
- [ ] Implemented
- [ ] Automated verification passed
- [ ] Placement parity, performance, and visual QA completed
- Spec: _not started_

### Prompt

```text
Create a live placement-consequences preview for held buildings. As the player
moves a valid building preview around the map, calculate and present what would
happen if it were committed on the current tile so locations can be compared
before placement.

The preview should update demand costs, community-value changes (Opportunity,
Livability, Beauty, and Belonging), affected nearby buildings or residents,
bonuses, penalties, effect radii, access or adjacency consequences, and other
material outcomes already supported by the simulation. Make positive, negative,
unchanged, invalid, and uncertain results visually distinct without flooding the
screen. Clearly separate intrinsic building effects from consequences caused by
the selected location.

Use the same canonical evaluation logic as committed placement. Previewing must
not mutate game state, consume resources or demand, emit durable events, advance
progression, or change deterministic results. The values shown immediately
before placement must match the values actually applied after placement, apart
from explicitly documented concurrent simulation changes. Define behavior for
invalid cells, rotation, multi-cell footprints, overlapping effects, replacement,
locked information, cancellation, rapid cursor movement, and save/load.

Treat this as a substantial simulation-and-UI feature. Plan a performant update
model with caching or invalidation where appropriate rather than recomputing the
whole town every frame. Add parity tests between preview and commit, no-mutation
tests, performance coverage on representative large towns, and visual QA for
clarity across placement modes and supported resolutions.
```
