extends GutTest

const EVIDENCE := "res://specs/008-civilian-simulation-coherence/validation/last-run.json"

func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func test_fixed_step_full_day_is_clean_and_repeats_ten_times() -> void:
	var evidence := _json(EVIDENCE)
	assert_true(bool(evidence.get("success",false)))
	assert_eq(int(evidence.get("repeat_count",0)),10)
	var hashes: Array = evidence.get("trace_hashes",[]); assert_eq(hashes.size(),10)
	assert_eq(hashes.duplicate().reduce(func(unique, value): return unique if value in unique else unique + [value], []).size(),1)
	assert_eq(evidence.get("canonical_trace",[]).size(),25)

func test_disconnect_edit_and_programme_scenarios_encode_required_changes() -> void:
	var disconnected := _json("res://test/scenarios/civilian_simulation/disconnected_day.json")
	var edit := _json("res://test/scenarios/civilian_simulation/edit_continuity.json")
	assert_eq(disconnected["scenario_id"],"civilian_disconnected_day")
	assert_ne(edit["civilian_layout"]["unrelated_edit"],edit["civilian_layout"]["dependent_road_removal"])
	var faults: Dictionary = _json(EVIDENCE).get("fault_detection",{})
	assert_true(faults.values().all(func(value): return bool(value)))
