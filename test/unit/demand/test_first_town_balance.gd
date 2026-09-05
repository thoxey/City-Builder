extends GutTest

const CommunityPlugin := preload("res://plugins/community/community_plugin.gd")

func test_fresh_town_has_usable_tier_one_and_locked_tier_two() -> void:
	var fresh := _json("res://test/scenarios/fresh_city.json")
	for bucket in ["residential", "industrial", "commercial"]:
		assert_gte(float(fresh["initial_state"]["demand"][bucket]), 5.0)
		var tier_one := _json("res://data/buildings/generic/_pools/%s_t1.json" % bucket)
		var tier_two := _json("res://data/buildings/generic/_pools/%s_t2.json" % bucket)
		assert_eq(float(tier_one.get("demand_threshold", -1)), 0.0)
		assert_gt(float(tier_two.get("demand_threshold", 0)), float(fresh["initial_state"]["demand"][bucket]))

func test_road_cash_cost_is_explicit_and_nonzero() -> void:
	var road := _json("res://data/buildings/road/road_straight.json")
	assert_eq(int(road.get("cash_cost", 0)), 2)

func test_empty_town_has_no_residential_demand_signal() -> void:
	var community := CommunityPlugin.new()
	assert_eq(community.get_residential_demand_signal(), 0)
	community.free()

func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
