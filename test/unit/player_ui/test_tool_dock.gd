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

func test_placement_shows_signed_authored_costs_and_community_effects_with_icons() -> void:
	var dock := PlayerToolDock.new()
	dock.setup()
	dock.set_model({"entries_by_id":{"house":{
		"display_name":"House", "icon_key":"missing-artwork",
		"representative_cash_cost":120,
		"representative_demand_cost":{"bucket_id":"residential", "cost":5.0},
		"authored_effects":[
			{"quality":"beauty", "amount":4.0, "scope":"city", "reason":"Base Beauty"},
			{"quality":"liveability", "amount":-2.5, "scope":"local", "reason":"Traffic noise"},
		],
	}}})
	dock.show_placement("house")
	var rows: Array = dock.effect_row_projection()
	assert_eq(rows.map(func(row): return [row["kind"], row["label"], row["signed_value"]]), [
		["cash", "Cash", "-£120"],
		["demand", "Homes", "-5"],
		["community", "Beauty", "+4"],
		["community", "Liveability", "-2.5"],
	])
	assert_true(rows.all(func(row): return row["icon_available"]), "established icons resolve")
	dock.free()

func test_placement_rows_ignore_live_cell_preview_and_missing_icons_keep_text() -> void:
	var dock := PlayerToolDock.new()
	dock.setup()
	var entry := {"display_name":"House", "icon_key":"missing-artwork", "authored_effects":[
		{"quality":"opportunity", "amount":1.0, "scope":"city", "reason":"Authored"},
	]}
	dock.set_model({"entries_by_id":{"house":entry}})
	dock.show_placement("house", "", 0, {"effects":[{"quality":"beauty","amount":999}], "same_type_neighbours":12})
	var rows: Array = dock.effect_row_projection()
	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["label"], "Opportunity")
	assert_eq(rows[0]["signed_value"], "+1")
	assert_false(rows.any(func(row): return row["signed_value"] == "+999"))
	dock._add_effect_row("community", "res://missing/icon.png", "Unknown", "+3", "Fallback")
	rows = dock.effect_row_projection()
	assert_false(rows[-1]["icon_available"])
	assert_eq(rows[-1]["label"], "Unknown")
	assert_eq(rows[-1]["signed_value"], "+3")
	dock.free()


func test_high_dpi_layout_scales_dock_and_keeps_safe_inset_in_physical_pixels() -> void:
	var dock := PlayerToolDock.new()
	dock.setup()
	dock.apply_viewport_layout(3840.0)
	dock.set_right_safe_inset(380.0)
	assert_eq(dock.scale, Vector2(2.0, 2.0))
	assert_eq(dock.pivot_offset, Vector2(360.0, 192.0))
	assert_eq(dock.offset_left, -550.0)
	assert_eq(dock.offset_right, 170.0)
	dock.apply_viewport_layout(1280.0)
	assert_eq(dock.scale, Vector2.ONE)
	assert_eq(dock.offset_left, -550.0)
	dock.free()
