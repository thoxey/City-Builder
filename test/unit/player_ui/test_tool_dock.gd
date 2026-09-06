extends GutTest

func test_idle_placement_and_demolition_have_one_canonical_mode() -> void:
	var dock := PlayerToolDock.new()
	dock.setup()
	dock.set_model({"entries_by_id":{"house":{"display_name":"House","icon_key":"missing-artwork"}}})
	dock.show_idle()
	assert_false(dock._context_group.visible)
	assert_false(dock._cancel_button.visible)
	assert_false(dock._demolish_button.button_pressed)
	dock.show_placement("house")
	assert_true(dock._context_group.visible)
	assert_true(dock._cancel_button.visible)
	assert_false(dock._demolish_button.button_pressed)
	assert_string_contains(dock._context_label.text, "House")
	dock.show_demolition()
	assert_true(dock._demolish_button.button_pressed)
	assert_string_contains(dock._context_label.text, "Demolition")
	dock.free()

func test_buttons_emit_one_action_with_current_toggle_state() -> void:
	var dock := PlayerToolDock.new()
	dock.setup()
	watch_signals(dock)
	dock._build_button.pressed.emit()
	dock._demolish_button.button_pressed = true
	dock._demolish_button.pressed.emit()
	dock._cancel_button.pressed.emit()
	assert_signal_emit_count(dock, "build_requested", 1)
	assert_signal_emitted_with_parameters(dock, "demolition_requested", [true])
	assert_signal_emit_count(dock, "cancel_requested", 1)
	dock.free()
