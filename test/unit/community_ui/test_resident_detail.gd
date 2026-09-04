extends GutTest

func test_simultaneous_positive_and_negative_effects_remain_separate() -> void:
	var resident: Dictionary = CommunityUITestFixtures.model()["residents"][0]
	assert_eq(resident["positive_effects"].size(), 1); assert_eq(resident["negative_effects"].size(), 1)
	assert_gt(float(resident["positive_effects"][0]["applied_amount"]), 0.0); assert_lt(float(resident["negative_effects"][0]["applied_amount"]), 0.0)

func test_resident_has_profile_quality_personality_sensitivity_and_activity_fields() -> void:
	var resident: Dictionary = CommunityUITestFixtures.model()["residents"][0]
	assert_eq(resident["label"], "Resident #1"); assert_eq(resident["qualities"].size(), 4); assert_eq(resident["sensitivities"].size(), 4)
	assert_has(resident, "lens_weights_by_quality"); assert_not_null(resident["activity"])

func test_personality_contrast_has_distinct_outlook_labels() -> void:
	var residents: Array = CommunityUITestFixtures.model()["residents"]
	assert_ne(residents[0]["dominant_lens"], residents[1]["dominant_lens"])
	assert_ne(residents[0]["outlook_label"], residents[1]["outlook_label"])

func test_filters_combine_home_risk_outlook_and_lowest_quality() -> void:
	var panel := CommunityPanel.new(); panel._model = CommunityUITestFixtures.model(); panel._home_filter = "housed"; panel._risk_filter = "stable"; panel._outlook_filter = "identity"; panel._quality_filter = "liveability"
	assert_eq(panel.filtered_residents().size(), 1); panel.free()

func test_homeless_retention_uses_configured_relocation_grace() -> void:
	var source := CommunityUITestFixtures.snapshot(1, 2); source["residents"][0]["home_anchor"] = null; source["residents"][0]["homeless_hours"] = 7
	var config := CommunityUITestFixtures.config(); config["relocation_grace_hours"] = 12
	var retention: Dictionary = CommunityInspector.project(source, CommunityUITestFixtures.context(), {"hour": 7}, config)["residents"][0]["retention"]
	assert_eq(retention["state"], "homeless"); assert_eq(retention["hours_remaining"], 5)
