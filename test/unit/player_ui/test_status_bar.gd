extends GutTest

class StubEconomy extends RefCounted:
	func get_last_hourly_income() -> int: return 17

class StubWorkplace extends RefCounted:
	func get_total_output() -> int: return 23

class StubAttractiveness extends RefCounted:
	func city_score() -> int: return 31

class StubDemand extends RefCounted:
	func get_bucket_snapshot(bucket_id: String) -> Dictionary:
		return {
			"unserved": {"residential":4, "industrial":5, "commercial":6}.get(bucket_id, 0),
			"total": {"residential":75, "industrial":31, "commercial":12}.get(bucket_id, 0),
		}

class StubUniques extends RefCounted:
	func get_all_profiles() -> Dictionary:
		return {
			"building_postwar_tower_block":{"bucket":"residential","prerequisite_threshold":225},
			"building_postwar_midblock":{"bucket":"residential","prerequisite_threshold":75},
			"building_windmill":{"bucket":"industrial","prerequisite_threshold":10},
			"building_pub":{"bucket":"commercial","prerequisite_threshold":15},
			"building_zero":{"bucket":"commercial","prerequisite_threshold":0},
		}

class StubCatalog extends RefCounted:
	func get_summary_by_id(building_id: String) -> Dictionary:
		return {"display_name": {
			"building_postwar_tower_block":"Postwar Tower Block",
			"building_postwar_midblock":"Postwar Mid-Block",
			"building_windmill":"Windmill",
			"building_pub":"Pub",
		}.get(building_id, building_id)}

class StubCommunity extends RefCounted:
	func get_population() -> int: return 7
	func get_capacity() -> int: return 9
	func get_average_composite() -> float: return 82.4

class StubInbox extends RefCounted:
	func get_pending_count() -> int: return 3

func test_every_top_bar_metric_and_action_has_a_runtime_icon() -> void:
	var bar := PlayerStatusBar.new()
	bar.setup({})
	assert_eq(bar._icons.size(), 9)
	assert_false(bar._icons.has("satisfaction"))
	for key in bar._icons:
		assert_not_null((bar._icons[key] as TextureRect).texture, key)
	assert_not_null(bar._inbox_button.icon)
	assert_not_null(bar._insights_button.icon)
	bar.free()

func test_refresh_projects_canonical_provider_values_without_rebuilding_metrics() -> void:
	var saved_map := GameState.map
	GameState.map = DataMap.new()
	GameState.map.cash = 4321
	var bar := PlayerStatusBar.new()
	bar.setup({"Economy":StubEconomy.new(),"Workplace":StubWorkplace.new(),"Attractiveness":StubAttractiveness.new(),"Demand":StubDemand.new(),"Community":StubCommunity.new(),"Inbox":StubInbox.new()})
	var label_instances := bar._labels.duplicate()
	bar.refresh()
	assert_eq(bar._labels.cash.text, "£4321")
	assert_eq(bar._labels.budget.text, "£17/hr")
	assert_eq(bar._labels.output.text, "23/hr")
	assert_eq(bar._labels.population.text, "7/9")
	assert_eq(bar._labels.community.text, "82%")
	assert_eq(bar._inbox_button.text, "3")
	for key in label_instances: assert_same(bar._labels[key], label_instances[key])
	bar.free()
	GameState.map = saved_map


func test_demand_hover_distinguishes_current_lifetime_and_sorted_lifetime_targets() -> void:
	var bar := PlayerStatusBar.new()
	bar.setup({"Demand":StubDemand.new(),"UniqueRegistry":StubUniques.new(),"BuildingCatalog":StubCatalog.new()})
	bar.refresh()
	var homes: Dictionary = bar._demand_hover_projections["residential"]
	assert_eq(homes["current_available"], 4)
	assert_eq(homes["lifetime_earned"], 75)
	assert_string_contains(homes["text"], "Current available: 4")
	assert_string_contains(homes["text"], "Lifetime earned: 75")
	assert_string_contains(homes["text"], "75 — Postwar Mid-Block (reached)")
	assert_eq(homes["lifetime_targets"].map(func(item): return item["threshold"]), [75, 225])
	assert_eq(bar._metrics["residential"].tooltip_text, homes["text"])
	bar.free()


func test_work_and_shops_hover_only_include_their_own_lifetime_targets() -> void:
	var bar := PlayerStatusBar.new()
	bar.setup({"Demand":StubDemand.new(),"UniqueRegistry":StubUniques.new(),"BuildingCatalog":StubCatalog.new()})
	bar.refresh()
	var work_text := String(bar._demand_hover_projections["industrial"]["text"])
	var shops_text := String(bar._demand_hover_projections["commercial"]["text"])
	assert_string_contains(work_text, "Lifetime earned: 31")
	assert_string_contains(work_text, "10 — Windmill (reached)")
	assert_false(work_text.contains("Pub"))
	assert_string_contains(shops_text, "Lifetime earned: 12")
	assert_string_contains(shops_text, "15 — Pub")
	assert_false(shops_text.contains("Windmill"))
	assert_false(shops_text.contains("building_zero"), "zero thresholds are not lifetime unlock targets")
	bar.free()


func test_high_dpi_layout_scales_authored_hud_without_expanding_past_safe_margins() -> void:
	var bar := PlayerStatusBar.new()
	bar.setup({})
	bar.apply_compact_layout(3840.0)
	assert_eq(bar.scale, Vector2(2.0, 2.0))
	assert_almost_eq(bar.offset_left, 76.8, 0.001)
	assert_almost_eq(bar.offset_right, 1920.0, 0.001)
	assert_eq(bar.offset_bottom - bar.offset_top, 108.0)
	bar.apply_compact_layout(1280.0)
	assert_eq(bar.scale, Vector2.ONE)
	assert_almost_eq(bar.anchor_left, 0.02, 0.001)
	assert_almost_eq(bar.anchor_right, 0.98, 0.001)
	bar.free()
