extends PluginBase

const BALANCE_PATH := "res://data/community/balance.json"
const COHORTS_PATH := "res://data/community/cohorts.json"
const COMMUNITY_SCHEMA_VERSION := 1
const CompiledRuntime := preload("res://scripts/community/community_compiled_runtime.gd")
const CompiledEvaluator := preload("res://scripts/community/community_compiled_evaluator.gd")
const SimulationIntentType := preload("res://scripts/simulation/simulation_intent.gd")
const AuthoritativeChangeSetType := preload("res://scripts/simulation/authoritative_change_set.gd")

var _catalog: PluginBase
var _clock: PluginBase
var _residential: PluginBase
var _road_network: PluginBase
var _performance_monitor: PluginBase
var _simulation_transaction: PluginBase
var _projection_registry: PluginBase
var _balance: Dictionary = {}
var _cohorts: Array = []
var _generator: CommunityPersonalityGenerator
var _rng := RandomNumberGenerator.new()
var _residents: Dictionary = {} # resident_id -> CommunityResident
var _resident_order: Array[int] = []
var _persisted_records_by_id: Dictionary = {}
var _migration := {"arrivals": 0, "departures": 0, "rejections": 0, "last_day": -1}
var _latest_event: String = ""
var _assignment_cache_key := ""
var _assignment_prepared_hour_key := ""
var _hour_source_cache_key := ""
var _hour_source_cache: Array = []
var _assignment_revision: int = 0
var _work_counts: Dictionary = {}
var _activity_counts: Dictionary = {}
var _assignment_records: Array = []
var _changed_assignment_resident_ids: Array[int] = []
var _assignment_route_cache: Dictionary = {}
var _assignment_schedule_states: Dictionary = {}
var _compiled_runtime: Variant = null
var _runtime_dependency_revisions: Dictionary = {}
var _static_runtime_revisions: Dictionary = {}
var _explanation_cache_key := ""
var _explanation_cache: Dictionary = {}
var _migration_fact_cache_key := ""
var _migration_fact_cache: Dictionary = {}
var _migration_fact_cache_hits := 0
var _migration_fact_cache_misses := 0
var _pending_hourly_events: Array = []
var _defer_hourly_publication := false
var compiled_evaluator_enabled := true
var _compat_events_to_ignore := 0

func get_plugin_name() -> String: return "Community"

func get_dependencies() -> Array[String]:
	return ["BuildingCatalog", "DayNight", "Residential", "RoadNetwork", "PerformanceMonitor", "SimulationTransaction", "ProjectionRegistry"]

func inject(deps: Dictionary) -> void:
	_catalog = deps.get("BuildingCatalog")
	_clock = deps.get("DayNight")
	_residential = deps.get("Residential")
	_road_network = deps.get("RoadNetwork")
	_performance_monitor = deps.get("PerformanceMonitor")
	_simulation_transaction = deps.get("SimulationTransaction")
	_projection_registry = deps.get("ProjectionRegistry")

func _plugin_ready() -> void:
	compiled_evaluator_enabled = OS.get_environment("CITY_BUILDER_COMMUNITY_EVALUATOR") != "canonical"
	_load_authored_data()
	if _simulation_transaction:
		_simulation_transaction.register_reducer(&"community", [&"community_tick", &"migration_candidate"], _reduce_hour, _commit_hour, 2)
		_simulation_transaction.register_contributor(&"community", [&"community"], _collect_hour)
		_simulation_transaction.transaction_committed.connect(_publish_committed_hour)
	elif _clock and not _clock.hour_changed.is_connected(_on_hour):
		_clock.hour_changed.connect(_on_hour)
	if _projection_registry:
		_projection_registry.register_projection(&"community.operational", [&"community", &"occupancy"],
			func(_version, _revisions): return get_operational_snapshot())
		_projection_registry.register_diagnostic_projection(&"community.residents", [&"community", &"occupancy", &"structures", &"topology"],
			func(_version, _revisions): return get_resident_records(true))
	GameEvents.structure_placed.connect(_on_structure_placed)
	GameEvents.structure_demolished.connect(_on_structure_demolished)
	GameEvents.map_loaded.connect(_on_map_loaded)
	GameEvents.authoritative_change_committed.connect(_on_authoritative_change)
	_on_map_loaded(GameState.map)

func _collect_hour(context: Variant, sink: Variant) -> void:
	sink.submit(SimulationIntentType.create("community:%d" % context.absolute_hour, &"community",
		"residents", &"community", &"community_tick", {"hour":context.clock_hour}, 0, &"set", 2))
	var day := int(context.absolute_hour / 24)
	if int(context.clock_hour) != int(_balance.get("migration_hour", 6)) or day == int(_migration.get("last_day", -1)):
		return
	var candidate_rng := RandomNumberGenerator.new()
	candidate_rng.state = _rng.state
	for candidate_index in int(_balance.get("candidate_batch_size", 4)):
		var personal_seed := int(candidate_rng.randi())
		sink.submit(SimulationIntentType.create("community:migration:%d:%02d" % [day, candidate_index],
			&"community", "candidate:%d:%02d" % [day, candidate_index], &"community",
			&"migration_candidate", {"candidate_index":candidate_index,
				"personal_seed":personal_seed, "rng_state_after":candidate_rng.state},
			candidate_index, &"set", 2))

func _reduce_hour(intents: Array, _context: Variant) -> Dictionary:
	var tick_intents := intents.filter(func(intent): return intent.operation == &"community_tick")
	var candidate_intents := intents.filter(func(intent): return intent.operation == &"migration_candidate")
	candidate_intents.sort_custom(func(a, b): return int(a.get_payload().candidate_index) < int(b.get_payload().candidate_index))
	return {"ok":tick_intents.size() == 1, "reason_code":"invalid_payload",
		"plan":{"hour":float(tick_intents[0].get_payload().hour),
			"migration_candidates":candidate_intents.map(func(intent): return intent.get_payload())} if tick_intents.size() == 1 else {},
		"domains":[&"community", &"occupancy"]}

func _commit_hour(plan: Dictionary, _context: Variant) -> Dictionary:
	_pending_hourly_events.clear()
	_defer_hourly_publication = true
	_on_hour(float(plan.hour), plan.get("migration_candidates", []))
	_defer_hourly_publication = false
	return {"ok":true}

func _publish_committed_hour(_change_set: Variant, _ledger: Dictionary) -> void:
	for row in _pending_hourly_events:
		_emit_community_event(StringName(row.name), row.args)
	_pending_hourly_events.clear()

func _queue_or_emit_community_event(event_name: StringName, args: Array) -> void:
	if _defer_hourly_publication:
		_pending_hourly_events.append({"name":event_name, "args":args.duplicate(true)})
	else:
		_emit_community_event(event_name, args)

func _emit_community_event(event_name: StringName, args: Array) -> void:
	match event_name:
		&"population": GameEvents.community_population_changed.emit(int(args[0]), int(args[1]))
		&"qualities": GameEvents.community_qualities_changed.emit(args[0])
		&"refresh": GameEvents.community_ui_refresh_requested.emit(String(args[0]))
		&"arrival": GameEvents.community_resident_arrived.emit(int(args[0]), args[1])
		&"departure": GameEvents.community_resident_departed.emit(int(args[0]), String(args[1]))
		&"rehome": GameEvents.community_resident_rehomed.emit(int(args[0]), args[1])
		&"notification": GameEvents.community_notification.emit(String(args[0]), int(args[1]), String(args[2]))

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
	if _consume_compat_event(): return
	_clear_residents()
	_invalidate_assignments()
	_dispose_compiled_runtime()
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
			_add_resident(resident)
			_persisted_records_by_id[resident.resident_id] = record
	if map.community_schema_version < COMMUNITY_SCHEMA_VERSION:
		_migrate_legacy_map(map)
	_persist()
	_prime_runtime_index(int(_clock.current_hour()) if _clock and _clock.has_method("current_hour") else 0)
	_emit_summary()

func _migrate_legacy_map(map: DataMap) -> void:
	# Old saves had no individual population records. Seed every occupied housing
	# slot in canonical order once; fresh empty maps remain empty and use migration.
	for slot in _housing_slots():
		var resident := _new_resident(int(map.community_next_resident_id))
		map.community_next_resident_id += 1
		resident.home_anchor = CommunityConstants.coordinate(slot["anchor"])
		_add_resident(resident)
	map.community_schema_version = COMMUNITY_SCHEMA_VERSION

func _new_resident(resident_id: int, forced_cohort: String = "", explicit_seed: int = 0) -> CommunityResident:
	var personal_seed := explicit_seed if explicit_seed != 0 else int(_rng.randi())
	return _generator.generate(personal_seed, resident_id, forced_cohort)

func _on_structure_placed(_position: Vector3i, _structure_index: int, _orientation: int) -> void:
	if _consume_compat_event(): return
	_invalidate_assignments()
	_dispose_compiled_runtime()
	_prime_runtime_index(int(_clock.current_hour()) if _clock and _clock.has_method("current_hour") else 0)
	_persist()
	_emit_summary()

func _on_structure_demolished(position: Vector3i) -> void:
	if _consume_compat_event(): return
	var anchor := Vector2i(position.x, position.z)
	for resident in _residents.values():
		if resident.home_anchor == anchor:
			resident.home_anchor = null
			resident.homeless_hours = 0
			resident.activity_assignment = null
			resident.work_assignment = null
	_invalidate_assignments()
	_dispose_compiled_runtime()
	_prime_runtime_index(int(_clock.current_hour()) if _clock and _clock.has_method("current_hour") else 0)
	_persist()
	_emit_summary()

func _consume_compat_event() -> bool:
	if _compat_events_to_ignore <= 0: return false
	_compat_events_to_ignore -= 1
	return true

func _on_authoritative_change(change_set: Variant) -> void:
	if change_set.source_kind in [&"map_load", &"map_clear"]:
		_on_map_loaded(GameState.map)
		_compat_events_to_ignore = 1
		return
	if change_set.source_kind != &"building_mutation" or not (&"community" in change_set.get_domains()):
		return
	# Programme commands already mutate and reconcile inside set_programme.
	if String(change_set.source_id).begins_with("programme:"):
		return
	_compat_events_to_ignore = 2 if change_set.source_id == "replace" else 1
	var affected := {}
	for key in change_set.get_entity_keys().get("community", []): affected[String(key)] = true
	if change_set.source_id in ["demolish", "replace"]:
		for resident in _residents.values():
			if resident.home_anchor != null and affected.has(_anchor_key(resident.home_anchor)):
				resident.home_anchor = null
				resident.homeless_hours = 0
				resident.activity_assignment = null
				resident.work_assignment = null
	_invalidate_assignments()
	_dispose_compiled_runtime()
	_prime_runtime_index(int(_clock.current_hour()) if _clock and _clock.has_method("current_hour") else 0)
	_persist()
	_emit_summary()

func _on_hour(hour: float, migration_candidates: Array = []) -> void:
	var collect_started := Time.get_ticks_usec()
	var hour_i := int(hour) % 24
	var assignment_key := _assignment_fast_key(hour_i)
	var sources := _hour_sources(hour_i)
	# Identical schedule/topology/population states reuse the same cached source
	# records and participant lists. Reapplying them performs a full source and
	# resident scan without changing a single assignment.
	if assignment_key != _assignment_prepared_hour_key:
		_assign_residents(sources, hour_i)
		_assignment_prepared_hour_key = assignment_key
	else:
		_changed_assignment_resident_ids.clear()
	var revisions := _runtime_revisions(hour_i)
	var runtime: Variant = null
	if compiled_evaluator_enabled:
		runtime = _ensure_compiled_runtime(sources, revisions)
	var prepared: Array = [] if runtime != null else CommunityEffectEvaluator.prepare_effects(sources)
	if _performance_monitor:
		_performance_monitor.record(&"hour.collect", Time.get_ticks_usec() - collect_started,
			{"owner":"community", "sources":sources.size(), "residents":_residents.size()})
	var evaluate_started := Time.get_ticks_usec()
	var compact_result := CommunityEvaluationResult.new() if runtime != null else null
	for resident in _sorted_residents():
		if runtime != null:
			CompiledEvaluator.evaluate_into(resident, runtime, {"hour": hour_i}, compact_result, false)
			CommunityEffectEvaluator.update_quality_numeric(resident, compact_result.quality_totals,
				float(_balance.get("quality_baseline", 50.0)), float(_balance.get("hourly_response_rate", 0.1)))
		else:
			var totals := CommunityEffectEvaluator.evaluate_prepared_totals(resident, prepared, {"hour": hour_i})
			CommunityEffectEvaluator.update_quality_totals(resident, totals,
				float(_balance.get("quality_baseline", 50.0)), float(_balance.get("hourly_response_rate", 0.1)))
	if _performance_monitor:
		_performance_monitor.record(&"hour.validate_reduce", Time.get_ticks_usec() - evaluate_started,
			{"owner":"community", "effects":runtime.effect_ids.size() if runtime != null else prepared.size(), "residents":_residents.size()})
	var commit_started := Time.get_ticks_usec()
	_relocate_homeless()
	_evaluate_departures()
	var absolute_hour: int = int(_clock.get_absolute_hour()) if _clock and _clock.has_method("get_absolute_hour") else 0
	var day: int = int(absolute_hour / 24)
	if hour_i == int(_balance.get("migration_hour", 6)) and day != int(_migration.get("last_day", -1)):
		_migration["last_day"] = day
		_run_daily_migration(sources, runtime, migration_candidates)
	_emit_summary()
	if _performance_monitor:
		_performance_monitor.record(&"hour.commit", Time.get_ticks_usec() - commit_started,
			{"owner":"community", "residents":_residents.size()})

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
		var source := _build_source_record(structure_index, entry.get("anchor", Vector2i.ZERO), hour, int(internal_id))
		if not source.is_empty():
			result.append(source)
	return result

## One canonical source-record builder is shared by committed hourly evaluation
## and detached placement quotes. Candidate records deliberately have no
## participant allocation: that is called out as uncertain by the quote.
func _build_source_record(structure_index: int, anchor: Vector2i, hour: int,
		internal_id: int = -1) -> Dictionary:
	if structure_index < 0 or structure_index >= GameState.structures.size():
		return {}
	var structure: Structure = GameState.structures[structure_index]
	var profile := structure.find_metadata(CommunityEffectProfile) as CommunityEffectProfile
	var building_profile := structure.find_metadata(BuildingProfile) as BuildingProfile
	if profile == null and building_profile == null:
		return {}
	var active := true
	var capacity := 0
	if building_profile:
		active = _in_window(hour, int(building_profile.active_start), int(building_profile.active_end))
		capacity = building_profile.capacity
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
	var proximity := get_town_hall_proximity(internal_id) if internal_id >= 0 else {
		"reachable": false, "distance": -1, "band": "", "shop_activity_bonus": 0.0,
		"home_liveability_penalty": 0.0, "route": {},
	}
	if building_profile and building_profile.category == "residential" and proximity.get("band", "") != "":
		effects.append({
			"effect_id": "town_hall_bustle_%s" % proximity["band"],
			"quality": "liveability", "manifestation": "neutral",
			"amount": float(proximity["home_liveability_penalty"]),
			"scope": "resident", "stacking_group": "town_hall_bustle",
			"requires_active_building": false,
			"reason": "Lived within %d road tiles of the busy Town Hall" % int(proximity["distance"]),
		})
	return {
		"internal_id": internal_id,
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
	}

## Builds one immutable authored source catalogue, then projects the 24 active
## windows with shallow records. Nested effects and route evidence are read-only
## during quotes, so they do not need to be rediscovered or deep-copied.
func _source_records_for_day() -> Array:
	var base_sources := _source_records(0)
	var sources_by_hour: Array = []
	for evaluation_hour in 24:
		var hourly_sources: Array = []
		for base_source in base_sources:
			var source: Dictionary = base_source.duplicate()
			var schedule: Variant = source.get("building_schedule")
			source["active"] = _in_window(evaluation_hour, int(schedule.get("start", 0)), int(schedule.get("end", 0))) if schedule is Dictionary else true
			source["evaluation_hour"] = evaluation_hour
			source["participants"] = []
			hourly_sources.append(source)
		sources_by_hour.append(hourly_sources)
	return sources_by_hour

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
	var cache_key := _assignment_key(sources, hour)
	if not force and cache_key == _assignment_cache_key:
		_changed_assignment_resident_ids.clear()
		_apply_cached_participants(sources)
		return
	var previous_assignments := {}
	for resident in _sorted_residents():
		previous_assignments[resident.resident_id] = _resident_assignment_signature(resident)
	_assignment_revision += 1
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
	_changed_assignment_resident_ids.clear()
	for resident in _sorted_residents():
		if previous_assignments.get(resident.resident_id, "") != _resident_assignment_signature(resident):
			_changed_assignment_resident_ids.append(resident.resident_id)

func _resident_assignment_signature(resident: CommunityResident) -> String:
	var assignment: Variant = resident.work_assignment if resident.work_assignment != null else resident.activity_assignment
	if assignment == null: return "home:%s" % _anchor_key(resident.home_anchor)
	return "%s:%d:%s" % [String(assignment.get("purpose", "")), int(assignment.get("internal_id", -1)),
		JSON.stringify(assignment.get("source_effect_ids", []))]

func _rank_reachable_sources(resident: CommunityResident, sources: Array, remaining: Dictionary, use_benefit: bool, hour: int) -> Array:
	var best: Dictionary = {}
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
		var candidate := {"source":source, "benefit":benefit, "distance":int(route.get("distance", 0)), "route":route}
		if best.is_empty() or _assignment_candidate_before(candidate, best, use_benefit): best = candidate
	return [] if best.is_empty() else [best]

func _assignment_candidate_before(a: Dictionary, b: Dictionary, use_benefit: bool) -> bool:
	if use_benefit and a["benefit"] != b["benefit"]: return a["benefit"] > b["benefit"]
	if a["distance"] != b["distance"]: return a["distance"] < b["distance"]
	var aa: Vector2i = a["source"]["anchor"]
	var bb: Vector2i = b["source"]["anchor"]
	if aa.x != bb.x: return aa.x < bb.x
	if aa.y != bb.y: return aa.y < bb.y
	if a["source"]["building_id"] != b["source"]["building_id"]: return a["source"]["building_id"] < b["source"]["building_id"]
	return int(a["source"]["internal_id"]) < int(b["source"]["internal_id"])

func _route_to_source(resident: CommunityResident, destination_id: int) -> Dictionary:
	if resident.home_anchor == null:
		return {"reachable": false, "distance": -1, "reason": "no_road_access"}
	if _road_network == null or not _road_network.has_method("get_route_between_buildings"):
		var destination_anchor: Vector2i = GameState.building_registry.get(destination_id, {}).get("anchor", resident.home_anchor)
		return {"reachable": true, "distance": CommunityConstants.manhattan(resident.home_anchor, destination_anchor), "reason": ""}
	var home_id := _building_id_at_anchor(CommunityConstants.coordinate(resident.home_anchor))
	if home_id < 0:
		return {"reachable": false, "distance": -1, "reason": "no_road_access"}
	var road_revision := int(_road_network.get_revision()) if _road_network.has_method("get_revision") else 0
	var cache_key := "%d>%d@%d" % [home_id, destination_id, road_revision]
	if _assignment_route_cache.has(cache_key): return _assignment_route_cache[cache_key]
	var result: Dictionary
	if _road_network.has_method("get_route_summary_between_buildings"):
		result = _road_network.get_route_summary_between_buildings(home_id, destination_id)
	else:
		result = _road_network.get_route_between_buildings(home_id, destination_id)
	_assignment_route_cache[cache_key] = result
	return result

func _building_id_at_anchor(anchor: Vector2i) -> int:
	if _road_network and _road_network.has_method("get_internal_id_for_anchor"):
		return int(_road_network.get_internal_id_for_anchor(anchor))
	var ids := GameState.building_registry.keys()
	ids.sort()
	for internal_id in ids:
		if CommunityConstants.coordinate(GameState.building_registry[internal_id].get("anchor")) == anchor:
			return int(internal_id)
	return -1

func _assignment_record(resident: CommunityResident, source: Dictionary, purpose: String, ranked: Dictionary, hour: int) -> Dictionary:
	var route: Dictionary = ranked.get("route", {})
	var components: Array = route.get("shared_component_ids", [])
	var source_effect_ids: Array = []
	if purpose == "activity":
		for effect in source.get("effects", []):
			if effect.get("scope") == "participant" and CommunityEffectEvaluator.schedule_active(effect.get("schedule"), hour):
				source_effect_ids.append(String(effect.get("effect_id", "")))
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
		"source_effect_ids": source_effect_ids,
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
	_assignment_revision += 1
	_assignment_cache_key = ""
	_assignment_prepared_hour_key = ""
	_hour_source_cache_key = ""
	_hour_source_cache.clear()
	_work_counts.clear()
	_activity_counts.clear()
	_assignment_records.clear()
	_changed_assignment_resident_ids.clear()
	_assignment_route_cache.clear()
	_assignment_schedule_states.clear()

func _ensure_assignments(hour: int) -> void:
	var fast_key := _assignment_fast_key(hour)
	if fast_key == _assignment_prepared_hour_key: return
	var sources := _hour_sources(hour)
	_assign_residents(sources, hour)
	_assignment_prepared_hour_key = fast_key

func _hour_sources(hour: int) -> Array:
	var key := _assignment_fast_key(hour)
	if key != _hour_source_cache_key:
		_hour_source_cache = _source_records(hour)
		_hour_source_cache_key = key
	return _hour_source_cache

func _assignment_fast_key(hour: int) -> String:
	var revision := int(_road_network.get_revision()) if _road_network and _road_network.has_method("get_revision") else 0
	return "%s|%d|%d|%d" % [_assignment_schedule_state(hour), revision, _residents.size(), GameState.building_registry.size()]

func _assignment_schedule_state(hour: int) -> String:
	hour = hour % 24
	if _assignment_schedule_states.has(hour): return String(_assignment_schedule_states[hour])
	var active: Array[String] = []
	var ids := GameState.building_registry.keys(); ids.sort()
	for internal_id in ids:
		var structure_index := int(GameState.building_registry[internal_id].get("structure", -1))
		if structure_index < 0 or structure_index >= GameState.structures.size(): continue
		var structure: Structure = GameState.structures[structure_index]
		var building_profile := structure.find_metadata(BuildingProfile) as BuildingProfile
		if building_profile and _in_window(hour, int(building_profile.active_start), int(building_profile.active_end)):
			active.append("b%d" % int(internal_id))
		var effect_profile := structure.find_metadata(CommunityEffectProfile) as CommunityEffectProfile
		if effect_profile == null: continue
		var programme := String(GameState.map.community_programmes.get(_anchor_key(GameState.building_registry[internal_id].get("anchor")), effect_profile.default_programme)) if GameState.map else effect_profile.default_programme
		for effect in effect_profile.effects_for(programme):
			if effect.get("scope") == "participant" and CommunityEffectEvaluator.schedule_active(effect.get("schedule"), hour):
				active.append("e%d:%s" % [int(internal_id), String(effect.get("effect_id", ""))])
	var result := ",".join(active)
	_assignment_schedule_states[hour] = result
	return result

func _assignment_key(sources: Array, hour: int) -> String:
	var revision := int(_road_network.get_revision()) if _road_network and _road_network.has_method("get_revision") else 0
	var active_signature: Array[String] = []
	for source in sources:
		if bool(source.get("active", true)): active_signature.append("b%d" % int(source.get("internal_id", -1)))
		for effect in source.get("effects", []):
			if effect.get("scope") == "participant" and CommunityEffectEvaluator.schedule_active(effect.get("schedule"), hour):
				active_signature.append("e%d:%s" % [int(source.get("internal_id", -1)), String(effect.get("effect_id", ""))])
	return "%d|%d|%d|%s" % [revision, _residents.size(), GameState.building_registry.size(), ",".join(active_signature)]

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

func get_assignment_revision() -> int:
	return _assignment_revision

func get_changed_civilian_ids() -> Array[int]:
	return _changed_assignment_resident_ids.duplicate()

func get_civilian_intent(resident_id: int) -> Dictionary:
	var resident: CommunityResident = _residents.get(resident_id)
	return {} if resident == null else _civilian_intent_for(resident)

func get_civilian_intents(include_unhoused: bool = true) -> Array:
	var result: Array = []
	for resident: CommunityResident in _sorted_residents():
		if resident.home_anchor == null and not include_unhoused:
			continue
		result.append(_civilian_intent_for(resident))
	return result.duplicate(true)

func _civilian_intent_for(resident: CommunityResident) -> Dictionary:
	var absolute_hour := int(_clock.get_absolute_hour()) if _clock and _clock.has_method("get_absolute_hour") else 0
	var assignment: Variant = resident.work_assignment
	if assignment == null:
		assignment = resident.activity_assignment
	var purpose := "unhoused" if resident.home_anchor == null else "home"
	var destination: Variant = resident.home_anchor
	var building_id := ""
	var source_effect_ids: Array = []
	var active := false
	var valid_until: Variant = null
	var route_distance := 0
	if assignment != null:
		purpose = String(assignment.get("purpose", "activity"))
		destination = CommunityConstants.coordinate(assignment.get("anchor"))
		building_id = String(assignment.get("building_id", ""))
		if purpose == "activity": source_effect_ids = assignment.get("source_effect_ids", []).duplicate()
		active = true
		valid_until = absolute_hour + 1
		route_distance = int(assignment.get("route_distance", 0))
	return {
		"resident_id": resident.resident_id,
		"resident_seed": resident.seed,
		"home_anchor": null if resident.home_anchor == null else CommunityConstants.coordinate_record(resident.home_anchor),
		"assignment_revision": _assignment_revision,
		"absolute_hour": absolute_hour,
		"purpose": purpose,
		"destination_anchor": null if destination == null else CommunityConstants.coordinate_record(destination),
		"destination_building_id": building_id,
		"source_effect_ids": source_effect_ids,
		"active": active,
		"valid_until_hour": valid_until,
		"reachable": destination != null,
		"blocked_reason": "resident_unhoused" if destination == null else "",
		"route_distance": route_distance,
	}

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

func _run_daily_migration(hour_sources: Array = [], hour_runtime: Variant = null,
		candidate_records: Array = []) -> void:
	var batch := int(_balance.get("candidate_batch_size", 4))
	# Every candidate in one dawn batch observes the same authored day and road
	# topology. Construct it once rather than repeating 24 source scans per quote.
	var context_started := Time.get_ticks_usec()
	var quote_context := _migration_quote_context(hour_sources, hour_runtime)
	if _performance_monitor:
		_performance_monitor.record(&"migration.context", Time.get_ticks_usec() - context_started,
			{"buildings":GameState.building_registry.size(), "residents":_residents.size()})
	for _index in batch:
		var candidate_started := Time.get_ticks_usec()
		var next_id := GameState.map.community_next_resident_id if GameState.map else _next_id()
		var candidate: CommunityResident
		if _index < candidate_records.size():
			candidate = _generator.generate(int(candidate_records[_index].personal_seed), next_id)
		else:
			candidate = _new_resident(next_id)
		var quote := quote_migration(candidate, quote_context)
		if quote.get("ok", false):
			candidate.home_anchor = CommunityConstants.coordinate(quote["home_anchor"])
			candidate.target_qualities = quote["target_qualities"].duplicate(true)
			candidate.current_qualities = quote["target_qualities"].duplicate(true)
			candidate.composite_happiness = float(quote["predicted_happiness"])
			_add_resident(candidate)
			if GameState.map: GameState.map.community_next_resident_id += 1
			_migration["arrivals"] = int(_migration.get("arrivals", 0)) + 1
			_queue_or_emit_community_event(&"arrival", [candidate.resident_id, candidate.home_anchor])
			_latest_event = "Resident #%d arrived" % candidate.resident_id
			_queue_or_emit_community_event(&"notification", ["arrival", candidate.resident_id, _latest_event])
			_consume_migration_home(quote_context.get("available_homes", []), quote)
		else:
			_migration["rejections"] = int(_migration.get("rejections", 0)) + 1
			var reason := String(quote.get("reason", "below_threshold"))
			_latest_event = "Arrival rejected: no free housing" if reason == "no_capacity" else "Arrival rejected: town fit below threshold"
			_queue_or_emit_community_event(&"notification", ["capacity" if reason == "no_capacity" else "rejection", 0, _latest_event])
		if _performance_monitor:
			_performance_monitor.record(&"migration.candidates", Time.get_ticks_usec() - candidate_started,
				{"candidate":_index, "homes":quote_context.get("available_homes", []).size(), "residents":_residents.size()})
	if not candidate_records.is_empty():
		_rng.state = int(candidate_records[-1].rng_state_after)

func _consume_migration_home(available_homes: Array, quote: Dictionary) -> void:
	var chosen_anchor: Variant = CommunityConstants.coordinate(quote.get("home_anchor"))
	var chosen_slot := int(quote.get("slot", 0))
	for index in available_homes.size():
		var home: Dictionary = available_homes[index]
		if CommunityConstants.coordinate(home.get("anchor")) == chosen_anchor and int(home.get("slot", 0)) == chosen_slot:
			available_homes.remove_at(index)
			return

func _migration_quote_context(reusable_sources: Array = [], reusable_runtime: Variant = null) -> Dictionary:
	var initial_homes := _free_housing_slots()
	if initial_homes.is_empty():
		return {"available_homes": initial_homes}
	for home in initial_homes:
		home["_migration_home_key"] = _anchor_key(home.get("anchor"))
	var revisions := _runtime_revisions(0)
	var revision_key := JSON.stringify({
		"topology":revisions.get("topology", 0), "structures":revisions.get("structures", 0),
		"programmes":revisions.get("programmes", 0), "schedules":revisions.get("schedules", 0),
		"balance":revisions.get("balance", 0),
	}).sha256_text()
	if revision_key == _migration_fact_cache_key and not _migration_fact_cache.is_empty():
		_migration_fact_cache_hits += 1
		var cached := _migration_fact_cache.duplicate()
		cached["available_homes"] = initial_homes
		return cached
	_migration_fact_cache_misses += 1
	# Building/effect schedules are encoded in the compiled runtime, so the
	# operational batch needs one authored catalogue rather than 24 deep source
	# projections. Rich one-off quotes keep the canonical day projection below.
	var base_sources := reusable_sources if not reusable_sources.is_empty() else _source_records(0)
	var reachable_source_ids_by_home := {}
	var represented_anchors := {}
	var component_ids_by_source := {}
	var active_runtime: Variant = reusable_runtime if reusable_runtime != null else CompiledRuntime.build(base_sources, _runtime_revisions(0))
	var candidate_effects_by_home := {}
	var participant_source_indexes_by_home := {}
	if _road_network and _road_network.has_method("get_access_for_building"):
		for source in base_sources:
			var source_id := int(source.get("internal_id", -1))
			component_ids_by_source[source_id] = _road_network.get_access_for_building(source_id).get("component_ids", [])
	for home in initial_homes:
		var home_key := String(home["_migration_home_key"]) if home.has("_migration_home_key") else _anchor_key(home.get("anchor"))
		if represented_anchors.has(home_key):
			continue
		represented_anchors[home_key] = true
		var reachable := {}
		if _road_network and _road_network.has_method("get_internal_id_for_anchor"):
			var home_id := int(_road_network.get_internal_id_for_anchor(CommunityConstants.coordinate(home.get("anchor"))))
			var home_components: Array = _road_network.get_access_for_building(home_id).get("component_ids", [])
			var home_component_lookup := {}
			for component_id in home_components: home_component_lookup[String(component_id)] = true
			for source_id in component_ids_by_source:
				for component_id in component_ids_by_source[source_id]:
					if home_component_lookup.has(String(component_id)):
						reachable[int(source_id)] = true
						break
		else:
			var probe := CommunityResident.new()
			probe.home_anchor = CommunityConstants.coordinate(home.get("anchor"))
			for source in base_sources:
				var source_id := int(source.get("internal_id", -1))
				if bool(_route_to_source(probe, source_id).get("reachable", false)):
					reachable[source_id] = true
		reachable_source_ids_by_home[home_key] = reachable
		candidate_effects_by_home[home_key] = active_runtime.candidate_effects_for_home(home.get("anchor"))
		var participant_source_indexes: Array = []
		for source_index in base_sources.size():
			var source: Dictionary = base_sources[source_index]
			var source_id := int(source.get("internal_id", -1))
			if not reachable.has(source_id): continue
			if source.get("effects", []).any(func(effect): return String(effect.get("scope", "")) == "participant"):
				participant_source_indexes.append(source_index)
		participant_source_indexes_by_home[home_key] = participant_source_indexes
	var facts := {
		"base_sources": base_sources,
		"compiled_runtime": active_runtime,
		"reachable_source_ids_by_home": reachable_source_ids_by_home,
		"candidate_effects_by_home": candidate_effects_by_home,
		"participant_source_indexes_by_home": participant_source_indexes_by_home,
		"evaluation_sets": {},
		# The migration mutation consumes only the score and target qualities.
		# Direct quote callers still receive the authored effect explanation.
		"include_effects": false,
	}
	_migration_fact_cache_key = revision_key
	_migration_fact_cache = facts
	var result := facts.duplicate()
	result["available_homes"] = initial_homes
	return result

func get_migration_fact_cache_stats() -> Dictionary:
	return {"key":_migration_fact_cache_key, "hits":_migration_fact_cache_hits,
		"misses":_migration_fact_cache_misses, "cached":not _migration_fact_cache.is_empty()}

func quote_migration(candidate: CommunityResident, shared_context: Dictionary = {}) -> Dictionary:
	var homes: Array = shared_context["available_homes"] if shared_context.has("available_homes") else _free_housing_slots()
	if homes.is_empty():
		return {"ok": false, "reason": "no_capacity"}
	# Every free slot at one anchor receives identical authored effects. Quote the
	# first free slot once per building rather than repeating the full 24-hour
	# evaluation for every unit of capacity.
	var representative_homes: Array = []
	var represented_anchors := {}
	for home in homes:
		var key := String(home["_migration_home_key"]) if home.has("_migration_home_key") else _anchor_key(home.get("anchor"))
		if represented_anchors.has(key):
			continue
		represented_anchors[key] = true
		representative_homes.append(home)
	# Source discovery is independent of a candidate's proposed home. Reuse one
	# authored day and restore the temporary participant marker after each hour.
	var sources_by_hour: Array = shared_context.get("sources_by_hour", [])
	var effects_by_hour: Array = shared_context.get("effects_by_hour", [])
	var base_sources: Array = shared_context.get("base_sources", [])
	var migration_runtime: Variant = shared_context.get("compiled_runtime")
	var include_effects := bool(shared_context.get("include_effects", true))
	var compact_result := CommunityEvaluationResult.new() if not include_effects and migration_runtime != null else null
	var resident_multipliers := CompiledEvaluator.compile_resident_multipliers(candidate, migration_runtime) if compact_result != null else PackedFloat64Array()
	var candidate_effects_by_home: Dictionary = shared_context.get("candidate_effects_by_home", {})
	var evaluation_sets: Dictionary = shared_context.get("evaluation_sets", {})
	var participant_source_indexes_by_home: Dictionary = shared_context.get("participant_source_indexes_by_home", {})
	if sources_by_hour.is_empty() and base_sources.is_empty():
		sources_by_hour = _source_records_for_day()
	if not include_effects and effects_by_hour.is_empty():
		for sources in sources_by_hour:
			effects_by_hour.append(CommunityEffectEvaluator.prepare_effects(sources))
	# Participant preference does not depend on the proposed home. Compute each
	# candidate/source/hour benefit once, then apply each home's reachability mask.
	var participant_benefits_by_hour: Array = []
	if migration_runtime != null:
		participant_benefits_by_hour = migration_runtime.participant_benefits_by_hour(candidate)
	else:
		for evaluation_hour in 24:
			var benefits := {}
			var benefit_sources: Array = base_sources if not base_sources.is_empty() else sources_by_hour[evaluation_hour]
			for source in benefit_sources:
				benefits[int(source.get("internal_id", -1))] = _participant_benefit(candidate, source, evaluation_hour)
			participant_benefits_by_hour.append(benefits)
	var best_result: Dictionary = {}
	for home in representative_homes:
		var home_key := String(home["_migration_home_key"]) if home.has("_migration_home_key") else _anchor_key(home.get("anchor"))
		var previous_home: Variant = candidate.home_anchor
		candidate.home_anchor = CommunityConstants.coordinate(home["anchor"])
		var daily_totals := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
		var predicted_effects: Array = []
		var reachable_source_ids: Variant = shared_context.get("reachable_source_ids_by_home", {}).get(home_key)
		# A migration quote considers one representative authored day so scheduled
		# work/night opportunities and their nuisances remain visible at dawn.
		for evaluation_hour in 24:
			# Evaluators only read source records. Temporarily mark the selected shared
			# source and restore it immediately, avoiding per-candidate array/dictionary
			# allocations across the full 24-hour quote.
			var sources: Array = base_sources if not base_sources.is_empty() else sources_by_hour[evaluation_hour]
			var best_source_index := -1
			var best_benefit := 0.0
			var selectable_indexes: Array
			if migration_runtime != null:
				selectable_indexes = participant_source_indexes_by_home.get(home_key, [])
			else:
				selectable_indexes = range(sources.size())
			for source_index in selectable_indexes:
				var source: Dictionary = sources[source_index]
				var source_id := int(source.get("internal_id", -1))
				var reachable := bool(reachable_source_ids.has(source_id)) if reachable_source_ids is Dictionary else bool(_route_to_source(candidate, source_id).get("reachable", false))
				if not reachable:
					continue
				var benefit := float(participant_benefits_by_hour[evaluation_hour].get(source_id, 0.0))
				if benefit > best_benefit:
					best_benefit = benefit
					best_source_index = source_index
			if best_source_index >= 0 and migration_runtime == null:
				var selected_source: Dictionary = sources[best_source_index]
				selected_source["participants"] = [candidate.resident_id]
			var evaluation := CommunityEffectEvaluator.evaluate(candidate, sources, {"hour": evaluation_hour}) if include_effects else {}
			var evaluation_totals: Dictionary = {}
			if include_effects:
				evaluation_totals = evaluation.get("totals", {})
			elif migration_runtime != null:
				var participant_effects: Array = migration_runtime.participant_effects_for_source(sources[best_source_index]) if best_source_index >= 0 else []
				var evaluation_set_key := "%s|%d" % [home_key, int(sources[best_source_index].get("internal_id", -1)) if best_source_index >= 0 else -1]
				if not evaluation_sets.has(evaluation_set_key):
					var override_lookup := {}
					for effect_index in participant_effects: override_lookup[int(effect_index)] = true
					var merged_effects: Array = migration_runtime.merge_effect_handles(candidate_effects_by_home.get(home_key, []), participant_effects)
					var rows_by_hour: Array = []
					for indexed_hour in 24:
						rows_by_hour.append(CompiledEvaluator.compile_indexed_rows(migration_runtime,
							indexed_hour, merged_effects, override_lookup))
					evaluation_sets[evaluation_set_key] = {
						"candidate_effects":merged_effects,
						"participant_override_lookup":override_lookup,
						"rows_by_hour":rows_by_hour,
					}
				var evaluation_set: Dictionary = evaluation_sets[evaluation_set_key]
				CompiledEvaluator.evaluate_rows_with_multipliers_into(migration_runtime,
					evaluation_set.rows_by_hour[evaluation_hour], resident_multipliers, compact_result)
			else:
				evaluation_totals = CommunityEffectEvaluator.evaluate_prepared_totals(candidate, effects_by_hour[evaluation_hour], {"hour": evaluation_hour})
			if best_source_index >= 0 and migration_runtime == null:
				sources[best_source_index]["participants"] = []
			for quality_index in CommunityConstants.QUALITIES.size():
				# Preserve the canonical evaluator adapter's per-hour rounding point;
				# moving it after the daily average changes migration tie outcomes.
				var amount := CommunityConstants.rounded(float(compact_result.quality_totals[quality_index])) if compact_result != null else float(evaluation_totals.get(CommunityConstants.QUALITIES[quality_index], 0.0))
				daily_totals[quality_index] += amount / 24.0
			if include_effects:
				for effect in evaluation["effects"]:
					var timed_effect: Dictionary = effect.duplicate(true)
					timed_effect["active_hour"] = evaluation_hour
					predicted_effects.append(timed_effect)
		var targets := {}
		var composite := 0.0
		for quality_index in CommunityConstants.QUALITIES.size():
			var quality: String = CommunityConstants.QUALITIES[quality_index]
			var target := clampf(float(_balance.get("quality_baseline", 50.0)) + float(daily_totals[quality_index]), 0.0, 100.0)
			targets[quality] = target
			composite += target * float(candidate.quality_importance[quality])
		if include_effects:
			predicted_effects.sort_custom(func(a: Dictionary, b: Dictionary): return absf(float(a.get("applied_amount", 0.0))) > absf(float(b.get("applied_amount", 0.0))))
		var replace_best := best_result.is_empty() or composite > float(best_result.get("predicted_happiness", 0.0))
		if not replace_best and not best_result.is_empty() and composite == float(best_result.get("predicted_happiness", 0.0)):
			var candidate_anchor: Vector2i = CommunityConstants.coordinate(home["anchor"])
			var best_anchor: Vector2i = CommunityConstants.coordinate(best_result["home_anchor"])
			replace_best = candidate_anchor.x < best_anchor.x or (candidate_anchor.x == best_anchor.x and \
				(candidate_anchor.y < best_anchor.y or (candidate_anchor.y == best_anchor.y and int(home.get("slot", 0)) < int(best_result.get("slot", 0)))))
		if replace_best:
			best_result = {"home_anchor": home["anchor"], "slot": home.get("slot", 0),
				"predicted_happiness": composite, "target_qualities": targets,
				"effects": predicted_effects.slice(0, int(_balance.get("effect_snapshot_limit", 12)))}
		candidate.home_anchor = previous_home
	var best: Dictionary = best_result
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
			_queue_or_emit_community_event(&"rehome", [resident.resident_id, resident.home_anchor])
			_latest_event = "Resident #%d rehomed" % resident.resident_id
			_queue_or_emit_community_event(&"notification", ["rehome", resident.resident_id, _latest_event])
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
		_remove_resident(resident_id)
		_migration["departures"] = int(_migration.get("departures", 0)) + 1
		_queue_or_emit_community_event(&"departure", [resident_id, String(departure["reason"])])
		_latest_event = "Resident #%d departed: %s" % [resident_id, String(departure["reason"]).replace("_", " ")]
		_queue_or_emit_community_event(&"notification", ["departure", resident_id, _latest_event])

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
			var pre_version := GameState.get_state_version()
			GameState.map.community_programmes[_anchor_key(anchor)] = programme_id
			_invalidate_assignments()
			_dispose_compiled_runtime()
			var current_hour := int(_clock.current_hour()) if _clock else 0
			_assign_residents(_source_records(current_hour), current_hour, true)
			_persist()
			var post_version := GameState.commit_state_version(pre_version)
			if post_version >= 0:
				var change_set = AuthoritativeChangeSetType.create(
					"community:programme:v%d" % post_version, &"building_mutation",
					"programme:%s" % _anchor_key(anchor), pre_version, post_version,
					[&"community", &"progression", &"presentation_config"],
					{"community":[_anchor_key(anchor)]}, {"programme_id":programme_id},
					{"programmes":JSON.stringify(GameState.map.community_programmes).hash()})
				GameEvents.authoritative_change_committed.emit(change_set)
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
	var hour := int(_clock.current_hour()) if _clock and _clock.has_method("current_hour") else 0
	var bounded_residents: Array = _sorted_residents().slice(0, limit)
	var explanations := _project_explanations(bounded_residents, effect_limit, hour) if include_effects else {}
	for resident in bounded_residents:
		var record: Dictionary = resident.to_dict(false, effect_limit)
		if include_effects:
			record["applied_effects"] = explanations.get(resident.resident_id, []).duplicate(true)
		records.append(record)
	return records

## Bounded aggregate for routine presenters. This deliberately excludes
## residents, AppliedEffects, spatial exposure rows and authored source records.
func get_operational_snapshot() -> Dictionary:
	return {
		"population": get_population(), "capacity": get_capacity(),
		"average_qualities": _average_qualities(),
		"average_composite_happiness": CommunityConstants.rounded(get_average_composite()),
		"migration": _migration.duplicate(true), "latest_event": _latest_event,
	}

## Explicit diagnostic boundary. The returned records are detached and capped.
func get_resident_explanation(resident_id: int, limit: int = 12, hour: int = -1) -> Array:
	var resident: CommunityResident = _residents.get(resident_id)
	if resident == null: return []
	var active_hour := hour if hour >= 0 else (int(_clock.current_hour()) if _clock and _clock.has_method("current_hour") else 0)
	return _project_explanations([resident], limit, active_hour).get(resident_id, []).duplicate(true)

func _project_explanations(residents: Array, limit: int, active_hour: int) -> Dictionary:
	var resident_ids: Array = residents.map(func(resident): return int(resident.resident_id))
	resident_ids.sort()
	var cache_key := "%d|%d|%d|%s" % [active_hour, _assignment_revision, limit, str(resident_ids)]
	if cache_key == _explanation_cache_key:
		return _explanation_cache.duplicate(true)
	var sources := _source_records(active_hour)
	_assign_residents(sources, active_hour)
	var runtime = CompiledRuntime.build(sources, _runtime_revisions(active_hour))
	var result := {}
	for resident in residents:
		result[resident.resident_id] = CompiledEvaluator.project_explanation(resident, runtime, {"hour":active_hour}, limit)
	_explanation_cache_key = cache_key
	_explanation_cache = result.duplicate(true)
	return result.duplicate(true)

func get_snapshot(compact: bool = false) -> Dictionary:
	var snapshot := {
		"population": get_population(),
		"capacity": get_capacity(),
		"average_qualities": _average_qualities(),
		"average_composite_happiness": CommunityConstants.rounded(get_average_composite()),
		"personality_distribution": _personality_distribution(),
		"migration": _migration.duplicate(true),
		"assignments": get_assignment_records(),
		"latest_event": _latest_event,
	}
	if not compact:
		snapshot["effect_summary"] = _effect_summary()
		snapshot["spatial"] = get_spatial_snapshot()
		snapshot["residents"] = get_resident_records(true)
	return snapshot

func get_spatial_snapshot() -> Dictionary:
	var exposures: Array = []
	var coverage_by_key := {}
	var residents := _sorted_residents()
	var explanations := _project_explanations(residents, int(_balance.get("effect_snapshot_limit", 12)), int(_clock.current_hour()) if _clock and _clock.has_method("current_hour") else 0)
	for resident in residents:
		for effect_raw in explanations.get(resident.resident_id, []):
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

## Detached before/after quote. It uses CommunityEffectEvaluator directly, the
## same filtering, order, stacking, preference and sensitivity authority used by
## the committed hourly simulation. It never calls update_qualities().
func quote_placement_consequences(structure_index: int, anchor: Vector2i,
		removed_internal_ids: Array = [], _rotation: int = 0) -> Dictionary:
	var empty_totals := {}
	for quality in CommunityConstants.QUALITIES:
		empty_totals[quality] = 0.0
	if structure_index < 0 or structure_index >= GameState.structures.size():
		return {"quality_deltas": empty_totals, "affected_resident_count": 0,
			"affected_home_count": 0, "affected_residents": [], "effect_radii": [],
			"certainty": "uncertain", "uncertainties": ["unknown_structure"]}
	var hour := int(_clock.current_hour()) if _clock else 0
	# Placement preview reads the same immutable authored catalogue as the live
	# hour. Building/programme/topology commits explicitly invalidate this cache,
	# so repeated cursor quotes do not rebuild all 135 source dictionaries.
	var before_sources := _hour_sources(hour)
	var removed_lookup := {}
	var removed_home_anchors := {}
	for raw_id in removed_internal_ids:
		var internal_id := int(raw_id)
		removed_lookup[internal_id] = true
		var removed: Dictionary = GameState.building_registry.get(internal_id, {})
		var removed_sid := int(removed.get("structure", -1))
		if removed_sid >= 0 and removed_sid < GameState.structures.size():
			var removed_profile := GameState.structures[removed_sid].find_metadata(BuildingProfile) as BuildingProfile
			if removed_profile and removed_profile.category == "residential":
				removed_home_anchors[removed.get("anchor", Vector2i.ZERO)] = true
	var after_sources: Array = []
	var impact_sources: Array = []
	for source in before_sources:
		if removed_lookup.has(int(source.get("internal_id", -1))):
			impact_sources.append(source)
		else:
			after_sources.append(source)
	var candidate := _build_source_record(structure_index, anchor, hour, GameState._next_building_id)
	if not candidate.is_empty():
		after_sources.append(candidate)
		impact_sources.append(candidate)

	var totals := empty_totals.duplicate(true)
	var affected: Array = []
	var affected_homes := {}
	var before_prepared := CommunityEffectEvaluator.prepare_effects(before_sources)
	var after_prepared := CommunityEffectEvaluator.prepare_effects(after_sources)
	for resident in _sorted_residents():
		var after_resident: CommunityResident = resident
		var home_removed := resident.home_anchor != null and removed_home_anchors.has(resident.home_anchor)
		var potentially_affected := home_removed
		if not potentially_affected:
			for source in impact_sources:
				for effect in source.get("effects", []):
					if CommunityEffectEvaluator.applies(effect, resident, source, {"hour": hour}):
						potentially_affected = true
						break
				if potentially_affected:
					break
		if not potentially_affected:
			continue
		if home_removed:
			after_resident = CommunityResident.from_dict(resident.to_dict(false))
			after_resident.home_anchor = null
		var before_totals: Dictionary = CommunityEffectEvaluator.evaluate_prepared_totals(resident, before_prepared, {"hour": hour})
		var after_totals: Dictionary = CommunityEffectEvaluator.evaluate_prepared_totals(after_resident, after_prepared, {"hour": hour})
		var resident_deltas := {}
		var changed := home_removed
		for quality in CommunityConstants.QUALITIES:
			var delta := CommunityConstants.rounded(float(after_totals.get(quality, 0.0)) - float(before_totals.get(quality, 0.0)))
			resident_deltas[quality] = delta
			totals[quality] = float(totals[quality]) + delta
			changed = changed or not is_zero_approx(delta)
		if not changed:
			continue
		var home_record: Variant = CommunityConstants.coordinate_record(resident.home_anchor)
		if home_record != null:
			affected_homes[_anchor_key(home_record)] = home_record
		affected.append({
			"resident_id": resident.resident_id,
			"home_anchor": home_record,
			"home_removed": home_removed,
			"quality_deltas": resident_deltas,
		})
	for quality in CommunityConstants.QUALITIES:
		totals[quality] = CommunityConstants.rounded(float(totals[quality]))
	var effect_radii: Array[int] = []
	var uncertainties: Array[String] = []
	for effect in candidate.get("effects", []):
		if String(effect.get("scope", "")) == "local" and effect.get("radius") != null:
			var radius := int(effect["radius"])
			if radius not in effect_radii:
				effect_radii.append(radius)
		if String(effect.get("scope", "")) == "participant" and "participant_allocation_after_commit" not in uncertainties:
			uncertainties.append("participant_allocation_after_commit")
	if String(candidate.get("category", "")) in ["industrial", "commercial"]:
		uncertainties.append("reachable_assignment_after_commit")
	effect_radii.sort()
	affected.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["resident_id"]) < int(b["resident_id"]))
	return {
		"quality_deltas": totals,
		"affected_resident_count": affected.size(),
		"affected_home_count": affected_homes.size(),
		"affected_residents": affected.slice(0, 12),
		"effect_radii": effect_radii,
		"evaluation_hour": hour,
		"certainty": "exact" if uncertainties.is_empty() else "mixed",
		"uncertainties": uncertainties,
	}

## Compatibility alias for older callers. New code uses the explicit quote API.
func get_placement_preview(structure_index: int, anchor: Vector2i, rotation: int = 0) -> Dictionary:
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
			var existing_effects: Array = resident.applied_effects if not resident.applied_effects.is_empty() else get_resident_explanation(resident.resident_id, int(_balance.get("effect_snapshot_limit", 12)))
			for applied in existing_effects:
				if float(applied.get("applied_amount", 0.0)) > 0.0 and String(applied.get("stacking_group", "")) == String(effect.get("stacking_group", "")):
					already_covered = true
					break
			if already_covered:
				if resident.resident_id not in overlapping: overlapping.append(resident.resident_id)
			elif resident.resident_id not in newly_served:
				newly_served.append(resident.resident_id)
	categories.sort_custom(func(a: Dictionary, b: Dictionary): return String(a["effect_id"]) < String(b["effect_id"]))
	homes_in_range.sort(); newly_served.sort(); overlapping.sort()
	return {"anchor": CommunityConstants.coordinate_record(anchor), "rotation": rotation,
		"categories": categories, "max_radius": max_radius, "homes_in_range": homes_in_range,
		"newly_served_homes": newly_served, "overlapping_coverage_homes": overlapping}

func get_effect_totals_snapshot() -> Dictionary:
	var hour := int(_clock.current_hour()) if _clock else 0
	var sources := _source_records(hour)
	var totals := {}
	for quality in CommunityConstants.QUALITIES:
		totals[quality] = 0.0
	for resident in _sorted_residents():
		var evaluation := CommunityEffectEvaluator.evaluate(resident, sources, {"hour": hour})
		for quality in CommunityConstants.QUALITIES:
			totals[quality] = float(totals[quality]) + float(evaluation["totals"].get(quality, 0.0))
	for quality in CommunityConstants.QUALITIES:
		totals[quality] = CommunityConstants.rounded(float(totals[quality]))
	return totals

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
	var residents := _sorted_residents()
	var explanations := _project_explanations(residents, int(_balance.get("effect_snapshot_limit", 12)), int(_clock.current_hour()) if _clock and _clock.has_method("current_hour") else 0)
	for resident in residents:
		for effect in explanations.get(resident.resident_id, []):
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

func _runtime_revisions(hour: int) -> Dictionary:
	if _static_runtime_revisions.is_empty():
		_static_runtime_revisions = {
			"topology": int(_road_network.get_revision()) if _road_network and _road_network.has_method("get_revision") else 0,
			"structures": GameState.building_registry.size(),
			"programmes": JSON.stringify(GameState.map.community_programmes if GameState.map else {}).hash(),
			"schedules": JSON.stringify(_source_schedule_signature()).hash(),
			"balance": JSON.stringify(_balance).hash(),
		}
	var result := _static_runtime_revisions.duplicate()
	result["occupancy"] = _residents.size()
	result["assignments"] = _assignment_revision
	return result

func _source_schedule_signature() -> Array:
	var result: Array = []
	for internal_id in GameState.building_registry.keys():
		var entry: Dictionary = GameState.building_registry[internal_id]
		var structure_index := int(entry.get("structure", -1))
		if structure_index < 0 or structure_index >= GameState.structures.size(): continue
		var profile := GameState.structures[structure_index].find_metadata(BuildingProfile) as BuildingProfile
		if profile:
			result.append([int(internal_id), int(profile.active_start), int(profile.active_end)])
	result.sort_custom(func(a: Array, b: Array): return a[0] < b[0])
	return result

func _ensure_compiled_runtime(sources: Array, revisions: Dictionary) -> Variant:
	if _compiled_runtime == null or not _compiled_runtime.matches_static_revisions(revisions):
		_compiled_runtime = CompiledRuntime.build(sources, revisions)
	elif not _compiled_runtime.matches_revisions(revisions):
		_compiled_runtime.update_dynamic_sources(sources, revisions)
	_runtime_dependency_revisions = revisions.duplicate(true)
	return _compiled_runtime

func _dispose_compiled_runtime() -> void:
	_compiled_runtime = null
	_runtime_dependency_revisions.clear()
	_static_runtime_revisions.clear()
	_explanation_cache_key = ""
	_explanation_cache.clear()
	_migration_fact_cache_key = ""
	_migration_fact_cache.clear()

func _prime_runtime_index(hour: int) -> void:
	if _generator == null or GameState.map == null: return
	var sources := _hour_sources(hour)
	_assign_residents(sources, hour)
	_assignment_prepared_hour_key = _assignment_fast_key(hour)
	if compiled_evaluator_enabled:
		_compiled_runtime = CompiledRuntime.build(sources, _runtime_revisions(hour))
		_runtime_dependency_revisions = _compiled_runtime.get_dependency_revisions()

func rebuild_compiled_runtime(hour: int = -1) -> String:
	var active_hour := hour if hour >= 0 else (int(_clock.current_hour()) if _clock and _clock.has_method("current_hour") else 0)
	var sources := _source_records(active_hour)
	_assign_residents(sources, active_hour)
	_compiled_runtime = CompiledRuntime.build(sources, _runtime_revisions(active_hour))
	_runtime_dependency_revisions = _compiled_runtime.get_dependency_revisions()
	return _compiled_runtime.canonical_fingerprint()

func add_resident_for_tests(resident: CommunityResident) -> void:
	_add_resident(resident)
	_persist()

func clear_residents_for_tests() -> void:
	_clear_residents()
	_persist()

## Scenario-only deterministic seeding. It creates normal resident records and
## never mutates buildings, capacity, cash, demand, or placement state.
func apply_scenario_fixture(fixture: Dictionary, scenario_seed: int) -> void:
	if fixture.is_empty(): return
	_clear_residents()
	_rng.seed = scenario_seed
	var next_id := 1
	for definition in fixture.get("residents", []):
		if not definition is Dictionary: continue
		var resident_id := int(definition.get("resident_id", next_id))
		var personal_seed := int(definition.get("seed", scenario_seed * 1009 + resident_id))
		var resident := _new_resident(resident_id, String(definition.get("cohort_id", "")), personal_seed)
		resident.home_anchor = CommunityConstants.coordinate(definition.get("home_anchor"))
		_add_resident(resident)
		next_id = maxi(next_id, resident_id + 1)
	if GameState.map:
		GameState.map.community_next_resident_id = next_id
	_persist()
	_emit_summary()

func _persist() -> void:
	if GameState.map == null: return
	GameState.map.community_schema_version = COMMUNITY_SCHEMA_VERSION
	GameState.map.community_generation_version = int(_balance.get("personality_generation_version", 1))
	var projection: Array = []
	for resident in _sorted_residents():
		var record: Dictionary = _persisted_records_by_id.get(resident.resident_id, {})
		record = resident.write_persistence_dict(record)
		_persisted_records_by_id[resident.resident_id] = record
		projection.append(record)
	GameState.map.community_residents = projection
	GameState.map.community_rng_state = _rng.state
	GameState.map.community_migration_day = int(_migration.get("last_day", -1))
	GameState.map.community_migration_counters = {
		"arrivals": int(_migration.get("arrivals", 0)),
		"departures": int(_migration.get("departures", 0)),
		"rejections": int(_migration.get("rejections", 0)),
	}

## Explicit persistence boundary used by Builder immediately before a save.
## Normal simulation never treats the DataMap projection as live authority.
func prepare_persistence_projection() -> void:
	_persist()

func _emit_summary() -> void:
	_queue_or_emit_community_event(&"population", [get_population(), get_capacity()])
	_queue_or_emit_community_event(&"qualities", [_average_qualities()])
	_queue_or_emit_community_event(&"refresh", ["community_state"])

func _average_qualities() -> Dictionary:
	var averages := {}
	for quality in CommunityConstants.QUALITIES:
		averages[quality] = 0.0
	for resident in _residents.values():
		for quality in CommunityConstants.QUALITIES:
			averages[quality] += float(resident.current_qualities[quality])
	if not _residents.is_empty():
		for quality in CommunityConstants.QUALITIES:
			averages[quality] /= float(_residents.size())
	return CommunityConstants.rounded_map(averages)

func _sorted_residents() -> Array:
	_ensure_resident_order()
	var result: Array = []
	for resident_id in _resident_order:
		var resident: Variant = _residents.get(resident_id)
		if resident != null: result.append(resident)
	return result

func _ensure_resident_order() -> void:
	var stale := _resident_order.size() != _residents.size()
	if not stale:
		for resident_id in _resident_order:
			if not _residents.has(resident_id): stale = true; break
	if stale:
		_resident_order.assign(_residents.keys())
		_resident_order.sort()

func _add_resident(resident: CommunityResident) -> void:
	var resident_id := resident.resident_id
	if not _residents.has(resident_id):
		_resident_order.insert(_resident_order.bsearch(resident_id), resident_id)
	_residents[resident_id] = resident

func _remove_resident(resident_id: int) -> void:
	_residents.erase(resident_id)
	_persisted_records_by_id.erase(resident_id)
	var index := _resident_order.bsearch(resident_id)
	if index < _resident_order.size() and _resident_order[index] == resident_id:
		_resident_order.remove_at(index)

func _clear_residents() -> void:
	_residents.clear()
	_resident_order.clear()
	_persisted_records_by_id.clear()

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
