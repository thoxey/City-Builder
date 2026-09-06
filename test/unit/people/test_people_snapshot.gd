extends GutTest

const PeoplePlugin := preload("res://plugins/people/people_plugin.gd")

func _slot(id: int, index: int, state: int) -> PersonSlot:
	var slot := PersonSlot.new()
	slot.resident_id = id
	slot.resident_seed = id * 10
	slot.slot_index = index
	slot.home_anchor = Vector2i(id, 0)
	slot.current_place = Vector2i(id, 0)
	slot.state = state
	slot.purpose = "home"
	return slot

func test_snapshot_reports_binding_counts_and_stable_resident_order() -> void:
	var plugin := PeoplePlugin.new()
	plugin._people = [_slot(8, 0, PersonSlot.VisualState.AT_HOME), _slot(2, 1, PersonSlot.VisualState.AT_HOME)]
	plugin._resident_index = {8: plugin._people[0], 2: plugin._people[1]}
	var snapshot: Dictionary = plugin.get_civilian_snapshot()
	assert_eq(snapshot["visible_count"], 2)
	assert_eq(snapshot["residents"].map(func(row): return row["resident_id"]), [2, 8])
	assert_eq(snapshot["counts_by_state"], {"at_home": 2})
	plugin.free()

func test_snapshot_is_detached_and_projects_alignment_violations() -> void:
	var plugin := PeoplePlugin.new()
	var slot := _slot(4, 0, PersonSlot.VisualState.AT_HOME)
	slot.purpose = "work"
	slot.destination_anchor = Vector2i(8, 0)
	slot.intent = {"resident_id":4, "purpose":"work", "destination_anchor":{"x":9,"z":0}, "reachable":true}
	plugin._people = [slot]
	plugin._resident_index = {4: slot}
	var snapshot: Dictionary = plugin.get_civilian_snapshot()
	assert_eq(snapshot["violations"][0]["code"], "intent_destination_mismatch")
	snapshot["residents"][0]["home_anchor"]["x"] = 999
	assert_eq(plugin.get_civilian_snapshot()["residents"][0]["home_anchor"]["x"], 4)
	plugin.free()
