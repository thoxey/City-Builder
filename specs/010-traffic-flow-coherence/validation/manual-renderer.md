# Normal-Renderer Observation — Open Manual Gate

Status: **OPEN — not observed during this implementation run**.

No screenshot or observer note is claimed. Headless deterministic, integration,
diagnostic, and performance tests cannot establish final mesh appearance, camera
occlusion, perceived jitter, clipping, or queue readability in the normal renderer.

Run the game at 1920x1080 with the normal renderer and preserve screenshots/notes for:

- four same-origin departures: exactly two cars appear and two residents remain visible
  while pending;
- a long downstream blockage: cars remain on-road, distinct, and present without
  teleporting, rerouting, or disappearing;
- release of one capacity claim: exactly the next FIFO departure becomes visible;
- a corner and junction: current/next claim interpolation stays visually within the
  road and does not visibly snap through another car;
- opposing traffic: two-total capacity is respected and lane positions remain distinct;
- grouped and opposing pedestrians: proxies remain distinct, pavement-relative, and
  free of visible bunching or oscillation.

A longer full traffic simulation is also still required to judge network-wide queue
propagation, sustained junction throughput/fairness, and emergent gridlock recovery.
Those are visual/scale limitations of the automated fixtures, not failed assertions.
