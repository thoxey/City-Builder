extends GutTest

const CommunityPlugin := preload("res://plugins/community/community_plugin.gd")
const DemandPlugin := preload("res://plugins/demand/demand_plugin.gd")

func test_fresh_town_has_usable_tier_one_and_authored_tier_two_gates() -> void:
	var fresh := _json("res://test/scenarios/fresh_city.json")
	for bucket in ["residential", "industrial", "commercial"]:
		assert_gte(float(fresh["initial_state"]["demand"][bucket]), 5.0)
		var tier_one := _json("res://data/buildings/generic/_pools/%s_t1.json" % bucket)
		var tier_two := _json("res://data/buildings/generic/_pools/%s_t2.json" % bucket)
		assert_eq(float(tier_one.get("demand_threshold", -1)), 0.0)
		if bucket == "residential":
			assert_eq(float(tier_two.get("demand_threshold", 0)), 25.0,
				"generic tower block unlocks at the starting five-house demand budget")
		else:
			assert_gt(float(tier_two.get("demand_threshold", 0)), float(fresh["initial_state"]["demand"][bucket]))

func test_road_cash_cost_is_explicit_and_nonzero() -> void:
	var road := _json("res://data/buildings/road/road_straight.json")
	assert_eq(int(road.get("cash_cost", 0)), 2)

func test_empty_town_has_no_residential_demand_signal() -> void:
	var community := CommunityPlugin.new()
	assert_eq(community.get_residential_demand_signal(), 0)
	community.free()

func test_rebalanced_residential_progression_thresholds() -> void:
	var expected := {
		"building_postwar_terrace": 25,
		"building_postwar_midblock": 75,
		"building_postwar_tower_block": 225,
	}
	for building_id in expected:
		var building := _json("res://data/buildings/unique/%s.json" % building_id)
		assert_eq(_unique_threshold(building), expected[building_id], building_id)

	var tower_pool := _json("res://data/buildings/generic/_pools/residential_t2.json")
	assert_eq(int(tower_pool.get("demand_threshold", -1)), 25)
	assert_eq(int(tower_pool.get("demand_per_unit", -1)), 15)

func test_commercial_demand_generation_is_rebalanced_upward() -> void:
	var demand := DemandPlugin.new()
	assert_eq(demand.commercial_ratio, 1.0)
	assert_eq(demand.rooted_commercial_ratio, 0.5)
	demand.free()

func _unique_threshold(building: Dictionary) -> int:
	for profile: Dictionary in building.get("profiles", []):
		if profile.get("type", "") == "UniqueProfile":
			return int(profile.get("prerequisite_threshold", -1))
	return -1

func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
