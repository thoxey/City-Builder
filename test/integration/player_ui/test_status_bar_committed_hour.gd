extends GutTest

const Coordinator := preload("res://plugins/simulation/simulation_transaction_plugin.gd")
const Scheduler := preload("res://plugins/presentation/presentation_scheduler_plugin.gd")
const DayNight := preload("res://plugins/day_night/day_night_plugin.gd")
const PlayerUI := preload("res://plugins/player_ui/player_ui_plugin.gd")
const Intent := preload("res://scripts/simulation/simulation_intent.gd")

class MutableDemand extends RefCounted:
	var available := 2.0
	func get_bucket_snapshot(_id: String) -> Dictionary: return {"unserved":available, "total":available}
class MutableEconomy extends RefCounted:
	var income := 1
	func get_last_hourly_income() -> int: return income
class MutableCommunity extends RefCounted:
	func get_population() -> int: return 3
	func get_capacity() -> int: return 5
	func get_average_composite() -> float: return 70.0

func test_committed_hour_refreshes_the_player_visible_city_stats() -> void:
	var previous_map := GameState.map
	GameState.map = DataMap.new(); GameState.map.cash = 100
	GameState.reset_state_version()
	var demand := MutableDemand.new()
	var economy := MutableEconomy.new()
	var bar := PlayerStatusBar.new()
	add_child(bar)
	bar.setup({"Demand":demand, "Economy":economy, "Community":MutableCommunity.new()})
	var coordinator = Coordinator.new()
	var scheduler = Scheduler.new()
	scheduler.inject({"SimulationTransaction":coordinator})
	add_child(scheduler); scheduler._plugin_ready()
	var ui = PlayerUI.new(); ui._status = bar
	assert_true(ui._register_status_presenter(scheduler).ok)
	coordinator.register_reducer(&"economy", [&"tick"], func(_intents, _context):
		return {"ok":true, "plan":{}, "domains":[&"economy", &"demand"]},
		func(_plan, _context): GameState.map.cash += 25; demand.available += 4; economy.income = 25; return {"ok":true})
	coordinator.register_contributor(&"stats", [&"economy"], func(context, sink):
		sink.submit(Intent.create("stats:%d" % context.absolute_hour, &"stats", "city", &"economy", &"tick", {})))
	var clock = DayNight.new(); clock._simulation_transaction = coordinator
	clock._time = 6.0 / 24.0; clock._last_hour = 6; clock._absolute_hour = 0
	assert_eq(bar._labels.cash.text, "£100")
	assert_eq(bar._labels.residential.text, "2")
	assert_true(clock.advance_hours(1).changed)
	assert_eq(bar._labels.cash.text, "£100", "presenters are deferred until the consistent flush")
	var report: Dictionary = scheduler.flush()
	assert_has(report.presented, "player_ui.status")
	assert_eq(bar._labels.cash.text, "£125")
	assert_eq(bar._labels.budget.text, "£25/hr")
	assert_eq(bar._labels.residential.text, "6")
	clock.free(); ui.free(); scheduler.free(); coordinator.free(); bar.free()
	GameState.map = previous_map
	GameState.reset_state_version()
