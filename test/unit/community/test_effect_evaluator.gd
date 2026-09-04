extends GutTest

func _resident(identity: float, freedom: float, care: float) -> CommunityResident:
	var resident := CommunityResident.new()
	resident.resident_id = 1
	resident.home_anchor = Vector2i.ZERO
	resident.manifestation_weights["belonging"] = {"identity": identity, "freedom": freedom, "care": care}
	return resident

func _effect(effect_id: String, amount: float, manifestation: String = "neutral", scope: String = "city") -> Dictionary:
	return CommunityEffectProfile.normalize_effect({
		"effect_id": effect_id, "quality": "belonging", "manifestation": manifestation,
		"amount": amount, "scope": scope, "radius": 2 if scope == "local" else null,
		"stacking_group": "test", "reason": effect_id,
	})

func test_tagged_and_neutral_formulas_are_exact() -> void:
	var resident := _resident(0.8, 0.1, 0.1)
	resident.sensitivities["noise"] = 1.25
	var tagged := CommunityEffectEvaluator.apply_effect(resident, {"building_id": "theatre", "anchor": Vector2i.ZERO}, _effect("play", 8.0, "identity"))
	assert_almost_eq(tagged["preference_multiplier"], 1.7, 0.0001)
	assert_almost_eq(tagged["applied_amount"], 13.6, 0.0001)
	var neutral := _effect("noise", -10.0)
	neutral["sensitivity"] = "noise"
	var nuisance := CommunityEffectEvaluator.apply_effect(resident, {"building_id": "club", "anchor": Vector2i.ZERO}, neutral)
	assert_eq(nuisance["preference_multiplier"], 1.0)
	assert_almost_eq(nuisance["applied_amount"], -12.5, 0.0001)

func test_identity_and_freedom_residents_rank_programmes_oppositely() -> void:
	var identity := _resident(0.8, 0.1, 0.1)
	var freedom := _resident(0.1, 0.8, 0.1)
	var source := {"building_id": "theatre", "anchor": Vector2i.ZERO, "active": true, "participants": [1], "effects": [_effect("plays", 8.0, "identity"), _effect("rock", 8.0, "freedom")]}
	var i_eval := CommunityEffectEvaluator.evaluate(identity, [source], {"hour": 20})
	var f_eval := CommunityEffectEvaluator.evaluate(freedom, [source], {"hour": 20})
	assert_gt(i_eval["effects"][0]["applied_amount"], i_eval["effects"][1]["applied_amount"])
	assert_gt(f_eval["effects"][1]["applied_amount"], f_eval["effects"][0]["applied_amount"])

func test_radius_schedule_and_participation_boundaries() -> void:
	var resident := _resident(0.3, 0.4, 0.3)
	var local := _effect("noise", -8.0, "neutral", "local")
	local["schedule"] = {"start": 21, "end": 4}
	var source := {"building_id": "club", "anchor": Vector2i(2, 0), "active": true, "participants": [], "effects": [local]}
	assert_true(CommunityEffectEvaluator.applies(local, resident, source, {"hour": 21}))
	assert_true(CommunityEffectEvaluator.applies(local, resident, source, {"hour": 3}))
	assert_false(CommunityEffectEvaluator.applies(local, resident, source, {"hour": 4}))
	resident.home_anchor = Vector2i(5, 0)
	assert_false(CommunityEffectEvaluator.applies(local, resident, source, {"hour": 21}))

func test_stacking_is_deterministic_and_diminishing() -> void:
	var resident := _resident(0.3, 0.4, 0.3)
	var sources := [
		{"building_id": "c", "anchor": Vector2i(2, 0), "active": true, "effects": [_effect("third", 4.0)]},
		{"building_id": "a", "anchor": Vector2i(0, 0), "active": true, "effects": [_effect("first", 8.0)]},
		{"building_id": "b", "anchor": Vector2i(1, 0), "active": true, "effects": [_effect("second", 6.0)]},
	]
	var evaluated := CommunityEffectEvaluator.evaluate(resident, sources)
	assert_eq(evaluated["effects"][0]["stacking_multiplier"], 1.0)
	assert_eq(evaluated["effects"][1]["stacking_multiplier"], 0.5)
	assert_eq(evaluated["effects"][2]["stacking_multiplier"], 0.25)
	assert_almost_eq(evaluated["totals"]["belonging"], 12.0, 0.0001)

func test_smoothing_clamping_and_composite() -> void:
	var resident := _resident(0.3, 0.4, 0.3)
	resident.quality_importance = {"opportunity": 1.0, "liveability": 0.0, "beauty": 0.0, "belonging": 0.0}
	CommunityEffectEvaluator.update_qualities(resident, {"totals": {"opportunity": 100.0}, "effects": []}, 50.0, 0.1)
	assert_eq(resident.target_qualities["opportunity"], 100.0)
	assert_almost_eq(resident.current_qualities["opportunity"], 55.0, 0.0001)
	assert_almost_eq(resident.composite_happiness, 55.0, 0.0001)
