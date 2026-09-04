# Community Performance Validation

Date: 2026-09-04  
Godot: 4.6.2.stable.official.71f334935  
Machine: local development Mac

Command:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path . --log-file /tmp/community-performance-gut.log \
  -s addons/gut/gut_cmdln.gd \
  -gtest=res://test/unit/community/test_community_performance.gd -gexit
```

Result: 500 persistent residents completed 168 exact hourly Community ticks in
approximately 2.84 seconds, including quality updates, retention evaluation,
persistence projection, aggregate signals, and daily migration-capacity checks.
The test passed the required under-10-second limit.

Full resident snapshots are capped at 500 records and per-resident/effect
summaries are bounded by authored balance limits. Compact snapshots retain only
aggregates and omit the resident array.
