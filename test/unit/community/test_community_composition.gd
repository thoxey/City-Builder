extends GutTest

func _cohort(id: String, lens: String, weight: float) -> Dictionary:
	var row := {"identity": 0.1, "freedom": 0.1, "care": 0.1}
	row[lens] = 0.8
	return {
		"cohort_id": id,
		"quality_importance_centre": {"opportunity": 0.25, "liveability": 0.25, "beauty": 0.25, "belonging": 0.25},
		"manifestation_centre": {"opportunity": row, "liveability": row, "beauty": row, "belonging": row},
		"variation": 0.05,
		"candidate_weight": weight,
	}

func test_authored_cohort_extremes_still_generate_individual_variation() -> void:
	var generator := CommunityPersonalityGenerator.new([_cohort("identity", "identity", 1.0)])
	var first := generator.generate(1, 1)
	var second := generator.generate(2, 2)
	assert_gt(first.manifestation_weights["belonging"]["identity"], first.manifestation_weights["belonging"]["freedom"])
	assert_ne(first.manifestation_weights, second.manifestation_weights)

func test_candidate_weights_change_frequency_without_approval_state() -> void:
	var generator := CommunityPersonalityGenerator.new([
		_cohort("identity", "identity", 9.0),
		_cohort("freedom", "freedom", 1.0),
	])
	var identity_count := 0
	for seed in 200:
		var resident := generator.generate(seed + 1, seed + 1)
		if resident.cohort_id == "identity": identity_count += 1
		assert_false(resident.to_dict().has("cohort_approval"))
		assert_false(resident.to_dict().has("diversity_bonus"))
	assert_gt(identity_count, 150)

func test_same_candidate_stream_prefers_compatible_town_over_nuisance_town() -> void:
	var generator := CommunityPersonalityGenerator.new([
		_cohort("identity", "identity", 1.0),
		_cohort("freedom", "freedom", 1.0),
	])
	var matched_sources := [{"building_id": "amenities", "anchor": Vector2i.ZERO, "active": true, "effects": [
		CommunityEffectProfile.normalize_effect({"effect_id": "jobs", "quality": "opportunity", "manifestation": "neutral", "amount": 18.0, "scope": "city"}),
		CommunityEffectProfile.normalize_effect({"effect_id": "social", "quality": "belonging", "manifestation": "freedom", "amount": 18.0, "scope": "city"}),
		CommunityEffectProfile.normalize_effect({"effect_id": "heritage", "quality": "beauty", "manifestation": "identity", "amount": 18.0, "scope": "city"}),
	]}]
	var nuisance_sources := [{"building_id": "nuisance", "anchor": Vector2i.ZERO, "active": true, "effects": [
		CommunityEffectProfile.normalize_effect({"effect_id": "pollution", "quality": "liveability", "manifestation": "neutral", "amount": -20.0, "scope": "city"}),
		CommunityEffectProfile.normalize_effect({"effect_id": "blight", "quality": "beauty", "manifestation": "neutral", "amount": -15.0, "scope": "city"}),
	]}]
	var matched_arrivals := 0
	var nuisance_arrivals := 0
	for seed in 28:
		var candidate := generator.generate(1000 + seed, seed + 1)
		var matched := CommunityEffectEvaluator.evaluate(candidate, matched_sources)
		var nuisance := CommunityEffectEvaluator.evaluate(candidate, nuisance_sources)
		if _target_composite(candidate, matched) >= 60.0: matched_arrivals += 1
		if _target_composite(candidate, nuisance) >= 60.0: nuisance_arrivals += 1
	assert_gt(matched_arrivals, nuisance_arrivals)
	assert_eq(nuisance_arrivals, 0)

func _target_composite(resident: CommunityResident, evaluated: Dictionary) -> float:
	var total := 0.0
	for quality in CommunityConstants.QUALITIES:
		total += clampf(50.0 + float(evaluated["totals"].get(quality, 0.0)), 0.0, 100.0) * float(resident.quality_importance[quality])
	return total
