extends PluginBase

const BALANCE_PATH := "res://data/community/balance.json"
const COHORTS_PATH := "res://data/community/cohorts.json"
const COMMUNITY_SCHEMA_VERSION := 1

var _catalog: PluginBase
var _clock: PluginBase
var _residential: PluginBase
var _road_network: PluginBase
var _balance: Dictionary = {}
var _cohorts: Array = []
var _generator: CommunityPersonalityGenerator
var _rng := RandomNumberGenerator.new()
var _residents: Dictionary = {} # resident_id -> CommunityResident
var _migration := {"arrivals": 0, "departures": 0, "rejections": 0, "last_day": -1}
var _latest_event: String = ""
var _assignment_cache_key := ""
var _work_counts: Dictionary = {}
var _activity_counts: Dictionary = {}
var _assignment_records: Array = []

func get_plugin_name() -> String: return "Community"

func get_dependencies() -> Array[String]:
	return ["BuildingCatalog", "DayNight", "Residential", "RoadNetwork"]

func inject(deps: Dictionary) -> void:
	_catalog = deps.get("BuildingCatalog")
	_clock = deps.get("DayNight")
	_residential = deps.get("Residential")
	_road_network = deps.get("RoadNetwork")

func _plugin_ready() -> void:
	_load_authored_data()
	if _clock and not _clock.hour_changed.is_connected(_on_hour):
		_clock.hour_changed.connect(_on_hour)
	GameEvents.structure_placed.connect(_on_structure_placed)
	GameEvents.structure_demolished.connect(_on_structure_demolished)
	GameEvents.map_loaded.connect(_on_map_loaded)
	_on_map_loaded(GameState.map)

func _load_authored_data() -> void:
	_balance = _read_json(BALANCE_PATH)
	var cohort_doc := _read_json(COHORTS_PATH)
	_cohorts = cohort_doc.get("cohorts", [])
	_generator = CommunityPersonalityGenerator.new(
		_cohorts,
		int(_balance.get("personality_generation_version", 1)),
		float(_balance.get("sensitivity_min", 0.75)),
		float(_balance.get("sensitivity_max", 1.25)))

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("[Community] missing authored data: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("[Community] invalid authored data: %s" % path)
		return {}
	return parsed

func _on_map_loaded(map: DataMap) -> void:
	_residents.clear()
	_invalidate_assignments()
	if map == null:
		return
	if _generator == null:
		_load_authored_data()
	_rng.seed = maxi(1, map.community_rng_seed)
	if map.community_rng_state != 0:
		_rng.state = map.community_rng_state
	_migration = map.community_migration_counters.duplicate(true)
	_migration["last_day"] = map.community_migration_day
	for record in map.community_residents:
		if record is Dictionary:
			var resident := CommunityResident.from_dict(record)
			_residents[resident.resident_id] = resident
	if map.community_schema_version < COMMUNITY_SCHEMA_VERSION:
		_migrate_legacy_map(map)
	_persist()
	_emit_summary()

func _migrate_legacy_map(map: DataMap) -> void:
	# Old saves had no individual population records. Seed every occupied housing
	# slot in canonical order once; fresh empty maps remain empty and use migration.
	for slot in _housing_slots():
		var resident := _new_resident(int(map.community_next_resident_id))
		map.community_next_resident_id += 1
		resident.home_anchor = CommunityConstants.coordinate(slot["anchor"])
		_residents[resident.resident_id] = resident
	map.community_schema_version = COMMUNITY_SCHEMA_VERSION

func _new_resident(resident_id: int, forced_cohort: String = "", explicit_seed: int = 0) -> CommunityResident:
	var personal_seed := explicit_seed if explicit_seed != 0 else int(_rng.randi())
	return _generator.generate(personal_seed, resident_id, forced_cohort)

func _on_structure_placed(_position: Vector3i, _structure_index: int, _orientation: int) -> void:
	_invalidate_assignments()
	_persist()
	_emit_summary()

func _on_structure_demolished(position: Vector3i) -> void:
	var anchor := Vector2i(position.x, position.z)
	for resident in _residents.values():
		if resident.home_anchor == anchor:
			resident.home_anchor = null
			resident.homeless_hours = 0
			resident.activity_assignment = null
			resident.work_assignment = null
	_invalidate_assignments()
	_persist()
	_emit_summary()

func _on_hour(hour: float) -> void:
	var hour_i := int(hour) % 24
	var sources := _source_records(hour_i)
	_assign_residents(sources, hour_i)
	for resident in _sorted_residents():
		var evaluation := CommunityEffectEvaluator.evaluate(resident, sources, {"hour": hour_i})
		CommunityEffectEvaluator.update_qualities(
			resident, evaluation,
			float(_balance.get("quality_baseline", 50.0)),
			float(_balance.get("hourly_response_rate", 0.1)))
		_bound_resident_effects(resident)
	_relocate_homeless()
	_evaluate_departures()
	var absolute_hour: int = int(_clock.get_absolute_hour()) if _clock and _clock.has_method("get_absolute_hour") else 0
	var day: int = int(absolute_hour / 24)
	if hour_i == int(_balance.get("migration_hour", 6)) and day != int(_migration.get("last_day", -1)):
		_migration["last_day"] = day
		_run_daily_migration()
	_persist()
	_emit_summary()

func _source_records(hour: int) -> Array:
	var result: Array = []
	var building_ids := GameState.building_registry.keys()
	building_ids.sort_custom(func(a, b):
		var aa: Vector2i = GameState.building_registry[a].get("anchor", Vector2i.ZERO)
		var bb: Vector2i = GameState.building_registry[b].get("anchor", Vector2i.ZERO)
		return aa.x < bb.x if aa.x != bb.x else (aa.y < bb.y if aa.y != bb.y else int(a) < int(b)))
	for internal_id in building_ids:
		var entry: Dictionary = GameState.building_registry[internal_id]
		var structure_index := int(entry.get("structure", -1))
		if structure_index < 0 or structure_index >= GameState.structures.size():
			continue
		var structure: Structure = GameState.structures[structure_index]
		var profile := structure.find_metadata(CommunityEffectProfile) as CommunityEffectProfile
		var building_profile := structure.find_metadata(BuildingProfile) as BuildingProfile
		if profile == null and building_profile == null:
			continue
		var active := true
		var capacity := 0
		if building_profile:
			active = _in_window(hour, int(building_profile.active_start), int(building_profile.active_end))
			capacity = building_profile.capacity
		var anchor: Vector2i = entry.get("anchor", Vector2i.ZERO)
		var key := _anchor_key(anchor)
		var default_programme := profile.default_programme if profile else ""
		var programme := String(GameState.map.community_programmes.get(key, default_programme)) if GameState.map else default_programme
		var effects := profile.effects_for(programme) if profile else []
		effects = effects.duplicate(true)
		var available_programmes: Array = profile.programmes.keys() if profile else []
		available_programmes.sort()
		for effect in effects:
			if effect.get("capacity") != null:
				capacity = maxi(capacity, int(effect["capacity"]))
		var catalog_summary: Dictionary = _catalog.get_summary_by_index(structure_index) if _catalog and _catalog.has_method("get_summary_by_index") else {}
		var proximity := get_town_hall_proximity(int(internal_id))
		if building_profile and building_profile.category == "residential" and proximity.get("band", "") != "":
			effects.append({
				"effect_id": "town_hall_bustle_%s" % proximity["band"],
				"quality": "liveability", "manifestation": "neutral",
				"amount": float(proximity["home_liveability_penalty"]),
				"scope": "resident", "stacking_group": "town_hall_bustle",
				"requires_active_building": false,
				"reason": "Lived within %d road tiles of the busy Town Hall" % int(proximity["distance"]),
			})
		result.append({
			"internal_id": int(internal_id),
			"building_id": _catalog.get_id_by_index(structure_index) if _catalog else "",
			"anchor": anchor,
			"active": active,
			"category": building_profile.category if building_profile else "",
			"catalog_category": String(catalog_summary.get("category", "")),
			"community_role": String(catalog_summary.get("community_role", "")),
			"capacity": capacity,
			"programme": programme,
			"available_programmes": available_programmes,
			"building_schedule": {"start": int(building_profile.active_start), "end": int(building_profile.active_end)} if building_profile else null,
			"evaluation_hour": hour,
			"effects": effects,
			"participants": [],
			"town_hall_proximity": proximity,
		})
	return result

func get_town_hall_proximity(internal_id: int) -> Dictionary:
	var route: Dictionary = _road_network.get_route_from_town_hall(internal_id) if _road_network and _road_network.has_method("get_route_from_town_hall") else {}
	var distance := int(route.get("distance", -1))
	var tuning: Dictionary = _balance.get("town_hall_proximity", {})
	var band := ""
	if bool(route.get("reachable", false)) and distance <= int(tuning.get("core_max_road_tiles", 5)):
		band = "core"
	elif bool(route.get("reachable", false)) and distance <= int(tuning.get("near_max_road_tiles", 10)):
		band = "near"
	return {
		"reachable": bool(route.get("reachable", false)), "distance": distance, "band": band,
		"shop_activity_bonus": float(tuning.get("core_shop_activity_bonus", 0.2)) if band == "core" else (float(tuning.get("near_shop_activity_bonus", 0.1)) if band == "near" else 0.0),
		"home_liveability_penalty": float(tuning.get("core_home_liveability_penalty", -8.0)) if band == "core" else (float(tuning.get("near_home_liveability_penalty", -4.0)) if band == "near" else 0.0),
		"route": route,
	}

func _assign_activities(sources: Array) -> void:
	_assign_residents(sources, int(_clock.current_hour() if _clock else 0), true)

## Canonical deterministic allocation. The optional force flag keeps older unit
## tests that mutate authored sources within one hour able to request a refresh.
func _assign_residents(sources: Array, hour: int, force: bool = false) -> void:
	var revision := int(_road_network.get_revision()) if _road_network and _road_network.has_method("get_revision") else 0
	var cache_key := "%d|%d|%d|%d" % [hour, revision, _residents.size(), GameState.building_registry.size()]
	if not force and cache_key == _assignment_cache_key:
		_apply_cached_participants(sources)
		return
	_assignment_cache_key = cache_key
	_work_counts.clear()
	_activity_counts.clear()
	_assignment_records.clear()
	for resident in _residents.values():
		resident.work_assignment = null
		resident.activity_assignment = null
	for source in sources:
		source["participants"] = []

	var workplaces: Array = []
	for source in sources:
		if String(source.get("category", "")) == "industrial" and bool(source.get("active", true)) and int(source.get("capacity", 0)) > 0:
			workplaces.append(source)
	var work_remaining := {}
	for source in workplaces:
		work_remaining[int(source["internal_id"])] = int(source["capacity"])
	for resident in _sorted_residents():
		var ranked := _rank_reachable_sources(resident, workplaces, work_remaining, false, hour)
		if ranked.is_empty():
			continue
		var chosen: Dictionary = ranked[0]["source"]
		var chosen_id := int(chosen["internal_id"])
		work_remaining[chosen_id] = int(work_remaining[chosen_id]) - 1
		chosen["participants"].append(resident.resident_id)
		resident.work_assignment = _assignment_record(resident, chosen, "work", ranked[0], hour)
		_work_counts[chosen_id] = int(_work_counts.get(chosen_id, 0)) + 1
		_assignment_records.append(resident.work_assignment.duplicate(true))

	var participant_sources: Array = []
	for source in sources:
		if String(source.get("category", "")) == "industrial":
			continue
		if not source.get("active", true) or int(source.get("capacity", 0)) <= 0:
			continue
		for effect in source.get("effects", []):
			if effect.get("scope") == "participant" and CommunityEffectEvaluator.schedule_active(effect.get("schedule"), hour):
				participant_sources.append(source)
				break
	var remaining := {}
	for source in participant_sources:
		remaining[int(source["internal_id"])] = int(source["capacity"])
	for resident in _sorted_residents():
		if resident.work_assignment != null:
			continue
		var ranked := _rank_reachable_sources(resident, participant_sources, remaining, true, hour)
		if ranked.is_empty():
			continue
		var chosen: Dictionary = ranked[0]["source"]
		chosen["participants"].append(resident.resident_id)
		var chosen_id := int(chosen["internal_id"])
		remaining[chosen_id] -= 1
		resident.activity_assignment = _assignment_record(resident, chosen, "activity", ranked[0], hour)
		_activity_counts[chosen_id] = int(_activity_counts.get(chosen_id, 0)) + 1
		_assignment_records.append(resident.activity_assignment.duplicate(true))

func _rank_reachable_sources(resident: CommunityResident, sources: Array, remaining: Dictionary, use_benefit: bool, hour: int) -> Array:
	var ranked: Array = []
	for source in sources:
		var source_id := int(source["internal_id"])
		if int(remaining.get(source_id, 0)) <= 0:
			continue
		var route := _route_to_source(resident, source_id)
		if not bool(route.get("reachable", false)):
			continue
		var benefit := _participant_benefit(resident, source, hour) if use_benefit else 0.0
		if use_benefit and benefit <= 0.0:
			continue
		ranked.append({"source": source, "benefit": benefit, "distance": int(route.get("distance", 0)), "route": route})
	ranked.sort_custom(func(a, b):
		if use_benefit and a["benefit"] != b["benefit"]: return a["benefit"] > b["benefit"]
		if a["distance"] != b["distance"]: return a["distance"] < b["distance"]
		var aa: Vector2i = a["source"]["anchor"]
		var bb: Vector2i = b["source"]["anchor"]
		if aa.x != bb.x: return aa.x < bb.x
		if aa.y != bb.y: return aa.y < bb.y
		if a["source"]["building_id"] != b["source"]["building_id"]: return a["source"]["building_id"] < b["source"]["building_id"]
		return int(a["source"]["internal_id"]) < int(b["source"]["internal_id"]))
	return ranked

func _route_to_source(resident: CommunityResident, destination_id: int) -> Dictionary:
	if resident.home_anchor == null:
		return {"reachable": false, "distance": -1, "reason": "no_road_access"}
	if _road_network == null or not _road_network.has_method("get_route_between_buildings"):
		var destination_anchor: Vector2i = GameState.building_registry.get(destination_id, {}).get("anchor", resident.home_anchor)
		return {"reachable": true, "distance": CommunityConstants.manhattan(resident.home_anchor, destination_anchor), "reason": ""}
	var home_id := _building_id_at_anchor(CommunityConstants.coordinate(resident.home_anchor))
	if home_id < 0:
		return {"reachable": false, "distance": -1, "reason": "no_road_access"}
	return _road_network.get_route_between_buildings(home_id, destination_id)

func _building_id_at_anchor(anchor: Vector2i) -> int:
	var ids := GameState.building_registry.keys()
	ids.sort()
	for internal_id in ids:
		if CommunityConstants.coordinate(GameState.building_registry[internal_id].get("anchor")) == anchor:
			return int(internal_id)
	return -1

func _assignment_record(resident: CommunityResident, source: Dictionary, purpose: String, ranked: Dictionary, hour: int) -> Dictionary:
	var route: Dictionary = ranked.get("route", {})
	var components: Array = route.get("shared_component_ids", [])
	return {
		"resident_id": resident.resident_id,
		"purpose": purpose,
		"destination_internal_id": int(source["internal_id"]),
		"internal_id": int(source["internal_id"]),
		"building_id": source["building_id"],
		"anchor": CommunityConstants.coordinate_record(source["anchor"]),
		"programme": source.get("programme", ""),
		"route_distance": int(ranked.get("distance", 0)),
		"component_id": String(components[0]) if not components.is_empty() else "",
		"priority": 0 if purpose == "work" else 1,
		"allocation_order": _assignment_records.size(),
		"assigned_hour": hour,
	}

func _apply_cached_participants(sources: Array) -> void:
	var by_id := {}
	for source in sources:
		source["participants"] = []
		by_id[int(source["internal_id"])] = source
	for record in _assignment_records:
		var source: Variant = by_id.get(int(record.get("internal_id", -1)))
		if source != null:
			source["participants"].append(int(record["resident_id"]))

func _invalidate_assignments() -> void:
	_assignment_cache_key = ""
	_work_counts.clear()
	_activity_counts.clear()
	_assignment_records.clear()

func _ensure_assignments(hour: int) -> void:
	var sources := _source_records(hour)
	_assign_residents(sources, hour)

func get_fulfilled_workplace(anchor: Vector2i, hour: int) -> int:
	_ensure_assignments(hour)
	var internal_id := _building_id_at_anchor(anchor)
	return int(_work_counts.get(internal_id, 0))

func get_fulfilled_activity(anchor: Vector2i, hour: int) -> int:
	_ensure_assignments(hour)
	var internal_id := _building_id_at_anchor(anchor)
	return int(_activity_counts.get(internal_id, 0))

func get_assignment_records() -> Array:
	return _assignment_records.duplicate(true)

func _participant_benefit(resident: CommunityResident, source: Dictionary, hour: int = -1) -> float:
	var active_hour: int = hour if hour >= 0 else int(_clock.current_hour() if _clock else 0)
	var total := 0.0
	for effect in source.get("effects", []):
		if effect.get("scope") != "participant": continue
		if not CommunityEffectEvaluator.schedule_active(effect.get("schedule"), active_hour): continue
		var quality := String(effect.get("quality", ""))
		var value := float(effect.get("amount", 0.0)) * CommunityEffectEvaluator.preference_multiplier(resident, quality, String(effect.get("manifestation", "neutral")))
		total += value * float(resident.quality_importance.get(quality, 0.0))
	return total

func _run_daily_migration() -> void:
	var batch := int(_balance.get("candidate_batch_size", 4))
	for _index in batch:
		var next_id := GameState.map.community_next_resident_id if GameState.map else _next_id()
		var candidate := _new_resident(next_id)
		var quote := quote_migration(candidate)
		if quote.get("ok", false):
			candidate.home_anchor = CommunityConstants.coordinate(quote["home_anchor"])
			candidate.target_qualities = quote["target_qualities"].duplicate(true)
			candidate.current_qualities = quote["target_qualities"].duplicate(true)
			candidate.composite_happiness = float(quote["predicted_happiness"])
			_residents[candidate.resident_id] = candidate
			if GameState.map: GameState.map.community_next_resident_id += 1
			_migration["arrivals"] = int(_migration.get("arrivals", 0)) + 1
			GameEvents.community_resident_arrived.emit(candidate.resident_id, candidate.home_anchor)
			_latest_event = "Resident #%d arrived" % candidate.resident_id
			GameEvents.community_notification.emit("arrival", candidate.resident_id, _latest_event)
		else:
			_migration["rejections"] = int(_migration.get("rejections", 0)) + 1
			var reason := String(quote.get("reason", "below_threshold"))
			_latest_event = "Arrival rejected: no free housing" if reason == "no_capacity" else "Arrival rejected: town fit below threshold"
			GameEvents.community_notification.emit("capacity" if reason == "no_capacity" else "rejection", 0, _latest_event)

func quote_migration(candidate: CommunityResident) -> Dictionary:
	var homes := _free_housing_slots()
	if homes.is_empty():
		return {"ok": false, "reason": "no_capacity"}
	# Every free slot at one anchor receives identical authored effects. Quote the
	# first free slot once per building rather than repeating the full 24-hour
	# evaluation for every unit of capacity.
	var representative_homes: Array = []
	var represented_anchors := {}
	for home in homes:
		var key := _anchor_key(home.get("anchor"))
		if represented_anchors.has(key):
			continue
		represented_anchors[key] = true
		representative_homes.append(home)
	# Source discovery is independent of a candidate's proposed home. Cache one
	# pristine authored day and deep-copy each hour before assigning participants.
	var sources_by_hour: Array = []
	for evaluation_hour in 24:
		sources_by_hour.append(_source_records(evaluation_hour))
	var results: Array = []
	for home in representative_homes:
		var previous_home: Variant = candidate.home_anchor
		candidate.home_anchor = CommunityConstants.coordinate(home["anchor"])
		var daily_totals := {}
		for quality in CommunityConstants.QUALITIES: daily_totals[quality] = 0.0
		var predicted_effects: Array = []
		# A migration quote considers one representative authored day so scheduled
		# work/night opportunities and their nuisances remain visible at dawn.
		for evaluation_hour in 24:
			# Evaluators only read source records. Copy the array and the one selected
			# participant source instead of deep-copying every nested effect record for
			# every candidate/home/hour combination.
			var sources: Array = sources_by_hour[evaluation_hour].duplicate()
			var best_source_index := -1
			var best_benefit := 0.0
			for source_index in sources.size():
				var source: Dictionary = sources[source_index]
				if not bool(_route_to_source(candidate, int(source.get("internal_id", -1))).get("reachable", false)):
					continue
				var benefit := _participant_benefit(candidate, source, evaluation_hour)
				if benefit > best_benefit:
					best_benefit = benefit
					best_source_index = source_index
			if best_source_index >= 0:
				var selected_source: Dictionary = sources[best_source_index].duplicate()
				selected_source["participants"] = [candidate.resident_id]
				sources[best_source_index] = selected_source
			var evaluation := CommunityEffectEvaluator.evaluate(candidate, sources, {"hour": evaluation_hour})
			for quality in CommunityConstants.QUALITIES:
				daily_totals[quality] += float(evaluation["totals"].get(quality, 0.0)) / 24.0
			for effect in evaluation["effects"]:
				var timed_effect: Dictionary = effect.duplicate(true)
				timed_effect["active_hour"] = evaluation_hour
				predicted_effects.append(timed_effect)
		var targets := {}
		var composite := 0.0
		for quality in CommunityConstants.QUALITIES:
			var target := clampf(float(_balance.get("quality_baseline", 50.0)) + float(daily_totals.get(quality, 0.0)), 0.0, 100.0)
			targets[quality] = target
			composite += target * float(candidate.quality_importance[quality])
		predicted_effects.sort_custom(func(a: Dictionary, b: Dictionary): return absf(float(a.get("applied_amount", 0.0))) > absf(float(b.get("applied_amount", 0.0))))
		results.append({"home_anchor": home["anchor"], "slot": home.get("slot", 0), "predicted_happiness": composite, "target_qualities": targets, "effects": predicted_effects.slice(0, int(_balance.get("effect_snapshot_limit", 12)))})
		candidate.home_anchor = previous_home
	results.sort_custom(func(a, b):
		if a["predicted_happiness"] != b["predicted_happiness"]: return a["predicted_happiness"] > b["predicted_happiness"]
		var aa: Variant = CommunityConstants.coordinate(a["home_anchor"])
		var bb: Variant = CommunityConstants.coordinate(b["home_anchor"])
		if aa.x != bb.x: return aa.x < bb.x
		if aa.y != bb.y: return aa.y < bb.y
		return int(a["slot"]) < int(b["slot"]))
	var best: Dictionary = results[0]
	var threshold := float(_balance.get("migration_threshold", 60.0))
	if float(best["predicted_happiness"]) < threshold:
		return {"ok": false, "reason": "below_threshold", "predicted_happiness": CommunityConstants.rounded(best["predicted_happiness"]), "threshold": threshold}
	best["ok"] = true
	best["home_anchor"] = CommunityConstants.coordinate_record(best["home_anchor"])
	best["predicted_happiness"] = CommunityConstants.rounded(best["predicted_happiness"])
	best["target_qualities"] = CommunityConstants.rounded_map(best["target_qualities"])
	return best

func _relocate_homeless() -> void:
	var homes := _free_housing_slots()
	for resident in _sorted_residents():
		if resident.home_anchor != null:
			resident.homeless_hours = 0
			continue
		if not homes.is_empty():
			var home: Dictionary = homes.pop_front()
			resident.home_anchor = CommunityConstants.coordinate(home["anchor"])
			resident.homeless_hours = 0
			GameEvents.community_resident_rehomed.emit(resident.resident_id, resident.home_anchor)
			_latest_event = "Resident #%d rehomed" % resident.resident_id
			GameEvents.community_notification.emit("rehome", resident.resident_id, _latest_event)
		else:
			resident.homeless_hours += 1

func _evaluate_departures() -> void:
	var leaving: Array = []
	var threshold := float(_balance.get("departure_threshold", 30.0))
	var grace := int(_balance.get("departure_grace_hours", 24))
	var homeless_grace := int(_balance.get("relocation_grace_hours", 24))
	for resident in _sorted_residents():
		if resident.home_anchor == null:
			if resident.homeless_hours >= homeless_grace:
				leaving.append({"resident_id": resident.resident_id, "reason": "relocation_failed"})
			continue
		if resident.composite_happiness < threshold:
			resident.below_departure_hours += 1
		else:
			resident.below_departure_hours = 0
		if resident.below_departure_hours >= grace:
			leaving.append({"resident_id": resident.resident_id, "reason": "sustained_unhappiness"})
	for departure in leaving:
		var resident_id := int(departure["resident_id"])
		_residents.erase(resident_id)
		_migration["departures"] = int(_migration.get("departures", 0)) + 1
		GameEvents.community_resident_departed.emit(resident_id, String(departure["reason"]))
		_latest_event = "Resident #%d departed: %s" % [resident_id, String(departure["reason"]).replace("_", " ")]
		GameEvents.community_notification.emit("departure", resident_id, _latest_event)

func _housing_slots() -> Array:
	if _residential and _residential.has_method("get_housing_slots"):
		return _residential.get_housing_slots()
	var slots: Array = []
	for internal_id in GameState.building_registry:
		var entry: Dictionary = GameState.building_registry[internal_id]
		var sid := int(entry.get("structure", -1))
		if sid < 0 or sid >= GameState.structures.size(): continue
		var profile := GameState.structures[sid].find_metadata(BuildingProfile) as BuildingProfile
		if profile == null or profile.category != "residential": continue
		for slot in profile.capacity:
			slots.append({"anchor": entry["anchor"], "slot": slot})
	slots.sort_custom(func(a, b):
		var aa: Vector2i = a["anchor"]; var bb: Vector2i = b["anchor"]
		return aa.x < bb.x if aa.x != bb.x else (aa.y < bb.y if aa.y != bb.y else int(a["slot"]) < int(b["slot"])))
	return slots

func _free_housing_slots() -> Array:
	var occupancy := {}
	for resident in _residents.values():
		if resident.home_anchor != null:
			var key := _anchor_key(resident.home_anchor)
			occupancy[key] = int(occupancy.get(key, 0)) + 1
	var free: Array = []
	for slot in _housing_slots():
		var key := _anchor_key(slot["anchor"])
		if int(slot.get("slot", 0)) >= int(occupancy.get(key, 0)):
			free.append(slot)
	return free

func set_programme(anchor: Vector2i, programme_id: String) -> bool:
	for source in _source_records(_clock.current_hour() if _clock else 0):
		if source["anchor"] != anchor: continue
		var structure: Structure = GameState.structures[GameState.building_registry[source["internal_id"]]["structure"]]
		var profile := structure.find_metadata(CommunityEffectProfile) as CommunityEffectProfile
		if profile and profile.programmes.has(programme_id):
			GameState.map.community_programmes[_anchor_key(anchor)] = programme_id
			_persist()
			GameEvents.community_programme_changed.emit(anchor, programme_id)
			return true
	return false

## UI-facing intent boundary. Validation and mutation remain in set_programme.
func request_programme_change(anchor: Vector2i, programme_id: String) -> Dictionary:
	if set_programme(anchor, programme_id):
		return {"ok": true, "reason": ""}
	return {"ok": false, "reason": "Programme is not available for this place"}

## Narrow read-only presentation projection. This joins canonical state with
## authored labels/schedules but does not perform simulation calculations.
func get_ui_model(previous_projection: Dictionary = {}) -> Dictionary:
	var hour := int(_clock.current_hour()) if _clock and _clock.has_method("current_hour") else 0
	var absolute_hour := int(_clock.get_absolute_hour()) if _clock and _clock.has_method("get_absolute_hour") else hour
	var snapshot := get_snapshot(false)
	snapshot["latest_event"] = _latest_event
	return CommunityInspector.project(snapshot, get_presentation_context(hour), {"hour": hour, "absolute_hour": absolute_hour}, _balance, previous_projection)

func get_presentation_context(hour: int = -1) -> Dictionary:
	var active_hour := hour if hour >= 0 else (int(_clock.current_hour()) if _clock and _clock.has_method("current_hour") else 0)
	var names := {}
	if _catalog:
		for summary in _catalog.get_summary():
			names[String(summary.get("building_id", ""))] = String(summary.get("display_name", summary.get("building_id", "")))
	var cohort_names := {}
	for cohort in _cohorts:
		cohort_names[String(cohort.get("cohort_id", "general"))] = String(cohort.get("display_name", "Residents"))
	return {
		"building_names": names,
		"cohort_names": cohort_names,
		"places": _source_records(active_hour),
		"operation": get_operation_records(active_hour),
	}

func get_population() -> int: return _residents.size()
func get_capacity() -> int: return _housing_slots().size()

func get_population_at(anchor: Vector2i) -> int:
	var total := 0
	for resident in _residents.values():
		if resident.home_anchor == anchor: total += 1
	return total

func get_average_composite() -> float:
	if _residents.is_empty(): return 50.0
	var total := 0.0
	for resident in _residents.values(): total += resident.composite_happiness
	return total / float(_residents.size())

## Bounded demand input derived only from residents actually living in the
## town. Unserved decoration in an empty area cannot increase this signal.
func get_residential_demand_signal() -> int:
	return 0 if _residents.is_empty() else int(round(get_average_composite() * 5.0))

func get_resident_records(include_effects: bool = true) -> Array:
	var records: Array = []
	var limit := int(_balance.get("resident_snapshot_limit", 500))
	var effect_limit := int(_balance.get("effect_snapshot_limit", 12))
	for resident in _sorted_residents().slice(0, limit):
		records.append(resident.to_dict(include_effects, effect_limit))
	return records

func get_snapshot(compact: bool = false) -> Dictionary:
	var averages := {}
	for quality in CommunityConstants.QUALITIES: averages[quality] = 0.0
	for resident in _residents.values():
		for quality in CommunityConstants.QUALITIES:
			averages[quality] += float(resident.current_qualities[quality])
	if not _residents.is_empty():
		for quality in CommunityConstants.QUALITIES: averages[quality] /= float(_residents.size())
	var snapshot := {
		"population": get_population(),
		"capacity": get_capacity(),
		"average_qualities": CommunityConstants.rounded_map(averages),
		"average_composite_happiness": CommunityConstants.rounded(get_average_composite()),
		"personality_distribution": _personality_distribution(),
		"migration": _migration.duplicate(true),
		"effect_summary": _effect_summary(),
		"assignments": get_assignment_records(),
		"spatial": get_spatial_snapshot(),
		"latest_event": _latest_event,
	}
	if not compact:
		snapshot["residents"] = get_resident_records(true)
	return snapshot

func get_spatial_snapshot() -> Dictionary:
	var exposures: Array = []
	var coverage_by_key := {}
	for resident in _sorted_residents():
		for effect_raw in resident.applied_effects:
			var effect: Dictionary = effect_raw
			var record := effect.duplicate(true)
			exposures.append(record)
			var sign := "positive" if float(effect.get("applied_amount", 0.0)) >= 0.0 else "negative"
			var key := "%s|%s|%s" % [effect.get("effect_id", ""), effect.get("stacking_group", ""), sign]
			if not coverage_by_key.has(key):
				coverage_by_key[key] = {
					"effect_id": effect.get("effect_id", ""),
					"stacking_group": effect.get("stacking_group", ""),
					"sign": sign,
					"resident_ids": [],
					"source_anchors": [],
					"exposure_count": 0,
					"applied_total": 0.0,
				}
			var row: Dictionary = coverage_by_key[key]
			if resident.resident_id not in row["resident_ids"]:
				row["resident_ids"].append(resident.resident_id)
			var source_anchor: Variant = effect.get("source_anchor")
			if source_anchor not in row["source_anchors"]:
				row["source_anchors"].append(source_anchor)
			row["exposure_count"] = int(row["exposure_count"]) + 1
			row["applied_total"] = float(row["applied_total"]) + float(effect.get("applied_amount", 0.0))
	exposures.sort_custom(func(a: Dictionary, b: Dictionary): return String(a.get("exposure_id", "")) < String(b.get("exposure_id", "")))
	var coverage: Array = coverage_by_key.values()
	for row in coverage:
		row["resident_ids"].sort()
		row["distinct_resident_count"] = row["resident_ids"].size()
		row["applied_total"] = CommunityConstants.rounded(float(row["applied_total"]))
	coverage.sort_custom(func(a: Dictionary, b: Dictionary):
		return String(a["effect_id"]) < String(b["effect_id"]) if a["effect_id"] != b["effect_id"] else String(a["stacking_group"]) < String(b["stacking_group"]))
	return {"exposures": exposures, "coverage": coverage, "resident_serving_nature": _resident_serving_nature(exposures)}

func get_placement_preview(structure_index: int, anchor: Vector2i, _rotation: int = 0) -> Dictionary:
	if structure_index < 0 or structure_index >= GameState.structures.size(): return {}
	var profile := GameState.structures[structure_index].find_metadata(CommunityEffectProfile) as CommunityEffectProfile
	if profile == null: return {}
	var categories: Array = []
	var homes_in_range: Array[int] = []
	var newly_served: Array[int] = []
	var overlapping: Array[int] = []
	var max_radius := 0
	for effect in profile.effects:
		var amount := float(effect.get("amount", 0.0))
		var radius := int(effect.get("radius", -1)) if effect.get("radius") != null else -1
		max_radius = maxi(max_radius, radius)
		categories.append({"effect_id": effect.get("effect_id", ""), "quality": effect.get("quality", ""), "scope": effect.get("scope", ""), "sign": "positive" if amount >= 0.0 else "negative", "radius": radius})
		if String(effect.get("scope", "")) != "local": continue
		for resident in _sorted_residents():
			if resident.home_anchor == null or CommunityConstants.manhattan(resident.home_anchor, anchor) > radius: continue
			if resident.resident_id not in homes_in_range: homes_in_range.append(resident.resident_id)
			if amount <= 0.0: continue
			var already_covered := false
			for applied in resident.applied_effects:
				if float(applied.get("applied_amount", 0.0)) > 0.0 and String(applied.get("stacking_group", "")) == String(effect.get("stacking_group", "")):
					already_covered = true
					break
			if already_covered:
				if resident.resident_id not in overlapping: overlapping.append(resident.resident_id)
			elif resident.resident_id not in newly_served:
				newly_served.append(resident.resident_id)
	categories.sort_custom(func(a: Dictionary, b: Dictionary): return String(a["effect_id"]) < String(b["effect_id"]))
	homes_in_range.sort(); newly_served.sort(); overlapping.sort()
	return {"anchor": CommunityConstants.coordinate_record(anchor), "categories": categories, "max_radius": max_radius,
		"homes_in_range": homes_in_range, "newly_served_homes": newly_served, "overlapping_coverage_homes": overlapping}

func _resident_serving_nature(exposures: Array) -> Array:
	var sources := _source_records(int(_clock.current_hour()) if _clock else 0)
	_assign_residents(sources, int(_clock.current_hour()) if _clock else 0)
	var free_home_anchors: Array = []
	for slot in _free_housing_slots():
		var candidate_anchor: Variant = CommunityConstants.coordinate_record(slot.get("anchor"))
		if candidate_anchor != null and candidate_anchor not in free_home_anchors: free_home_anchors.append(candidate_anchor)
	var result: Array = []
	for source in sources:
		if String(source.get("catalog_category", "")) != "nature": continue
		var anchor: Dictionary = CommunityConstants.coordinate_record(source.get("anchor"))
		var served_residents: Array[int] = []
		var candidate_homes: Array = []
		var applied_total := 0.0
		for exposure in exposures:
			if _anchor_key(exposure.get("source_anchor")) != _anchor_key(anchor): continue
			var resident_id := int(exposure.get("resident_id", 0))
			if resident_id not in served_residents: served_residents.append(resident_id)
			applied_total += float(exposure.get("applied_amount", 0.0))
		for home_record in free_home_anchors:
			var home: Variant = CommunityConstants.coordinate(home_record)
			for effect in source.get("effects", []):
				if String(effect.get("scope", "")) == "local" and CommunityConstants.manhattan(home, source.get("anchor")) <= int(effect.get("radius", 0)):
					candidate_homes.append(home_record)
					break
		served_residents.sort()
		candidate_homes.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["x"]) < int(b["x"]) if a["x"] != b["x"] else int(a["z"]) < int(b["z"]))
		var participants: Array = source.get("participants", []).duplicate()
		participants.sort()
		result.append({
			"internal_id": int(source.get("internal_id", -1)),
			"building_id": source.get("building_id", ""),
			"anchor": anchor,
			"role": source.get("community_role", ""),
			"occupied_resident_ids": served_residents,
			"candidate_home_anchors": candidate_homes,
			"reachable_participant_ids": participants,
			"resident_serving": not served_residents.is_empty() or not candidate_homes.is_empty() or not participants.is_empty(),
			"applied_total": CommunityConstants.rounded(applied_total),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["internal_id"]) < int(b["internal_id"]))
	return result

func get_operation_records(hour: int = -1) -> Array:
	var active_hour := hour if hour >= 0 else int(_clock.current_hour() if _clock else 0)
	var sources := _source_records(active_hour)
	_assign_residents(sources, active_hour)
	var result: Array = []
	for source in sources:
		var category := String(source.get("category", ""))
		var has_participant_effect := false
		for effect in source.get("effects", []):
			if String(effect.get("scope", "")) == "participant":
				has_participant_effect = true
				break
		if category not in ["industrial", "commercial"] and not has_participant_effect:
			continue
		var internal_id := int(source["internal_id"])
		var access: Dictionary = _road_network.get_access_for_building(internal_id) if _road_network and _road_network.has_method("get_access_for_building") else {"road_accessible": true, "component_ids": [], "stops": []}
		var fulfilled := int(_work_counts.get(internal_id, 0)) if category == "industrial" else int(_activity_counts.get(internal_id, 0))
		var reasons: Array[String] = []
		if not bool(access.get("road_accessible", false)):
			reasons.append("no_road_access")
		elif not bool(source.get("active", true)):
			reasons.append("outside_active_hours")
		elif int(source.get("capacity", 0)) <= 0:
			reasons.append("no_free_capacity")
		elif fulfilled <= 0:
			if not _residents.is_empty(): reasons.append("isolated_road_component")
			reasons.append("no_reachable_residents")
		result.append({
			"internal_id": internal_id,
			"building_id": source.get("building_id", ""),
			"anchor": CommunityConstants.coordinate_record(source.get("anchor")),
			"category": category,
			"road_accessible": access.get("road_accessible", false),
			"component_ids": access.get("component_ids", []),
			"stops": access.get("stops", []),
			"open_now": source.get("active", true),
			"capacity": int(source.get("capacity", 0)),
			"fulfilled": fulfilled,
			"available_capacity": maxi(0, int(source.get("capacity", 0)) - fulfilled),
			"operating": reasons.is_empty() and fulfilled > 0,
			"latest_activity": fulfilled if category == "commercial" or has_participant_effect else 0,
			"town_hall_proximity": source.get("town_hall_proximity", {}).duplicate(true),
			"reasons": reasons,
			"primary_reason": reasons[0] if not reasons.is_empty() else "",
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["internal_id"]) < int(b["internal_id"]))
	return result

func _personality_distribution() -> Dictionary:
	var result := {"cohorts": {}, "dominant_lenses": {"identity": 0, "freedom": 0, "care": 0}}
	for resident in _residents.values():
		var cohort := String(resident.cohort_id) if resident.cohort_id != null else "general"
		result["cohorts"][cohort] = int(result["cohorts"].get(cohort, 0)) + 1
		var totals := {"identity": 0.0, "freedom": 0.0, "care": 0.0}
		for quality in CommunityConstants.QUALITIES:
			for lens in CommunityConstants.LENSES:
				totals[lens] += float(resident.manifestation_weights[quality][lens])
		var dominant := "identity"
		for lens in CommunityConstants.LENSES:
			if totals[lens] > totals[dominant]: dominant = lens
		result["dominant_lenses"][dominant] += 1
	return result

func _effect_summary() -> Array:
	var totals := {}
	for resident in _residents.values():
		for effect in resident.applied_effects:
			var key := "%s|%s|%s" % [effect.get("source_building_id", ""), effect.get("effect_id", ""), effect.get("quality", "")]
			if not totals.has(key):
				totals[key] = {"source_building_id": effect.get("source_building_id"), "effect_id": effect.get("effect_id"), "quality": effect.get("quality"), "reason": effect.get("reason", ""), "amount": 0.0, "residents": 0}
			totals[key]["amount"] += float(effect.get("applied_amount", 0.0))
			totals[key]["residents"] += 1
	var rows: Array = totals.values()
	for row in rows: row["amount"] = CommunityConstants.rounded(row["amount"])
	rows.sort_custom(func(a, b):
		var aa := absf(float(a["amount"])); var bb := absf(float(b["amount"]))
		return aa > bb if aa != bb else String(a["effect_id"]) < String(b["effect_id"]))
	return rows.slice(0, int(_balance.get("effect_snapshot_limit", 12)))

func _bound_resident_effects(resident: CommunityResident) -> void:
	resident.applied_effects.sort_custom(func(a: Dictionary, b: Dictionary):
		var aa := absf(float(a.get("applied_amount", 0.0)))
		var bb := absf(float(b.get("applied_amount", 0.0)))
		return aa > bb if aa != bb else String(a.get("effect_id", "")) < String(b.get("effect_id", "")))
	resident.applied_effects = resident.applied_effects.slice(0, int(_balance.get("effect_snapshot_limit", 12)))

func add_resident_for_tests(resident: CommunityResident) -> void:
	_residents[resident.resident_id] = resident
	_persist()

func clear_residents_for_tests() -> void:
	_residents.clear()
	_persist()

## Scenario-only deterministic seeding. It creates normal resident records and
## never mutates buildings, capacity, cash, demand, or placement state.
func apply_scenario_fixture(fixture: Dictionary, scenario_seed: int) -> void:
	if fixture.is_empty(): return
	_residents.clear()
	_rng.seed = scenario_seed
	var next_id := 1
	for definition in fixture.get("residents", []):
		if not definition is Dictionary: continue
		var resident_id := int(definition.get("resident_id", next_id))
		var personal_seed := int(definition.get("seed", scenario_seed * 1009 + resident_id))
		var resident := _new_resident(resident_id, String(definition.get("cohort_id", "")), personal_seed)
		resident.home_anchor = CommunityConstants.coordinate(definition.get("home_anchor"))
		_residents[resident_id] = resident
		next_id = maxi(next_id, resident_id + 1)
	if GameState.map:
		GameState.map.community_next_resident_id = next_id
	_persist()
	_emit_summary()

func _persist() -> void:
	if GameState.map == null: return
	GameState.map.community_schema_version = COMMUNITY_SCHEMA_VERSION
	GameState.map.community_generation_version = int(_balance.get("personality_generation_version", 1))
	GameState.map.community_residents = []
	for resident in _sorted_residents():
		GameState.map.community_residents.append(resident.to_dict(false))
	GameState.map.community_rng_state = _rng.state
	GameState.map.community_migration_day = int(_migration.get("last_day", -1))
	GameState.map.community_migration_counters = {
		"arrivals": int(_migration.get("arrivals", 0)),
		"departures": int(_migration.get("departures", 0)),
		"rejections": int(_migration.get("rejections", 0)),
	}

func _emit_summary() -> void:
	GameEvents.community_population_changed.emit(get_population(), get_capacity())
	GameEvents.community_qualities_changed.emit(get_snapshot(true)["average_qualities"])
	GameEvents.community_ui_refresh_requested.emit("community_state")

func _sorted_residents() -> Array:
	var result: Array = _residents.values()
	result.sort_custom(func(a: CommunityResident, b: CommunityResident): return a.resident_id < b.resident_id)
	return result

func _next_id() -> int:
	var highest := 0
	for id in _residents: highest = maxi(highest, int(id))
	return highest + 1

static func _anchor_key(anchor: Variant) -> String:
	var cell: Variant = CommunityConstants.coordinate(anchor)
	return "" if cell == null else "%d,%d" % [cell.x, cell.y]

static func _in_window(hour: int, start: int, end: int) -> bool:
	start %= 24; end %= 24; hour %= 24
	if start == end: return true
	return hour >= start and hour < end if start < end else hour >= start or hour < end
