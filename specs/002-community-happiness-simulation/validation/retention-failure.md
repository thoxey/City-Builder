# Retention Failure Validation

Date: 2026-09-04  
Scenario: `community_retention_failure`  
Seed: `22004`

Unit verification covers the exact retention boundaries:

- A housed resident remains after 23 consecutive hours below `30`.
- The resident departs after the 24th consecutive below-threshold hour.
- One hour at or above threshold resets the counter to zero.
- Demolishing an occupied home sets `home_anchor` to null rather than deleting
  the resident.
- A free slot relocates homeless residents in canonical order.
- Without a slot, departure waits for the separate 24-hour relocation grace.

Departure records use stable reasons `sustained_unhappiness` and
`relocation_failed`, and freeing a resident immediately frees housing capacity.
