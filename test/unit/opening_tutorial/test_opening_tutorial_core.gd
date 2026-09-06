extends GutTest

const OpeningTutorial := preload("res://plugins/opening_tutorial/opening_tutorial_plugin.gd")
const RoadNetwork := preload("res://plugins/traffic/road_network_plugin.gd")

class _RootedRoadNetwork:
	extends RoadNetwork
	var hall_internal_id := 100

	func get_town_hall_internal_id() -> int:
		return hall_internal_id

class _MutableAttractiveness:
	extends PluginBase
	var scores := {
		Vector2i(0, 0): 111,
		Vector2i(5, 0): 47,
		Vector2i(6, 0): 23,
	}
	var current_city_score := 200

	func get_plugin_name() -> String:
		return "MutableAttractiveness"

	func get_score(cell: Vector2i) -> int:
		return int(scores.get(cell, 0))

	func city_score() -> int:
		return current_city_score

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

func test_measured_experiment_records_survive_normalization() -> void:
	var state: Dictionary = _tutorial._default_state()
	state.experiment.anchor_home = {"internal_id": 7, "anchor": {"x": 2, "z": 0}}
	state.experiment.baseline = {"home_tile_score": -10, "city_score": 84}
	state.experiment.adjacent_home = {"internal_id": 8, "anchor": {"x": 3, "z": 0}}
	state.experiment.after_adjacency = {"home_tile_score": -20, "home_delta": -10}
	state.experiment.repair_source = {"building_id": "grass_trees", "anchor": {"x": 2, "z": -1}}
	state.experiment.after_repair = {"home_tile_score": 0, "home_delta": 20}
	GameState.map.opening_tutorial_state = state
	_tutorial._normalize_state()
	var normalized: Dictionary = _tutorial.get_state().experiment
	assert_eq(normalized.anchor_home.internal_id, 7)
	assert_eq(normalized.after_adjacency.home_delta, -10)
	assert_eq(normalized.repair_source.building_id, "grass_trees")
	assert_eq(normalized.after_repair.home_delta, 20)

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
		"rooted_road_count": 9, "rooted_road_cells": [],
		"nature_building_ids": ["oak", "pond"], "city_attractiveness": 0,
	}
	assert_true(_tutorial._evaluate_gate("place_town_hall").satisfied)
	assert_false(_tutorial._evaluate_gate("connect_rooted_roads").satisfied)
	assert_false(_tutorial._evaluate_gate("establish_nature").satisfied)
	_tutorial._evidence.rooted_road_count = 10
	_tutorial._evidence.city_attractiveness = 1
	assert_true(_tutorial._evaluate_gate("connect_rooted_roads").satisfied)
	assert_true(_tutorial._evaluate_gate("establish_nature").satisfied)
	_tutorial._state.current_step_id = "connect_rooted_roads"
	var projection: Dictionary = _tutorial._make_projection()
	assert_eq(projection.progress, {"current":10,"required":10,"unit":"road_cells"})

func test_legacy_four_road_receipt_remains_complete() -> void:
	var state: Dictionary = _tutorial._default_state()
	state.completed_receipts["opening.town_hall_placed"] = {
		"receipt_id":"opening.town_hall_placed", "step_id":"place_town_hall", "evidence_kind":"fixture", "evidence":{},
	}
	state.completed_receipts["opening.rooted_roads_connected"] = {
		"receipt_id":"opening.rooted_roads_connected", "step_id":"connect_rooted_roads", "evidence_kind":"legacy", "evidence":{"count":4},
	}
	GameState.map.opening_tutorial_state = state
	_tutorial._normalize_state()
	assert_true(_tutorial.get_state().completed_receipts.has("opening.rooted_roads_connected"))
	assert_eq(_tutorial.get_state().current_step_id, "establish_nature")

func test_incomplete_nine_and_ten_road_save_states_keep_new_gate_boundary() -> void:
	for rooted_count in [9, 10]:
		var state: Dictionary = _tutorial._default_state()
		state.completed_receipts["opening.town_hall_placed"] = {
			"receipt_id":"opening.town_hall_placed", "step_id":"place_town_hall",
			"evidence_kind":"building", "evidence":{"building_id":"building_town_hall"},
		}
		var round_tripped: Variant = JSON.parse_string(JSON.stringify(state))
		GameState.map.opening_tutorial_state = round_tripped
		_tutorial._normalize_state()
		assert_eq(_tutorial.get_state().current_step_id, "connect_rooted_roads")
		_tutorial._evidence = {"rooted_road_count": rooted_count, "rooted_road_cells": []}
		assert_eq(_tutorial._evaluate_gate("connect_rooted_roads").satisfied, rooted_count == 10)

func test_disconnected_roads_do_not_count_until_the_component_connects_past_ten() -> void:
	var roads := _RootedRoadNetwork.new()
	add_child_autofree(roads)
	_tutorial._roads = roads
	var state: Dictionary = _tutorial._default_state()
	state.completed_receipts["opening.town_hall_placed"] = {
		"receipt_id":"opening.town_hall_placed", "step_id":"place_town_hall",
		"evidence_kind":"building", "evidence":{"building_id":"building_town_hall"},
	}
	GameState.map.opening_tutorial_state = state

	# Nine cells form the Town Hall-rooted component. The tenth road exists in a
	# separate component and therefore must not advance the lesson.
	var road_cells: Array[Vector2i] = []
	for x in range(9):
		road_cells.append(Vector2i(x, 0))
	road_cells.append(Vector2i(10, 0))
	_set_road_topology(roads, road_cells)
	var before_connect: Dictionary = _tutorial.reconcile("disconnected_fixture")
	assert_eq(roads.get_connectivity_snapshot().road_cell_count, 10)
	assert_eq(roads.get_connectivity_snapshot().components.size(), 2)
	assert_eq(_tutorial.get_evidence_snapshot().rooted_road_count, 9)
	assert_eq(_tutorial.get_projection().progress, {
		"current":9, "required":10, "unit":"road_cells",
	})
	assert_false(_tutorial.get_state().completed_receipts.has("opening.rooted_roads_connected"))
	assert_eq(before_connect.step_id, "connect_rooted_roads")

	# The bridge joins the formerly disconnected road, taking the authoritative
	# rooted component from nine directly to eleven cells.
	road_cells.append(Vector2i(9, 0))
	_set_road_topology(roads, road_cells)
	var after_connect: Dictionary = _tutorial.reconcile("connected_fixture")
	var receipt: Dictionary = _tutorial.get_state().completed_receipts.get(
		"opening.rooted_roads_connected", {})
	assert_eq(roads.get_connectivity_snapshot().components.size(), 1)
	assert_eq(_tutorial.get_evidence_snapshot().rooted_road_count, 11)
	assert_eq(receipt.get("evidence", {}).get("count"), 11)
	assert_eq(receipt.get("evidence", {}).get("cells", []).size(), 11)
	assert_true("opening.rooted_roads_connected" in after_connect.added_receipts)
	var receipt_before_duplicate := receipt.duplicate(true)
	assert_true(_tutorial.reconcile("duplicate_connected_fixture").added_receipts.is_empty())
	assert_eq(_tutorial.get_state().completed_receipts["opening.rooted_roads_connected"],
		receipt_before_duplicate)

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
	_tutorial._evidence = {"early_homes": [anchor, adjacent], "diagnostics": []}
	_tutorial._placement_observations = [{
		"building": adjacent, "score": {"home_tile_score": 10, "city_score": 21},
	}]
	_tutorial._replay_placement_observations()
	assert_eq(_tutorial.get_state().experiment.adjacency_result, "no_penalty")
	assert_eq(int(_tutorial.get_state().experiment.after_adjacency.home_delta), 0)

	_tutorial._state = _tutorial._default_state()
	_tutorial._state.experiment.anchor_home = anchor.duplicate(true)
	_tutorial._state.experiment.baseline = null
	_tutorial._evidence = {"early_homes": [anchor, adjacent], "diagnostics": []}
	_tutorial._placement_observations = [{
		"building": adjacent, "score": {"home_tile_score": 8, "city_score": 18},
	}]
	_tutorial._replay_placement_observations()
	assert_eq(_tutorial.get_state().experiment.adjacency_result, "baseline_unavailable")
	assert_null(_tutorial.get_state().experiment.after_adjacency)

func test_demolished_anchor_is_never_used_as_a_current_adjacency_candidate() -> void:
	var demolished := {"internal_id":1,"building_id":"home_a","category":"residential","tier":1,"anchor":{"x":0,"z":0},"footprint":[{"x":0,"z":0}]}
	var newly_placed := {"internal_id":2,"building_id":"home_b","category":"residential","tier":1,"anchor":{"x":1,"z":0},"footprint":[{"x":1,"z":0}]}
	_tutorial._state = _tutorial._default_state()
	_tutorial._state.experiment.anchor_home = demolished.duplicate(true)
	_tutorial._state.experiment.baseline = {"home_tile_score":8,"city_score":10}
	_tutorial._remember_home_baseline(_tutorial._state.experiment, demolished, {"home_tile_score":8,"city_score":10})
	# The authoritative evidence contains only the new placement: the persisted
	# anchor was demolished and must not be resurrected as the second home.
	_tutorial._evidence = {"early_homes":[newly_placed], "diagnostics":[]}
	_tutorial._placement_observations = [{"building":newly_placed,"score":{"home_tile_score":6,"city_score":10}}]
	_tutorial._replay_placement_observations()
	assert_null(_tutorial.get_state().experiment.after_adjacency)
	assert_null(_tutorial.get_state().experiment.adjacent_home)

func test_replacement_home_does_not_inherit_demolished_home_baseline() -> void:
	var demolished := {"internal_id":1,"building_id":"home_a","category":"residential","tier":1,"anchor":{"x":0,"z":0},"footprint":[{"x":0,"z":0}]}
	var replacement := {"internal_id":2,"building_id":"home_a","category":"residential","tier":1,"anchor":{"x":0,"z":0},"footprint":[{"x":0,"z":0}]}
	var newly_placed := {"internal_id":3,"building_id":"home_b","category":"residential","tier":1,"anchor":{"x":1,"z":0},"footprint":[{"x":1,"z":0}]}
	_tutorial._state = _tutorial._default_state()
	_tutorial._state.experiment.anchor_home = demolished.duplicate(true)
	_tutorial._state.experiment.baseline = {"home_tile_score":8,"city_score":10}
	_tutorial._remember_home_baseline(_tutorial._state.experiment, demolished, {"home_tile_score":8,"city_score":10})
	_tutorial._evidence = {"early_homes":[replacement, newly_placed], "diagnostics":[]}
	_tutorial._placement_observations = [{"building":newly_placed,"score":{"home_tile_score":6,"city_score":10}}]
	_tutorial._replay_placement_observations()
	assert_eq(_tutorial.get_state().experiment.adjacency_result, "baseline_unavailable")
	assert_null(_tutorial.get_state().experiment.after_adjacency)

func test_json_save_load_rebinds_home_baseline_across_builder_id_gap_renumbering() -> void:
	var stale_gap_home := {"internal_id":0,"building_id":"home_stale","category":"residential","tier":1,"anchor":{"x":20,"z":0},"footprint":[{"x":20,"z":0}]}
	var persisted_anchor := {"internal_id":7,"building_id":"home_a","category":"residential","tier":1,"anchor":{"x":0,"z":0},"footprint":[{"x":0,"z":0}]}
	var loaded_anchor := persisted_anchor.duplicate(true)
	loaded_anchor.internal_id = 0
	var newly_placed := {"internal_id":1,"building_id":"home_b","category":"residential","tier":1,"anchor":{"x":1,"z":0},"footprint":[{"x":1,"z":0}]}
	var state: Dictionary = _tutorial._default_state()
	state.experiment.anchor_home = persisted_anchor.duplicate(true)
	state.experiment.baseline = {"home_tile_score":8,"city_score":10}
	_tutorial._remember_home_baseline(state.experiment, stale_gap_home, {"home_tile_score":999,"city_score":999})
	_tutorial._remember_home_baseline(state.experiment, persisted_anchor, {"home_tile_score":8,"city_score":10})
	# Builder saves only building identity/position and recreates contiguous IDs;
	# exercise the same persisted JSON boundary with 7 becoming 0.
	GameState.map.opening_tutorial_state = JSON.parse_string(JSON.stringify(state))
	_tutorial._normalize_state()
	_tutorial._evidence = {"early_homes":[loaded_anchor, newly_placed], "diagnostics":[]}
	_tutorial._rebind_persisted_home_evidence()
	assert_eq(int(_tutorial.get_state().experiment.anchor_home.internal_id), 7, "saved explanatory evidence stays immutable")
	assert_eq(int(_tutorial._rebound_home_baselines[0].home_tile_score), 8, "runtime ID 0 receives the matching stable baseline, not stale ID 0's score")
	_tutorial._placement_observations = [{"building":newly_placed,"score":{"home_tile_score":6,"city_score":11}}]
	_tutorial._replay_placement_observations()
	assert_eq(int(_tutorial.get_state().experiment.after_adjacency.home_delta), -2)
	assert_eq(int(_tutorial.get_state().experiment.anchor_home.internal_id), 0)

func test_upgrade_load_backfills_non_anchor_home_baseline_without_overwriting_persisted_anchor() -> void:
	var attractiveness := _MutableAttractiveness.new()
	add_child_autofree(attractiveness)
	_tutorial._attractiveness = attractiveness
	var persisted_anchor := {"internal_id":7,"building_id":"home_a","category":"residential","tier":1,"anchor":{"x":0,"z":0},"footprint":[{"x":0,"z":0}]}
	var loaded_anchor := persisted_anchor.duplicate(true)
	loaded_anchor.internal_id = 0
	var other_existing := {"internal_id":1,"building_id":"home_b","category":"residential","tier":1,"anchor":{"x":5,"z":0},"footprint":[{"x":5,"z":0}]}
	var newly_placed := {"internal_id":2,"building_id":"home_c","category":"residential","tier":1,"anchor":{"x":6,"z":0},"footprint":[{"x":6,"z":0}]}
	var state: Dictionary = _tutorial._default_state()
	for step in ["place_town_hall", "connect_rooted_roads", "establish_nature", "place_first_home"]:
		var receipt_id: String = OpeningTutorial.RECEIPTS[step]
		state.completed_receipts[receipt_id] = {
			"receipt_id":receipt_id, "step_id":step,
			"evidence_kind":"legacy_fixture", "evidence":{},
		}
	state.experiment.anchor_home = persisted_anchor.duplicate(true)
	state.experiment.baseline = {"home_tile_score":321,"city_score":654}
	state.experiment.erase("home_baselines") # Pre-feature-019 save shape.
	GameState.map.opening_tutorial_state = JSON.parse_string(JSON.stringify(state))
	_tutorial._normalize_state()
	_tutorial._evidence = {"early_homes":[loaded_anchor, other_existing], "diagnostics":[]}
	_tutorial._rebind_persisted_home_evidence()

	assert_eq(int(_tutorial._rebound_home_baselines[0].home_tile_score), 321,
		"the legacy anchor's persisted score must win over a load-time sample")
	assert_true(_tutorial._rebound_home_baselines.has(1),
		"the different pre-existing home receives an honest load-time baseline")
	assert_eq(_tutorial._rebound_home_baselines[1].home_tile_score, 47)
	assert_eq(_tutorial._rebound_home_baselines[1].city_score, 200)
	assert_eq(_tutorial.get_state().experiment.home_baselines.size(), 1)
	assert_eq(_tutorial.get_state().experiment.home_baselines[0].identity,
		OpeningTutorial._stable_home_identity(other_existing))
	assert_eq(_tutorial.get_state().experiment.home_baselines[0].score.home_tile_score, 47)
	assert_eq(_tutorial.get_state().experiment.home_baselines[0].score.city_score, 200)

	attractiveness.scores[Vector2i(5, 0)] = 37
	attractiveness.current_city_score = 190
	_tutorial._evidence = {
		"early_homes":[loaded_anchor, other_existing, newly_placed],
		"diagnostics":[],
	}
	_tutorial._placement_observations = [{
		"building":newly_placed, "score":{"home_tile_score":0,"city_score":0},
	}]
	_tutorial._replay_placement_observations()
	var experiment: Dictionary = _tutorial.get_state().experiment
	assert_not_null(experiment.after_adjacency)
	assert_eq(experiment.anchor_home.anchor, {"x":5,"z":0})
	assert_eq(experiment.adjacent_home.anchor, {"x":6,"z":0})
	assert_eq(experiment.after_adjacency.home_delta, -10)
	assert_eq(experiment.after_adjacency.city_delta, -10)
	assert_eq(experiment.adjacency_result, "penalty_observed")

func test_adjacency_uses_stable_observed_pair_with_any_eligible_home() -> void:
	var first := {"internal_id":1,"building_id":"home_a","category":"residential","tier":1,"anchor":{"x":0,"z":0},"footprint":[{"x":0,"z":0}]}
	var stable_candidate := {"internal_id":2,"building_id":"home_b","category":"residential","tier":1,"anchor":{"x":5,"z":0},"footprint":[{"x":5,"z":0}]}
	var later_candidate := {"internal_id":4,"building_id":"home_d","category":"residential","tier":1,"anchor":{"x":7,"z":0},"footprint":[{"x":7,"z":0}]}
	var newly_placed := {"internal_id":5,"building_id":"home_c","category":"residential","tier":1,"anchor":{"x":6,"z":0},"footprint":[{"x":6,"z":0}]}
	var canonical_observation: Dictionary = {}
	var permutations := _permutations([first, stable_candidate, later_candidate, newly_placed])
	assert_eq(permutations.size(), 24)
	for permutation_index in permutations.size():
		_tutorial._state = _tutorial._default_state()
		_tutorial._state.experiment.anchor_home = first.duplicate(true)
		_tutorial._state.experiment.baseline = {"home_tile_score":8,"city_score":10}
		_tutorial._remember_home_baseline(_tutorial._state.experiment, first, {"home_tile_score":8,"city_score":10})
		_tutorial._remember_home_baseline(_tutorial._state.experiment, stable_candidate, {"home_tile_score":7,"city_score":10})
		_tutorial._remember_home_baseline(_tutorial._state.experiment, later_candidate, {"home_tile_score":9,"city_score":11})
		if permutation_index % 2 == 1:
			_tutorial._state.experiment.home_baselines.reverse()
		_tutorial._evidence = {
			"early_homes":permutations[permutation_index].duplicate(true),
			"diagnostics":[],
		}
		_tutorial._placement_observations = [{
			"building":newly_placed.duplicate(true),
			"score":{"home_tile_score":0,"city_score":0},
		}]
		_tutorial._replay_placement_observations()
		var experiment: Dictionary = _tutorial.get_state().experiment
		var observation := {
			"anchor_home":experiment.anchor_home,
			"adjacent_home":experiment.adjacent_home,
			"baseline":experiment.baseline,
			"after_adjacency":experiment.after_adjacency,
			"adjacency_result":experiment.adjacency_result,
		}
		assert_eq(experiment.anchor_home.internal_id, 2,
			"lowest stable eligible candidate wins permutation %d" % permutation_index)
		assert_eq(experiment.adjacent_home.internal_id, 5)
		assert_not_null(experiment.after_adjacency)
		if canonical_observation.is_empty():
			canonical_observation = observation.duplicate(true)
		else:
			assert_eq(observation, canonical_observation,
				"persisted pair and score evidence are order-independent for permutation %d" % permutation_index)

func test_player_facing_copy_says_ten_and_another_home() -> void:
	assert_true(String(OpeningTutorial.COPY.B02).contains("ten connected road"))
	assert_true(String(OpeningTutorial.COPY.B08).contains("another home"))
	assert_false(String(OpeningTutorial.COPY.B08).to_lower().contains("first house"))

func _set_road_topology(roads: Node, cells: Array[Vector2i]) -> void:
	var graph: Dictionary = {}
	var lookup: Dictionary = {}
	for cell in cells:
		lookup[cell] = true
	for cell in cells:
		var cell_3d := Vector3i(cell.x, 0, cell.y)
		var neighbours: Array[Vector3i] = []
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbour: Vector2i = cell + offset
			if lookup.has(neighbour):
				neighbours.append(Vector3i(neighbour.x, 0, neighbour.y))
		graph[cell_3d] = neighbours
	roads._graph = graph
	roads._build_components()
	var root_component := String(roads._component_by_cell.get(Vector3i.ZERO, ""))
	roads._access_by_building = {
		roads.hall_internal_id: {
			"internal_id":roads.hall_internal_id,
			"road_accessible":not root_component.is_empty(),
			"stops":[{"x":0,"z":0}] if not root_component.is_empty() else [],
			"component_ids":[root_component] if not root_component.is_empty() else [],
			"reasons":[], "primary_reason":"",
		},
	}
	roads._revision += 1

func _permutations(rows: Array) -> Array:
	if rows.size() <= 1:
		return [rows.duplicate(true)]
	var result: Array = []
	for index in rows.size():
		var rest := rows.duplicate(true)
		var head: Variant = rest.pop_at(index)
		for suffix in _permutations(rest):
			var permutation: Array = [head]
			permutation.append_array(suffix)
			result.append(permutation)
	return result
