# Baseline Before Tutorial Implementation

**Date**: 2026-09-06

The combined Dashboard, Dialogue, EventSystem, Demand, Community, Traffic, progression,
and dialogue-integration baseline ran headlessly with a writable temporary HOME.

```text
Scripts: 45
Tests: 238
Passing: 237
Failing: 1
Asserts: 2014
```

The sole failure predates tutorial implementation:

```text
test/unit/community/test_early_quality_balance.gd
test_ordinary_mixed_early_town_improves_liveability_beauty_and_belonging
line 74: 58.5888465312825 expected > 60.0
line 75: 53.6809342276925 expected > 54.0
```

The failing content/balance assertion belongs to unrelated existing working-tree changes
and is not a tutorial acceptance exception. It must be rechecked at release and must not
mask any introduced tutorial failure. Full log: `/tmp/city-builder-tutorial-baseline.log`.
