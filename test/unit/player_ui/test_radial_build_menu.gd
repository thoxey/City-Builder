extends GutTest

const Radial := preload("res://plugins/player_ui/radial_build_menu.gd")

func test_polar_hit_testing_and_dead_zone() -> void:
	var origin := Vector2(300, 300)
	assert_eq(Radial.wedge_index_for_point(origin, origin, 58, 154, 7), -1)
	assert_eq(Radial.wedge_index_for_point(origin + Vector2.UP * 100, origin, 58, 154, 7), 0)
	assert_eq(Radial.wedge_index_for_point(origin + Vector2.RIGHT * 200, origin, 58, 154, 7), -1)

func test_origin_clamps_inside_safe_area() -> void:
	var rect := Rect2(0, 0, 1280, 720)
	assert_eq(Radial.clamp_origin(Vector2.ZERO, rect, 240, 18), Vector2(258, 258))
	assert_eq(Radial.clamp_origin(Vector2(1280, 720), rect, 240, 18), Vector2(1022, 462))

func test_pages_never_exceed_eight_and_reach_every_entry() -> void:
	for count in [1, 8, 9, 20]:
		var ids: Array = []
		for i in count: ids.append("entry_%02d" % i)
		var reached: Array = []
		for page in Radial.build_pages(ids):
			assert_lte(page.size(), 8)
			for action in page:
				if action.kind == "entry": reached.append(action.target_id)
		assert_eq(reached, ids)

func test_stick_angle_clockwise_order_is_stable() -> void:
	assert_eq(Radial.wedge_index_for_angle(-PI * 0.5, 4), 0)
	assert_eq(Radial.wedge_index_for_angle(0.0, 4), 1)
	assert_eq(Radial.wedge_index_for_angle(PI * 0.5, 4), 2)
