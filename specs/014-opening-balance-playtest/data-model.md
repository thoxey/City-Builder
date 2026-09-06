# Data Model: Automated Opening Balance Playtest

## Strategy Config

- `scenario_id`, `primary_seed`, `seeds`
- `beauty_floor`, `max_hours`, `max_actions`
- `endpoint_building_id`, `endpoint_total_homes`
- ordered `road_cells` and `candidate_cells`

## Decision Record

- `index`, `sequence`, `absolute_hour`
- `decision` and human-readable `reason`
- `blockers`: stable structured strings/records from current state
- `request`: operation and semantic parameters
- `outcome`: status, rejection reason, details
- `before`, `after`: balance slices containing cash, demand, Beauty, building count,
  available choices, and state hash
- `delta`: elapsed hours, cash, each demand total/fulfilled/unserved, Beauty, structures

## Milestone Record

- `milestone_id`
- first-observed `absolute_hour`, `sequence`, and `decision_index`
- `state_hash`, demand slice, Beauty, and relevant building IDs

## Run Report

- schema/config/seed/status/failures
- ordered decisions and milestones
- `summary`: elapsed hours, idle hours, wait spans/reasons, demand earned/spent, placement
  counts/rejections, Beauty history/minimum, resource constraint counts, endpoint
- `final`: normalized balance slice, building manifest, progression gate
- `semantic_trace_hash`

## Suite Report

- schema/config/run timestamp (excluded from comparisons)
- primary replay comparison fields/result
- run reports for primary replay and seed cohort
- aggregate longest wait and constraint frequencies
- `all_passed`, failures
