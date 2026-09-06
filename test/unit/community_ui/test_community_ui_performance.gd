extends GutTest

func test_500_resident_projection_meets_frame_budget() -> void:
	var source := CommunityUITestFixtures.snapshot(500, 500)
	for resident in source["residents"]:
		resident["applied_effects"] = []
	# The frame-budget gate measures the aggregate/list projection used by the
	# overview and scrolling path. Detailed place joins are exercised separately.
	# Warm up the script and assert the median so a scheduler interruption cannot
	# turn one otherwise healthy projection into a false regression.
	var previous := CommunityInspector.project(source, {}, {"hour": 22, "absolute_hour": 22}, CommunityUITestFixtures.config())
	for warmup_index in range(3):
		previous = CommunityInspector.project(source, {}, {"hour": 23, "absolute_hour": 23 + warmup_index}, CommunityUITestFixtures.config(), previous)
	var samples_usec: Array[int] = []
	var model: Dictionary = previous
	for sample_index in range(7):
		var started := Time.get_ticks_usec()
		model = CommunityInspector.project(source, {}, {"hour": 2, "absolute_hour": 26 + sample_index}, CommunityUITestFixtures.config(), previous)
		samples_usec.append(Time.get_ticks_usec() - started)
		previous = model
	samples_usec.sort()
	var median_ms := float(samples_usec[samples_usec.size() / 2]) / 1000.0
	gut.p("COMMUNITY_UI_PERF projection_500_median_ms=%.3f samples_usec=%s" % [median_ms, samples_usec])
	assert_eq(model["residents"].size(), 500); assert_lt(median_ms, 16.7)

func test_resident_controls_are_bounded_to_page_size() -> void:
	var panel := CommunityPanel.new(); panel._model = CommunityUITestFixtures.model(500, 500)
	assert_eq(panel.get_live_row_count(), CommunityPanel.PAGE_SIZE); panel.free()

func test_projection_is_not_driven_from_process() -> void:
	var source := FileAccess.get_file_as_string("res://plugins/community/community_panel.gd")
	assert_false(source.contains("func _process")); assert_true(source.contains("call_deferred(\"_perform_refresh\")"))
