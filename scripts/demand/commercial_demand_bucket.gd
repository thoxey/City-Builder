extends DemandBucket
class_name CommercialDemandBucket

## Commercial demand — total grows monotonically toward industrial_output × ratio.
## Shops follow money flowing through the city; once that money has flowed,
## the accumulated commercial need persists even if output later collapses.
##
## fulfilled is decremented on demolish; unserved = total - fulfilled gates the
## next placement.
##
## Input read from context:
##   industrial_output: int

var ratio: float = 0.5

func _init() -> void:
	super("commercial_demand", 1.0)

func _compute(context: Dictionary) -> float:
	var output: float = float(context.get("industrial_output", 0))
	return output * ratio
