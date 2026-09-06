extends SceneTree

const SCENARIO_ID := "first_town/rebalance"
const EVIDENCE_PATH := "res://specs/006-connected-first-town-loop/validation/rebalance-last-run.json"
const CHECKPOINTS := {60: 15, 120: 30, 240: 60}
const SCENARIO_SEED := 6066

var _failures: Array[String] = []
var _checkpoints: Array = []
var _meaningful_placements := 0
var _meaningful_attempts := 0
var _successful_attempts := 0
var _request_number := 0
var _peak_operating := 0
var _candidate_cells: Array[Vector2i] = []
var _next_candidate := 0
var _hour_timings: Array = []
var _profiled_action_usec := 0
var _profiled_snapshot_usec := 0
var _scenario_started_usec := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_scenario_started_usec = Time.get_ticks_usec()
	change_scene_to_file("res://scenes/main.tscn")
	for _frame in 12: await process_frame
	var manager = root.get_node("PluginManager")
	var playtest = manager.get_plugin("Playtest")
	var builder = current_scene.get_node("Builder")
	var road_network = manager.get_plugin("RoadNetwork")
	var community = manager.get_plugin("Community")
	var catalog = manager.get_plugin("BuildingCatalog")
	var started: Dictionary = playtest.start_session({"scenario_id": SCENARIO_ID, "seed": SCENARIO_SEED})
	if started.has("error"):
		_failures.append("session_start_failed")
		_finish(playtest, road_network, community, catalog)
		return

	var blocked: Dictionary = builder.try_place_building("building_small_a", Vector2i(-3, 0))
	_assert(blocked.get("reason") == PlaytestActionResult.TOWN_HALL_REQUIRED,
		"A functional building before Town Hall must be rejected with town_hall_required")
	_place(playtest, "building_town_hall", Vector2i(-1, -1), true)
	var duplicate: Dictionary = builder.try_place_building("building_town_hall", Vector2i(3, 3))
	_assert(duplicate.get("reason") == PlaytestActionResult.TOWN_HALL_ALREADY_PLACED,
		"A second Town Hall must be rejected with town_hall_already_placed")
	var replacement: Dictionary = builder.try_place_building("road", Vector2i(-1, -1), 0, true)
	_assert(replacement.get("reason") == PlaytestActionResult.DEMOLITION_NOT_ALLOWED,
		"Replacement must not bypass Town Hall demolition protection")
	_build_road_grid(playtest)
	_build_candidates()
	_fill_to_target(playtest, builder, 14)

	for absolute_hour in range(4, 241, 4):
		_apply(playtest, "advance", {"hours": 4}, false)
		var target := int(floor(float(absolute_hour) / 4.0))
		_fill_to_target(playtest, builder, target)
		if CHECKPOINTS.has(absolute_hour):
			var snapshot: Dictionary = playtest.get_snapshot(true)
			_peak_operating = maxi(_peak_operating, snapshot.get("operation", []).filter(func(row): return bool(row.get("operating", false))).size())
			var required := int(CHECKPOINTS[absolute_hour])
			_checkpoints.append({
				"absolute_hour": absolute_hour,
				"real_minutes": absolute_hour / 12,
				"required_meaningful_placements": required,
				"actual_meaningful_placements": _meaningful_placements,
				"cash": snapshot.get("economy", {}).get("cash", -1),
				"state_hash": snapshot.get("state_hash", ""),
			})
			_assert(_meaningful_placements >= required,
				"Cadence missed at %d hours: %d/%d meaningful placements" % [absolute_hour, _meaningful_placements, required])
			_assert(int(snapshot.get("economy", {}).get("cash", -1)) >= 0,
				"Cash must remain non-negative at cadence checkpoints")

	await _capture_midgame(manager)
	_finish(playtest, road_network, community, catalog)

func _build_road_grid(playtest) -> void:
	var roads: Array[Vector2i] = []
	for x in range(0, 7): roads.append(Vector2i(x, 1))
	for x in range(-1, -8, -1): roads.append(Vector2i(x, 1))
	for x in [-4, 1, 5]:
		for z in range(2, 7): roads.append(Vector2i(x, z))
		for z in range(0, -8, -1):
			if not Vector2i(x, z) in [Vector2i(-1,-1), Vector2i(0,-1), Vector2i(-1,0), Vector2i(0,0)]:
				roads.append(Vector2i(x, z))
	for z in [-4, 5]:
		# Grow away from the already-rooted x=1 intersection in both directions.
		for x in [0, -1, -2, -3, -5, -6, -7, 2, 3, 4, 6]:
			var cell := Vector2i(x, z)
			if cell not in roads: roads.append(cell)
	for cell in roads:
		_place(playtest, "road", cell, false)

func _build_candidates() -> void:
	var road_lines_z := [-4, 1, 5]
	var road_lines_x := [-4, 1, 5]
	var reserved := {Vector2i(-1,-1):true, Vector2i(0,-1):true, Vector2i(-1,0):true, Vector2i(0,0):true}
	for z in range(-7, 7):
		for x in range(-7, 7):
			var cell := Vector2i(x, z)
			if z in road_lines_z or x in road_lines_x or reserved.has(cell): continue
			if (z - 1 in road_lines_z) or (z + 1 in road_lines_z) or (x - 1 in road_lines_x) or (x + 1 in road_lines_x):
				_candidate_cells.append(cell)

func _fill_to_target(playtest, builder, target: int) -> void:
	# Four homes per shop/workplace is the intended opening-town silhouette;
	# useful nature remains part of every cycle so growth does not form a block.
	var ids := ["building_small_a", "building_small_a", "building_small_b",
		"building_small_a", "building_nature_patch", "building_garage",
		"building_small_a", "building_nature_patch"]
	var stalled := 0
	while _meaningful_placements < target and _next_candidate < _candidate_cells.size() and stalled < ids.size():
		var building_id: String = ids[_meaningful_placements % ids.size()]
		var cell := _candidate_cells[_next_candidate]
		var evaluation: Dictionary = builder.evaluate_placement(building_id, cell)
		if not bool(evaluation.get("ok", false)):
			stalled += 1
			# Try the next category without consuming the connected frontage cell.
			ids.push_back(ids.pop_front())
			continue
		stalled = 0
		_next_candidate += 1
		_place(playtest, building_id, cell, true)

func _place(playtest, building_id: String, cell: Vector2i, meaningful: bool) -> void:
	var outcome := _apply(playtest, "place", {"building_id": building_id, "anchor": {"x": cell.x, "z": cell.y}}, meaningful)
	if meaningful and String(outcome.get("status", "")) == PlaytestActionResult.STATUS_APPLIED:
		_meaningful_placements += 1

func _apply(playtest, operation: String, params: Dictionary, meaningful: bool) -> Dictionary:
	_request_number += 1
	params["request_id"] = "rebalance-%04d" % _request_number
	params["snapshot_mode"] = "none"
	params["profile"] = true
	if meaningful: _meaningful_attempts += 1
	var outcome: Dictionary = playtest.handle_command(operation, params)
	var action_performance: Dictionary = outcome.get("performance", {})
	_profiled_action_usec += int(action_performance.get("command_usec", 0))
	_profiled_snapshot_usec += int(action_performance.get("snapshot_usec", 0))
	if operation == "advance":
		_hour_timings.append_array(outcome.get("details", {}).get("performance", {}).get("hour_timings", []))
	if meaningful and String(outcome.get("status", "")) == PlaytestActionResult.STATUS_APPLIED:
		_successful_attempts += 1
	if String(outcome.get("status", "")) != PlaytestActionResult.STATUS_APPLIED:
		_failures.append("%s failed at request %d: %s" % [operation, _request_number, outcome])
	return outcome

func _finish(playtest, road_network, community, catalog) -> void:
	var snapshot: Dictionary = playtest.get_snapshot() if playtest else {}
	_peak_operating = maxi(_peak_operating, snapshot.get("operation", []).filter(func(row): return bool(row.get("operating", false))).size())
	var game_state = root.get_node("GameState")
	var categories := {}
	var functional_nature := 0
	var rooted_failures: Array = []
	for building in snapshot.get("buildings", []):
		var building_id := String(building.get("building_id", ""))
		var summary: Dictionary = catalog.get_summary_by_id(building_id) if catalog else {}
		if building_id == "building_town_hall": categories["civic"] = int(categories.get("civic", 0)) + 1
		var catalog_category := String(summary.get("category", ""))
		if catalog_category in ["road", "nature"]:
			categories[catalog_category] = int(categories.get(catalog_category, 0)) + 1
		var sid := int(catalog.get_item_index(building_id)) if catalog else -1
		var profile := game_state.structures[sid].find_metadata(BuildingProfile) as BuildingProfile if sid >= 0 else null
		if profile: categories[profile.category] = int(categories.get(profile.category, 0)) + 1
		if String(summary.get("category", "")) == "nature" and String(summary.get("community_role", "")) == "functional": functional_nature += 1
		if String(summary.get("community_role", "")) == "functional":
			var point: Dictionary = building.get("anchor", {})
			var anchor := Vector2i(int(point.get("x", 0)), int(point.get("z", 0)))
			var internal_id := int(game_state.cell_to_building.get(anchor, -1))
			var access: Dictionary = road_network.get_access_for_building(internal_id)
			if not bool(access.get("road_accessible", false)): rooted_failures.append(building_id)
	var proximity_records: Array = []
	if community:
		for source in community.get_presentation_context(12).get("places", []):
			if String(source.get("category", "")) in ["residential", "commercial"]:
				proximity_records.append({"building_id":source.get("building_id"), "anchor":CommunityConstants.coordinate_record(source.get("anchor")), "proximity":source.get("town_hall_proximity", {}), "effects":source.get("effects", [])})
	var has_home_penalty := proximity_records.any(func(row): return row.effects.any(func(effect): return String(effect.get("effect_id", "")).begins_with("town_hall_bustle")))
	var has_shop_bonus := proximity_records.any(func(row): return String(row.building_id).begins_with("building_small_b") and float(row.proximity.get("shop_activity_bonus", 0.0)) > 0.0)
	var success_rate := float(_successful_attempts) / float(maxi(1, _meaningful_attempts))
	var operating_count: int = snapshot.get("operation", []).filter(func(row): return bool(row.get("operating", false))).size()
	_assert(success_rate >= 0.9, "At least 90% of meaningful placement attempts must succeed")
	_assert(_meaningful_placements >= 60, "Twenty-minute town must contain at least 60 meaningful structures")
	_assert(categories.size() >= 4, "Twenty-minute town must span at least four functional categories")
	_assert(functional_nature >= 2, "Twenty-minute town must contain at least two functional nature places")
	_assert(int(categories.get("residential", 0)) + int(categories.get("commercial", 0)) + int(categories.get("industrial", 0)) >= 40,
		"Twenty-minute town must contain at least 40 homes, shops, and workplaces")
	_assert(rooted_failures.is_empty(), "Every functional building must remain attached to the Town Hall-rooted road network")
	_assert(has_home_penalty, "A home within ten road tiles must expose the Town Hall liveability penalty")
	_assert(has_shop_bonus, "A shop within ten road tiles must expose the Town Hall activity bonus")
	_assert(int(snapshot.get("economy", {}).get("ledger", {}).get("cumulative_shop_proximity_income", 0)) > 0,
		"The nearby-shop bonus must produce incremental income during the run")
	_assert(_peak_operating > 0 and int(snapshot.get("economy", {}).get("ledger", {}).get("cumulative_income", 0)) > 0,
		"The run must have positive operation and cumulative income")
	_assert(int(snapshot.get("available_choice_count", 0)) > 1, "Useful build choices must remain available")
	var final_summary := {
		"state_hash":snapshot.get("state_hash", ""), "simulation":snapshot.get("simulation", {}),
		"economy":snapshot.get("economy", {}), "population":snapshot.get("population", {}),
		"community": {"average_qualities":snapshot.get("community", {}).get("average_qualities", {}), "migration":snapshot.get("community", {}).get("migration", {})},
		"demand":snapshot.get("demand", {}), "land": {"allowed_count":snapshot.get("land", {}).get("allowed_count", 0), "occupied_count":snapshot.get("land", {}).get("occupied_count", 0), "free_count":snapshot.get("land", {}).get("free_count", 0)},
		"road_cell_count":snapshot.get("connectivity", {}).get("road_cell_count", 0),
		"operation":snapshot.get("operation", []), "available_choice_count":snapshot.get("available_choice_count", 0),
		"building_manifest":snapshot.get("buildings", []),
	}
	var max_hour_usec := 0
	var max_migration_usec := 0
	var total_tick_usec := 0
	for timing in _hour_timings:
		var elapsed_usec := int(timing.get("elapsed_usec", 0))
		total_tick_usec += elapsed_usec
		max_hour_usec = maxi(max_hour_usec, elapsed_usec)
		if bool(timing.get("migration_boundary", false)):
			max_migration_usec = maxi(max_migration_usec, elapsed_usec)
	var evidence := {
		"schema_version": 2, "scenario_id": SCENARIO_ID, "seed": SCENARIO_SEED,
		"success": _failures.is_empty(), "failures": _failures,
		"criteria": {"meaningful_placements":_meaningful_placements, "meaningful_attempts":_meaningful_attempts,
			"successful_attempts":_successful_attempts, "success_rate":success_rate,
			"categories":categories, "functional_nature":functional_nature, "rooted_failures":rooted_failures,
			"has_home_penalty":has_home_penalty, "has_shop_bonus":has_shop_bonus,
			"final_operating_count":operating_count, "peak_operating_count":_peak_operating,
			"useful_choice_count":snapshot.get("available_choice_count", 0)},
		"checkpoints": _checkpoints, "proximity_records": proximity_records,
		"performance": {
			"scenario_elapsed_usec": Time.get_ticks_usec() - _scenario_started_usec,
			"profiled_command_usec": _profiled_action_usec,
			"profiled_snapshot_usec": _profiled_snapshot_usec,
			"total_tick_usec": total_tick_usec,
			"max_hour_usec": max_hour_usec,
			"max_migration_usec": max_migration_usec,
			"hour_sample_count": _hour_timings.size(),
			"route_cache": road_network.get_route_cache_stats() if road_network and road_network.has_method("get_route_cache_stats") else {},
		},
		"final_summary": final_summary,
	}
	var file := FileAccess.open(EVIDENCE_PATH, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(evidence, "  ", true) + "\n")
	print("TOWN_REBALANCE success=%s meaningful=%d attempts=%d max_hour_ms=%.3f max_06_ms=%.3f failures=%d" % [_failures.is_empty(), _meaningful_placements, _meaningful_attempts, float(max_hour_usec) / 1000.0, float(max_migration_usec) / 1000.0, _failures.size()])
	for failure in _failures: push_error(failure)
	quit(0 if _failures.is_empty() else 1)

func _assert(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)

func _capture_midgame(manager) -> void:
	root.size = Vector2i(1280, 720)
	var dashboard = manager.get_plugin("Dashboard")
	if dashboard and dashboard.has_method("set_collapsed"): dashboard.set_collapsed(true)
	var view = current_scene.get_node_or_null("View")
	if view:
		view.camera_position = Vector3(-0.5, 0.0, -0.5)
		view.zoom = 25.0
	for _frame in 12: await process_frame
	var output := "res://specs/006-connected-first-town-loop/validation/screenshots/rebalance-midgame.png"
	if DisplayServer.get_name() == "headless":
		print("TOWN_REBALANCE screenshot skipped: headless display")
		return
	var texture := root.get_texture()
	if texture == null:
		_failures.append("Normal mid-game screenshot requires a rendering display")
		return
	var image := texture.get_image()
	if image == null:
		print("TOWN_REBALANCE screenshot skipped: headless renderer has no viewport image")
		return
	var error := image.save_png(ProjectSettings.globalize_path(output))
	_assert(error == OK and image.get_size() == Vector2i(1280, 720), "Normal mid-game screenshot must save at 1280x720")
	var manifest := {"schema_version":1, "file":"rebalance-midgame.png", "renderer":RenderingServer.get_current_rendering_method(),
		"viewport":{"width":image.get_width(), "height":image.get_height()}, "meaningful_structures":_meaningful_placements,
		"road_tiles":75, "camera":{"x":-0.5,"y":0.0,"z":-0.5,"zoom":25.0}}
	var file := FileAccess.open("res://specs/006-connected-first-town-loop/validation/screenshots/rebalance-manifest.json", FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(manifest, "  ", true) + "\n")
