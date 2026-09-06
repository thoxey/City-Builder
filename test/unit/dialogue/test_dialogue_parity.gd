extends GutTest

const DialogueCls := preload("res://plugins/dialogue/dialogue_plugin.gd")
const Fixtures := preload("res://test/unit/dialogue/dialogue_fixtures.gd")

var _visible: Node
var _headless: Node
var _visible_events: _StubEvents
var _headless_events: _StubEvents
var _visible_chars: _StubChars
var _headless_chars: _StubChars

func before_each() -> void:
	_visible_events = _StubEvents.new()
	_headless_events = _StubEvents.new()
	_visible_chars = _StubChars.new()
	_headless_chars = _StubChars.new()
	_visible = _make_dialogue(_visible_events, _visible_chars, true)
	_headless = _make_dialogue(_headless_events, _headless_chars, false)

func after_each() -> void:
	for plugin in [_visible, _headless]:
		if is_instance_valid(plugin): plugin.queue_free()

func test_visible_and_headless_first_option_paths_have_identical_ordered_outcomes() -> void:
	var record := Fixtures.branching_event("parity")
	_visible_events.pending["parity"] = true
	_headless_events.pending["parity"] = true
	_headless_events.records["parity"] = record
	_visible.open_event_for_test(record)
	_visible.advance_dialogue()
	_visible._on_option_pressed(record["payload"]["nodes"][0]["options"][0])
	_visible.advance_dialogue()
	var visible_outcome: Dictionary = _visible.last_outcome_for_test()
	var headless_result: Dictionary = _headless.resolve_pending_event("parity")
	var headless_outcome: Dictionary = headless_result["details"]
	assert_eq(visible_outcome["visited_node_ids"], headless_outcome["visited_node_ids"])
	assert_eq(visible_outcome["ordered_effects"], headless_outcome["ordered_effects"])
	assert_eq(visible_outcome["arrival_transition"], headless_outcome["arrival_transition"])
	assert_true(visible_outcome["acknowledged"])
	assert_true(headless_outcome["acknowledged"])

func test_missing_destination_is_rejected_without_effects_or_acknowledgement() -> void:
	var record := Fixtures.branching_event("missing_destination")
	record["payload"]["nodes"][0]["options"][0]["next"] = "not_there"
	_visible_events.pending["missing_destination"] = true
	_headless_events.pending["missing_destination"] = true
	_headless_events.records["missing_destination"] = record
	_visible.open_event_for_test(record)
	var result: Dictionary = _headless.resolve_pending_event("missing_destination")
	assert_false(_visible.is_modal_open())
	assert_eq(result["status"], PlaytestActionResult.STATUS_REJECTED)
	assert_eq(_visible_events.applied_effects, [])
	assert_eq(_headless_events.applied_effects, [])
	assert_eq(_visible_events.acknowledged_ids, [])
	assert_eq(_headless_events.acknowledged_ids, [])

func test_visible_and_headless_traversal_ceiling_reject_cycle_without_completion() -> void:
	var record := Fixtures.cyclic_event("cycle_ceiling")
	_visible_events.pending["cycle_ceiling"] = true
	_headless_events.pending["cycle_ceiling"] = true
	_headless_events.records["cycle_ceiling"] = record
	_visible.open_event_for_test(record)
	for index in range(128):
		_visible.advance_dialogue()
		var node: Dictionary = _visible._current_node()
		_visible._on_option_pressed(node["options"][0])
	var visible_outcome: Dictionary = _visible.last_outcome_for_test()
	var result: Dictionary = _headless.resolve_pending_event("cycle_ceiling")
	assert_eq(visible_outcome["diagnostic"], "dialogue_cycle_limit")
	assert_eq(visible_outcome["visited_node_ids"].size(), 128)
	assert_false(visible_outcome["acknowledged"])
	assert_eq(result["status"], PlaytestActionResult.STATUS_REJECTED)
	assert_eq(result["details"]["visited_node_ids"].size(), 128)
	assert_eq(_visible_events.acknowledged_ids, [])
	assert_eq(_headless_events.acknowledged_ids, [])

func test_data_only_three_way_scenario_plays_without_renderer_special_case() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://test/scenarios/dialogue/three_way_conversation.json"
	))
	assert_true(parsed is Dictionary)
	var record: Dictionary = parsed
	_visible_events.pending[record["event_id"]] = true
	_visible.open_event_for_test(record)
	for index in range(3):
		assert_eq(_visible.advance_dialogue()["transition"], "beat_started")
	assert_eq(_visible.advance_dialogue()["transition"], "conversation_completed")
	var rows: Array = _visible.transcript_projection()
	assert_eq(rows.map(func(row): return row["speaker"]), [
		Fixtures.BABA, Fixtures.FLICK, Fixtures.PLAYER, Fixtures.BABA,
	])
	assert_eq(rows.map(func(row): return row["side"]), ["right", "right", "left", "right"])

func _make_dialogue(events: _StubEvents, chars: _StubChars, visible: bool) -> Node:
	var plugin := DialogueCls.new()
	plugin._event_system = events
	plugin._characters = chars
	add_child(plugin)
	plugin._build_ui()
	plugin.set_instant_text_for_test(true)
	plugin.set_presentation_enabled(visible)
	return plugin

class _StubEvents extends PluginBase:
	var applied_effects: Array = []
	var records: Dictionary = {}
	var pending: Dictionary = {}
	var acknowledged_ids: Array[String] = []
	func apply_effects(effects: Array) -> void:
		for effect in effects: applied_effects.append(effect.duplicate(true))
	func get_event(event_id: String) -> Dictionary: return records.get(event_id, {}).duplicate(true)
	func is_dialogue_pending(event_id: String) -> bool: return pending.get(event_id, false)
	func acknowledge_dialogue(event_id: String) -> bool:
		if not is_dialogue_pending(event_id): return false
		pending.erase(event_id)
		acknowledged_ids.append(event_id)
		return true

class _StubChars extends PluginBase:
	var revealed_ids: Array[String] = []
	var states := {Fixtures.BABA: 1}
	func mark_want_revealed(character_id: String) -> void:
		revealed_ids.append(character_id)
		states[character_id] = 2
	func get_state(character_id: String) -> int: return int(states.get(character_id, 1))
	func get_def(character_id: String) -> Dictionary:
		return {"display_name": character_id, "portrait": ""}
