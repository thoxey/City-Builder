extends Node

## Shared game state references, populated by Builder on _ready().
## Plugins read from here; they never write — mutation goes through Builder.

var gridmap: GridMap
var structures: Array[Structure]
var map: DataMap

## Maps every occupied grid cell (Vector2i) to the building_id (int) that owns it.
## Includes all footprint cells — anchor and satellites.
var cell_to_building: Dictionary = {}

## Maps building_id (int) to its placement data.
## Shape: { anchor: Vector2i, structure: int, orientation: int, cells: Array }
var building_registry: Dictionary = {}

var _next_building_id: int = 0

## Monotonic runtime revision for committed gameplay state.  It deliberately
## does not live on DataMap: loading establishes a new runtime version epoch,
## while the durable gameplay fields remain the save/hash authority.
var _state_version: int = 0

var _is_ready: bool = false
var _ready_callbacks: Array[Callable] = []

## Plugins call this in their _ready() to defer until state is available.
## If state is already ready, the callback fires immediately (synchronous).
func register_ready_callback(cb: Callable) -> void:
	if _is_ready:
		cb.call()
	else:
		_ready_callbacks.append(cb)

## Called by Builder at the end of its _ready(), once all references are set.
func _notify_ready() -> void:
	_is_ready = true
	for cb in _ready_callbacks:
		cb.call()
	_ready_callbacks.clear()

func get_state_version() -> int:
	return _state_version

## Advances exactly once when the caller still holds the expected pre-version.
## A stale caller receives -1 and authority remains untouched.
func commit_state_version(expected_pre_version: int) -> int:
	if expected_pre_version != _state_version:
		return -1
	_state_version += 1
	return _state_version

## Called at fresh-map and cold-load boundaries before derived runtime rebuilds.
func reset_state_version() -> void:
	_state_version = 0
