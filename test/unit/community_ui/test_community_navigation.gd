extends GutTest

class FakeCommunity extends PluginBase:
	var value: Dictionary
	func get_ui_model(_previous: Dictionary = {}) -> Dictionary: return value.duplicate(true)

func test_section_navigation_persists_without_affecting_model() -> void:
	var saved := GameState.map; GameState.map = DataMap.new()
	var community := FakeCommunity.new(); community.value = CommunityUITestFixtures.model()
	var panel := CommunityPanel.new(); add_child(panel); panel.setup(community); panel._perform_refresh()
	var before := community.value.duplicate(true); panel.show_section("residents")
	assert_eq(GameState.map.community_section, "residents"); assert_eq(community.value, before)
	panel.queue_free(); community.free(); GameState.map = saved

func test_panel_uses_one_dimensional_scroll_and_bounded_width_at_1280() -> void:
	var panel := CommunityPanel.new(); add_child(panel); panel._build_shell(); panel.size = Vector2(380, 650)
	assert_eq(panel._scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	assert_lte(panel.size.x, 380.0); assert_lte(panel.size.y, 660.0)
	panel.queue_free()

func test_stale_resident_and_place_selection_return_to_parent() -> void:
	var community := FakeCommunity.new(); community.value = CommunityUITestFixtures.model()
	var panel := CommunityPanel.new(); add_child(panel); panel.setup(community); panel._selected_resident_id = 999; panel._selected_place_key = "99,99"; panel._perform_refresh()
	assert_eq(panel._selected_resident_id, 0); assert_eq(panel._selected_place_key, "")
	panel.queue_free(); community.free()
