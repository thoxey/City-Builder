extends GutTest

const Monitor := preload("res://plugins/performance/performance_monitor_plugin.gd")

func test_exceeded_boundary_is_attributed_without_failing_other_boundaries() -> void:
	var monitor = Monitor.new(); monitor.enabled = true; monitor.seed = 6066; monitor.town_id = "reference-135"
	monitor.record(&"hour.total", 10_000, {"buildings":135, "residents":140}, 1)
	monitor.record(&"hour.total", 40_000, {"buildings":135, "residents":140}, 2)
	monitor.record(&"projection.operational", 2_000, {"rows":9})
	var report: Dictionary = monitor.build_report({
		&"hour.total":{"threshold":33_300.0, "statistic":&"max"},
		&"projection.operational":{"threshold":8_000.0, "statistic":&"p95"},
	})
	assert_false(report.passed)
	assert_eq(report.failures, ["hour.total:max"])
	assert_eq(report.boundaries["hour.total"].workload_counts.buildings, 135)
	assert_true(report.boundaries["projection.operational"].passed)
	monitor.free()
