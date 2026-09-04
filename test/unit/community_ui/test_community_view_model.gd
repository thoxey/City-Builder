extends GutTest

func test_projection_contains_contract_shape_and_four_ordered_qualities() -> void:
	var model := CommunityUITestFixtures.model()
	assert_has(model, "summary"); assert_has(model, "overview"); assert_has(model, "residents"); assert_has(model, "places"); assert_has(model, "neighbourhoods")
	assert_eq(model["overview"]["qualities"].map(func(row): return row["quality_id"]), CommunityConstants.QUALITIES)

func test_projection_is_immutable_and_hides_seed_from_default_rows() -> void:
	var source := CommunityUITestFixtures.snapshot()
	var before := source.duplicate(true)
	var model := CommunityInspector.project(source, CommunityUITestFixtures.context(), {"hour": 23}, CommunityUITestFixtures.config())
	assert_eq(source, before)
	assert_does_not_have(model["residents"][0], "seed")
	assert_does_not_have(model["residents"][0], "quality_importance")

func test_effect_rows_preserve_required_provenance_and_sign() -> void:
	var resident: Dictionary = CommunityUITestFixtures.model()["residents"][0]
	assert_eq(resident["positive_effects"].size(), 1)
	assert_eq(resident["negative_effects"].size(), 1)
	for row in resident["positive_effects"] + resident["negative_effects"]:
		for field in ["source_display_name", "quality", "manifestation", "applied_amount", "scope", "reason", "schedule_label", "active_now"]: assert_has(row, field)

func test_previous_projection_drives_presentation_only_direction_and_delta() -> void:
	var previous := CommunityUITestFixtures.model(1)
	var current := CommunityInspector.project(CommunityUITestFixtures.snapshot(2), CommunityUITestFixtures.context(), {"hour": 24}, CommunityUITestFixtures.config(), previous)
	assert_eq(current["summary"]["recent_population_delta"], 1)
	assert_eq(current["overview"]["qualities"][0]["direction"], "stable")

func test_stable_resident_and_effect_ordering() -> void:
	var source := CommunityUITestFixtures.snapshot()
	source["residents"].reverse()
	var ids: Array = CommunityInspector.project(source, CommunityUITestFixtures.context(), {"hour": 23}, CommunityUITestFixtures.config())["residents"].map(func(row): return row["resident_id"])
	assert_eq(ids, [1, 2])
