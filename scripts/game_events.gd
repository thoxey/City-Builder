extends Node

## Pure signal bus. No state, no logic.
## Builder emits here; plugins receive from here.
## Builder never knows plugins exist.

signal structure_placed(position: Vector3i, structure_index: int, orientation: int)
signal structure_demolished(position: Vector3i)
signal map_loaded(map: DataMap)
signal satisfaction_changed(score: float)
signal demand_changed(bucket_type_id: String, value: float)
## Cash surplus changed — `amount` is the new total, `delta` is the signed change.
signal cash_changed(amount: int, delta: int)
## Palette's affordable-entry set or selection has changed.
## `entry_ids` is the ordered list of currently affordable entry ids;
## `selected_id` is the currently active entry (or "" if none affordable).
signal palette_changed(entry_ids: Array, selected_id: String)
