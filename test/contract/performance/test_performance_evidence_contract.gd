extends GutTest

const Sample := preload("res://scripts/performance/performance_sample.gd")
const Budget := preload("res://scripts/performance/performance_budget.gd")
const Monitor := preload("res://plugins/performance/performance_monitor_plugin.gd")

func test_sample_and_budget_schemas_are_detached_and_validated() -> void:
	var counts := {"residents": 5}
	var sample = Sample.create(&"hour.total", 100, 20, 1, 6, -1, counts, "debug", "4.6", "host", 7, "town")
	counts.residents = 9
	assert_true(sample.is_valid())
	assert_eq(sample.get_workload_counts().residents, 5)
	var budget = Budget.create("hour-p95", &"hour.total", "town", &"p95", 16700.0, "usec", "host", &"error")
	assert_true(budget.is_valid())

func test_nearest_rank_percentiles_are_deterministic() -> void:
	assert_eq(Monitor.nearest_rank([1, 2, 3, 4, 5], 0.5), 3.0)
	assert_eq(Monitor.nearest_rank([1, 2, 3, 4, 5], 0.95), 5.0)
