extends DemandBucket
class_name IndustrialDemandBucket

## Industrial demand — total grows monotonically toward population × ratio.
## The town's *accumulated* industrial need persists even if population later
## drops; the base class's monotonic clamp prevents shrinkage.
##
## fulfilled is decremented on demolish; unserved = total - fulfilled gates the
## next placement.
##
## Input read from context:
##   population: int

var ratio: float = 0.5

func _init() -> void:
	super("industrial_demand", 1.0)

func _compute(context: Dictionary) -> float:
	var population: int = context.get("population", 0)
	return float(population) * ratio
