extends GutTest

const Scheduler := preload("res://plugins/presentation/presentation_scheduler_plugin.gd")
const ChangeSet := preload("res://scripts/simulation/authoritative_change_set.gd")

func _change(version: int, domains: Array) -> Variant:
	return ChangeSet.create("c%d" % version, &"hourly_transaction", "h%d" % version,
		version - 1, version, domains)

func test_coalesces_and_presents_visible_registration_once() -> void:
	var scheduler = Scheduler.new()
	var calls: Array = []
	scheduler.register_presenter(&"hud", [&"clock", &"economy"], func(): return true,
		func(version, domains): calls.append([version, domains]))
	scheduler.invalidate(_change(1, [&"clock"]))
	scheduler.invalidate(_change(2, [&"economy"]))
	var report: Dictionary = scheduler.flush()
	assert_eq(calls.size(), 1)
	assert_eq(calls[0][0], 2)
	assert_eq(report.presented, ["hud"])
	scheduler.free()

func test_hidden_presenter_does_no_work_then_catches_up_once() -> void:
	var scheduler = Scheduler.new()
	var state := {"visible": false, "count": 0}
	scheduler.register_presenter(&"community", [&"community"], func(): return state.visible,
		func(_version, _domains): state.count += 1)
	scheduler.invalidate(_change(1, [&"community"]))
	assert_eq(scheduler.flush().skipped_hidden, ["community"])
	assert_eq(state.count, 0)
	state.visible = true
	scheduler.flush()
	assert_eq(state.count, 1)
	scheduler.free()

func test_reentrant_invalidation_waits_for_next_flush() -> void:
	var scheduler = Scheduler.new()
	var state := {"count": 0}
	scheduler.register_presenter(&"hud", [&"clock"], func(): return true, func(_version, _domains):
		state.count += 1
		if state.count == 1: scheduler.invalidate(_change(2, [&"clock"])))
	scheduler.invalidate(_change(1, [&"clock"]))
	var first: Dictionary = scheduler.flush()
	assert_eq(state.count, 1)
	assert_eq(first.next_flush_count, 1)
	scheduler.flush()
	assert_eq(state.count, 2)
	scheduler.free()

func test_failed_presenter_is_reported_without_blocking_later_presenters() -> void:
	var scheduler = Scheduler.new()
	var calls: Array = []
	scheduler.register_presenter(&"alpha", [&"clock"], func(): return true,
		func(_version, _domains): calls.append("alpha"); return {"ok":false, "reason":"fixture"})
	scheduler.register_presenter(&"beta", [&"clock"], func(): return true,
		func(_version, _domains): calls.append("beta"); return {"ok":true})
	scheduler.invalidate(_change(1, [&"clock"]))
	var report: Dictionary = scheduler.flush()
	assert_eq(calls, ["alpha", "beta"])
	assert_eq(report.failed, [{"presenter_id":"alpha", "reason":"fixture"}])
	assert_eq(report.presented, ["beta"])
	scheduler.free()
