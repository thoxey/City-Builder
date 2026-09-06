extends RefCounted
class_name CommunityInspector

const QUALITY_META := {
	"opportunity": {"label": "Opportunity", "icon_key": "opportunity"},
	"liveability": {"label": "Liveability", "icon_key": "liveability"},
	"beauty": {"label": "Beauty", "icon_key": "beauty"},
	"belonging": {"label": "Belonging", "icon_key": "belonging"},
}
const LENS_LABELS := {"identity": "Rooted", "freedom": "Independent", "care": "Civic", "neutral": "Shared"}
const SCOPE_LABELS := {"local": "Nearby homes", "participant": "Participants", "resident": "Residents here", "city": "Whole town"}

## Pure projection from canonical Community output and authored context.
static func project(snapshot: Dictionary, catalog_context: Dictionary = {}, clock_context: Dictionary = {}, display_config: Dictionary = {}, previous_projection: Dictionary = {}) -> Dictionary:
	var population := int(snapshot.get("population", 0))
	var capacity := int(snapshot.get("capacity", 0))
	var hour := int(clock_context.get("absolute_hour", clock_context.get("hour", 0)))
	var previous_qualities: Dictionary = previous_projection.get("overview", {}).get("quality_values", {})
	var quality_rows: Array = []
	var quality_values := {}
	for quality in CommunityConstants.QUALITIES:
		var current := float(snapshot.get("average_qualities", {}).get(quality, 0.0))
		quality_values[quality] = current
		quality_rows.append(_quality(quality, current, null, previous_qualities.get(quality), population == 0))

	var residents: Array = []
	var residents_are_sorted := true
	var previous_resident_id := -9223372036854775808
	for raw in snapshot.get("residents", []):
		if raw is Dictionary:
			var resident := _resident(raw, catalog_context, display_config, hour)
			var resident_id := int(resident["resident_id"])
			residents_are_sorted = residents_are_sorted and resident_id >= previous_resident_id
			previous_resident_id = resident_id
			residents.append(resident)
	if not residents_are_sorted:
		residents.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["resident_id"]) < int(b["resident_id"]))
	var resident_limit := int(display_config.get("resident_snapshot_limit", 500))
	var resident_capped := residents.size() > resident_limit
	residents = residents.slice(0, resident_limit)

	var occupied := 0
	var homeless := 0
	var at_risk := 0
	for resident in residents:
		if resident["is_homeless"]: homeless += 1
		else: occupied += 1
		if resident["retention"]["state"] in ["at_risk", "homeless"]: at_risk += 1
	var migration: Dictionary = snapshot.get("migration", {}).duplicate(true)
	migration["net"] = int(migration.get("arrivals", 0)) - int(migration.get("departures", 0))
	migration["latest_event"] = String(snapshot.get("latest_event", ""))
	var composition := _composition(snapshot.get("personality_distribution", {}), population, catalog_context)
	var drivers := _drivers(snapshot.get("effect_summary", []), catalog_context, display_config)
	var warnings := _warnings(population, capacity, homeless, at_risk, migration)
	var empty_state: Variant = null
	if population == 0:
		empty_state = {"title": "Your community is waiting to grow", "body": "Build homes and create a town where prospective residents can thrive.", "action_hint": "Add housing, then balance opportunity, liveability, beauty and belonging."}
	var places := _places(catalog_context.get("places", []), residents, catalog_context, hour, display_config)
	var neighbourhoods := _neighbourhoods(residents, places, display_config)
	var snapshot_key := JSON.stringify({"hour": hour, "population": population, "capacity": capacity, "qualities": quality_values, "migration": migration}).sha256_text()
	return {
		"snapshot_key": snapshot_key, "hour": hour,
		"summary": {"population": population, "capacity": capacity, "composite_happiness": float(snapshot.get("average_composite_happiness", 50.0)), "recent_population_delta": population - int(previous_projection.get("summary", {}).get("population", population)), "has_warning": not warnings.is_empty()},
		"overview": {"occupied_homes": occupied, "free_homes": maxi(0, capacity - occupied), "capacity": capacity, "occupancy_percent": 0.0 if capacity <= 0 else float(occupied) * 100.0 / float(capacity), "homeless_count": homeless, "at_risk_count": at_risk, "qualities": quality_rows, "quality_values": quality_values, "migration": migration, "composition": composition, "positive_drivers": drivers["positive"], "negative_drivers": drivers["negative"], "warnings": warnings, "empty_state": empty_state},
		"residents": residents, "resident_capped": resident_capped, "places": places,
		"neighbourhoods": neighbourhoods, "config": _display_config(display_config),
	}

static func summary_text(snapshot: Dictionary) -> String:
	var model := project(snapshot)
	var summary: Dictionary = model["summary"]
	var qualities: Dictionary = model["overview"]["quality_values"]
	var text := "Community  %d/%d · Happiness %.1f\nOpportunity %.1f  Liveability %.1f\nBeauty %.1f  Belonging %.1f" % [int(summary["population"]), int(summary["capacity"]), float(summary["composite_happiness"]), float(qualities["opportunity"]), float(qualities["liveability"]), float(qualities["beauty"]), float(qualities["belonging"])]
	var positive: Array = model["overview"]["positive_drivers"]
	var negative: Array = model["overview"]["negative_drivers"]
	if not positive.is_empty(): text += "\n+ %.1f %s" % [float(positive[0]["amount"]), positive[0]["reason"]]
	if not negative.is_empty(): text += "\n− %.1f %s" % [absf(float(negative[0]["amount"])), negative[0]["reason"]]
	return text

static func _quality(quality: String, current: float, target: Variant, previous: Variant, empty: bool = false) -> Dictionary:
	var delta := 0.0 if previous == null else current - float(previous)
	var direction := "unknown" if previous == null else ("rising" if delta > 0.0001 else ("falling" if delta < -0.0001 else "stable"))
	return {"quality_id": quality, "label": QUALITY_META[quality]["label"], "icon_key": QUALITY_META[quality]["icon_key"], "current": current, "target": target, "delta": delta, "direction": direction, "status": "empty" if empty else ("good" if current >= 65.0 else ("watch" if current >= 40.0 else "poor"))}

static func _resident(raw: Dictionary, context: Dictionary, config: Dictionary, hour: int) -> Dictionary:
	var id := int(raw.get("resident_id", 0))
	var cohort_id := String(raw.get("cohort_id", "general"))
	var outlook := String(context.get("cohort_names", {}).get(cohort_id, cohort_id.replace("_heavy", "").replace("_", " ").capitalize()))
	var identity_total := 0.0
	var freedom_total := 0.0
	var care_total := 0.0
	var lens_by_quality := {}
	var manifestation_weights: Dictionary = raw.get("manifestation_weights", {})
	for quality in CommunityConstants.QUALITIES:
		var source_weights: Dictionary = manifestation_weights.get(quality, {})
		# Weight rows contain scalar values only; a shallow copy preserves the
		# detached projection contract without paying for recursive duplication.
		var weights: Dictionary = {} if source_weights.is_empty() else source_weights.duplicate()
		lens_by_quality[quality] = weights
		identity_total += float(weights.get("identity", 0.0))
		freedom_total += float(weights.get("freedom", 0.0))
		care_total += float(weights.get("care", 0.0))
	var dominant := "identity"
	var dominant_total := identity_total
	if freedom_total > dominant_total:
		dominant = "freedom"
		dominant_total = freedom_total
	if care_total > dominant_total:
		dominant = "care"
	var home: Variant = CommunityConstants.coordinate_record(raw.get("home_anchor"))
	var is_homeless := home == null
	var below := int(raw.get("below_departure_hours", 0))
	var homeless_hours := int(raw.get("homeless_hours", 0))
	var departure_grace := maxi(1, int(config.get("departure_grace_hours", 24)))
	var relocation_grace := maxi(1, int(config.get("relocation_grace_hours", 24)))
	var elapsed := homeless_hours if is_homeless else below
	var grace := relocation_grace if is_homeless else departure_grace
	var activity: Variant = raw.get("activity_assignment")
	var effects: Array = []
	for effect in raw.get("applied_effects", []):
		if effect is Dictionary: effects.append(_effect(effect, context, hour, activity))
	if effects.size() > 1: effects.sort_custom(_effect_before)
	var positive: Array = []; var negative: Array = []
	for effect in effects:
		if float(effect["applied_amount"]) >= 0.0: positive.append(effect)
		else: negative.append(effect)
	var quality_rows: Array = []
	var current_qualities: Dictionary = raw.get("current_qualities", {})
	var target_qualities: Dictionary = raw.get("target_qualities", {})
	for quality in CommunityConstants.QUALITIES:
		var current := float(current_qualities.get(quality, 50.0))
		quality_rows.append({"quality_id": quality, "label": QUALITY_META[quality]["label"], "icon_key": QUALITY_META[quality]["icon_key"], "current": current, "target": float(target_qualities.get(quality, 50.0)), "delta": 0.0, "direction": "unknown", "status": "good" if current >= 65.0 else ("watch" if current >= 40.0 else "poor")})
	var sensitivities: Array = []
	var raw_sensitivities: Dictionary = raw.get("sensitivities", {})
	for key in ["noise", "pollution", "crowding", "travel"]: sensitivities.append({"sensitivity_id": key, "label": key.capitalize(), "value": float(raw_sensitivities.get(key, 1.0)), "icon_key": key + "-sensitivity"})
	return {"resident_id": id, "label": "Resident #%d" % id, "cohort_id": cohort_id, "outlook_label": outlook, "dominant_lens": dominant, "dominant_lens_label": LENS_LABELS[dominant], "home_anchor": home, "home_label": "No home" if is_homeless else "Home %s" % _anchor_text(home), "is_homeless": is_homeless, "activity": null if activity == null else activity.duplicate(true), "composite_happiness": float(raw.get("composite_happiness", 50.0)), "qualities": quality_rows, "lens_weights_by_quality": lens_by_quality, "sensitivities": sensitivities, "retention": {"state": "homeless" if is_homeless else ("at_risk" if below > 0 else "stable"), "below_threshold_hours": below, "departure_grace_hours": departure_grace, "homeless_hours": homeless_hours, "relocation_grace_hours": relocation_grace, "progress": clampf(float(elapsed) / float(grace), 0.0, 1.0), "hours_remaining": maxi(0, grace - elapsed), "message": ("Relocation window: %d/%d hours" % [homeless_hours, relocation_grace]) if is_homeless else (("Departure risk: %d/%d hours" % [below, departure_grace]) if below > 0 else "Stable")}, "positive_effects": positive, "negative_effects": negative}

static func _effect(raw: Dictionary, context: Dictionary, hour: int, activity: Variant = null) -> Dictionary:
	var bid := String(raw.get("source_building_id", "")); var effect_id := String(raw.get("effect_id", "effect")); var quality := String(raw.get("quality", "opportunity")); var manifestation := String(raw.get("manifestation", "neutral")); var scope := String(raw.get("scope", "city")); var schedule: Variant = raw.get("schedule")
	return {"effect_id": effect_id, "source_building_id": bid, "source_anchor": CommunityConstants.coordinate_record(raw.get("source_anchor")), "source_display_name": _building_name(bid, context), "quality": quality, "quality_label": QUALITY_META.get(quality, {"label": quality.capitalize()})["label"], "manifestation": manifestation, "manifestation_label": LENS_LABELS.get(manifestation, manifestation.capitalize()), "scope": scope, "scope_label": SCOPE_LABELS.get(scope, scope.capitalize()), "base_amount": float(raw.get("base_amount", raw.get("amount", 0.0))), "applied_amount": float(raw.get("applied_amount", raw.get("amount", 0.0))), "exposure": float(raw.get("exposure", 1.0)), "preference_multiplier": float(raw.get("preference_multiplier", 1.0)), "sensitivity_multiplier": float(raw.get("sensitivity_multiplier", 1.0)), "stacking_multiplier": float(raw.get("stacking_multiplier", 1.0)), "reason": String(raw.get("reason", effect_id.replace("_", " ").capitalize())), "schedule": null if schedule == null else schedule.duplicate(true), "schedule_label": _schedule_label(schedule), "active_now": bool(raw.get("active_now", CommunityEffectEvaluator.schedule_active(schedule, hour % 24))), "participant": scope != "participant" or (activity is Dictionary and String(activity.get("building_id", "")) == bid)}

static func _places(source_records: Array, residents: Array, context: Dictionary, hour: int, config: Dictionary) -> Dictionary:
	var result := {}
	var operation_by_id := {}
	for operation_raw in context.get("operation", []):
		if operation_raw is Dictionary:
			operation_by_id[int(operation_raw.get("internal_id", -1))] = operation_raw
	for source_raw in source_records:
		if not source_raw is Dictionary: continue
		var source: Dictionary = source_raw; var anchor: Variant = CommunityConstants.coordinate_record(source.get("anchor")); var key := _anchor_key(anchor)
		if key.is_empty(): continue
		var bid := String(source.get("building_id", "")); var housed: Array = []; var participating: Array = []; var affected: Array = []; var positive: Array = []; var negative: Array = []
		for resident in residents:
			if _anchor_key(resident["home_anchor"]) == key: housed.append(resident["resident_id"])
			var activity: Variant = resident["activity"]
			if activity is Dictionary and _anchor_key(activity.get("anchor")) == key: participating.append(resident["resident_id"])
			var resident_affected := false
			for effect in resident["positive_effects"] + resident["negative_effects"]:
				if _anchor_key(effect["source_anchor"]) != key: continue
				resident_affected = true
				if float(effect["applied_amount"]) >= 0.0: positive.append(effect)
				else: negative.append(effect)
			if resident_affected: affected.append(resident["resident_id"])
		var programme_options: Array = []
		for programme_id in source.get("available_programmes", []):
			var pid := String(programme_id); programme_options.append({"programme_id": pid, "label": pid.replace("_", " ").capitalize(), "theme": "Authored effects and schedule; individual outcomes depend on residents."})
		var radii: Array = []; var capacities: Array = []; var authored_effects: Array = []
		if int(source.get("capacity", 0)) > 0: capacities.append(int(source["capacity"]))
		for effect in source.get("effects", []):
			if effect.get("radius") != null and int(effect.get("radius", 0)) not in radii: radii.append(int(effect["radius"]))
			if effect.get("capacity") != null and int(effect.get("capacity", 0)) not in capacities: capacities.append(int(effect["capacity"]))
			var authored: Dictionary = effect.duplicate(true); authored["source_building_id"] = bid; authored["source_anchor"] = anchor; authored["base_amount"] = float(effect.get("amount", 0.0)); authored["applied_amount"] = float(effect.get("amount", 0.0)); authored["active_now"] = bool(source.get("active", true)) and CommunityEffectEvaluator.schedule_active(effect.get("schedule"), hour % 24); authored_effects.append(_effect(authored, context, hour))
		var operation: Dictionary = operation_by_id.get(int(source.get("internal_id", -1)), {})
		result[key] = {"building_id": bid, "display_name": _building_name(bid, context), "anchor": anchor, "current_programme": String(source.get("programme", "")), "available_programmes": programme_options, "active": bool(source.get("active", true)), "active_schedule": source.get("building_schedule", null), "active_schedule_label": _schedule_label(source.get("building_schedule")), "radii": radii, "capacities": capacities, "housed_resident_ids": housed, "participating_resident_ids": participating, "affected_resident_ids": affected, "positive_effects": _aggregate_effects(positive, config), "negative_effects": _aggregate_effects(negative, config), "authored_effects": authored_effects, "linked_neighbourhood_anchor_keys": [], "active_hour": hour % 24, "operation": operation.duplicate(true), "road_accessible": operation.get("road_accessible"), "open_now": operation.get("open_now", source.get("active", true)), "operating": operation.get("operating"), "operation_reason": operation.get("primary_reason", ""), "fulfilled": operation.get("fulfilled", participating.size())}
	return result

static func _neighbourhoods(residents: Array, places: Dictionary, config: Dictionary) -> Dictionary:
	var result := {}
	for resident in residents:
		if resident["is_homeless"]: continue
		var key := _anchor_key(resident["home_anchor"])
		if not result.has(key): result[key] = {"home_anchor": resident["home_anchor"], "display_label": "Neighbourhood %s" % _anchor_text(resident["home_anchor"]), "resident_ids": [], "quality_totals": {"opportunity": 0.0, "liveability": 0.0, "beauty": 0.0, "belonging": 0.0}, "outlook_counts": {}, "dominant_lenses": {"identity": 0, "freedom": 0, "care": 0}, "positive": [], "negative": [], "affecting_place_anchors": []}
		var n: Dictionary = result[key]; n["resident_ids"].append(resident["resident_id"])
		for quality in resident["qualities"]: n["quality_totals"][quality["quality_id"]] += float(quality["current"])
		n["outlook_counts"][resident["outlook_label"]] = int(n["outlook_counts"].get(resident["outlook_label"], 0)) + 1; n["dominant_lenses"][resident["dominant_lens"]] += 1
		for effect in resident["positive_effects"]: n["positive"].append(effect)
		for effect in resident["negative_effects"]: n["negative"].append(effect)
	for key in result:
		var n: Dictionary = result[key]; var count: int = n["resident_ids"].size(); var averages := {}
		for quality in CommunityConstants.QUALITIES: averages[quality] = float(n["quality_totals"][quality]) / float(count)
		n["resident_count"] = count; n["average_qualities"] = averages; n["positive_drivers"] = _aggregate_effects(n["positive"], config); n["negative_drivers"] = _aggregate_effects(n["negative"], config)
		n.erase("quality_totals"); n.erase("positive"); n.erase("negative")
		for place_key in places:
			var place: Dictionary = places[place_key]
			if place["affected_resident_ids"].any(func(id): return id in n["resident_ids"]): n["affecting_place_anchors"].append(place["anchor"]); place["linked_neighbourhood_anchor_keys"].append(key)
	return result

static func _composition(distribution: Dictionary, population: int, context: Dictionary) -> Dictionary:
	var cohorts: Array = []; var keys: Array = distribution.get("cohorts", {}).keys(); keys.sort()
	for id in keys:
		var count := int(distribution["cohorts"][id]); cohorts.append({"cohort_id": id, "label": context.get("cohort_names", {}).get(id, String(id).replace("_heavy", "").capitalize()), "count": count, "proportion": 0.0 if population <= 0 else float(count) / float(population)})
	var lenses: Array = []
	for lens in CommunityConstants.LENSES:
		var count := int(distribution.get("dominant_lenses", {}).get(lens, 0)); lenses.append({"lens_id": lens, "label": LENS_LABELS[lens], "count": count, "proportion": 0.0 if population <= 0 else float(count) / float(population)})
	return {"outlooks": cohorts, "dominant_lenses": lenses, "empty": population == 0}

static func _drivers(rows: Array, context: Dictionary, config: Dictionary) -> Dictionary:
	var positive: Array = []; var negative: Array = []
	for raw in rows:
		if not raw is Dictionary: continue
		var row := {"effect_id": String(raw.get("effect_id", "")), "source_display_name": _building_name(String(raw.get("source_building_id", "")), context), "quality": String(raw.get("quality", "")), "reason": String(raw.get("reason", "Effect")), "amount": float(raw.get("amount", 0.0)), "residents": int(raw.get("residents", 0))}
		if row["amount"] >= 0.0: positive.append(row)
		else: negative.append(row)
	positive.sort_custom(_summary_before); negative.sort_custom(_summary_before); var limit := int(config.get("effect_snapshot_limit", 12))
	return {"positive": positive.slice(0, limit), "negative": negative.slice(0, limit)}

static func _aggregate_effects(effects: Array, config: Dictionary) -> Array:
	var totals := {}
	for effect in effects:
		var key := "%s|%s|%s" % [effect.get("source_building_id", ""), effect.get("effect_id", ""), effect.get("quality", "")]
		if not totals.has(key): totals[key] = effect.duplicate(true); totals[key]["amount"] = 0.0; totals[key]["residents"] = 0
		totals[key]["amount"] += float(effect.get("applied_amount", 0.0)); totals[key]["residents"] += 1
	var rows: Array = totals.values()
	for row in rows:
		# Place and neighbourhood rows describe the aggregate, not one resident's
		# contribution retained from the first copied effect.
		row["applied_amount"] = row["amount"]
	rows.sort_custom(_summary_before)
	return rows.slice(0, int(config.get("effect_snapshot_limit", 12)))

static func _warnings(population: int, capacity: int, homeless: int, at_risk: int, migration: Dictionary) -> Array:
	var result: Array = []
	if homeless > 0: result.append({"kind": "homeless", "priority": 0, "message": "%d resident%s without a home" % [homeless, "" if homeless == 1 else "s"]})
	if at_risk > 0: result.append({"kind": "at_risk", "priority": 1, "message": "%d resident%s approaching a grace boundary" % [at_risk, "" if at_risk == 1 else "s"]})
	if capacity <= population: result.append({"kind": "no_capacity", "priority": 2, "message": "No free housing capacity"})
	if int(migration.get("rejections", 0)) > 0: result.append({"kind": "rejections", "priority": 3, "message": "%d prospective residents rejected" % int(migration["rejections"])})
	return result

static func _display_config(config: Dictionary) -> Dictionary:
	return {"departure_threshold": float(config.get("departure_threshold", 30.0)), "departure_grace_hours": int(config.get("departure_grace_hours", 24)), "relocation_grace_hours": int(config.get("relocation_grace_hours", 24)), "resident_snapshot_limit": int(config.get("resident_snapshot_limit", 500)), "effect_snapshot_limit": int(config.get("effect_snapshot_limit", 12))}

static func _dominant(values: Dictionary) -> String:
	var result := "identity"
	for key in CommunityConstants.LENSES:
		if float(values.get(key, 0.0)) > float(values.get(result, 0.0)): result = key
	return result

static func _effect_before(a: Dictionary, b: Dictionary) -> bool:
	var aq := CommunityConstants.QUALITIES.find(a.get("quality", "")); var bq := CommunityConstants.QUALITIES.find(b.get("quality", ""))
	if aq != bq: return aq < bq
	var aa := absf(float(a.get("applied_amount", 0.0))); var ba := absf(float(b.get("applied_amount", 0.0)))
	if aa != ba: return aa > ba
	if a.get("source_display_name", "") != b.get("source_display_name", ""): return a.get("source_display_name", "") < b.get("source_display_name", "")
	return a.get("effect_id", "") < b.get("effect_id", "")

static func _summary_before(a: Dictionary, b: Dictionary) -> bool:
	var aa := absf(float(a.get("amount", a.get("applied_amount", 0.0)))); var ba := absf(float(b.get("amount", b.get("applied_amount", 0.0))))
	return aa > ba if aa != ba else String(a.get("effect_id", "")) < String(b.get("effect_id", ""))

static func _building_name(id: String, context: Dictionary) -> String:
	return "Unknown place" if id.is_empty() else String(context.get("building_names", {}).get(id, id.replace("building_", "").replace("_", " ").capitalize()))

static func _schedule_label(schedule: Variant) -> String:
	return "Always" if not schedule is Dictionary else "%02d:00–%02d:00" % [int(schedule.get("start", 0)) % 24, int(schedule.get("end", 0)) % 24]

static func _anchor_key(anchor: Variant) -> String:
	var value: Variant = CommunityConstants.coordinate(anchor)
	return "" if value == null else "%d,%d" % [value.x, value.y]

static func _anchor_text(anchor: Variant) -> String:
	var value: Variant = CommunityConstants.coordinate(anchor)
	return "unknown" if value == null else "(%d, %d)" % [value.x, value.y]
