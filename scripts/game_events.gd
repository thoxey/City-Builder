extends Node

## Pure signal bus. No state, no logic.
## Builder emits here; plugins receive from here.
## Builder never knows plugins exist.

signal structure_placed(position: Vector3i, structure_index: int, orientation: int)
signal structure_demolished(position: Vector3i)
signal cash_changed(new_amount: int)
signal map_loaded(map: DataMap)
signal population_updated(residential: int, commercial: int, workplace: int)
