# Balance Comparison Capability

The comparison layer validates matching scenario id and seed before reporting
metric changes. Its automated tests cover cash deltas, incompatible scenario
rejection, and incompatible seed rejection. Reports include milestone-hour,
cash, output, population, satisfaction, attractiveness, demand, building-count,
rejection-count, and terminal-condition differences. It deliberately produces
no composite “fun” score.

The canonical `early_city_baseline` fixture defines a 48-hour window, positive
output success, low-cash soft failure, no-cash/no-choice hard failure, and early
population, tier-two, and land-pressure milestones. Actual before/after tuning
runs should only be frozen after the first intentional balance change.
