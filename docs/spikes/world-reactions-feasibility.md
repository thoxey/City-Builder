# Spike: emotive world reactions

## Outcome

Feasible, with a bounded presentation-only system. The town already has the
simulation facts, entity identities, world positions, billboard rendering
technique, and illustrated icon language needed for short reactions above
people, cars, and buildings. The missing pieces are a small reaction projection,
one public person-position accessor, a clutter/cooldown policy, and a dedicated
speech-flag art family.

This should not become a second mood simulation. Reactions explain or flavour
state owned elsewhere; they never alter happiness, traffic, demand, schedules,
or progression.

## What the reference contributes

The useful idea in the reference is a compact, instantly readable vocabulary in
a speech-like silhouette: expression, sleep, punctuation, confirmation, and
warning all use the same recognisable carrier. We should borrow that grammar,
not its pixel treatment or face grid.

In this game's visual language the carrier should be a slightly wonky parchment
speech flag with thick near-black ink. Its content should normally be a symbolic
gesture rather than a literal face: a rose heart/lift for pleased, red recoil or
warning for concerned, a blocked-road kink with anger ticks for frustrated,
mustard discovery rays for surprised, motion ticks for busy, and a drooping
moon/inactive motif for sleepy. This keeps the project’s generally faceless
character rule while allowing entities to feel expressive.

Treat these as fixed-size world markers, not dialogue boxes. Assumed apparent
display range is 24 px minimum, 32–40 px typical, and 48 px maximum. Make a
labelled 6–8 silhouette exploration sheet before production, then preserve a
high-resolution master and export individual 128 px RGBA runtime files with
actual-size and noisy-town proofs. Do not ask an image model to produce the
runtime atlas directly.

## Evidence in the current architecture

### Rendering is already proven

`scripts/builder.gd` creates `Sprite3D` feedback, enables billboarding and
no-depth-test, raises it in world space, applies a deterministic opacity curve,
and frees it after 3.2 seconds. `plugins/nameplate/nameplate_plugin.gd` separately
proves persistent world-following billboards above buildings.

The reaction renderer can use the same primitives, but should live in a new
`WorldReactions` presentation plugin rather than adding more responsibility to
Builder.

### People are addressable, but their routine snapshot needs one field

People are stored as lightweight `PersonSlot` records and drawn through one
`MultiMeshInstance3D`; they are not nodes that can own child bubbles. Each slot
already has stable `resident_id`, `display_position`, visual state, purpose,
blocked reason, and car journey id. `get_civilian_snapshot()` exposes most of
that but currently omits `display_position` for ordinary rows.

The smallest production change is to add detached `display_position` and
`visible` fields to each resident row (or add a narrowly named operational
reaction-anchor projection). The reaction plugin can then follow selected
residents without breaking instancing or reaching into People’s private arrays.

### Cars already expose everything needed

`CarManager.get_traffic_flow_snapshot()` exposes journey id, resident id,
waiting state, segment progress, and display position. A car reaction should be
keyed by journey id and can express prolonged waiting, the start of movement
after a queue, or very rare ambient motoring flavour. If the resident is inside
the car, the reaction targets the car, never a hidden person proxy.

### Buildings have anchors and meaningful causes

`GameState.building_registry` provides stable placed instance ids, structure
indices, and anchors. Community exposes resident happiness, applied effects,
source anchors, operation records, and programme/activity changes. Existing
placement consequence code already understands affected homes and signed
quality deltas.

A building reaction should mean “this place changed or is doing something,” not
that the masonry has a private mood. Good causes are residents arriving or being
rehomed, a programme opening/closing, participant capacity filling, a material
local effect beginning, or a road-access state changing.

## Proposed flow

1. Authoritative systems commit a normal change set; no reaction data is saved.
2. A reaction projector compares the previous bounded presentation projection
   with the new one and emits semantic candidates.
3. `WorldReactionPolicy` orders candidates, applies per-target cooldowns,
   suppresses nearby low-priority clutter, and enforces a hard visible cap.
4. A renderer takes the selected records from a small pool, resolves their live
   anchor each frame, and displays a speech-flag sprite for 1.6–2.4 seconds.
5. Completion returns the sprite to the pool and starts the target cooldown.

Candidate contract:

```gdscript
{
  "target_key": "person:41",       # person, car, or building instance
  "target_kind": "person",
  "target_id": "41",
  "expression": "concerned",       # semantic asset key
  "cause": "happiness_drop",       # diagnostics/accessibility
  "priority": 80,
  "world_position": Vector3(...),
  "source_version": 217,
  "ttl_seconds": 2.0
}
```

Keep the contract semantic. No atlas cells, sprite filenames, or simulation
effects cross into the reaction candidate.

## Trigger policy

Condition changes should carry most of the meaning:

| Priority | Example | Target | Expression |
|---|---|---|---|
| 100 | becomes unhoused; route becomes impossible | person | concerned/frustrated |
| 90 | car has remained capacity-blocked beyond threshold | car | frustrated |
| 80 | resident happiness changes by a material threshold | person or current car | pleased/concerned |
| 70 | programme opens/closes; home gains/loses active benefit | building | busy/pleased/concerned |
| 50 | resident arrives, reaches work/activity, or returns home | person/building | pleased/busy/sleepy |
| 10 | rare flavour beat in a quiet area | any visible target | contextual ambient |

Recommended initial thresholds: happiness delta at least 8 points, traffic wait
at least 1.5 real seconds, 2.0 second display, 8–12 second per-target cooldown,
maximum 5 simultaneous reactions at 1080p, and minimum 1.35 world-unit spacing
for non-critical reactions. These are tuning defaults, not simulation rules.

Ambient reactions must be deterministic. Hash world seed, target kind/id, and a
coarse simulation-time bucket; never sample the global RNG from rendering. Gate
ambient candidates further so they run only when no recent condition candidate
exists nearby. Start with an expected town-wide rate around one ambient reaction
every 6–10 seconds, not one roll per entity per frame.

## Clutter, camera, and accessibility

- Suppress reactions during modal dialogue and radial navigation; consider also
  suppressing them during Community inspection and active placement.
- Cull off-screen and behind-camera anchors before arbitration.
- Keep one reaction per target, a global cap, local spacing, and priority-based
  pre-emption. A critical state change may bypass local spacing but not the hard
  cap.
- Follow the target in world space but clamp vertical bob so text-like motion
  does not become tiring. Cars need slightly more lead and height than people.
- Provide a settings toggle for ambient reactions; condition reactions can have
  a separate reduced-motion/quiet mode.
- Every expression must differ by silhouette/mark, not colour alone. The cause
  remains available to inspection/debug tools even when the reaction itself has
  no text.

## Performance disposition

The simulation already supports up to 512 people and 256 civilian cars, but the
renderer should never create a node for each. Project candidates on committed
state changes (hourly or event-driven), poll only live anchors for at most five
selected reactions, and reuse a pool of roughly 6–8 `Sprite3D` nodes.

That keeps routine work proportional to the bounded projection and visible
reaction count. The main performance risk is requesting full Community
explanations for every resident each frame; production code must instead use a
bounded operational delta projection at commit time.

## Spike code and what it proves

`scripts/reactions/world_reaction_policy.gd` is a pure, unregistered prototype.
It proves deterministic ambient selection, priority order, per-target exclusion,
cooldowns, local clutter suppression, and a hard visible cap without touching
simulation authority or global RNG. Its unit tests live in
`test/unit/reactions/test_world_reaction_policy.gd`.

It deliberately does not register a plugin, edit existing dirty runtime files,
or ship provisional art. That is the correct stopping point for a feasibility
spike.

## Production slice estimate

The smallest useful vertical slice is about 2–4 focused development days plus
art review:

- half day: operational reaction projection and person anchor accessor;
- half to one day: pooled renderer, camera culling, suppression modes, cleanup;
- half day: three condition triggers (blocked person, waiting car, happiness
  delta) and one deterministic ambient trigger;
- half day: unit/integration/performance instrumentation and replay parity;
- one day or parallel art pass: exploration, six approved masters, runtime
  exports, manifest, actual-size and noisy-town QA.

Defer building reactions to a second slice unless one building trigger is needed
to prove the target abstraction. They have more semantic ambiguity than people
and traffic, while the renderer is the same.

## Recommendation

Proceed with a people-and-cars vertical slice behind a presentation setting.
Use three reactions first: `pleased`, `concerned`, and `frustrated`. Trigger them
only from meaningful transitions, then add rare deterministic ambient `busy` or
`sleepy` beats after playtesting the visual density. Add buildings once the team
has agreed which operational changes a building is allowed to “speak for.”

Success means players can correctly infer why at least 80% of condition-driven
reactions appeared in a short narrated playtest, no more than five bubbles are
visible, ambient output is repeatable for the same seed, and the added
presentation work stays within the existing render-submit budget.
