extends SceneTree

## Real-stack fixture driver for the feature-019 tutorial save boundary.  The
## fixture maps are built by Builder, persisted by Builder, cleared, and then
## cold-loaded by Builder before any tutorial assertion is recorded.

const RESULT_PREFIX := "OPENING_TUTORIAL_BUILDER_SAVE_RESULT "
const SCENARIO_ID := "first_town/opening_balance"
const SCENARIO_SEED := 19019
const ROAD_CELLS: Array[Vector2i] = [
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
	Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1),
	Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1),
	Vector2i(7, 2),
]
const SAVE_PATHS := {
	"legacy_four": "/tmp/starter-kit-opening-tutorial-legacy-four.res",
	"incomplete_nine": "/tmp/starter-kit-opening-tutorial-incomplete-nine.res",
	"incomplete_ten": "/tmp/starter-kit-opening-tutorial-incomplete-ten.res",
	"legacy_non_anchor_home": "/tmp/starter-kit-opening-tutorial-legacy-non-anchor-home.res",
	"migrated_non_anchor_home": "/tmp/starter-kit-opening-tutorial-migrated-non-anchor-home.res",
}

var _failures: Array[String] = []
var _game_state: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	change_scene_to_file("res://scenes/main.tscn")
	for _frame in 12:
		await process_frame

	var manager: Node = root.get_node_or_null("PluginManager")
	_game_state = root.get_node_or_null("GameState")
	var builder: Node = current_scene.get_node_or_null("Builder") if current_scene else null
	var playtest: Node = manager.get_plugin("Playtest") if manager else null
	var tutorial: Node = manager.get_plugin("OpeningTutorial") if manager else null
	if manager == null or _game_state == null or builder == null or playtest == null or tutorial == null:
		_fail("real_stack_unavailable")
		_finish({})
		return

	var started: Dictionary = playtest.start_session({
		"scenario_id": SCENARIO_ID,
		"seed": SCENARIO_SEED,
	})
	_check(not started.has("error"), "session_start_failed")
	await _settle()

	var cases := {
		"legacy_four": await _exercise_fixture(
			builder, tutorial, SAVE_PATHS.legacy_four, 4, true),
		"incomplete_nine": await _exercise_fixture(
			builder, tutorial, SAVE_PATHS.incomplete_nine, 9, false),
		"incomplete_ten": await _exercise_fixture(
			builder, tutorial, SAVE_PATHS.incomplete_ten, 10, false),
		"legacy_non_anchor_home": await _exercise_legacy_non_anchor_home_fixture(
			builder, tutorial, SAVE_PATHS.legacy_non_anchor_home,
			SAVE_PATHS.migrated_non_anchor_home),
	}
	_cleanup()
	_finish(cases)


func _exercise_fixture(builder: Node, tutorial: Node, save_path: String,
		road_count: int, legacy_road_receipt: bool) -> Dictionary:
	var fresh := DataMap.new()
	fresh.rooted_town_rules = true
	var reset_result: Dictionary = builder.reset_to_fresh_map(fresh)
	_check(str(reset_result.get("status", "")) == PlaytestActionResult.STATUS_APPLIED,
		"reset_failed_%d" % road_count)
	await _settle()

	await _place(builder, "building_town_hall", Vector2i(-1, -1), road_count)
	for index in road_count:
		await _place(builder, "road", ROAD_CELLS[index], road_count)

	# Author the historical/incomplete tutorial payload only after live placement
	# events have settled.  This is the fixture input; Builder remains the sole
	# authority for the map's actual save and load representation.
	_game_state.map.opening_tutorial_state = _fixture_state(tutorial, legacy_road_receipt)
	var save_result: Dictionary = builder.save_map_to_path(save_path)
	_check(str(save_result.get("status", "")) == PlaytestActionResult.STATUS_APPLIED,
		"save_failed_%d" % road_count)

	var persisted := ResourceLoader.load(
		save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as DataMap
	_check(persisted != null, "persisted_fixture_unreadable_%d" % road_count)
	var persisted_state: Dictionary = (
		persisted.opening_tutorial_state.duplicate(true) if persisted else {})
	var persisted_receipts: Dictionary = persisted_state.get("completed_receipts", {})

	# Prove this is a cold Builder load rather than an in-memory normalization:
	# clear the registry first, then let Builder reconstruct it from the .res.
	var cleared: Dictionary = builder.reset_to_fresh_map(DataMap.new())
	_check(str(cleared.get("status", "")) == PlaytestActionResult.STATUS_APPLIED,
		"clear_before_load_failed_%d" % road_count)
	await _settle()
	_check(_game_state.building_registry.is_empty(),
		"registry_not_empty_before_load_%d" % road_count)

	var load_result: Dictionary = builder.load_map_from_path(save_path)
	_check(str(load_result.get("status", "")) == PlaytestActionResult.STATUS_APPLIED,
		"load_failed_%d" % road_count)
	await _settle()

	var loaded_state: Dictionary = tutorial.get_state()
	var loaded_receipts: Dictionary = loaded_state.get("completed_receipts", {})
	var road_receipt: Dictionary = loaded_receipts.get(
		"opening.rooted_roads_connected", {})
	var evidence: Dictionary = tutorial.get_evidence_snapshot()
	var projection: Dictionary = tutorial.get_projection()
	var result := {
		"road_count": road_count,
		"saved_structure_count": int(save_result.get("details", {}).get("structures", -1)),
		"loaded_structure_count": int(load_result.get("details", {}).get("structures", -1)),
		"registry_count_after_load": _game_state.building_registry.size(),
		"rooted_road_count_after_load": int(evidence.get("rooted_road_count", -1)),
		"persisted_had_road_receipt": persisted_receipts.has("opening.rooted_roads_connected"),
		"loaded_has_road_receipt": loaded_receipts.has("opening.rooted_roads_connected"),
		"loaded_step_id": str(loaded_state.get("current_step_id", "")),
		"road_receipt_count": int(road_receipt.get("evidence", {}).get("count", -1)),
		"projection_progress": projection.get("progress", {}).duplicate(true),
	}

	_check(result.saved_structure_count == road_count + 1,
		"saved_structure_count_%d" % road_count)
	_check(result.loaded_structure_count == road_count + 1,
		"loaded_structure_count_%d" % road_count)
	_check(result.registry_count_after_load == road_count + 1,
		"registry_count_after_load_%d" % road_count)
	_check(result.rooted_road_count_after_load == road_count,
		"rooted_road_count_after_load_%d" % road_count)

	if legacy_road_receipt:
		_check(result.persisted_had_road_receipt, "legacy_receipt_not_persisted")
		_check(result.loaded_has_road_receipt, "legacy_receipt_not_retained")
		_check(result.road_receipt_count == 4, "legacy_receipt_evidence_changed")
		_check(result.loaded_step_id == "establish_nature",
			"legacy_receipt_did_not_remain_monotonic")
	else:
		_check(not result.persisted_had_road_receipt,
			"incomplete_fixture_already_had_road_receipt_%d" % road_count)
		_check(result.loaded_has_road_receipt == (road_count == 10),
			"new_gate_boundary_wrong_%d" % road_count)
		_check(result.loaded_step_id == (
			"establish_nature" if road_count == 10 else "connect_rooted_roads"),
			"loaded_step_wrong_%d" % road_count)
		if road_count == 10:
			_check(result.road_receipt_count == 10,
				"ten_road_receipt_evidence_wrong")
		else:
			_check(result.projection_progress == {
				"current": 9, "required": 10, "unit": "road_cells",
			}, "nine_road_projection_wrong")

	return result


func _exercise_legacy_non_anchor_home_fixture(builder: Node, tutorial: Node,
		legacy_save_path: String, migrated_save_path: String) -> Dictionary:
	var fresh := DataMap.new()
	fresh.rooted_town_rules = false
	fresh.demand_totals = {"residential":100.0,"industrial":5.0,"commercial":5.0}
	var reset_result: Dictionary = builder.reset_to_fresh_map(fresh)
	_check(str(reset_result.get("status", "")) == PlaytestActionResult.STATUS_APPLIED,
		"non_anchor_reset_failed")
	await _settle()

	# Capture the historical anchor baseline before the second home exists. The
	# second placement changes city attractiveness, making any accidental
	# load-time overwrite of this persisted evidence observable.
	await _place(builder, "building_small_a", Vector2i(-3, 0), 90)
	var persisted_anchor: Dictionary = _tutorial_home_at(tutorial, -3)
	var anchor_baseline: Dictionary = (
		tutorial._score_evidence(persisted_anchor, null) if not persisted_anchor.is_empty() else {})
	_check(not persisted_anchor.is_empty() and not anchor_baseline.is_empty(),
		"non_anchor_initial_anchor_missing")

	# This eligible home exists in the legacy map but not its old single-anchor
	# experiment schema. Its current authoritative score is therefore the exact
	# load-boundary sample feature 019 must backfill and preserve.
	await _place(builder, "building_small_a", Vector2i(1, 0), 90)
	var other_existing: Dictionary = _tutorial_home_at(tutorial, 1)
	_check(not persisted_anchor.is_empty() and not other_existing.is_empty(),
		"non_anchor_preexisting_homes_missing")
	var other_preplacement_score: Dictionary = (
		tutorial._score_evidence(other_existing, null) if not other_existing.is_empty() else {})
	var anchor_score_after_second: Dictionary = tutorial._score_evidence(persisted_anchor, null)
	_check(anchor_score_after_second != anchor_baseline,
		"non_anchor_fixture_cannot_detect_anchor_overwrite")
	_check(not other_preplacement_score.is_empty(),
		"non_anchor_other_home_score_missing")
	var fixture_state: Dictionary = tutorial._default_state()
	for step in ["place_town_hall", "connect_rooted_roads", "establish_nature", "place_first_home"]:
		var receipt_id: String = tutorial.RECEIPTS[step]
		fixture_state.completed_receipts[receipt_id] = {
			"receipt_id":receipt_id, "step_id":step,
			"evidence_kind":"legacy_fixture", "evidence":{},
		}
	fixture_state.current_step_id = "observe_adjacent_home"
	fixture_state.experiment.anchor_home = persisted_anchor.duplicate(true)
	fixture_state.experiment.baseline = anchor_baseline.duplicate(true)
	fixture_state.experiment.erase("home_baselines")
	_game_state.map.opening_tutorial_state = fixture_state

	var legacy_save_result: Dictionary = builder.save_map_to_path(legacy_save_path)
	_check(str(legacy_save_result.get("status", "")) == PlaytestActionResult.STATUS_APPLIED,
		"non_anchor_save_failed")
	var persisted := ResourceLoader.load(
		legacy_save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as DataMap
	_check(persisted != null, "non_anchor_persisted_fixture_unreadable")
	var persisted_state: Dictionary = (
		persisted.opening_tutorial_state.duplicate(true) if persisted else {})
	var persisted_experiment: Dictionary = persisted_state.get("experiment", {})

	var cleared: Dictionary = builder.reset_to_fresh_map(DataMap.new())
	_check(str(cleared.get("status", "")) == PlaytestActionResult.STATUS_APPLIED,
		"non_anchor_clear_before_load_failed")
	await _settle()
	_check(_game_state.building_registry.is_empty(),
		"non_anchor_registry_not_empty_before_load")
	var first_load_result: Dictionary = builder.load_map_from_path(legacy_save_path)
	_check(str(first_load_result.get("status", "")) == PlaytestActionResult.STATUS_APPLIED,
		"non_anchor_load_failed")
	await _settle()

	var first_loaded_state: Dictionary = tutorial.get_state()
	var first_loaded_experiment: Dictionary = first_loaded_state.get("experiment", {})
	var first_loaded_baselines: Array = first_loaded_experiment.get("home_baselines", [])
	var first_backfilled_score := _baseline_score_at(first_loaded_baselines, 1)
	var first_loaded_other := _tutorial_home_at(tutorial, 1)
	var first_loaded_other_id := int(first_loaded_other.get("internal_id", -1))
	var first_rebound_score: Dictionary = tutorial._rebound_home_baselines.get(
		first_loaded_other_id, {}).duplicate(true)
	_check(not persisted_experiment.has("home_baselines"),
		"non_anchor_fixture_was_not_legacy_shape")
	_check(first_loaded_experiment.get("baseline", {}) == anchor_baseline,
		"non_anchor_persisted_anchor_baseline_overwritten")
	_check(first_backfilled_score == other_preplacement_score,
		"non_anchor_existing_home_score_not_backfilled_exactly")
	_check(first_rebound_score == other_preplacement_score,
		"non_anchor_first_load_rebound_score_wrong")

	# Save the normalized/migrated tutorial state, then perform a second genuine
	# cold load. This proves the new row is durable and that identity rebinding
	# restores the exact sampled score rather than silently taking a fresh one.
	var migrated_save_result: Dictionary = builder.save_map_to_path(migrated_save_path)
	_check(str(migrated_save_result.get("status", "")) == PlaytestActionResult.STATUS_APPLIED,
		"non_anchor_migrated_save_failed")
	var migrated := ResourceLoader.load(
		migrated_save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as DataMap
	_check(migrated != null, "non_anchor_migrated_fixture_unreadable")
	var migrated_experiment: Dictionary = (
		migrated.opening_tutorial_state.get("experiment", {}).duplicate(true) if migrated else {})
	var migrated_persisted_score := _baseline_score_at(
		migrated_experiment.get("home_baselines", []), 1)
	_check(migrated_persisted_score == other_preplacement_score,
		"non_anchor_backfilled_score_not_persisted")

	cleared = builder.reset_to_fresh_map(DataMap.new())
	_check(str(cleared.get("status", "")) == PlaytestActionResult.STATUS_APPLIED,
		"non_anchor_second_clear_before_load_failed")
	await _settle()
	_check(_game_state.building_registry.is_empty(),
		"non_anchor_registry_not_empty_before_second_load")
	var second_load_result: Dictionary = builder.load_map_from_path(migrated_save_path)
	_check(str(second_load_result.get("status", "")) == PlaytestActionResult.STATUS_APPLIED,
		"non_anchor_second_load_failed")
	await _settle()
	var second_loaded_state: Dictionary = tutorial.get_state()
	var second_loaded_experiment: Dictionary = second_loaded_state.get("experiment", {})
	var second_persisted_score := _baseline_score_at(
		second_loaded_experiment.get("home_baselines", []), 1)
	var second_loaded_other := _tutorial_home_at(tutorial, 1)
	var second_loaded_other_id := int(second_loaded_other.get("internal_id", -1))
	var second_rebound_score: Dictionary = tutorial._rebound_home_baselines.get(
		second_loaded_other_id, {}).duplicate(true)
	_check(second_persisted_score == other_preplacement_score,
		"non_anchor_second_load_persisted_score_changed")
	_check(second_rebound_score == other_preplacement_score,
		"non_anchor_second_load_rebound_score_wrong")

	var placement: Dictionary = builder.try_place_building(
		"building_small_a", Vector2i(2, 0))
	_check(str(placement.get("status", "")) == PlaytestActionResult.STATUS_APPLIED,
		"non_anchor_new_home_placement_failed:%s" % str(placement.get("reason", "")))
	await _settle()
	var completed_state: Dictionary = tutorial.get_state()
	var experiment: Dictionary = completed_state.get("experiment", {})
	var adjacency_receipt: Dictionary = completed_state.get("completed_receipts", {}).get(
		"opening.adjacent_home_observed", {})
	var selected_anchor: Dictionary = experiment.get("anchor_home", {}).get("anchor", {})
	var adjacent_anchor: Dictionary = experiment.get("adjacent_home", {}).get("anchor", {})
	var after_adjacency: Dictionary = experiment.get("after_adjacency", {})
	var authoritative_after: Dictionary = tutorial._score_evidence(
		experiment.get("anchor_home", {}), null)
	var expected_home_delta := (int(authoritative_after.get("home_tile_score", 0))
		- int(other_preplacement_score.get("home_tile_score", 0)))
	var expected_city_delta := (int(authoritative_after.get("city_score", 0))
		- int(other_preplacement_score.get("city_score", 0)))
	var expected_result := "penalty_observed" if expected_home_delta < 0 or expected_city_delta < 0 else "no_penalty"
	var result := {
		"saved_structure_count":int(legacy_save_result.get("details", {}).get("structures", -1)),
		"loaded_structure_count":int(first_load_result.get("details", {}).get("structures", -1)),
		"migrated_saved_structure_count":int(migrated_save_result.get("details", {}).get("structures", -1)),
		"second_loaded_structure_count":int(second_load_result.get("details", {}).get("structures", -1)),
		"persisted_had_home_baselines":persisted_experiment.has("home_baselines"),
		"loaded_home_baseline_count":first_loaded_baselines.size(),
		"backfilled_other_home":not first_backfilled_score.is_empty(),
		"persisted_anchor_baseline_preserved":first_loaded_experiment.get("baseline", {}) == anchor_baseline,
		"anchor_fixture_detects_overwrite":anchor_score_after_second != anchor_baseline,
		"first_load_score_exact":first_backfilled_score == other_preplacement_score,
		"first_load_rebound_score_exact":first_rebound_score == other_preplacement_score,
		"migrated_score_persisted":migrated_persisted_score == other_preplacement_score,
		"second_load_score_exact":second_persisted_score == other_preplacement_score,
		"second_load_rebound_score_exact":second_rebound_score == other_preplacement_score,
		"selected_anchor":selected_anchor.duplicate(true),
		"adjacent_anchor":adjacent_anchor.duplicate(true),
		"adjacency_result":str(experiment.get("adjacency_result", "")),
		"expected_adjacency_result":expected_result,
		"adjacency_home_delta":int(after_adjacency.get("home_delta", 0)),
		"expected_home_delta":expected_home_delta,
		"adjacency_city_delta":int(after_adjacency.get("city_delta", 0)),
		"expected_city_delta":expected_city_delta,
		"adjacency_receipt_present":not adjacency_receipt.is_empty(),
		"registry_count_after_new_home":_game_state.building_registry.size(),
	}
	_check(result.saved_structure_count == 2, "non_anchor_saved_structure_count")
	_check(result.loaded_structure_count == 2, "non_anchor_loaded_structure_count")
	_check(result.migrated_saved_structure_count == 2,
		"non_anchor_migrated_saved_structure_count")
	_check(result.second_loaded_structure_count == 2,
		"non_anchor_second_loaded_structure_count")
	_check(result.registry_count_after_new_home == 3, "non_anchor_registry_count")
	_check(result.selected_anchor == {"x":1,"z":0},
		"non_anchor_wrong_existing_home_selected")
	_check(result.adjacent_anchor == {"x":2,"z":0},
		"non_anchor_new_home_evidence_wrong")
	_check(result.expected_home_delta == -10,
		"non_anchor_fixture_expected_home_delta_changed")
	_check(result.adjacency_home_delta == result.expected_home_delta,
		"non_anchor_adjacency_home_delta_wrong")
	_check(result.adjacency_city_delta == result.expected_city_delta,
		"non_anchor_adjacency_city_delta_wrong")
	_check(result.adjacency_result == result.expected_adjacency_result,
		"non_anchor_adjacency_result_wrong")
	_check(result.adjacency_result == "penalty_observed",
		"non_anchor_expected_penalty_not_observed")
	_check(result.adjacency_receipt_present,
		"non_anchor_adjacency_receipt_missing")
	return result


func _tutorial_home_at(tutorial: Node, anchor_x: int) -> Dictionary:
	for home in tutorial.get_evidence_snapshot().get("early_homes", []):
		if home is Dictionary and int(home.get("anchor", {}).get("x", -999)) == anchor_x:
			return home.duplicate(true)
	return {}


func _baseline_score_at(rows: Array, anchor_x: int) -> Dictionary:
	for row in rows:
		if not row is Dictionary:
			continue
		var home: Dictionary = row.get("home", {})
		if int(home.get("anchor", {}).get("x", -999)) == anchor_x:
			var score: Variant = row.get("score")
			return score.duplicate(true) if score is Dictionary else {}
	return {}


func _fixture_state(tutorial: Node, legacy_road_receipt: bool) -> Dictionary:
	var state: Dictionary = tutorial._default_state()
	state.completed_receipts["opening.town_hall_placed"] = {
		"receipt_id": "opening.town_hall_placed",
		"step_id": "place_town_hall",
		"evidence_kind": "building",
		"evidence": {
			"building_id": "building_town_hall",
			"anchor": {"x": -1, "z": -1},
		},
	}
	state.current_step_id = "connect_rooted_roads"
	if legacy_road_receipt:
		state.completed_receipts["opening.rooted_roads_connected"] = {
			"receipt_id": "opening.rooted_roads_connected",
			"step_id": "connect_rooted_roads",
			"evidence_kind": "legacy_rooted_road_cells",
			"evidence": {"count": 4, "required": 4},
		}
		state.current_step_id = "establish_nature"
	return state


func _place(builder: Node, building_id: String, anchor: Vector2i,
		fixture_road_count: int) -> void:
	var outcome: Dictionary = builder.try_place_building(building_id, anchor)
	_check(str(outcome.get("status", "")) == PlaytestActionResult.STATUS_APPLIED,
		"placement_failed_%d_%s_%d_%d_%s" % [
			fixture_road_count, building_id, anchor.x, anchor.y,
			str(outcome.get("reason", "")),
		])
	await _settle()


func _settle() -> void:
	await process_frame
	await process_frame


func _check(ok: bool, failure: String) -> void:
	if not ok:
		_fail(failure)


func _fail(failure: String) -> void:
	if failure not in _failures:
		_failures.append(failure)


func _cleanup() -> void:
	for path in SAVE_PATHS.values():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _finish(cases: Dictionary) -> void:
	var result := {
		"success": _failures.is_empty(),
		"cases": cases,
		"failures": _failures,
	}
	print("%s%s" % [RESULT_PREFIX, JSON.stringify(result)])
	quit(0 if _failures.is_empty() else 1)
