# Spatial and Demand Inventory

Captured 2026-09-05.

- Canonical local inclusion is Manhattan distance `<= radius`; diagonal cells
  do not receive bounding-box treatment.
- Garage nuisance radius is 1: noise affects Liveability during 08:00–18:00
  and visual clutter affects Beauty at all hours.
- Pond and Nature Patch benefit radius is 2. Their different effect IDs and
  stacking groups preserve function rather than awarding asset variety.
- Positive same-group overlap uses multipliers `1.0, 0.5, 0.25, 0.0...`.
  Negative nuisance records are retained independently.
- Exposure records identify resident, resident/source anchors, distance,
  radius, group, ordinal, multiplier, and signed applied amount. Coverage uses
  stable distinct resident IDs.
- Residential demand now reads the Community resident-served signal. With no
  residents it is zero, so unserved nature on an empty map cannot grow housing
  demand. The previous city-wide Attractiveness route remains only as an
  isolated-test/pre-Community compatibility fallback.
