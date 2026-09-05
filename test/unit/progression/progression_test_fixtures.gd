extends RefCounted
class_name ProgressionTestFixtures

static func character(
	character_id: String = "aristocrat_industrial",
	bucket: String = "industrial",
	want_id: String = "building_crazy_golf",
	threshold: int = 100,
	required_tier: int = 1
) -> Dictionary:
	return {
		"character_id": character_id,
		"character_type": "character",
		"display_name": character_id.replace("_", " ").capitalize(),
		"patron_id": "aristocrat",
		"associated_bucket": bucket,
		"arrival_threshold": threshold,
		"arrival_requires_tier": required_tier,
		"want_building_id": want_id,
		"_source_path": "res://test/fixtures/%s.json" % character_id,
	}

static func patron(
	character_ids: Array = ["aristocrat_residential", "aristocrat_commercial", "aristocrat_industrial"]
) -> Dictionary:
	return {
		"patron_id": "aristocrat",
		"display_name": "The Howarth Players",
		"character_ids": character_ids,
		"landmark_building_id": "building_theatre",
		"donation_area": {"shape": "rect", "rect": [8, -8, 12, 16]},
		"_source_path": "res://test/fixtures/aristocrat.json",
	}

static func unique_profile(
	role: String = "want",
	bucket: String = "industrial",
	tier: int = 1,
	character_id: String = "aristocrat_industrial",
	patron_id: String = ""
) -> UniqueProfile:
	var profile := UniqueProfile.new()
	profile.chain_role = role
	profile.bucket = bucket
	profile.tier = tier
	profile.character_id = character_id
	profile.patron_id = patron_id
	return profile

static func bucket_projection(
	bucket_id: String = "industrial",
	fulfilled: float = 100.0,
	tier: int = 1
) -> Dictionary:
	return {
		"bucket_id": bucket_id,
		"display_name": bucket_id.capitalize(),
		"fulfilled": fulfilled,
		"attained_tier": tier,
		"tier_evidence": [],
	}

static func fresh_map() -> DataMap:
	var map := DataMap.new()
	map.cash = 1000
	map.demand_totals = {
		"residential": 100.0,
		"industrial": 100.0,
		"commercial": 100.0,
	}
	return map
