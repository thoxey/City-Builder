extends SceneTree

## Normal-renderer evidence for feature 019. Every capture is taken from the
## real main scene and every UI model comes from an authoritative runtime
## projection; this deliberately contains no hand-authored consequence quotes,
## tutorial copy, fake town blocks, or hard-coded Grass results.

const OUTPUT := "res://specs/019-opening-playtest-polish/validation/screenshots"
const VIEWPORTS := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const SCENARIO_ID := "first_town/opening_balance"
const SCENARIO_SEED := 19019

var _captures: Array = []
var _failures: Array[String] = []
var _manager: Node
var _builder: Node
var _playtest: Node
var _tutorial: Node
var _dashboard: Node
var _player_ui: Node
var _community: Node
var _catalog: Node
var _game_state: Node


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = VIEWPORTS[0]
	DisplayServer.window_set_size(VIEWPORTS[0])
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(48)
	_manager = root.get_node_or_null("PluginManager")
	_builder = current_scene.find_child("Builder", true, false) if current_scene else null
	_playtest = _manager.get_plugin("Playtest") if _manager else null
	_tutorial = _manager.get_plugin("OpeningTutorial") if _manager else null
	_dashboard = _manager.get_plugin("Dashboard") if _manager else null
	_player_ui = _manager.get_plugin("PlayerUI") if _manager else null
	_community = _manager.get_plugin("Community") if _manager else null
	_catalog = _manager.get_plugin("BuildingCatalog") if _manager else null
	_game_state = root.get_node_or_null("GameState")
	if [_manager, _builder, _playtest, _tutorial, _dashboard, _player_ui, _community, _catalog, _game_state].any(func(node): return node == null):
		_fail("real_main_stack_unavailable")
		_finish([])
		return

	var started: Dictionary = _playtest.start_session({"scenario_id":SCENARIO_ID, "seed":SCENARIO_SEED})
	_check(not started.has("error"), "consequence_session_start_failed")
	await _frames(8)
	# Keep the authoritative 16x16 starter mask but remove rooted-access gates so
	# each location-panel state can be isolated without fabricating a quote.
	_game_state.map.rooted_town_rules = false
	# A normal player's pointer supplies the preview anchor every frame. Freeze
	# only Builder's pointer polling while this automated capture supplies those
	# same anchors directly; all presentation nodes continue to process normally.
	_builder.set_process(false)
	_dashboard.set_collapsed(false)
	_freeze_camera()

	var unchanged := await _preview_quote("pavement", Vector2i(-7, -6), "pavement")
	_check(String(unchanged.get("status", "")) == "valid", "unchanged_quote_not_valid")
	_check(_rows(unchanged).is_empty(), "unchanged_quote_retained_rows")
	await _capture_quote_state("unchanged-hidden", unchanged, false)

	var changed := await _preview_quote("grass_trees", Vector2i(-7, -7), "grass")
	_check(String(changed.get("status", "")) == "valid", "changed_quote_not_valid")
	_check(not _rows(changed).is_empty(), "changed_quote_missing_rows")
	await _capture_quote_state("changed", changed, true)

	var invalid := await _preview_quote("pavement", Vector2i(8, 8), "pavement")
	_check(String(invalid.get("status", "")) == "invalid", "invalid_quote_not_invalid")
	_check(String(invalid.get("reason", "")) == PlaytestActionResult.OUTSIDE_BUILDABLE_AREA,
		"invalid_quote_wrong_reason")
	await _capture_quote_state("invalid", invalid, true)

	var home_outcome: Dictionary = _builder.try_place_building("building_small_a", Vector2i(0, 0))
	_check(String(home_outcome.get("status", "")) == PlaytestActionResult.STATUS_APPLIED,
		"replacement_fixture_home_failed")
	await _frames(6)
	var replacement := await _preview_quote("grass_trees", Vector2i(0, 0), "grass")
	_check(String(replacement.get("status", "")) == "replacement", "replacement_quote_missing")
	_check(replacement.get("replacement", {}).get("removed_buildings", []).size() == 1,
		"replacement_quote_wrong_removed_count")
	await _capture_quote_state("replacement", replacement, true)

	var uncertain := await _preview_quote("road_straight", Vector2i(-5, -4), "road")
	_check(String(uncertain.get("status", "")) == "valid", "uncertain_quote_not_valid")
	_check("network_reconnections_after_commit" in uncertain.get("uncertainties", []),
		"uncertain_quote_missing_network_warning")
	await _capture_quote_state("uncertain", uncertain, true)

	# Reset into the real rooted opening and play the tutorial in semantic order.
	started = _playtest.start_session({"scenario_id":SCENARIO_ID, "seed":SCENARIO_SEED})
	_check(not started.has("error"), "tutorial_session_start_failed")
	_builder.set_process(true)
	_builder.cancel_placement()
	_builder._set_input_mode("world")
	await _frames(8)
	_dashboard.set_collapsed(true)
	_freeze_camera()
	await _place_exact("building_town_hall", Vector2i(-1, -1))
	for x in range(-1, 7):
		await _place_exact("road", Vector2i(x, 1))
	await _place_exact("road", Vector2i(7, 1))
	_check(int(_tutorial.get_evidence_snapshot().get("rooted_road_count", 0)) == 9,
		"road_count_before_tenth_not_nine")
	await _place_exact("road", Vector2i(7, 2))
	var road_state: Dictionary = _tutorial.get_state()
	var road_projection: Dictionary = _tutorial.get_projection()
	var road_receipt: Dictionary = road_state.get("completed_receipts", {}).get("opening.rooted_roads_connected", {})
	_check(int(_tutorial.get_evidence_snapshot().get("rooted_road_count", 0)) == 10,
		"road_count_after_tenth_not_ten")
	_check(int(road_receipt.get("evidence", {}).get("count", 0)) == 10,
		"road_receipt_not_exactly_ten")
	_check(String(road_projection.get("beat_id", "")) == "B03",
		"tenth_road_did_not_advance_to_nature")
	await _capture_guidance_state("ten-rooted-roads", road_projection)

	await _place_exact("grass_trees", Vector2i(-7, -7))
	await _place_exact("grass_trees_tall", Vector2i(-6, -7))
	await _place_exact("building_small_a", Vector2i(2, 0))
	var adjacency_projection: Dictionary = _tutorial.get_projection()
	var adjacency_text := String(adjacency_projection.get("text", ""))
	_check(String(adjacency_projection.get("beat_id", "")) == "B08",
		"first_home_did_not_advance_to_adjacency")
	_check(adjacency_text.to_lower().contains("another home"),
		"adjacency_projection_missing_another_home")
	_check(not adjacency_text.to_lower().contains("the first house"),
		"adjacency_projection_retained_first_house")
	await _capture_guidance_state("adjacency-another-home", adjacency_projection)

	await _place_exact("building_small_a", Vector2i(3, 0))
	await _place_exact("grass_trees", Vector2i(2, -1))
	await _place_exact("building_garage", Vector2i(6, 0))
	_community.apply_scenario_fixture({"residents":[{
		"resident_id":1, "seed":SCENARIO_SEED * 100 + 1, "cohort_id":"general",
		"home_anchor":{"x":2, "z":0},
	}]}, SCENARIO_SEED)
	var advanced: Dictionary = _playtest.handle_command("advance", {
		"hours":2, "request_id":"opening-polish-capture-work-shift", "snapshot_mode":"none",
	})
	_check(String(advanced.get("status", "")) == PlaytestActionResult.STATUS_APPLIED,
		"work_shift_advance_failed")
	await _frames(8)
	await _place_exact("building_small_b", Vector2i(4, 0))
	await _frames(8)
	_builder.cancel_placement()
	await _frames(6)
	var completed_state: Dictionary = _tutorial.get_state()
	var guidance: Dictionary = _dashboard.build_compact_guidance_model(_dashboard.snapshot())
	_check(_tutorial.is_complete(), "first_shop_did_not_complete_tutorial")
	_check(bool(completed_state.get("completion_handoff", {}).get("applied", false)),
		"completion_handoff_not_persisted")
	_check(String(guidance.get("kind", "")) == "first_quest", "first_quest_not_primary")
	_check(not String(guidance.get("text", "")).contains("0/100"),
		"commercial_demand_prompt_leaked_into_handoff")
	await _capture_guidance_state("first-quest-handoff", guidance)

	# Commit through the player-facing Playtest choice path. The concrete IDs in
	# the manifest therefore prove the ID-collision behavior as well as the art.
	var grass_variants: Array[String] = []
	for index in 12:
		var anchor := Vector2i(-7 + index, -5)
		var outcome: Dictionary = _playtest.handle_command("place", {
			"request_id":"opening-polish-grass-%02d" % index,
			"choice_id":"grass", "anchor":{"x":anchor.x, "z":anchor.y},
			"snapshot_mode":"none",
		})
		_check(String(outcome.get("status", "")) == PlaytestActionResult.STATUS_APPLIED,
			"grass_pool_commit_failed_%02d" % index)
		var concrete := String(outcome.get("details", {}).get("building_id", ""))
		if not concrete.is_empty() and concrete not in grass_variants:
			grass_variants.append(concrete)
		await _frames(2)
	grass_variants.sort()
	_check(grass_variants == ["grass_trees", "grass_trees_tall"],
		"grass_pool_concrete_variants_wrong:%s" % str(grass_variants))
	_builder.set_process(false)
	_player_ui._request_entry("grass")
	await _frames(6)
	var grass_preview := await _preview_quote("grass_trees", Vector2i(5, -5), "grass")
	await _capture_runtime_state("grass-pool-variants", {
		"grass_pool_variants":grass_variants.duplicate(),
		"excluded_variant":"grass",
		"preview_rows":_row_texts(grass_preview),
	})
	_builder.set_process(true)

	_finish(grass_variants)


func _preview_quote(building_id: String, anchor: Vector2i, entry_id: String) -> Dictionary:
	var index := int(_catalog.get_item_index(building_id))
	_check(index >= 0, "preview_building_missing:%s" % building_id)
	if index < 0:
		return {}
	_player_ui._selected_entry_id = entry_id
	_builder._preview_idx = index
	_builder._placement_active = true
	_builder._demolition_active = false
	_builder._last_preview_anchor = anchor
	_builder._set_input_mode("placement")
	_builder.update_structure()
	_builder._update_preview_color(anchor)
	_builder._emit_placement_context("", anchor)
	await _frames(6)
	return _builder.evaluate_placement_consequences(index, anchor, 0)


func _place_exact(building_id: String, anchor: Vector2i) -> void:
	var outcome: Dictionary = _builder.try_place_building(building_id, anchor)
	_check(String(outcome.get("status", "")) == PlaytestActionResult.STATUS_APPLIED,
		"placement_failed:%s:%d,%d:%s" % [building_id, anchor.x, anchor.y,
			str(outcome.get("reason", ""))])
	await _frames(4)


func _capture_quote_state(state: String, quote: Dictionary, expected_visible: bool) -> void:
	await _capture_runtime_state(state, {
		"quote_status":String(quote.get("status", "")),
		"quote_reason":String(quote.get("reason", "")),
		"rows":_row_texts(quote),
		"expected_panel_visible":expected_visible,
	}, expected_visible)


func _capture_guidance_state(state: String, projection: Dictionary) -> void:
	_builder.cancel_placement()
	_builder._set_input_mode("world")
	await _frames(6)
	var model: Dictionary = _dashboard._guidance_view.model_for_test()
	var expected_text := String(projection.get("text", projection.get("direction", "")))
	if not expected_text.is_empty():
		_check(String(model.get("text", "")) == expected_text,
			"guidance_model_not_authoritative:%s" % state)
	_check(_dashboard._guidance_view.visible, "guidance_not_visible:%s" % state)
	await _capture_runtime_state(state, {
		"projection":projection.duplicate(true),
		"guidance_model":model,
	})


func _capture_runtime_state(state: String, evidence: Dictionary,
		expected_panel_visible: Variant = null) -> void:
	for viewport_size in VIEWPORTS:
		root.size = viewport_size
		DisplayServer.window_set_size(viewport_size)
		await _frames(8)
		var panel_rect: Rect2 = _player_ui._consequences.get_global_rect()
		var guidance_rect: Rect2 = _dashboard._guidance_view.get_global_rect()
		var dashboard_rect: Rect2 = _dashboard._panel.get_global_rect()
		var guidance_clearance := panel_rect.position.x - guidance_rect.end.x
		var dashboard_clearance := dashboard_rect.position.x - panel_rect.end.x
		if expected_panel_visible != null:
			_check(bool(_player_ui._consequences.visible) == bool(expected_panel_visible),
				"panel_visibility_wrong:%s:%s" % [state, str(viewport_size)])
		if _player_ui._consequences.visible and _dashboard._guidance_view.visible:
			_check(not panel_rect.intersects(guidance_rect),
				"panel_guidance_overlap:%s:%s:%s:%s" % [
					state, str(viewport_size), str(panel_rect), str(guidance_rect),
				])
			_check(guidance_clearance >= 11.5,
				"panel_guidance_margin_too_small:%s:%s:%.2f" % [
					state, str(viewport_size), guidance_clearance,
				])
		if _player_ui._consequences.visible and _dashboard._panel.visible:
			_check(not panel_rect.intersects(dashboard_rect),
				"panel_dashboard_overlap:%s:%s:%s:%s" % [
					state, str(viewport_size), str(panel_rect), str(dashboard_rect),
				])
			_check(dashboard_clearance >= 11.5,
				"panel_dashboard_margin_too_small:%s:%s:%.2f" % [
					state, str(viewport_size), dashboard_clearance,
				])
		if DisplayServer.get_name() == "headless":
			continue
		var image := root.get_texture().get_image()
		if image == null:
			_fail("capture_texture_missing:%s:%s" % [state, str(viewport_size)])
			continue
		_check(image.get_size() == viewport_size,
			"capture_size_wrong:%s:%s:%s" % [state, str(viewport_size), str(image.get_size())])
		var file_name := "%dx%d-%s.png" % [viewport_size.x, viewport_size.y, state]
		var error := image.save_png(ProjectSettings.globalize_path(OUTPUT.path_join(file_name)))
		_check(error == OK, "capture_write_failed:%s:%s" % [file_name, error])
		var record := {
			"file":file_name, "viewport":[viewport_size.x, viewport_size.y],
			"state":state, "source":"real_main_scene",
			"panel_visible":bool(_player_ui._consequences.visible),
			"guidance_visible":bool(_dashboard._guidance_view.visible),
			"panel_rect":_rect_evidence(panel_rect),
			"guidance_rect":_rect_evidence(guidance_rect),
			"dashboard_rect":_rect_evidence(dashboard_rect),
			"guidance_clearance_px":guidance_clearance,
			"dashboard_clearance_px":dashboard_clearance,
		}
		record.merge(evidence.duplicate(true), true)
		_captures.append(record)


func _rect_evidence(rect: Rect2) -> Dictionary:
	return {
		"x":rect.position.x,
		"y":rect.position.y,
		"width":rect.size.x,
		"height":rect.size.y,
	}


func _freeze_camera() -> void:
	var view := current_scene.get_node_or_null("View") if current_scene else null
	if view:
		view.camera_position = Vector3(1.0, 0.0, -1.0)
		view.zoom = 35.0


func _rows(quote: Dictionary) -> Array:
	return _player_ui._consequences.presentation_rows(quote)


func _row_texts(quote: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for row in _rows(quote):
		result.append(String(row.get("text", "")))
	return result


func _check(ok: bool, failure: String) -> void:
	if not ok:
		_fail(failure)


func _fail(failure: String) -> void:
	if failure not in _failures:
		_failures.append(failure)
	push_error("opening_polish_capture:%s" % failure)


func _finish(grass_variants: Array) -> void:
	var manifest_path := OUTPUT.path_join("manifest.json")
	var manifest := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest == null:
		_fail("manifest_write_failed")
	else:
		manifest.store_string(JSON.stringify({
			"schema_version":2,
			"feature":"019-opening-playtest-polish",
			"renderer":RenderingServer.get_current_rendering_method(),
			"display_server":DisplayServer.get_name(),
			"scenario_id":SCENARIO_ID,
			"seed":SCENARIO_SEED,
			"capture_source":"real main scene, authoritative runtime projections and committed commands",
			"captures":_captures,
			"grass_pool_variants":grass_variants,
			"excluded_variant":"grass",
			"success":_failures.is_empty(),
			"failures":_failures,
		}, "  ", true) + "\n")
		manifest.close()
	print("OPENING_POLISH_CAPTURE success=%s files=%d renderer=%s failures=%s" % [
		str(_failures.is_empty()), _captures.size(), RenderingServer.get_current_rendering_method(),
		str(_failures),
	])
	quit(0 if _failures.is_empty() else 1)


func _frames(count: int) -> void:
	for _index in count:
		await process_frame
