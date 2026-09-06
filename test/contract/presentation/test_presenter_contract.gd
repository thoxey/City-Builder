extends GutTest

const Scheduler := preload("res://plugins/presentation/presentation_scheduler_plugin.gd")
const ChangeSet := preload("res://scripts/simulation/authoritative_change_set.gd")

func test_presenters_receive_one_consistent_version_without_cross_references() -> void:
	var scheduler = Scheduler.new()
	var observed := {}
	for id in [&"community", &"dashboard", &"hud"]:
		var captured: StringName = id
		scheduler.register_presenter(id, [&"community"], func(): return true,
			func(version, domains): observed[String(captured)] = [version, domains]; return {"ok":true})
	var change = ChangeSet.create("c4", &"hourly_transaction", "h4", 3, 4, [&"community"])
	scheduler.invalidate(change)
	var report: Dictionary = scheduler.flush()
	assert_eq(report.presented, ["community", "dashboard", "hud"])
	assert_eq(observed.community, observed.dashboard)
	assert_eq(observed.dashboard, observed.hud)
	scheduler.free()
