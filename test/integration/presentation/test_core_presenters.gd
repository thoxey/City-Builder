extends GutTest

const Scheduler := preload("res://plugins/presentation/presentation_scheduler_plugin.gd")
const ChangeSet := preload("res://scripts/simulation/authoritative_change_set.gd")

func test_dashboard_community_and_status_present_at_one_committed_version() -> void:
	var scheduler = Scheduler.new()
	var observed := {}
	for presenter_id in [&"dashboard", &"community.panel", &"player_ui.status"]:
		var captured_id: StringName = presenter_id
		scheduler.register_presenter(presenter_id,
			[&"clock", &"economy", &"community", &"occupancy"], func(): return true,
			func(version, domains):
				observed[String(captured_id)] = {"version":version, "domains":domains}
				return {"ok":true})
	var change = ChangeSet.create("hour:8", &"hourly_transaction", "hour:8", 7, 8,
		[&"clock", &"economy", &"community", &"occupancy"])
	scheduler.invalidate(change)
	var report: Dictionary = scheduler.flush()
	assert_eq(report.presented, ["community.panel", "dashboard", "player_ui.status"])
	assert_eq(observed["community.panel"].version, 8)
	assert_eq(observed.dashboard.version, 8)
	assert_eq(observed["player_ui.status"].version, 8)
	assert_eq(observed["community.panel"].domains, observed.dashboard.domains)
	scheduler.free()

func test_hidden_community_does_not_block_visible_status_or_dashboard() -> void:
	var scheduler = Scheduler.new()
	var calls := {"community":0, "dashboard":0, "status":0}
	scheduler.register_presenter(&"community.panel", [&"community"], func(): return false,
		func(_version, _domains): calls.community += 1)
	scheduler.register_presenter(&"dashboard", [&"community"], func(): return true,
		func(_version, _domains): calls.dashboard += 1)
	scheduler.register_presenter(&"player_ui.status", [&"community"], func(): return true,
		func(_version, _domains): calls.status += 1)
	scheduler.invalidate(ChangeSet.create("c1", &"hourly_transaction", "h1", 0, 1, [&"community"]))
	var report: Dictionary = scheduler.flush()
	assert_eq(report.skipped_hidden, ["community.panel"])
	assert_eq(calls, {"community":0, "dashboard":1, "status":1})
	scheduler.free()
