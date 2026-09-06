# Performance Gate

Captured 2026-09-06 on the reference development machine during the complete unit
suite. The fixture holds 512 visible People proxies while also maintaining 256 active
cars, 128 pending departures, 256 capacity-blocked queues, and 128 walkers.

| Measurement | Result |
|---|---:|
| Samples | 300 |
| Combined CarManager + People average update | 5.0902 ms |
| Combined maximum sampled update | 6.0080 ms |
| Frame target | 16.7 ms average |
| Car traffic diagnostic projection | 14.1370 ms |
| Full People diagnostic projection | 18.9460 ms |

The combined presentation update passes SC-009 with 11.6098 ms of average-frame
headroom. Diagnostics are deliberately measured outside the update timing and are not
called per frame. The full People projection exceeds one frame in this synthetic
maximum-load fixture, so tooling must continue to request it on demand rather than
turning it into a per-frame path.

For comparison, the non-traffic 512-proxy test in the same run averaged 1.2448 ms,
peaked at 1.4710 ms, and took 4.3010 ms for its diagnostic snapshot.
