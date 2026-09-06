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
	_plugin.set_reveal_rate_for_test(10.0, 0.2)


func after_each() -> void:
	if _plugin and is_instance_valid(_plugin):
		_plugin.queue_free()
	_plugin = null
	GameState.map = _saved_map


func test_first_row_has_full_text_layout_before_first_character_is_visible() -> void:
	_plugin.open_event_for_test(_linear_event([_speech("player", "Hello, transmitter.")]))
	var row: Dictionary = _plugin.current_row_projection()
	assert_eq(row["full_text"], "Hello, transmitter.")
	assert_eq(row["label_text"], "Hello, transmitter.")
	assert_eq(row["visible_characters"], 0)
	assert_gt(row["minimum_height"], 0.0)
	assert_eq(_plugin.dialogue_mode(), "REVEALING")


func test_deterministic_character_stepping_uses_accumulated_time() -> void:
	_plugin.open_event_for_test(_linear_event([_speech("player", "ABCD")]))
	_plugin.step_reveal_for_test(0.09)
	assert_eq(_plugin.current_row_projection()["visible_characters"], 0)
	_plugin.step_reveal_for_test(0.01)
	assert_eq(_plugin.current_row_projection()["visible_characters"], 1)
	_plugin.step_reveal_for_test(0.2)
	assert_eq(_plugin.current_row_projection()["visible_characters"], 3)
	assert_eq(_plugin.dialogue_mode(), "REVEALING")


func test_punctuation_has_deterministic_additional_delay() -> void:
	_plugin.open_event_for_test(_linear_event([_speech("player", "A,B")]))
	_plugin.step_reveal_for_test(0.1)
	assert_eq(_plugin.current_row_projection()["visible_characters"], 1)
	_plugin.step_reveal_for_test(0.29)
	assert_eq(_plugin.current_row_projection()["visible_characters"], 1)
	_plugin.step_reveal_for_test(0.01)
	assert_eq(_plugin.current_row_projection()["visible_characters"], 2)


func test_instant_mode_displays_whole_beat_and_enters_ready() -> void:
	_plugin.set_instant_text_for_test(true)
	_plugin.open_event_for_test(_linear_event([_speech("player", "Immediate.")]))
	assert_eq(_plugin.current_row_projection()["visible_characters"], "Immediate.".length())
	assert_eq(_plugin.dialogue_mode(), "READY")


func test_natural_timer_completion_only_enters_ready() -> void:
	_plugin.open_event_for_test(_linear_event([
		_speech("player", "A"),
		{"type": "narration", "text": "B"},
	]))
	_plugin.step_reveal_for_test(0.1)
	assert_eq(_plugin.dialogue_mode(), "READY")
	assert_eq(_plugin.current_beat_index(), 0)
	assert_eq(_plugin.transcript_projection().size(), 1)


func test_rapid_complete_then_advance_requires_distinct_calls() -> void:
	_plugin.open_event_for_test(_linear_event([
		_speech("player", "First"),
		{"type": "narration", "text": "Second"},
	]))
	var complete: Dictionary = _plugin.advance_dialogue()
	assert_eq(complete["transition"], "reveal_completed")
	assert_eq(_plugin.current_beat_index(), 0)
	assert_eq(_plugin.transcript_projection().size(), 1)
	var advance: Dictionary = _plugin.advance_dialogue()
	assert_eq(advance["transition"], "beat_started")
	assert_eq(_plugin.current_beat_index(), 1)
	assert_eq(_plugin.transcript_projection().size(), 2)
	assert_eq(_plugin.dialogue_mode(), "REVEALING")


static func _linear_event(beats: Array) -> Dictionary:
	var event := Fixtures.valid_event("reveal_test")
	event["payload"]["nodes"] = [{
		"node_id": "n_start", "beats": beats, "on_enter": [], "options": [],
	}]
	return event


static func _speech(speaker: String, text: String) -> Dictionary:
	return {"type": "speech", "speaker": speaker, "expression": "neutral", "text": text}


class _StubEvents:
	extends PluginBase
	func get_plugin_name() -> String: return "_RevealEvents"
	func apply_effects(_effects: Array) -> void: pass
	func acknowledge_dialogue(_event_id: String) -> bool: return true


class _StubChars:
	extends PluginBase
	func get_plugin_name() -> String: return "_RevealChars"
	func get_def(cid: String) -> Dictionary:
		return {"character_id": cid, "display_name": cid, "portrait": ""}
	func mark_want_revealed(_cid: String) -> void: pass
	func get_state(_cid: String) -> int: return 1
