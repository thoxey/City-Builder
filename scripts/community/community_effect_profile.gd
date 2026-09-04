extends StructureMetadata
class_name CommunityEffectProfile

var effects: Array = []
var programmes: Dictionary = {}
var default_programme: String = ""

static func from_dict(data: Dictionary) -> CommunityEffectProfile:
	var profile := CommunityEffectProfile.new()
	profile.default_programme = String(data.get("default_programme", ""))
	var seen := {}
	for raw in data.get("effects", []):
		var normalized: Dictionary = normalize_effect(raw)
		if not normalized.is_empty() and not seen.has(normalized["effect_id"]):
			profile.effects.append(normalized)
			seen[normalized["effect_id"]] = true
	for programme_id in data.get("programmes", {}):
		var programme_effects: Array = []
		var programme_seen := {}
		for raw in data["programmes"][programme_id]:
			var normalized: Dictionary = normalize_effect(raw)
			if not normalized.is_empty() and not programme_seen.has(normalized["effect_id"]):
				programme_effects.append(normalized)
				programme_seen[normalized["effect_id"]] = true
		profile.programmes[String(programme_id)] = programme_effects
	if not profile.default_programme.is_empty() and not profile.programmes.has(profile.default_programme):
		profile.default_programme = ""
	return profile

static func normalize_effect(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var effect: Dictionary = raw
	var quality := String(effect.get("quality", ""))
	var manifestation := String(effect.get("manifestation", "neutral"))
	var scope := String(effect.get("scope", ""))
	if quality not in CommunityConstants.QUALITIES or manifestation not in CommunityConstants.MANIFESTATIONS or scope not in CommunityConstants.SCOPES:
		return {}
	var effect_id := String(effect.get("effect_id", ""))
	if effect_id.is_empty():
		return {}
	var radius: Variant = effect.get("radius")
	if scope == "local" and (radius == null or int(radius) < 0):
		return {}
	var schedule: Variant = effect.get("schedule")
	if schedule != null and (not schedule is Dictionary or not schedule.has("start") or not schedule.has("end")):
		return {}
	return {
		"effect_id": effect_id,
		"quality": quality,
		"manifestation": manifestation,
		"amount": float(effect.get("amount", 0.0)),
		"scope": scope,
		"radius": int(radius) if radius != null else null,
		"schedule": schedule.duplicate(true) if schedule is Dictionary else null,
		"capacity": maxi(0, int(effect.get("capacity", 0))) if effect.get("capacity") != null else null,
		"sensitivity": String(effect.get("sensitivity", "")) if effect.get("sensitivity") != null else null,
		"stacking_group": String(effect.get("stacking_group", effect_id)),
		"requires_active_building": bool(effect.get("requires_active_building", true)),
		"reason": String(effect.get("reason", effect_id.replace("_", " ").capitalize())),
	}

func effects_for(programme_id: String = "") -> Array:
	var result := effects.duplicate(true)
	var selected := programme_id if programmes.has(programme_id) else default_programme
	for effect in programmes.get(selected, []):
		result.append(effect.duplicate(true))
	return result
