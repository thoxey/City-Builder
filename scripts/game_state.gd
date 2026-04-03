extends Node

## Shared game state references, populated by Builder on _ready().
## Plugins read from here; they never write — mutation goes through Builder.

var gridmap: GridMap
var structures: Array[Structure]
var map: DataMap

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
