extends GutTest

const RESULT_PREFIX := "OPENING_TUTORIAL_BUILDER_SAVE_RESULT "


func test_builder_cold_loads_legacy_four_and_incomplete_nine_ten_fixtures() -> void:
	var output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--log-file", "/tmp/city-builder-opening-tutorial-builder-save-child.log",
		"-s", "res://test/integration/opening_tutorial/opening_tutorial_builder_save_load_fixtures.gd",
	], output, true)
	var result := _extract_result("\n".join(output))
	assert_eq(exit_code, 0, "real Builder save/load fixture process must pass")
	assert_false(result.is_empty(), "fixture process must print its result record")
	assert_true(bool(result.get("success", false)), str(result.get("failures", [])))

	var legacy: Dictionary = result.get("cases", {}).get("legacy_four", {})
	assert_eq(int(legacy.get("saved_structure_count", -1)), 5)
	assert_eq(int(legacy.get("loaded_structure_count", -1)), 5)
	assert_eq(int(legacy.get("rooted_road_count_after_load", -1)), 4)
	assert_true(bool(legacy.get("persisted_had_road_receipt", false)))
	assert_true(bool(legacy.get("loaded_has_road_receipt", false)))
	assert_eq(int(legacy.get("road_receipt_count", -1)), 4)
	assert_eq(str(legacy.get("loaded_step_id", "")), "establish_nature")

	var nine: Dictionary = result.get("cases", {}).get("incomplete_nine", {})
	assert_eq(int(nine.get("saved_structure_count", -1)), 10)
	assert_eq(int(nine.get("loaded_structure_count", -1)), 10)
	assert_eq(int(nine.get("rooted_road_count_after_load", -1)), 9)
	assert_false(bool(nine.get("persisted_had_road_receipt", true)))
	assert_false(bool(nine.get("loaded_has_road_receipt", true)))
	assert_eq(str(nine.get("loaded_step_id", "")), "connect_rooted_roads")
	var nine_progress: Dictionary = nine.get("projection_progress", {})
	assert_eq(int(nine_progress.get("current", -1)), 9)
	assert_eq(int(nine_progress.get("required", -1)), 10)
	assert_eq(str(nine_progress.get("unit", "")), "road_cells")

	var ten: Dictionary = result.get("cases", {}).get("incomplete_ten", {})
	assert_eq(int(ten.get("saved_structure_count", -1)), 11)
	assert_eq(int(ten.get("loaded_structure_count", -1)), 11)
	assert_eq(int(ten.get("rooted_road_count_after_load", -1)), 10)
	assert_false(bool(ten.get("persisted_had_road_receipt", true)))
	assert_true(bool(ten.get("loaded_has_road_receipt", false)))
	assert_eq(int(ten.get("road_receipt_count", -1)), 10)
	assert_eq(str(ten.get("loaded_step_id", "")), "establish_nature")

	var non_anchor: Dictionary = result.get("cases", {}).get("legacy_non_anchor_home", {})
	assert_eq(int(non_anchor.get("saved_structure_count", -1)), 2)
	assert_eq(int(non_anchor.get("loaded_structure_count", -1)), 2)
	assert_eq(int(non_anchor.get("migrated_saved_structure_count", -1)), 2)
	assert_eq(int(non_anchor.get("second_loaded_structure_count", -1)), 2)
	assert_false(bool(non_anchor.get("persisted_had_home_baselines", true)))
	assert_true(bool(non_anchor.get("backfilled_other_home", false)))
	assert_true(bool(non_anchor.get("persisted_anchor_baseline_preserved", false)))
	assert_true(bool(non_anchor.get("anchor_fixture_detects_overwrite", false)))
	assert_true(bool(non_anchor.get("first_load_score_exact", false)))
	assert_true(bool(non_anchor.get("first_load_rebound_score_exact", false)))
	assert_true(bool(non_anchor.get("migrated_score_persisted", false)))
	assert_true(bool(non_anchor.get("second_load_score_exact", false)))
	assert_true(bool(non_anchor.get("second_load_rebound_score_exact", false)))
	var selected_anchor: Dictionary = non_anchor.get("selected_anchor", {})
	var adjacent_anchor: Dictionary = non_anchor.get("adjacent_anchor", {})
	assert_eq(int(selected_anchor.get("x", -999)), 1)
	assert_eq(int(selected_anchor.get("z", -999)), 0)
	assert_eq(int(adjacent_anchor.get("x", -999)), 2)
	assert_eq(int(adjacent_anchor.get("z", -999)), 0)
	assert_eq(int(non_anchor.get("expected_home_delta", 0)), -10)
	assert_eq(int(non_anchor.get("adjacency_home_delta", 0)), -10)
	assert_eq(int(non_anchor.get("adjacency_city_delta", 0)),
		int(non_anchor.get("expected_city_delta", 1)))
	assert_eq(str(non_anchor.get("adjacency_result", "")), "penalty_observed")
	assert_eq(str(non_anchor.get("adjacency_result", "")),
		str(non_anchor.get("expected_adjacency_result", "missing")))
	assert_true(bool(non_anchor.get("adjacency_receipt_present", false)))
	assert_eq(int(non_anchor.get("registry_count_after_new_home", -1)), 3)


func _extract_result(output: String) -> Dictionary:
	for line in output.split("\n"):
		if line.begins_with(RESULT_PREFIX):
			var parsed: Variant = JSON.parse_string(line.trim_prefix(RESULT_PREFIX))
			return parsed if parsed is Dictionary else {}
	return {}
