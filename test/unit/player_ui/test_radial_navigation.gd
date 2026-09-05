extends GutTest

const Radial := preload("res://plugins/player_ui/radial_build_menu.gd")

func test_clockwise_navigation_and_dead_zone_leave_a_stable_focus() -> void:
	var menu := Radial.new()
	add_child(menu)
	menu._actions = [
		{"kind":"group", "target_id":"a", "label":"A", "accessible_description":"A", "enabled":true},
		{"kind":"group", "target_id":"b", "label":"B", "accessible_description":"B", "enabled":true},
		{"kind":"group", "target_id":"c", "label":"C", "accessible_description":"C", "enabled":true},
	]
	menu._focused_index = 0
	menu.move_focus(1); assert_eq(menu._focused_index, 1)
	menu.move_focus(-1); assert_eq(menu._focused_index, 0)
	menu.move_focus(-1); assert_eq(menu._focused_index, 2)
	menu.free()

func test_previous_and_next_slots_preserve_deterministic_entry_order() -> void:
	var ids: Array = []
	for i in 20: ids.append("item_%02d" % i)
	var pages := Radial.build_pages(ids)
	assert_eq(pages.size(), 3)
	assert_eq(pages[0][-1]["kind"], "next_page")
	assert_eq(pages[1][0]["kind"], "previous_page")
	assert_eq(pages[1][-1]["kind"], "next_page")
	assert_eq(pages[2][0]["kind"], "previous_page")

func test_pointer_and_stick_angles_share_the_same_sector_mapping() -> void:
	var origin := Vector2(400, 300)
	for index in 8:
		var angle := -PI * 0.5 + TAU * float(index) / 8.0
		assert_eq(Radial.wedge_index_for_point(origin + Vector2.from_angle(angle) * 100.0, origin, 58, 154, 8), index)
		assert_eq(Radial.wedge_index_for_angle(angle, 8), index)

func test_device_switch_keeps_one_focus_and_escape_closes() -> void:
	var menu := Radial.new()
	add_child(menu)
	menu.set_model({"groups":[
		{"id":"roads", "label":"Roads & Paths", "icon_key":"roads", "total_count":1, "entry_ids":["road"]},
		{"id":"nature", "label":"Nature", "icon_key":"nature", "total_count":1, "entry_ids":["grass"]},
	], "entries_by_id":{}})
	menu.open_menu(Vector2(400, 300))
	menu.move_focus(1) # keyboard
	assert_eq(menu._focused_index, 1)
	menu._set_focus(Radial.wedge_index_for_point(menu._origin + Vector2.UP * 100.0, menu._origin, 58, 154, 2)) # pointer
	assert_eq(menu._focused_index, 0)
	menu._set_focus(Radial.wedge_index_for_angle(PI * 0.5, 2)) # stick
	assert_eq(menu._focused_index, 1)
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"; escape.pressed = true
	menu._input(escape)
	assert_false(menu.visible)
	menu.free()
