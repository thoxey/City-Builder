extends GutTest

func test_housing_migration_composition_and_drivers_match_snapshot() -> void:
	var model := CommunityUITestFixtures.model(2, 5)
	var overview: Dictionary = model["overview"]
	assert_eq(overview["occupied_homes"], 2); assert_eq(overview["free_homes"], 3); assert_eq(overview["migration"]["net"], 2)
	assert_eq(overview["composition"]["outlooks"][0]["count"] + overview["composition"]["outlooks"][1]["count"], 2)
	assert_eq(overview["positive_drivers"][0]["source_display_name"], "Duck Pond")
	assert_eq(overview["negative_drivers"][0]["source_display_name"], "Nightclub")

func test_empty_state_does_not_render_zero_scores_as_failure() -> void:
	var model := CommunityInspector.project(CommunityUITestFixtures.snapshot(0, 0), CommunityUITestFixtures.context(), {"hour": 0}, CommunityUITestFixtures.config())
	assert_not_null(model["overview"]["empty_state"])
	for quality in model["overview"]["qualities"]: assert_eq(quality["status"], "empty")

func test_full_capacity_is_distinct_warning() -> void:
	var source := CommunityUITestFixtures.snapshot(2, 2); source["migration"]["rejections"] = 3
	var warnings: Array = CommunityInspector.project(source, CommunityUITestFixtures.context(), {"hour": 23}, CommunityUITestFixtures.config())["overview"]["warnings"]
	assert_true(warnings.any(func(row): return row["kind"] == "no_capacity"))
	assert_true(warnings.any(func(row): return row["kind"] == "rejections"))

func test_retention_hour_23_is_at_risk_and_has_one_hour_remaining() -> void:
	var source := CommunityUITestFixtures.snapshot(1, 2); source["residents"][0]["below_departure_hours"] = 23
	var retention: Dictionary = CommunityInspector.project(source, CommunityUITestFixtures.context(), {"hour": 23}, CommunityUITestFixtures.config())["residents"][0]["retention"]
	assert_eq(retention["state"], "at_risk"); assert_eq(retention["hours_remaining"], 1); assert_almost_eq(retention["progress"], 23.0 / 24.0, 0.0001)

func test_notification_batches_are_bounded_and_coalesced() -> void:
	var panel := CommunityPanel.new(); add_child(panel)
	panel._build_shell()
	for id in 12: panel._on_notification("arrival", id + 1, "Resident arrived")
	panel._flush_notifications()
	assert_eq(panel._notifications.size(), 1); assert_true(String(panel._notifications[0]).contains("12 arrival events"))
	panel.queue_free()
