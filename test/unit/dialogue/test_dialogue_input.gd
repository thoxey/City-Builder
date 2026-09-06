extends GutTest

const DialogueCls := preload("res://plugins/dialogue/dialogue_plugin.gd")
const Fixtures := preload("res://test/unit/dialogue/dialogue_fixtures.gd")

var _plugin: Node
var _saved_map: DataMap


func before_each() -> void:
	_saved_map = GameState.map
	GameState.map = DataMap.new()
	_plugin = DialogueCls.new()
	_plugin._event_system = _StubEvents.new()
	_plugin._characters = _StubChars.new()
	add_child(_plugin)
	_plugin._build_ui()


func after_each() -> void:
	if _plugin and is_instance_valid(_plugin):
		_plugin.queue_free()
	_plugin = null
	GameState.map = _saved_map


func test_frame_bubble_and_narration_clicks_share_surface_advance() -> void:
	for target in ["frame", "bubble", "narration"]:
		_open_revealing()
		var result: Dictionary = _plugin.accept_input_event_for_test(_left_click(), target)
		assert_eq(result["transition"], "reveal_completed", target)
		assert_true(result["consumed"], target)
		_plugin.discard_session_for_test()


func test_space_enter_and_controller_confirm_share_advance_command() -> void:
	for event in [_key(KEY_SPACE), _key(KEY_ENTER), _action("dialogue_advance")]:
		_open_revealing()
		var result: Dictionary = _plugin.accept_input_event_for_test(event, "surface")
		assert_eq(result["transition"], "reveal_completed")
		assert_true(result["consumed"])
		_plugin.discard_session_for_test()


func test_key_echo_is_rejected_without_transition() -> void:
	_open_revealing()
	var event := _key(KEY_SPACE)
	event.echo = true
	var result: Dictionary = _plugin.accept_input_event_for_test(event, "surface")
	assert_eq(result["transition"], "ignored")
	assert_false(result["accepted"])
	assert_eq(_plugin.dialogue_mode(), "REVEALING")


func test_already_handled_event_is_rejected() -> void:
	_open_revealing()
	var result: Dictionary = _plugin.accept_input_event_for_test(_left_click(), "surface", true)
	assert_eq(result["transition"], "ignored")
	assert_false(result["accepted"])
	assert_eq(_plugin.dialogue_mode(), "REVEALING")


func test_choice_scrollbar_and_return_latest_consume_without_ordinary_advance() -> void:
	for target in ["choice", "scrollbar", "return_latest"]:
		_open_revealing()
		var result: Dictionary = _plugin.accept_input_event_for_test(_left_click(), target)
		assert_eq(result["transition"], "ignored", target)
		assert_true(result["consumed"], target)
		assert_eq(_plugin.dialogue_mode(), "REVEALING", target)
		_plugin.discard_session_for_test()


func test_one_physical_event_causes_at_most_one_transition() -> void:
	_open_revealing()
	var before_rows: int = _plugin.transcript_projection().size()
	var result: Dictionary = _plugin.accept_input_event_for_test(_left_click(), "bubble")
	assert_eq(result["transition"], "reveal_completed")
	assert_eq(_plugin.current_beat_index(), 0)
	assert_eq(_plugin.transcript_projection().size(), before_rows)


func test_terminal_ready_surface_activation_completes_without_button() -> void:
	_plugin.set_instant_text_for_test(true)
	_plugin.open_event_for_test(_terminal_event())
	assert_eq(_plugin.dialogue_mode(), "READY")
	var result: Dictionary = _plugin.accept_input_event_for_test(_left_click(), "frame")
	assert_eq(result["transition"], "conversation_completed")
	assert_eq(_plugin.dialogue_mode(), "DONE")
	assert_false(_plugin.is_modal_open())
	assert_eq(_plugin.dialogue_button_texts(), [])


func test_dialogue_tree_never_constructs_continue_or_finish_buttons() -> void:
	_plugin.set_instant_text_for_test(true)
	_plugin.open_event_for_test(_terminal_event())
	var labels: Array = _plugin.dialogue_button_texts()
	assert_eq(labels, [])
	for label in labels:
		assert_false(String(label).to_lower() in ["continue", "finish", "close"])


func _open_revealing() -> void:
	_plugin.set_instant_text_for_test(false)
	_plugin.open_event_for_test(Fixtures.two_person_event("input_test"))


static func _terminal_event() -> Dictionary:
	var event := Fixtures.valid_event("input_terminal")
	event["payload"]["nodes"] = [{
		"node_id": "n_start",
		"beats": [{"type": "narration", "text": "The end."}],
		"on_enter": [],
		"options": [],
	}]
	return event


static func _left_click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


static func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


static func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


class _StubEvents:
	extends PluginBase
	var acknowledged: Array[String] = []
	func get_plugin_name() -> String: return "_InputEvents"
	func apply_effects(_effects: Array) -> void: pass
	func acknowledge_dialogue(event_id: String) -> bool:
		acknowledged.append(event_id)
		return true


class _StubChars:
	extends PluginBase
	func get_plugin_name() -> String: return "_InputChars"
	func get_def(cid: String) -> Dictionary:
		return {"character_id": cid, "display_name": cid, "portrait": ""}
	func mark_want_revealed(_cid: String) -> void: pass
	func get_state(_cid: String) -> int: return 1
