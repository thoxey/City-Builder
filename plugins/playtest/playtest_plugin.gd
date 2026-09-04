extends PluginBase

const SCENARIO_ROOT := "res://test/scenarios/"
const SNAPSHOT_SCHEMA := 1

var _builder: Node
var _catalog: PluginBase
var _clock: PluginBase
var _demand: PluginBase
var _economy: PluginBase
var _city_stats: PluginBase
var _satisfaction: PluginBase
var _residential: PluginBase
var _workplace: PluginBase
var _attractiveness: PluginBase
var _land: PluginBase
var _uniques: PluginBase
var _palette: PluginBase
var _dialogue: PluginBase
var _inbox: PluginBase
var _community: PluginBase

var _session_id := ""
var _scenario_id := ""
var _seed := 0
var _sequence := 0
var _status := "absent"
var _rng := RandomNumberGenerator.new()
var _request_cache: Dictionary = {}
var _request_order: Array[String] = []
var _trace: Array[Dictionary] = []
const REQUEST_CACHE_LIMIT := 256
const TRACE_LIMIT := 5000
const SNAPSHOT_COLLECTION_LIMIT := 10000

func get_plugin_name() -> String: return "Playtest"

func get_dependencies() -> Array[String]:
	return ["BuildingCatalog", "DayNight", "Demand", "Economy", "CityStats",
		"Satisfaction", "Residential", "Workplace", "Attractiveness",
		"BuildableArea", "UniqueRegistry", "Palette", "Dialogue", "Inbox", "Community"]

func inject(deps: Dictionary) -> void:
	_catalog = deps.get("BuildingCatalog")
	_clock = deps.get("DayNight")
	_demand = deps.get("Demand")
	_economy = deps.get("Economy")
	_city_stats = deps.get("CityStats")
	_satisfaction = deps.get("Satisfaction")
	_residential = deps.get("Residential")
	_workplace = deps.get("Workplace")
	_attractiveness = deps.get("Attractiveness")
	_land = deps.get("BuildableArea")
	_uniques = deps.get("UniqueRegistry")
	_palette = deps.get("Palette")
	_dialogue = deps.get("Dialogue")
	_inbox = deps.get("Inbox")
	_community = deps.get("Community")

func _plugin_ready() -> void:
	_builder = _find_builder()
	print("[Playtest] ready: active=%s builder=%s" % [OS.is_debug_build(), _builder != null])

func _find_builder() -> Node:
	var root := get_tree().current_scene if get_tree() else null
	if root == null:
		return null
	if root.has_method("try_place_building"):
		return root
	var found := root.find_child("Builder", true, false)
	return found if found and found.has_method("try_place_building") else null

func set_builder_for_tests(builder: Node) -> void:
	_builder = builder

func is_ready_for_commands() -> bool:
	return OS.is_debug_build() and _builder != null

func handle_command(operation: String, params: Dictionary) -> Dictionary:
	match operation:
		"start": return start_session(params)
		"get_state": return _require_session_state(params)
		"place": return _run_action("place", params)
		"demolish": return _run_action("demolish", params)
		"advance": return _run_action("advance", params)
		"get_choices": return get_choices(params)
	print("[Playtest] command_failed operation=%s reason=unknown_operation" % operation)
	return {"error": {"reason": "internal_error", "message": "Unknown playtest operation: %s" % operation}}

func start_session(params: Dictionary = {}) -> Dictionary:
	if not is_ready_for_commands():
		print("[Playtest] start_failed reason=game_not_ready")
		return {"error": {"reason": "game_not_ready", "message": "Builder is not ready"}}
	var scenario_id: String = params.get("scenario_id", "fresh_city")
	var scenario := _load_scenario(scenario_id)
	if scenario.is_empty():
		print("[Playtest] start_failed scenario=%s reason=unknown_scenario" % scenario_id)
		return {"error": {"reason": "internal_error", "message": "Unknown scenario: %s" % scenario_id}}
	_status = "starting"
	_scenario_id = scenario_id
	_seed = int(params.get("seed", 1))
	_rng.seed = _seed
	_sequence = 0
	_request_cache.clear()
	_request_order.clear()
	_trace.clear()
	_session_id = "%s-%d-%d" % [scenario_id, Time.get_ticks_usec(), _seed]
	var initial: Dictionary = scenario.get("initial_state", {})
	var fresh := DataMap.new()
	fresh.cash = int(initial.get("cash", fresh.cash))
	fresh.community_rng_seed = _seed
	_builder.reset_to_fresh_map(fresh)
	if _community and _community.has_method("apply_scenario_fixture"):
		_community.apply_scenario_fixture(scenario.get("fixture", {}), _seed)
	for runtime_plugin in [_economy, _city_stats, _satisfaction]:
		if runtime_plugin and runtime_plugin.has_method("reset_runtime_state"):
			runtime_plugin.reset_runtime_state()
	if _demand and _demand.has_method("reset_to_starting_state"):
		_demand.reset_to_starting_state(initial.get("demand", {}))
	if _clock and _clock.has_method("reset_manual_clock"):
		_clock.reset_manual_clock(int(initial.get("clock", {}).get("start_hour", 6)))
	if _dialogue and _dialogue.has_method("set_presentation_enabled"):
		_dialogue.set_presentation_enabled(false)
	if _inbox and _inbox.has_method("set_presentation_enabled"):
		_inbox.set_presentation_enabled(false)
	_status = "ready"
	var result := {"session": _session_record(), "snapshot": get_snapshot()}
	_append_trace("start", params, result)
	print("[Playtest] session_started scenario=%s seed=%d session=%s" % [_scenario_id, _seed, _session_id])
	return result

func _load_scenario(scenario_id: String) -> Dictionary:
	if not scenario_id.is_valid_filename() or scenario_id.contains("/") or scenario_id.contains("\\"):
		return {}
	var path := SCENARIO_ROOT + scenario_id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _session_record() -> Dictionary:
	return {
		"session_id": _session_id, "scenario_id": _scenario_id, "seed": _seed,
		"snapshot_schema": SNAPSHOT_SCHEMA, "sequence": _sequence,
		"status": _status, "clock_mode": "manual",
		"narrative_mode": "presentation_disabled",
	}

func _require_session_state(params: Dictionary = {}) -> Dictionary:
	if _status != "ready":
		print("[Playtest] state_failed reason=session_not_ready")
		return {"error": {"reason": "session_not_ready", "message": "Start a playtest session first"}}
	return {"session": _session_record(), "snapshot": get_snapshot(bool(params.get("compact", false)))}

func _run_action(kind: String, params: Dictionary) -> Dictionary:
	if _status != "ready":
		print("[Playtest] action_failed kind=%s reason=session_not_ready" % kind)
		return {"error": {"reason": "session_not_ready", "message": "Start a playtest session first"}}
	var request_id: String = params.get("request_id", "")
	if request_id.is_empty():
		print("[Playtest] action_failed kind=%s reason=missing_request_id" % kind)
		return {"error": {"reason": "internal_error", "message": "request_id is required"}}
	if _request_cache.has(request_id):
		var duplicate_outcome: Dictionary = _request_cache[request_id].duplicate(true)
		duplicate_outcome["status"] = PlaytestActionResult.STATUS_DUPLICATE
		duplicate_outcome["changed"] = false
		return duplicate_outcome
	if params.has("expected_sequence") and int(params["expected_sequence"]) != _sequence:
		var conflict := PlaytestActionResult.rejected(PlaytestActionResult.SEQUENCE_CONFLICT, {
			"expected_sequence": int(params["expected_sequence"]), "actual_sequence": _sequence,
		})
		conflict["request_id"] = request_id
		conflict["session_id"] = _session_id
		conflict["sequence"] = _sequence
		conflict["snapshot"] = get_snapshot()
		_cache_outcome(request_id, conflict)
		_append_trace(kind, params, conflict)
		return conflict
	var outcome: Dictionary
	match kind:
		"place":
			var anchor: Variant = _coordinate(params.get("anchor", {}))
			if anchor == null:
				outcome = PlaytestActionResult.rejected(PlaytestActionResult.INVALID_COORDINATE)
			else:
				var requested_id: String = params.get("building_id", params.get("choice_id", ""))
				outcome = _builder.try_place_building(requested_id, anchor,
					int(params.get("rotation", 0)), bool(params.get("replace", false)),
					String(params.get("variant_id", "")), _rng)
		"demolish":
			var cell: Variant = _coordinate(params.get("cell", {}))
			outcome = PlaytestActionResult.rejected(PlaytestActionResult.INVALID_COORDINATE) if cell == null else _builder.try_demolish_cell(cell)
		"advance":
			outcome = _clock.advance_hours(int(params.get("hours", -1)))
		_:
			outcome = PlaytestActionResult.rejected("internal_error")
	_sequence += 1
	outcome["request_id"] = request_id
	outcome["session_id"] = _session_id
	outcome["sequence"] = _sequence
	outcome["snapshot"] = get_snapshot()
	var safe: Dictionary = _json_safe(outcome)
	_cache_outcome(request_id, safe)
	_append_trace(kind, params, safe)
	if safe.get("status") == PlaytestActionResult.STATUS_REJECTED:
		print("[Playtest] action_rejected kind=%s request=%s reason=%s sequence=%d" % [kind, request_id, safe.get("reason", "unknown"), _sequence])
	return safe

func _cache_outcome(request_id: String, outcome: Dictionary) -> void:
	_request_cache[request_id] = outcome.duplicate(true)
	_request_order.append(request_id)
	while _request_order.size() > REQUEST_CACHE_LIMIT:
		_request_cache.erase(_request_order.pop_front())

func _append_trace(kind: String, request: Dictionary, outcome: Dictionary) -> void:
	_trace.append({
		"sequence": _sequence,
		"absolute_hour": _clock.get_absolute_hour() if _clock else 0,
		"kind": kind,
		"request": _json_safe(request),
		"status": outcome.get("status", outcome.get("session", {}).get("status", "observed")),
		"reason": outcome.get("reason"),
		"state_hash": outcome.get("snapshot", {}).get("state_hash", ""),
	})
	if _trace.size() > TRACE_LIMIT:
		_trace.pop_front()

func get_trace() -> Array:
	return _trace.duplicate(true)

func persist_completed_trace() -> Dictionary:
	if _status != "ready":
		return {"error": "session_not_ready"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://playtests"))
	var safe_id := _session_id.validate_filename()
	var path := "user://playtests/%s.json" % safe_id
	if FileAccess.file_exists(path):
		return {"error": "trace_already_exists", "path": path}
	var payload := {
		"schema_version": SNAPSHOT_SCHEMA, "session_id": _session_id,
		"scenario_id": _scenario_id, "seed": _seed, "entries": get_trace(),
		"final_snapshot": get_snapshot(),
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return {"error": "trace_write_failed"}
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	return {"path": path, "entries": _trace.size()}

func get_choices(params: Dictionary = {}) -> Dictionary:
	if _status != "ready":
		return {"error": {"reason": "session_not_ready", "message": "Start a playtest session first"}}
	var category_filter: String = params.get("category", "")
	var available_only: bool = params.get("available_only", false)
	var choices: Array = []
	if _palette == null:
		return {"choices": choices}
	for entry: Dictionary in _palette.get_entry_records():
		var variants: Array[String] = []
		var footprints: Array = []
		var reasons: Array[String] = []
		var category := ""
		var cash_cost := 0
		var demand_info: Variant = null
		var unique := false
		for sid: int in entry["structure_indices"]:
			var summary: Dictionary = _catalog.get_summary_by_index(sid)
			var id: String = summary.get("building_id", "")
			variants.append(id)
			category = summary.get("category", category)
			cash_cost = maxi(cash_cost, int(summary.get("cash_cost", 0)))
			var structure: Structure = _catalog.get_all()[sid]
			var cells: Array = []
			for cell in structure.footprint: cells.append(_coord(cell))
			footprints.append({"variant_id": id, "cells": cells})
			var cash_quote: Dictionary = _economy.quote_cash(structure) if _economy else {"ok": true}
			var demand_quote: Dictionary = _demand.quote_placement(structure) if _demand else {"ok": true, "bucket_id": ""}
			if not cash_quote["ok"] and PlaytestActionResult.INSUFFICIENT_CASH not in reasons: reasons.append(PlaytestActionResult.INSUFFICIENT_CASH)
			if not demand_quote["ok"]:
				var code := PlaytestActionResult.BELOW_DEMAND_THRESHOLD if demand_quote["reason"] == "below_threshold" else PlaytestActionResult.INSUFFICIENT_DEMAND
				if code not in reasons: reasons.append(code)
			if not String(demand_quote.get("bucket_id", "")).is_empty(): demand_info = demand_quote
			if _uniques and _uniques.is_unique(id):
				unique = true
				for reason in _uniques.evaluate_unlock(id)["reasons"]:
					if reason not in reasons: reasons.append(reason)
		variants.sort()
		reasons.sort()
		var available := reasons.is_empty()
		if not category_filter.is_empty() and category != category_filter: continue
		if available_only and not available: continue
		choices.append({
			"choice_id": entry["id"], "display_name": entry["display_name"],
			"variants": variants, "category": category, "tier": _tier_for(entry["id"]),
			"footprints": footprints, "cash_cost": cash_cost, "demand": demand_info,
			"unique": unique, "available": available, "reasons": reasons,
		})
	choices.sort_custom(func(a: Dictionary, b: Dictionary): return a["choice_id"] < b["choice_id"])
	return {"choices": choices}

func _tier_for(choice_id: String) -> Variant:
	var marker := choice_id.rfind("_t")
	if marker < 0:
		return null
	return int(choice_id.substr(marker + 2))

func _coordinate(value: Variant) -> Variant:
	if not value is Dictionary or not value.has("x") or not value.has("z"):
		return null
	if not value["x"] is int and not value["x"] is float:
		return null
	if not value["z"] is int and not value["z"] is float:
		return null
	return Vector2i(int(value["x"]), int(value["z"]))

func get_snapshot(compact: bool = false) -> Dictionary:
	var buildings := _building_records()
	var allowed := _sorted_coordinates(_land.allowed_cells() if _land else [])
	var land_counts := _land_counts()
	var choice_records: Array = get_choices().get("choices", []) if _status == "ready" else []
	var available_choice_count := 0
	var tier_two_available := false
	for choice: Dictionary in choice_records:
		if not choice.get("available", false):
			continue
		available_choice_count += 1
		if choice.get("tier") == 2:
			tier_two_available = true
	var satisfaction_parts: Dictionary = _city_stats.get_satisfaction_snapshot() if _city_stats else {}
	var snapshot := {
		"schema_version": SNAPSHOT_SCHEMA,
		"session_id": _session_id,
		"sequence": _sequence,
		"simulation": {
			"day": _clock.get_absolute_hour() / 24 if _clock else 0,
			"hour": _clock.current_hour() if _clock else 0,
			"absolute_hour": _clock.get_absolute_hour() if _clock else 0,
			"manual": _clock.is_manual() if _clock else false,
		},
		"economy": {
			"cash": GameState.map.cash if GameState.map else 0,
			"last_hourly_income": _economy.get_last_hourly_income() if _economy else 0,
			"industrial_output": _workplace.get_total_output() if _workplace else 0,
		},
		"population": {
			"current": _community.get_population() if _community else (_residential.get_current_population() if _residential else 0),
			"residential_capacity": _residential.get_total_capacity() if _residential else 0,
		},
		"community": _community.get_snapshot(compact) if _community else {},
		"satisfaction": {
			"score": _rounded(_satisfaction.get_score() if _satisfaction else 1.0),
			"components": _rounded_dictionary(satisfaction_parts),
		},
		"attractiveness": {
			"total": _attractiveness.city_score() if _attractiveness else 0,
			"tiles": _attractiveness_tiles(),
		},
		"demand": _demand_snapshot(),
		"land": {
			"allowed_count": allowed.size(),
			"occupied_count": land_counts["occupied_count"],
			"free_count": maxi(0, allowed.size() - land_counts["occupied_count"]),
			"allowed_cells": allowed,
		},
		"buildings": buildings,
		"progression": _progression_snapshot(),
		"available_choice_count": available_choice_count,
		"tier_two_available": tier_two_available,
	}
	var hash_payload := snapshot.duplicate(true)
	hash_payload.erase("session_id")
	hash_payload.erase("sequence")
	snapshot["state_hash"] = JSON.stringify(hash_payload).sha256_text()
	# Presentation parity is exposed to live acceptance tooling but deliberately
	# excluded from the deterministic simulation hash.
	if _community and not compact and _community.has_method("get_ui_model"):
		snapshot["community_ui"] = _community.get_ui_model()
	return snapshot

func _land_counts() -> Dictionary:
	var allowed_lookup := {}
	if _land:
		for cell: Vector2i in _land.allowed_cells():
			allowed_lookup[cell] = true
	var occupied_lookup := {}
	for entry: Dictionary in GameState.building_registry.values():
		for cell: Vector2i in entry.get("cells", []):
			if allowed_lookup.has(cell):
				occupied_lookup[cell] = true
	return {"occupied_count": occupied_lookup.size()}

func _building_records() -> Array:
	var records: Array = []
	for internal_id in GameState.building_registry:
		if records.size() >= SNAPSHOT_COLLECTION_LIMIT: break
		var entry: Dictionary = GameState.building_registry[internal_id]
		var sid: int = entry.get("structure", -1)
		var building_id: String = _catalog.get_id_by_index(sid) if _catalog else ""
		var summary: Dictionary = _catalog.get_summary_by_index(sid) if _catalog else {}
		records.append({
			"building_id": building_id,
			"anchor": _coord(entry.get("anchor", Vector2i.ZERO)),
			"rotation": _builder._orientation_to_steps(int(entry.get("orientation", 0))),
			"footprint": _sorted_coordinates(entry.get("cells", [])),
			"category": summary.get("category", ""),
			"pool_id": null if summary.get("pool_id", "").is_empty() else summary.get("pool_id"),
			"unique": _uniques.is_unique(building_id) if _uniques else false,
		})
	records.sort_custom(func(a: Dictionary, b: Dictionary):
		if a["anchor"]["x"] != b["anchor"]["x"]: return a["anchor"]["x"] < b["anchor"]["x"]
		if a["anchor"]["z"] != b["anchor"]["z"]: return a["anchor"]["z"] < b["anchor"]["z"]
		return a["building_id"] < b["building_id"])
	return records

func _demand_snapshot() -> Dictionary:
	var result := {}
	for bucket_id in ["residential", "industrial", "commercial"]:
		result[bucket_id] = _rounded_dictionary(_demand.get_bucket_snapshot(bucket_id)) if _demand else {}
	return result

func _progression_snapshot() -> Dictionary:
	var result := {"unlocked": [], "placed": []}
	if _uniques == null:
		return result
	for id in _uniques.get_all_profiles().keys():
		if _uniques.is_unlocked(id): result["unlocked"].append(id)
		if _uniques.is_placed(id): result["placed"].append(id)
	result["unlocked"].sort()
	result["placed"].sort()
	return result

func _attractiveness_tiles() -> Array:
	var rows: Array = []
	if _attractiveness == null: return rows
	for cell in _attractiveness.score_snapshot():
		rows.append({"cell": _coord(cell), "score": _attractiveness.get_score(cell)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary):
		return a["cell"]["x"] < b["cell"]["x"] if a["cell"]["x"] != b["cell"]["x"] else a["cell"]["z"] < b["cell"]["z"])
	return rows

func _coord(value: Vector2i) -> Dictionary:
	return {"x": value.x, "z": value.y}

func _sorted_coordinates(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if result.size() >= SNAPSHOT_COLLECTION_LIMIT: break
		result.append(_coord(value))
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		return a["x"] < b["x"] if a["x"] != b["x"] else a["z"] < b["z"])
	return result

func _rounded(value: float) -> float:
	return snappedf(value, 0.0001)

func _rounded_dictionary(values: Dictionary) -> Dictionary:
	var result := {}
	for key in values:
		result[str(key)] = _rounded(float(values[key])) if values[key] is float else values[key]
	return result

func _json_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2I: return _coord(value)
		TYPE_VECTOR3I: return {"x": value.x, "y": value.y, "z": value.z}
		TYPE_ARRAY:
			var result: Array = []
			for item in value: result.append(_json_safe(item))
			return result
		TYPE_DICTIONARY:
			var result := {}
			for key in value: result[str(key)] = _json_safe(value[key])
			return result
	return value
