# Contract: Recurring Townsperson Profiles

## Purpose

A profile gives later authored scenes a stable human perspective. It is not dialogue,
not a stat modifier, and not a runtime text-generation prompt.

## Required coverage

The first-land quest definition references exactly four unique character IDs. Their
`townsperson_profile.dominant_quality` values cover exactly once:

```text
opportunity, liveability, beauty, belonging
```

The canonical data spelling is `liveability`. Approved displayed copy may use the
project's chosen locale spelling without changing the ID.

## Required character fields

Each profile's enclosing character definition has:

- stable `character_id` and approved `display_name`;
- `character_type: "townsperson"`;
- approved biography or an intentionally empty approved bio;
- portrait, `default_expression`, and semantic expression map;
- no patron/demand arrival gate unless a later specification adds one; and
- the profile fields defined in `data-model.md`.

## Humanity checks

Validation and editorial review require each person to have:

- one concrete want that could be affected by town planning;
- at least one cost they tolerate to obtain it;
- at least one unacceptable cost;
- tension with at least one of the other three profiles;
- at least one point on which they can concede the opposing view; and
- voice notes describing rhythm/posture/humour and at least one pattern to avoid.

Names and copy must not contain the dominant quality as a title, catchphrase, or obvious
stat mascot. A reaction must cite a concrete lived consequence rather than merely naming
the quality.

## Reaction selection

Later authored content may match stable `reaction_tags`, for example:

```text
shop_access, walking_distance, home_noise, industrial_fumes,
street_trees, boundary_finish, shared_space, exclusion
```

A tag selects from already-authored event/beat records. It must not interpolate the
voice anchor into generated prose. If no approved reaction exists, emit nothing or use
an explicitly authored neutral fallback; never synthesize a line.

## Simulation boundary

Townsperson profile fields do not change `CommunityResident.quality_importance`, current
qualities, target qualities, composite happiness, building effects, demand, or placement
validity. A later feature may connect named profiles to live residents only through a
separate specified mapping and canonical Community authority.

## Persistence

Character/profile data is authored content and not copied into every save. Saves retain
only stable referenced character IDs and semantic reaction/quest flags. Missing content
on load produces a stable diagnostic and never substitutes another identity.

## Approval and validation

Runtime definitions are permitted only after the workshop approval record includes the
role, name, voice anchor, relationship/tension, portrait policy, and expression set.
Manifest validation rejects duplicate quality coverage, unknown tags/qualities,
unresolved tensions, missing expressions, or draft/provisional markers.
