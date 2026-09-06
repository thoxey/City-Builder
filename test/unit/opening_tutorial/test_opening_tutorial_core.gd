extends GutTest

const OpeningTutorial := preload("res://plugins/opening_tutorial/opening_tutorial_plugin.gd")

var _previous_map: DataMap
var _tutorial

func before_each() -> void:
	_previous_map = GameState.map
	GameState.map = DataMap.new()
	_tutorial = OpeningTutorial.new()

func after_each() -> void:
	_tutorial.free()
	GameState.map = _previous_map

func test_malformed_state_normalizes_to_first_semantic_step() -> void:
	GameState.map.opening_tutorial_state = {"current_step_id": "future_step", "completed_receipts": "bad"}
	_tutorial._normalize_state()
	var state: Dictionary = _tutorial.get_state()
	assert_eq(state.schema_version, 1)
	assert_eq(state.tutorial_id, "opening_tutorial")
	assert_eq(state.current_step_id, "place_town_hall")
	assert_true(state.completed_receipts.is_empty())
	assert_eq(state.experiment.adjacency_result, "pending")

func test_receipts_are_validated_and_do_not_trust_claimed_step() -> void:
	GameState.map.opening_tutorial_state = {
		"completed_receipts": {
			"opening.town_hall_placed": {"receipt_id": "opening.town_hall_placed", "step_id": "place_town_hall", "evidence_kind": "building", "evidence": {}},
			"opening.rooted_roads_connected": {"receipt_id": "wrong", "step_id": "connect_rooted_roads"},
		}
	}
	_tutorial._normalize_state()
	var state: Dictionary = _tutorial.get_state()
	assert_true(state.completed_receipts.has("opening.town_hall_placed"))
	assert_false(state.completed_receipts.has("opening.rooted_roads_connected"))
	assert_eq(state.current_step_id, "connect_rooted_roads")

func test_footprint_distance_is_chebyshev_and_footprint_aware() -> void:
	var a := [{"x": 0, "z": 0}, {"x": 1, "z": 0}]
	var adjacent := [{"x": 2, "z": 1}]
	var separated := [{"x": 4, "z": 0}]
	assert_eq(OpeningTutorial._footprint_distance(a, adjacent), 1)
	assert_eq(OpeningTutorial._footprint_distance(a, separated), 3)
	assert_eq(OpeningTutorial._footprint_manhattan_distance(a, adjacent), 2)
	assert_eq(OpeningTutorial._footprint_manhattan_distance(a, separated), 3)

func test_all_runtime_copy_is_literal_approved_ambrose_placeholder_text() -> void:
	assert_eq(OpeningTutorial.COPY.size(), 18)
	for index in range(1, 19):
		var beat := "B%02d" % index
		assert_true(String(OpeningTutorial.COPY.get(beat, "")).begins_with("AMBROSE PLACEHOLDER:"), beat)
	assert_eq(OpeningTutorial.COPY.B01, "AMBROSE PLACEHOLDER: tell the player to place the Town Hall")

func test_public_getters_return_detached_records() -> void:
	_tutorial._normalize_state()
	var state: Dictionary = _tutorial.get_state()
	state.completed_receipts["bad"] = true
	assert_false(_tutorial.get_state().completed_receipts.has("bad"))

func test_road_and_nature_gates_use_canonical_thresholds() -> void:
	_tutorial._state = _tutorial._default_state()
	_tutorial._evidence = {
		"town_hall": {"building_id": "building_town_hall"},
		"rooted_road_count": 3, "rooted_road_cells": [],
		"nature_building_ids": ["oak", "pond"], "city_attractiveness": 0,
	}
	assert_true(_tutorial._evaluate_gate("place_town_hall").satisfied)
	assert_false(_tutorial._evaluate_gate("connect_rooted_roads").satisfied)
	assert_false(_tutorial._evaluate_gate("establish_nature").satisfied)
	_tutorial._evidence.rooted_road_count = 4
	_tutorial._evidence.city_attractiveness = 1
	assert_true(_tutorial._evaluate_gate("connect_rooted_roads").satisfied)
	assert_true(_tutorial._evaluate_gate("establish_nature").satisfied)

func test_receipts_make_reconciliation_monotonic_after_facts_disappear() -> void:
	var state: Dictionary = _tutorial._default_state()
	state.completed_receipts["opening.town_hall_placed"] = {
		"receipt_id": "opening.town_hall_placed", "step_id": "place_town_hall",
		"evidence_kind": "building", "evidence": {"building_id": "building_town_hall"},
	}
	GameState.map.opening_tutorial_state = state
	_tutorial.reconcile("demolition")
	assert_true(_tutorial.get_state().completed_receipts.has("opening.town_hall_placed"))
	assert_eq(_tutorial.get_state().current_step_id, "connect_rooted_roads")

func test_completion_persists_before_exactly_once_handoff_signal() -> void:
	var state: Dictionary = _tutorial._default_state()
	for step in OpeningTutorial.RECEIPTS:
		var receipt_id: String = OpeningTutorial.RECEIPTS[step]
		state.completed_receipts[receipt_id] = {
			"receipt_id": receipt_id, "step_id": step, "evidence_kind": "fixture",
			"evidence": {"building_id": "building_shop", "anchor": {"x": 4, "z": 2}} if step == "place_first_shop" else {},
		}
	GameState.map.opening_tutorial_state = state
	var emissions: Array = []
	var listener := func(payload: Dictionary):
		emissions.append({"payload": payload, "persisted": bool(GameState.map.opening_tutorial_state.completion_handoff.applied)})
	GameEvents.tutorial_opening_completed.connect(listener)
	_tutorial.reconcile("shop")
	_tutorial.reconcile("duplicate")
	GameEvents.tutorial_opening_completed.disconnect(listener)
	assert_eq(emissions.size(), 1)
	assert_true(emissions[0].persisted)
	assert_eq(emissions[0].payload.shop_building_id, "building_shop")
	assert_true(_tutorial.is_complete())


func test_every_semantic_receipt_boundary_survives_json_round_trip() -> void:
	var ordered_steps: Array[String] = OpeningTutorial.STEPS.slice(0, OpeningTutorial.STEPS.size() - 1)
	for completed_count in range(ordered_steps.size() + 1):
		var state: Dictionary = _tutorial._default_state()
		for index in completed_count:
			var step: String = ordered_steps[index]
			var receipt_id: String = OpeningTutorial.RECEIPTS[step]
			state.completed_receipts[receipt_id] = {
				"receipt_id": receipt_id, "step_id": step,
				"evidence_kind": "boundary_fixture", "evidence": {},
			}
		GameState.map.opening_tutorial_state = JSON.parse_string(JSON.stringify(state))
		_tutorial._normalize_state()
		var restored: Dictionary = _tutorial.get_state()
		var expected_step: String = "complete" if completed_count == ordered_steps.size() else ordered_steps[completed_count]
		assert_eq(restored.current_step_id, expected_step, "boundary %d" % completed_count)
		assert_eq(restored.completed_receipts.size(), completed_count, "boundary %d" % completed_count)


func test_no_penalty_and_missing_baseline_observations_never_invent_a_loss() -> void:
	var anchor := {
		"internal_id": 1, "building_id": "home_a", "category": "residential",
		"tier": 1, "anchor": {"x": 0, "z": 0}, "footprint": [{"x": 0, "z": 0}],
	}
	var adjacent := {
		"internal_id": 2, "building_id": "home_b", "category": "residential",
		"tier": 1, "anchor": {"x": 1, "z": 0}, "footprint": [{"x": 1, "z": 0}],
	}
	_tutorial._state = _tutorial._default_state()
	_tutorial._state.experiment.anchor_home = anchor.duplicate(true)
	_tutorial._state.experiment.baseline = {"home_tile_score": 10, "city_score": 20}
	_tutorial._placement_observations = [{
		"building": adjacent, "score": {"home_tile_score": 10, "city_score": 21},
	}]
	_tutorial._replay_placement_observations()
	assert_eq(_tutorial.get_state().experiment.adjacency_result, "no_penalty")
	assert_eq(int(_tutorial.get_state().experiment.after_adjacency.home_delta), 0)

	_tutorial._state = _tutorial._default_state()
	_tutorial._state.experiment.anchor_home = anchor.duplicate(true)
	_tutorial._state.experiment.baseline = null
	_tutorial._placement_observations = [{
		"building": adjacent, "score": {"home_tile_score": 8, "city_score": 18},
	}]
	_tutorial._replay_placement_observations()
	assert_eq(_tutorial.get_state().experiment.adjacency_result, "baseline_unavailable")
	assert_null(_tutorial.get_state().experiment.after_adjacency.get("home_delta"))
