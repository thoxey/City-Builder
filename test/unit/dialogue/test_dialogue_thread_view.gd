extends GutTest

const DialogueThreadView := preload("res://plugins/dialogue/dialogue_thread_view.gd")

var _view: Control


func before_each() -> void:
	_view = DialogueThreadView.new()
	add_child(_view)
	_view.build()


func after_each() -> void:
	if _view and is_instance_valid(_view):
		_view.queue_free()
	_view = null


func test_appending_speech_rows_never_rebuilds_prior_nodes_or_text() -> void:
	var first: Control = _view.append_speech_row("player", "Player", "left", "First line.")
	var first_id := first.get_instance_id()
	var first_text: String = _view.row_projection(0)["full_text"]
	var second: Control = _view.append_speech_row("npc", "NPC", "right", "Second line.")
	assert_eq(_view.transcript_row_count(), 2)
	assert_eq(_view.transcript_row_at(0).get_instance_id(), first_id)
	assert_eq(_view.row_projection(0)["full_text"], first_text)
	assert_eq(_view.transcript_row_at(1), second)


func test_appending_narration_preserves_all_existing_row_identity() -> void:
	var speech: Control = _view.append_speech_row("player", "Player", "left", "Speech.")
	var speech_id := speech.get_instance_id()
	var narration: Control = _view.append_narration_row("Narration.")
	var narration_id := narration.get_instance_id()
	_view.append_speech_row("npc", "NPC", "right", "Reply.")
	assert_eq(_view.transcript_row_at(0).get_instance_id(), speech_id)
	assert_eq(_view.transcript_row_at(1).get_instance_id(), narration_id)
	assert_eq(_view.row_projection(1)["full_text"], "Narration.")


func test_only_current_row_visible_prefix_changes() -> void:
	_view.append_speech_row("player", "Player", "left", "Immutable first.")
	_view.set_current_row_visible_characters(5)
	var first_before: Dictionary = _view.row_projection(0)
	_view.append_narration_row("Current second.")
	_view.set_current_row_visible_characters(7)
	assert_eq(_view.row_projection(0), first_before)
	assert_eq(_view.row_projection(1)["visible_characters"], 7)


func test_player_active_left_and_counterpart_active_right_have_non_colour_emphasis() -> void:
	_view.set_player_portrait("player", "Ambrose", null, "concerned", true)
	_view.set_counterpart_portrait("baba", "Baba Soyink", null, "neutral", false)
	var state: Dictionary = _view.portrait_projection()
	assert_true(state["player"]["active"])
	assert_true(state["player"]["emphasis_visible"])
	assert_eq(state["player"]["side"], "left")
	assert_false(state["counterpart"]["active"])
	assert_lt(state["counterpart"]["opacity"], state["player"]["opacity"])

	_view.set_player_active(false)
	_view.set_counterpart_active(true)
	state = _view.portrait_projection()
	assert_false(state["player"]["active"])
	assert_true(state["counterpart"]["active"])
	assert_true(state["counterpart"]["emphasis_visible"])
	assert_eq(state["counterpart"]["side"], "right")


func test_narration_deactivates_both_portraits_without_losing_identity_or_expression() -> void:
	_view.set_player_portrait("player", "Ambrose", null, "thoughtful", true)
	_view.set_counterpart_portrait("baba", "Baba Soyink", null, "surprised", false)
	_view.deactivate_portraits()
	var state: Dictionary = _view.portrait_projection()
	assert_false(state["player"]["active"])
	assert_false(state["counterpart"]["active"])
	assert_eq(state["player"]["expression"], "thoughtful")
	assert_eq(state["counterpart"]["character_id"], "baba")
	assert_eq(state["counterpart"]["expression"], "surprised")


func test_consecutive_npc_swap_replaces_right_slot_but_retains_prior_row_name() -> void:
	_view.set_counterpart_portrait("baba", "Baba Soyink", null, "surprised", true)
	_view.append_speech_row("baba", "Baba Soyink", "right", "First.")
	_view.set_counterpart_portrait("flick", "Flick", null, "concerned", true)
	_view.append_speech_row("flick", "Flick", "right", "Second.")
	assert_eq(_view.portrait_projection()["counterpart"]["character_id"], "flick")
	assert_eq(_view.row_projection(0)["display_name"], "Baba Soyink")
	assert_eq(_view.row_projection(1)["display_name"], "Flick")


func test_portraits_overlap_frame_by_approximately_five_percent_at_supported_viewports() -> void:
	for viewport_size in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(3840, 2160)]:
		_view.layout_for_viewport_for_test(viewport_size)
		var geometry: Dictionary = _view.geometry_projection()
		assert_almost_eq(geometry["player_overlap_ratio"], 0.05, 0.01, str(viewport_size))
		assert_almost_eq(geometry["counterpart_overlap_ratio"], 0.05, 0.01, str(viewport_size))
		assert_false(geometry["player_rect"].intersects(geometry["transcript_rect"]), str(viewport_size))
		assert_false(geometry["counterpart_rect"].intersects(geometry["transcript_rect"]), str(viewport_size))
		assert_true(geometry["frame_rect"].end.x <= viewport_size.x, str(viewport_size))
		assert_true(geometry["frame_rect"].end.y <= viewport_size.y, str(viewport_size))


func test_bottom_follow_tracks_new_rows_when_already_at_latest() -> void:
	_view.append_narration_row("First.", true)
	_view.set_scroll_state_for_test(100.0, 100.0)
	_view.append_narration_row("Second.", true)
	var scroll: Dictionary = _view.scroll_projection()
	assert_true(scroll["follow_latest"])
	assert_eq(scroll["value"], scroll["maximum"])
	assert_false(scroll["return_to_latest_visible"])


func test_manual_upward_scrollback_is_preserved_when_content_arrives() -> void:
	_view.append_narration_row("First.", true)
	_view.set_scroll_state_for_test(25.0, 100.0)
	_view.append_narration_row("Second.", true)
	var scroll: Dictionary = _view.scroll_projection()
	assert_false(scroll["follow_latest"])
	assert_eq(scroll["value"], 25.0)
	assert_gt(scroll["maximum"], 100.0)
	assert_true(scroll["return_to_latest_visible"])


func test_return_to_latest_restores_follow_mode_and_consumes_indicator() -> void:
	_view.set_scroll_state_for_test(10.0, 200.0)
	_view.return_to_latest_for_test()
	var scroll: Dictionary = _view.scroll_projection()
	assert_true(scroll["follow_latest"])
	assert_eq(scroll["value"], 200.0)
	assert_false(scroll["return_to_latest_visible"])


func test_long_transcript_appends_without_losing_scroll_state() -> void:
	for index in range(200):
		_view.append_narration_row("Transcript row %03d with enough text to wrap once." % index, true)
	assert_eq(_view.transcript_row_count(), 200)
	var scroll: Dictionary = _view.scroll_projection()
	assert_true(scroll["follow_latest"])
	assert_eq(scroll["value"], scroll["maximum"])
