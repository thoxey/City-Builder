extends GutTest

func test_all_factory_buttons_are_keyboard_focusable() -> void:
	var button := CommunityUIFactory.button("Community")
	assert_eq(button.focus_mode, Control.FOCUS_ALL); button.free()

func test_quality_direction_and_effect_signs_do_not_depend_on_colour() -> void:
	var model := CommunityUITestFixtures.model()
	for row in model["overview"]["qualities"]: assert_has(row, "direction"); assert_has(row, "label")
	var resident: Dictionary = model["residents"][0]
	assert_true(CommunityUIFactory.signed_amount(resident["positive_effects"][0]["applied_amount"]).begins_with("+"))
	assert_true(CommunityUIFactory.signed_amount(resident["negative_effects"][0]["applied_amount"]).begins_with("-"))

func test_runtime_icons_resolve_only_from_game_directory() -> void:
	for slug in ["community", "population", "composite-happiness", "opportunity", "resident", "place-inspection", "warning"]:
		var path: String = CommunityUIFactory.ICON_ROOT + slug + ".png"
		assert_true(ResourceLoader.exists(path)); assert_false(path.contains("/review/"))

func test_panel_section_controls_have_deterministic_order_and_focus() -> void:
	var panel := CommunityPanel.new(); add_child(panel); panel._build_shell()
	assert_eq(panel._section_buttons.keys(), ["overview", "residents", "places"])
	for section in CommunityPanel.SECTIONS: assert_eq((panel._section_buttons[section] as Button).focus_mode, Control.FOCUS_ALL)
	assert_true(panel._scroll.follow_focus); panel.queue_free()
