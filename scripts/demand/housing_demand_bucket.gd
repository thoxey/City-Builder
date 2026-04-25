extends DemandBucket
class_name HousingDemandBucket

## Housing demand — total grows monotonically, capped by desirability × max_cap.
## Each tick adds `desirability × growth_rate` to total_demand, never exceeding
## the cap. If desirability later drops, total_demand stays at peak (monotonic) —
## the cap only gates *growth*.
##
## unserved = total_demand - fulfilled. The HUD bank, try_spend, and quest
## triggers all read whichever of the three numbers fits the question.
##
## Input read from context:
##   desirability: float (0..1)

var growth_rate: float = 0.5
var max_cap: float = 1000.0

func _init() -> void:
	super("housing_demand", 1.0)

func _compute(context: Dictionary) -> float:
	var desirability: float = context.get("desirability", 0.0)
	var cap := desirability * max_cap
	if total_demand >= cap:
		return total_demand
	return min(total_demand + desirability * growth_rate, cap)
