# Park and Noise Validation

Date: 2026-09-04  
Scenario: `community_park_and_noise`  
Seed: `22002`

The catalog-backed integration places a resident within range of the Duck Pond
and Nightclub at hour 21. The resulting effect set contains separate
`accessible_recreation` (Liveability), `shared_greenery` and `local_landscape`
(Beauty), `compatible_crowd` (Belonging participant benefit), and
`late_music_noise` (neutral Liveability nuisance).

The same evaluated resident has positive Belonging and negative Liveability in
one snapshot. Schedule boundary tests confirm a `21..4` effect is active at 21
and 03, and inactive at the exclusive end hour 04. Moving the home outside the
authored radius removes only the local contribution.

Initial values remain authored fixtures. Any tuning change must replay the same
seed and layout before acceptance.

## Initial before/after trace

For seed `22002`, the pre-feature baseline contains no Community effects and all
four targets remain `50`. The authored slice adds independent park Liveability
and Beauty contributions and, at hour 21, adds the attendee's positive
Belonging alongside the negative neutral Liveability noise. This matched-layout
comparison is the frozen initial balance trace; future amount changes compare
against the authored values in the scenario fixture rather than a different
resident stream.
