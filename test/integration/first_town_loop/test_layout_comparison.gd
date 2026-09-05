extends GutTest

const ROOT := "res://test/scenarios/first_town/"

func test_every_matrix_pair_is_admissible_and_passes_frozen_expectations() -> void:
	var matrix := _json(ROOT + "matrix.json")
	var report := _json("res://specs/006-connected-first-town-loop/validation/matrix-report.json")
	assert_true(report.get("success", false), "run scripts/run_first_town_matrix.gd to refresh matrix evidence")
	assert_eq(report.get("pairs", []).size(), matrix.get("pairs", []).size())
	for pair in report.get("pairs", []):
		assert_true(pair.get("admissible", false), "%s must be admissible: %s" % [pair.get("pair_id", ""), pair.get("errors", [])])
		assert_true(pair.get("passed", false), "%s must pass its frozen expectations" % pair.get("pair_id", ""))

func test_comparator_rejects_mismatched_held_constant_before_deltas() -> void:
	var left := _json(ROOT + "compact.json")
	var right := _json(ROOT + "spread.json")
	right["seed"] = int(left["seed"]) + 1
	var manifest := {"schema_version": 1, "pair_id": "invalid", "left_scenario": left["scenario_id"], "right_scenario": right["scenario_id"], "permitted_differences": ["anchors", "road_cells"]}
	var validation := FirstTownLayoutComparator.validate_manifest(manifest, left, right)
	assert_false(validation["admissible"])
	assert_has(validation["errors"], "held_constant_mismatch:seed")

func test_ten_repeat_report_is_deterministic_for_every_scenario() -> void:
	var report := _json("res://specs/006-connected-first-town-loop/validation/determinism-report.json")
	assert_true(report.get("success", false), "run scripts/run_first_town_matrix.gd to refresh determinism evidence")
	for scenario in report.get("scenarios", []):
		assert_eq(int(scenario.get("repeat_count", 0)), 10)
		assert_true(scenario.get("deterministic", false), scenario.get("scenario_id", ""))
		assert_eq(_set_size(scenario.get("hashes", [])), 1)

func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _set_size(values: Array) -> int:
	var found := {}
	for value in values: found[value] = true
	return found.size()
