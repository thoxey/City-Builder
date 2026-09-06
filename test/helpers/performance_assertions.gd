extends RefCounted
class_name PerformanceAssertions

static func nearest_rank(values: Array, percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var ordered := values.duplicate()
	ordered.sort()
	var rank := clampi(ceili(clampf(percentile, 0.0, 1.0) * ordered.size()) - 1, 0, ordered.size() - 1)
	return float(ordered[rank])

static func canonical_hashes_match(runs: Array) -> bool:
	if runs.is_empty():
		return false
	var expected := String(runs[0].get("state_hash", ""))
	if expected.is_empty():
		return false
	for run in runs:
		if String(run.get("state_hash", "")) != expected:
			return false
	return true

static func workload_matches(actual: Dictionary, expected: Dictionary) -> bool:
	for key in expected:
		if actual.get(key) != expected[key]:
			return false
	return true
