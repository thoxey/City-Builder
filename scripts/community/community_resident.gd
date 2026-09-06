extends RefCounted
class_name CommunityResident

const DEFAULT_SENSITIVITIES := {"noise": 1.0, "pollution": 1.0, "crowding": 1.0, "travel": 1.0}

var resident_id: int = 0
var seed: int = 0
var cohort_id: Variant = null
var home_anchor: Variant = null
var quality_importance: Dictionary = {}
var manifestation_weights: Dictionary = {}
var sensitivities: Dictionary = {}
var current_qualities: Dictionary = {}
var target_qualities: Dictionary = {}
var composite_happiness: float = 50.0
var below_departure_hours: int = 0
var homeless_hours: int = 0
var work_assignment: Variant = null
var activity_assignment: Variant = null
var applied_effects: Array = []

func _init() -> void:
	quality_importance = CommunityConstants.normalized({}, CommunityConstants.QUALITIES, 1.0)
	for quality in CommunityConstants.QUALITIES:
		manifestation_weights[quality] = CommunityConstants.normalized({}, CommunityConstants.LENSES, 1.0)
		current_qualities[quality] = 50.0
		target_qualities[quality] = 50.0
	sensitivities = DEFAULT_SENSITIVITIES.duplicate(true)

static func from_dict(data: Dictionary) -> CommunityResident:
	var resident := CommunityResident.new()
	resident.resident_id = int(data.get("resident_id", 0))
	resident.seed = int(data.get("seed", 0))
	resident.cohort_id = data.get("cohort_id")
	resident.home_anchor = CommunityConstants.coordinate(data.get("home_anchor"))
	resident.quality_importance = CommunityConstants.normalized(data.get("quality_importance", {}), CommunityConstants.QUALITIES, 1.0)
	var weights: Dictionary = data.get("manifestation_weights", {})
	for quality in CommunityConstants.QUALITIES:
		resident.manifestation_weights[quality] = CommunityConstants.normalized(weights.get(quality, {}), CommunityConstants.LENSES, 1.0)
	resident.sensitivities = DEFAULT_SENSITIVITIES.duplicate(true)
	for key in resident.sensitivities:
		resident.sensitivities[key] = clampf(float(data.get("sensitivities", {}).get(key, 1.0)), 0.0, 4.0)
	for quality in CommunityConstants.QUALITIES:
		resident.current_qualities[quality] = clampf(float(data.get("current_qualities", {}).get(quality, 50.0)), 0.0, 100.0)
		resident.target_qualities[quality] = clampf(float(data.get("target_qualities", {}).get(quality, 50.0)), 0.0, 100.0)
	resident.composite_happiness = clampf(float(data.get("composite_happiness", 50.0)), 0.0, 100.0)
	resident.below_departure_hours = maxi(0, int(data.get("below_departure_hours", 0)))
	resident.homeless_hours = maxi(0, int(data.get("homeless_hours", 0)))
	resident.work_assignment = data.get("work_assignment")
	resident.activity_assignment = data.get("activity_assignment")
	resident.applied_effects = data.get("applied_effects", []).duplicate(true)
	return resident

func to_dict(include_effects: bool = true, effect_limit: int = 12) -> Dictionary:
	var result := {
		"resident_id": resident_id,
		"seed": seed,
		"cohort_id": cohort_id,
		"home_anchor": CommunityConstants.coordinate_record(home_anchor),
		"quality_importance": CommunityConstants.rounded_map(quality_importance),
		"manifestation_weights": CommunityConstants.rounded_map(manifestation_weights),
		"sensitivities": CommunityConstants.rounded_map(sensitivities),
		"current_qualities": CommunityConstants.rounded_map(current_qualities),
		"target_qualities": CommunityConstants.rounded_map(target_qualities),
		"composite_happiness": CommunityConstants.rounded(composite_happiness),
		"below_departure_hours": below_departure_hours,
		"homeless_hours": homeless_hours,
		"work_assignment": _json_safe(work_assignment),
		"activity_assignment": _json_safe(activity_assignment),
	}
	if include_effects:
		result["applied_effects"] = []
		for effect in applied_effects.slice(0, effect_limit):
			result["applied_effects"].append(_json_safe(effect))
	return result

## Updates the durable DataMap projection without replacing its nested
## dictionaries every hour. The live resident remains the sole authority.
func write_persistence_dict(target: Dictionary = {}) -> Dictionary:
	target["resident_id"] = resident_id
	target["seed"] = seed
	target["cohort_id"] = cohort_id
	target["home_anchor"] = CommunityConstants.coordinate_record(home_anchor)
	target["quality_importance"] = _write_rounded_map(target.get("quality_importance", {}), quality_importance)
	target["manifestation_weights"] = _write_rounded_map(target.get("manifestation_weights", {}), manifestation_weights)
	target["sensitivities"] = _write_rounded_map(target.get("sensitivities", {}), sensitivities)
	target["current_qualities"] = _write_rounded_map(target.get("current_qualities", {}), current_qualities)
	target["target_qualities"] = _write_rounded_map(target.get("target_qualities", {}), target_qualities)
	target["composite_happiness"] = CommunityConstants.rounded(composite_happiness)
	target["below_departure_hours"] = below_departure_hours
	target["homeless_hours"] = homeless_hours
	target["work_assignment"] = _json_safe(work_assignment)
	target["activity_assignment"] = _json_safe(activity_assignment)
	target.erase("applied_effects")
	return target

static func _write_rounded_map(target: Dictionary, values: Dictionary) -> Dictionary:
	var keys := values.keys(); keys.sort()
	for key in keys:
		var value: Variant = values[key]
		if value is Dictionary:
			target[str(key)] = _write_rounded_map(target.get(str(key), {}), value)
		elif value is float:
			target[str(key)] = CommunityConstants.rounded(value)
		else:
			target[str(key)] = value
	return target

static func _json_safe(value: Variant) -> Variant:
	if value is Vector2i or value is Vector3i:
		return CommunityConstants.coordinate_record(value)
	if value is Dictionary:
		var result := {}
		for key in value:
			result[str(key)] = _json_safe(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_json_safe(item))
		return result
	return CommunityConstants.rounded(value) if value is float else value
