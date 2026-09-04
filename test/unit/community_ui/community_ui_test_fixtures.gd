extends RefCounted
class_name CommunityUITestFixtures

static func resident(id: int, home: Variant = Vector2i.ZERO, cohort: String = "general", lens: String = "care", below: int = 0, homeless_hours: int = 0) -> Dictionary:
	var weights := {}
	for quality in CommunityConstants.QUALITIES:
		weights[quality] = {"identity": 0.1, "freedom": 0.1, "care": 0.1}
		weights[quality][lens] = 0.8
	return {"resident_id": id, "seed": id * 999, "cohort_id": cohort, "home_anchor": CommunityConstants.coordinate_record(home), "quality_importance": {"opportunity": 0.25, "liveability": 0.25, "beauty": 0.25, "belonging": 0.25}, "manifestation_weights": weights, "sensitivities": {"noise": 1.2, "pollution": 0.9, "crowding": 1.1, "travel": 0.8}, "current_qualities": {"opportunity": 62.0, "liveability": 44.0, "beauty": 70.0, "belonging": 58.0}, "target_qualities": {"opportunity": 66.0, "liveability": 40.0, "beauty": 74.0, "belonging": 65.0}, "composite_happiness": 58.5, "below_departure_hours": below, "homeless_hours": homeless_hours, "activity_assignment": {"building_id": "building_nightclub", "anchor": {"x": 2, "z": 0}, "programme": "rock_nights"}, "applied_effects": []}

static func applied(id: String, amount: float, quality: String, source: String, anchor: Vector2i, schedule: Variant = null, scope: String = "local", manifestation: String = "neutral") -> Dictionary:
	return {"effect_id": id, "source_building_id": source, "source_anchor": CommunityConstants.coordinate_record(anchor), "quality": quality, "manifestation": manifestation, "scope": scope, "base_amount": amount, "applied_amount": amount, "exposure": 1.0, "preference_multiplier": 1.0, "sensitivity_multiplier": 1.0, "stacking_multiplier": 1.0, "reason": id.replace("_", " ").capitalize(), "schedule": schedule, "active_now": true}

static func snapshot(count: int = 2, capacity: int = 5) -> Dictionary:
	var residents: Array = []
	for index in count:
		var value := resident(index + 1, Vector2i.ZERO, "identity_heavy" if index % 2 == 0 else "freedom_heavy", "identity" if index % 2 == 0 else "freedom")
		value["applied_effects"] = [applied("park_benefit", 6.0, "beauty", "building_duck_pond", Vector2i(1, 0), null, "local", "care"), applied("late_music_noise", -12.0, "liveability", "building_nightclub", Vector2i(2, 0), {"start": 21, "end": 4})]
		residents.append(value)
	return {"population": count, "capacity": capacity, "average_qualities": {"opportunity": 62.0, "liveability": 44.0, "beauty": 70.0, "belonging": 58.0}, "average_composite_happiness": 58.5, "personality_distribution": {"cohorts": {"identity_heavy": ceili(count / 2.0), "freedom_heavy": floori(count / 2.0)}, "dominant_lenses": {"identity": ceili(count / 2.0), "freedom": floori(count / 2.0), "care": 0}}, "migration": {"arrivals": count, "departures": 0, "rejections": 0, "last_day": 0}, "effect_summary": [{"source_building_id": "building_duck_pond", "effect_id": "park_benefit", "quality": "beauty", "reason": "Park benefit", "amount": 6.0 * count, "residents": count}, {"source_building_id": "building_nightclub", "effect_id": "late_music_noise", "quality": "liveability", "reason": "Late music noise", "amount": -12.0 * count, "residents": count}], "residents": residents}

static func context(hour: int = 23) -> Dictionary:
	return {"building_names": {"building_duck_pond": "Duck Pond", "building_nightclub": "Nightclub", "building_theatre": "The Theatre"}, "cohort_names": {"identity_heavy": "Rooted residents", "freedom_heavy": "Independent residents", "care_heavy": "Civic residents", "general": "General residents"}, "places": [{"building_id": "building_duck_pond", "anchor": Vector2i(1, 0), "active": true, "capacity": 20, "programme": "", "available_programmes": [], "effects": [{"effect_id": "park_benefit", "quality": "beauty", "manifestation": "care", "amount": 6.0, "scope": "local", "radius": 2, "reason": "Park benefit"}], "participants": []}, {"building_id": "building_nightclub", "anchor": Vector2i(2, 0), "active": true, "capacity": 60, "programme": "rock_nights", "available_programmes": ["rock_nights"], "building_schedule": {"start": 21, "end": 4}, "effects": [{"effect_id": "late_music_noise", "quality": "liveability", "manifestation": "neutral", "amount": -12.0, "scope": "local", "radius": 2, "schedule": {"start": 21, "end": 4}, "reason": "Late music noise"}], "participants": [1, 2], "evaluation_hour": hour}]}

static func config() -> Dictionary:
	return {"departure_threshold": 30.0, "departure_grace_hours": 24, "relocation_grace_hours": 24, "resident_snapshot_limit": 500, "effect_snapshot_limit": 12}

static func model(count: int = 2, capacity: int = 5, hour: int = 23) -> Dictionary:
	return CommunityInspector.project(snapshot(count, capacity), context(hour), {"hour": hour, "absolute_hour": hour}, config())
