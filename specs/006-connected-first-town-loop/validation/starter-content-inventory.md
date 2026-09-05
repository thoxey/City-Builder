# Starter Content Inventory

Captured 2026-09-05 from the authored JSON validated by the data editor.

| Choice | Pool/role | Community contract |
|---|---|---|
| Small Residence A | residential T1 / functional | Secure home, resident Liveability +20 |
| Cottage Residence D | residential T1 / functional | Secure home, resident Liveability +20 |
| Small Residence C | residential T2 / functional | Secure home, resident Liveability +20 |
| Small Commercial B | commercial T1 / functional | Reachable local shopping (Opportunity +5) and high-street encounter (Belonging +3), capacity 10 |
| Business Park (Garage) | industrial T1 / functional | Reachable employment (Opportunity +15), capacity 20, 08:00–18:00; local noise −7 and visual −4 within radius 1 |
| Duck Pond | amenity / functional | Local recreation +6, greenery +7, landscape +5 within radius 2; reachable meeting place +4, capacity 20 |
| Nature Patch | amenity / functional | Local nature +4 and landscape +6 within radius 2 |
| Grass variants | nature palette / cosmetic_only | No Community or progression effect |

All functional entries above have a `CommunityEffectProfile`; cosmetic-only
entries have none. The validator rejects missing roles on nature, functional
content without effects, cosmetic content with effects, and incomplete effect
records.

Opening pool thresholds are `0` for T1 and `30` for T2. Fresh demand is `25`
per growth bucket, so every T1 pool is usable and every T2 pool is initially
locked. A road cell costs £2.
