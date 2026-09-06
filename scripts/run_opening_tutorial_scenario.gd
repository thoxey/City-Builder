extends SceneTree

const SCENARIO_ID := "first_town/opening_balance"
const SCENARIO_SEED := 12012
const SAVE_PATH := "/tmp/starter-kit-opening-tutorial-scenario.res"
const EXPECTED_RECEIPTS := [
	"opening.adjacent_home_observed",
	"opening.first_home_placed",
	"opening.first_shop_placed",
	"opening.home_improved",
	"opening.nature_established",
	"opening.rooted_roads_connected",
	"opening.town_hall_placed",
	"opening.work_participation_confirmed",
	"opening.workplace_established",
]
const EVENT_IDS := [
	"tutorial_opening_beauty_homes",
	"tutorial_opening_home_adjacency",
	"tutorial_opening_work_participation",
	"tutorial_opening_complete",
]

var _failures: Array[String] = []
var _handoffs: Array = []
var _game_events: Node
var _game_state: Node
var _verification_flags := {
	"early_action_reconciled": false,
	"duplicate_reconcile_idempotent": false,
	"demolition_non_regression": false,
	"cold_load_parity": false,
	"legacy_grass_identity": false,
	"legacy_grass_inspection_demolition": false,
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if FileAccess.file_exists(SAVE_PATH): DirAccess.remove_absolute(SAVE_PATH)
	change_scene_to_file("res://scenes/main.tscn")
	for _frame in 12: await process_frame
	var manager = root.get_node_or_null("PluginManager")
	_game_events = root.get_node_or_null("GameEvents")
	_game_state = root.get_node_or_null("GameState")
	var builder = current_scene.get_node_or_null("Builder") if current_scene else null
	var playtest = manager.get_plugin("Playtest") if manager else null
	var tutorial = manager.get_plugin("OpeningTutorial") if manager else null
	var community = manager.get_plugin("Community") if manager else null
	var catalog = manager.get_plugin("BuildingCatalog") if manager else null
	var palette = manager.get_plugin("Palette") if manager else null
	var dashboard = manager.get_plugin("Dashboard") if manager else null
	if manager == null or builder == null or playtest == null or tutorial == null or community == null or catalog == null or palette == null or dashboard == null:
		_fail("real_stack_unavailable")
		_finish(tutorial)
		return
	var started: Dictionary = playtest.start_session({"scenario_id": SCENARIO_ID, "seed": SCENARIO_SEED})
	_check(not started.has("error"), "session_start_failed")
	await _settle()
	_check(str(tutorial.get_projection().get("text", "")).begins_with("AMBROSE PLACEHOLDER:"), "placeholder_projection_missing")

	await _place(builder, "building_town_hall", Vector2i(-1, -1))
	for x in range(-1, 7): await _place(builder, "road", Vector2i(x, 1))
	await _place(builder, "road", Vector2i(7, 1))
	await _place(builder, "road", Vector2i(7, 2))
	_check(int(tutorial.get_evidence_snapshot().get("rooted_road_count", 0)) >= 10, "rooted_road_gate_failed")
	# A rooted shop is deliberately committed before nature, homes, work, and
	# participation. Ordered reconciliation must remember the world fact but
	# cannot skip the earlier semantic gates.
	_game_events.tutorial_opening_completed.connect(_on_handoff)
	await _place(builder, "building_small_b", Vector2i(4, 0))
	_check(not tutorial.is_complete(), "early_shop_skipped_prerequisites")
	_check(not tutorial.get_state().get("completed_receipts", {}).has("opening.first_shop_placed"), "early_shop_receipt_written_out_of_order")
	await _place(builder, "grass_trees", Vector2i(-7, -7))
	await _place(builder, "grass_trees_tall", Vector2i(-6, -7))
	_check(tutorial.get_evidence_snapshot().get("nature_building_ids", []) == ["grass_trees", "grass_trees_tall"], "distinct_nature_gate_failed")
	_check(int(tutorial.get_evidence_snapshot().get("city_attractiveness", 0)) > 0, "positive_beauty_gate_failed")

	await _place(builder, "building_small_a", Vector2i(2, 0))
	await _place(builder, "building_small_a", Vector2i(3, 0))
	var adjacent_state: Dictionary = tutorial.get_state()
	var adjacency_delta := int(adjacent_state.get("experiment", {}).get("after_adjacency", {}).get("home_delta", 0))
	_check(str(adjacent_state.get("experiment", {}).get("adjacency_result", "")) == "penalty_observed", "adjacency_penalty_not_observed")
	_check(adjacency_delta < 0, "adjacency_delta_not_negative")

	await _place(builder, "grass_trees", Vector2i(2, -1))
	var repaired_state: Dictionary = tutorial.get_state()
	var after_repair: Variant = repaired_state.get("experiment", {}).get("after_repair")
	_check(after_repair is Dictionary, "repair_measurement_missing")
	var repair_delta := int(after_repair.get("home_delta", 0)) if after_repair is Dictionary else 0
	_check(repair_delta > 0, "repair_delta_not_positive")
	await _place(builder, "building_garage", Vector2i(6, 0))
	_check(repaired_state.get("completed_receipts", {}).has("opening.home_improved"), "repair_receipt_missing")
	_check(tutorial.get_state().get("completed_receipts", {}).has("opening.workplace_established"), "workplace_receipt_missing")

	community.apply_scenario_fixture({"residents": [{
		"resident_id": 1, "seed": 1201201, "cohort_id": "general",
		"home_anchor": {"x": 2, "z": 0},
	}]}, SCENARIO_SEED)
	var advanced: Dictionary = playtest.handle_command("advance", {
		"hours": 2, "request_id": "opening-tutorial-work-shift", "snapshot_mode": "none",
	})
	_check(str(advanced.get("status", "")) == PlaytestActionResult.STATUS_APPLIED, "work_shift_advance_failed")
	await _settle()
	_check(tutorial.get_state().get("completed_receipts", {}).has("opening.work_participation_confirmed"), "work_participation_receipt_missing")

	var completed_state: Dictionary = tutorial.get_state()
	var receipts: Array = completed_state.get("completed_receipts", {}).keys()
	receipts.sort()
	_verification_flags.early_action_reconciled = completed_state.get("completed_receipts", {}).get("opening.first_shop_placed", {}).get("evidence", {}).get("anchor", {}) == {"x": 4, "z": 0}
	_check(bool(_verification_flags.early_action_reconciled), "early_shop_not_reconciled")
	_check(tutorial.is_complete(), "tutorial_not_complete")
	_check(receipts == EXPECTED_RECEIPTS, "receipt_set_mismatch")
	_check(_handoffs.size() == 1, "handoff_count_before_load")
	if not _handoffs.is_empty():
		_check(bool(_handoffs[0].get("persisted", false)), "handoff_emitted_before_persistence")
		_check(str(_handoffs[0].get("payload", {}).get("shop_building_id", "")) == "building_small_b", "handoff_shop_identity_mismatch")

	var event_counts := {}
	for event_id in EVENT_IDS:
		event_counts[event_id] = int(_game_state.map.event_counts.get(event_id, 0))
		_check(int(event_counts[event_id]) == 1, "event_count_%s" % event_id)

	var handoffs_before_duplicate := _handoffs.size()
	var state_before_duplicate: Dictionary = tutorial.get_state()
	tutorial.reconcile("scenario_duplicate_1")
	tutorial.reconcile("scenario_duplicate_2")
	_verification_flags.duplicate_reconcile_idempotent = tutorial.get_state() == state_before_duplicate and _handoffs.size() == handoffs_before_duplicate
	_check(bool(_verification_flags.duplicate_reconcile_idempotent), "duplicate_reconcile_changed_completion")

	var demolition: Dictionary = builder.try_demolish_cell(Vector2i(4, 0))
	_check(str(demolition.get("status", "")) == PlaytestActionResult.STATUS_APPLIED, "completed_shop_demolition_failed")
	await _settle()
	completed_state = tutorial.get_state()
	_verification_flags.demolition_non_regression = tutorial.is_complete() and completed_state.get("completed_receipts", {}).has("opening.first_shop_placed") and _handoffs.size() == handoffs_before_duplicate
	_check(bool(_verification_flags.demolition_non_regression), "demolition_regressed_completion")

	# Plain grass is deliberately placed by its historical exact ID, not through
	# the curated pool, to prove old saves retain their catalogue identity.
	await _place(builder, "grass", Vector2i(7, -7))
	var grass_pool_record: Dictionary = {}
	for entry in palette.get_entry_records():
		if str(entry.get("id", "")) == "grass": grass_pool_record = entry
	var grass_pool_ids: Array[String] = []
	for structure_index in grass_pool_record.get("structure_indices", []):
		grass_pool_ids.append(catalog.get_id_by_index(int(structure_index)))
	_check(grass_pool_ids == ["grass_trees", "grass_trees_tall"], "grass_pool_not_curated")

	var save_result: Dictionary = builder.save_map_to_path(SAVE_PATH)
	_check(str(save_result.get("status", "")) == PlaytestActionResult.STATUS_APPLIED, "save_failed")
	var before_load_hash := _state_hash(completed_state)
	var load_result: Dictionary = builder.load_map_from_path(SAVE_PATH)
	_check(str(load_result.get("status", "")) == PlaytestActionResult.STATUS_APPLIED, "load_failed")
	await _settle()
	var loaded_state: Dictionary = tutorial.get_state()
	_check(loaded_state == completed_state, "cold_load_state_mismatch")
	_check(_handoffs.size() == 1, "cold_load_reemitted_handoff")
	_check(_state_hash(loaded_state) == before_load_hash, "cold_load_hash_mismatch")
	_verification_flags.cold_load_parity = loaded_state == completed_state and _handoffs.size() == 1 and _state_hash(loaded_state) == before_load_hash
	var grass_instance_id := int(_game_state.cell_to_building.get(Vector2i(7, -7), -1))
	var grass_record: Dictionary = _game_state.building_registry.get(grass_instance_id, {})
	_verification_flags.legacy_grass_identity = grass_instance_id >= 0 and catalog.get_id_by_index(int(grass_record.get("structure", -1))) == "grass"
	_check(bool(_verification_flags.legacy_grass_identity), "legacy_grass_identity_lost")
	var community_panel: Variant = dashboard.get("_community_panel")
	dashboard.open_community()
	if community_panel:
		community_panel.show_section("places")
	var notifications_before := int(community_panel.get("_notifications").size()) if community_panel else -1
	_game_events.community_place_selected.emit(Vector2i(7, -7))
	await _settle()
	# Plain grass is cosmetic-only and therefore has no Community-effect detail
	# card. Its normal inspection result is the explicit no-data notice, not a
	# fabricated effect record. Assert that the inspector actually consumed the
	# selection before proving demolition compatibility.
	var inspection_ok: bool = false
	if community_panel:
		var notifications: Array = community_panel.get("_notifications")
		inspection_ok = (str(community_panel.get("_section")) == "places"
			and notifications.size() == notifications_before + 1
			and str(notifications.back()) == "No Community effect data for that place")
	_check(inspection_ok, "legacy_grass_inspection_failed")
	var grass_demolition: Dictionary = builder.try_demolish_cell(Vector2i(7, -7))
	_verification_flags.legacy_grass_inspection_demolition = (inspection_ok
		and str(grass_demolition.get("status", "")) == PlaytestActionResult.STATUS_APPLIED
		and not _game_state.cell_to_building.has(Vector2i(7, -7)))
	_check(bool(_verification_flags.legacy_grass_inspection_demolition), "legacy_grass_inspection_or_demolition_failed")
	for event_id in EVENT_IDS:
		_check(int(_game_state.map.event_counts.get(event_id, 0)) == 1, "cold_load_event_count_%s" % event_id)
	if _game_events.tutorial_opening_completed.is_connected(_on_handoff): _game_events.tutorial_opening_completed.disconnect(_on_handoff)
	if FileAccess.file_exists(SAVE_PATH): DirAccess.remove_absolute(SAVE_PATH)
	_finish(tutorial, receipts, event_counts, adjacency_delta, repair_delta)

func _place(builder: Node, building_id: String, anchor: Vector2i) -> void:
	var outcome: Dictionary = builder.try_place_building(building_id, anchor)
	_check(str(outcome.get("status", "")) == PlaytestActionResult.STATUS_APPLIED,
		"placement_failed:%s:%d,%d:%s" % [building_id, anchor.x, anchor.y, str(outcome.get("reason", ""))])
	await _settle()

func _settle() -> void:
	await process_frame
	await process_frame

func _on_handoff(payload: Dictionary) -> void:
	_handoffs.append({
		"payload": payload.duplicate(true),
		"persisted": bool(_game_state.map.opening_tutorial_state.get("completion_handoff", {}).get("applied", false)),
	})

func _check(ok: bool, failure: String) -> void:
	if not ok: _fail(failure)

func _fail(failure: String) -> void:
	if failure not in _failures: _failures.append(failure)

func _finish(tutorial, receipts: Array = [], event_counts: Dictionary = {}, adjacency_delta: int = 0, repair_delta: int = 0) -> void:
	var state: Dictionary = tutorial.get_state() if tutorial else {}
	var result := {
		"success": _failures.is_empty(),
		"scenario_id": SCENARIO_ID,
		"seed": SCENARIO_SEED,
		"receipts": receipts,
		"handoff_count": _handoffs.size(),
		"event_counts": event_counts,
		"adjacency_home_delta": adjacency_delta,
		"repair_home_delta": repair_delta,
		"experiment": state.get("experiment", {}).duplicate(true),
		"verification": _verification_flags,
		"state_hash": _state_hash(state),
		"failures": _failures,
	}
	print("OPENING_TUTORIAL_RESULT %s" % JSON.stringify(result))
	quit(0 if _failures.is_empty() else 1)

func _state_hash(state: Dictionary) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(_canonical(state).to_utf8_buffer())
	return context.finish().hex_encode()

func _canonical(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(a, b): return str(a) < str(b))
		var pairs: Array[String] = []
		for key in keys: pairs.append("%s:%s" % [JSON.stringify(str(key)), _canonical(value[key])])
		return "{%s}" % ",".join(pairs)
	if value is Array:
		var items: Array[String] = []
		for item in value: items.append(_canonical(item))
		return "[%s]" % ",".join(items)
	return JSON.stringify(value)
