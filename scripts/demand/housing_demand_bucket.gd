extends DemandBucket
class_name HousingDemandBucket

## Residential demand — total grows monotonically, driven by city attractiveness.
##
## growth = clamp(attractiveness / saturation, 0, 1) × growth_rate
## cap    = clamp(attractiveness / saturation, 0, 1) × max_cap
##
## The saturation point is a tuning knob. Below saturation, growth scales
## linearly with city attractiveness; at and above saturation, growth runs
## at full speed and the cap pegs at max_cap.
##
## Once total_demand reaches the cap, growth halts; the base class's monotonic
## clamp keeps total_demand at peak even if attractiveness later collapses.
##
## Input read from context:
##   attractiveness: int  (city-wide sum)

var growth_rate: float = 0.5
var max_cap: float = 1000.0
## City attractiveness sum that pegs the cap and growth at full speed.
var saturation: float = 500.0

func _init() -> void:
	super("residential", 1.0)

func _compute(context: Dictionary) -> float:
	var attr: int = int(context.get("attractiveness", 0))
	var factor: float = clampf(float(attr) / max(saturation, 0.001), 0.0, 1.0)
	var cap: float = factor * max_cap
	if total_demand >= cap:
		return total_demand
	return min(total_demand + factor * growth_rate, cap)
