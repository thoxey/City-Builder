extends GutTest

class StubEconomy extends RefCounted:
	func get_last_hourly_income() -> int: return 17

class StubWorkplace extends RefCounted:
	func get_total_output() -> int: return 23

class StubAttractiveness extends RefCounted:
	func city_score() -> int: return 31

class StubDemand extends RefCounted:
	func get_bucket_snapshot(bucket_id: String) -> Dictionary:
		return {"unserved": {"residential":4, "industrial":5, "commercial":6}.get(bucket_id, 0)}

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
