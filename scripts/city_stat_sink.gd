extends RefCounted
class_name CityStatSink

## Base class for city simulation demand consumers.
## Extend this in a building-type plugin to request resources each in-game hour.
##
## priority: lower value = fulfilled first within a tick.
##   Recommended bands: critical=0, workers=10, leisure=100.

## Fulfilment priority — lower = served before higher values in the same tick.
var priority: int = 0

## The resource category this sink consumes (must match a CityStatSource type_id).
func get_type_id() -> String:
	return ""

## Called once per in-game hour. Return how many units are needed this hour.
func tick(_hour: float) -> int:
	return 0

## Called after matching. fulfilled ≤ requested.
## Override to react to under/over supply.
func on_fulfilled(_fulfilled: int, _requested: int) -> void:
	pass

## Returns true when hour falls in [start, end).
## Wraps midnight when end < start (e.g. 22:00–02:00).
func _in_window(hour: float, start: float, end: float) -> bool:
	if end >= start:
		return hour >= start and hour < end
	return hour >= start or hour < end
