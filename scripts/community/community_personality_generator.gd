extends RefCounted
class_name CommunityPersonalityGenerator

var cohorts: Array = []
var version: int = 1
var sensitivity_min: float = 0.75
var sensitivity_max: float = 1.25

func _init(cohort_records: Array = [], generation_version: int = 1, min_sensitivity: float = 0.75, max_sensitivity: float = 1.25) -> void:
	cohorts = cohort_records.duplicate(true)
	version = generation_version
	sensitivity_min = min_sensitivity
	sensitivity_max = max_sensitivity

func generate(seed: int, resident_id: int, forced_cohort_id: String = "") -> CommunityResident:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var cohort := _select_cohort(rng, forced_cohort_id)
	var resident := CommunityResident.new()
	resident.resident_id = resident_id
	resident.seed = seed
	resident.cohort_id = cohort.get("cohort_id")
	var variation := maxf(0.0, float(cohort.get("variation", 0.0)))
	resident.quality_importance = _perturb(cohort.get("quality_importance_centre", {}), CommunityConstants.QUALITIES, variation, rng)
	var centres: Dictionary = cohort.get("manifestation_centre", {})
	for quality in CommunityConstants.QUALITIES:
		resident.manifestation_weights[quality] = _perturb(centres.get(quality, {}), CommunityConstants.LENSES, variation, rng)
	for sensitivity in resident.sensitivities:
		resident.sensitivities[sensitivity] = rng.randf_range(sensitivity_min, sensitivity_max)
	resident.composite_happiness = 50.0
	return resident

func _select_cohort(rng: RandomNumberGenerator, forced_id: String) -> Dictionary:
	if not forced_id.is_empty():
		for cohort in cohorts:
			if String(cohort.get("cohort_id", "")) == forced_id:
				return cohort
	if cohorts.is_empty():
		return {"cohort_id": "general", "variation": 0.0}
	var total := 0.0
	for cohort in cohorts:
		total += maxf(0.0, float(cohort.get("candidate_weight", 0.0)))
	if total <= 0.0:
		return cohorts[0]
	var pick := rng.randf() * total
	for cohort in cohorts:
		pick -= maxf(0.0, float(cohort.get("candidate_weight", 0.0)))
		if pick <= 0.0:
			return cohort
	return cohorts.back()

func _perturb(centre: Dictionary, keys: Array, variation: float, rng: RandomNumberGenerator) -> Dictionary:
	var values := {}
	for key in keys:
		values[key] = maxf(0.0001, float(centre.get(key, 1.0)) + rng.randf_range(-variation, variation))
	return CommunityConstants.normalized(values, keys, 1.0)
