extends RefCounted
class_name CityStatSink

## Base class for city simulation demand consumers.
## Extend this in a building-type plugin to request resources each in-game hour.
##
## Example:
##   class _WorkplaceSink extends CityStatSink:
##       func get_type_id() -> String: return "workers"
##       func tick(hour: float) -> int: return capacity if _open(hour) else 0
##       func on_fulfilled(fulfilled: int, requested: int) -> void:
##           satisfaction = float(fulfilled) / float(requested)

## The resource category this sink consumes (must match a CityStatSource type_id).
func get_type_id() -> String:
	return ""

## Called once per in-game hour. Return how many units are needed this hour.
func tick(_hour: float) -> int:
	return 0

## Called after matching. fulfilled ≤ requested.
## Override to react to under/over supply (update visuals, log, etc).
func on_fulfilled(_fulfilled: int, _requested: int) -> void:
	pass
