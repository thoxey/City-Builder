# Live Early-City Balance Probe

Date: 2026-09-04  
Godot: 4.6.2.stable  
Scenario: `fresh_city` and `early_city_baseline`

These runs drove the live game through the bounded `city_playtest` runtime route.
They are diagnostic openings, not proposed final balance settings.

## Bridge smoke

- Fresh start: ready, empty map, sequence 0.
- Available choices: 12.
- Residential placement: applied as seeded variant `building_small_a`.
- Identical request retry: returned `duplicate`; building count stayed at one.
- Placement at `(99, 99)`: rejected as `outside_buildable_area`.
- 24-hour advance: exactly 24 hours emitted.
- Demolition: applied; building count returned to zero.

## Opening comparison after 48 hours

| Opening | Buildings | Population | Cash | Attractiveness | Residential demand | Industrial demand | Commercial demand |
|---|---:|---:|---:|---:|---:|---:|---:|
| 8 residential | 8 | 33 | 1000 | -288 | 60 | 100 | 100 |
| 8 industrial | 8 | 0 | 1000 | -240 | 100 | 60 | 100 |
| 4 residential, 3 industrial, 2 commercial | 9 | 17 | 2700 | -286 | 80 | 85 | 90 |

The single-purpose openings remained static. The mixed opening generated cash
without roads or any other connectivity requirement.

## Same-seed greenery A/B

Using seed 4242 and the identical nine-building mixed opening:

- No greenery: attractiveness -223, peak output 19, peak hourly income 95,
  cash after one day 1950.
- Four exact grass tiles: attractiveness -175, the same output and income, cash
  after one day 1910.
- Nineteen exact grass tiles produced attractiveness 734 due to overlapping
  local effects. Residential total demand then grew from 100 to 124 over 48
  hours while population remained 19 because no new capacity was placed.

## Findings for the first tuning pass

1. Roads currently do not gate employment or income, so a profitable city can
   ignore the road-building layer entirely.
2. Mixed cities earn 95 per active work hour with only three starter industrial
   buildings and recover small nature costs almost immediately.
3. Residential-only and industrial-only cities have no endogenous evolution
   over 48 hours; their state is effectively frozen after placement.
4. Satisfaction stayed at 1.0 in every probe, including no-job and no-resident
   openings, so it currently provides little early-game feedback.
5. Industrial output and last income correctly fall to zero outside work hours,
   but a final midnight snapshot hides the positive daytime economy. Scenario
   evaluation should use milestone observations rather than infer the whole run
   from its final snapshot.
6. The probe found missing snapshot paths used by the authored baseline:
   `land.free_count`, `tier_two_available`, and `available_choice_count`. These
   were added with regression coverage during this test pass.
7. The repaired live snapshot reports `tier_two_available=true` at hour zero on
   an empty city. If tier two is intended as an earned milestone, its current
   demand threshold is already satisfied by the starting demand of 100.

The strongest first balance hypothesis is to make connectivity meaningful and
reduce the immediate mixed-opening income slope before tuning cosmetic or story
systems.
