extends GutTest

const DayNightPluginCls := preload("res://plugins/day_night/day_night_plugin.gd")

var clock: Node

func before_each() -> void:
	clock = DayNightPluginCls.new()
	clock._time = 6.0 / 24.0
	clock._last_hour = 6
	clock._absolute_hour = 0
	add_child(clock)

func after_each() -> void:
	clock.queue_free()

func test_manual_mode_can_be_enabled_explicitly() -> void:
	clock.set_manual_mode(true)
	assert_true(clock.is_manual())

func test_zero_hour_advance_is_valid_and_emits_nothing() -> void:
	watch_signals(clock)
	var result: Dictionary = clock.advance_hours(0)
	assert_eq(result["status"], "applied")
	assert_false(result["changed"])
	assert_eq(result["details"]["emitted_hours"], 0)
	assert_signal_emit_count(clock, "hour_changed", 0)

func test_one_hour_advance_emits_exactly_once() -> void:
	watch_signals(clock)
	var result: Dictionary = clock.advance_hours(1)
	assert_eq(result["details"]["from_absolute_hour"], 0)
	assert_eq(result["details"]["to_absolute_hour"], 1)
	assert_eq(clock.current_hour(), 7)
	assert_signal_emit_count(clock, "hour_changed", 1)

func test_day_rollover_is_chronological() -> void:
	clock._time = 23.0 / 24.0
	clock._last_hour = 23
	var observed: Array[int] = []
	clock.hour_changed.connect(func(hour: float): observed.append(int(hour)))
	clock.advance_hours(2)
	assert_eq(observed, [0, 1])
	assert_eq(clock.get_absolute_hour(), 2)

func test_advance_emits_one_event_per_requested_hour() -> void:
	watch_signals(clock)
	clock.advance_hours(48)
	assert_signal_emit_count(clock, "hour_changed", 48)
	assert_eq(clock.get_absolute_hour(), 48)

func test_advance_enforces_1000_hour_bound() -> void:
	var result: Dictionary = clock.advance_hours(1001)
	assert_eq(result["status"], "rejected")
	assert_eq(result["reason"], "invalid_hours")
	assert_eq(clock.get_absolute_hour(), 0)
