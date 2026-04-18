extends DemandBucket
class_name IndustrialDemandBucket

## Industrial demand — tracks population.
## target = population × ratio; bucket eases toward target at adjust_rate per tick.
##
## Input read from context:
##   population: int

var ratio: float = 0.5
var adjust_rate: float = 0.25

func _init() -> void:
	super("industrial_demand", 1.0)

func _compute(context: Dictionary) -> float:
	var population: int = context.get("population", 0)
	var target := float(population) * ratio
	return value + (target - value) * adjust_rate
