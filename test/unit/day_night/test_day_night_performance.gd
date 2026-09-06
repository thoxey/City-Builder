extends GutTest

const DayNightPluginCls := preload("res://plugins/day_night/day_night_plugin.gd")

func test_profiled_advance_reports_one_ordered_sample_per_hour() -> void:
	var clock := DayNightPluginCls.new()
	clock._time = 5.0 / 24.0
	clock._last_hour = 5
	add_child(clock)
	var result: Dictionary = clock.advance_hours(3, true)
	var performance: Dictionary = result["details"]["performance"]
	assert_eq(performance["hour_timings"].size(), 3)
	assert_eq(performance["hour_timings"].map(func(row): return row["hour"]), [6, 7, 8])
	assert_eq(performance["hour_timings"].map(func(row): return row["absolute_hour"]), [1, 2, 3])
	assert_gte(performance["total_usec"], performance["max_hour_usec"])
	for sample in performance["hour_timings"]:
		assert_gte(sample["elapsed_usec"], 0)
		assert_typeof(sample["day"], TYPE_INT)
	clock.queue_free()

func test_default_advance_has_no_performance_payload() -> void:
	var clock := DayNightPluginCls.new()
	clock._time = 6.0 / 24.0
	clock._last_hour = 6
	add_child(clock)
	var result: Dictionary = clock.advance_hours(1)
	assert_does_not_have(result["details"], "performance")
	clock.queue_free()
