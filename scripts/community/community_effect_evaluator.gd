extends RefCounted
class_name CommunityEffectEvaluator

static func preference_multiplier(resident: CommunityResident, quality: String, manifestation: String) -> float:
	if manifestation == "neutral":
		return 1.0
	var weight := float(resident.manifestation_weights.get(quality, {}).get(manifestation, 0.0))
	return 0.5 + 1.5 * weight

static func schedule_active(schedule: Variant, hour: int) -> bool:
	if schedule == null:
		return true
	var start := int(schedule.get("start", 0)) % 24
	var end := int(schedule.get("end", 24)) % 24
	var current := hour % 24
	if start == end:
		return true
	return current >= start and current < end if start < end else current >= start or current < end

static func applies(effect: Dictionary, resident: CommunityResident, source: Dictionary, context: Dictionary) -> bool:
	if not schedule_active(effect.get("schedule"), int(context.get("hour", 0))):
		return false
	if effect.get("requires_active_building", true) and not bool(source.get("active", true)):
		return false
	match String(effect.get("scope", "")):
		"city": return true
		"local":
			return resident.home_anchor != null and CommunityConstants.manhattan(resident.home_anchor, source.get("anchor")) <= int(effect.get("radius", 0))
		"resident":
			return resident.home_anchor != null and CommunityConstants.manhattan(resident.home_anchor, source.get("anchor")) == 0
		"participant":
			return int(resident.resident_id) in source.get("participants", [])
	return false

static func evaluate(resident: CommunityResident, sources: Array, context: Dictionary = {}) -> Dictionary:
	var applicable: Array = []
	for source_raw in sources:
		var source: Dictionary = source_raw
		for effect_raw in source.get("effects", []):
			var effect: Dictionary = effect_raw
			if applies(effect, resident, source, context):
				applicable.append({"source": source, "effect": effect})
	applicable.sort_custom(_effect_before)
	var group_counts := {}
	var applied: Array = []
	var totals := {}
	for quality in CommunityConstants.QUALITIES:
		totals[quality] = 0.0
	for item in applicable:
		var effect: Dictionary = item["effect"]
		var sign_key := "positive" if float(effect.get("amount", 0.0)) >= 0.0 else "negative"
		var group_key := "%s|%s|%s" % [effect.get("quality", ""), effect.get("stacking_group", ""), sign_key]
		var ordinal := int(group_counts.get(group_key, 0))
		var stacking := 1.0 if ordinal == 0 else (0.5 if ordinal == 1 else (0.25 if ordinal == 2 else 0.0))
		group_counts[group_key] = ordinal + 1
		var record := apply_effect(resident, item["source"], effect, stacking, ordinal)
		applied.append(record)
		totals[effect["quality"]] += float(record["applied_amount"])
	return {"totals": totals, "effects": applied}

## Score-only projection for hot paths such as migration. It deliberately follows
## the same filtering, ordering, stacking and rounding rules as evaluate(), while
## avoiding the diagnostic exposure record allocated for every applied effect.
static func evaluate_totals(resident: CommunityResident, sources: Array, context: Dictionary = {}) -> Dictionary:
	return evaluate_prepared_totals(resident, prepare_effects(sources), context)

## The canonical effect order depends only on authored source/effect fields. Hot
## callers can prepare it once and filter that order for many residents/homes.
static func prepare_effects(sources: Array) -> Array:
	var prepared: Array = []
	for source_raw in sources:
		var source: Dictionary = source_raw
		for effect_raw in source.get("effects", []):
			var effect: Dictionary = effect_raw
			prepared.append({"source": source, "effect": effect})
	prepared.sort_custom(_effect_before)
	return prepared

static func evaluate_prepared_totals(resident: CommunityResident, prepared: Array, context: Dictionary = {}) -> Dictionary:
	var group_counts := {}
	var totals := {}
	for quality in CommunityConstants.QUALITIES:
		totals[quality] = 0.0
	for item in prepared:
		if not applies(item["effect"], resident, item["source"], context):
			continue
		var effect: Dictionary = item["effect"]
		var amount := float(effect.get("amount", 0.0))
		var sign_key := "positive" if amount >= 0.0 else "negative"
		var group_key := "%s|%s|%s" % [effect.get("quality", ""), effect.get("stacking_group", ""), sign_key]
		var ordinal := int(group_counts.get(group_key, 0))
		var stacking := 1.0 if ordinal == 0 else (0.5 if ordinal == 1 else (0.25 if ordinal == 2 else 0.0))
		group_counts[group_key] = ordinal + 1
		var quality := String(effect.get("quality", ""))
		var manifestation := String(effect.get("manifestation", "neutral"))
		var preference := preference_multiplier(resident, quality, manifestation)
		var sensitivity := 1.0
		var sensitivity_id: Variant = effect.get("sensitivity")
		if sensitivity_id != null and not String(sensitivity_id).is_empty():
			sensitivity = float(resident.sensitivities.get(String(sensitivity_id), 1.0))
		totals[quality] += CommunityConstants.rounded(amount * preference * sensitivity * stacking)
	return totals

static func apply_effect(resident: CommunityResident, source: Dictionary, effect: Dictionary, stacking_multiplier: float = 1.0, stacking_ordinal: int = 0) -> Dictionary:
	var quality := String(effect.get("quality", ""))
	var manifestation := String(effect.get("manifestation", "neutral"))
	var preference := preference_multiplier(resident, quality, manifestation)
	var sensitivity := 1.0
	var sensitivity_id: Variant = effect.get("sensitivity")
	if sensitivity_id != null and not String(sensitivity_id).is_empty():
		sensitivity = float(resident.sensitivities.get(String(sensitivity_id), 1.0))
	var exposure := 1.0
	var amount := float(effect.get("amount", 0.0)) * exposure * preference * sensitivity * stacking_multiplier
	var source_anchor: Variant = CommunityConstants.coordinate(source.get("anchor"))
	var resident_anchor: Variant = CommunityConstants.coordinate(resident.home_anchor)
	var distance := CommunityConstants.manhattan(resident_anchor, source_anchor) if resident_anchor != null and source_anchor != null else -1
	var source_building_id := String(source.get("building_id", ""))
	var effect_id := String(effect.get("effect_id", ""))
	return {
		"exposure_id": "%d|%s|%s|%s" % [resident.resident_id, source_building_id, CommunityConstants.coordinate_key(source_anchor), effect_id],
		"resident_id": resident.resident_id,
		"resident_anchor": CommunityConstants.coordinate_record(resident_anchor),
		"source_building_id": source_building_id,
		"source_anchor": CommunityConstants.coordinate_record(source_anchor),
		"effect_id": effect_id,
		"quality": quality,
		"manifestation": manifestation,
		"scope": String(effect.get("scope", "")),
		"base_amount": CommunityConstants.rounded(float(effect.get("amount", 0.0))),
		"radius": int(effect.get("radius", -1)) if effect.get("radius") != null else -1,
		"distance": distance,
		"stacking_group": String(effect.get("stacking_group", "")),
		"stacking_ordinal": stacking_ordinal,
		"exposure": exposure,
		"preference_multiplier": CommunityConstants.rounded(preference),
		"sensitivity_multiplier": CommunityConstants.rounded(sensitivity),
		"stacking_multiplier": CommunityConstants.rounded(stacking_multiplier),
		"applied_amount": CommunityConstants.rounded(amount),
		"reason": String(effect.get("reason", "")),
		"schedule": effect.get("schedule").duplicate(true) if effect.get("schedule") is Dictionary else null,
		"active_now": schedule_active(effect.get("schedule"), int(source.get("evaluation_hour", 0))),
		"participant": String(effect.get("scope", "")) != "participant" or resident.resident_id in source.get("participants", []),
	}

static func update_qualities(resident: CommunityResident, evaluation: Dictionary, baseline: float = 50.0, response_rate: float = 0.1) -> void:
	resident.applied_effects = evaluation.get("effects", []).duplicate(true)
	update_quality_totals(resident, evaluation.get("totals", {}), baseline, response_rate)

## Authoritative hot-path update from compact numeric/domain totals. Explanatory
## AppliedEffect records are projected explicitly and are not resident state.
static func update_quality_totals(resident: CommunityResident, totals: Dictionary,
		baseline: float = 50.0, response_rate: float = 0.1) -> void:
	resident.applied_effects.clear()
	for quality in CommunityConstants.QUALITIES:
		var target := clampf(baseline + float(totals.get(quality, 0.0)), 0.0, 100.0)
		resident.target_qualities[quality] = target
		var current := float(resident.current_qualities.get(quality, baseline))
		resident.current_qualities[quality] = clampf(current + (target - current) * response_rate, 0.0, 100.0)
	var composite := 0.0
	for quality in CommunityConstants.QUALITIES:
		composite += float(resident.current_qualities[quality]) * float(resident.quality_importance.get(quality, 0.0))
	resident.composite_happiness = clampf(composite, 0.0, 100.0)

static func update_quality_numeric(resident: CommunityResident, totals: PackedFloat32Array,
		baseline: float = 50.0, response_rate: float = 0.1) -> void:
	resident.applied_effects.clear()
	var composite := 0.0
	for index in CommunityConstants.QUALITIES.size():
		var quality: String = CommunityConstants.QUALITIES[index]
		var target := clampf(baseline + float(totals[index]), 0.0, 100.0)
		resident.target_qualities[quality] = target
		var current := float(resident.current_qualities.get(quality, baseline))
		var updated := clampf(current + (target - current) * response_rate, 0.0, 100.0)
		resident.current_qualities[quality] = updated
		composite += updated * float(resident.quality_importance.get(quality, 0.0))
	resident.composite_happiness = clampf(composite, 0.0, 100.0)

static func _effect_before(a: Dictionary, b: Dictionary) -> bool:
	var aa := absf(float(a["effect"].get("amount", 0.0)))
	var ba := absf(float(b["effect"].get("amount", 0.0)))
	if aa != ba:
		return aa > ba
	var ac: Variant = CommunityConstants.coordinate(a["source"].get("anchor"))
	var bc: Variant = CommunityConstants.coordinate(b["source"].get("anchor"))
	ac = ac if ac != null else Vector2i.ZERO
	bc = bc if bc != null else Vector2i.ZERO
	if ac.x != bc.x: return ac.x < bc.x
	if ac.y != bc.y: return ac.y < bc.y
	var aid := String(a["source"].get("building_id", ""))
	var bid := String(b["source"].get("building_id", ""))
	if aid != bid: return aid < bid
	return String(a["effect"].get("effect_id", "")) < String(b["effect"].get("effect_id", ""))
