# Migration Week Validation

Date: 2026-09-04  
Scenario: `community_migration_week`  
Seed: `22003`  
Duration: 168 exact hours

Migration quotes are non-mutating, enumerate only free housing slots, and use
canonical happiness/anchor/slot tie-breaking. Prediction evaluates a complete
representative 24-hour schedule, so night opportunities and scheduled nuisances
remain visible when the daily migration boundary occurs at dawn.

The same deterministic 28-candidate comparison accepts candidates for the
matched amenity town and accepts zero for the persistent-nuisance town. The
matched total is strictly higher. Cohort candidate weights affect the stream,
but no resident or aggregate contains a cohort approval, diversity bonus, or
monoculture penalty.

Population is bounded by explicit Residential slots. Community snapshots expose
arrivals, departures, rejections, cohort counts, and dominant-lens counts without
creating faction state.

The initial pre-feature comparison holds every candidate at the neutral `50`
target and therefore admits none at threshold `60`. With the same candidate
seeds, the authored compatible-effect fixture admits residents while the
persistent-nuisance fixture still admits zero. This is the initial before/after
trace for population behavior; later tuning must retain seed `22003` and the
same 28-candidate stream.
