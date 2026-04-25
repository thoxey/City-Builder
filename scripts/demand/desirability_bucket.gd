extends DemandBucket
class_name DesirabilityBucket

## Desirability (0..1) — weighted blend of the overall satisfaction score
## and amenity coverage. Acts as a rate multiplier on housing growth; it
## never subtracts from other buckets.
##
## Non-monotonic: desirability follows live conditions and can drop.
## Fulfilled stays at 0 (desirability is a rate, not a spendable bucket),
## so unserved == total_demand.
##
## Inputs read from context:
##   satisfaction_score: float  (0..1)
##   amenity_count:      int

var weight_satisfaction: float = 0.6
var weight_amenity: float = 0.4
var amenity_saturation: float = 10.0

func _init() -> void:
	super("desirability", 100.0)
	monotonic = false  # desirability tracks live state, not accumulated need

func _compute(context: Dictionary) -> float:
	var sat: float = context.get("satisfaction_score", 1.0)
	var amenities: int = context.get("amenity_count", 0)
	var amenity_term := clampf(float(amenities) / max(amenity_saturation, 0.001), 0.0, 1.0)
	var total_weight := weight_satisfaction + weight_amenity
	if total_weight <= 0.0:
		return 0.0
	var raw := (sat * weight_satisfaction + amenity_term * weight_amenity) / total_weight
	return clampf(raw, 0.0, 1.0)
