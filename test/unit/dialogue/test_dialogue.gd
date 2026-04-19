extends GutTest

## Unit tests for DialoguePlugin.
##
## Constructs the plugin with stub EventSystem + CharacterSystem so we don't
## need to load JSONs or ResourceLoader portraits. Tests drive the modal via
## the test hook `queue_dialogue_for_test` and poke internal _on_option_pressed
## to avoid fighting the button tree.

const DialogueCls := preload("res://plugins/dialogue/dialogue_plugin.gd")

var _plugin: Node
var _stub_events: Object
var _stub_chars:  Object
var _saved_map: DataMap

func before_each() -> void:
	_saved_map = GameState.map
	GameState.map = DataMap.new()

	_stub_events = _StubEvents.new()
	_stub_chars  = _StubChars.new()

	_plugin = DialogueCls.new()
	_plugin._event_system = _stub_events
	_plugin._characters   = _stub_chars
	add_child(_plugin)
	_plugin._build_ui()

func after_each() -> void:
	if _plugin and is_instance_valid(_plugin):
		_plugin.queue_free()
	_plugin = null
	GameState.map = _saved_map

# ── Queue FIFO ────────────────────────────────────────────────────────────────

func test_queue_fifo_three_events() -> void:
	var a := _make_record("a", "character_arrived", "cid_a")
	var b := _make_record("b", "character_arrived", "cid_b")
	var c := _make_record("c", "character_arrived", "cid_c")

	_plugin.queue_dialogue_for_test(a)
	_plugin.queue_dialogue_for_test(b)
	_plugin.queue_dialogue_for_test(c)

	# First event opens immediately; queue holds [a(active), b, c]
	assert_eq(_plugin.queue_size(), 3)
	assert_true(_plugin.is_modal_open())

	# Close a → b becomes active (via call_deferred).
	_plugin._close_current()
	# call_deferred on _open_next — flush deferred calls.
	await get_tree().process_frame
	assert_eq(_plugin.queue_size(), 2)

	_plugin._close_current()
	await get_tree().process_frame
	assert_eq(_plugin.queue_size(), 1)

	_plugin._close_current()
	await get_tree().process_frame
	assert_eq(_plugin.queue_size(), 0)
	assert_false(_plugin.is_modal_open())

# ── Input suppression ─────────────────────────────────────────────────────────

func test_is_input_suppressed_while_open() -> void:
	assert_false(_plugin.is_input_suppressed())
	_plugin.queue_dialogue_for_test(_make_record("x", "character_arrived", "cid"))
	assert_true(_plugin.is_input_suppressed())
	_plugin._close_current()
	await get_tree().process_frame
	assert_false(_plugin.is_input_suppressed())

# ── Tree traversal ────────────────────────────────────────────────────────────

func test_tree_traversal_follows_next_until_close() -> void:
	var rec := _make_record("multi", "character_arrived", "cid_x")
	# n_start → n_middle → "" (close)
	rec["payload"] = {
		"entry_node_id": "n_start",
		"nodes": [
			{"node_id": "n_start", "body": "start", "options": [
				{"label": "go", "next": "n_middle", "effects": []}
			]},
			{"node_id": "n_middle", "body": "middle", "options": [
				{"label": "end", "next": "", "effects": []}
			]},
		]
	}
	_plugin.queue_dialogue_for_test(rec)
	assert_eq(_plugin.current_node_id(), "n_start")

	_plugin._on_option_pressed({"label": "go", "next": "n_middle", "effects": []})
	assert_eq(_plugin.current_node_id(), "n_middle")

	_plugin._on_option_pressed({"label": "end", "next": "", "effects": []})
	await get_tree().process_frame
	assert_false(_plugin.is_modal_open())

# ── Option effects ────────────────────────────────────────────────────────────

func test_option_effects_forwarded_to_event_system() -> void:
	var rec := _make_record("fx", "character_arrived", "cid_x")
	rec["payload"] = {
		"entry_node_id": "n_start",
		"nodes": [
			{"node_id": "n_start", "body": "b", "options": [
				{"label": "do", "next": "", "effects": [{"kind": "set_flag", "target": "f1"}]}
			]},
		]
	}
	_plugin.queue_dialogue_for_test(rec)
	_plugin._on_option_pressed({"label": "do", "next": "", "effects": [{"kind": "set_flag", "target": "f1"}]})
	await get_tree().process_frame
	assert_eq(_stub_events.applied_effects.size(), 1)
	assert_eq(_stub_events.applied_effects[0].get("kind"), "set_flag")

# ── Arrival tree → mark_want_revealed ────────────────────────────────────────

func test_arrival_close_calls_mark_want_revealed() -> void:
	var rec := _make_record("arr", "character_arrived", "cid_alice")
	_plugin.queue_dialogue_for_test(rec)
	_plugin._close_current()
	assert_eq(_stub_chars.revealed_ids, ["cid_alice"])

func test_non_arrival_close_does_not_mark_want_revealed() -> void:
	var rec := _make_record("patron_ready", "patron_landmark_ready", "")
	rec["trigger"]["patron_id"] = "pid_zed"
	_plugin.queue_dialogue_for_test(rec)
	_plugin._close_current()
	assert_eq(_stub_chars.revealed_ids, [], "non-arrival trees don't trigger reveal")

# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_record(eid: String, sig: String, cid: String) -> Dictionary:
	return {
		"event_id": eid,
		"event_type": "dialogue",
		"trigger": {"event": sig, "character_id": cid},
		"payload": {
			"entry_node_id": "n_start",
			"nodes": [
				{"node_id": "n_start", "body": "hello", "options": [
					{"label": "Close", "next": "", "effects": []}
				]}
			]
		}
	}

class _StubEvents:
	extends PluginBase
	signal event_resolved(record: Dictionary)
	var applied_effects: Array = []
	func get_plugin_name() -> String: return "_StubEvents"
	func apply_effects(effects: Array) -> void:
		for e in effects: applied_effects.append(e)
	func apply_effect(e: Dictionary) -> bool:
		applied_effects.append(e); return true

class _StubChars:
	extends PluginBase
	var revealed_ids: Array[String] = []
	func get_plugin_name() -> String: return "_StubChars"
	func mark_want_revealed(cid: String) -> void:
		revealed_ids.append(cid)
	func get_def(_cid: String) -> Dictionary:
		return {"display_name": "Test", "bio": "", "portrait": ""}
