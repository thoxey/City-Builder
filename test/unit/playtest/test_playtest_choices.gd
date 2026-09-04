extends GutTest

const PlaytestCls := preload("res://plugins/playtest/playtest_plugin.gd")

func test_choice_projection_groups_variants_and_filters() -> void:
	var plugin := PlaytestCls.new()
	var catalog := ChoiceCatalog.new()
	var palette := ChoicePalette.new()
	var economy := ChoiceEconomy.new()
	var demand := ChoiceDemand.new()
	var uniques := ChoiceUniques.new()
	plugin._status = "ready"
	plugin._catalog = catalog
	plugin._palette = palette
	plugin._economy = economy
	plugin._demand = demand
	plugin._uniques = uniques
	var all: Array = plugin.get_choices()["choices"]
	assert_eq(all.size(), 2)
	assert_eq(all[0]["choice_id"], "residential_t1")
	assert_eq(all[0]["variants"], ["house_a", "house_b"])
	assert_eq(plugin.get_choices({"category": "nature"})["choices"].size(), 1)
	var snapshot := plugin.get_snapshot()
	assert_eq(snapshot["available_choice_count"], 2)
	assert_false(snapshot["tier_two_available"])
	plugin.free(); catalog.free(); palette.free(); economy.free(); demand.free(); uniques.free()

func test_choice_availability_contains_stable_reasons() -> void:
	var plugin := PlaytestCls.new()
	var catalog := ChoiceCatalog.new()
	var palette := ChoicePalette.new()
	var economy := ChoiceEconomy.new()
	var demand := ChoiceDemand.new()
	var uniques := ChoiceUniques.new()
	plugin._status = "ready"; plugin._catalog = catalog; plugin._palette = palette
	plugin._economy = economy; plugin._demand = demand; plugin._uniques = uniques
	economy.blocked = true
	demand.blocked = true
	var choices: Array = plugin.get_choices({"available_only": false})["choices"]
	assert_false(choices[0]["available"])
	assert_has(choices[0]["reasons"], "insufficient_cash")
	assert_has(choices[0]["reasons"], "insufficient_demand")
	assert_eq(plugin.get_choices({"available_only": true})["choices"].size(), 0)
	plugin.free(); catalog.free(); palette.free(); economy.free(); demand.free(); uniques.free()

class ChoiceCatalog extends PluginBase:
	var items: Array[Structure] = []
	var summaries: Array = []
	func _init() -> void:
		for row in [["tree", "nature", ""], ["house_b", "residential", "residential_t1"], ["house_a", "residential", "residential_t1"]]:
			var s := Structure.new(); s.pool_id = row[2]; items.append(s)
			summaries.append({"building_id": row[0], "category": row[1], "pool_id": row[2], "cash_cost": 10})
	func get_plugin_name() -> String: return "ChoiceCatalog"
	func get_all() -> Array[Structure]: return items
	func get_summary_by_index(i: int) -> Dictionary: return summaries[i]

class ChoicePalette extends PluginBase:
	func get_plugin_name() -> String: return "ChoicePalette"
	func get_entry_records() -> Array:
		return [{"id": "tree", "display_name": "Tree", "structure_indices": [0]}, {"id": "residential_t1", "display_name": "House", "structure_indices": [1, 2]}]

class ChoiceEconomy extends PluginBase:
	var blocked := false
	func get_plugin_name() -> String: return "ChoiceEconomy"
	func quote_cash(_s: Structure) -> Dictionary: return {"ok": not blocked, "cost": 10, "have": 0 if blocked else 100}
	func get_last_hourly_income() -> int: return 0

class ChoiceDemand extends PluginBase:
	var blocked := false
	func get_plugin_name() -> String: return "ChoiceDemand"
	func quote_placement(_s: Structure) -> Dictionary: return {"ok": not blocked, "bucket_id": "residential", "cost": 5.0, "have": 0.0 if blocked else 100.0, "threshold": 0.0, "reason": "insufficient" if blocked else ""}
	func get_bucket_snapshot(_bucket_id: String) -> Dictionary: return {"total": 100.0, "fulfilled": 0.0, "unserved": 100.0}

class ChoiceUniques extends PluginBase:
	func get_plugin_name() -> String: return "ChoiceUniques"
	func is_unique(_id: String) -> bool: return false
	func get_all_profiles() -> Dictionary: return {}
	func is_unlocked(_id: String) -> bool: return false
	func is_placed(_id: String) -> bool: return false
