extends RefCounted
class_name PerformanceBudget

const Sample := preload("res://scripts/performance/performance_sample.gd")

const STATISTICS := [&"median", &"p95", &"max", &"each_run", &"median_fps"]
const LEVELS := [&"info", &"warning", &"error"]

var budget_id: String
var boundary: StringName
var workload_profile: String
var statistic: StringName
var threshold: float
var unit: String
var reference_environment: String
var enforcement_level: StringName
var _exclusions: Dictionary

static func create(p_id: String, p_boundary: StringName, p_profile: String,
		p_statistic: StringName, p_threshold: float, p_unit: String,
		p_environment: String, p_level: StringName, exclusions: Dictionary = {}) -> Variant:
	var value = (load("res://scripts/performance/performance_budget.gd") as GDScript).new()
	value.budget_id = p_id; value.boundary = p_boundary; value.workload_profile = p_profile
	value.statistic = p_statistic; value.threshold = p_threshold; value.unit = p_unit
	value.reference_environment = p_environment; value.enforcement_level = p_level
	value._exclusions = exclusions.duplicate(true)
	return value

func is_valid() -> bool:
	return not budget_id.is_empty() and boundary in Sample.BOUNDARIES \
		and statistic in STATISTICS and threshold >= 0.0 and enforcement_level in LEVELS

func get_exclusions() -> Dictionary: return _exclusions.duplicate(true)
