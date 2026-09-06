extends GutTest

const CarManagerPlugin := preload("res://plugins/traffic/car_manager_plugin.gd")

func _slot(journey_id: int, resident_id: int, revision: int, waiting: bool) -> CarSlot:
	var slot := CarSlot.new()
	slot.journey_id = journey_id
	slot.resident_id = resident_id
	slot.plan_key = "plan-%d" % resident_id
	slot.origin_stop = Vector3i.ZERO
	slot.destination_stop = Vector3i(2, 0, 0)
	slot.route = [Vector3i.ZERO, Vector3i(1, 0, 0), Vector3i(2, 0, 0)]
	slot.road_revision = revision
	slot.waiting = waiting
	return slot

func test_snapshot_has_resident_revision_and_active_waiting_counts() -> void:
	var plugin := CarManagerPlugin.new()
	plugin._active = {7: _slot(7, 12, 3, false), 4: _slot(4, 5, 2, true)}
	var snapshot: Dictionary = plugin.get_civilian_snapshot()
	assert_eq(snapshot["active_car_count"], 2)
	assert_eq(snapshot["waiting_car_count"], 1)
	assert_eq(snapshot["journeys"].map(func(row): return row["resident_id"]), [5, 12])
	assert_eq(snapshot["journeys"][0]["road_revision"], 2)
	plugin.free()

func test_snapshot_route_is_a_detached_copy() -> void:
	var plugin := CarManagerPlugin.new()
	plugin._active = {1: _slot(1, 2, 6, false)}
	var snapshot: Dictionary = plugin.get_civilian_snapshot()
	snapshot["journeys"][0]["road_path"].clear()
	assert_eq(plugin.get_civilian_snapshot()["journeys"][0]["road_path"].size(), 3)
	plugin.free()
