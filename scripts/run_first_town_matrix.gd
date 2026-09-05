extends SceneTree

const ROOT := "res://test/scenarios/first_town/"
const MATRIX_PATH := ROOT + "matrix.json"
const EVIDENCE_PATH := "res://specs/006-connected-first-town-loop/validation/matrix-report.json"
const REPLAY_PATH := "res://specs/006-connected-first-town-loop/validation/determinism-report.json"

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for _frame in 12: await process_frame
	var playtest = root.get_node("PluginManager").get_plugin("Playtest")
	var community = root.get_node("PluginManager").get_plugin("Community")
	var catalog = root.get_node("PluginManager").get_plugin("BuildingCatalog")
	var matrix := _json(MATRIX_PATH)
	if playtest == null or community == null or catalog == null or matrix.is_empty():
		_fail("matrix_setup_failed")
		_finish({}, {})
		return
	# Pair runs freeze the declared resident stream. Migration itself already has
	# dedicated seven-day tests and would invalidate a controlled layout pair.
	community._balance["candidate_batch_size"] = 0
	var repeat_count := int(matrix.get("repeat_count", 10))
	var scenario_ids := {}
	for pair in matrix.get("pairs", []):
		scenario_ids[String(pair["left_scenario"])] = true
		scenario_ids[String(pair["right_scenario"])] = true
	for id in matrix.get("adversaries", []): scenario_ids[String(id)] = true
	var traces := {}
	var determinism_rows: Array = []
	var ids := scenario_ids.keys(); ids.sort()
	for scenario_id in ids:
		var scenario := _scenario(String(scenario_id))
		var hashes: Array[String] = []
		var first_trace: Dictionary = {}
		for repeat_index in repeat_count:
			var trace := _run_scenario(playtest, community, catalog, scenario, repeat_index)
			if repeat_index == 0: first_trace = trace
			hashes.append(String(trace.get("state_hash", "")))
		var deterministic := not hashes.is_empty() and hashes.all(func(value): return value == hashes[0])
		if not deterministic: _fail("nondeterministic:%s" % scenario_id)
		traces[scenario_id] = first_trace
		determinism_rows.append({"scenario_id": scenario_id, "repeat_count": repeat_count, "deterministic": deterministic, "hash": hashes[0] if not hashes.is_empty() else "", "hashes": hashes})

	var pair_rows: Array = []
	for pair in matrix.get("pairs", []):
		var left_id := String(pair["left_scenario"]); var right_id := String(pair["right_scenario"])
		var comparison := FirstTownLayoutComparator.compare(pair, _scenario(left_id), _scenario(right_id), traces[left_id], traces[right_id])
		if not bool(comparison.get("passed", false)): _fail("comparison_failed:%s" % pair.get("pair_id", "unknown"))
		pair_rows.append(comparison)
	var adversary_rows: Array = []
	for scenario_id in matrix.get("adversaries", []):
		var trace: Dictionary = traces[String(scenario_id)]
		var final: Dictionary = trace.get("final", {})
		var passed := int(final.get("population", -1)) == 0 and int(final.get("economy", {}).get("industrial_output", -1)) == 0 and int(final.get("economy", {}).get("cumulative_income", -1)) == 0 and not bool(final.get("tier_two_available", true)) and int(final.get("spatial", {}).get("resident_serving_nature_count", -1)) == 0
		if not passed: _fail("adversary_failed:%s" % scenario_id)
		adversary_rows.append({"scenario_id": scenario_id, "passed": passed, "final": final})
	_finish({"pairs": pair_rows, "adversaries": adversary_rows, "scenario_traces": traces}, {"scenarios": determinism_rows})

func _run_scenario(playtest, community, catalog, scenario: Dictionary, repeat_index: int) -> Dictionary:
	var scenario_id := String(scenario.get("scenario_id", ""))
	if String(scenario.get("evaluation_mode", "")) == "programme_fixture":
		return _programme_trace(catalog, scenario)
	var started: Dictionary = playtest.start_session({"scenario_id": scenario_id, "seed": int(scenario.get("seed", 1))})
	if started.has("error"):
		_fail("start_failed:%s" % scenario_id)
		return {"success": false, "state_hash": "start-failed", "final": {}}
	var index := 0
	for item in scenario.get("layout", []):
		index += 1
		var outcome: Dictionary = playtest.handle_command("place", {
			"request_id": "r%d-place-%d" % [repeat_index, index],
			"building_id": item.get("building_id", ""), "anchor": item.get("anchor", {}),
		})
		if String(outcome.get("status", "")) != PlaytestActionResult.STATUS_APPLIED:
			_fail("placement_failed:%s:%d:%s" % [scenario_id, index, outcome.get("reason", "error")])
			return {"success": false, "state_hash": "placement-failed", "final": {}}
	community.apply_scenario_fixture(scenario.get("fixture", {}), int(scenario.get("seed", 1)))
	var hours := int(scenario.get("duration_hours", 168))
	if scenario_id in ["first_town/bridge_connected", "first_town/bridge_removed"]: hours = maxi(hours, 2)
	var advanced: Dictionary = playtest.handle_command("advance", {"request_id": "r%d-advance" % repeat_index, "hours": hours})
	if String(advanced.get("status", "")) != PlaytestActionResult.STATUS_APPLIED:
		_fail("advance_failed:%s" % scenario_id)
		return {"success": false, "state_hash": "advance-failed", "final": {}}
	var snapshot: Dictionary = playtest.get_snapshot()
	var final := _summarize(snapshot)
	return {"success": true, "scenario_id": scenario_id, "state_hash": JSON.stringify(final).sha256_text(), "canonical_state_hash": snapshot.get("state_hash", ""), "final": final}

func _programme_trace(catalog, scenario: Dictionary) -> Dictionary:
	var cohorts_doc := _json("res://data/community/cohorts.json")
	var generator := CommunityPersonalityGenerator.new(cohorts_doc.get("cohorts", []), 1, 0.75, 1.25)
	var definition: Dictionary = scenario.get("fixture", {}).get("residents", [])[0]
	var resident := generator.generate(int(definition.get("seed", 1)), int(definition.get("resident_id", 1)), String(definition.get("cohort_id", "general")))
	resident.home_anchor = Vector2i.ZERO
	var theatre_index: int = int(catalog.get_item_index("building_theatre"))
	var profile := catalog.get_all()[theatre_index].find_metadata(CommunityEffectProfile) as CommunityEffectProfile
	var scores := {}
	for programme in ["plays", "rock_nights", "community_use"]:
		var source := {"building_id": "building_theatre", "anchor": Vector2i.ZERO, "active": true, "participants": [resident.resident_id], "effects": profile.effects_for(programme)}
		var evaluation := CommunityEffectEvaluator.evaluate(resident, [source], {"hour": 21})
		var score := 0.0
		for amount in evaluation.get("totals", {}).values(): score += float(amount)
		scores[programme] = CommunityConstants.rounded(score)
	var ranked := scores.keys()
	ranked.sort_custom(func(a, b): return float(scores[a]) > float(scores[b]))
	var margin := float(scores[ranked[0]]) - float(scores[ranked[1]])
	var final := {"programme": {"preferred_programme": ranked[0], "preference_margin": CommunityConstants.rounded(margin), "scores": scores}}
	return {"success": true, "scenario_id": scenario.get("scenario_id", ""), "state_hash": JSON.stringify(final).sha256_text(), "final": final}

func _summarize(snapshot: Dictionary) -> Dictionary:
	var community: Dictionary = snapshot.get("community", {})
	var spatial: Dictionary = community.get("spatial", {})
	var negative_count := 0; var positive_residents := {}; var exposure_count := 0
	for exposure in spatial.get("exposures", []):
		exposure_count += 1
		if float(exposure.get("applied_amount", 0.0)) < 0.0: negative_count += 1
		elif float(exposure.get("applied_amount", 0.0)) > 0.0 and String(exposure.get("scope", "")) == "local": positive_residents[int(exposure.get("resident_id", 0))] = true
	var serving_count := 0
	for source in spatial.get("resident_serving_nature", []):
		if bool(source.get("resident_serving", false)): serving_count += 1
	var work := 0; var activity := 0
	for assignment in community.get("assignments", []):
		if assignment.get("purpose") == "work": work += 1
		else: activity += 1
	var ledger: Dictionary = snapshot.get("economy", {}).get("ledger", {})
	var extent := _extent(snapshot.get("buildings", []))
	return {
		"population": int(snapshot.get("population", {}).get("current", 0)),
		"community": {"average_qualities": community.get("average_qualities", {}).duplicate(true), "average_composite_happiness": community.get("average_composite_happiness", 0.0), "migration": community.get("migration", {}).duplicate(true)},
		"spatial": {"exposure_count": exposure_count, "negative_exposure_count": negative_count, "distinct_positive_residents": positive_residents.size(), "resident_serving_nature_count": serving_count},
		"assignments": {"work": work, "activity": activity},
		"connectivity": {"road_cell_count": int(snapshot.get("connectivity", {}).get("road_cell_count", 0))},
		"economy": {"cash": int(snapshot.get("economy", {}).get("cash", 0)), "industrial_output": int(snapshot.get("economy", {}).get("industrial_output", 0)), "last_hourly_income": int(snapshot.get("economy", {}).get("last_hourly_income", 0)), "cumulative_income": int(ledger.get("cumulative_income", 0)), "cumulative_spend": int(ledger.get("cumulative_spend", 0)), "spend_by_category": ledger.get("spend_by_category", {}).duplicate(true)},
		"demand": snapshot.get("demand", {}).duplicate(true),
		"land": {"occupied_count": int(snapshot.get("land", {}).get("occupied_count", 0)), "free_count": int(snapshot.get("land", {}).get("free_count", 0)), "extent_area": extent},
		"tier_two_available": bool(snapshot.get("tier_two_available", false)),
	}

func _extent(buildings: Array) -> int:
	if buildings.is_empty(): return 0
	var min_x := 99999; var max_x := -99999; var min_z := 99999; var max_z := -99999
	for building in buildings:
		for cell in building.get("footprint", [building.get("anchor", {})]):
			min_x = mini(min_x, int(cell.get("x", 0))); max_x = maxi(max_x, int(cell.get("x", 0)))
			min_z = mini(min_z, int(cell.get("z", 0))); max_z = maxi(max_z, int(cell.get("z", 0)))
	return (max_x - min_x + 1) * (max_z - min_z + 1)

func _scenario(id: String) -> Dictionary:
	return _json(ROOT + id.trim_prefix("first_town/") + ".json")

func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _fail(message: String) -> void:
	if message not in _failures: _failures.append(message)

func _finish(matrix_data: Dictionary, replay_data: Dictionary) -> void:
	var report := {"schema_version": 1, "success": _failures.is_empty(), "failures": _failures, "generated_at": Time.get_datetime_string_from_system(true)}
	report.merge(matrix_data, true)
	var replay := {"schema_version": 1, "success": _failures.filter(func(value): return String(value).begins_with("nondeterministic")).is_empty(), "failures": _failures.filter(func(value): return String(value).begins_with("nondeterministic")), "generated_at": report["generated_at"]}
	replay.merge(replay_data, true)
	_write(EVIDENCE_PATH, report); _write(REPLAY_PATH, replay)
	print("FIRST_TOWN_MATRIX success=%s pairs=%d failures=%d" % [report["success"], report.get("pairs", []).size(), _failures.size()])
	for failure in _failures: push_error(failure)
	quit(0 if _failures.is_empty() else 1)

func _write(path: String, payload: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(payload, "  ", true) + "\n"); file.close()
