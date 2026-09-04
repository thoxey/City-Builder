extends GutTest

func test_place_lists_only_actual_housed_affected_and_participating_residents() -> void:
	var places: Dictionary = CommunityUITestFixtures.model()["places"]
	var pond: Dictionary = places["1,0"]; var club: Dictionary = places["2,0"]
	assert_eq(pond["housed_resident_ids"], []); assert_eq(pond["affected_resident_ids"], [1, 2])
	assert_eq(club["participating_resident_ids"], [1, 2])

func test_place_preserves_radius_capacity_scope_and_schedule() -> void:
	var places: Dictionary = CommunityUITestFixtures.model()["places"]
	assert_has(places["1,0"]["radii"], 2); assert_has(places["2,0"]["capacities"], 60)
	assert_eq(places["2,0"]["authored_effects"][0]["scope"], "local")
	assert_eq(places["2,0"]["authored_effects"][0]["schedule_label"], "21:00–04:00")

func test_overnight_schedule_is_inactive_at_exclusive_end_hour() -> void:
	var model := CommunityUITestFixtures.model(2, 5, 4)
	assert_false(model["places"]["2,0"]["authored_effects"][0]["active_now"])

func test_neighbourhood_is_derived_from_home_anchor() -> void:
	var neighbourhood: Dictionary = CommunityUITestFixtures.model()["neighbourhoods"]["0,0"]
	assert_eq(neighbourhood["resident_count"], 2); assert_eq(neighbourhood["resident_ids"], [1, 2]); assert_almost_eq(neighbourhood["average_qualities"]["beauty"], 70.0, 0.001)

func test_programme_options_are_authored_previews() -> void:
	var option: Dictionary = CommunityUITestFixtures.model()["places"]["2,0"]["available_programmes"][0]
	assert_eq(option["programme_id"], "rock_nights"); assert_true(String(option["theme"]).contains("individual outcomes"))
