extends Node

## Simulation clock — decoupled from render frames.
## Plugins connect to `tick` for simulation-time updates.
## Use tick_number % N == 0 to sample every N ticks without a local counter.

signal tick(tick_number: int)

var ticks_per_second: float = 1.0
var tick_number: int = 0
var paused: bool = false

var _accumulator: float = 0.0

func _process(delta: float) -> void:
	if paused:
		return
	_accumulator += delta
	var interval := 1.0 / ticks_per_second
	# Use while to avoid missing ticks when framerate dips
	while _accumulator >= interval:
		_accumulator -= interval
		tick_number += 1
		tick.emit(tick_number)
