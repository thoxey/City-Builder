extends GutTest

const EVIDENCE_PATH := "res://specs/013-buildable-community-pass/validation/rebalance-after.json"
const BASELINE := {"liveability": 68.8143, "beauty": 56.3298, "belonging": 50.4525}

func test_fixed_seed_ordinary_town_improves_all_three_early_qualities() -> void:
	var evidence := _json(EVIDENCE_PATH)
	assert_true(evidence.get("success", false), "run scripts/run_town_rebalance.gd to refresh feature-013 evidence")
	assert_eq(int(evidence.get("seed", 0)), 6066)
	assert_eq(int(evidence.get("final_summary", {}).get("land", {}).get("allowed_count", 0)), 256)
	var qualities: Dictionary = evidence.get("final_summary", {}).get("community", {}).get("average_qualities", {})
	for quality in ["liveability", "beauty", "belonging"]:
		assert_gt(float(qualities.get(quality, 0.0)), 50.0, "%s should finish above neutral" % quality)
	assert_gt(float(qualities.get("belonging", 0.0)), float(BASELINE["belonging"]), "the measured pass should make belonging more responsive")

func test_fixed_seed_town_retains_planning_pressure_and_functional_mix() -> void:
	var evidence := _json(EVIDENCE_PATH)
	var criteria: Dictionary = evidence.get("criteria", {})
	assert_true(criteria.get("has_home_penalty", false))
	assert_true(criteria.get("has_shop_bonus", false))
	assert_true(criteria.get("rooted_failures", []).is_empty())
	assert_gte(int(criteria.get("functional_nature", 0)), 2)
	assert_gte(float(criteria.get("success_rate", 0.0)), 0.9)

func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
