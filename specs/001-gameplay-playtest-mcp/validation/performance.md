# Exact-Time Performance

Date: 2026-09-04  
Godot: 4.6.2.stable

A live `playtest_advance` request for 100 hours completed in 107 ms measured at
the local IPC caller. The outcome reported `requested_hours=100`,
`emitted_hours=100`, and `absolute_hour=100`. This is comfortably below the
10-second requirement while retaining one chronological signal per hour.
