extends Node

## Pure signal bus. No state, no logic.
## Builder emits here; plugins receive from here.
## Builder never knows plugins exist.

signal structure_placed(position: Vector3i, structure_index: int, orientation: int)
signal structure_demolished(position: Vector3i)
signal map_loaded(map: DataMap)
signal satisfaction_changed(score: float)
signal demand_changed(bucket_type_id: String, value: float)
