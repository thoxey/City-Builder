extends RefCounted
class_name CommunityTestFixtures

static func resident(resident_id: int = 1, home: Variant = Vector2i.ZERO, dominant_lens: String = "care") -> CommunityResident:
	var value := CommunityResident.new()
	value.resident_id = resident_id
	value.seed = resident_id * 1009
	value.home_anchor = CommunityConstants.coordinate(home)
	for quality in CommunityConstants.QUALITIES:
		value.manifestation_weights[quality] = {"identity": 0.1, "freedom": 0.1, "care": 0.1}
		value.manifestation_weights[quality][dominant_lens] = 0.8
	return value

static func effect(effect_id: String, quality: String, amount: float, manifestation: String = "neutral", scope: String = "city", extras: Dictionary = {}) -> Dictionary:
	var raw := {
		"effect_id": effect_id, "quality": quality, "manifestation": manifestation,
		"amount": amount, "scope": scope, "stacking_group": extras.get("stacking_group", effect_id),
		"reason": extras.get("reason", effect_id.replace("_", " ").capitalize()),
	}
	for key in extras: raw[key] = extras[key]
	return CommunityEffectProfile.normalize_effect(raw)

static func source(building_id: String, anchor: Vector2i, effects: Array, participants: Array = []) -> Dictionary:
	return {"building_id": building_id, "anchor": anchor, "active": true, "effects": effects, "participants": participants}

static func empty_map(seed: int = 1) -> DataMap:
	var map := DataMap.new()
	map.community_schema_version = 1
	map.community_rng_seed = seed
	return map
