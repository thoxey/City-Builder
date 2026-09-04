# Deterministic Replay Validation

Date: 2026-09-04

The declared 20-candidate stream was regenerated ten times from the same seeds.
All ten arrays matched exactly, including cohort IDs, per-quality importance,
four independent lens rows, sensitivities, and rounded serialized values.

Additional deterministic assertions cover cohort weighting, effect stacking
order, source/anchor/effect tie-breaks, housing selection, resident-ID ordering,
programme schedules, and Playtest state hashes. Global `randf`, array insertion
order, and wall-clock time are not inputs to community state.

The Playtest session ID remains intentionally volatile and is already excluded
from normalized state hashes.
