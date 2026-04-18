extends DemandBucket
class_name CommercialDemandBucket

## Commercial demand — tracks industrial OUTPUT (what workplaces actually produce),
## not industrial demand. Shops follow money flowing through the city; unstaffed
## factories produce nothing and generate no commercial demand.
##
## target = industrial_output × ratio; bucket eases toward target at adjust_rate
## per tick. The easing creates the intentional one-tick lag behind output.
##
## Input read from context:
##   industrial_output: int

var ratio: float = 0.5
var adjust_rate: float = 0.25

func _init() -> void:
	super("commercial_demand", 1.0)

func _compute(context: Dictionary) -> float:
	var output: float = float(context.get("industrial_output", 0))
	var target := output * ratio
	return value + (target - value) * adjust_rate
