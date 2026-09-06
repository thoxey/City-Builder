# Venue Inventory Before Feature 008

Captured 2026-09-06 from authored JSON and Community's existing source/allocation
rules.

| Building | Existing role | Building schedule/capacity | Participant effects | Decision baseline |
|---|---|---|---|---|
| Pub | commercial/productive | 17:00–23:00, 30 | none | participant candidate |
| Restaurant | commercial/productive | 12:00–23:00, 40 | none | participant candidate |
| Private Members' Club | commercial/productive | 18:00–02:00, 25 | none | participant candidate |
| Crazy Golf | unique landmark | none | none | participant candidate; needs profile |
| Town Hall | functional civic | no BuildingProfile | `civic_heart`, local, radius 3, amount 2 | retain local-only |
| Pirate Radio Station | unique landmark | none | none | retain productive/cosmetic non-attendance |
| The Theatre | programme-driven landmark | programme effects; no BuildingProfile schedule | participant capacity 60; programmes `plays`, `rock_nights`, `community_use` | retain participant reference |

Before this feature only Theatre can enter Community activity allocation. Pub,
Restaurant, and Members' Club expose productive commercial capacity/opening hours
but no participant effect; Crazy Golf exposes neither participant capacity nor a
schedule. Community uses participant-effect capacity when present, canonical road
reachability, and stable assignment ordering.
