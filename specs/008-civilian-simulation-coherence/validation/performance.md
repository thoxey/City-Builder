# Civilian Performance

Date: 2026-09-06  
Reference environment: macOS, Godot 4.6.2 headless

The diagnostics-off case stepped People and CarManager for 300 samples with 512
stable visible proxy records:

| Measurement | Result |
|---|---:|
| Average combined update | 0.6558 ms |
| Maximum combined update | 0.8390 ms |
| On-demand People snapshot | 4.4620 ms |
| Target | average < 16.7 ms |

Result: **pass**. Snapshot construction is measured separately and is not part of the
ordinary per-frame update path.
