extends GutTest

func test_resident_round_trip_is_json_safe_and_normalized() -> void:
	var resident := CommunityResident.new()
	resident.resident_id = 7
	resident.seed = 99
	resident.home_anchor = Vector2i(3, -2)
	resident.quality_importance = CommunityConstants.normalized({"opportunity": 2.0, "liveability": 1.0}, CommunityConstants.QUALITIES)
	resident.current_qualities["beauty"] = 44.123456
	var record := resident.to_dict()
	assert_eq(record["home_anchor"], {"x": 3, "z": -2})
	assert_eq(record["current_qualities"]["beauty"], 44.1235)
	var total := 0.0
	for value in record["quality_importance"].values(): total += value
	assert_almost_eq(total, 1.0, 0.0002)
	var restored := CommunityResident.from_dict(record)
	assert_eq(restored.resident_id, 7)
	assert_eq(restored.home_anchor, Vector2i(3, -2))

func test_invalid_vectors_fall_back_to_even_rows() -> void:
	var resident := CommunityResident.from_dict({
		"quality_importance": {"opportunity": -2.0},
		"manifestation_weights": {"beauty": {"identity": 0.0, "freedom": 0.0, "care": 0.0}},
	})
	assert_eq(resident.quality_importance["opportunity"], 0.0)
	assert_almost_eq(resident.quality_importance["liveability"], 1.0 / 3.0, 0.0001)
	assert_almost_eq(resident.manifestation_weights["beauty"]["care"], 1.0 / 3.0, 0.0001)

func test_effect_profile_rejects_invalid_enums_and_local_without_radius() -> void:
	assert_true(CommunityEffectProfile.normalize_effect({"effect_id": "bad", "quality": "fun", "manifestation": "neutral", "scope": "city"}).is_empty())
	assert_true(CommunityEffectProfile.normalize_effect({"effect_id": "bad", "quality": "beauty", "manifestation": "neutral", "scope": "local"}).is_empty())
	assert_false(CommunityEffectProfile.normalize_effect({"effect_id": "ok", "quality": "beauty", "manifestation": "neutral", "scope": "local", "radius": 2, "amount": 3}).is_empty())
