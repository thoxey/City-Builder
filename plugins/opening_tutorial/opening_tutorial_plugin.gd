extends PluginBase

## Canonical, state-driven observer for the opening mini-quest.  This plugin
## deliberately has no placement or simulation mutation API.

signal projection_changed(projection: Dictionary)

const TUTORIAL_ID := "opening_tutorial"
const SCHEMA_VERSION := 1
const TOWN_HALL_ID := "building_town_hall"
const REQUIRED_ROOTED_ROAD_COUNT := 10
const STEPS: Array[String] = [
	"place_town_hall", "connect_rooted_roads", "establish_nature",
	"place_first_home", "observe_adjacent_home", "improve_home",
	"establish_workplace", "confirm_work_participation",
	"place_first_shop", "complete",
]
const RECEIPTS := {
	"place_town_hall": "opening.town_hall_placed",
	"connect_rooted_roads": "opening.rooted_roads_connected",
	"establish_nature": "opening.nature_established",
	"place_first_home": "opening.first_home_placed",
	"observe_adjacent_home": "opening.adjacent_home_observed",
	"improve_home": "opening.home_improved",
	"establish_workplace": "opening.workplace_established",
	"confirm_work_participation": "opening.work_participation_confirmed",
	"place_first_shop": "opening.first_shop_placed",
}
const FULL_EVENTS := {
	"B05": "tutorial_opening_beauty_homes",
	"B09": "tutorial_opening_home_adjacency",
	"B15": "tutorial_opening_work_participation",
	"B18": "tutorial_opening_complete",
}
const COPY := {
	"B01": "AMBROSE PLACEHOLDER: tell the player to place the Town Hall",
	"B02": "AMBROSE PLACEHOLDER: tell the player to build ten connected road pieces from the Town Hall",
	"B03": "AMBROSE PLACEHOLDER: tell the player to place two different kinds of nature",
	"B04": "AMBROSE PLACEHOLDER: tell the player to add or improve nature until Beauty is positive",
	"B05": "AMBROSE PLACEHOLDER: explain that positive Beauty creates Homes demand",
	"B06": "AMBROSE PLACEHOLDER: explain that Homes demand is still accruing",
	"B07": "AMBROSE PLACEHOLDER: tell the player to place an early home",
	"B08": "AMBROSE PLACEHOLDER: ask the player to place a home directly beside another home",
	"B09": "AMBROSE PLACEHOLDER: explain the home adjacency result that was actually observed",
	"B10": "AMBROSE PLACEHOLDER: ask the player to improve the affected home with nature or decoration",
	"B11": "AMBROSE PLACEHOLDER: acknowledge that decoration improved the affected home",
	"B12": "AMBROSE PLACEHOLDER: tell the player to place accessible industry away from homes",
	"B13": "AMBROSE PLACEHOLDER: explain the observed industry access or residential-impact problem",
	"B14": "AMBROSE PLACEHOLDER: explain that residents need time and access to attend work",
	"B15": "AMBROSE PLACEHOLDER: explain that residents now work and earn money",
	"B16": "AMBROSE PLACEHOLDER: tell the player to place an accessible shop and consider nearby homes",
	"B17": "AMBROSE PLACEHOLDER: explain that the shop needs rooted road access",
	"B18": "AMBROSE PLACEHOLDER: acknowledge the first shop and hand off toward Sir William and more land",
}

var _catalog: PluginBase
var _roads: PluginBase
var _attractiveness: PluginBase
var _demand: PluginBase
var _community: PluginBase
var _events: PluginBase
var _state: Dictionary = {}
var _evidence: Dictionary = {}
var _projection: Dictionary = {}
var _projection_revision := 0
var _reconcile_queued := false
var _placement_observations: Array = []
var _suppress_handoff_emit := false
var _normalization_diagnostics: Array = []
var _rebound_home_baselines: Dictionary = {}
var _rebound_anchor_internal_id := -1
var _using_rebound_home_ids := false

func get_plugin_name() -> String: return "OpeningTutorial"

func get_dependencies() -> Array[String]:
	return ["BuildingCatalog", "RoadNetwork", "Attractiveness", "Demand", "Community", "EventSystem"]

func inject(deps: Dictionary) -> void:
	_catalog = deps.get("BuildingCatalog")
	_roads = deps.get("RoadNetwork")
	_attractiveness = deps.get("Attractiveness")
	_demand = deps.get("Demand")
	_community = deps.get("Community")
	_events = deps.get("EventSystem")

func _plugin_ready() -> void:
	GameEvents.structure_placed.connect(_on_structure_placed)
	GameEvents.structure_demolished.connect(func(_position): _queue_reconcile("structure_demolished"))
	GameEvents.unique_placed.connect(func(_id): _queue_reconcile("unique_placed"))
	GameEvents.unique_removed.connect(func(_id): _queue_reconcile("unique_removed"))
	GameEvents.demand_total_changed.connect(func(_id, _value): _queue_reconcile("demand_total"))
	GameEvents.demand_fulfilled_changed.connect(func(_id, _value): _queue_reconcile("demand_fulfilled"))
	GameEvents.demand_unserved_changed.connect(func(_id, _value): _queue_reconcile("demand_unserved"))
	GameEvents.city_attractiveness_changed.connect(func(_value): _queue_reconcile("attractiveness"))
	GameEvents.community_population_changed.connect(func(_population, _capacity): _queue_reconcile("community"))
	GameEvents.community_qualities_changed.connect(func(_averages): _queue_reconcile("community"))
	GameEvents.map_loaded.connect(_on_map_loaded)
	reconcile("boot")

func get_state() -> Dictionary: return _state.duplicate(true)
func get_evidence_snapshot() -> Dictionary: return _evidence.duplicate(true)
func get_projection() -> Dictionary: return _projection.duplicate(true)
func is_complete() -> bool: return String(_state.get("current_step_id", "")) == "complete"

func _on_map_loaded(_map: DataMap) -> void:
	_placement_observations.clear()
	_suppress_handoff_emit = true
	reconcile("map_loaded")
	_suppress_handoff_emit = false

func _on_structure_placed(position: Vector3i, structure_index: int, _orientation: int) -> void:
	var observation := _placement_observation(position, structure_index)
	if not observation.is_empty():
		_placement_observations.append(observation)
	_queue_reconcile("structure_placed")

func _queue_reconcile(_reason: String) -> void:
	if _reconcile_queued: return
	_reconcile_queued = true
	call_deferred("_run_queued_reconcile")

func _run_queued_reconcile() -> void:
	_reconcile_queued = false
	reconcile("invalidated")

func reconcile(reason: String = "explicit") -> Dictionary:
	_normalize_state()
	_evidence = _build_evidence_snapshot()
	# Builder intentionally recreates runtime internal IDs when it cold-loads a
	# DataMap. Rebind the persisted experiment records at those boundaries before
	# any new observation tries to use their baselines.
	if reason in ["boot", "map_loaded"]:
		_rebind_persisted_home_evidence()
	_recover_experiment()
	_replay_placement_observations()
	var added: Array[String] = []
	var handoff_payload: Dictionary = {}
	for step in STEPS.slice(0, STEPS.size() - 1):
		var receipt_id: String = RECEIPTS[step]
		if _state["completed_receipts"].has(receipt_id):
			continue
		var gate := _evaluate_gate(step)
		if not bool(gate.get("satisfied", false)):
			break
		_write_receipt(step, String(gate.get("evidence_kind", step)), gate.get("evidence", {}))
		added.append(receipt_id)
		_dispatch_milestone_for_step(step)
	if _all_step_receipts_present():
		_state["current_step_id"] = "complete"
		if not bool(_state["completion_handoff"].get("applied", false)):
			var shop: Dictionary = _state["completed_receipts"][RECEIPTS["place_first_shop"]].get("evidence", {})
			_state["completion_handoff"] = {"receipt_id": "tutorial_opening_completed", "applied": true, "shop": shop.duplicate(true)}
			handoff_payload = {
				"tutorial_id": TUTORIAL_ID,
				"receipt_id": "tutorial_opening_completed",
				"shop_building_id": String(shop.get("building_id", "")),
				"shop_anchor": shop.get("anchor", {}).duplicate(true),
			}
	else:
		_state["current_step_id"] = _first_incomplete_step()
	_persist_state()
	_publish_projection()
	if not handoff_payload.is_empty() and not _suppress_handoff_emit:
		GameEvents.tutorial_opening_completed.emit(handoff_payload.duplicate(true))
	if is_complete(): _dispatch_beat("B18")
	_placement_observations.clear()
	return {"reason": reason, "added_receipts": added, "step_id": _state["current_step_id"], "complete": is_complete()}

func _default_state() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION, "tutorial_id": TUTORIAL_ID,
		"current_step_id": "place_town_hall", "completed_receipts": {},
		"presentation_receipts": {},
		"experiment": {"anchor_home": null, "baseline": null, "adjacent_home": null,
			"adjacency_result": "pending", "after_adjacency": null,
			"repair_source": null, "after_repair": null, "home_baselines": []},
		"completion_handoff": {"receipt_id": "tutorial_opening_completed", "applied": false},
	}

func _normalize_state() -> void:
	var raw: Variant = GameState.map.opening_tutorial_state if GameState and GameState.map else {}
	_normalization_diagnostics = []
	if not raw is Dictionary:
		_normalization_diagnostics.append({"code": "tutorial_state_malformed", "evidence": {"field": "opening_tutorial_state"}})
	elif raw.has("current_step_id") and String(raw.get("current_step_id", "")) not in STEPS:
		_normalization_diagnostics.append({"code": "tutorial_unknown_step", "evidence": {"step_id": String(raw.get("current_step_id", ""))}})
	var normalized: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
	var defaults: Dictionary = _default_state()
	for key in defaults:
		if not normalized.has(key) or typeof(normalized[key]) != typeof(defaults[key]): normalized[key] = defaults[key].duplicate(true) if defaults[key] is Dictionary else defaults[key]
	normalized["schema_version"] = SCHEMA_VERSION
	normalized["tutorial_id"] = TUTORIAL_ID
	var valid_receipts := {}
	for step in RECEIPTS:
		var rid: String = RECEIPTS[step]
		var receipt: Variant = normalized["completed_receipts"].get(rid)
		if receipt is Dictionary and String(receipt.get("receipt_id", "")) == rid and String(receipt.get("step_id", "")) == step:
			valid_receipts[rid] = receipt.duplicate(true)
	normalized["completed_receipts"] = valid_receipts
	var presentations := {}
	for key in normalized["presentation_receipts"]:
		if bool(normalized["presentation_receipts"][key]): presentations[String(key)] = true
	normalized["presentation_receipts"] = presentations
	var valid_results := ["pending", "penalty_observed", "no_penalty", "baseline_unavailable"]
	for key in defaults["experiment"]:
		if not normalized["experiment"].has(key):
			normalized["experiment"][key] = defaults["experiment"][key].duplicate(true) if defaults["experiment"][key] is Array else defaults["experiment"][key]
	for key in ["anchor_home", "baseline", "adjacent_home", "after_adjacency", "repair_source", "after_repair"]:
		var nullable_record: Variant = normalized["experiment"].get(key)
		if nullable_record != null and not nullable_record is Dictionary:
			normalized["experiment"][key] = null
	if not normalized["experiment"].get("home_baselines") is Array:
		normalized["experiment"]["home_baselines"] = []
	if String(normalized["experiment"].get("adjacency_result", "")) not in valid_results:
		normalized["experiment"]["adjacency_result"] = "pending"
	for key in defaults["completion_handoff"]:
		if not normalized["completion_handoff"].has(key): normalized["completion_handoff"][key] = defaults["completion_handoff"][key]
	_state = normalized
	_state["current_step_id"] = "complete" if _all_step_receipts_present() else _first_incomplete_step()
	_persist_state()

func _persist_state() -> void:
	if GameState and GameState.map: GameState.map.opening_tutorial_state = _state.duplicate(true)

func _write_receipt(step: String, evidence_kind: String, evidence: Dictionary) -> void:
	var rid: String = RECEIPTS[step]
	if _state["completed_receipts"].has(rid): return
	_state["completed_receipts"][rid] = {"receipt_id": rid, "step_id": step, "evidence_kind": evidence_kind, "evidence": evidence.duplicate(true)}

func _first_incomplete_step() -> String:
	for step in STEPS.slice(0, STEPS.size() - 1):
		if not _state.get("completed_receipts", {}).has(RECEIPTS[step]): return step
	return "complete"

func _all_step_receipts_present() -> bool:
	for step in RECEIPTS:
		if not _state.get("completed_receipts", {}).has(RECEIPTS[step]): return false
	return true

func _build_evidence_snapshot() -> Dictionary:
	var buildings: Array = []
	var diagnostics: Array = _normalization_diagnostics.duplicate(true)
	if GameState and GameState.map and _catalog:
		var internal_ids := GameState.building_registry.keys()
		internal_ids.sort()
		for raw_id in internal_ids:
			var row := _building_evidence(int(raw_id), GameState.building_registry[raw_id])
			if not row.is_empty(): buildings.append(row)
	_buildings_sort(buildings)
	var hall: Variant = null
	var nature_ids: Array[String] = []
	var nature_seen := {}
	var homes: Array = []
	var workplaces: Array = []
	var shops: Array = []
	for building in buildings:
		if building["building_id"] == TOWN_HALL_ID:
			var hall_internal_id := int(_roads.get_town_hall_internal_id()) if _roads and _roads.has_method("get_town_hall_internal_id") else -1
			if hall_internal_id == int(building["internal_id"]): hall = building
		if building["category"] == "nature" and not nature_seen.has(building["building_id"]):
			nature_seen[building["building_id"]] = true; nature_ids.append(building["building_id"])
		if building["category"] == "residential" and int(building.get("tier", 0)) == 1: homes.append(building)
	# Derive radius evidence only after the complete, stably sorted homes list is
	# known; workplace anchors can sort before homes.
	for building in buildings:
		if building["category"] == "industrial" and int(building.get("tier", 0)) == 1: workplaces.append(_workplace_evidence(building, homes))
		if building["category"] == "commercial" and int(building.get("tier", 0)) == 1: shops.append(_shop_evidence(building))
	nature_ids.sort()
	var rooted_ids: Array = _roads.get_rooted_component_ids() if _roads and _roads.has_method("get_rooted_component_ids") else []
	rooted_ids.sort()
	var rooted_cells: Array = []
	var snapshot: Dictionary = _roads.get_connectivity_snapshot() if _roads and _roads.has_method("get_connectivity_snapshot") else {}
	for component in snapshot.get("components", []):
		if String(component.get("component_id", "")) in rooted_ids:
			for cell in component.get("cells", []):
				var rec := {"x": int(cell.get("x", 0)), "z": int(cell.get("z", cell.get("y", 0)))}
				if rec not in rooted_cells: rooted_cells.append(rec)
	rooted_cells.sort_custom(func(a, b): return a.x < b.x if a.x != b.x else a.z < b.z)
	var assignments: Array = []
	var operations_by_id := {}
	if _community:
		if _community.has_method("get_operation_records"):
			for operation in _community.get_operation_records(): operations_by_id[int(operation.get("internal_id", -1))] = operation
		if _community.has_method("get_assignment_records"): assignments = _community.get_assignment_records()
	for workplace in workplaces:
		var operation: Dictionary = operations_by_id.get(int(workplace.internal_id), {})
		workplace["open_now"] = bool(operation.get("open_now", false))
		workplace["operating"] = bool(operation.get("operating", false))
		workplace["fulfilled"] = int(operation.get("fulfilled", 0))
		workplace["operation_reasons"] = operation.get("reasons", []).duplicate(true)
	assignments = assignments.filter(func(row): return String(row.get("purpose", "")) == "work")
	assignments.sort_custom(func(a, b): return int(a.get("resident_id", 0)) < int(b.get("resident_id", 0)))
	return {
		"rooted_town_rules": bool(GameState.map.rooted_town_rules) if GameState and GameState.map else false,
		"town_hall": hall, "rooted_component_ids": rooted_ids.duplicate(),
		"rooted_road_cells": rooted_cells, "rooted_road_count": rooted_cells.size(),
		"nature_building_ids": nature_ids, "city_attractiveness": _city_score(),
		"demand": _demand_evidence(), "early_homes": homes,
		"early_workplaces": workplaces, "early_shops": shops,
		"work_assignments": assignments.duplicate(true),
		"road_revision": int(_roads.get_revision()) if _roads and _roads.has_method("get_revision") else 0,
		"diagnostics": diagnostics,
	}

func _building_evidence(internal_id: int, entry: Dictionary) -> Dictionary:
	var idx := int(entry.get("structure", -1))
	var building_id := String(_catalog.get_id_by_index(idx))
	if building_id.is_empty(): return {}
	var structure: Structure = _catalog.get_by_id(building_id)
	if structure == null: return {}
	var summary: Dictionary = _catalog.get_summary_by_id(building_id)
	var profile := structure.find_metadata(BuildingProfile) as BuildingProfile
	var category := profile.category if profile else String(summary.get("category", ""))
	var anchor: Vector2i = entry.get("anchor", Vector2i.ZERO)
	var cells: Array = entry.get("cells", [])
	if cells.is_empty():
		for offset in structure.footprint: cells.append(anchor + offset)
	var footprint: Array = []
	for cell in cells: footprint.append(_coordinate(cell))
	footprint.sort_custom(func(a, b): return a.x < b.x if a.x != b.x else a.z < b.z)
	var pool_cfg: Dictionary = _catalog.get_pool_config(structure.pool_id)
	return {"internal_id": internal_id, "building_id": building_id, "category": category,
		"pool_id": structure.pool_id, "tier": int(pool_cfg.get("tier", 0)),
		"anchor": _coordinate(anchor), "footprint": footprint}

func _workplace_evidence(building: Dictionary, homes: Array) -> Dictionary:
	var result := building.duplicate(true)
	var route: Dictionary = _roads.get_route_from_town_hall(int(building.internal_id)) if _roads and _roads.has_method("get_route_from_town_hall") else {"reachable": false, "reason": "road_network_missing", "distance": -1}
	var impacts := _negative_residential_impacts(building, homes)
	result.merge({"rooted_accessible": bool(route.get("reachable", false)), "route_reason": String(route.get("reason", "")),
		"rooted_route_distance": int(route.get("distance", -1)), "negative_residential_impacts": impacts,
		"separated": bool(route.get("reachable", false)) and impacts.is_empty()}, true)
	return result

func _shop_evidence(building: Dictionary) -> Dictionary:
	var result := building.duplicate(true)
	var route: Dictionary = _roads.get_route_from_town_hall(int(building.internal_id)) if _roads and _roads.has_method("get_route_from_town_hall") else {"reachable": false, "reason": "road_network_missing", "distance": -1}
	result.merge({"rooted_accessible": bool(route.get("reachable", false)), "route_reason": String(route.get("reason", "")), "rooted_route_distance": int(route.get("distance", -1)), "authored_effects": _authored_effects(building)}, true)
	return result

func _authored_effects(building: Dictionary) -> Array:
	var effects: Array = []
	var structure: Structure = _catalog.get_by_id(building.building_id)
	var attr := structure.find_metadata(AttractivenessProfile) as AttractivenessProfile
	if attr:
		for receiver in ["residential", "commercial", "industrial", "nature"]:
			var amount := int(attr.get(receiver))
			if amount != 0: effects.append({"system": "attractiveness", "effect_id": "attractiveness.%s" % receiver, "receiver": receiver, "amount": amount, "radius": attr.radius})
	var community_profile := structure.find_metadata(CommunityEffectProfile) as CommunityEffectProfile
	if community_profile:
		for effect in community_profile.effects:
			effects.append({"system": "community", "effect_id": String(effect.get("effect_id", "")), "scope": String(effect.get("scope", "")), "amount": float(effect.get("amount", 0.0)), "radius": effect.get("radius")})
	effects.sort_custom(func(a, b): return String(a.effect_id) < String(b.effect_id))
	return effects

func _negative_residential_impacts(source: Dictionary, homes: Array) -> Array:
	var impacts: Array = []
	var structure: Structure = _catalog.get_by_id(source.building_id)
	var attr := structure.find_metadata(AttractivenessProfile) as AttractivenessProfile
	if attr and attr.residential < 0 and attr.radius >= 0:
		for home in homes:
			var distance := _footprint_distance(source.footprint, home.footprint)
			if distance <= attr.radius: impacts.append({"home": home, "effect_id": "attractiveness.residential", "radius": attr.radius, "metric": "attractiveness_chebyshev", "distance": distance})
	var community_profile := structure.find_metadata(CommunityEffectProfile) as CommunityEffectProfile
	if community_profile:
		for effect in community_profile.effects:
			if String(effect.get("scope", "")) != "local" or float(effect.get("amount", 0.0)) >= 0.0: continue
			for home in homes:
				var distance := _footprint_manhattan_distance(source.footprint, home.footprint)
				if distance <= int(effect.get("radius", -1)): impacts.append({"home": home, "effect_id": effect.get("effect_id", ""), "radius": int(effect.get("radius", -1)), "metric": "community_manhattan", "distance": distance})
	return impacts

func _demand_evidence() -> Dictionary:
	var result := {}
	if _catalog == null:
		return result
	for bucket in ["residential", "industrial", "commercial"]:
		var candidate := _tier_one_candidate(bucket)
		if candidate == null: continue
		var quote: Dictionary = _demand.quote_placement(candidate) if _demand and _demand.has_method("quote_placement") else {"ok": true, "have": 0.0, "cost": 0.0, "threshold": 0.0, "reason": ""}
		result[bucket] = {"bucket_id": String(quote.get("bucket_id", bucket)), "affordable": bool(quote.get("ok", false)), "have": float(quote.get("have", 0.0)), "cost": float(quote.get("cost", 0.0)), "threshold": float(quote.get("threshold", 0.0)), "reason": String(quote.get("reason", "")), "candidate_building_id": _catalog_id_for(candidate)}
	return result

func _tier_one_candidate(bucket: String) -> Structure:
	for summary in _catalog.get_summary():
		var structure: Structure = _catalog.get_by_id(String(summary.get("building_id", "")))
		var profile := structure.find_metadata(BuildingProfile) as BuildingProfile if structure else null
		var cfg: Dictionary = _catalog.get_pool_config(structure.pool_id) if structure else {}
		if profile and profile.category == bucket and int(cfg.get("tier", 0)) == 1: return structure
	return null

func _catalog_id_for(structure: Structure) -> String:
	for summary in _catalog.get_summary():
		if _catalog.get_by_id(String(summary.get("building_id", ""))) == structure: return String(summary.get("building_id", ""))
	return ""

func _evaluate_gate(step: String) -> Dictionary:
	match step:
		"place_town_hall": return _gate(_evidence.town_hall != null, "building", _evidence.town_hall if _evidence.town_hall != null else {})
		"connect_rooted_roads": return _gate(int(_evidence.rooted_road_count) >= REQUIRED_ROOTED_ROAD_COUNT, "rooted_road_cells", {"count": _evidence.rooted_road_count, "required": REQUIRED_ROOTED_ROAD_COUNT, "cells": _evidence.rooted_road_cells})
		"establish_nature": return _gate(_evidence.nature_building_ids.size() >= 2 and int(_evidence.city_attractiveness) > 0, "nature_and_city_score", {"building_ids": _evidence.nature_building_ids, "city_score": _evidence.city_attractiveness})
		"place_first_home":
			var home: Variant = _evidence.early_homes.front() if not _evidence.early_homes.is_empty() else null
			if home != null and _state.experiment.anchor_home == null:
				_state.experiment.anchor_home = home.duplicate(true); _state.experiment.baseline = _score_evidence(home, null)
				_remember_home_baseline(_state.experiment, home, _state.experiment.baseline)
				for baseline_home in _evidence.early_homes:
					_remember_home_baseline(_state.experiment, baseline_home, _score_evidence(baseline_home, null))
				for other in _evidence.early_homes:
					if int(other.internal_id) != int(home.internal_id) and _footprint_distance(home.footprint, other.footprint) <= 1:
						_state.experiment.adjacency_result = "baseline_unavailable"
						_add_diagnostic("tutorial_home_baseline_unavailable", {"anchor_home": home, "existing_adjacent_home": other})
						break
			return _gate(home != null, "building_and_baseline", home if home != null else {})
		"observe_adjacent_home": return _gate(_state.experiment.after_adjacency != null, "measured_adjacency", {"anchor_home": _state.experiment.anchor_home, "adjacent_home": _state.experiment.adjacent_home, "result": _state.experiment.adjacency_result, "score": _state.experiment.after_adjacency})
		"improve_home": return _gate(_state.experiment.after_repair != null, "measured_repair", {"source": _state.experiment.repair_source, "score": _state.experiment.after_repair})
		"establish_workplace":
			var workplace: Variant = _first_where(_evidence.early_workplaces, func(row): return bool(row.get("separated", false)))
			return _gate(workplace != null, "separated_workplace", workplace if workplace != null else {})
		"confirm_work_participation":
			var workplace_receipt: Dictionary = _state.completed_receipts.get(RECEIPTS.establish_workplace, {})
			var wid: int = int(workplace_receipt.get("evidence", {}).get("internal_id", -1))
			var assignment: Variant = _first_where(_evidence.work_assignments, func(row): return int(row.get("destination_internal_id", row.get("internal_id", -1))) == wid)
			return _gate(assignment != null, "work_assignment", assignment if assignment != null else {})
		"place_first_shop":
			var shop: Variant = _first_where(_evidence.early_shops, func(row): return bool(row.get("rooted_accessible", false)))
			return _gate(shop != null, "rooted_shop", shop if shop != null else {})
	return _gate(false, "unknown", {})

func _gate(satisfied: bool, kind: String, evidence: Dictionary) -> Dictionary:
	return {"satisfied": satisfied, "evidence_kind": kind, "evidence": evidence.duplicate(true)}

func _replay_placement_observations() -> void:
	var experiment: Dictionary = _state.experiment
	for observation in _placement_observations:
		var building: Dictionary = observation.get("building", {})
		if building.is_empty(): continue
		if experiment.anchor_home == null and building.category == "residential" and int(building.tier) == 1:
			experiment.anchor_home = building.duplicate(true)
			experiment.baseline = observation.score.duplicate(true)
			_remember_home_baseline(experiment, building, observation.score)
		elif experiment.after_adjacency == null and building.category == "residential" and int(building.tier) == 1:
			var candidates: Array = []
			for other in _evidence.get("early_homes", []):
				if int(other.internal_id) != int(building.internal_id) and _footprint_distance(other.footprint, building.footprint) <= 1:
					candidates.append(other)
			candidates.sort_custom(_home_evidence_less)
			var selected: Variant = null
			var selected_baseline: Variant = null
			for candidate in candidates:
				var candidate_baseline: Variant = _baseline_for_home(experiment, candidate)
				if candidate_baseline != null:
					selected = candidate
					selected_baseline = candidate_baseline
					break
			if selected != null:
				var selected_was_observation_anchor := _is_observation_anchor(experiment, selected)
				experiment.anchor_home = selected.duplicate(true)
				if _using_rebound_home_ids:
					_rebound_anchor_internal_id = int(selected.get("internal_id", -1))
				experiment.baseline = selected_baseline.duplicate(true)
				experiment.adjacent_home = building.duplicate(true)
				var after: Dictionary = observation.score.duplicate(true) if selected_was_observation_anchor else _score_evidence(selected, building)
				after.home_delta = int(after.home_tile_score) - int(selected_baseline.home_tile_score)
				after.city_delta = int(after.city_score) - int(selected_baseline.city_score)
				experiment.adjacency_result = "penalty_observed" if int(after.home_delta) < 0 or int(after.city_delta) < 0 else "no_penalty"
				experiment.after_adjacency = after
			elif not candidates.is_empty():
				experiment.adjacency_result = "baseline_unavailable"
				_add_diagnostic("tutorial_home_baseline_unavailable", {"new_home": building, "candidate_homes": candidates})
			_remember_home_baseline(experiment, building, _score_evidence(building, null))
		elif experiment.after_adjacency != null and experiment.after_repair == null and building.category == "nature":
			# Structure placement is emitted before every downstream scoring listener has
			# necessarily refreshed. Re-read the affected home's authoritative score
			# during reconciliation so the repair proof cannot retain a pre-placement
			# sample while still preserving the exact nature source as evidence.
			var repaired: Dictionary = _score_evidence(experiment.anchor_home, building)
			if int(repaired.home_tile_score) > int(experiment.after_adjacency.home_tile_score):
				repaired.home_delta = int(repaired.home_tile_score) - int(experiment.after_adjacency.home_tile_score)
				repaired.city_delta = int(repaired.city_score) - int(experiment.after_adjacency.city_score)
				experiment.repair_source = building.duplicate(true); experiment.after_repair = repaired
	_state.experiment = experiment

static func _home_evidence_less(a: Dictionary, b: Dictionary) -> bool:
	if int(a.get("internal_id", -1)) != int(b.get("internal_id", -1)):
		return int(a.get("internal_id", -1)) < int(b.get("internal_id", -1))
	var aa: Dictionary = a.get("anchor", {})
	var bb: Dictionary = b.get("anchor", {})
	if int(aa.get("x", 0)) != int(bb.get("x", 0)):
		return int(aa.get("x", 0)) < int(bb.get("x", 0))
	return int(aa.get("z", 0)) < int(bb.get("z", 0))

func _remember_home_baseline(experiment: Dictionary, home: Dictionary, score: Dictionary) -> void:
	var rows: Array = experiment.get("home_baselines", [])
	var internal_id := int(home.get("internal_id", -1))
	if _using_rebound_home_ids:
		# At a load boundary an old persisted ID can now belong to a different
		# building. Existing rebound baselines stay immutable; newly observed homes
		# append their own record instead of overwriting by the colliding old ID.
		if _rebound_home_baselines.has(internal_id):
			return
		rows.append({"internal_id": internal_id, "identity": _stable_home_identity(home),
			"home": home.duplicate(true), "score": score.duplicate(true)})
		rows.sort_custom(func(a: Dictionary, b: Dictionary): return _home_evidence_less(a.home, b.home))
		experiment["home_baselines"] = rows
		_rebound_home_baselines[internal_id] = score.duplicate(true)
		return
	for index in rows.size():
		if int(rows[index].get("internal_id", -2)) == internal_id:
			rows[index] = {"internal_id": internal_id, "identity": _stable_home_identity(home),
				"home": home.duplicate(true), "score": score.duplicate(true)}
			experiment["home_baselines"] = rows
			return
	rows.append({"internal_id": internal_id, "identity": _stable_home_identity(home),
		"home": home.duplicate(true), "score": score.duplicate(true)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary): return _home_evidence_less(a.home, b.home))
	experiment["home_baselines"] = rows

func _baseline_for_home(experiment: Dictionary, home: Dictionary) -> Variant:
	var internal_id := int(home.get("internal_id", -1))
	if _using_rebound_home_ids:
		if _rebound_home_baselines.has(internal_id):
			return _rebound_home_baselines[internal_id].duplicate(true)
		if internal_id == _rebound_anchor_internal_id and experiment.get("baseline") is Dictionary:
			return experiment.baseline.duplicate(true)
		return null
	for row in experiment.get("home_baselines", []):
		if int(row.get("internal_id", -1)) == internal_id:
			return row.get("score", {}).duplicate(true)
	if experiment.get("anchor_home") is Dictionary and int(experiment.anchor_home.get("internal_id", -1)) == internal_id and experiment.get("baseline") is Dictionary:
		return experiment.baseline.duplicate(true)
	return null

func _rebind_persisted_home_evidence() -> void:
	var experiment: Dictionary = _state.get("experiment", {})
	var homes: Array = _evidence.get("early_homes", [])
	_rebound_home_baselines.clear()
	_rebound_anchor_internal_id = -1
	_using_rebound_home_ids = true
	var anchor: Variant = experiment.get("anchor_home")
	if anchor is Dictionary:
		var rebound_anchor: Variant = _current_home_for_stable_identity(anchor, homes)
		if rebound_anchor != null:
			_rebound_anchor_internal_id = int(rebound_anchor.get("internal_id", -1))
			# Legacy tutorial state persisted only the selected anchor baseline. Make
			# that score participate in the rebound map before filling any gaps so a
			# current score can never replace already-observed evidence.
			var anchor_baseline: Variant = experiment.get("baseline")
			if anchor_baseline is Dictionary:
				_rebound_home_baselines[_rebound_anchor_internal_id] = anchor_baseline.duplicate(true)

	for raw_row in experiment.get("home_baselines", []):
		if not raw_row is Dictionary:
			continue
		var row: Dictionary = raw_row
		var stored_home: Variant = row.get("home")
		var identity: Dictionary = {}
		if stored_home is Dictionary:
			identity = _stable_home_identity(stored_home)
		var stored_identity: Variant = row.get("identity")
		if identity.is_empty() and stored_identity is Dictionary:
			identity = _stable_home_identity(stored_identity)
		if not identity.is_empty():
			var current: Variant = _current_home_for_identity(identity, homes)
			if current != null:
				var score: Variant = row.get("score")
				if score is Dictionary:
					_rebound_home_baselines[int(current.get("internal_id", -1))] = score.duplicate(true)

	# Before feature 019, only the selected anchor had a saved baseline. A loaded
	# incomplete tutorial can nevertheless contain several other eligible homes.
	# Observe those missing homes now, at the load boundary and before the player's
	# next placement, so that a later adjacency with any of them has honest before /
	# after evidence. Persisted rows and the legacy anchor baseline always win.
	if experiment.get("after_adjacency") == null \
			and _state.get("completed_receipts", {}).has(RECEIPTS.place_first_home):
		var ordered_homes := homes.duplicate(true)
		ordered_homes.sort_custom(_home_evidence_less)
		for home in ordered_homes:
			if not home is Dictionary:
				continue
			var current_id := int(home.get("internal_id", -1))
			if current_id < 0 or _rebound_home_baselines.has(current_id):
				continue
			_remember_home_baseline(experiment, home, _score_evidence(home, null))
	_state.experiment = experiment

static func _current_home_for_stable_identity(stored: Dictionary, homes: Array) -> Variant:
	var identity := _stable_home_identity(stored)
	return _current_home_for_identity(identity, homes) if not identity.is_empty() else null

static func _current_home_for_identity(identity: Dictionary, homes: Array) -> Variant:
	for home in homes:
		if home is Dictionary and _stable_home_identity(home) == identity:
			return home
	return null

static func _stable_home_identity(home: Dictionary) -> Dictionary:
	var building_id := String(home.get("building_id", ""))
	var anchor: Variant = home.get("anchor")
	if building_id.is_empty() or not anchor is Dictionary:
		return {}
	var footprint: Array = []
	for cell in home.get("footprint", []):
		footprint.append(_coordinate(cell))
	footprint.sort_custom(func(a: Dictionary, b: Dictionary):
		return int(a.get("x", 0)) < int(b.get("x", 0)) if int(a.get("x", 0)) != int(b.get("x", 0)) else int(a.get("z", 0)) < int(b.get("z", 0)))
	return {"building_id": building_id, "anchor": _coordinate(anchor), "footprint": footprint}

func _is_observation_anchor(experiment: Dictionary, candidate: Dictionary) -> bool:
	if not experiment.get("anchor_home") is Dictionary:
		return false
	var candidate_id := int(candidate.get("internal_id", -1))
	if _using_rebound_home_ids:
		return candidate_id >= 0 and candidate_id == _rebound_anchor_internal_id
	return candidate_id >= 0 and candidate_id == int(experiment.anchor_home.get("internal_id", -2))

func _recover_experiment() -> void:
	if not _state.completed_receipts.has(RECEIPTS.place_first_home): return
	if _state.experiment.anchor_home is Dictionary: return
	if _evidence.early_homes.is_empty():
		_add_diagnostic("tutorial_home_baseline_unavailable")
		return
	var anchor: Dictionary = _evidence.early_homes.front().duplicate(true)
	_state.experiment.anchor_home = anchor
	_state.experiment.baseline = _score_evidence(anchor, null)
	_state.experiment.adjacency_result = "baseline_unavailable"
	_add_diagnostic("tutorial_home_baseline_unavailable", {"anchor_home": anchor})

func _placement_observation(position: Vector3i, structure_index: int) -> Dictionary:
	if not GameState or not GameState.map or not _catalog: return {}
	var anchor := Vector2i(position.x, position.z)
	for internal_id in GameState.building_registry:
		var entry: Dictionary = GameState.building_registry[internal_id]
		if entry.get("anchor", Vector2i.ZERO) == anchor and int(entry.get("structure", -1)) == structure_index:
			var building := _building_evidence(int(internal_id), entry)
			var score_home: Variant = _state.get("experiment", {}).get("anchor_home")
			if not score_home is Dictionary: score_home = building
			var score := _score_evidence(score_home, building)
			return {"building": building, "score": score}
	return {}

func _score_evidence(home: Dictionary, source: Variant) -> Dictionary:
	var anchor: Dictionary = home.get("anchor", {})
	var result := {"home_tile_score": int(_attractiveness.get_score(Vector2i(int(anchor.get("x", 0)), int(anchor.get("z", 0))))) if _attractiveness and _attractiveness.has_method("get_score") else 0, "city_score": _city_score(), "source_building_id": "", "source_anchor": null, "home_delta": null, "city_delta": null}
	if source is Dictionary:
		result.source_building_id = String(source.get("building_id", "")); result.source_anchor = source.get("anchor", {}).duplicate(true)
	return result

func _city_score() -> int: return int(_attractiveness.city_score()) if _attractiveness and _attractiveness.has_method("city_score") else 0

func _dispatch_milestone_for_step(step: String) -> void:
	match step:
		"establish_nature": _dispatch_beat("B05")
		"observe_adjacent_home": _dispatch_beat("B09")
		"confirm_work_participation": _dispatch_beat("B15")

func _dispatch_beat(beat: String) -> void:
	if _state.presentation_receipts.has(beat): return
	var event_id := String(FULL_EVENTS.get(beat, ""))
	if event_id.is_empty(): return
	if _events == null or not _events.has_method("get_event") or _events.get_event(event_id).is_empty():
		_add_diagnostic("tutorial_dialogue_event_missing", {"beat_id": beat, "event_id": event_id})
		return
	_state.presentation_receipts[beat] = true
	_persist_state()
	_events.fire(event_id)

func _publish_projection() -> void:
	var next := _make_projection()
	var comparable_old := _projection.duplicate(true); comparable_old.erase("revision")
	var comparable_new := next.duplicate(true); comparable_new.erase("revision")
	if comparable_old == comparable_new and not _projection.is_empty(): return
	_projection_revision += 1; next.revision = _projection_revision; _projection = next
	var beat := String(next.get("beat_id", ""))
	if not beat.is_empty() and not FULL_EVENTS.has(beat): _state.presentation_receipts[beat] = true; _persist_state()
	projection_changed.emit(_projection.duplicate(true))

func _make_projection() -> Dictionary:
	var step := String(_state.current_step_id)
	var beat := ""
	var variant := "default"
	var status := "active"
	var progress := {"current": 0, "required": 1, "unit": "building"}
	var blocker: Variant = null
	match step:
		"place_town_hall": beat = "B01"
		"connect_rooted_roads": beat = "B02"; progress = {"current": _evidence.rooted_road_count, "required": REQUIRED_ROOTED_ROAD_COUNT, "unit": "road_cells"}
		"establish_nature":
			if _evidence.nature_building_ids.size() < 2: beat = "B03"; progress = {"current": _evidence.nature_building_ids.size(), "required": 2, "unit": "distinct_building_ids"}
			else: beat = "B04"; variant = "beauty_not_positive"; blocker = {"code": "beauty_not_positive", "evidence": {"city_score": _evidence.city_attractiveness}}
		"place_first_home":
			var quote: Dictionary = _evidence.demand.get("residential", {})
			if not bool(quote.get("affordable", false)): beat = "B06"; status = "waiting"; variant = String(quote.get("reason", "waiting")); progress = {"current": quote.get("have", 0), "required": quote.get("cost", 0), "unit": "homes_demand"}; blocker = {"code": variant, "evidence": quote}
			else: beat = "B07"
		"observe_adjacent_home": beat = "B08"
		"improve_home": beat = "B10"
		"establish_workplace":
			if not _state.presentation_receipts.has("B11"):
				beat = "B11"; variant = "repair_acknowledgement"
			else:
				beat = "B12"
				if not _evidence.early_workplaces.is_empty(): beat = "B13"; variant = "access_or_radius"; blocker = {"code": "workplace_not_separated", "evidence": _evidence.early_workplaces.front()}
		"confirm_work_participation": beat = "B14"; status = "waiting"; progress = {"current": _evidence.work_assignments.size(), "required": 1, "unit": "work_assignments"}
		"place_first_shop":
			beat = "B16"
			if not _evidence.early_shops.is_empty(): beat = "B17"; variant = "rooted_access"; blocker = {"code": "shop_not_rooted", "evidence": _evidence.early_shops.front()}
		"complete": beat = "B18"; status = "complete"; progress = {"current": 1, "required": 1, "unit": "tutorial"}
	var copy_key := "opening.%s.%s" % [step, beat.to_lower()]
	return {"schema_version": 1, "revision": 0, "tutorial_id": TUTORIAL_ID, "step_id": step,
		"status": status, "projection_key": "%s|%s|%s|%s" % [TUTORIAL_ID, step, beat, variant],
		"beat_id": beat, "speaker_id": "ambrose", "expression": _expression_for(beat),
		"copy_key": copy_key, "copy_args": _projection_args(step), "text": String(COPY.get(beat, "")),
		"progress": progress, "blocker": blocker, "target": _projection_target(step),
		"full_dialogue_event_id": String(FULL_EVENTS.get(beat, ""))}

func _projection_args(step: String) -> Dictionary:
	return {"city_beauty": _evidence.get("city_attractiveness", 0), "step_id": step}

func _projection_target(step: String) -> Variant:
	match step:
		"place_town_hall": return {"kind": "building", "id": TOWN_HALL_ID, "label": "Town Hall"}
		"place_first_home": return {"kind": "pool", "id": "residential_t1", "label": "Homes"}
		"establish_workplace": return {"kind": "pool", "id": "industrial_t1", "label": "Industry"}
		"place_first_shop": return {"kind": "pool", "id": "commercial_t1", "label": "Shops"}
	return null

func _expression_for(beat: String) -> String:
	if beat in ["B05", "B11", "B15", "B18"]: return "pleased"
	if beat in ["B04", "B06", "B09", "B13", "B14", "B17"]: return "concerned"
	return "thoughtful"

func _add_diagnostic(code: String, evidence: Dictionary = {}) -> void:
	if not _evidence.has("diagnostics"): _evidence.diagnostics = []
	var row := {"code": code, "evidence": evidence.duplicate(true)}
	if row not in _evidence.diagnostics: _evidence.diagnostics.append(row)

func _first_where(rows: Array, predicate: Callable) -> Variant:
	for row in rows:
		if predicate.call(row): return row
	return null

func _buildings_sort(rows: Array) -> void:
	rows.sort_custom(func(a, b):
		if a.anchor.x != b.anchor.x: return a.anchor.x < b.anchor.x
		if a.anchor.z != b.anchor.z: return a.anchor.z < b.anchor.z
		if a.building_id != b.building_id: return a.building_id < b.building_id
		return int(a.internal_id) < int(b.internal_id))

static func _coordinate(value: Variant) -> Dictionary:
	if value is Vector2i: return {"x": value.x, "z": value.y}
	if value is Vector3i: return {"x": value.x, "z": value.z}
	if value is Dictionary: return {"x": int(value.get("x", 0)), "z": int(value.get("z", value.get("y", 0)))}
	return {"x": 0, "z": 0}

static func _footprint_distance(a: Array, b: Array) -> int:
	var best := 2147483647
	for ca in a:
		for cb in b:
			best = mini(best, maxi(absi(int(ca.get("x", 0)) - int(cb.get("x", 0))), absi(int(ca.get("z", 0)) - int(cb.get("z", 0)))))
	return best

static func _anchor_to_footprint_chebyshev(anchor: Dictionary, footprint: Array) -> int:
	var best := 2147483647
	for cell in footprint:
		best = mini(best, maxi(absi(int(anchor.x) - int(cell.x)), absi(int(anchor.z) - int(cell.z))))
	return best

static func _footprint_manhattan_distance(a: Array, b: Array) -> int:
	var best := 2147483647
	for ca in a:
		for cb in b:
			best = mini(best, absi(int(ca.get("x", 0)) - int(cb.get("x", 0))) + absi(int(ca.get("z", 0)) - int(cb.get("z", 0))))
	return best
