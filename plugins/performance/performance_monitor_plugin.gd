extends PluginBase
class_name PerformanceMonitorPlugin

const Sample := preload("res://scripts/performance/performance_sample.gd")
const MAX_SAMPLES := 20000

var enabled := OS.is_debug_build()
var seed := 0
var town_id := ""
var _samples: Array = []
var _stack: Array = []

func get_plugin_name() -> String: return "PerformanceMonitor"
func get_dependencies() -> Array[String]: return []

func begin(boundary: StringName, workload_counts: Dictionary = {}, excluded_reason: String = "") -> Dictionary:
	if not enabled: return {}
	var token := {"boundary": boundary, "started_usec": Time.get_ticks_usec(),
		"parent_boundary": _stack[-1].boundary if not _stack.is_empty() else &"",
		"workload_counts": workload_counts.duplicate(true), "excluded_reason": excluded_reason}
	_stack.append(token)
	return token

func finish(token: Dictionary, absolute_hour: int = -1, frame_index: int = -1) -> Variant:
	if token.is_empty() or not enabled: return null
	if not _stack.is_empty(): _stack.pop_back()
	return record(token.boundary, Time.get_ticks_usec() - int(token.started_usec),
		token.workload_counts, absolute_hour, frame_index, token.parent_boundary, token.excluded_reason,
		int(token.started_usec))

func record(boundary: StringName, elapsed_usec: int, workload_counts: Dictionary = {},
		absolute_hour: int = -1, frame_index: int = -1, parent: StringName = &"",
		excluded_reason: String = "", started_usec: int = 0) -> Variant:
	if not enabled: return null
	var sample = Sample.create(boundary, started_usec, elapsed_usec, GameState.get_state_version(),
		absolute_hour, frame_index, workload_counts, "debug" if OS.is_debug_build() else "release",
		Engine.get_version_info().string, OS.get_name(), seed, town_id, parent, excluded_reason)
	_samples.append(sample)
	if _samples.size() > MAX_SAMPLES: _samples = _samples.slice(_samples.size() - MAX_SAMPLES)
	return sample

func get_samples() -> Array: return _samples.duplicate()
func clear() -> void: _samples.clear(); _stack.clear()

static func nearest_rank(values: Array, percentile: float) -> float:
	if values.is_empty(): return 0.0
	var ordered := values.duplicate()
	ordered.sort()
	var rank := clampi(int(ceil(percentile * ordered.size())), 1, ordered.size())
	return float(ordered[rank - 1])

func aggregate(boundary: StringName, threshold: float = 1.0e300, statistic: StringName = &"p95") -> Dictionary:
	var values: Array = []
	var exclusions := 0
	for sample in _samples:
		if sample.boundary != boundary: continue
		if not sample.excluded_reason.is_empty(): exclusions += 1; continue
		values.append(sample.elapsed_usec)
	var measured := 0.0
	match statistic:
		&"median": measured = nearest_rank(values, 0.5)
		&"p95": measured = nearest_rank(values, 0.95)
		&"max": measured = float(values.max()) if not values.is_empty() else 0.0
		_: measured = nearest_rank(values, 0.95)
	return {"boundary":String(boundary), "statistic":String(statistic), "value":measured,
		"threshold":threshold, "passed":measured <= threshold, "sample_count":values.size(),
		"excluded_count":exclusions, "median":nearest_rank(values, 0.5),
		"p95":nearest_rank(values, 0.95), "max":float(values.max()) if not values.is_empty() else 0.0}

func build_report(gates: Dictionary) -> Dictionary:
	var boundaries := {}
	var failures: Array[String] = []
	var gate_names: Array = gates.keys(); gate_names.sort_custom(func(a, b): return String(a) < String(b))
	for boundary_raw in gate_names:
		var boundary := StringName(boundary_raw)
		var gate: Dictionary = gates[boundary_raw]
		var result := aggregate(boundary, float(gate.get("threshold", 1.0e300)),
			StringName(gate.get("statistic", &"p95")))
		var counts := {}
		for sample in _samples:
			if sample.boundary == boundary and sample.excluded_reason.is_empty():
				counts = sample.get_workload_counts()
				break
		result["workload_counts"] = counts
		boundaries[String(boundary)] = result
		if not result.passed: failures.append("%s:%s" % [String(boundary), result.statistic])
	return {"schema_version":1, "passed":failures.is_empty(), "failures":failures,
		"seed":seed, "town_id":town_id, "sample_count":_samples.size(),
		"boundaries":boundaries}

func write_report(path: String, gates: Dictionary, metadata: Dictionary = {}) -> Dictionary:
	var report := build_report(gates)
	for key in metadata: report[key] = metadata[key]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return {"ok":false, "reason":"report_write_failed", "report":report}
	file.store_string(JSON.stringify(report, "  ", true) + "\n")
	return {"ok":true, "report":report}
