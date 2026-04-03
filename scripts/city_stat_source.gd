extends RefCounted
class_name CityStatSource

## Base class for city simulation supply providers.
## Extend this in a building-type plugin to contribute supply each in-game hour.
##
## Example:
##   class _ResidentialSource extends CityStatSource:
##       func get_type_id() -> String: return "workers"
##       func tick(hour: float) -> int: return capacity if _active(hour) else 0

## The resource category this source supplies (e.g. "workers", "goods").
func get_type_id() -> String:
	return ""

## Called once per in-game hour. Return how many units are available this hour.
func tick(_hour: float) -> int:
	return 0
