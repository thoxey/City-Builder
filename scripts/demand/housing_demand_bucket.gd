extends DemandBucket
class_name HousingDemandBucket

## Housing demand — monotonically non-decreasing between ticks.
## Grows at `desirability × growth_rate` per tick, but can't exceed the cap
## `desirability × max_cap`. Desirability is both the rate multiplier and
## the ceiling — a low-desirability town accumulates housing demand slowly
## AND tops out early.
##
## The floor is the previous tick's value so a drop in desirability only
## slows growth; towns never shrink (the cap only gates *growth*, it doesn't
## claw back already-accumulated demand if desirability later drops).
## Player-driven spending via DemandPlugin.try_spend is a separate path that
## may reduce the value within a tick — the floor resets each tick, so the
## spend is respected.
##
## Input read from context:
##   desirability: float (0..1)

var growth_rate: float = 0.5
## Desirability=1.0 pins the cap here; desirability=0.5 pins it at half.
## Mad high on purpose for M1 — rebalance when real buildings exist to fill it.
var max_cap: float = 1000.0

func _init() -> void:
	super("housing_demand", 1.0)

func tick(hour: float, context: Dictionary) -> void:
	# Lock the floor to the current value before compute — the base clamp then
	# ensures we never regress below it, regardless of what _compute returns.
	floor_value = value
	super.tick(hour, context)

func _compute(context: Dictionary) -> float:
	var desirability: float = context.get("desirability", 0.0)
	var cap := desirability * max_cap
	if value >= cap:
		return value  # at/above cap — no growth, floor holds
	return min(value + desirability * growth_rate, cap)
