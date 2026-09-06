extends GutTest

const PlaytestCls := preload("res://plugins/playtest/playtest_plugin.gd")

var _playtest: Node
var _saved_map: DataMap

func before_each() -> void:
	_saved_map = GameState.map
	GameState.map = DataMap.new()
	_playtest = PlaytestCls.new()
	_playtest._clock = ProfileClock.new()
	_playtest._community = EmptyCommunity.new()
	_playtest.set_builder_for_tests(EmptyBuilder.new())
	add_child(_playtest)
	_playtest.start_session({"scenario_id":"fresh_city", "seed":9})

func after_each() -> void:
	var owned := [_playtest._clock, _playtest._community, _playtest._builder]
	_playtest.queue_free()
	for node in owned:
		node.free()
	GameState.map = _saved_map

func test_none_mode_omits_snapshot_and_reports_action_costs() -> void:
	var outcome: Dictionary = _playtest.handle_command("advance", {
		"request_id":"none-1", "hours":2, "snapshot_mode":"none", "profile":true,
	})
	assert_eq(outcome["status"], "applied")
	assert_does_not_have(outcome, "snapshot")
	assert_eq(outcome["performance"]["snapshot_mode"], "none")
	assert_eq(outcome["performance"]["snapshot_usec"], 0)
	assert_has(outcome["details"], "performance")

func test_compact_and_default_full_modes_preserve_projection_contract() -> void:
	var compact: Dictionary = _playtest.handle_command("advance", {"request_id":"compact-1", "hours":0, "snapshot_mode":"compact"})
	var full: Dictionary = _playtest.handle_command("advance", {"request_id":"full-1", "hours":0})
	assert_does_not_have(compact["snapshot"]["community"], "residents")
	assert_has(full["snapshot"]["community"], "residents")

func test_invalid_snapshot_mode_rejects_without_mutating_gameplay() -> void:
	var before: int = int(_playtest._clock.absolute_hour)
	var outcome: Dictionary = _playtest.handle_command("advance", {"request_id":"bad-mode", "hours":1, "snapshot_mode":"huge"})
	assert_eq(outcome["status"], "rejected")
	assert_eq(outcome["reason"], "invalid_snapshot_mode")
	assert_eq(_playtest._clock.absolute_hour, before)

class EmptyBuilder extends Node:
	func reset_to_fresh_map(map: DataMap) -> Dictionary:
		GameState.map = map
		return PlaytestActionResult.applied()
	static func _orientation_to_steps(_orientation: int) -> int: return 0

class ProfileClock extends PluginBase:
	var absolute_hour := 0
	var hour := 6
	func reset_manual_clock(start_hour: int) -> void:
		absolute_hour = 0
		hour = start_hour
	func advance_hours(hours: int, profile: bool = false) -> Dictionary:
		var old := absolute_hour
		absolute_hour += hours
		hour = (hour + hours) % 24
		var details := {"requested_hours":hours,"emitted_hours":hours,"from_absolute_hour":old,"to_absolute_hour":absolute_hour}
		if profile:
			details["performance"] = {"total_usec":1,"max_hour_usec":1,"hour_timings":[]}
		return PlaytestActionResult.applied(details)
	func get_absolute_hour() -> int: return absolute_hour
	func current_hour() -> int: return hour
	func is_manual() -> bool: return true

class EmptyCommunity extends PluginBase:
	func get_population() -> int: return 0
	func get_snapshot(compact: bool = false) -> Dictionary:
		var result := {"population":0,"capacity":0,"average_qualities":{},"average_composite_happiness":50.0,"personality_distribution":{},"migration":{},"effect_summary":[],"assignments":[],"spatial":{}}
		if not compact: result["residents"] = []
		return result
