# Baseline Before Optimization

**Recorded**: 2026-09-06

**Godot**: 4.6.2.stable

**Scenario**: `res://test/scenarios/first_town/rebalance.json`

**Runner**: `res://scripts/run_town_rebalance.gd`

**Seed**: 6066

## Command

```bash
/usr/bin/time -lp /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/tom/Starter-Kit-City-Builder --log-file /tmp/city-builder-rebalance-baseline.log -s res://scripts/run_town_rebalance.gd
```

## Result

- Passed: yes
- Meaningful placements: 60/60
- Failed gameplay actions: 0
- Simulated hours: 240
- Residents: 145
- Total buildings: 135
- Roads: 75
- Final hour: 06:00
- Final authoritative hash: `4440de04356f95a80c7219dba3718825de1cc1b258adae28a61b7cf735fb2942`
- Wall time: 132.75 seconds
- User CPU: 128.32 seconds
- System CPU: 3.83 seconds

## Reproduced stall

At an intermediate 06:00 boundary with approximately 130 residents, the runner emitted the hourly CityStats line and then produced no further progress for more than 30 seconds. Because `DayNight` emits hour changes synchronously, this represents a player-visible main-thread freeze. The baseline runner had no per-hour timings, so the observation is a conservative lower bound.

## Profile trace

Call-path inspection identified the following repeated synchronous work:

1. `Community._run_daily_migration()` quotes 20 candidates at 06:00.
2. Each quote rebuilds all 24 hourly service-source arrays.
3. Each source calculation repeatedly resolves building-to-building routes.
4. RoadNetwork rescans/sorts building anchors and runs BFS for unchanged pairs.
5. Every hourly Community summary builds a full compact spatial snapshot.
6. Every Playtest action builds a full post-action game snapshot.

The after benchmark must use this exact scenario and seed and preserve the final state hash.
