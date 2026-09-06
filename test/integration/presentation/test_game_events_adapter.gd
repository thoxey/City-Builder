extends GutTest

const Scheduler := preload("res://plugins/presentation/presentation_scheduler_plugin.gd")
const ChangeSet := preload("res://scripts/simulation/authoritative_change_set.gd")

func test_authoritative_game_event_uses_same_change_set_invalidation_path() -> void:
	var scheduler = Scheduler.new()
	add_child_autofree(scheduler)
	scheduler._plugin_ready()
	var calls: Array = []
	scheduler.register_presenter(&"fixture", [&"structures"], func(): return true,
		func(version, domains): calls.append([version, domains]); return {"ok":true})
	var change = ChangeSet.create("place:v1", &"building_mutation", "place", 0, 1,
		[&"structures"], {"structures":["4,5"]})
	GameEvents.authoritative_change_committed.emit(change)
	var report: Dictionary = scheduler.flush()
	assert_eq(report.presented, ["fixture"])
	assert_eq(calls, [[1, [&"structures"]]])
