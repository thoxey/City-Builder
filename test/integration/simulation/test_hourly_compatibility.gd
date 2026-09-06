extends GutTest

const Coordinator := preload("res://plugins/simulation/simulation_transaction_plugin.gd")
const DayNight := preload("res://plugins/day_night/day_night_plugin.gd")
const Intent := preload("res://scripts/simulation/simulation_intent.gd")

func test_legacy_hour_signal_observes_only_committed_state() -> void:
	GameState.reset_state_version()
	var authority := {"ticks":0}
	var coordinator = Coordinator.new()
	coordinator.register_reducer(&"resources", [&"tick"], func(_intents, _context):
		return {"ok":true, "plan":{}, "domains":[&"resources"]},
		func(_plan, _context): authority.ticks += 1; return {"ok":true})
	coordinator.register_contributor(&"stats", [&"resources"], func(context, sink):
		sink.submit(Intent.create("tick:%d" % context.absolute_hour, &"stats", "city",
			&"resources", &"tick", {})))
	var clock = DayNight.new()
	clock._simulation_transaction = coordinator
	clock._time = 6.0 / 24.0; clock._last_hour = 6; clock._absolute_hour = 0
	var observed: Array = []
	coordinator.transaction_committed.connect(func(_change, _ledger):
		observed.append(["committed", authority.ticks, GameState.get_state_version()]))
	clock.hour_changed.connect(func(_hour):
		observed.append(["legacy", authority.ticks, GameState.get_state_version()]))
	assert_true(clock.advance_hours(1).get("changed", false))
	assert_eq(observed, [["committed", 1, 1], ["legacy", 1, 1]])
	clock.free(); coordinator.free()
