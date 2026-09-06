extends GutTest

func test_invalid_replacement_changed_and_uncertain_are_visually_distinct() -> void:
	var invalid := PlacementConsequencesPanel.presentation_rows({"status":"invalid", "reason":"outside_buildable_area"})
	assert_eq(invalid[0].tone, "invalid")
	assert_true(String(invalid[0].text).begins_with("Blocked"))
	var quote := {
		"status":"replacement",
		"replacement":{"removed_buildings":[{"internal_id":1}]},
		"access":{"ok":true},
		"community":{"quality_deltas":{"opportunity":0.0,"liveability":-2.0,"beauty":3.0,"belonging":0.0},"affected_resident_count":2,"affected_home_count":1},
		"attractiveness":{"city_delta":0,"affected_tile_count":0},
		"uncertainties":["participant_allocation_after_commit"],
	}
	var rows := PlacementConsequencesPanel.presentation_rows(quote)
	assert_eq(rows[0].tone, "replacement")
	assert_true(rows.any(func(row): return row.tone == "positive"))
	assert_true(rows.any(func(row): return row.tone == "negative"))
	assert_false(rows.any(func(row): return row.tone == "unchanged"))
	assert_true(rows.any(func(row): return row.tone == "uncertain"))
	assert_lte(rows.size(), 9)
	for row in rows:
		assert_has(row, "kind")
		assert_has(row, "actionable")

func test_panel_clears_transient_quote_on_cancel() -> void:
	var panel := PlacementConsequencesPanel.new()
	add_child_autofree(panel)
	panel.setup()
	panel.show_quote({"status":"valid", "community":{"quality_deltas":{}}, "uncertainties":[]})
	assert_false(panel.visible)
	panel.hide_quote()
	assert_false(panel.visible)
	assert_true(panel._last_quote.is_empty())

func test_unchanged_valid_quote_has_no_presentation_rows() -> void:
	var rows := PlacementConsequencesPanel.presentation_rows({
		"status":"valid", "access":{"ok":true},
		"community":{"quality_deltas":{"opportunity":0.0,"liveability":0.0,"beauty":0.0,"belonging":0.0},"affected_resident_count":0,"affected_home_count":0,"effect_radii":[]},
		"attractiveness":{"city_delta":0.0,"affected_tile_count":0},
		"same_type_neighbours":0, "uncertainties":[],
	})
	assert_true(rows.is_empty())

func test_semantic_small_delta_survives_before_formatting() -> void:
	var rows := PlacementConsequencesPanel.presentation_rows({
		"status":"valid", "community":{"quality_deltas":{"beauty":0.000001}},
	})
	assert_eq(rows.size(), 1)
	assert_eq(rows[0].tone, "positive")
	assert_eq(rows[0].kind, "quality")
	assert_false(rows[0].actionable)
	assert_eq(rows[0].semantic_delta, 0.000001)

func test_failed_access_is_actionable_without_numeric_changes() -> void:
	var rows := PlacementConsequencesPanel.presentation_rows({
		"status":"valid", "access":{"ok":false,"reason":"rooted_road_access_required"},
		"community":{"quality_deltas":{}}, "attractiveness":{"city_delta":0},
	})
	assert_eq(rows.size(), 1)
	assert_eq(rows[0].tone, "invalid")
	assert_eq(rows[0].kind, "access")
	assert_true(rows[0].actionable)

func test_invalid_quote_retains_compound_access_and_uncertainty_warnings() -> void:
	var rows := PlacementConsequencesPanel.presentation_rows({
		"status":"invalid", "reason":"outside_buildable_area",
		"access":{"ok":false,"reason":"rooted_road_access_required"},
		"community":{"quality_deltas":{"beauty":12.0}},
		"uncertainties":["network_reconnections_after_commit"],
	})
	assert_eq(rows.size(), 3)
	assert_true(String(rows[0].text).begins_with("Blocked"))
	assert_eq(rows[1].icon, "neighbourhood")
	assert_eq(rows[2].tone, "uncertain")
	assert_false(rows.any(func(row): return String(row.text).begins_with("Beauty")), "invalid domain deltas remain suppressed")

func test_changed_summaries_omit_zero_count_fragments() -> void:
	var rows := PlacementConsequencesPanel.presentation_rows({
		"status":"valid",
		"community":{
			"quality_deltas":{"beauty":2.0},
			"affected_resident_count":0,
			"affected_home_count":2,
			"effect_radii":[0, 3],
		},
		"same_type_neighbours":1,
		"attractiveness":{"city_delta":4.0,"affected_tile_count":0},
	})
	var texts: PackedStringArray = []
	for row in rows:
		texts.append(String(row.text))
	var joined := " | ".join(texts)
	assert_true(joined.contains("2 homes affected"))
	assert_true(joined.contains("1 similar nearby"))
	assert_false(joined.contains("0 resident"))
	assert_false(joined.contains("0 tile"))
	assert_true(joined.contains("Effect reach: 3 tile"))
	assert_false(joined.contains("Effect reach: 0"))

func test_net_neutral_appeal_retains_nonzero_changed_tile_evidence_without_zero_metric() -> void:
	var rows := PlacementConsequencesPanel.presentation_rows({
		"status":"valid",
		"community":{"quality_deltas":{}},
		"attractiveness":{"city_delta":0.0,"affected_tile_count":2},
	})
	assert_eq(rows.size(), 1)
	assert_eq(rows[0].text, "Town appeal shifts across 2 tiles")
	assert_false(String(rows[0].text).contains("±0"))
	assert_eq(rows[0].kind, "attractiveness")
	assert_false(rows[0].actionable)
	assert_eq(rows[0].semantic_delta, 0.0)

func test_compact_layout_and_dashboard_inset_compose_in_either_call_order() -> void:
	var compact_then_inset := PlacementConsequencesPanel.new()
	add_child_autofree(compact_then_inset)
	compact_then_inset.setup()
	compact_then_inset.apply_compact_layout(1280.0)
	compact_then_inset.set_left_safe_inset(504.0)
	compact_then_inset.set_right_safe_inset(380.0)

	var inset_then_compact := PlacementConsequencesPanel.new()
	add_child_autofree(inset_then_compact)
	inset_then_compact.setup()
	inset_then_compact.set_right_safe_inset(380.0)
	inset_then_compact.set_left_safe_inset(504.0)
	inset_then_compact.apply_compact_layout(1280.0)

	# Global panel rect is 516..888: 12 px beyond guidance and Dashboard.
	assert_eq(compact_then_inset.offset_left, -124.0)
	assert_eq(compact_then_inset.offset_right, 248.0)
	assert_eq(inset_then_compact.offset_left, compact_then_inset.offset_left)
	assert_eq(inset_then_compact.offset_right, compact_then_inset.offset_right)
	compact_then_inset.set_right_safe_inset(0.0)
	assert_eq(compact_then_inset.offset_left, -124.0)
	assert_eq(compact_then_inset.offset_right, 346.0)
	compact_then_inset.set_left_safe_inset(0.0)
	assert_eq(compact_then_inset.offset_left, -425.0)
	assert_eq(compact_then_inset.offset_right, 45.0)
