extends GutTest

func test_500_resident_projection_meets_frame_budget() -> void:
	var source := CommunityUITestFixtures.snapshot(500, 500)
	for resident in source["residents"]:
		resident["applied_effects"] = []
	# The frame-budget gate measures the aggregate/list projection used by the
	# overview and scrolling path. Detailed place joins are exercised separately.
	var previous := CommunityInspector.project(source, {}, {"hour": 22, "absolute_hour": 22}, CommunityUITestFixtures.config())
	var started := Time.get_ticks_usec()
	var model := CommunityInspector.project(source, {}, {"hour": 23, "absolute_hour": 23}, CommunityUITestFixtures.config(), previous)
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	gut.p("COMMUNITY_UI_PERF projection_500_ms=%.3f" % elapsed_ms)
	assert_eq(model["residents"].size(), 500); assert_lt(elapsed_ms, 16.7)

func test_resident_controls_are_bounded_to_page_size() -> void:
	var panel := CommunityPanel.new(); panel._model = CommunityUITestFixtures.model(500, 500)
	assert_eq(panel.get_live_row_count(), CommunityPanel.PAGE_SIZE); panel.free()

func test_projection_is_not_driven_from_process() -> void:
	var source := FileAccess.get_file_as_string("res://plugins/community/community_panel.gd")
	assert_false(source.contains("func _process")); assert_true(source.contains("call_deferred(\"_perform_refresh\")"))
