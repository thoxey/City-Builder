extends PluginBase

const BALANCE_PATH := "res://data/community/balance.json"
const COHORTS_PATH := "res://data/community/cohorts.json"
const COMMUNITY_SCHEMA_VERSION := 1

var _catalog: PluginBase
var _clock: PluginBase
var _residential: PluginBase
var _balance: Dictionary = {}
var _cohorts: Array = []
var _generator: CommunityPersonalityGenerator
var _rng := RandomNumberGenerator.new()
var _residents: Dictionary = {} # resident_id -> CommunityResident
var _migration := {"arrivals": 0, "departures": 0, "rejections": 0, "last_day": -1}
var _latest_event: String = ""

func get_plugin_name() -> String: return "Community"

func get_dependencies() -> Array[String]:
	return ["BuildingCatalog", "DayNight", "Residential"]

func inject(deps: Dictionary) -> void:
	_catalog = deps.get("BuildingCatalog")
	_clock = deps.get("DayNight")
	_residential = deps.get("Residential")

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
	_persist()
	_emit_summary()

func _on_structure_demolished(position: Vector3i) -> void:
	var anchor := Vector2i(position.x, position.z)
	for resident in _residents.values():
		if resident.home_anchor == anchor:
			resident.home_anchor = null
			resident.homeless_hours = 0
			resident.activity_assignment = null
	_persist()
	_emit_summary()

func _on_hour(hour: float) -> void:
	var hour_i := int(hour) % 24
	var sources := _source_records(hour_i)
	_assign_activities(sources)
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
		if profile == null:
			continue
		var building_profile := structure.find_metadata(BuildingProfile) as BuildingProfile
		var active := true
		var capacity := 0
		if building_profile:
			active = _in_window(hour, int(building_profile.active_start), int(building_profile.active_end))
			capacity = building_profile.capacity
		var anchor: Vector2i = entry.get("anchor", Vector2i.ZERO)
		var key := _anchor_key(anchor)
		var programme := String(GameState.map.community_programmes.get(key, profile.default_programme)) if GameState.map else profile.default_programme
		var effects := profile.effects_for(programme)
		var available_programmes: Array = profile.programmes.keys()
		available_programmes.sort()
		for effect in effects:
			if effect.get("capacity") != null:
				capacity = maxi(capacity, int(effect["capacity"]))
		result.append({
			"internal_id": int(internal_id),
			"building_id": _catalog.get_id_by_index(structure_index) if _catalog else "",
			"anchor": anchor,
			"active": active,
			"capacity": capacity,
			"programme": programme,
			"available_programmes": available_programmes,
			"building_schedule": {"start": int(building_profile.active_start), "end": int(building_profile.active_end)} if building_profile else null,
			"evaluation_hour": hour,
			"effects": effects,
			"participants": [],
		})
	return result

func _assign_activities(sources: Array) -> void:
	var participant_sources: Array = []
	for source in sources:
		if not source.get("active", true) or int(source.get("capacity", 0)) <= 0:
			continue
		for effect in source.get("effects", []):
			if effect.get("scope") == "participant" and CommunityEffectEvaluator.schedule_active(effect.get("schedule"), _clock.current_hour() if _clock else 0):
				participant_sources.append(source)
				break
	var remaining := {}
	for source in participant_sources:
		remaining[int(source["internal_id"])] = int(source["capacity"])
	# Keep valid assignments first in resident-id order.
	for resident in _sorted_residents():
		var assigned_id := int(resident.activity_assignment.get("internal_id", -1)) if resident.activity_assignment is Dictionary else -1
		for source in participant_sources:
			if int(source["internal_id"]) == assigned_id and int(remaining[assigned_id]) > 0:
				source["participants"].append(resident.resident_id)
				remaining[assigned_id] -= 1
				break
	# Assign everyone else by weighted personal benefit, then distance and source order.
	for resident in _sorted_residents():
		var already := false
		for source in participant_sources:
			if resident.resident_id in source["participants"]:
				already = true
				break
		if already:
			continue
		var ranked: Array = []
		for source in participant_sources:
			var source_id := int(source["internal_id"])
			if int(remaining[source_id]) <= 0:
				continue
			var benefit := _participant_benefit(resident, source)
			if benefit <= 0.0:
				continue
			ranked.append({"source": source, "benefit": benefit, "distance": CommunityConstants.manhattan(resident.home_anchor, source["anchor"])})
		ranked.sort_custom(func(a, b):
			if a["benefit"] != b["benefit"]: return a["benefit"] > b["benefit"]
			if a["distance"] != b["distance"]: return a["distance"] < b["distance"]
			var aa: Vector2i = a["source"]["anchor"]
			var bb: Vector2i = b["source"]["anchor"]
			return aa.x < bb.x if aa.x != bb.x else (aa.y < bb.y if aa.y != bb.y else a["source"]["building_id"] < b["source"]["building_id"]))
		if ranked.is_empty():
			resident.activity_assignment = null
			continue
		var chosen: Dictionary = ranked[0]["source"]
		chosen["participants"].append(resident.resident_id)
		remaining[int(chosen["internal_id"])] -= 1
		resident.activity_assignment = {
			"internal_id": int(chosen["internal_id"]),
			"building_id": chosen["building_id"],
			"anchor": CommunityConstants.coordinate_record(chosen["anchor"]),
			"programme": chosen["programme"],
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
	var results: Array = []
	for home in homes:
		var previous_home: Variant = candidate.home_anchor
		candidate.home_anchor = CommunityConstants.coordinate(home["anchor"])
		var daily_totals := {}
		for quality in CommunityConstants.QUALITIES: daily_totals[quality] = 0.0
		var predicted_effects: Array = []
		# A migration quote considers one representative authored day so scheduled
		# work/night opportunities and their nuisances remain visible at dawn.
		for evaluation_hour in 24:
			var sources := _source_records(evaluation_hour)
			var best_source: Variant = null
			var best_benefit := 0.0
			for source in sources:
				var benefit := _participant_benefit(candidate, source, evaluation_hour)
				if benefit > best_benefit:
					best_benefit = benefit
					best_source = source
			if best_source != null:
				best_source["participants"] = [candidate.resident_id]
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
	return {"building_names": names, "cohort_names": cohort_names, "places": _source_records(active_hour)}

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
		"latest_event": _latest_event,
	}
	if not compact:
		snapshot["residents"] = get_resident_records(true)
	return snapshot

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
