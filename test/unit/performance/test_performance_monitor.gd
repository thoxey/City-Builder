extends GutTest

const Monitor := preload("res://plugins/performance/performance_monitor_plugin.gd")

func test_disabled_monitor_records_nothing_and_nested_samples_link_parent() -> void:
	var monitor = Monitor.new()
	monitor.enabled = false
	var ignored := monitor.begin(&"hour.total")
	monitor.finish(ignored)
	assert_true(monitor.get_samples().is_empty())
	monitor.enabled = true
	var parent := monitor.begin(&"hour.total")
	var child := monitor.begin(&"hour.collect")
	monitor.finish(child)
	monitor.finish(parent)
	var samples: Array = monitor.get_samples()
	assert_eq(samples.size(), 2)
	assert_eq(String(samples[0].parent_boundary), "hour.total")
	monitor.free()

func test_report_attributes_budget_failure_to_boundary() -> void:
	var monitor = Monitor.new()
	monitor.record(&"projection.operational", 9000, {"rows": 2})
	var report: Dictionary = monitor.aggregate(&"projection.operational", 8000.0, &"max")
	assert_false(report.passed)
	assert_eq(report.boundary, "projection.operational")
	monitor.free()
